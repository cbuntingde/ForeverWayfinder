local ADDON, ns = ...

-- Pure classification and validation helpers; no WoW UI/API dependencies.

local CLASS_TRAINER_WORDS = {
    "death knight", "warrior", "paladin", "hunter", "rogue", "priest",
    "shaman", "mage", "warlock", "druid", "monk",
}
local PROFESSION_WORDS = {
    "alchemy", "alchemist", "blacksmithing", "blacksmith", "enchanting", "enchanter",
    "engineering", "engineer", "herbalism", "herbalist", "leatherworking", "leatherworker",
    "mining", "miner", "skinning", "skinner", "tailoring", "tailor", "cooking", "cook",
    "fishing", "fisherman", "fisher", "first aid", "riding", "jewelcrafting", "jeweler",
    "inscription", "scribe", "archaeology", "archaeologist",
    "smith", "leather", "armorer", "butcher", "physician", "surgeon", "medic", "pilot",
}
local function Contains(text, needle)
    return text:find(needle, 1, true) ~= nil
end
function ns.ClassificationNormalizeText(value)
    if type(value) ~= "string" then return "" end
    local text = value:lower():gsub("[%c]", " "):gsub("%s+", " ")
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end
function ns.ClassificationIsFiniteNumber(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end
function ns.ClassificationIsPositiveInteger(value)
    return ns.ClassificationIsFiniteNumber(value) and value > 0 and value % 1 == 0
end
function ns.ClassificationIsCoordinate(value)
    return ns.ClassificationIsFiniteNumber(value) and value >= 0 and value <= 100
end
function ns.ClassificationTrainerCategory(subName)
    local sub = ns.ClassificationNormalizeText(subName)
    if sub == "" then return "otherTrainer" end
    if Contains(sub, "portal") then return "portal" end
    if Contains(sub, "battle pet") or Contains(sub, "pet trainer") then return "pet" end
    if Contains(sub, "weapon master") then return "weapon" end
    for i = 1, #CLASS_TRAINER_WORDS do
        if Contains(sub, CLASS_TRAINER_WORDS[i]) then return "classTrainer" end
    end
    for i = 1, #PROFESSION_WORDS do
        if Contains(sub, PROFESSION_WORDS[i]) then return "profession" end
    end
    return "otherTrainer"
end
function ns.ClassificationCategoriesForNpc(flags, subName, bits, band)
    if not ns.ClassificationIsFiniteNumber(flags) or type(bits) ~= "table" or type(band) ~= "function" then
        return {}
    end
    local cats = {}
    local function has(flag)
        return type(flag) == "number" and flag > 0 and band(flags, flag) ~= 0
    end
    if has(bits.VENDOR) then cats.vendor = true end
    if has(bits.REPAIR) then cats.repair = true end
    if has(bits.INNKEEPER) then cats.innkeeper = true end
    if has(bits.AUCTIONEER) then cats.auctioneer = true end
    if has(bits.BANKER) then cats.banker = true end
    if has(bits.FLIGHT_MASTER) then cats.flight = true end
    if has(bits.STABLEMASTER) then cats.stable = true end
    if has(bits.SPIRIT_HEALER) then cats.spirit = true end
    if has(bits.BATTLEMASTER) then cats.battlemaster = true end
    if has(bits.BARBER) then cats.barber = true end
    if has(bits.TRANSMOGRIFIER) then cats.transmog = true end
    if has(bits.TABARD_DESIGNER) then cats.tabard = true end
    if has(bits.TRAINER) then cats[ns.ClassificationTrainerCategory(subName)] = true end
    return cats
end
