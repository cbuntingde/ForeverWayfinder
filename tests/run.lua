-- Headless tests for the WoW-free modules. Run with:
--   lua5.1 tests/run.lua
-- from the addon directory.

local failures, checks = 0, 0

local function check(name, ok, detail)
    checks = checks + 1
    if not ok then
        failures = failures + 1
        print(("FAIL %s%s"):format(name, detail and (" - " .. tostring(detail)) or ""))
    end
end

local function eq(name, actual, expected)
    check(name, actual == expected, ("expected %s, got %s"):format(tostring(expected), tostring(actual)))
end

local function loadModule(path)
    local chunk, err = loadfile(path)
    assert(chunk, err)
    return chunk
end

local ns = {}
loadModule("Classification.lua")("ForeverWayfinder", ns)
loadModule("Location.lua")("ForeverWayfinder", ns)

-- Classification ------------------------------------------------------------

eq("IsPositiveInteger(3)", ns.ClassificationIsPositiveInteger(3), true)
eq("IsPositiveInteger(0)", ns.ClassificationIsPositiveInteger(0), false)
eq("IsPositiveInteger(1.5)", ns.ClassificationIsPositiveInteger(1.5), false)
eq("IsPositiveInteger(nan)", ns.ClassificationIsPositiveInteger(0 / 0), false)
eq("IsNonNegativeInteger(0)", ns.ClassificationIsNonNegativeInteger(0), true)
eq("IsNonNegativeInteger(-1)", ns.ClassificationIsNonNegativeInteger(-1), false)

eq("TrainerCategory(warrior)", ns.ClassificationTrainerCategory("Warrior Trainer"), "classTrainer")
eq("TrainerCategory(alchemy)", ns.ClassificationTrainerCategory("Alchemy Trainer"), "profession")
eq("TrainerCategory(bear)", ns.ClassificationTrainerCategory("Bear Trainer"), "pet")
eq("TrainerCategory(riding)", ns.ClassificationTrainerCategory("Riding Trainer"), "profession")
eq("TrainerCategory(combat)", ns.ClassificationTrainerCategory("Combat Trainer"), "otherTrainer")
eq("TrainerCategory(portal)", ns.ClassificationTrainerCategory("Portal Trainer"), "portal")

local bits = {
    VENDOR = 1, REPAIR = 2, INNKEEPER = 4, AUCTIONEER = 8, BANKER = 16,
    FLIGHT_MASTER = 32, STABLEMASTER = 64, SPIRIT_HEALER = 128,
    BATTLEMASTER = 256, BARBER = 512, TRANSMOGRIFIER = 1024,
    TABARD_DESIGNER = 2048, TRAINER = 4096,
}
local function band(flags, flag) return math.floor(flags / flag) % 2 end
local vendor = ns.ClassificationCategoriesForNpc(1, "Trade Supplies", bits, band)
eq("vendor category", vendor.vendor, true)
eq("vendor repair flag", vendor.repair, nil)
local demon = ns.ClassificationCategoriesForNpc(0, "Demon Trainer", bits, band)
eq("title-only trainer", demon.otherTrainer, true)
eq("non-numeric flags", next(ns.ClassificationCategoriesForNpc("x", "Vendor", bits, band)), nil)

-- Cursor mapping ------------------------------------------------------------

local cx, cy = ns.Location:MapCursorPosition(500, 300, 100, 700, 800, 400)
eq("cursor x", cx, 50)
eq("cursor y", cy, 100)
eq("cursor outside", ns.Location:MapCursorPosition(50, 300, 100, 700, 800, 400), nil)
eq("cursor zero width", ns.Location:MapCursorPosition(500, 300, 100, 700, 0, 400), nil)
eq("cursor nil input", ns.Location:MapCursorPosition(nil, 300, 100, 700, 800, 400), nil)

-- Distance formatting -------------------------------------------------------

eq("FormatDistance(0)", ns.Location:FormatDistance(0), "0 yd")
eq("FormatDistance(42.6)", ns.Location:FormatDistance(42.6), "42 yd")
eq("FormatDistance(999)", ns.Location:FormatDistance(999), "999 yd")
eq("FormatDistance(1234)", ns.Location:FormatDistance(1234), "1.2k yd")
eq("FormatDistance(nil)", ns.Location:FormatDistance(nil), nil)
eq("FormatDistance(-1)", ns.Location:FormatDistance(-1), nil)

-- Location ------------------------------------------------------------------

local function vector(x, y)
    return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
end

local state = { mapID = 1415, zone = "Elwynn Forest", sub = "", pos = vector(0.25, 0.5) }
C_Map = {
    GetBestMapForUnit = function() return state.mapID end,
    GetMapInfo = function() return { name = "Elwynn Forest" } end,
    GetPlayerMapPosition = function() return state.pos end,
}
GetZoneText = function() return state.zone end
GetSubZoneText = function() return state.sub end

local info = ns.Location:Read()
eq("Read mapID", info.mapID, 1415)
eq("Read zone", info.zoneName, "Elwynn Forest")
eq("Read x", info.x, 25)
eq("Read y", info.y, 50)
eq("Format", ns.Location:Format(info), "You  ·  Elwynn Forest  25.0, 50.0")
eq("Format compact", ns.Location:Format(info, true), "Elwynn Forest  25.0, 50.0")
eq("Format no coords", ns.Location:Format(info, false, false), "You  ·  Elwynn Forest")

state.sub = "Goldshire"
eq("Format subzone", ns.Location:Format(ns.Location:Read(), true), "Goldshire  25.0, 50.0")
state.sub = "A subzone name that is far too long to show"

state.pos = { x = 0.1, y = 0.2 }
local plain = ns.Location:Read()
eq("plain x fallback", plain.x, 10)
eq("plain y fallback", plain.y, 20)

state.pos = vector(0, 0)
local origin = ns.Location:Read()
eq("(0,0) rejected x", origin.x, nil)
eq("(0,0) rejected y", origin.y, nil)
check("Format coords fallback", ns.Location:Format(origin):find("Elwynn Forest", 1, true) ~= nil)

C_Map.GetPlayerMapPosition = function() error("boom") end
local broken = ns.Location:Read()
eq("pcall failure x", broken.x, nil)
state.pos = vector(0.5, 0.5)

C_Map = nil
GetZoneText = function() return nil end
GetSubZoneText = function() return nil end
eq("no C_Map format", ns.Location:Format(ns.Location:Read(), true), "Location unavailable")

print(("%d checks, %d failures"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
