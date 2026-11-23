# Custom world map frame + built-in location sidebar — feasibility (2026-11-23)

Question: can we ship our own world map frame with the location browser built into
the side, the way Blizzard's quest sidebar is part of the map?

Short answer: a fully custom map is technically buildable on 1.60.1, but it is the
expensive and fragile path. Making our existing panel behave like a built-in sidebar
gets ~90% of the feel for a fraction of the risk. Recommended: Option B.

## Option A — replace WorldMapFrame with our own map frame

Building blocks that do exist on this client:

- Map art is readable: `C_Map.GetMapArtID(mapID)` and `C_Map.GetMapArtLayers(mapID)`
  are used by ForeverQoL to tile unexplored art (`ForeverQoL/Modules/RevealWorldMap.lua`),
  so a custom frame can draw real map layers.
- Coordinate math and pin placement are solved: HereBeDragons is already shipped by
  Questie, HandyNotes and TomTom.

What we would have to rebuild and keep working:

- Pan/zoom/fit, continent -> zone -> dungeon layer switching, sub-zone levels.
- Blizzard POIs and vignettes, flight-master pins, tracking-pin button, map tooltip,
  mousewheel behavior, "Toggle World Map" keybinding, Escape handling.
- Fog/reveal, quest pins and objectives, archaeology/dig sites (if present).
- Our own pin projection for every map, not just current-zone pins.

Two hard blockers against replacing, not reskinning:

1. Integration loss. Questie, HandyNotes and TomTom all paint into `WorldMapFrame`
   (HandyNotes via `WorldMapFrame.dataProviders`, Questie via its own map module).
   A replacement frame gets none of that unless we reimplement their pin layers, so
   we would lose the quest context that makes Wayfinder useful.
2. Protected frame. `WorldMapFrame` is tied to the map key and the panel system.
   Substituting our frame means remapping the key and hiding theirs, which is
   taint-prone; the real map also can't be opened in combat, and we would own that
   problem ourselves.

Verdict: not recommended. The maintenance cost scales with every client build.

## Option B — integrated sidebar on Blizzard's map (recommended)

Status: Phase 1 shipped in 1.4.0 — location strip (browsed map + player
zone/subzone/coords), an opt-out for those coords ("Panel coordinates"), and a
persisted collapse rail that docks beside Blizzard's quest sidebar when it is
shown. Phase 2 shipped in 1.5.0 — "What's here" group chips (All / Services /
Trainers / Other) with live counts that filter the list only; map pins and the
saved category toggles are untouched. Phase 3 shipped in 1.6.0 — a NEAR ME
toggle sorts rows by yard distance (HereBeDragons, bundled with HandyNotes) and
adds the distance to each row, and list rows have a hover card with name, role,
zone, coords, distance, and the click actions. Phase 4 shipped in 1.7.0 — a
cursor position readout on the scope row (canvas math, same opt-out as the
player coordinates) and a filter palette: `/fw find [text]` or the "Focus map
location filter" key binding opens the map, expands the panel, and focuses the
filter. Phase 5 shipped in 1.8.0 — the "Cartographer's Column" redesign of the
panel itself (see below). Phase 6 shipped in 1.9.0 — a wider column with an
opaque page, coordinates in their own column, and profession trainers as a
group of their own (see below). Phase 7 shipped in 1.10.0 — the faceted
category filter and the settings window on the same column design (see below).
Phase 8 shipped in 1.11.0 — the code audit fixes (see below). The parked
minimap-parity and route-planner ideas remain out of scope unless asked.

## Phase 5 — Cartographer's Column (shipped in 1.8.0)

The panel stopped borrowing the settings dialog's chrome. It is now a column
with its own identity, built on a 4 px spacing scale:

- **Spine.** A 28 px branded rail down the map-facing edge: the addon icon in
  a gold socket, vertical "LOCATIONS" lettering, and a gold hairline that
  separates the rail from the page. It reads as the spine of a folded map.
- **Page.** The panel body is a dark leather page with a soft vertical falloff
  (stacked bands, because this client has no gradient primitive), a printed
  double rule, and a full-bleed header and location strip.
- **Header.** Carries the browsed scope (the map name, or ALL ZONES) instead of
  a fixed title; the strip below it carries the player location on the left
  and the cursor position on the right.
- **Scope switch.** A two-segment control (THIS MAP / ALL ZONES) replaces the
  underline tabs, with NEAR ME as a pill beside it.
- **Category chips.** A two-column grid with the group name on the left and the
  live count on the right, so four-digit counts no longer crowd the label.
- **Ledger rows.** Rows are 38 px: the category glyph sits in a dark badge, the
  name and the meta line hang off a common indent, and the hairline rule sits
  at the row's foot. Sections are leather bands with a gold edge and a count.
- **Spacing.** Every gap is 4, 8, 12 or 16 px and every block is placed from the
  one above it, so the column keeps its rhythm when a block changes height.

Checks for 1.8.0:

- The column docks beside the Blizzard quest sidebar and the spine faces the map.
- The header names the browsed map and switches to ALL ZONES in that mode.
- The location strip shows the player on the left and the cursor on the right;
  the cursor readout hides in the collapsed rail and with "Panel coordinates" off.
- The scope switch, the chips and the NEAR ME pill all still drive the list.
- Rows show a badge, a name and a meta line; hovering lights the gold edge bar
  and the badge, and the hover card still carries name, role, zone, coords and
  distance.
- Collapsing to the rail keeps the spine, the scope name and the location
  strip; expanding restores everything with the same spacing.

## Phase 6 — opaque page, coordinates column, profession group (shipped in 1.9.0)

Three fixes to the 1.8.0 column, all reported from the map itself:

- **The page was see-through.** The falloff bands are colour textures, and a
  colour texture has no intrinsic size: without a right-hand anchor each band
  was zero pixels wide, so the only thing covering the map was the list well
  (itself at 82% alpha). The map art, the map's own zone lettering and the
  strip under the header all showed through. The bands now span their parent,
  the list well is opaque, and the header and location strip are solid.
- **Coordinates wrapped onto a second line.** The row meta line was
  "role · distance · coordinates", which is wider than the column, so long
  roles pushed the coordinates onto a second line. The column is now 380 px
  wide and the row has a fixed right-hand column: the distance sits beside the
  name, the coordinates sit under it, and the role keeps the left column. A
  name or role that is still too wide is trimmed with an ellipsis instead of
  wrapping into the row below.
- **Profession trainers are their own group.** "Profession Trainers" used to
  sit inside the TRAINERS group, so it could not be filtered on its own. It
  is now the PROFESSIONS group with its own chip and count, and the settings
  window lists it under its own heading.

Checks for 1.9.0:

- The column is opaque over the map art: no terrain, zone lettering or
  watermark text shows through the page, the spine or the footer.
- Every row keeps its coordinates on one line, right-aligned in a column.
- The PROFESSIONS chip lists only profession trainers, with its own count, and
  the settings window shows a PROFESSION TRAINERS section.
- The ALL chip spans the full width above the four group chips.

## Phase 7 — faceted filter and one product (shipped in 1.10.0)

The five group chips answer "what kind of place is this". They do not answer
"which one of my services". Phase 7 adds a second tier for that, brings the
settings window onto the same design, and fixes the gaps the audit turned up.

- **Facet tier.** Under the group chips, a three-column grid of category chips
  shows the categories of the selected group only. Under ALL the tier is empty,
  so the default view keeps its full list height and no new tier appears for
  every category in the game.
- **The section bands are filters too.** A band with the vendor count filters
  the list by that category; the small marker beside it folds the section away.
  A second click on the same band or chip clears the filter again.
- **One set of names.** The group table in `Core.lua` owns the group title, the
  chip label and the short label. The chips, the settings bands, the status
  line and the facet tier read the same table, so a group cannot be renamed in
  one place and forgotten in another.
- **The settings window is the same column.** Banded leather page, spine rail,
  section bands and ledger rows, one implementation shared with the map column
  (`ns.Journal` and `ns.Column` in `Core.lua`). The page scrolls, so a category
  added later cannot push rows out of the window.
- **Search covers the enabled categories.** The search window matches the
  category toggles from the settings, and the name box also matches a category
  name, the same way the column filter does.
- **One category name, two surfaces.** In the column the category is the band
  above the rows; in the search window there are no bands, so the matched
  category leads the result line in gold.
- **The waypoint survives a reload.** TomTom owns the waypoint, so the handle is
  looked up by source instead of stored; the settings window shows whether one
  is set and clears it.

Checks for 1.10.0:

- The facet tier appears with a group chip and lists that group's categories.
- Clicking a facet chip or a section band filters the list; clicking the same
  one again clears the filter.
- The marker beside a band folds its section without changing the filter.
- The settings window scrolls, and every category, display and waypoint row is
  reachable.
- The search window returns nothing for a category that is switched off, and
  finds a NPC by its category name.
- `/fw clear` removes the waypoint after a reload, and the settings row shows
  the waypoint state.

## Phase 8 — code audit fixes (shipped in 1.11.0)

A line-by-line audit of the addon produced ten defects. Each entry below gives
the root cause, the wire that carried it, and what to look at in game.

### Counts described two different things

The group chips counted list rows, the footer counted indexed locations
(pins). A place listed under two categories — a smith that is both a vendor
and a repairer — inflated one number and not the other, so "12 locations" sat
above a list of 14 rows.

Cause: the counts were taken where the rows were built. Fix: `ns:BrowseEntries`
now counts distinct nodes per section and per group (`section.nodes`,
`meta.groupCounts` in `Search.lua`), and the chips read that count
(`Browser.lua:UpdateGroups`). The chip tooltip names the unit ("3 locations"),
so the number can no longer be read as a row count by accident.

### A disabled category wrote a filter it could not fill

The facet chip wrote `ns.db.browserCategory` even when the category had been
switched off in the settings. The category is not in the index, so the list came
back empty with no visible cause.

Fix: the facet chip refuses to write a filter for a switched-off category
(`Browser.lua:CreateFacetChip`), and the facet tier no longer lists it, so the
grid holds no row that cannot be selected.

### The minimap button could get stuck in a drag

The button never receives the mouse-up when the cursor is released outside it,
so `dragging` stayed true and the button kept following the cursor.

Fix: the `OnUpdate` handler ends the drag as soon as the left button is no
longer down (`Minimap.lua`), which is the only reliable end-of-drag signal.

### The minimap drag compared two coordinate spaces

`GetCursorPosition()` is scale independent, frame offsets are not, so the drag
angle drifted on a scaled UI.

Fix: the cursor is converted into the parent's coordinate space before it is
compared with the minimap centre. The exact offset semantics of the client
could not be settled offline, so the conversion is explicit and guarded rather
than swapped for an unverified convention. This one needs an in-game look on a
scaled UI.

### Opening the column rewrote a setting

`Browser:Show()` set `ns.db.browserEnabled = true`. Closing the column and
opening the map again turned the auto-show back on, against the user's choice.

Fix: `Show()` only updates the scope; the flag belongs to the user.

### The minimap button flag was inverted

The setting was stored as `hideMinimapButton` and read as "show", so the stored
value and the meaning were two different things.

Fix: the flag is `showMinimapButton` (default true), and `ns:InitDB` moves an
existing choice from the old name to the new one before the defaults are
filled in, so the saved preference survives the rename.

### The object scan read everything to keep only mailboxes

`ns:StartScan` walked the whole QuestieDB object table, but only mailboxes are
used from it.

Fix: the object table is read only when the mailbox category is switched on.

### Long setting labels ran under the checkbox

`Journal.LedgerRow` gave the label the full width, so a long setting name
wrapped into the row below.

Fix: the label is trimmed with `Journal.FitText`.

### Dead code and one long command chain

`Journal.Section` and `Journal.CheckRow` were never used and are gone. The
`/fw` handler was a single 290-line if/else chain; it is now one function per
command behind a dispatch table, with the same output text.

### Checks for 1.11.0

- The chip counts match the number of places the tooltip names; the smith that
  is both a vendor and a repairer counts once.
- Switch a category off in the settings: its chip leaves the facet tier, and
  clicking it no longer empties the list.
- Drag the minimap button and release the mouse outside it: the button stays
  where it was dropped and the angle stops following the cursor.
- Open the column, close it, open the map again: with auto-show off the column
  stays closed.
- The minimap button appears by default, the settings can switch it off, and
  the choice survives a reload.
- `/fw status` and the settings footer report mailboxes, not objects.
- `/fw`, `/fw on`, `/fw off`, `/fw refresh`, `/fw reset`, `/fw search`,
  `/fw browse`, `/fw find <text>`, `/fw clear`, `/fw status`, `/fw icon` and
  `/fw map` all still print what they printed before.

## 1.12.0 — the sidebar swallowed the keyboard

### The M key stopped toggling the world map

The panel called `EnableKeyboard(true)` and handled keys in `Browser:HandleKey`
without ever calling `SetPropagateKeyboardInput`. On this client a visible
keyboard-enabled frame consumes every key, so while the auto-shown sidebar was
up the `TOGGLEWORLDMAP` binding never reached the WorldFrame: M opened the map
once and then did nothing, and ESC appeared to work only because the first
press hid the sidebar and the second closed the map.

Fix: the panel no longer enables keyboard input at all. Arrow-key selection
and Enter-to-set-waypoint moved onto the filter edit box, which captures keys
only while it has focus, and clicking a row clears that focus. The key set was
never a user-facing feature; the sidebar is a mouse surface now.

`Bindings.xml` was also removed: this client rejects addon `<Binding>` XML
(`Unrecognized XML: Binding`, the same warnings MacroRotate triggers), so the
binding never registered. `/fw find` already opens the map and focuses the
filter, and `BINDING_HEADER_*` strings went with the file.

The column also sat under the map's cursor strip and title bar: the old
default top offset was 56 px and a vertically centered saved position ignored
the header entirely. Placement now uses a 112 px top inset, the panel height
reserves that inset plus a bottom margin, and a restored position is pulled
down until its top clears the band. UI-parented (dragged-off-map) positions
are left alone.

The settings page was also taller than the 700×780 window could show on a
short UI scale, so it always scrolled and the last DISPLAY row was clipped.
The ledger rows now form three columns (22 px rows, 12 pt labels), the five
surface toggles and four panel switches share one grid, and the page keeps
16 px of bottom padding. Content is 530 px against a 568 px viewport on a
764-tall screen. The scroll frame remains for shorter screens, and its bar is
hidden when the content fits.

### Checks for 1.12.0

- Open the map with M, press M again: the map closes with the sidebar up.
- Open the map with M, press ESC: the map closes (no two-press behavior).
- The column's top starts below the map's cursor strip and title bar, both on
  a fresh install and after a reload with a saved position.
- `/fw` shows the whole settings page on one screen: every category, the
  DISPLAY switches, Waypoint and Pin scale are visible without scrolling,
  with clear space below the last row.
- Click the filter box, type a name: rows filter; UP/DOWN move the selection;
  ENTER sets the waypoint and returns the keyboard to the bindings.
- Click a row: the waypoint is set and M closes the map afterwards.
- BugSack no longer records ForeverWayfinder's `Bindings.xml` warnings.
- `/fw find orc` still opens the map, expands the column, and focuses the
  filter.

We already have the panel; it is a child of `WorldMapFrame` docked to the right edge
(`Browser.lua`). The gap is presentation, not capability. Make it read as built-in:

- Fixed right rail with a vertical tab strip: Locations / Search / Route / Filters.
- Detect the Blizzard quest sidebar and dock to its left (or auto-collapse) so the
  two sidebars never fight. Remember expanded/collapsed state.
- Journal chrome (same `Journal.*` helpers as the settings window) so map, panel and
  settings look like one product.
- Collapse to an icon rail on map open, expand on click/hover.

This keeps Questie/HandyNotes/TomTom pins, works in every map mode, and can ship
incrementally.

## Ideas worth considering (ranked by value / effort)

1. Location strip in the panel header: map name, cursor zone/subzone + coords,
   player coords, one-click "set waypoint here". This is the "location bar" ask.
2. Hover card on pins: NPC name, role, faction, coords, Set waypoint / Copy coords.
3. "What's here": per-category counts for the current map in the panel header,
   clickable to filter.
4. Near-me sort + distance column (HereBeDragons `GetDistance`).
5. Command palette: `/fw` or Ctrl+F on the map opens search over the panel, results
   grouped "this zone / continent / world".
6. Category chips + saved filter presets ("trainers for my class").
7. Pin declutter: cluster at low zoom, Alt to show only hovered category.
8. Multi-stop route: queue 2-5 locations, line on the map, TomTom waypoint per stop,
   auto-advance on arrival. Bigger feature; park unless asked.
9. Minimap parity: same filters and a compact zone/subzone/coords line under the
   minimap so both surfaces speak the same language.

## Verify in game before building

- Whether this client shows the Blizzard quest sidebar on the map and which frame
  owns its width (to dock around it).
- Whether hiding/replacing `WorldMapFrame` taints (test `/console taintLog 1`) —
  only relevant if Option A is ever revisited.
- Panel position persistence across map size changes.

## Phase 3 checks (1.6.0)

- NEAR ME ordering matches walking distance on your continent; rows on another
  continent sort last and show no distance.
- Hovering a row shows name, role, zone/coords, distance, and both click actions;
  the tooltip closes with the panel.

## Phase 4 checks (1.7.0)

- Cursor coords follow the mouse over map art and hide over the panel, in
  all-zones mode, while collapsed, and when "Panel coordinates" is off.
- `/fw find trainer` or the "Focus map location filter" binding opens the map,
  expands the panel, and focuses the filter with the text selected.
