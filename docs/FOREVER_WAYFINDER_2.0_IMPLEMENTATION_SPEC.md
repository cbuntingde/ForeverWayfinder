# Forever Wayfinder 2.0 — Implementation Specification

**Status:** Proposed implementation plan  
**Target:** Forever Wayfinder 2.0  
**Baseline reviewed:** Repository state on `main` at the time this specification was prepared  
**Implementation tracking:** Phase 0 completed; Phase 1 foundation implemented, validation pending CI/in-game checks  
**Primary objective:** Evolve Forever Wayfinder from a map-pin locator into a dependable, searchable NPC and point-of-interest discovery and navigation addon.

---

## 1. Executive summary

Forever Wayfinder already has a useful foundation: QuestieDB-backed NPC data, HandyNotes map/minimap pins, category toggles, faction filtering, optional continent aggregation, and optional TomTom waypoint integration.

Version 2.0 should improve the quality and usefulness of that foundation rather than replace it. The priorities are:

1. Make indexing, classification, and map resolution observable and resilient.
2. Make it easy to find a particular NPC or service instead of relying exclusively on map browsing.
3. Improve pin and tooltip behavior when several NPCs share one location.
4. Add practical navigation actions while keeping TomTom optional.
5. Improve settings usability, persistence, and discoverability.
6. Establish repeatable tests and release checks for supported game clients and dependency versions.

This document is an implementation plan, not authorization to remove existing features or perform a wholesale rewrite. Existing behavior must remain available unless a change is explicitly approved and covered by migration and regression tests.

## 2. Product goals and non-goals

### 2.1 Goals

- Provide a reliable catalog of supported NPC services and selected world objects.
- Let players search and filter that catalog by name, service, profession, faction, and zone where the available data supports those fields.
- Make map pins understandable, readable, and actionable.
- Offer direct waypoint actions through optional navigation integrations.
- Keep indexing and map rendering responsive on lower-end systems.
- Keep the addon compatible with its declared World of Warcraft client/API target and the supported QuestieDB and HandyNotes versions.
- Make failures diagnosable without flooding the player's chat frame.
- Preserve existing settings and user preferences across upgrades.

### 2.2 Non-goals

- Do not reimplement QuestieDB, HandyNotes, or TomTom.
- Do not promise route planning, pathfinding, or shortest-path navigation unless a supported provider actually supplies it.
- Do not assume QuestieDB contains vendor inventory, exact stock, prices, or every NPC in the game.
- Do not add a network service, telemetry, or external account dependency.
- Do not add gameplay automation, bot behavior, or actions that interact with protected UI in unsupported ways.
- Do not remove current categories or existing map/minimap behavior merely to simplify the code.

## 3. Current baseline and audit notes

The current implementation is organized around the root-level Lua files `Core.lua`, `Data.lua`, `ZoneMap.lua`, `Pins.lua`, `UI.lua`, and `Minimap.lua`, loaded through `ForeverWayfinder.toc`.

### 3.1 Existing capabilities to preserve

- QuestieDB NPC data indexing.
- HandyNotes integration for world map and minimap pins.
- Service and trainer categories, including vendor, repair, innkeeper, auctioneer, banker, flight master, stable master, spirit healer, battlemaster, barber, transmog, tabard, class/profession/other trainers, portal, pet, and weapon-related services where supported by the current data.
- Mailbox object discovery based on available object data.
- Faction filtering.
- Optional continent-level aggregation.
- Pin scaling and minimap display controls.
- Draggable/hideable minimap button behavior.
- Optional TomTom waypoint integration.
- Existing slash commands and settings defaults.

### 3.2 Findings to validate during implementation

These are audit observations and risk areas, not all confirmed user-facing defects. Reproduce and document each issue before changing behavior.

| Area | Observed design/risk | Required action |
|---|---|---|
| Classification | Trainer classification includes English text/keyword matching. | Centralize rules, add tests, and avoid assuming names are localized or complete. |
| Vendor subtype | Icon selection can use NPC subname/keyword heuristics. | Treat subtype as a hint, not proof of inventory. Expose uncertainty honestly. |
| Shared coordinates | Multiple NPCs can be merged into one pin; tooltip display is capped. | Provide a way to inspect all entries at a shared location. |
| Map conversion | Zone map data is decoded from QuestieDB-provided Lua source strings using `loadstring`/`load` when present. | Investigate a native decoded-table API; validate input and fail closed with diagnostics if source decoding remains necessary. |
| Map traversal | Parent/descendant traversal uses depth limits. | Verify limits against supported map hierarchies and report skipped/unresolved map IDs. |
| Index startup | ID enumeration occurs before the time-sliced scan. | Measure startup cost and move expensive enumeration into bounded work if necessary. |
| Index lifecycle | Index rebuild and cancellation behavior need explicit lifecycle guarantees. | Define cancellation, restart, completion, and error states. |
| Diagnostics | Existing counters provide basic scan visibility. | Add structured counts, timing, and reason codes without noisy chat output. |
| Settings UI | Fixed-size layout may become difficult as controls grow. | Add scrollable sections and clear grouping before adding many settings. |
| Test automation | No test suite or CI workflow was identified in the inspected repository snapshot. | Recheck the full tree and establish a lightweight validation workflow. |

### 3.3 Baseline verification checklist

Before implementation begins, record:

- Exact addon interface/client version declared in the TOC.
- Supported game client(s) and whether Classic Era, progression Classic, or another client is in scope.
- QuestieDB versions tested and the public data/API contract used.
- HandyNotes versions tested and the plugin contract used.
- TomTom versions tested, including behavior when absent.
- Current saved-variable schema and real upgrade behavior from the latest release.
- Current icon asset provenance and license/redistribution requirements.
- Whether any existing user reports or open issues supersede the observations above.

Do not silently broaden the supported client matrix. Declare support only after runtime testing.

## 4. Version 2.0 functional requirements

Priority labels: **P0** release-critical, **P1** high-value, **P2** optional enhancement.

### 4.1 Data indexing and classification

**P0**
- Separate raw source extraction from classification and presentation.
- Normalize NPC records into a documented internal record shape.
- Validate IDs, names, faction values, flags, map IDs, and coordinates before indexing.
- Reject invalid coordinates and non-finite numeric values.
- Deduplicate repeated spawns without losing distinct NPC identities.
- Ensure one bad record cannot abort the complete scan.
- Make scans idempotent: a completed rebuild produces the same logical index from the same source data and settings.
- Expose scan lifecycle states: idle, enumerating, indexing, complete, cancelled, and failed.
- Add a cancellation/restart path that invalidates stale scheduled work safely.

**P1**
- Centralize classification rules in a dedicated module.
- Use QuestieDB flags and structured metadata as the primary classification signals.
- Keep text matching as a documented fallback only.
- Normalize text matching for case, whitespace, punctuation, and known aliases.
- Keep classification reasons available in debug diagnostics.
- Support multiple categories per NPC without duplicate visible pins.
- Preserve source metadata needed for future filters, while avoiding unnecessary retained data.

**P2**
- Add localized classification dictionaries only when localization data and a maintainable translation process are available.
- Add an optional data-provider adapter for other databases only after a concrete supported provider is identified.

### 4.2 NPC and service search

**P1**
- Add a search interface accessible from the addon settings or a dedicated launcher.
- Search NPC name and subname using case-insensitive matching.
- Filter by one or more service categories.
- Filter by faction when the source data supports reliable faction values.
- Filter by zone/map when map resolution is available.
- Display result name, service/category, zone (if known), and whether the result has a valid map location.
- Selecting a result opens the appropriate map when the client API permits it and highlights or focuses the corresponding pin when supported.
- Show a clear empty state and a clear state when the index is not ready.
- Search must remain responsive with the full indexed dataset.

**P2**
- Add optional vendor subtype filters, but label them as inferred unless inventory data is authoritative.
- Add favorites and recently selected entries.
- Add nearest-NPC sorting only when player position and map coordinate conversion can be performed reliably. Clearly distinguish straight-line map distance from travel distance.

### 4.3 Shared-location discovery and tooltips

**P0**
- A location containing multiple NPCs must not hide the existence of additional NPCs.
- Tooltips must show the total count and a useful sample.
- Ensure tooltip text remains bounded and does not create unbounded UI work.

**P1**
- Add a detail panel or expandable list for every NPC at a shared coordinate.
- Show each NPC's name and all known service categories.
- Provide per-NPC waypoint actions when the underlying coordinate is shared.
- Ensure mouse interaction remains compatible with HandyNotes' expected click/tooltip lifecycle.

**P2**
- Add optional compact/expanded tooltip modes.
- Add a configurable tooltip detail level if real usage demonstrates a need.

### 4.4 Navigation and waypoint actions

**P1**
- Centralize waypoint integration behind a provider interface.
- Keep TomTom optional and detect it safely at runtime.
- Provide a waypoint action from search results and detailed pin entries.
- Provide a clear-waypoint action only when the active provider supports it.
- If no provider exists, explain the missing optional dependency in the UI without throwing Lua errors.
- Do not claim to calculate a route when only a waypoint is being set.

**P2**
- Add a nearest-service action.
- Add favorites/recent waypoint shortcuts.
- Evaluate flight-master and transport discovery as catalog categories only where reliable data exists; do not imply automated flight routing.

### 4.5 Map and pin presentation

**P0**
- Preserve current HandyNotes registration and map/minimap visibility controls.
- Validate all coordinates and map IDs before rendering.
- Ensure toggling categories updates pins without requiring a full client reload.
- Ensure continent aggregation does not duplicate pins or omit valid child-map pins.

**P1**
- Add a legend or category key accessible from settings.
- Define a documented icon-priority policy for NPCs with multiple categories.
- Keep icon scale bounded to a safe minimum and maximum.
- Add optional visibility controls for dense maps if profiling demonstrates a need.
- Add map traversal diagnostics for unresolved and truncated hierarchies.

**P2**
- Evaluate pin clustering or aggregation for dense locations.
- Consider instance/interior map support after map hierarchy behavior is tested.
- Consider distance labels only if coordinate semantics are consistent across supported maps.

### 4.6 Settings, persistence, and UX

**P0**
- Preserve existing setting names and defaults unless a migration is implemented.
- Validate saved values before use; restore safe defaults for invalid values.
- Ensure settings changes update the relevant UI/pin state immediately.
- Keep all existing category toggles and display toggles.
- Provide a reset action with clear confirmation or a safe reset scope.

**P1**
- Group settings into sections: Categories, Map, Minimap, Search, Navigation, and Diagnostics.
- Make the panel scrollable and usable at supported UI scales/resolutions.
- Add enable-all/disable-all controls where useful.
- Show category counts only when counts can be computed accurately.
- Add a concise status section: dependency state, index state, indexed NPCs, unresolved map records, and last scan result.
- Keep debug output opt-in.

**P2**
- Add favorites and recent-entry management.
- Add localization support for all user-facing strings.
- Add configurable key bindings only if they fit the addon/client's supported binding API.

## 5. Internal architecture

A modular structure is recommended, but the current root-level files should not be moved wholesale before the TOC load order, public globals, saved variables, and HandyNotes callbacks are mapped.

Proposed target layout:

```text
ForeverWayfinder/
├── ForeverWayfinder.toc
├── Core/
│   ├── Bootstrap.lua
│   ├── Dependencies.lua
│   ├── Database.lua
│   ├── Events.lua
│   └── Diagnostics.lua
├── Data/
│   ├── NPCIndexer.lua
│   ├── ObjectIndexer.lua
│   ├── Classification.lua
│   ├── Record.lua
│   └── ZoneMap.lua
├── Map/
│   ├── Pins.lua
│   ├── Tooltips.lua
│   ├── WorldMap.lua
│   ├── Minimap.lua
│   └── Clustering.lua
├── Navigation/
│   ├── Waypoints.lua
│   └── Providers/
│       └── TomTom.lua
├── Features/
│   ├── Search.lua
│   ├── Filters.lua
│   ├── Favorites.lua
│   └── RecentlyVisited.lua
├── UI/
│   ├── Settings.lua
│   ├── SearchFrame.lua
│   └── Widgets.lua
├── Tests/
│   ├── Classification.lua
│   ├── ZoneMap.lua
│   ├── Indexing.lua
│   └── Fixtures.lua
├── README.md
├── CHANGELOG.md
└── docs/
    └── FOREVER_WAYFINDER_2.0_IMPLEMENTATION_SPEC.md
```

### 5.1 Module contracts

- **Bootstrap:** creates the addon namespace, initializes modules in TOC order, and owns startup sequencing.
- **Dependencies:** checks required and optional dependencies and exposes capability flags; it must not scatter dependency checks across feature code.
- **Database:** owns saved-variable defaults, validation, versioning, and migrations.
- **Diagnostics:** owns structured counters, timings, warnings, and opt-in debug output.
- **Data providers/indexers:** read source data and produce normalized records; they do not create UI frames.
- **Classification:** pure functions mapping normalized source fields to categories and classification reasons.
- **ZoneMap:** owns area/map translation and hierarchy traversal; it must expose explicit success/failure results.
- **Map/Pins:** adapts indexed records to HandyNotes callbacks and pin rendering.
- **Navigation providers:** implement a small common interface and isolate optional integrations.
- **Features:** implement search, filters, favorites, and recents without depending on frame implementation details.
- **UI:** renders controls and calls feature APIs; it should not own source-data parsing or indexing logic.

### 5.2 Normalized record model

Define and document a stable internal record shape before implementing search. Suggested fields:

- `npcId`: source NPC identifier.
- `name`, `subName`: normalized display strings, possibly absent.
- `faction`: normalized known faction value or unknown.
- `flags`: validated source flags.
- `categories`: set/list of category identifiers.
- `classificationReasons`: optional debug-only reasons.
- `spawns`: one or more validated map/coordinate records.
- `source`: provider identifier.
- `vendorSubtype`: optional inferred value with an explicit confidence/source marker.

Do not retain duplicate copies of large source tables. Use compact records and shared references where practical.

### 5.3 Saved-variable schema

- Introduce an explicit schema version.
- Keep the current saved-variable global name unless a migration is justified.
- Add migrations that are deterministic and safe to rerun.
- Never discard unknown user keys during migration unless there is a documented reason.
- Validate booleans, numbers, enum values, and nested tables.
- Clamp numeric settings such as pin scale to documented bounds.
- Separate user preferences from rebuildable index/cache data.
- Do not persist source data that can be regenerated cheaply from QuestieDB.

## 6. Performance, reliability, and security requirements

### 6.1 Performance

- Profile the complete startup path, including ID enumeration, not just the scheduled scan loop.
- Keep indexing time-sliced with a configurable internal budget and a hard step cap.
- Avoid expensive full-index rebuilds for ordinary settings changes.
- Cache map hierarchy results with explicit invalidation when source map data changes or the index resets.
- Avoid creating frames or allocating large temporary tables inside per-pin iteration.
- Keep search result updates debounced or otherwise bounded.
- Record scan duration, record counts, skipped-record counts, and peak work per tick in debug mode.

**Initial performance acceptance targets** (to be validated on the supported client and representative hardware):
- No single indexing slice should exceed the configured budget by more than a small documented scheduling tolerance under normal conditions.
- Search should return an initial result set without a perceptible UI stall on a representative full dataset.
- Turning a category off should not trigger a complete source-data re-index.
- Repeated opening/closing of settings and search must not cause unbounded frame or memory growth.

Record actual measurements in release notes or a benchmark document. Do not claim performance targets are met without measurements.

### 6.2 Reliability

- Every scheduled callback must check that its scan/session generation is still current.
- Every optional API call must be guarded by capability detection.
- Every external database record must be validated before use.
- One malformed NPC, object, or map entry must not terminate the full scan.
- Errors should include module and operation context in debug diagnostics.
- The addon must degrade gracefully when QuestieDB, HandyNotes, or TomTom is absent or incompatible, according to whether each dependency is required or optional.
- Avoid repeated chat warnings; show actionable status once and provide detailed diagnostics on demand.

### 6.3 Dynamic Lua source handling

The current map-data path evaluates source strings with `loadstring`/`load` where available. This deserves specific treatment:

1. Check whether QuestieDB exposes the same mapping as an already-decoded Lua table or stable accessor.
2. Prefer the decoded API.
3. If source-string decoding is unavoidable, document the trusted source, validate the returned type and table contents, wrap compilation/execution in protected calls, and reject unexpected values.
4. Never evaluate strings from user input or arbitrary external sources.
5. Report invalid base and override data separately; do not silently mask a bad override.
6. Add tests for malformed source, non-table return values, missing mappings, and valid overrides.

## 7. Compatibility policy

- The TOC interface number is the source of truth for the declared client target.
- Maintain a written compatibility matrix for the supported WoW client/API version, QuestieDB, HandyNotes, and optional TomTom.
- Use only APIs available in the declared client target.
- Guard APIs that differ across supported clients with small compatibility adapters, not scattered version checks.
- Do not infer support for Retail, Classic Era, Hardcore, seasonal, or private-server clients without explicit test coverage.
- Keep optional integrations optional.
- Test the addon with each supported dependency combination, including missing optional dependencies.
- Document installation and dependency requirements clearly.

## 8. Testing strategy

The addon should have a lightweight test harness that can run outside the game for pure Lua logic, plus an in-game manual test matrix for WoW API and HandyNotes behavior.

### 8.1 Automated/pure-Lua tests

At minimum:

- Classification: every category, overlapping flags, missing names, localized/unknown strings, false-positive keyword cases, and fallback precedence.
- Faction: Alliance, Horde, neutral/unknown, missing faction, and filter enabled/disabled.
- Coordinate normalization: valid boundaries, duplicate spawns, invalid values, NaN/infinity, and out-of-range values.
- Indexing: empty source, malformed record, duplicate NPC ID, multiple spawns, multiple NPCs at one coordinate, cancellation, restart, and idempotent rebuild.
- Zone map: direct map, parent/child maps, missing mapping, override precedence, cycles, depth boundary, malformed data, and cache invalidation.
- Search: case-insensitive matching, empty query, category combinations, missing map locations, and large result sets.
- Saved variables: first install, valid prior schema, migration, corrupted settings, unknown keys, and reset behavior.
- Waypoint adapter: provider absent, provider present, invalid coordinate, and provider error.

### 8.2 In-game manual tests

- Fresh install with required dependencies.
- Fresh install without each optional dependency.
- Upgrade from the previous release with existing saved variables.
- World map pins and minimap pins enabled/disabled independently.
- All categories individually enabled/disabled and overlapping categories.
- Faction filtering for both factions and neutral/unknown NPCs.
- Continent-level aggregation on/off.
- Dense town with multiple NPCs at identical or nearby coordinates.
- Search selecting a result from the current zone and a different zone.
- TomTom present/absent and waypoint set/clear behavior.
- Minimap button drag, angle persistence, hide/show behavior.
- UI scale and supported screen resolutions.
- Reload, logout/login, and repeated settings changes.
- Performance observation on a representative large QuestieDB dataset.

### 8.3 Test harness rules

- Tests must not require a live game client for pure classification, indexing, and map conversion logic.
- Stub only the APIs needed by the unit under test.
- Keep fixtures small, explicit, and representative.
- Do not make tests pass by weakening assertions or silently skipping unsupported cases.
- Document how to run tests on Windows and Linux where tooling permits.
- If no Lua runtime is available in CI, add syntax/static checks first and document the manual test requirement; do not pretend this is equivalent to runtime testing.

## 9. Phased implementation roadmap

Implement in small, reviewable changes. Each phase must pass its acceptance criteria before the next phase builds on it.

### Phase 0 — Baseline and contracts (P0)

**Deliverables**
- Confirm client/dependency support matrix.
- Document current TOC load order, namespace, public callbacks, saved variables, slash commands, and settings.
- Capture current behavior in a regression checklist.
- Establish test harness and lint/syntax validation where practical.
- Define normalized record and category identifiers.

**Acceptance criteria**
- Existing behavior is documented and reproducible.
- No existing category or setting is removed.
- A developer can identify required vs optional dependencies and supported client APIs.
- Tests can execute at least the pure classification and normalization logic.

### Phase 1 — Data correctness and resilience (P0)

**Deliverables**
- Extract classification into a testable module.
- Add input validation and malformed-record isolation.
- Improve scan lifecycle, cancellation, restart, and generation checks.
- Harden ZoneMap conversion and diagnostics.
- Profile synchronous ID enumeration and bound it if measurement warrants.
- Add scan diagnostics and map-resolution counters.

**Acceptance criteria**
- Malformed source records do not abort the complete scan.
- Rebuilds are idempotent.
- Cancellation/restart cannot allow stale callbacks to mutate the current index.
- Map failures are visible in diagnostics with reason codes.
- Classification and map tests cover all listed edge cases.

### Phase 2 — Multi-NPC locations and search (P1)

**Deliverables**
- Shared-location detail list.
- Search UI and search/filter service.
- Search result map navigation/highlight where supported.
- Search empty/loading/index-not-ready states.
- Category and zone filters.

**Acceptance criteria**
- Every NPC represented by a merged location remains discoverable.
- Search results are deterministic and correctly filtered.
- Selecting a result cannot crash when its map location is missing.
- Search remains responsive on the representative dataset.
- Existing map pin behavior remains intact.

### Phase 3 — Navigation provider and UX (P1)

**Deliverables**
- Common waypoint-provider interface.
- TomTom adapter.
- Waypoint actions from search and pin details.
- Improved settings grouping, scrolling, status, and bulk category controls.
- Saved-variable schema versioning and migration if required.

**Acceptance criteria**
- TomTom absence does not cause errors.
- A waypoint is only set for validated coordinates and supported map context.
- UI communicates whether a waypoint was set or why it could not be.
- Existing saved settings survive upgrade.
- All existing slash commands continue to work.

### Phase 4 — Map quality and optional discovery features (P2)

**Deliverables, selected based on measured value**
- Pin density improvements/clustering.
- Favorites and recent entries.
- Nearest-service sorting.
- Additional transport/instance points of interest when data supports them.
- Optional vendor subtype filters with confidence labeling.

**Acceptance criteria**
- Each feature has a defined source of truth and documented limitations.
- No inferred data is presented as verified fact.
- Dense maps remain usable and rendering stays within measured performance budgets.
- Every new preference has a safe default and migration coverage.

### Phase 5 — Release hardening (P0)

**Deliverables**
- Full regression pass.
- Compatibility matrix updated with tested versions.
- README installation, dependencies, features, limitations, and troubleshooting updated.
- Changelog entry and version/TOC review.
- Packaging validation and clean-install test.
- Release checklist and known-issues list.

**Acceptance criteria**
- No known P0 defects remain.
- No unreviewed debug code or noisy logging remains enabled by default.
- All supported dependency combinations have been tested or clearly marked unverified.
- Upgrade and fresh-install paths pass.
- Release artifacts contain only intended addon files and documentation.

## 10. Definition of done

A 2.0 feature is complete only when:

- Requirements and edge cases are documented.
- Code follows the module contracts and supported client API.
- Errors and optional dependency absence are handled safely.
- Automated tests cover pure logic and failure cases.
- In-game behavior has been tested where game APIs are involved.
- Existing behavior has regression coverage.
- Saved-variable changes are versioned and migrated.
- Documentation and changelog are updated.
- Performance impact is measured for indexing, search, and pin rendering where relevant.
- No placeholders, dead controls, fake data, or silently swallowed errors are shipped.

## 11. Implementation rules for coding agents

1. Read this specification and the complete current repository before changing code.
2. Treat the current implementation as the compatibility baseline.
3. Do not perform a wholesale rewrite or file move as the first step.
4. Do not remove existing categories, settings, slash commands, map behavior, or optional integrations without explicit justification and approval.
5. Do not invent QuestieDB fields, WoW APIs, HandyNotes callbacks, or TomTom APIs. Verify them against the actual installed/dependency source and declared client target.
6. Prefer small, cohesive changes with tests over large unreviewable patches.
7. Keep pure data/classification logic separate from WoW frames and UI callbacks.
8. Keep optional integrations behind adapters and capability checks.
9. Validate all source data and saved-variable values at boundaries.
10. Avoid global namespace pollution; use the addon's namespace consistently.
11. Do not add dependencies unless their value and compatibility are documented.
12. Do not add network access, telemetry, or external services.
13. Do not mark a phase complete until its acceptance criteria are demonstrably met.
14. Update this specification only when implementation evidence changes a requirement; record the reason.
15. Report exactly what was changed, what was tested, what was not tested, and any remaining risks.

## 12. Suggested implementation issue breakdown

Create one issue or task per independently reviewable unit:

- [ ] Document supported client and dependency matrix.
- [x] Map current public API, TOC load order, saved variables, and settings.
- [x] Add pure-Lua test harness and representative fixtures.
- [ ] Define normalized NPC/spawn record contract.
- [x] Extract and test classification rules.
- [ ] Add robust coordinate/faction/flag validation.
- [x] Add scan lifecycle, cancellation, and generation safety.
- [x] Harden ZoneMap decoding, validation, and diagnostics.
- [ ] Profile and bound startup enumeration if necessary.
- [ ] Add complete shared-location NPC detail display.
- [ ] Implement search service and category/zone filters.
- [ ] Implement search UI and map selection behavior.
- [ ] Add waypoint provider abstraction and TomTom adapter.
- [ ] Improve settings layout and status diagnostics.
- [ ] Version and migrate saved-variable schema.
- [ ] Evaluate and implement selected map density improvements.
- [ ] Complete compatibility, regression, and release validation.
- [ ] Update README, changelog, and release packaging.

## 13. Open decisions requiring confirmation

Do not guess these during implementation:

1. Which WoW client branch/version is the official 2.0 target?
2. Is the intended audience official Blizzard clients only, or are specific private-server client builds also in scope?
3. Which QuestieDB and HandyNotes versions are the minimum supported versions?
4. Should search be a standalone window, a settings tab, or both?
5. Should favorites/recent entries be account-wide or character-specific?
6. Is localization in scope for 2.0, and which languages are required?
7. Are additional POI types desired only when QuestieDB provides reliable records, or should curated static data be considered?

Until these are answered, implement the architecture so the decisions remain configurable, but do not claim support or ship speculative data.

---

## 14. Recommended 2.0 delivery order

The recommended order is **Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 5**, with Phase 4 selected based on test results and user value. This sequence prioritizes correctness before adding more pins and controls, then adds search and navigation on top of a stable data model.

**The core 2.0 promise:** Find the service or NPC you need, understand exactly where the data says it is, and navigate to it without sacrificing the reliability and simplicity of the existing addon.
