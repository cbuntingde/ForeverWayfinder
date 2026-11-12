# Phase 0–2 validation plan

**Scope:** Phase 0–2 implementation plus the search UI release-hardening follow-up  
**Baseline:** `main` commit `74431c2efcedbacd4766888156b0cb7351b7885c`  
**Current review:** [PR #3](https://github.com/cbuntingde/ForeverWayfinder/pull/3) on `fix/search-window-layering`  
**Purpose:** Separate automated regression checks from tests that require the actual WoW Forever client and installed dependencies.

## Current validation status

| Area | Status | Evidence / limitation |
|---|---|---|
| Lua 5.1 syntax | Passed locally 2026-11-11 (`luac5.1 -p`, all nine modules + tests); CI rerun pending push | Waypoints.lua is now explicitly included in the syntax command. |
| Pure-Lua regression suite | Passed locally 2026-11-11 (`lua5.1 tests/run.lua`), expanded coverage | Adds faction filtering, scan lifecycle (completion, isolation, idempotent rebuild, restart generation safety, enumeration-failure recovery), saved-variable validation/reset, waypoint provider, and zone-override precedence tests. |
| QuestieDB contract and real data | Contract verified against installed source; in-game data spot-checks pending | QuestieDB Forever 1.0.14, contract 4. `RequireContract`, `NpcDB`/`ObjectDB` `Get`/`GetAll`/`GetRaw`/`GetAllIds`, `Enum.npcFlags` (Classic rules), and `Support.Get("ZoneDB").private.areaIdToUiMapId(+Override)` all match the addon's usage. |
| HandyNotes registration and map/minimap callbacks | Contract verified against installed source; in-game render pending | HandyNotes v1.6.32 (TOC lists interface 16001). `RegisterPluginDB`, `GetNodes2` iterator `(coord, mapID, icon, scale, alpha)`, and `UpdatePluginMap(nil, name)` match. Pins carry the iterator's mapID into `OnEnter`/`OnClick`, so continent-aggregated pins resolve to the correct child map. |
| TomTom waypoint creation | Contract verified against installed source; in-game click pending | TomTom v4.4.1-release (TOC lists interface 16001). `AddWaypoint(mapID, x, y, opts)` takes 0–1 coordinates with `title`/`crazy`/`from`; `RemoveWaypoint(uid)` backs the new clear action. |
| Search-window mocked lifecycle | Covered by `tests/search_ui.lua`; actual client still required | Mocked WoW frames cover creation, center anchor, strata/frame level, focus, close and reopen. Real rendering and input behavior remain in-game checks. |
| Search-window layout and input behavior | Not verified in game | UI frames and input scripts are not represented by the pure-Lua test harness beyond the mocked lifecycle above. |
| Large-dataset performance | Not profiled in game | Search now uses index-time normalized text, cached map names, and precomputed sort keys; enumeration and query latency still need measurement with representative data. |
| Saved-variable upgrade/reset behavior | Validation and reset covered by automated tests; in-game persistence test required | Corrupted values, clamping, unknown-key preservation, and reset scope are regression-tested. A real client reload cycle is still required. |

## Runtime evidence on the target client (2026-11-11)

- The addon has loaded and run on the installed Forever client: `ForeverWayfinderDB` saved variables exist with `schemaVersion = 1`, user-customized category toggles, and a dragged frame position.
- The installed `!BugGrabber` capture (160 sessions) contains zero Forever Wayfinder errors or protected-function blocks.
- The client runs a modern FrameXML (MapCanvas/WorldMap/EditMode); `C_Map.GetMapChildrenInfo`, `Enum.UIMapType`, `SetColorTexture`, `BackdropTemplate`, and `C_Timer.NewTicker` are all exercised by the installed Questie/HandyNotes/TomTom. Search map selection now follows Questie's proven `OpenWorldMap` pattern (`C_Map.OpenWorldMap` when present, otherwise `WorldMapFrame:Show()` + `SetMapID`).
- This evidence confirms load and basic operation only; it does not replace the functional matrix below.

## Verified dependency matrix

| Component | Installed version | Interface | Contract evidence |
|---|---|---|---|
| WoW Forever client | build 1.60.1.70291 (per QuestieDB zone-data header) | 16001 | Modern FrameXML confirmed via client logs and installed addon API usage. |
| QuestieDB | Forever 1.0.14 (`X-Contract-Version: 4`, baked mode) | 16001 | `src/api.lua`, `src/read/shared.lua`, `src/support/data.lua`, `src/corrections/enum/expansions.lua` (Classic rules). |
| HandyNotes | v1.6.32 | 16001 listed | `HandyNotes.lua` plugin documentation and pin callback wiring. |
| TomTom | v4.4.1-release (optional) | 16001 listed | `core/waypoints.lua` `AddWaypoint`/`RemoveWaypoint`. |
| Search-window CI status | CI rerun pending push | The rebased head re-runs syntax, both test suites, and the addon packaging check. |

## Automated checks

Run from the repository root with Lua 5.1:

```sh
luac5.1 -p Core.lua Classification.lua ZoneMap.lua Data.lua Waypoints.lua Search.lua Pins.lua UI.lua Minimap.lua tests/run.lua tests/search_ui.lua
lua5.1 tests/run.lua
lua5.1 tests/search_ui.lua
```

The GitHub Actions workflow also builds and inspects a clean addon ZIP, then uploads it as the `ForeverWayfinder-addon` artifact. PR #3 run 87 completed successfully, including all syntax, test, package-build, and package-content steps. This still does not replace target-client testing.

## In-game test setup

1. Use a clean test character/profile where possible; keep a backup of the existing `ForeverWayfinderDB` saved variables.
2. Install the target WoW Forever client build and the exact QuestieDB and HandyNotes releases intended for support.
3. Test once with TomTom installed and once without it.
4. Enable Lua errors and capture the client build, addon versions, and any stack traces.
5. Record baseline load time, indexing duration, maximum scan-slice duration, pin count, map count, NPC count, object count, and error counters from `/fw status`.

## Functional test matrix

### Startup and dependencies

- [ ] Addon loads without Lua errors with QuestieDB and HandyNotes installed.
- [ ] Missing QuestieDB produces a clear disabled reason and does not attempt indexing.
- [ ] Missing HandyNotes produces a clear disabled reason.
- [ ] TomTom is optional; the addon still loads and pins still render without it.
- [ ] Repeated `/reload` does not create duplicate HandyNotes registrations or minimap buttons.

### Indexing and recovery

- [ ] Initial scan completes and `/fw status` reports consistent nonzero counts.
- [ ] `/fw refresh` restarts indexing and reaches completion.
- [ ] Trigger a second refresh during indexing; only the newest generation completes and no stale ticker continues.
- [ ] Confirm an enumeration failure leaves no stale progress state and a subsequent refresh can recover.
- [ ] Invalid or unresolved records are counted without aborting the whole scan.
- [ ] Inspect representative Alliance-only and Horde-only NPCs with faction filtering enabled and disabled.
- [ ] Compare several known NPCs and mailboxes against QuestieDB source data.

### Shared coordinates and search

- [ ] A location with more than five NPCs retains and displays every distinct NPC.
- [ ] Duplicate NPC IDs at the same coordinate do not create duplicate search results.
- [ ] Search matches full and partial NPC names, case-insensitively.
- [ ] Search matches NPC sub-names.
- [ ] Category filtering returns only entries classified in the selected category.
- [ ] Zone-name filtering is case-insensitive.
- [ ] Numeric map-ID filtering matches the exact map ID, not IDs containing the same digits.
- [ ] Empty filters show the prompt instead of dumping the entire database.
- [ ] No-match and result-limit messages are correct.
- [ ] Typing quickly does not show stale results or freeze the client.
- [ ] Open search while indexing, then confirm results refresh after indexing completes.

### Map, pins, and navigation

- [ ] Left-clicking a search result opens/selects the expected map on the target client.
- [ ] Right-clicking a search result creates a waypoint at the correct map and coordinates when TomTom is installed.
- [ ] Right-clicking a HandyNotes pin creates a waypoint at the correct map and coordinates.
- [ ] Without TomTom, both paths fail gracefully with a useful message.
- [ ] World-map and minimap visibility toggles work independently.
- [ ] Continent/parent-map behavior is correct for representative zones.
- [ ] Tooltips show all NPCs at shared locations and the correct categories/coordinates.

### Settings and persistence

- [ ] Every category toggle updates pins without a reload.
- [ ] Pin scale changes apply correctly.
- [ ] Minimap button drag, click, right-click, and hide setting work.
- [ ] Settings panel and search window remain on-screen at supported UI scales/resolutions.
- [ ] Existing saved settings survive an addon update.
- [ ] Malformed saved values fall back safely without Lua errors.
- [ ] Reset restores defaults while preserving only the settings intentionally preserved by design.

### Performance and release checks

- [ ] Measure initial scan duration on a representative full QuestieDB dataset.
- [ ] Confirm scan slices do not cause noticeable frame stalls.
- [ ] Measure search latency on name, category-only, and zone-only queries.
- [ ] Check memory after repeated refreshes for retained old indexes/tickers.
- [ ] Confirm no duplicate rows, stale waypoints, or growing event/frame registrations after repeated use.
- [ ] Verify TOC interface number against the exact target client build.
- [ ] Verify dependency API contract versions against the exact supported QuestieDB/HandyNotes/TomTom releases.

## Exit criteria

Phase 0–2 is ready to proceed only when:

1. The latest PR head passes Lua syntax validation and all pure-Lua tests.
2. All startup, indexing, search, pin, navigation, and persistence test cases above pass in the target client, or are explicitly documented as unsupported with a clear fallback.
3. There are no reproducible Lua errors.
4. Performance measurements are recorded and acceptable on representative data.
5. The supported client/dependency versions are documented from actual tested builds, not inferred from TOC metadata alone.

Record failures with: client build, addon versions, exact reproduction steps, expected result, actual result, and full Lua error stack.
