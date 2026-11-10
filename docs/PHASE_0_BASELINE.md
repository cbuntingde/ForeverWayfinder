# Phase 0 baseline — Forever Wayfinder

**Baseline source:** `main` before the Phase 0/1 implementation branch  
**Declared client interface:** `16001` (from `ForeverWayfinder.toc`)  
**Addon version at baseline:** `1.0.0`

This document records facts visible in the repository. It does not claim unverified dependency-version compatibility.

## Runtime and dependencies

| Component | Baseline contract | Status |
|---|---|---|
| WoW client | TOC declares Interface 16001; addon uses the modern `C_Map` API and `C_Timer.NewTicker`. | Declared target; in-game verification still required. |
| QuestieDB | Required TOC dependency; checks `LibQuestieDB.RequireContract(4)`; expects `NpcDB`, `ObjectDB`, `LibQuestieDB.Enum.npcFlags`, and `LibQuestieDB.Support.Get("ZoneDB")`. | API contract is explicit; minimum addon release is not pinned. |
| HandyNotes | Required TOC dependency; expects `HandyNotes.RegisterPluginDB` and optionally calls `HandyNotes.UpdatePluginMap`. | API feature-detected; minimum addon release is not pinned. |
| TomTom | Optional TOC dependency; checks `TomTom.AddWaypoint`. | Optional integration; no minimum version is pinned. |

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

## Compatibility gaps not resolved by repository evidence

- Exact minimum QuestieDB, HandyNotes, and TomTom releases.
- Whether Interface 16001 covers every intended Forever client update.
- In-game behavior on the live target client, including map hierarchy and minimap callback semantics.
- Whether QuestieDB provides a non-source-string ZoneDB mapping accessor in the target release.
- Whether `GetAllIds()` enumeration cost is significant on representative data. The addon now measures this cost; a streaming/iterator API should only be adopted if the dependency actually exposes one.

Do not expand the supported client or dependency matrix until each combination is tested in game.
