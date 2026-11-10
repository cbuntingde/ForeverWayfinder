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

print("Forever Wayfinder tests passed.")
