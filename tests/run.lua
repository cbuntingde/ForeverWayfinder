-- Run from the repository root: lua tests/run.lua (Lua 5.1 compatible).
local ns = {}
local chunk, err = loadfile("Classification.lua")
assert(chunk, err)
chunk("ForeverWayfinder", ns)
local function eq(actual, expected, label)
    assert(actual == expected, (label or "assertion") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function band(a, b)
    local result, place = 0, 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then result = result + place end
        a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
    end
    return result
end
local bits = { VENDOR=1, REPAIR=2, INNKEEPER=4, AUCTIONEER=8, BANKER=16,
    FLIGHT_MASTER=32, STABLEMASTER=64, SPIRIT_HEALER=128, BATTLEMASTER=256,
    BARBER=512, TRANSMOGRIFIER=1024, TABARD_DESIGNER=2048, TRAINER=4096 }
eq(ns.ClassificationNormalizeText("  Mage\n Trainer "), "mage trainer", "normalize")
eq(ns.ClassificationTrainerCategory("Portal Trainer"), "portal", "portal")
eq(ns.ClassificationTrainerCategory("Battle Pet Trainer"), "pet", "pet")
eq(ns.ClassificationTrainerCategory("Weapon Master"), "weapon", "weapon")
eq(ns.ClassificationTrainerCategory("Master Mage"), "classTrainer", "class")
eq(ns.ClassificationTrainerCategory("Expert Blacksmith"), "profession", "profession")
eq(ns.ClassificationTrainerCategory("Trainer"), "otherTrainer", "fallback")
eq(ns.ClassificationTrainerCategory(nil), "otherTrainer", "missing trainer text")
local cats = ns.ClassificationCategoriesForNpc(bits.VENDOR + bits.REPAIR + bits.TRAINER, "Mage Trainer", bits, band)
eq(cats.vendor, true, "vendor")
eq(cats.repair, true, "repair")
eq(cats.classTrainer, true, "trainer")
eq(cats.profession, nil, "unrelated category")
-- Demon Trainers ship without the TRAINER flag; the title must still classify them.
local demon = ns.ClassificationCategoriesForNpc(bits.VENDOR, "Demon Trainer", bits, band)
eq(demon.vendor, true, "demon trainer keeps vendor")
eq(demon.otherTrainer, true, "demon trainer title fallback")
local plainVendor = ns.ClassificationCategoriesForNpc(bits.VENDOR, "Trade Supplies", bits, band)
eq(plainVendor.otherTrainer, nil, "non-trainer title not promoted")
eq(plainVendor.classTrainer, nil, "non-trainer title not promoted (class)")
local all = ns.ClassificationCategoriesForNpc(bits.INNKEEPER + bits.AUCTIONEER + bits.BANKER
    + bits.FLIGHT_MASTER + bits.STABLEMASTER + bits.SPIRIT_HEALER + bits.BATTLEMASTER
    + bits.BARBER + bits.TRANSMOGRIFIER + bits.TABARD_DESIGNER, "", bits, band)
for _, key in ipairs({ "innkeeper", "auctioneer", "banker", "flight", "stable",
    "spirit", "battlemaster", "barber", "transmog", "tabard" }) do eq(all[key], true, key) end
eq(ns.ClassificationIsPositiveInteger(3), true, "valid ID")
eq(ns.ClassificationIsPositiveInteger(2.5), false, "fractional ID")
eq(ns.ClassificationIsPositiveInteger(0), false, "zero ID")
eq(ns.ClassificationIsFiniteNumber(0 / 0), false, "NaN")
eq(ns.ClassificationIsCoordinate(100), true, "upper coordinate")
eq(ns.ClassificationIsCoordinate(-1), false, "negative coordinate")
eq(ns.ClassificationIsCoordinate(101), false, "out of range coordinate")
eq(ns.ClassificationIsCoordinate(math.huge), false, "infinite coordinate")
local dataChunk, dataError = loadfile("Data.lua")
assert(dataChunk, dataError)
dataChunk("ForeverWayfinder", ns)
ns.band = band
ns.db = { factionFilter = false }
ns.areaToMap = { [1] = 100 }
ns:ResetIndex()
local entryA = { id = 10, name = "Vendor A" }
local entryB = { id = 11, name = "Vendor B" }
eq(ns:AddSpawn(100, 50, 25, { vendor = true }, entryA), true, "first spawn")
eq(ns:AddSpawn(100, 50, 25, { repair = true }, entryB), true, "shared spawn")
local shared = ns.index[100][50002500]
eq(#shared.entries, 2, "shared-location entries")
eq(shared.cats.vendor, true, "first category merged")
eq(shared.cats.repair, true, "second category merged")
eq(ns:AddSpawn(100, 101, 50, { vendor = true }, { id = 12 }), false, "invalid coordinate rejected")
eq(ns.stat.invalidSpawns, 1, "invalid spawn counted")

-- NPC and object IDs are separate namespaces: the same numeric ID at one coordinate must not collide.
eq(ns:AddSpawn(100, 1, 1, { vendor = true }, { id = 7, kind = "npc", name = "Same ID NPC" }), true, "npc with id 7 added")
eq(ns:AddSpawn(100, 1, 1, { mailbox = true }, { id = 7, kind = "object", name = "Same ID Box" }), true, "object with id 7 kept")
eq(ns:AddSpawn(100, 1, 1, { vendor = true }, { id = 7, kind = "npc", name = "Duplicate" }), nil, "same kind and id de-duplicated")
eq(#ns.index[100][1000100].entries, 2, "de-duplication is scoped to kind")

for index = 1, 6 do
    eq(ns:AddSpawn(100, 50, 25, { vendor = true }, {
        id = 20 + index, name = "Extra NPC " .. index,
    }), true, "additional shared NPC " .. index)
end
eq(#shared.entries, 8, "all shared-location NPCs retained")

local fakeBits = { VENDOR=1, REPAIR=2, INNKEEPER=4, AUCTIONEER=8, BANKER=16,
    FLIGHT_MASTER=32, STABLEMASTER=64, SPIRIT_HEALER=128, BATTLEMASTER=256,
    BARBER=512, TRANSMOGRIFIER=1024, TABARD_DESIGNER=2048, TRAINER=4096 }
NpcDB = {
    GetAll = function(id)
        if id == 102 then return { "Malformed NPC", nil, nil, "not-a-flag" } end
        return { "Mage NPC", "Mage Trainer", "A", fakeBits.TRAINER }
    end,
    GetRaw = function() return "Mage Trainer" end,
    Get = function() return { [1] = { { 40, 60 } } } end,
}
ns:IndexNpc(101, fakeBits)
eq(ns.stat.npcs, 1, "NPC indexed")
eq(ns.index[100][40006000].cats.classTrainer, true, "NPC trainer category indexed")
ns:IndexNpc(102, fakeBits)
eq(ns.stat.invalidRecords, 1, "malformed NPC flags counted")

local zoneChunk, zoneError = loadfile("ZoneMap.lua")
assert(zoneChunk, zoneError)
local zoneNS = {}
zoneChunk("ForeverWayfinder", zoneNS)
local decoded = zoneNS.DecodeZoneMapTable("return { [1] = 2, [3] = 4 }", "fixture")
eq(decoded[1], 2, "decoded map")
local validated, validationError, invalidCount = zoneNS.ValidateZoneMapMapping({ [1] = 2, ["bad"] = 3, [4] = 0 }, "test")
eq(validated[1], 2, "validated mapping")
eq(invalidCount, 2, "invalid mapping entries counted")
local unsafe = zoneNS.DecodeZoneMapTable("return setmetatable({}, {})", "unsafe")
eq(unsafe, nil, "sandbox blocks globals")
local malformed, malformedError = zoneNS.DecodeZoneMapTable("not valid lua", "malformed")
eq(malformed, nil, "malformed source")
assert(type(malformedError) == "string", "decode error surfaced")

-- Search covers all shared-location NPCs and applies deterministic text/category/zone filters.
local searchChunk, searchError = loadfile("Search.lua")
assert(searchChunk, searchError)
searchChunk("ForeverWayfinder", ns)
ns.categoryByKey = {
    vendor = { name = "Vendors" },
    repair = { name = "Repair" },
    classTrainer = { name = "Class Trainers" },
}
ns.ready = true
ns.index = {
    [100] = {
        [50002500] = shared,
    },
    [200] = {
        [25007500] = {
            x = 0.25, y = 0.75, cats = { classTrainer = true },
            entries = {
                { id = 20, name = "Ari", sub = "Mage Trainer", categories = { classTrainer = true } },
            },
        },
    },
}
C_Map = { GetMapInfo = function(id) return { name = id == 100 and "Stormwind City" or "Ironforge" } end }
local allShared = ns:SearchEntries("", "", "Stormwind")
eq(#allShared, 8, "all shared NPCs searchable")
local byCategory = ns:SearchEntries("", "repair", "")
eq(#byCategory, 1, "category filter")
eq(byCategory[1].entry.name, "Vendor B", "category result identity")
local byZone = ns:SearchEntries("ari", "", "ironforge")
eq(#byZone, 1, "case-insensitive zone and name filter")
eq(byZone[1].mapID, 200, "zone map ID")
local exactMapID = ns:SearchEntries("", "", "100")
eq(#exactMapID, 8, "numeric zone filter matches exact map ID")
local partialMapID = ns:SearchEntries("", "", "10")
eq(#partialMapID, 0, "numeric zone filter does not substring-match other map IDs")
local limited = ns:SearchEntries("vendor", "", "", 1)
eq(#limited, 1, "search result limit")

------------------------------------------------------------------------------------------
-- Faction filtering
------------------------------------------------------------------------------------------
ns.db = { factionFilter = true }
ns.myFaction = "Alliance"
eq(ns:FactionAllowed("A"), true, "Alliance player sees Alliance NPC")
eq(ns:FactionAllowed("H"), false, "Alliance player does not see Horde NPC")
eq(ns:FactionAllowed("AH"), true, "both-faction NPC always visible")
eq(ns:FactionAllowed(nil), true, "unknown faction NPC always visible")
ns.myFaction = "Horde"
eq(ns:FactionAllowed("A"), false, "Horde player does not see Alliance NPC")
eq(ns:FactionAllowed("H"), true, "Horde player sees Horde NPC")
ns.myFaction = nil
eq(ns:FactionAllowed("H"), true, "unknown player faction disables filtering")
ns.myFaction = "Alliance"
ns.db.factionFilter = false
eq(ns:FactionAllowed("H"), true, "filter disabled shows enemy services")

------------------------------------------------------------------------------------------
-- Zone map: override precedence and fail-closed diagnostics
------------------------------------------------------------------------------------------
_G.LibQuestieDB = { Support = { Get = function()
    return { private = {
        areaIdToUiMapId = "return { [1] = 100, [2] = 200 }",
        areaIdToUiMapIdOverride = "return { [2] = 201 }",
    } }
end } }
local buildOk = zoneNS:BuildZoneMap()
eq(buildOk, true, "zone map builds")
eq(zoneNS.areaToMap[1], 100, "base mapping kept")
eq(zoneNS.areaToMap[2], 201, "override takes precedence")
eq(zoneNS.mapToArea[201], 2, "reverse mapping follows override")
LibQuestieDB.Support.Get = function()
    return { private = {
        areaIdToUiMapId = "return { [1] = 100 }",
        areaIdToUiMapIdOverride = "return {",
    } }
end
local overrideOk, overrideMessage = zoneNS:BuildZoneMap()
eq(overrideOk, false, "malformed override fails closed")
assert(overrideMessage:find("override", 1, true), "override error reported separately")
LibQuestieDB.Support.Get = function() return nil end
eq(zoneNS:BuildZoneMap(), false, "missing zone support data fails closed")
_G.LibQuestieDB = nil

------------------------------------------------------------------------------------------
-- Waypoint provider
------------------------------------------------------------------------------------------
local wpChunk, wpError = loadfile("Waypoints.lua")
assert(wpChunk, wpError)
wpChunk("ForeverWayfinder", ns)
TomTom = nil
eq(ns.Waypoints:IsAvailable(), false, "provider absent detected")
local wpOk, wpReason = ns.Waypoints:Set(100, 0.5, 0.5, "Test")
eq(wpOk, false, "set without provider fails")
assert(type(wpReason) == "string" and wpReason ~= "", "missing provider reason surfaced")
local added, removed
TomTom = {
    AddWaypoint = function(_, m, x, y, opts)
        added = { m = m, x = x, y = y, opts = opts }
        return { m, x, y }
    end,
    RemoveWaypoint = function(_, uid) removed = uid end,
}
eq(ns.Waypoints:IsAvailable(), true, "provider present detected")
wpOk = ns.Waypoints:Set(100, 0.5, 0.25, "Vendor A")
eq(wpOk, true, "waypoint set")
eq(added.m, 100, "waypoint map ID")
eq(added.x, 0.5, "waypoint normalized x")
eq(added.y, 0.25, "waypoint normalized y")
eq(added.opts.from, "ForeverWayfinder", "waypoint source marker")
eq(ns.Waypoints:Set(100, 1.5, 0.5), false, "out-of-range coordinate rejected")
eq(ns.Waypoints:Set(0, 0.5, 0.5), false, "invalid map ID rejected")
eq(ns.Waypoints:Set(100, 0 / 0, 0.5), false, "NaN coordinate rejected")
eq(added.m, 100, "invalid coordinates never reach the provider")
wpOk = ns.Waypoints:ClearLast()
eq(wpOk, true, "clear last waypoint")
eq(removed[1], 100, "clear removes the created waypoint")
eq(ns.Waypoints:ClearLast(), false, "clear with no waypoint reports honestly")
TomTom.AddWaypoint = function() error("provider exploded") end
wpOk, wpReason = ns.Waypoints:Set(100, 0.5, 0.5, "Test")
eq(wpOk, false, "provider error contained")
assert(type(wpReason) == "string", "provider error reason surfaced")

------------------------------------------------------------------------------------------
-- Saved variables: validation, clamping, unknown keys, reset scope
------------------------------------------------------------------------------------------
CreateFrame = function()
    return { RegisterEvent = function() end, UnregisterEvent = function() end, SetScript = function() end }
end
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
local coreNS = {}
local coreChunk, coreError = loadfile("Core.lua")
assert(coreChunk, coreError)
coreChunk("ForeverWayfinder", coreNS)
ForeverWayfinderDB = {
    enabled = "yes", pinScale = 99, minimapAngle = 0 / 0, schemaVersion = "x",
    categories = { vendor = "nope", repair = false },
    uiPosition = { point = "BAD", x = 1, y = 2 },
    customKey = "keep",
}
coreNS:InitDB()
local sv = coreNS.db
eq(sv.enabled, true, "invalid boolean restored to default")
eq(sv.pinScale, 1.5, "pin scale clamped to maximum")
eq(sv.minimapAngle, 220, "NaN angle restored to default")
eq(sv.schemaVersion, 1, "invalid schema version reset")
eq(sv.categories.vendor, true, "invalid category restored to default")
eq(sv.categories.repair, false, "valid category preserved")
eq(sv.uiPosition, nil, "invalid anchor dropped")
eq(sv.customKey, "keep", "unknown user key preserved")
ForeverWayfinderDB = {
    pinScale = 0.1, minimapAngle = 400,
    uiPosition = { point = "CENTER", x = 10, y = 20 },
}
coreNS:InitDB()
eq(coreNS.db.pinScale, 0.5, "pin scale clamped to minimum")
eq(coreNS.db.minimapAngle, 40, "angle wrapped into range")
eq(coreNS.db.uiPosition.relativePoint, "CENTER", "missing relativePoint defaulted")
coreNS.db.categories.vendor = false
coreNS:ResetSettings()
eq(coreNS.db.categories.vendor, true, "reset restores category defaults")
eq(coreNS.db.uiPosition.x, 10, "reset preserves frame position")
eq(coreNS.db.minimapAngle, 40, "reset preserves minimap angle")
eq(coreNS.db.schemaVersion, 1, "reset keeps schema version")
eq(coreNS.db.customKey, nil, "reset clears unknown keys by design")

------------------------------------------------------------------------------------------
-- Scan lifecycle: completion, isolation, idempotent rebuild, restart, failure recovery
------------------------------------------------------------------------------------------
local now = 0
GetTime = function() return now end
local tickerFn, tickerCancelled
C_Timer = { NewTicker = function(_, fn)
    tickerFn, tickerCancelled = fn, false
    return { Cancel = function() tickerCancelled = true end }
end }
UnitFactionGroup = function() return "Alliance" end
ns.Print = function() end
ns.Refresh = function() end
ns.initialized = true
ns.blocked = nil
ns.db = { factionFilter = false }
ns.areaToMap = { [1] = 100 }

local lifecycleNpcs = {
    [1] = { name = "Alpha Vendor", sub = "General Goods", friendly = "AH", flags = 4, spawns = { [1] = { { 10, 20 } } } },
    [2] = { name = "Beta Trainer", sub = "Mage Trainer", friendly = "AH", flags = 16, spawns = { [1] = { { 30, 40 } } } },
    [3] = { name = "Bad Flags", sub = "", friendly = "AH", flags = "not-a-number", spawns = {} },
}
NpcDB = {
    GetAllIds = function() return { 1, 2, 3, 4 } end,
    GetAll = function(id)
        if id == 4 then error("record read exploded") end
        local d = lifecycleNpcs[id]
        return { d.name, d.sub, d.friendly, d.flags }
    end,
    GetRaw = function(id) return lifecycleNpcs[id].sub end,
    Get = function(id) return lifecycleNpcs[id].spawns end,
}
ObjectDB = {
    GetAllIds = function() return { 50 } end,
    GetRaw = function() return "Mailbox" end,
    Get = function(_, key)
        if key == "name" then return "Mailbox" end
        return { [1] = { { 10, 20 } } }
    end,
}
local function pumpScan()
    local guard = 0
    while tickerFn and not tickerCancelled and guard < 1000 do
        now = now + 0.05
        tickerFn()
        guard = guard + 1
    end
end
eq(ns:StartScan(), true, "scan starts")
pumpScan()
eq(ns.ready, true, "scan completes")
eq(ns.lastScan.state, "complete", "complete state recorded")
eq(tickerCancelled, true, "ticker cancelled on completion")
eq(ns.stat.npcs, 2, "valid NPCs indexed")
eq(ns.stat.objects, 1, "mailbox object indexed")
eq(ns.stat.invalidRecords, 1, "malformed record isolated")
eq(ns.stat.npcErrors, 1, "record error isolated")
eq(#ns.lastScan.errors, 1, "error sample retained")
local sharedNode = ns.index[100][10002000]
eq(#sharedNode.entries, 2, "vendor and mailbox share a node")
eq(sharedNode.entries[1].searchName, "alpha vendor", "search text precomputed at index time")

local firstNodes, firstNpcs = ns.stat.nodes, ns.stat.npcs
eq(ns:StartScan(), true, "rebuild starts")
pumpScan()
eq(ns.stat.nodes, firstNodes, "idempotent rebuild node count")
eq(ns.stat.npcs, firstNpcs, "idempotent rebuild NPC count")
eq(#ns.index[100][10002000].entries, 2, "idempotent rebuild does not duplicate entries")

local manyNpcs = {}
local manyIds = {}
for i = 1, 500 do
    manyIds[i] = i
    manyNpcs[i] = { name = "NPC " .. i, sub = "", friendly = "AH", flags = 4, spawns = { [1] = { { i % 100, i % 50 } } } }
end
NpcDB.GetAllIds = function() return manyIds end
NpcDB.GetAll = function(id)
    local d = manyNpcs[id]
    return { d.name, d.sub, d.friendly, d.flags }
end
NpcDB.GetRaw = function(id) return manyNpcs[id].sub end
NpcDB.Get = function(id) return manyNpcs[id].spawns end
eq(ns:StartScan(), true, "large scan starts")
now = now + 0.05
tickerFn()
eq(ns.ready, false, "large scan still in progress")
local staleFn = tickerFn
eq(ns:StartScan(), true, "restart during indexing")
staleFn()
eq(ns.stat.npcs, 0, "stale generation cannot mutate the new index")
pumpScan()
eq(ns.ready, true, "restarted scan completes")
eq(ns.stat.npcs, 500, "restarted scan indexes every NPC")

NpcDB.GetAllIds = function() error("enumeration exploded") end
eq(ns:StartScan(), false, "enumeration failure reported")
eq(ns.scan, nil, "no stale scan object after failure")
eq(ns.lastScan.state, "failed", "failed state recorded")
eq(ns.ready, false, "index not ready after failure")
NpcDB.GetAllIds = function() return manyIds end
eq(ns:StartScan(), true, "recovery scan starts")
pumpScan()
eq(ns.ready, true, "recovery scan completes")

------------------------------------------------------------------------------------------
-- Search against the real indexer output (precomputed text path)
------------------------------------------------------------------------------------------
local realResults = ns:SearchEntries("alpha", "", "")
eq(#realResults, 0, "large dataset has no alpha vendor")
local npcOne = ns:SearchEntries("NPC 1", "", "")
eq(#npcOne, 100, "large result set capped")
eq(npcOne[1].sortName, "npc 1", "deterministic ordering first row")
eq(npcOne[2].sortName, "npc 10", "deterministic ordering second row")
ns.ready = false
local notReady, notReadyReason = ns:SearchEntries("a", "", "")
eq(#notReady, 0, "no results when index not ready")
eq(notReadyReason, "index-not-ready", "index-not-ready reason")
ns.ready = true
local emptyResults, emptyReason = ns:SearchEntries("", "", "")
eq(#emptyResults, 0, "empty query returns no results")
eq(emptyReason, "query-required", "query-required reason")

------------------------------------------------------------------------------------------
-- World-map node iterator: a node whose categories are all disabled (no icon) must keep
-- scanning the current map, not advance past it. Regression for the bug that dropped every
-- pin after the first skipped node on a map.
------------------------------------------------------------------------------------------
local pinsChunk, pinsError = loadfile("Pins.lua")
assert(pinsChunk, pinsError)
pinsChunk("ForeverWayfinder", coreNS)

-- Force the categories this fixture uses so the skipped-node scenario holds regardless of
-- the shipped defaults: the three hidden categories off, the three icon categories on.
local pinCats = {}
for key, value in pairs(coreNS.defaultCategories) do pinCats[key] = value end
pinCats.battlemaster, pinCats.barber, pinCats.transmog = false, false, false
pinCats.vendor, pinCats.repair, pinCats.classTrainer = true, true, true
coreNS.db = { pinScale = 1.25, categories = pinCats }

-- Positional constructors populate the array part, so next() walks coords in a fixed
-- ascending order: a disabled node comes first, which is what tripped the old fall-through.
local function node(cats) return { cats = cats } end
coreNS.index = {
    [100] = {
        node({ battlemaster = true }),   -- 1: disabled -> skipped
        node({ vendor = true }),         -- 2: icon
        node({ barber = true }),         -- 3: disabled -> skipped
        node({ repair = true }),         -- 4: icon
        node({ classTrainer = true }),   -- 5: icon
    },
    [200] = {
        node({ transmog = true }),       -- 1: disabled -> skipped
        node({ vendor = true }),         -- 2: icon
    },
    [300] = {
        node({ battlemaster = true }),   -- whole map disabled
        node({ barber = true }),
    },
    [400] = {
        node({ vendor = true }),         -- icon after an all-disabled map
    },
}

local function collect(maps)
    local rows = {}
    for coord, mapID, icon, scale, alpha in coreNS:MakeNodeIterator(maps) do
        rows[#rows + 1] = { coord = coord, mapID = mapID, icon = icon, scale = scale, alpha = alpha }
    end
    return rows
end

local single = collect({ 100 })
eq(#single, 3, "iterator yields every icon node past skipped nodes")
eq(single[1].coord, 2, "first icon node survives a leading skipped node")
eq(single[2].coord, 4, "icon node between two skipped nodes")
eq(single[3].coord, 5, "trailing icon node")
eq(single[1].icon, "Interface\\Icons\\INV_Misc_Bag_10", "vendor default icon")
eq(single[2].icon, "Interface\\Icons\\Trade_BlackSmithing", "repair icon")
eq(single[3].icon, "Interface\\Minimap\\tracking\\class", "class trainer icon")
eq(single[1].scale, 1.25, "pin scale propagated")
eq(single[1].alpha, 1, "pin alpha")
eq(single[1].mapID, 100, "yielded map ID")

local multi = collect({ 100, 200 })
eq(#multi, 4, "iterator traverses every map")
eq(multi[4].mapID, 200, "second map reached after skipped nodes")
eq(multi[4].coord, 2, "second map icon node")

local allSkipped = collect({ 300, 400 })
eq(#allSkipped, 1, "all-disabled map does not terminate traversal")
eq(allSkipped[1].mapID, 400, "map after an all-disabled map reached")

eq(#collect({}), 0, "empty map list yields nothing")

------------------------------------------------------------------------------------------
-- Packaging: every file the TOC loads must exist, so a renamed or forgotten module fails CI.
------------------------------------------------------------------------------------------
local toc = assert(io.open("ForeverWayfinder.toc", "r"))
local listed = 0
for line in toc:lines() do
    local file = line:match("^%s*(.-)%s*$")
    if file ~= "" and file:sub(1, 2) ~= "##" then
        listed = listed + 1
        local handle = io.open(file, "r")
        assert(handle, "TOC lists a missing file: " .. file)
        handle:close()
    end
end
toc:close()
assert(listed > 0, "TOC lists no files")

print("Forever Wayfinder tests passed.")
