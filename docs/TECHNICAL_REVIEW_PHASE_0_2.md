# Technical review — Forever Wayfinder Phases 0–2

**Historical review branch:** `feature/phase-0-1-foundation`  
**Foundation pull request:** [#2](https://github.com/cbuntingde/ForeverWayfinder/pull/2) (merged into `main`)  
**Follow-up hardening:** [PR #3](https://github.com/cbuntingde/ForeverWayfinder/pull/3)  
**Review scope:** Phase 0 baseline, Phase 1 reliability foundation, Phase 2 NPC search/discovery.

## Executive assessment

The Phase 0–2 foundation was merged into `main`. The follow-up PR #3 adds a missing search-window anchor, mocked frame lifecycle tests, deterministic Lua 5.1 setup, and package verification. The addon is not yet production-verified. The main release blocker is the absence of runtime validation in the actual WoW Forever client with the supported QuestieDB, HandyNotes, and optional TomTom releases.

The review also found correctness and usability issues in the new search/indexing paths. The code-level issues listed below were corrected on this branch; the newest tooltip change still needs its own CI run.

## Findings and disposition

### Fixed in this review

| Severity | Finding | Impact | Disposition |
|---|---|---|---|
| High | A failed ID enumeration after restarting a scan could leave the previous scan object attached. | Status UI could display stale progress after the new scan had already failed. | Clear `self.scan` before resetting and enumerating. |
| Medium | Numeric map-ID filtering used substring matching. | Searching for map ID `10` could match IDs such as `100` or `210`. | Numeric zone input now matches the exact map ID; textual zone input still uses case-insensitive name matching. |
| Medium | Search.lua was not explicitly listed in the workflow's `luac -p` command. | The test harness did compile it through `loadfile`, but the syntax job did not explicitly enumerate every addon module. | Added Search.lua to the syntax command. |
| Medium | Retaining all NPC entries made the map tooltip unbounded. | Crowded coordinates could produce excessively long tooltips. | Tooltip now shows at most 12 NPCs and directs users to `/fw search` for the full list. |

### Remaining risks / work

| Priority | Risk | Why it matters | Required action |
|---|---|---|---|
| High | No in-game verification against the target client and real dependency versions. | API signatures, TOC interface compatibility, map hierarchy, HandyNotes callbacks, and TomTom behavior cannot be proven by pure-Lua tests. | Complete the manual matrix in `PHASE_0_2_VALIDATION.md`. |
| Medium | Search scans the complete in-memory index and sorts all matches for every debounced query. | Large QuestieDB datasets may cause UI stalls, especially with broad category/zone filters. | Measure query latency in game; if material, add a precomputed normalized search index and/or incremental result processing. |
| Medium | Search UI and navigation interactions are only partially covered by mocks. | The new mock covers frame creation, anchoring, layering, focus and toggle lifecycle, but not live input rendering, map navigation, or TomTom. | Complete the in-client matrix; extend mocks only where they provide reliable signal. |
| Medium | `GetAllIds()` enumeration is still synchronous. | The scan's later processing is sliced, but initial ID enumeration may still block the client on large datasets. | Record enumeration duration on representative QuestieDB data; adopt an iterator only if the dependency exposes a supported API. |
| Low | Search result click selects a map but does not explicitly zoom/focus the map at the NPC coordinate. | Users may still need to locate the pin manually on a large map. | Consider a tested map focus/zoom adapter in Phase 3; do not assume undocumented client APIs. |
| Low | Full shared-location retention increases memory use relative to the old five-entry cap. | This is the correct trade-off for complete search, but should be measured on the real dataset. | Record memory and index counts during the performance test. |

## Code review notes

- The data, classification, zone-map, search, pin, and presentation responsibilities are more clearly separated than before.
- The QuestieDB zone-map decoder uses a restricted environment, but it still executes dependency-supplied Lua source. The source is expected to be trusted addon data; this is not a general-purpose hostile-code sandbox and has no instruction/time budget.
- Search filtering uses plain substring matching, not tokenized or fuzzy search. This is acceptable for the initial phase but should be stated in user-facing help.
- Search results are capped for display, but the current implementation still gathers and sorts the complete matching set before applying that cap. The result limit therefore bounds UI rows, not search CPU or temporary memory.
- Existing assumptions about the target client's `C_Map`, `WorldMapFrame:SetMapID`, `C_Timer.NewTicker`, and dependency contracts remain to be verified in game.

## Follow-up: search window and release hardening

The current `main` version of `Search.lua` created a 560×590 frame without assigning any anchor. The search settings window does anchor itself. PR #3 corrects this by anchoring the search window at the center of `UIParent`, assigning `FULLSCREEN_DIALOG` strata before setting its frame level, and raising it above the settings panel's Search button. The frame level is rechecked on subsequent opens.

A new mocked frame lifecycle test verifies that the search frame is created, centered, shown, focused, hidden, and reopened above its opener. PR #3 also replaces the previous Lua source-build action with Ubuntu's Lua 5.1 package, runs all test files, builds a runtime-only ZIP, checks that the package excludes development files, and uploads the artifact.

## Current validation evidence

- PR #3 workflow run 87 passed on head `8e487be8dc365281e6343624b7ccbe8399aa2d9a`.
- The run passed Lua 5.1 syntax validation, pure-Lua regression tests, mocked search UI lifecycle tests, clean package creation, and package-content checks.
- The generated `ForeverWayfinder-addon` artifact is available from [workflow run 87](https://github.com/cbuntingde/ForeverWayfinder/actions/runs/42944578426).
- The user's in-game report confirms a complete scan with 1,616 coordinate nodes across 51 maps, 1,184 NPCs, 127 objects, zero invalid records/spawns, and zero scan errors. This is evidence for that tested setup only.
- Search-window rendering, actual keyboard/mouse input, map navigation, dependency compatibility, faction coverage, and performance still require testing in the target client.

## Recommendation

PR #2 is already merged and should remain the foundation. Do not call the addon release-ready or publish a new release based only on CI. Test PR #3 in the actual WoW Forever client, complete the P0 items in `RELEASE_READINESS_AUDIT.md`, and address any reproducible runtime defects before merging the hardening follow-up.
