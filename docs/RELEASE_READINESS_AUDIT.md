# Release-readiness audit — Forever Wayfinder

**Baseline:** `main` at `74431c2efcedbacd4766888156b0cb7351b7885c`  
**Hardening branch:** `fix/search-window-layering`  
**Product:** World of Warcraft: Forever addon  
**Current package version:** 1.1.0  
**TOC interface:** 16001

## Executive assessment

The addon has a working foundation: QuestieDB-backed indexing, HandyNotes world-map/minimap integration, service categories, faction filtering, settings, minimap button, TomTom waypoint support, status diagnostics, and a search service. The latest in-game report supplied during this review shows a completed scan with 1,616 coordinate nodes across 51 maps, 1,184 NPC records and 127 objects, zero invalid records, zero invalid spawns, and zero per-record scan errors.

That is strong evidence for the data/index pipeline on the tested character and dependency set. It is not proof of release-wide compatibility or completeness. UI, navigation, dependency-version, upgrade, packaging, and alternate-character/faction behavior still require actual client testing.

## Confirmed issue found and corrected

### Search window had no initial anchor

The search window was created and sized but did not call `SetPoint`. The settings panel, by contrast, explicitly anchors itself. An unanchored frame can be created and shown without appearing at a predictable on-screen location. The search window now:

- Anchors itself to the center of `UIParent` on first creation.
- Uses `FULLSCREEN_DIALOG` strata before assigning its frame level.
- Is placed above the settings panel's Search button.
- Rechecks its relative frame level whenever it opens.
- Retains the existing toggle, focus, filter, result and close behavior.

A mocked WoW-frame lifecycle regression test now checks creation, centering, strata, frame level, input focus, close, and reopen. This does not replace an in-client test.

## Feature inventory

| Area | Current behavior | Assessment |
|---|---|---|
| Data source | QuestieDB NPC and object data read at runtime; no bundled location database | Correctly avoids stale duplicate data; coverage is bounded by QuestieDB |
| Services | Vendor, repair, innkeeper, mailbox, auctioneer, banker, flight master, stable master | Implemented |
| Trainers | Class, profession, portal, weapon, battle-pet, other trainer | Implemented; text-based subcategory classification needs representative in-game spot checks |
| Other POIs | Spirit healer, battlemaster, barber, transmogrifier, tabard designer | Implemented when the client/database exposes the relevant flags |
| Vendor icons | Vendor sub-name keyword rules select stock-type icons; generic vendor icon is fallback | Heuristic, not a verified inventory listing |
| Map pins | HandyNotes world map and minimap, category-aware icon selection, shared-coordinate nodes | Implemented; map hierarchy and dense-city coverage need client validation |
| Tooltips | Names, sub-names, categories and coordinates; bounded to 12 visible entries | Implemented |
| Search | Case-insensitive name/sub-name substring, category, zone-name and exact numeric map-ID filters; capped result display | Implemented; no fuzzy search, NPC-ID search, or explicit map-coordinate zoom/highlight |
| Navigation | Search result selects map when supported; optional TomTom waypoint; pin right-click waypoint | Implemented with graceful optional dependency checks; verify on target client |
| Settings | Master enable, category toggles, map/minimap visibility, continent display, faction filter, pin scale | Implemented |
| Minimap button | Show/hide, drag around minimap, left-click settings, right-click minimap pin toggle | Implemented |
| Persistence | SavedVariables defaults and defensive normalization for existing values | Implemented; no multi-version migration framework is needed until schema changes are introduced |
| Diagnostics | Scan totals, invalid records/spawns, unavailable positions, unmapped areas, timing and protected-record errors | Implemented |
| Localization | English strings are embedded in Lua | Not implemented; only add if the product commits to localized releases |
| Favorites / recents | Not present | Optional product enhancement, not required for core promise |
| Search navigation focus | No guaranteed zoom/pin highlight at result coordinates | UX enhancement; only implement against verified client APIs |
| Data correction | No manually curated replacement coordinates for QuestieDB omissions | Deliberate; never invent coordinates |

## Data diagnostics interpretation

The current report has nine unavailable positions and five unmapped areas. These are not invalid spawn records:

- The nine unavailable positions use QuestieDB's `(-1, -1)` sentinel. They are correctly excluded from map pins and reported separately.
- The five unmapped areas are not currently resolved by the QuestieDB area-to-map mapping. Do not guess map IDs or fabricate coordinates.
- The report's 1,616 count is coordinate nodes/pins, not the number of NPCs. Multiple NPCs can share one pin.
- `Max scan slice: 0.0000s` is currently displayed to four decimal places. The real client timer resolution and measurement semantics should be checked before treating that number as proof that slices are free or instantaneous.

## Release blockers and required evidence

These items cannot be honestly marked complete from repository inspection or pure-Lua tests alone.

### P0 — Must pass before calling a release candidate

- [ ] Install from a clean folder using the exact release package layout.
- [ ] Verify the declared interface number against the current supported WoW Forever client build.
- [ ] Record the tested QuestieDB and HandyNotes versions and their public API contract.
- [ ] Test a clean install and an upgrade while preserving existing `ForeverWayfinderDB` saved variables.
- [ ] Confirm no Lua errors on login, reload, opening/closing both windows, changing settings, and using all slash commands.
- [ ] Confirm the search window opens visibly from both the settings button and `/fw search`; enter a name and confirm results appear.
- [ ] Confirm search filters, no-match state, index-not-ready state, result limit, and result clicks.
- [ ] Confirm representative major-city pins, including Stormwind, for vendors, trainers and service NPCs.
- [ ] Test Alliance and Horde characters with faction filtering on and off; verify neutral NPCs remain visible.
- [ ] Test world-map/minimap toggles, continent display, category toggles, tooltips, and minimap button interactions.
- [ ] Test with TomTom installed and absent.
- [ ] Run automated Lua syntax, pure-Lua regression, and mocked search UI tests on the exact PR head.
- [ ] Measure enumeration duration, scan slice duration, search latency, and memory behavior on the full QuestieDB dataset.
- [ ] Verify the packaged ZIP contains the TOC and runtime Lua files, and excludes tests, development docs, screenshots, and CI files.

### P1 — Strongly recommended before broad promotion

- [ ] Test repeated `/fw refresh`, including a refresh while a scan is in progress.
- [ ] Test missing QuestieDB, missing HandyNotes, incompatible QuestieDB contract, and missing optional TomTom.
- [ ] Test malformed saved-variable values and settings reset.
- [ ] Test window placement at multiple UI scales and screen resolutions.
- [ ] Check crowded cities and shared-coordinate tooltips for readability and responsiveness.
- [ ] Compare a sample of NPC classifications and vendor icon choices with QuestieDB data in game.
- [ ] Test zone and map navigation for both ordinary zones and nested map hierarchies.

## Automation and repository quality

The Lua validation workflow now installs the distro-provided Lua 5.1 package rather than downloading and compiling Lua from a third-party action. It runs:

1. Lua 5.1 syntax validation over every addon module and test file.
2. Pure-Lua regression tests for classification, data/index behavior, zone-map decoding, and search filtering.
3. Mocked search-window lifecycle tests for the WoW frame creation/toggle path.

A passing workflow is necessary but not sufficient: it cannot validate the real WoW UI, QuestieDB runtime data, HandyNotes callbacks, or TomTom integration.

## Deliberately deferred features

These are not release blockers and should not be added merely to increase feature count:

- Fuzzy search and NPC-ID lookup.
- Favorites, recent searches, and saved waypoints.
- A full embedded map browser or map-coordinate zoom/highlight.
- Additional POI types without a reliable QuestieDB source field.
- Curated static coordinates that duplicate or conflict with QuestieDB.
- Localization without a committed translation workflow.

Each should have a concrete user problem, a verified source of truth, acceptance criteria, and regression tests before implementation.

## Definition of release-ready

Forever Wayfinder is ready for a new public release only when all P0 checks are complete, the latest CI run is green, the package has been inspected, and the target client has been tested with documented dependency versions. Until then, the code can be described as **automated-test validated** or **in-game tested on the reported setup**, but not universally production-verified.
