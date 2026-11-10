# Technical review — Forever Wayfinder Phases 0–2

**Reviewed branch:** `feature/phase-0-1-foundation`  
**Pull request:** [#2](https://github.com/cbuntingde/ForeverWayfinder/pull/2)  
**Review scope:** Phase 0 baseline, Phase 1 reliability foundation, Phase 2 NPC search/discovery.

## Executive assessment

The branch establishes a useful modular foundation and has a passing pure-Lua CI run. It is not yet production-verified. The main release blocker is the absence of runtime validation in the actual WoW Forever client with the supported QuestieDB, HandyNotes, and optional TomTom releases.

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
| Medium | Search UI and navigation interactions have no frame/API integration tests. | The current test harness verifies the pure filtering service, not frame layout, input events, world-map selection, or TomTom. | Validate on the actual client and add a mock-frame harness where practical. |
| Medium | `GetAllIds()` enumeration is still synchronous. | The scan's later processing is sliced, but initial ID enumeration may still block the client on large datasets. | Record enumeration duration on representative QuestieDB data; adopt an iterator only if the dependency exposes a supported API. |
| Low | Search result click selects a map but does not explicitly zoom/focus the map at the NPC coordinate. | Users may still need to locate the pin manually on a large map. | Consider a tested map focus/zoom adapter in Phase 3; do not assume undocumented client APIs. |
| Low | Full shared-location retention increases memory use relative to the old five-entry cap. | This is the correct trade-off for complete search, but should be measured on the real dataset. | Record memory and index counts during the performance test. |

## Code review notes

- The data, classification, zone-map, search, pin, and presentation responsibilities are more clearly separated than before.
- The QuestieDB zone-map decoder uses a restricted environment, but it still executes dependency-supplied Lua source. The source is expected to be trusted addon data; this is not a general-purpose hostile-code sandbox and has no instruction/time budget.
- Search filtering uses plain substring matching, not tokenized or fuzzy search. This is acceptable for the initial phase but should be stated in user-facing help.
- Search results are capped for display, but the current implementation still gathers and sorts the complete matching set before applying that cap. The result limit therefore bounds UI rows, not search CPU or temporary memory.
- Existing assumptions about the target client's `C_Map`, `WorldMapFrame:SetMapID`, `C_Timer.NewTicker`, and dependency contracts remain to be verified in game.

## Validation evidence

- GitHub Actions run 51 passed Lua 5.1 syntax validation and the pure-Lua regression suite on commit `1ee83045c89ef0e7a6d1e686a5191cac64533071`.
- That run includes the scan recovery, exact numeric map-ID filtering, and explicit Search.lua syntax-command changes.
- A later change caps crowded map tooltips. That latest head must receive a fresh CI run before the branch can be called fully green.
- No actual WoW client test was performed during this review.

## Recommendation

Keep PR #2 open. Do not merge it as production-ready solely on the basis of the current automated test suite. First obtain a fresh green CI result for the latest head, then complete the target-client test matrix. Address any reproducible runtime defects before beginning Phase 3.
