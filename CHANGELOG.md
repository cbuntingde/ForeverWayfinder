# Changelog

## Unreleased

- Fix the search window's missing initial anchor so it opens centered and visibly.
- Ensure the search window is layered above the settings panel and remains above it when reopened.
- Add mocked WoW-frame regression coverage for search-window creation, visibility, focus, close, and reopen.
- Make CI install Lua 5.1 from the runner's package manager and run syntax, core regression, and search UI lifecycle checks.
- Document release readiness, feature boundaries, data limitations, and required in-game validation.

## 1.2.2

NPC/object identity fix, font fallback, and minimap drag reliability.

- Fix NPCs and objects sharing a numeric ID colliding at the same coordinates: entries are now de-duplicated on kind plus ID, so a mailbox is no longer dropped when an NPC reuses its ID and vice versa.
- Add a font fallback for the journal theme: when the MORPHEUS font is unavailable the text falls back to the standard UI font instead of failing to render.
- Fix minimap-button dragging: the button now registers both mouse-down and mouse-up clicks so drags are distinguished from clicks reliably.
- Remove unused color, media, and index-statistics bookkeeping left over from earlier revisions.
- Add regression coverage for NPC/object ID collisions and a packaging check that every file listed in the TOC exists.

## 1.2.1

World-map pin rendering fix, enable-all default categories, and journal theme correction.

- Fix world-map pins vanishing whenever any category was disabled: the node iterator stopped at the first pin whose categories were all hidden, dropping every later pin on that map. All enabled services now render regardless of which categories are hidden. Verified against Stormwind (179 nodes) and Elwynn data.
- Enable all 19 service categories by default so a fresh install shows every pin; uncheck any category to prune. Existing saved preferences are preserved on update.
- Fix the journal window border and corners drawing as missing-art squares: the theme now paints solid leather-and-gold borders and corners instead of relying on dialog textures the Forever client does not ship.
- Add `/fw map`, a copyable diagnostic that reports the render gates, HandyNotes registration, the current map's node and icon counts, a per-category breakdown of shown versus skipped pins, and icon-path validity, and refreshes the open world map.
- Add regression coverage for the world-map node iterator: skipped nodes must not terminate traversal, multiple maps are walked in order, and an all-disabled map is stepped over.

## 1.2.0

Illustrated-journal interface and a trainer-classification correctness fix.

- Redesign the settings and search windows as an illustrated journal: leather cover with gold filigree border and corners, parchment pages, serif headings, maroon-and-gold buttons, and cream inputs. Both windows share one theme so they read as a single book.
- Settings are laid out on a parchment page with grouped Services / Trainers / Other / Display sections, a pin-scale slider, and a footer status band with progress and actions.
- Search results render on parchment with serif NPC names and muted detail lines; filters use cream inputs with gold captions.
- Fix trainers that ship without the TRAINER npcFlag (notably warlock Demon Trainers): an explicit "trainer" title now classifies them, so they appear as trainer pins instead of vendor-only. Verified against QuestieDB Forever data: four additional genuine trainers, no false positives.
- Add regression coverage for the title-based trainer fallback and a guard against promoting non-trainer vendors.
## 1.1.0

NPC discovery and search improvements.

- Retain every NPC entry at shared map coordinates; no five-entry truncation.
- Add case-insensitive search by NPC name or sub-name.
- Add category and zone/map-name or map-ID filters.
- Add a dedicated scrollable search window, slash command, and settings shortcut.
- Left-click a result to select its map when the client exposes that API; right-click to set a TomTom waypoint when available.
- Add regression coverage for shared-location retention, filtering, and result limits.
- Centralize TomTom integration behind a waypoint provider with coordinate validation, and add `/fw clear` to remove the last Forever Wayfinder waypoint.
- Search result map selection now follows the client's proven open-world-map pattern (Questie-compatible), with a combat guard and a clear failure message.
- Precompute normalized search text at index time and cache map names so broad queries stay cheap; sort keys are computed once per result.
- The search window reports the disabled reason when a dependency is missing instead of claiming the index is still loading.
- Settings reset preserves the schema version; the copyable status report uses the guarded backdrop template.
- Expand the regression suite: faction filtering, scan lifecycle (restart, cancellation, idempotent rebuild, enumeration-failure recovery), saved-variable validation/reset, waypoint provider, and zone-override precedence.
- Verify dependency contracts against the installed QuestieDB Forever 1.0.14, HandyNotes v1.6.32, and TomTom v4.4.1-release.

## 1.0.0

Initial release.

- World map and minimap pins for vendors, trainers and service NPCs, built from QuestieDB data through HandyNotes.
- Vendor pins show an icon for what the vendor sells instead of the generic bag icon, and sales stock takes priority over the incidental repair flag on weaponsmiths and armor merchants.
- Category toggles for 19 NPC roles, grouped into Services, Trainers and Other points of interest.
- Display toggles for world map pins, minimap pins, continent pins and the faction filter, plus a master on/off switch.
- Pin scale slider and a draggable minimap button.
- Optional TomTom waypoints from a right-click on any pin.
- Slash commands: `/fw`, `/fw on|off`, `/fw refresh`, `/fw reset`, `/fw status`.


## 1.0.1

Reliability and development-foundation release.

- Extracted NPC trainer/category classification and data validation into a pure Lua module.
- Added defensive validation for NPC/object IDs, flags, map IDs and spawn coordinates.
- Isolated malformed records so one bad record does not abort the scan.
- Added scan generation checks, cancellation state, protected per-record indexing and enumeration error handling.
- Hardened QuestieDB zone-map decoding with a restricted chunk environment and validated mapping entries.
- Expanded `/fw status` diagnostics and added a standalone Lua regression harness.
- Preserved existing categories, settings, slash commands and map integrations.
