local ADDON, ns = ...

ns.PLUGIN = "ForeverWayfinder"
ns.VERSION = "1.0.1"
ns.PREFIX = "|cffd4af37Forever Wayfinder|r"

local floor = math.floor

--------------------------------------------------------------------------------------------
-- Visual identity
--------------------------------------------------------------------------------------------

ns.Colors = {
    gold = { 0.83, 0.69, 0.32 },
    brightGold = { 1.00, 0.82, 0.00 },
    parchment = { 0.95, 0.92, 0.82 },
    muted = { 0.62, 0.59, 0.52 },
    dark = { 0.05, 0.04, 0.03, 0.96 },
    panel = { 0.09, 0.075, 0.055, 0.98 },
    row = { 0.12, 0.10, 0.07, 0.55 },
    hover = { 0.20, 0.16, 0.09, 0.85 },
    frameBorder = { 0.55, 0.44, 0.23, 1 },
    green = { 0.45, 0.78, 0.45 },
    red = { 0.85, 0.35, 0.30 },
}

ns.MEDIA = {
    white = "Interface\\Buttons\\WHITE8X8",
    tooltipBorder = "Interface\\Tooltips\\UI-Tooltip-Border",
    checkbox = "Interface\\Buttons\\UI-CheckBox-Check",
    sliderBg = "Interface\\Buttons\\UI-SliderBar-Background",
    sliderThumb = "Interface\\Buttons\\UI-SliderBar-Button-Horizontal",
    minimapBg = "Interface\\Minimap\\UI-Minimap-Background",
    minimapHighlight = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
    addonIcon = "Interface\\Icons\\INV_Misc_Map_01",
}

--------------------------------------------------------------------------------------------
-- Categories
--------------------------------------------------------------------------------------------

-- Icons use paths that ship with the Forever client. Service categories lean on the
-- built-in tracking textures so a pin reads at a glance on the world map.
ns.categoryList = {
    -- Services
    { key = "vendor", group = "services", name = "Vendors", icon = "Interface\\Icons\\INV_Misc_Bag_10" },
    { key = "repair", group = "services", name = "Repair", icon = "Interface\\Icons\\Trade_BlackSmithing" },
    { key = "innkeeper", group = "services", name = "Innkeepers", icon = "Interface\\Icons\\INV_Misc_Food_15" },
    { key = "mailbox", group = "services", name = "Mailboxes", icon = "Interface\\Minimap\\tracking\\mailbox" },
    { key = "auctioneer", group = "services", name = "Auctioneers", icon = "Interface\\Icons\\INV_Misc_Coin_01" },
    { key = "banker", group = "services", name = "Bankers", icon = "Interface\\Icons\\INV_Misc_Coin_02" },
    { key = "flight", group = "services", name = "Flight Masters", icon = "Interface\\Minimap\\tracking\\flightmaster" },
    { key = "stable", group = "services", name = "Stable Masters", icon = "Interface\\Minimap\\tracking\\stablemaster" },

    -- Trainers
    { key = "classTrainer", group = "trainers", name = "Class Trainers", icon = "Interface\\Minimap\\tracking\\class" },
    { key = "profession", group = "trainers", name = "Profession Trainers", icon = "Interface\\Minimap\\tracking\\profession" },
    { key = "portal", group = "trainers", name = "Portal Trainers", icon = "Interface\\Minimap\\vehicle-alliancemageportal" },
    { key = "weapon", group = "trainers", name = "Weapon Masters", icon = "Interface\\Icons\\INV_Sword_04" },
    { key = "pet", group = "trainers", name = "Battle Pet Trainers", icon = "Interface\\Icons\\Ability_Hunter_BeastCall" },
    { key = "otherTrainer", group = "trainers", name = "Other Trainers", icon = "Interface\\Icons\\INV_Misc_Book_11" },

    -- Other points of interest
    { key = "spirit", group = "other", name = "Spirit Healers", icon = "Interface\\raidframe\\raid-icon-rez" },
    { key = "battlemaster", group = "other", name = "Battlemasters", icon = "Interface\\Icons\\INV_Banner_02" },
    { key = "barber", group = "other", name = "Barbers", icon = "Interface\\Icons\\INV_Misc_Comb_01" },
    { key = "transmog", group = "other", name = "Transmogrifiers", icon = "Interface\\Minimap\\tracking\\transmogrifier" },
    { key = "tabard", group = "other", name = "Tabard Designers", icon = "Interface\\Icons\\INV_Shirt_GuildTabard_01" },
}

ns.categoryByKey = {}
for _, category in ipairs(ns.categoryList) do
    ns.categoryByKey[category.key] = category
end

-- Used to pick one icon when a node belongs to several enabled categories. Specific service
-- roles win over the generic vendor flag, trainers win over vendors.
ns.iconPriority = {
    "repair", "auctioneer", "banker", "innkeeper", "stable", "flight", "mailbox",
    "portal", "profession", "classTrainer", "weapon", "pet", "otherTrainer",
    "vendor", "spirit", "battlemaster", "barber", "transmog", "tabard",
}

ns.categoryGroups = {
    { key = "services", title = "SERVICES", keys = { "vendor", "repair", "innkeeper", "mailbox", "auctioneer", "banker", "flight", "stable" } },
    { key = "trainers", title = "TRAINERS", keys = { "classTrainer", "profession", "portal", "weapon", "pet", "otherTrainer" } },
    { key = "other", title = "OTHER POINTS OF INTEREST", keys = { "spirit", "battlemaster", "barber", "transmog", "tabard" } },
}

ns.defaultCategories = {
    vendor = true,
    repair = true,
    innkeeper = true,
    mailbox = true,
    auctioneer = true,
    banker = true,
    flight = true,
    stable = true,
    classTrainer = true,
    profession = true,
    portal = true,
    weapon = false,
    pet = false,
    otherTrainer = true,
    spirit = true,
    battlemaster = false,
    barber = false,
    transmog = false,
    tabard = false,
}

ns.defaults = {
    enabled = true,
    showWorldMap = true,
    showMinimap = true,
    showOnContinent = false,
    factionFilter = true,
    pinScale = 1.0,
    minimapAngle = 220,
    hideMinimapButton = false,
    uiPosition = nil,
}

--------------------------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------------------------

local band
if bit and bit.band then
    band = bit.band
else
    function band(a, b)
        local result, place = 0, 1
        while a > 0 and b > 0 do
            if a % 2 == 1 and b % 2 == 1 then result = result + place end
            a = floor(a / 2)
            b = floor(b / 2)
            place = place * 2
        end
        return result
    end
end
ns.band = band

function ns:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(self.PREFIX .. " " .. tostring(message))
end

function ns:CopyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = value
        end
    end
end

function ns:IsCategoryEnabled(key)
    return self.db and self.db.categories[key] == true
end

local DEFAULT_VENDOR_ICON = "Interface\\Icons\\INV_Misc_Bag_10"

function ns:GetNodeIcon(node)
    local categories = self.db.categories
    -- Most vendors can also repair, which would otherwise paint them all with the anvil.
    -- When the vendor's stock is known, show what they sell instead of the incidental service.
    local showVendorStock = categories.vendor and node.vendorIcon

    for index = 1, #self.iconPriority do
        local key = self.iconPriority[index]
        if node.cats[key] and categories[key] then
            if not (key == "repair" and showVendorStock) then
                if key == "vendor" then
                    return node.vendorIcon or DEFAULT_VENDOR_ICON
                end
                return self.categoryByKey[key].icon
            end
        end
    end
    return nil
end

function ns:GetNodeTitle(node)
    local entry = node.entries[1]
    if not entry then return "Service NPC" end
    if entry.sub and entry.sub ~= "" then
        return entry.name .. " - " .. entry.sub
    end
    return entry.name
end

function ns:GetNodeCategoryNames(node, onlyEnabled)
    local names = {}
    for index = 1, #self.categoryList do
        local category = self.categoryList[index]
        if node.cats[category.key] and (not onlyEnabled or self.db.categories[category.key]) then
            names[#names + 1] = category.name
        end
    end
    return table.concat(names, " · ")
end

function ns:GetNode(mapID, coord)
    local map = self.index and self.index[mapID]
    return map and map[coord]
end

--------------------------------------------------------------------------------------------
-- Saved variables
--------------------------------------------------------------------------------------------

function ns:InitDB()
    if type(ForeverWayfinderDB) ~= "table" then ForeverWayfinderDB = {} end
    local db = ForeverWayfinderDB
    self:CopyDefaults(db, self.defaults)
    if type(db.categories) ~= "table" then db.categories = {} end
    self:CopyDefaults(db.categories, self.defaultCategories)

    local booleanKeys = { "enabled", "showWorldMap", "showMinimap", "showOnContinent",
        "factionFilter", "hideMinimapButton" }
    for i = 1, #booleanKeys do
        local key = booleanKeys[i]
        if type(db[key]) ~= "boolean" then db[key] = self.defaults[key] end
    end
    for key, defaultValue in pairs(self.defaultCategories) do
        if type(db.categories[key]) ~= "boolean" then db.categories[key] = defaultValue end
    end
    if type(db.pinScale) ~= "number" or db.pinScale ~= db.pinScale
        or db.pinScale == math.huge or db.pinScale == -math.huge then
        db.pinScale = self.defaults.pinScale
    else
        db.pinScale = math.max(0.5, math.min(1.5, db.pinScale))
    end
    if type(db.minimapAngle) ~= "number" or db.minimapAngle ~= db.minimapAngle
        or db.minimapAngle == math.huge or db.minimapAngle == -math.huge then
        db.minimapAngle = self.defaults.minimapAngle
    else
        db.minimapAngle = db.minimapAngle % 360
    end
    local validAnchors = {
        TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
        RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
    }
    local position = db.uiPosition
    if type(position) ~= "table" or not validAnchors[position.point]
        or type(position.x) ~= "number" or type(position.y) ~= "number"
        or position.x ~= position.x or position.y ~= position.y
        or position.x == math.huge or position.x == -math.huge
        or position.y == math.huge or position.y == -math.huge then
        db.uiPosition = nil
    elseif not validAnchors[position.relativePoint] then
        position.relativePoint = position.point
    end
    if type(db.schemaVersion) ~= "number" or db.schemaVersion ~= db.schemaVersion
        or db.schemaVersion == math.huge or db.schemaVersion == -math.huge
        or db.schemaVersion < 1 or db.schemaVersion % 1 ~= 0 then
        db.schemaVersion = 1
    end
    self.db = db
end

function ns:ResetSettings()
    local db = self.db
    for key in pairs(db) do
        if key ~= "uiPosition" and key ~= "minimapAngle" then
            db[key] = nil
        end
    end
    self:CopyDefaults(db, self.defaults)
    db.categories = {}
    self:CopyDefaults(db.categories, self.defaultCategories)
    self:Refresh()
    if self.UpdateUI then self:UpdateUI() end
    self:Print("Settings reset to defaults.")
end

--------------------------------------------------------------------------------------------
-- QuestieDB / HandyNotes availability
--------------------------------------------------------------------------------------------

function ns:CheckDependencies()
    local lib = _G.LibQuestieDB
    if not lib then
        return false, "QuestieDB is not loaded."
    end
    if type(lib.RequireContract) ~= "function" then
        return false, "QuestieDB is missing the public API. Update QuestieDB."
    end

    local ok, message = lib.RequireContract(4)
    if not ok then
        return false, message or "QuestieDB contract mismatch."
    end

    if not NpcDB or not ObjectDB then
        return false, "QuestieDB did not expose NpcDB/ObjectDB."
    end
    if not HandyNotes or not HandyNotes.RegisterPluginDB then
        return false, "HandyNotes is not loaded."
    end

    if self.BuildZoneMap then
        local callOk, zonesOk, zoneMessage = pcall(self.BuildZoneMap, self)
        if not callOk then
            return false, "QuestieDB zone map initialization failed: " .. tostring(zonesOk)
        end
        if not zonesOk then
            return false, zoneMessage or "QuestieDB zone data could not be read."
        end
    end

    return true
end

--------------------------------------------------------------------------------------------
-- Refresh
--------------------------------------------------------------------------------------------

function ns:Refresh()
    if self.blocked then return end

    if HandyNotes and HandyNotes.UpdatePluginMap then
        HandyNotes:UpdatePluginMap(nil, self.PLUGIN)
    end
    if self.UpdateMinimapButton then
        self:UpdateMinimapButton()
    end
    if self.UpdateUIStatus then
        self:UpdateUIStatus()
    end
end

--------------------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------------------

local function PrintHelp()
    ns:Print("Commands:")
    ns:Print("  /fw - open or close the settings panel")
    ns:Print("  /fw on | off - enable or disable all pins")
    ns:Print("  /fw refresh - rebuild the NPC index")
    ns:Print("  /fw reset - restore default settings")
    ns:Print("  /fw status - show index statistics")
end

local function HandleSlash(message)
    message = (message or ""):lower():match("^%s*(.-)%s*$")

    if message == "" then
        ns:ToggleUI()
    elseif message == "on" then
        ns.db.enabled = true
        ns:Refresh()
        ns:Print("Pins enabled.")
    elseif message == "off" then
        ns.db.enabled = false
        ns:Refresh()
        ns:Print("Pins disabled.")
    elseif message == "refresh" then
        ns:StartScan()
        ns:Print("Rebuilding the NPC index.")
    elseif message == "reset" then
        ns:ResetSettings()
    elseif message == "status" then
        local scan = ns.scan
        if ns.blocked then
            ns:Print("Disabled: " .. ns.blocked)
        elseif not ns.ready then
            local text = "Indexing"
            if scan then
                text = text .. (" (%d / %d NPCs"):format(scan.npcPos - 1, #scan.npcIds)
                if scan.phase == "objects" then
                    text = text .. (", %d / %d objects"):format(scan.objPos - 1, #scan.objIds)
                end
                text = text .. ")"
            elseif ns.lastScan and ns.lastScan.state then
                text = text .. " (last scan: " .. ns.lastScan.state .. ")"
            end
            ns:Print(text)
            if ns.lastScan and ns.lastScan.reason then ns:Print(ns.lastScan.reason) end
        else
            ns:Print(("%d pins across %d maps from %d NPCs and %d objects."):format(
                ns.stat.nodes, ns.stat.mapCount, ns.stat.npcs, ns.stat.objects))
            ns:Print(("%d invalid records, %d invalid spawns, %d unresolved zones."):format(
                ns.stat.invalidRecords or 0, ns.stat.invalidSpawns or 0, ns.stat.unresolvedZones or 0))
            if ns.lastScan then
                ns:Print(("Last scan: %s; enumeration %.3fs; duration %.3fs; NPC errors %d; object errors %d."):format(
                    ns.lastScan.state or "unknown", ns.lastScan.enumerationDuration or 0,
                    ns.lastScan.duration or 0, ns.stat.npcErrors or 0, ns.stat.objectErrors or 0))
                ns:Print(("Max scan slice: %.4fs / %d records."):format(
                    ns.lastScan.maxSliceDuration or 0, ns.lastScan.maxSliceProcessed or 0))
                for index, item in ipairs(ns.lastScan.errors or {}) do
                    ns:Print(("Sample error %d (%s %s): %s"):format(
                        index, item.kind, tostring(item.id), item.message))
                end
            end
        end
    else
        PrintHelp()
    end
end

SLASH_FOREVERWAYFINDER1 = "/fw"
SLASH_FOREVERWAYFINDER2 = "/foreverwayfinder"
SlashCmdList.FOREVERWAYFINDER = HandleSlash

--------------------------------------------------------------------------------------------
-- Startup
--------------------------------------------------------------------------------------------

function ns:Init()
    if self.initialized then return end
    self.initialized = true

    self:InitDB()

    local ok, reason = self:CheckDependencies()
    if not ok then
        self.blocked = reason
        self.lastScan = { state = "blocked", reason = reason }
        self:Print("Disabled: " .. reason)
        if self.CreateUI then self:CreateUI() end
        return
    end

    if self.ResetIndex then
        self:ResetIndex()
    else
        self.index = {}
        self.descCache = {}
        self.stat = { nodes = 0, mapCount = 0, npcs = 0, objects = 0, catCount = {} }
        self.ready = false
    end

    self:RegisterHandyNotes()
    if self.CreateUI then self:CreateUI() end
    if self.CreateMinimapButton then self:CreateMinimapButton() end
end

local startup = CreateFrame("Frame")
startup:RegisterEvent("ADDON_LOADED")
startup:RegisterEvent("PLAYER_LOGIN")
startup:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        self:UnregisterEvent("ADDON_LOADED")
        ns:Init()
    elseif event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        if not ns.initialized then ns:Init() end
        if not ns.blocked then
            ns:StartScan()
        end
    end
end)
