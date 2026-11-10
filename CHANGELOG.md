# Changelog

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
