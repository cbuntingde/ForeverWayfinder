local ADDON, ns = ...

local floor = math.floor


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
    return ns.ClassificationNormalizeText(value)
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

local function FlagBits()
    local enum = _G.LibQuestieDB and _G.LibQuestieDB.Enum and _G.LibQuestieDB.Enum.npcFlags or {}
    if type(enum) ~= "table" then enum = {} end
    local function ReadFlag(key, fallback)
        local value = enum[key]
        if type(value) ~= "number" or value <= 0 or value % 1 ~= 0 then
            return fallback
        end
        return value
    end
    return {
        VENDOR = ReadFlag("VENDOR", 4),
        FLIGHT_MASTER = ReadFlag("FLIGHT_MASTER", 8),
        TRAINER = ReadFlag("TRAINER", 16),
        SPIRIT_HEALER = ReadFlag("SPIRIT_HEALER", 32),
        INNKEEPER = ReadFlag("INNKEEPER", 128),
        BANKER = ReadFlag("BANKER", 256),
        TABARD_DESIGNER = ReadFlag("TABARD_DESIGNER", 1024),
        BATTLEMASTER = ReadFlag("BATTLEMASTER", 2048),
        AUCTIONEER = ReadFlag("AUCTIONEER", 4096),
        STABLEMASTER = ReadFlag("STABLEMASTER", 8192),
        REPAIR = ReadFlag("REPAIR", 16384),
        BARBER = ReadFlag("BARBER", 33554432),
        TRANSMOGRIFIER = ReadFlag("TRANSMOGRIFIER", 536870912),
    }
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
    self.stat = {
        nodes = 0, mapCount = 0, npcs = 0, objects = 0, catCount = {},
        invalidRecords = 0, invalidSpawns = 0, unresolvedZones = 0,
        npcErrors = 0, objectErrors = 0,
        invalidSpawnReasons = {}, invalidSpawnSamples = {},
        unresolvedZoneSamples = {},
    }
    self.ready = false
end

function ns:RecordScanError(kind, id, message)
    local scan = self.scan
    if not scan then return end
    scan.errors = scan.errors or {}
    if #scan.errors < 5 then
        scan.errors[#scan.errors + 1] = { kind = kind, id = id, message = tostring(message) }
    end
    if kind == "npc" then
        self.stat.npcErrors = (self.stat.npcErrors or 0) + 1
    else
        self.stat.objectErrors = (self.stat.objectErrors or 0) + 1
    end
end

function ns:RecordInvalidSpawn(reason, entry, zoneID, spawn, mapID)
    local stat = self.stat
    stat.invalidSpawns = (stat.invalidSpawns or 0) + 1
    stat.invalidSpawnReasons = stat.invalidSpawnReasons or {}
    stat.invalidSpawnReasons[reason] = (stat.invalidSpawnReasons[reason] or 0) + 1
    stat.invalidSpawnSamples = stat.invalidSpawnSamples or {}
    if #stat.invalidSpawnSamples < 20 then
        stat.invalidSpawnSamples[#stat.invalidSpawnSamples + 1] = {
            reason = reason,
            name = entry and entry.name or "Unknown",
            id = entry and entry.id or "unknown",
            zoneID = zoneID or "unknown",
            mapID = mapID or "unknown",
            x = type(spawn) == "table" and tostring(spawn[1]) or "n/a",
            y = type(spawn) == "table" and tostring(spawn[2]) or "n/a",
        }
    end
end

function ns:RecordUnresolvedZone(entry, zoneID, list)
    local stat = self.stat
    stat.unresolvedZones = (stat.unresolvedZones or 0) + 1
    stat.unresolvedZoneSamples = stat.unresolvedZoneSamples or {}
    if #stat.unresolvedZoneSamples < 20 then
        stat.unresolvedZoneSamples[#stat.unresolvedZoneSamples + 1] = {
            name = entry and entry.name or "Unknown",
            id = entry and entry.id or "unknown",
            zoneID = tostring(zoneID),
            spawnCount = type(list) == "table" and #list or 0,
        }
    end
end

function ns:AddSpawn(mapID, x, y, cats, entry)
    if not ns.ClassificationIsPositiveInteger(mapID)
        or not ns.ClassificationIsCoordinate(x) or not ns.ClassificationIsCoordinate(y)
        or type(cats) ~= "table" or type(entry) ~= "table" then
        local reason = "invalid-map-id"
        if not ns.ClassificationIsPositiveInteger(mapID) then
            reason = "invalid-map-id"
        elseif not ns.ClassificationIsCoordinate(x) then
            reason = "invalid-x-coordinate"
        elseif not ns.ClassificationIsCoordinate(y) then
            reason = "invalid-y-coordinate"
        elseif type(cats) ~= "table" then
            reason = "invalid-categories"
        else
            reason = "invalid-entry"
        end
        self:RecordInvalidSpawn(reason, entry, nil, { x, y }, mapID)
        return false
    end
    local nx, ny = x / 100, y / 100

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
    entry.categories = entry.categories or {}
    for key in pairs(cats) do entry.categories[key] = true end
    entries[#entries + 1] = entry
    node.more = 0
    return true
end

function ns:IndexNpc(id, bits)
    if not ns.ClassificationIsPositiveInteger(id) then
        self.stat.invalidRecords = (self.stat.invalidRecords or 0) + 1
        return
    end
    local values = NpcDB.GetAll(id, { "name", "subName", "friendlyToFaction", "npcFlags" })
    if type(values) ~= "table" then return end

    local name = values[1]
    local subName = values[2]
    local friendly = values[3]
    local flags = values[4]
    if flags == nil then flags = 0 end
    if not ns.ClassificationIsFiniteNumber(flags) or flags < 0 or flags % 1 ~= 0 then
        self.stat.invalidRecords = (self.stat.invalidRecords or 0) + 1
        return
    end
    if type(name) ~= "string" or name == "" then return end
    if not self:FactionAllowed(friendly) then return end

    local classificationName = subName
    if ns.band(flags, bits.TRAINER) ~= 0 then
        classificationName = NpcDB.GetRaw(id, "subName") or subName
    end

    local cats = ns.ClassificationCategoriesForNpc(flags, classificationName, bits, ns.band)
    if next(cats) == nil then return end

    local spawns = NpcDB.Get(id, "spawns")
    if type(spawns) ~= "table" then return end

    self.stat.npcs = self.stat.npcs + 1
    local entry = { name = name, sub = subName, id = id }
    if cats.vendor then
        entry.vendorIcon = VendorStockIcon(subName)
    end

    for zoneID, list in pairs(spawns) do
        local mapID = self.areaToMap[zoneID]
        if ns.ClassificationIsPositiveInteger(mapID) and type(list) == "table" then
            for index = 1, #list do
                local spawn = list[index]
                if type(spawn) == "table" then
                    local x, y = spawn[1], spawn[2]
                    if not ns.ClassificationIsCoordinate(x) then
                        self:RecordInvalidSpawn("invalid-x-coordinate", entry, zoneID, spawn, mapID)
                    elseif not ns.ClassificationIsCoordinate(y) then
                        self:RecordInvalidSpawn("invalid-y-coordinate", entry, zoneID, spawn, mapID)
                    else
                        self:AddSpawn(mapID, x, y, cats, entry)
                    end
                else
                    self:RecordInvalidSpawn("spawn-is-not-a-table", entry, zoneID, spawn, mapID)
                end
            end
        else
            self:RecordUnresolvedZone(entry, zoneID, list)
        end
    end
end

function ns:IndexObject(id)
    if not ns.ClassificationIsPositiveInteger(id) then
        self.stat.invalidRecords = (self.stat.invalidRecords or 0) + 1
        return
    end
    local rawName = ObjectDB.GetRaw(id, "name")
    local lower = Lower(rawName)
    if not (Find(lower, "mailbox") or Find(lower, "mail box")) then return end

    local spawns = ObjectDB.Get(id, "spawns")
    if type(spawns) ~= "table" then return end

    local name = ObjectDB.Get(id, "name") or rawName
    if type(name) ~= "string" or name == "" then
        self.stat.invalidRecords = (self.stat.invalidRecords or 0) + 1
        return
    end
    self.stat.objects = self.stat.objects + 1

    local entry = { name = name, sub = "Mailbox", id = id }
    local cats = { mailbox = true }

    for zoneID, list in pairs(spawns) do
        local mapID = self.areaToMap[zoneID]
        if ns.ClassificationIsPositiveInteger(mapID) and type(list) == "table" then
            for index = 1, #list do
                local spawn = list[index]
                if type(spawn) == "table" then
                    local x, y = spawn[1], spawn[2]
                    if not ns.ClassificationIsCoordinate(x) then
                        self:RecordInvalidSpawn("invalid-x-coordinate", entry, zoneID, spawn, mapID)
                    elseif not ns.ClassificationIsCoordinate(y) then
                        self:RecordInvalidSpawn("invalid-y-coordinate", entry, zoneID, spawn, mapID)
                    else
                        self:AddSpawn(mapID, x, y, cats, entry)
                    end
                else
                    self:RecordInvalidSpawn("spawn-is-not-a-table", entry, zoneID, spawn, mapID)
                end
            end
        else
            self:RecordUnresolvedZone(entry, zoneID, list)
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
    if not scan or scan.generation ~= self.scanGeneration then return end

    local sliceStarted = GetTime()
    local deadline = sliceStarted + SCAN_BUDGET
    local processed = 0

    if scan.phase == "npcs" then
        local ids, pos, total = scan.npcIds, scan.npcPos, #scan.npcIds
        while pos <= total and processed < SCAN_MAX_STEPS and GetTime() < deadline do
            local id = ids[pos]
            local ok, err = pcall(self.IndexNpc, self, id, scan.bits)
            if not ok then self:RecordScanError("npc", id, err) end
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
            local id = ids[pos]
            local ok, err = pcall(self.IndexObject, self, id)
            if not ok then self:RecordScanError("object", id, err) end
            pos = pos + 1
            processed = processed + 1
        end
        scan.objPos = pos
        if pos > total then
            scan.phase = "done"
        end
    end

    local sliceDuration = GetTime() - sliceStarted
    if sliceDuration > (scan.maxSliceDuration or 0) then scan.maxSliceDuration = sliceDuration end
    if processed > (scan.maxSliceProcessed or 0) then scan.maxSliceProcessed = processed end

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
        self.lastScan = {
            state = "complete", duration = GetTime() - scan.startedAt,
            enumerationDuration = scan.enumerationDuration,
            maxSliceDuration = scan.maxSliceDuration or 0,
            maxSliceProcessed = scan.maxSliceProcessed or 0,
            npcCount = scan.npcPos - 1, objectCount = scan.objPos - 1,
            errors = scan.errors or {},
        }
        self:Refresh()
        if self.RefreshSearchResults then self:RefreshSearchResults() end
        self:Print(("%d pins across %d maps (%.1fs; %d record errors, %d invalid spawns)."):format(
            self.stat.nodes, self.stat.mapCount, self.lastScan.duration,
            (self.stat.npcErrors or 0) + (self.stat.objectErrors or 0),
            self.stat.invalidSpawns or 0))
    else
        if self.UpdateUIStatus then self:UpdateUIStatus() end
    end
end

function ns:StartScan()
    if self.blocked then return false end
    if not self.initialized then self:Init() end
    if self.blocked then return false end

    self.scanGeneration = (self.scanGeneration or 0) + 1
    local generation = self.scanGeneration
    if self.scanTicker then self.scanTicker:Cancel(); self.scanTicker = nil end
    if self.scan then
        self.lastScan = { state = "cancelled", duration = GetTime() - self.scan.startedAt }
    end
    -- Do not leave a stale scan object behind if the new ID enumeration fails.
    self.scan = nil

    self:ResetIndex()
    self.myFaction = UnitFactionGroup("player")
    if self.myFaction ~= "Alliance" and self.myFaction ~= "Horde" then self.myFaction = nil end

    local enumerationStarted = GetTime()
    self.lastScan = { state = "enumerating", startedAt = enumerationStarted }
    local npcOk, npcIds = pcall(NpcDB.GetAllIds)
    local objOk, objIds = pcall(ObjectDB.GetAllIds)
    if not npcOk or type(npcIds) ~= "table" then
        self.lastScan = { state = "failed", reason = "QuestieDB NPC ID enumeration failed." }
        self:Print("Indexing failed: QuestieDB NPC ID enumeration failed.")
        self:UpdateUIStatus()
        return false
    end
    if not objOk or type(objIds) ~= "table" then
        self.lastScan = { state = "failed", reason = "QuestieDB object ID enumeration failed." }
        self:Print("Indexing failed: QuestieDB object ID enumeration failed.")
        self:UpdateUIStatus()
        return false
    end

    self.scan = {
        generation = generation, npcIds = npcIds, objIds = objIds,
        npcPos = 1, objPos = 1,
        phase = #npcIds > 0 and "npcs" or "objects",
        bits = FlagBits(), startedAt = GetTime(),
        enumerationDuration = GetTime() - enumerationStarted, errors = {},
    }
    self.lastScan = { state = "indexing", enumerationDuration = self.scan.enumerationDuration }
    self:Refresh()
    self.scanTicker = C_Timer.NewTicker(0.05, function()
        if generation == self.scanGeneration then self:ScanStep() end
    end)
    return true
end
