# Forever Wayfinder

Find vendors, trainers and service NPCs on the world map and the minimap in World of Warcraft: Forever.

Forever Wayfinder reads its location data from **QuestieDB** at runtime and displays it through **HandyNotes**. No NPC data is bundled with the addon; the pins are built once per login from the QuestieDB you already have installed.

![Forever Wayfinder settings panel](docs/screenshot-settings.png)

![Forever Wayfinder search window](docs/screenshot-search.png)

## Features

- Illustrated journal interface: parchment pages, leather-and-gold book chrome, serif headings and maroon-and-gold controls across the settings and search windows.
- Vendors drawn with an icon for what they actually sell: food and drink, trade and profession supplies, reagents, poisons, ammunition, weapons, armor, bags, tabards and mounts.
- Innkeepers, repair vendors, auctioneers, bankers, flight masters, stable masters, mailboxes, class, profession, portal, battle-pet and other trainers, weapon masters, spirit healers, battlemasters, barbers, transmogrifiers and tabard designers.
- All 19 categories are enabled by default, so a fresh install shows every service; uncheck any in settings to hide those pins.
- World map and minimap pins, each switchable.
- Optional continent-level pins that roll every zone up onto the continent map.
- Optional faction filter that hides services belonging to the opposite faction.
- Pin scale slider.
- HandyNotes plugin toggle, so the pins can also be switched from the HandyNotes options.
- Optional TomTom waypoints: right-click any pin.
- Draggable round minimap button.
- Search every indexed NPC by name or sub-name, with category and zone/map filters. Search uses case-insensitive substring matching (not fuzzy matching).

## Requirements

- World of Warcraft: Forever (Interface 16001)
- [QuestieDB](https://www.curseforge.com/wow/addons/questiedb) (required)
- [HandyNotes](https://www.curseforge.com/wow/addons/handynotes) (required)
- [TomTom](https://www.curseforge.com/wow/addons/tomtom) (optional, for waypoints)

Dependency contracts are verified against QuestieDB Forever 1.0.14 (contract 4), HandyNotes v1.6.32, and TomTom v4.4.1-release.

## Installation

1. Close the game.
2. Extract the `ForeverWayfinder` folder into `World of Warcraft\_forever_\Interface\AddOns\`.
3. Start the game and make sure QuestieDB and HandyNotes are enabled.

Pins are indexed after you log in. The first run takes a moment; `/fw status` shows progress.

## Usage

- `/fw` or `/foreverwayfinder` opens or closes the settings panel.
- `/fw on` / `/fw off` enables or disables all pins.
- `/fw refresh` rebuilds the NPC index.
- `/fw reset` restores default settings.
- `/fw search` opens NPC search; filter by name, category, zone name, or map ID.
- `/fw clear` removes the last waypoint set by Forever Wayfinder (requires TomTom).
- `/fw status` prints index statistics, scan timings, invalid data counts, unavailable coordinates, and unmapped areas.
- `/fw map` diagnoses map pins for the current map and refreshes the open world map.
- Left-click the minimap button to open the panel, right-click it to toggle minimap pins, drag it to move it around the minimap.
- Hover a pin for the NPC names and coordinates. Right-click it to set a TomTom waypoint.
- In search results, left-click to open/select the result's map when supported by the client; right-click to set a TomTom waypoint.

## Notes

- The zone-to-map mapping is decoded from QuestieDB's own support data, so new QuestieDB zone mappings are picked up without an addon update.
- If the panel says the addon is disabled, the reason is printed in chat: a missing dependency, an outdated QuestieDB contract, or unreadable zone data.

## License

MIT. See `LICENSE`.


## Diagnostics and development tests

- `/fw status` reports index totals, invalid records/spawns, unavailable positions, unmapped areas, scan timing and record errors.
- `/fw map` reports the render gates, HandyNotes registration, the current map's node and icon counts, a per-category shown-versus-skipped breakdown, and icon-path validity.
- Malformed QuestieDB records are skipped without aborting the full index build.
- Zone-map payloads are decoded in a restricted environment and validated before use.
- Pure Lua regression tests are in `tests/run.lua`. From the repository root, run `lua tests/run.lua` with a Lua 5.1-compatible interpreter.
- The standalone tests do not replace in-game testing against the declared client and supported QuestieDB/HandyNotes versions.

## Troubleshooting

- If the addon is disabled, read the reason printed in chat and check that QuestieDB and HandyNotes are enabled and current.
- If pins are missing in a zone, run `/fw status` and review the unavailable-position and unmapped-area samples. The addon does not invent coordinates for records that QuestieDB cannot place.
- If search does not open, try `/fw search` after `/reload`. Report whether the settings button, slash command, or both fail, along with any Lua error stack.
- To report a data or display issue, include the client build, QuestieDB and HandyNotes versions, character faction, affected map/zone, and the complete `/fw status` output.

## Release validation

See [the release-readiness audit](docs/RELEASE_READINESS_AUDIT.md) for the feature inventory, known limitations, automated checks, and required in-game release checklist. A passing Lua test suite does not replace testing against the target WoW Forever client and supported dependency versions.
