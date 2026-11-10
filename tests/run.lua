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
local zoneChunk, zoneError = loadfile("ZoneMap.lua")
assert(zoneChunk, zoneError)
local zoneNS = {}
zoneChunk("ForeverWayfinder", zoneNS)
local decoded = zoneNS.DecodeZoneMapTable("return { [1] = 2, [3] = 4 }", "fixture")
eq(decoded[1], 2, "decoded map")
local unsafe = zoneNS.DecodeZoneMapTable("return setmetatable({}, {})", "unsafe")
eq(unsafe, nil, "sandbox blocks globals")
local malformed, malformedError = zoneNS.DecodeZoneMapTable("not valid lua", "malformed")
eq(malformed, nil, "malformed source")
assert(type(malformedError) == "string", "decode error surfaced")
print("Forever Wayfinder tests passed.")
