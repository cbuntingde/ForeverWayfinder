# Phase 0 baseline — Forever Wayfinder

**Baseline source:** `main` before the Phase 0/1 implementation branch  
**Declared client interface:** `16001` (from `ForeverWayfinder.toc`)  
**Addon version at baseline:** `1.0.0`

This document records facts visible in the repository. It does not claim unverified dependency-version compatibility.

## Runtime and dependencies

| Component | Baseline contract | Status |
|---|---|---|
| WoW client | TOC declares Interface 16001; addon uses the modern `C_Map` API and `C_Timer.NewTicker`. | Verified 2026-11-11: installed client runs a modern FrameXML; the addon has loaded and saved variables on it. |
| QuestieDB | Required TOC dependency; checks `LibQuestieDB.RequireContract(4)`; expects `NpcDB`, `ObjectDB`, `LibQuestieDB.Enum.npcFlags`, and `LibQuestieDB.Support.Get("ZoneDB")`. | Contract verified against installed QuestieDB Forever 1.0.14 (contract 4, Classic rules). |
| HandyNotes | Required TOC dependency; expects `HandyNotes.RegisterPluginDB` and optionally calls `HandyNotes.UpdatePluginMap`. | Contract verified against installed HandyNotes v1.6.32 (TOC lists interface 16001). |
| TomTom | Optional TOC dependency; checks `TomTom.AddWaypoint`. | Contract verified against installed TomTom v4.4.1-release; accessed only through `Waypoints.lua`. |

## Load order

The original TOC loads:

1. `Core.lua`
2. `ZoneMap.lua`
3. `Data.lua`
4. `Pins.lua`
5. `UI.lua`
6. `Minimap.lua`

The Phase 1 branch inserts `Classification.lua` immediately after `Core.lua`, before modules that call its pure helpers.

## Saved variables and preferences

- Global saved-variable name: `ForeverWayfinderDB`.
- Existing top-level preferences: `enabled`, `showWorldMap`, `showMinimap`, `showOnContinent`, `factionFilter`, `pinScale`, `minimapAngle`, `hideMinimapButton`, and `uiPosition`.
- Category preference table: `categories`.
- Display defaults: master enabled, world map enabled, minimap enabled, continent pins disabled, faction filter enabled, pin scale 1.0, minimap angle 220 degrees, minimap button visible.
- Category defaults enabled: vendor, repair, innkeeper, mailbox, auctioneer, banker, flight, stable, class trainer, profession trainer, portal trainer, other trainer, and spirit healer.
- Category defaults disabled: weapon master, battle pet trainer, battlemaster, barber, transmogrifier, and tabard designer.
- All 19 category keys and display defaults are defined in `Core.lua`.
- Reset preserves `uiPosition` and `minimapAngle` by design.

## Public user entry points

- Slash commands: `/fw`, `/foreverwayfinder`; subcommands `on`, `off`, `refresh`, `reset`, and `status`.
- Minimap button: left-click opens settings, right-click toggles minimap pins, drag changes its angle.
- HandyNotes plugin key: `ForeverWayfinder`.
- HandyNotes handler callbacks: `GetNodes2`, `OnEnter`, `OnLeave`, and `OnClick`.
- Right-click pin action: optional TomTom waypoint.

## Index and map data flow

- NPC fields read through QuestieDB: `name`, `subName`, `friendlyToFaction`, `npcFlags`, and `spawns`.
- Object data is currently filtered to names containing `mailbox` or `mail box`; object spawns are indexed as mailbox points.
- Area IDs are translated to UI map IDs using QuestieDB ZoneDB support data.
- Coordinates are normalized from 0–100 percentages into the addon's packed integer coordinate key.
- Multiple records at one coordinate are represented by a single pin; the baseline tooltip displays up to five entries plus a count of additional entries.

## Normalized record contract

The indexer produces two compact record shapes. Search and pins consume only these.

**Entry** (one per distinct NPC/object ID at a coordinate; shared by reference across nodes):

| Field | Type | Meaning |
|---|---|---|
| `id` | positive integer | QuestieDB NPC or object ID. |
| `name` | string | Display name (validated non-empty). |
| `sub` | string or nil | Display subname; objects use `"Mailbox"`. |
| `searchName` | string | Index-time normalized `name` for case-insensitive search. |
| `searchSub` | string | Index-time normalized `sub`. |
| `categories` | set of category keys | Union of the record's categories across all spawns. |
| `vendorIcon` | string or nil | Inferred vendor-stock icon; a hint, not inventory proof. |

**Node** (one per map ID + packed coordinate):

| Field | Type | Meaning |
|---|---|---|
| `x`, `y` | number 0–1 | Normalized map coordinates (rounded to 4 decimal places). |
| `cats` | set of category keys | Union of member entry categories. |
| `entries` | array of entries | Every distinct ID at this coordinate; deduplicated by `id`. |
| `vendorIcon` | string or nil | First vendor-stock icon contributed by a member. |

Map IDs are positive integers; coordinates are validated to 0–100 before packing.
The packed coordinate key is `floor(x*10000+0.5)*10000 + floor(y*10000+0.5)`.

## Compatibility gaps not resolved by repository evidence

- Exact minimum QuestieDB, HandyNotes, and TomTom releases.
- Whether Interface 16001 covers every intended Forever client update.
- In-game behavior on the live target client, including map hierarchy and minimap callback semantics.
- Whether QuestieDB provides a non-source-string ZoneDB mapping accessor in the target release.
- Whether `GetAllIds()` enumeration cost is significant on representative data. The addon now measures this cost; a streaming/iterator API should only be adopted if the dependency actually exposes one.

Do not expand the supported client or dependency matrix until each combination is tested in game.
