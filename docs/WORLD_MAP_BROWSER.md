# World Map Location Browser — Design

**Status:** Phases A-C implemented (data layer, panel with this-map and all-zones scopes, settings and slash wiring); in-game geometry and map-change verification remain
**Date:** 2026-11-22  
**Scope:** Forever Wayfinder 1.3.x  
**Tracking issue:** the GitHub issue that links this document

---

## 1. Problem

Locations can only be discovered two ways today: hover every pin on the world map, or type a query in the search window. Neither lets a player scan "all flight masters in this zone" or "all bankers nearby" without already knowing a name.

The requested feature is a browsable list, attached to the world map, grouped by category, where clicking a location creates a TomTom waypoint.

## 2. Current state (evidence)

| Piece | Location | Notes |
|---|---|---|
| Index build | `Data.lua:246` (`ns:AddSpawn`) | `ns.index[mapID][coord] = { x, y, cats, entries, vendorIcon? }` |
| Node/entry shape | `Data.lua:281`, `Data.lua:296` | Entries carry `name`, `sub`, `id`, `kind`, `categories` |
| Categories and groups | `Core.lua:264`, `Core.lua:304` | 19 categories in three groups with icons |
| Icon priority | `Core.lua:298` | Order used to pick a single pin icon |
| Pin rendering | `Pins.lua:124` (`handler:GetNodes2`) | HandyNotes provider; `ns:GetMapsFor` at `Pins.lua:48` |
| Typed search | `Search.lua:23` (`ns:SearchEntries`), `Search.lua:129` | Requires a query; max 100 rows |
| Map focus | `Search.lua:190` (`FocusMap`) | `C_Map.OpenWorldMap` → `WorldMapFrame:SetMapID`, combat-guarded |
| Waypoints | `Waypoints.lua:13` (`Waypoints:Set`) | TomTom `AddWaypoint`, normalized 0–1 coords |
| Theme helpers | `Core.lua:47`–`Core.lua:256` | `Journal.Decorate/Page/Text/Button/Input/Solid` |
| Map ID access | `Core.lua:750`, `Search.lua:201` | `WorldMapFrame:GetMapID` / `SetMapID` with `pcall` |

No new data or indexing work is required. The browser is a second view over `ns.index`.

## 3. Proposal

A panel docked to the right edge of `WorldMapFrame`, rendered in the existing journal theme, listing indexed locations with a category-grouped, collapsible list. Left-click a row to create a TomTom waypoint; right-click to open/centre that map.

### 3.1 Placement and lifecycle

- Panel is a child of `WorldMapFrame`, anchored `TOPLEFT` to the map canvas's `TOPRIGHT` (offset ~8 px) when the frame leaves room; otherwise it anchors inside the map frame's right edge (24 px inset, 90 px down) so it never lands offscreen. Height is clamped to 320–640 px.
- A small tab/button on the map frame's right edge toggles the panel. State persists as `db.browserEnabled`.
- Shown only while the world map is shown and the index is ready; hidden with the map.
- Displayed map ID: `WorldMapFrame:GetMapID()`, falling back to `C_Map.GetBestMapForUnit("player")`. Both wrapped in `pcall`.
- Refresh triggers:
  - `WorldMapFrame:HookScript("OnShow", ...)`
  - `hooksecurefunc(WorldMapFrame, "SetMapID", ...)` when available
  - a 0.25 s `OnUpdate` guard while shown that compares the current map ID (covers clients whose map changes do not fire the hook)
  - `ns:Refresh()` path so category toggles and index completion update the list
- All refresh work is debounced through `C_Timer.After(0, ...)` so a map-change burst produces one rebuild.
- Rebuilds are read-only; no protected frames are touched. Right-click map focus reuses the existing `FocusMap` combat guard.

### 3.2 Scope modes

- **This map (default):** lists entries whose `mapID` equals the displayed map. No parent/continent fallback — an empty result shows "No indexed locations on this map". This avoids dumping a whole continent list onto a map that simply has no indexed data.
- **All zones:** lists every indexed map, grouped category → zone → location, with a zone subheader before each run of rows. Intended for cross-zone planning; waypoints are set with the node's own `mapID`, which TomTom accepts across zones.
- The two scope buttons ("This map" / "All zones") sit above the filter and persist the choice as `db.browserMode`.
- Continent aggregation (`db.showOnContinent`) does not affect the browser; it stays a pin-display option.

### 3.3 Grouping and sorting

- Sections follow `ns.categoryGroups` order (SERVICES, TRAINERS, OTHER POINTS OF INTEREST), then `keys` order within each group. Each section header shows a count.
- Each indexed entry appears under every enabled category it matches. A vendor that also repairs appears under both Vendors and Repair — that is the point of category browsing, and it matches how the search category filter behaves today. A shared coordinate with several NPCs yields one row per NPC, since the category claim belongs to the entry, not the merged node.
- Only categories enabled in `db.categories` are shown, so the list always matches the visible pins. `db.factionFilter` is applied at index time, so the list inherits it without extra work.
- Sort inside a category: map mode → `ns:GetNodeTitle(node)`, then coordinate; all-zones mode → zone name, then title.
- Row text: title, then a detail line with the sub-name and coordinates. All-zones mode adds a muted zone subheader before each zone's rows instead of repeating the zone on every row.
- Categories with no matching nodes are omitted in both modes.

### 3.4 Row actions

- **Left-click:** `ns.Waypoints:Set(mapID, node.x, node.y, title)`. On failure (TomTom missing, invalid coords) print the existing reason via `ns:Print`.
- **Right-click:** open/centre the node's map using the existing `FocusMap` logic; in combat print the existing "Cannot open the map during combat." message.
- **Hover:** highlight the row; optionally a tooltip listing every entry at that coordinate (same data the pin tooltip shows, `Pins.lua:141`), capped for crowded coordinates.
- **Footer:** result count/status line and a "Clear waypoint" button wired to `Waypoints:ClearLast()`.

### 3.5 Filter box

A single text input above the list filters the current mode by NPC name or sub-name using `ClassificationNormalizeText` and plain substring matching, consistent with search ([Search.lua:4](file:///C:/Program%20Files%20(x86)/World%20of%20Warcraft/_forever_/Interface/AddOns/ForeverWayfinder/Search.lua#L4)). Filtering stays inside the selected scope; it does not silently switch modes.

### 3.6 States

| State | Panel shows |
|---|---|
| `ns.blocked` | Disabled reason (red), same wording as the settings/search windows |
| `not ns.ready` | "Index is still loading…" and no rows |
| No matches in map mode | Empty message; switch scope with the All zones button |
| No matches in all-zones mode | Empty message; filter is kept |

## 4. Implementation plan

1. **Pure data layer (testable, no WoW API).** Add `ns:BrowseEntries(options)` in `Search.lua` next to `SearchEntries`: input `{ maps = { id, ... } | nil (all), query = "", categories = db.categories, limit = 100 }`; output sections in category-group order, each with `{ key, group, name, icon, total, capped, rows }` where rows carry `{ mapID, coord, node, entry, name, sub, title, zoneName }`, plus meta `{ shown, capped }`. Reuse `GetMapName` and normalized `searchName`/`searchSub`. Unit tests in `tests/run.lua` in the existing style (Lua 5.1, no client APIs).
2. **Panel UI.** New `Browser.lua`: map-frame anchor, toggle tab, header, filter input, scroll frame with lazily created rows (same pattern as `Search.lua:246`), section headers, footer, map-change hooks, debounced refresh. Load after `Search.lua` in the TOC.
3. **Wiring.** `Core.lua`: defaults `browserEnabled = true`, `browserMode = "map"`; `/fw browse` in `HandleSlash` and `PrintHelp`; call the browser refresh from `ns:Refresh()`. `UI.lua`: "World map browser" checkbox in the Display section.
4. **Tests and docs.** Extend `tests/run.lua` for grouping, multi-category membership, scope filtering, caps and sort order; update `README.md` usage/features; add a `CHANGELOG.md` entry.

Suggested phases: (A) `BrowseEntries` + tests, (B) panel with this-map mode, (C) all-zones mode + settings/slash + docs. All three are implemented; only in-game verification remains.

## 5. Performance

- Rows are created on demand and reused; hidden overflow rows are kept, as in the search window.
- Hard caps: 100 rows per category in both modes, applied after sorting so the kept rows are deterministic, with a "narrow with the filter" note when clamped. Collapsed sections need not render their rows.
- `GetMapName` results are cached in `ns.mapNameCache`.
- The only per-frame work while the panel is visible is the 0.25 s map-ID comparison.
- A rebuild walks only the nodes of the relevant maps; it never scans the full index in map mode.

## 6. Risks and open questions

- **Map frame geometry on Forever.** The panel's offset and default width (suggest 260–300 px) must be confirmed in-game; if the map has a right-side element (e.g. quest log), prefer a tabbed/collapsible panel or clamp to the screen.
- **Map-change signal.** `SetMapID` hooks may not cover every transition on this client; the polling fallback must be verified by switching zone → continent → city.
- **Large all-zones lists.** Thousands of nodes are indexed; the cap + filter is the mitigation. Grouping by category first (per the request) means a global name search across zones is better served by the existing search window.
- **Duplicates across sections** are intentional; duplicates inside one section are not, and must be de-duplicated by `(kind, id)` like `AddSpawn` does.
- **Other addons' POIs** are out of scope. Enumerating other HandyNotes plugins' nodes is a separate integration.

## 7. Acceptance criteria

1. With the world map open, the panel lists locations for the displayed map under SERVICES / TRAINERS / OTHER with per-category counts.
2. Left-clicking a row creates a TomTom waypoint at the node's normalized coordinates; without TomTom the existing failure message is printed.
3. Right-clicking a row opens/selects that map outside combat, and prints the existing combat message in combat.
4. Toggling a category in settings immediately adds/removes the corresponding rows.
5. "All zones" lists cross-zone locations grouped by category then zone, and waypoints resolve on the node's own map.
6. Indexing and disabled states render without Lua errors; no rows are shown before `ns.ready`.
7. The panel follows map changes and its visibility survives `/reload` via `db.browserEnabled`.
8. `lua5.1 tests/run.lua` and `lua5.1 tests/search_ui.lua` pass, including new browse tests.
9. `/fw browse` toggles the panel; README, CHANGELOG and TOC are updated.

## 8. Out of scope

- Route planning, distance ordering or pathfinding.
- Importing POIs from other addons.
- Replacing the world map or its pin rendering.
- Auction-house/faction-specific filtering beyond the existing `factionFilter`.

## 9. Rollout

Ship as 1.3.0 with the browser disabled-by-default only if in-game geometry cannot be verified on the target client; otherwise enabled. No migration needed beyond additive `db` defaults.
