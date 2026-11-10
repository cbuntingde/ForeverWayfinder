# Phase 0–2 validation plan

**Scope:** Forever Wayfinder 1.1.0 implementation on PR #2  
**Branch:** `feature/phase-0-1-foundation`  
**Purpose:** Separate automated regression checks from tests that require the actual WoW Forever client and installed dependencies.

## Current validation status

| Area | Status | Evidence / limitation |
|---|---|---|
| Lua 5.1 syntax | Passed on the latest previously checked commit; rerun required for this review patch | GitHub Actions run 42 passed before the review fixes. Search.lua is now explicitly included in the syntax command. |
| Pure-Lua regression suite | Passed on the latest previously checked commit; rerun required for this review patch | GitHub Actions run 42 passed before the exact-map-ID regression test was added. |
| QuestieDB contract and real data | Not verified in game | Requires the target client and actual QuestieDB release. |
| HandyNotes registration and map/minimap callbacks | Not verified in game | Requires the target client and HandyNotes. |
| TomTom waypoint creation | Not verified in game | Requires TomTom installed and its live API. |
| Search-window layout and input behavior | Not verified in game | UI frames and input scripts are not represented by the pure-Lua test harness. |
| Large-dataset performance | Not profiled in game | Enumeration and search latency must be measured with representative data. |
| Saved-variable upgrade/reset behavior | Partially reviewed; in-game persistence test required | Requires a real client profile and reload cycle. |

## Automated checks

Run from the repository root with Lua 5.1:

```sh
luac -p Core.lua Classification.lua ZoneMap.lua Data.lua Search.lua Pins.lua UI.lua Minimap.lua tests/run.lua
lua tests/run.lua
```

The GitHub Actions workflow runs both commands. Do not mark the branch fully validated until the latest head commit has a successful workflow run.

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
