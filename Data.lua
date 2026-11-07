local ADDON, ns = ...

local floor = math.floor

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
    -- Profession trainers whose title names the craft rather than the profession.
    "smith", "leather", "armorer", "butcher", "physician", "surgeon", "medic", "pilot",
}

-- Vendor stock icons. The first matching keyword wins, so profession-supply words sit above
-- the retail-type words ("Leatherworking Supplies" before "leather" armor).
local VENDOR_ICONS = {
    reagents = "Interface\\Minimap\\tracking\\reagents",
    poisons = "Interface\\Minimap\\tracking\\poisons",
    ammunition = "Interface\\Minimap\\tracking\\ammunition",
    food = "Interface\\Icons\\INV_Misc_Food_15",
    weapons = "Interface\\Icons\\INV_Sword_04",
    armor = "Interface\\Icons\\INV_Chest_Chain_04",
    bags = "Interface\\Icons\\INV_Misc_Bag_10",
    tabard = "Interface\\Icons\\INV_Shirt_GuildTabard_01",
    mount = "Interface\\Icons\\Ability_Mount_RidingHorse",
    alchemy = "Interface\\Icons\\trade_alchemy",
    blacksmithing = "Interface\\Icons\\trade_blacksmithing",
    enchanting = "Interface\\Icons\\trade_engraving",
    engineering = "Interface\\Icons\\trade_engineering",
    herbalism = "Interface\\Icons\\trade_herbalism",
    leatherworking = "Interface\\Icons\\trade_leatherworking",
    mining = "Interface\\Icons\\trade_mining",
    skinning = "Interface\\Icons\\inv_misc_pelt_wolf_01",
    tailoring = "Interface\\Icons\\trade_tailoring",
    cooking = "Interface\\Icons\\INV_Misc_Food_15",
    fishing = "Interface\\Icons\\trade_fishing",
    jewelcrafting = "Interface\\Icons\\inv_misc_gem_01",
    inscription = "Interface\\Icons\\inv_inscription_tradeskill01",
}

local VENDOR_ICON_KEYWORDS = {
    { "reagent", "reagents" },
    { "poison", "poisons" },
    { "ammunition", "ammunition" },
    { "arrow", "ammunition" },
    { "bullet", "ammunition" },
    { "alchemy", "alchemy" },
    { "blacksmith", "blacksmithing" },
    { "enchant", "enchanting" },
    { "engineering", "engineering" },
    { "herbalism", "herbalism" },
    { "leatherworking", "leatherworking" },
    { "mining", "mining" },
    { "skinning", "skinning" },
    { "tailoring", "tailoring" },
    { "cooking", "cooking" },
    { "fishing", "fishing" },
    { "fisher", "fishing" },
    { "jewel", "jewelcrafting" },
    { "inscription", "inscription" },
    { "potion", "alchemy" },
    { "food", "food" },
    { "drink", "food" },
    { "baker", "food" },
    { "butcher", "food" },
    { "bartender", "food" },
    { "barmaid", "food" },
    { "waitress", "food" },
    { "chef", "food" },
    { "cook", "food" },
    { "meat", "food" },
    { "fruit", "food" },
    { "fish", "food" },
    { "smokywood", "food" },
    { "brew", "food" },
    { "horse", "mount" },
    { "mount", "mount" },
    { "tabard", "tabard" },
    { "bag", "bags" },
    { "bow", "weapons" },
    { "gun", "weapons" },
    { "weapon", "weapons" },
    { "sword", "weapons" },
    { "axe", "weapons" },
    { "mace", "weapons" },
    { "dagger", "weapons" },
    { "blade", "weapons" },
    { "staff", "weapons" },
    { "polearm", "weapons" },
    { "fletch", "weapons" },
    { "armor", "armor" },
    { "armour", "armor" },
    { "armorer", "armor" },
    { "shield", "armor" },
    { "clothier", "armor" },
    { "cloth", "armor" },
    { "leather", "armor" },
    { "mail", "armor" },
    { "plate", "armor" },
    { "robe", "armor" },
}

local function Lower(value)
    return type(value) == "string" and value:lower() or ""
end

local function Find(text, needle)
    return text:find(needle, 1, true) ~= nil
end

local function VendorStockIcon(subName)
    local sub = Lower(subName)
    if sub == "" then return nil end
    for index = 1, #VENDOR_ICON_KEYWORDS do
        local rule = VENDOR_ICON_KEYWORDS[index]
        if Find(sub, rule[1]) then
            return VENDOR_ICONS[rule[2]]
        end
    end
    return nil
end

local function TrainerCategory(subName)
    local sub = Lower(subName)
    if sub == "" then return "otherTrainer" end

    if Find(sub, "portal") then return "portal" end
    if Find(sub, "battle pet") or Find(sub, "pet trainer") then return "pet" end
    if Find(sub, "weapon master") then return "weapon" end

    for index = 1, #CLASS_TRAINER_WORDS do
        if Find(sub, CLASS_TRAINER_WORDS[index]) then
            return "classTrainer"
        end
    end
    for index = 1, #PROFESSION_WORDS do
        if Find(sub, PROFESSION_WORDS[index]) then
            return "profession"
        end
    end

    return "otherTrainer"
end

local function FlagBits()
    local enum = _G.LibQuestieDB and _G.LibQuestieDB.Enum and _G.LibQuestieDB.Enum.npcFlags or {}
    return {
        VENDOR = enum.VENDOR or 4,
        FLIGHT_MASTER = enum.FLIGHT_MASTER or 8,
        TRAINER = enum.TRAINER or 16,
        SPIRIT_HEALER = enum.SPIRIT_HEALER or 32,
        INNKEEPER = enum.INNKEEPER or 128,
        BANKER = enum.BANKER or 256,
        TABARD_DESIGNER = enum.TABARD_DESIGNER or 1024,
        BATTLEMASTER = enum.BATTLEMASTER or 2048,
        AUCTIONEER = enum.AUCTIONEER or 4096,
        STABLEMASTER = enum.STABLEMASTER or 8192,
        REPAIR = enum.REPAIR or 16384,
        BARBER = enum.BARBER or 33554432,
        TRANSMOGRIFIER = enum.TRANSMOGRIFIER or 536870912,
    }
end

local function CategoriesForNpc(flags, subName, bits)
    local cats = {}

    if ns.band(flags, bits.VENDOR) ~= 0 then cats.vendor = true end
    if ns.band(flags, bits.REPAIR) ~= 0 then cats.repair = true end
    if ns.band(flags, bits.INNKEEPER) ~= 0 then cats.innkeeper = true end
    if ns.band(flags, bits.AUCTIONEER) ~= 0 then cats.auctioneer = true end
    if ns.band(flags, bits.BANKER) ~= 0 then cats.banker = true end
    if ns.band(flags, bits.FLIGHT_MASTER) ~= 0 then cats.flight = true end
    if ns.band(flags, bits.STABLEMASTER) ~= 0 then cats.stable = true end
    if ns.band(flags, bits.SPIRIT_HEALER) ~= 0 then cats.spirit = true end
    if ns.band(flags, bits.BATTLEMASTER) ~= 0 then cats.battlemaster = true end
    if ns.band(flags, bits.BARBER) ~= 0 then cats.barber = true end
    if ns.band(flags, bits.TRANSMOGRIFIER) ~= 0 then cats.transmog = true end
    if ns.band(flags, bits.TABARD_DESIGNER) ~= 0 then cats.tabard = true end
    if ns.band(flags, bits.TRAINER) ~= 0 then
        cats[TrainerCategory(subName)] = true
    end

    return cats
end

function ns:FactionAllowed(friendlyToFaction)
    if not self.db.factionFilter or not self.myFaction then
        return true
    end
    if friendlyToFaction == "A" then
        return self.myFaction ~= "Horde"
    end
    if friendlyToFaction == "H" then
        return self.myFaction ~= "Alliance"
    end
    return true
end

--------------------------------------------------------------------------------------------
-- Index construction
--------------------------------------------------------------------------------------------

function ns:ResetIndex()
    self.index = {}
    self.descCache = {}
    self.stat = { nodes = 0, mapCount = 0, npcs = 0, objects = 0, catCount = {} }
    self.ready = false
end

function ns:AddSpawn(mapID, x, y, cats, entry)
    local nx, ny = x / 100, y / 100
    if nx < 0 or nx > 1 or ny < 0 or ny > 1 then return end

    local xi = floor(nx * 10000 + 0.5)
    local yi = floor(ny * 10000 + 0.5)
    if xi > 9999 then xi = 9999 end
    if yi > 9999 then yi = 9999 end

    local coord = xi * 10000 + yi
    local map = self.index[mapID]
    if not map then
        map = {}
        self.index[mapID] = map
    end

    local node = map[coord]
    if not node then
        node = { x = xi / 10000, y = yi / 10000, cats = {}, entries = {}, more = 0 }
        map[coord] = node
        self.stat.nodes = self.stat.nodes + 1
        for key in pairs(cats) do
            node.cats[key] = true
            self.stat.catCount[key] = (self.stat.catCount[key] or 0) + 1
        end
    else
        for key in pairs(cats) do
            if not node.cats[key] then
                node.cats[key] = true
                self.stat.catCount[key] = (self.stat.catCount[key] or 0) + 1
            end
        end
    end

    if cats.vendor and entry.vendorIcon and not node.vendorIcon then
        node.vendorIcon = entry.vendorIcon
    end

    local entries = node.entries
    for index = 1, #entries do
        if entries[index].id == entry.id then return end
    end
    if #entries < 5 then
        entries[#entries + 1] = entry
    else
        node.more = node.more + 1
    end
end

function ns:IndexNpc(id, bits)
    local values = NpcDB.GetAll(id, { "name", "subName", "friendlyToFaction", "npcFlags" })
    if not values then return end

    local name = values[1]
    local subName = values[2]
    local friendly = values[3]
    local flags = values[4] or 0

    if not name or name == "" then return end
    if not self:FactionAllowed(friendly) then return end

    local classificationName = subName
    if ns.band(flags, bits.TRAINER) ~= 0 then
        classificationName = NpcDB.GetRaw(id, "subName") or subName
    end

    local cats = CategoriesForNpc(flags, classificationName, bits)
    if next(cats) == nil then return end

    local spawns = NpcDB.Get(id, "spawns")
    if not spawns then return end

    self.stat.npcs = self.stat.npcs + 1
    local entry = { name = name, sub = subName, id = id }
    if cats.vendor then
        entry.vendorIcon = VendorStockIcon(subName)
    end

    for zoneID, list in pairs(spawns) do
        local mapID = self.areaToMap[zoneID]
        if mapID and mapID > 0 then
            for index = 1, #list do
                local spawn = list[index]
                local x, y = spawn[1], spawn[2]
                if type(x) == "number" and type(y) == "number" then
                    self:AddSpawn(mapID, x, y, cats, entry)
                end
            end
        end
    end
end

function ns:IndexObject(id)
    local rawName = ObjectDB.GetRaw(id, "name")
    local lower = Lower(rawName)
    if not (Find(lower, "mailbox") or Find(lower, "mail box")) then return end

    local spawns = ObjectDB.Get(id, "spawns")
    if not spawns then return end

    local name = ObjectDB.Get(id, "name") or rawName
    self.stat.objects = self.stat.objects + 1

    local entry = { name = name, sub = "Mailbox", id = id }
    local cats = { mailbox = true }

    for zoneID, list in pairs(spawns) do
        local mapID = self.areaToMap[zoneID]
        if mapID and mapID > 0 then
            for index = 1, #list do
                local spawn = list[index]
                local x, y = spawn[1], spawn[2]
                if type(x) == "number" and type(y) == "number" then
                    self:AddSpawn(mapID, x, y, cats, entry)
                end
            end
        end
    end
end

--------------------------------------------------------------------------------------------
-- Scan driver
--------------------------------------------------------------------------------------------

local SCAN_BUDGET = 0.008
local SCAN_MAX_STEPS = 400

function ns:ScanStep()
    local scan = self.scan
    if not scan then return end

    local deadline = GetTime() + SCAN_BUDGET
    local processed = 0

    if scan.phase == "npcs" then
        local ids, pos, total = scan.npcIds, scan.npcPos, #scan.npcIds
        while pos <= total and processed < SCAN_MAX_STEPS and GetTime() < deadline do
            self:IndexNpc(ids[pos], scan.bits)
            pos = pos + 1
            processed = processed + 1
        end
        scan.npcPos = pos
        if pos > total then
            scan.phase = "objects"
        end
    end

    if scan.phase == "objects" then
        local ids, pos, total = scan.objIds, scan.objPos, #scan.objIds
        while pos <= total and processed < SCAN_MAX_STEPS and GetTime() < deadline do
            self:IndexObject(ids[pos])
            pos = pos + 1
            processed = processed + 1
        end
        scan.objPos = pos
        if pos > total then
            scan.phase = "done"
        end
    end

    if scan.phase == "done" then
        if self.scanTicker then
            self.scanTicker:Cancel()
            self.scanTicker = nil
        end

        local count = 0
        for _ in pairs(self.index) do count = count + 1 end
        self.stat.mapCount = count
        self.scan = nil
        self.ready = true

        self:Refresh()
        self:Print(("%d pins across %d maps (%.1fs)."):format(
            self.stat.nodes, self.stat.mapCount, GetTime() - scan.startedAt))
    else
        if self.UpdateUIStatus then self:UpdateUIStatus() end
    end
end

function ns:StartScan()
    if self.blocked then return end
    if not self.initialized then self:Init() end
    if self.blocked then return end

    if self.scanTicker then
        self.scanTicker:Cancel()
        self.scanTicker = nil
    end

    self:ResetIndex()
    self.myFaction = UnitFactionGroup("player")
    if self.myFaction ~= "Alliance" and self.myFaction ~= "Horde" then
        self.myFaction = nil
    end

    local npcIds = (NpcDB and NpcDB.GetAllIds and NpcDB.GetAllIds()) or {}
    local objIds = (ObjectDB and ObjectDB.GetAllIds and ObjectDB.GetAllIds()) or {}

    self.scan = {
        npcIds = npcIds,
        objIds = objIds,
        npcPos = 1,
        objPos = 1,
        phase = #npcIds > 0 and "npcs" or "objects",
        bits = FlagBits(),
        startedAt = GetTime(),
    }

    self:Refresh()
    self.scanTicker = C_Timer.NewTicker(0.05, function()
        self:ScanStep()
    end)
end
