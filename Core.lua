local ADDON, ns = ...

ns.PLUGIN = "ForeverWayfinder"
ns.VERSION = "1.2.2"
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
}

ns.MEDIA = {
    white = "Interface\\Buttons\\WHITE8X8",
    checkbox = "Interface\\Buttons\\UI-CheckBox-Check",
    sliderBg = "Interface\\Buttons\\UI-SliderBar-Background",
    sliderThumb = "Interface\\Buttons\\UI-SliderBar-Button-Horizontal",
    minimapBg = "Interface\\Minimap\\UI-Minimap-Background",
    minimapHighlight = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
    addonIcon = "Interface\\Icons\\INV_Misc_Map_01",
}

--------------------------------------------------------------------------------------------
-- Journal theme: leather + gold book chrome, parchment pages, maroon controls.
-- Shared by the settings and search windows so both read as one illustrated journal.
--------------------------------------------------------------------------------------------

ns.Colors.leather = { 0.16, 0.11, 0.07, 1 }
ns.Colors.leatherDark = { 0.10, 0.07, 0.045, 1 }
ns.Colors.page = { 0.90, 0.85, 0.71, 1 }
ns.Colors.pageEdge = { 0.72, 0.63, 0.45, 1 }
ns.Colors.pageHover = { 0.80, 0.72, 0.53, 1 }
ns.Colors.ink = { 0.24, 0.17, 0.10 }
ns.Colors.inkMuted = { 0.47, 0.40, 0.29 }
ns.Colors.maroon = { 0.45, 0.10, 0.10, 1 }
ns.Colors.maroonHover = { 0.60, 0.16, 0.14, 1 }
ns.Colors.cream = { 0.86, 0.80, 0.63, 1 }
ns.Colors.goldLine = { 0.72, 0.58, 0.30, 1 }

ns.Journal = {}
local Journal = ns.Journal
local fontCache = {}

-- Serif display face for the book feel; falls back to the client default if the
-- legacy font alias is unavailable on a given client build.
function Journal.Font(size, outline)
    local key = size .. ":" .. (outline or "")
    if not fontCache[key] then
        local font = CreateFont("ForeverWayfinderJournal" .. key:gsub("%W", "_"))
        if not font:SetFont("Fonts\\MORPHEUS.TTF", size, outline or "") then
            font:SetFont(STANDARD_TEXT_FONT, size, outline or "")
        end
        fontCache[key] = font
    end
    return fontCache[key]
end

function Journal.Text(parent, size, text, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(Journal.Font(size))
    fs:SetText(text or "")
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    if justify then fs:SetJustifyH(justify) end
    return fs
end

local function Solid(frame, color, layer)
    local tex = frame:CreateTexture(nil, layer or "BACKGROUND")
    tex:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    return tex
end
Journal.Solid = Solid

-- Ornate leather cover with a double gold pinline. Uses only solid color textures
-- so it renders identically on clients that lack the legacy dialog-frame art.
function Journal.Decorate(frame)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = ns.MEDIA.white,
            edgeFile = ns.MEDIA.white,
            edgeSize = 2,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        frame:SetBackdropColor(ns.Colors.leather[1], ns.Colors.leather[2], ns.Colors.leather[3], 1)
        frame:SetBackdropBorderColor(ns.Colors.goldLine[1], ns.Colors.goldLine[2], ns.Colors.goldLine[3], 1)
    end
    local inner = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    inner:SetPoint("TOPLEFT", 6, -6)
    inner:SetPoint("BOTTOMRIGHT", -6, 6)
    if inner.SetBackdrop then
        inner:SetBackdrop({
            bgFile = ns.MEDIA.white, edgeFile = ns.MEDIA.white, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        inner:SetBackdropColor(0, 0, 0, 0)
        inner:SetBackdropBorderColor(ns.Colors.goldLine[1], ns.Colors.goldLine[2], ns.Colors.goldLine[3], 0.6)
    end
end

-- A parchment page inset within the cover.
function Journal.Page(parent, left, top, right, bottom)
    local page = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    page:SetPoint("TOPLEFT", left, top)
    page:SetPoint("BOTTOMRIGHT", right, bottom)
    if page.SetBackdrop then
        page:SetBackdrop({
            bgFile = ns.MEDIA.white, edgeFile = ns.MEDIA.white, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        page:SetBackdropColor(ns.Colors.page[1], ns.Colors.page[2], ns.Colors.page[3], 1)
        page:SetBackdropBorderColor(ns.Colors.pageEdge[1], ns.Colors.pageEdge[2], ns.Colors.pageEdge[3], 1)
    end
    return page
end

function Journal.Header(frame, height)
    local band = Solid(frame, ns.Colors.leatherDark)
    band:SetPoint("TOPLEFT", 10, -10)
    band:SetPoint("TOPRIGHT", -10, -10)
    band:SetHeight(height)
    local rule = Solid(frame, ns.Colors.goldLine)
    rule:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT", 0, 0)
    rule:SetHeight(1)
    return band
end

function Journal.Button(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    button:SetSize(width, 24)
    if button.SetBackdrop then
        button:SetBackdrop({
            bgFile = ns.MEDIA.white, edgeFile = ns.MEDIA.white, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        button:SetBackdropColor(ns.Colors.maroon[1], ns.Colors.maroon[2], ns.Colors.maroon[3], 1)
        button:SetBackdropBorderColor(ns.Colors.goldLine[1], ns.Colors.goldLine[2], ns.Colors.goldLine[3], 1)
    end
    button.label = Journal.Text(button, 14, text, ns.Colors.gold)
    button.label:SetPoint("CENTER")
    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(ns.Colors.maroonHover[1], ns.Colors.maroonHover[2], ns.Colors.maroonHover[3], 1)
        self.label:SetTextColor(ns.Colors.brightGold[1], ns.Colors.brightGold[2], ns.Colors.brightGold[3])
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(ns.Colors.maroon[1], ns.Colors.maroon[2], ns.Colors.maroon[3], 1)
        self.label:SetTextColor(ns.Colors.gold[1], ns.Colors.gold[2], ns.Colors.gold[3])
    end)
    button:SetScript("OnClick", onClick)
    return button
end

function Journal.Section(parent, x, y, width, title)
    local header = Journal.Text(parent, 15, title:upper(), ns.Colors.ink)
    header:SetPoint("TOPLEFT", x, y)
    local rule = Solid(parent, ns.Colors.inkMuted)
    rule:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -3)
    rule:SetSize(width, 1)
    rule:SetAlpha(0.45)
    return header
end

function Journal.CheckRow(parent, x, y, width, height, label, iconPath, getter, setter)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, height)
    row:SetPoint("TOPLEFT", x, y)

    row.hover = Solid(row, ns.Colors.pageHover)
    row.hover:SetAllPoints()
    row.hover:SetAlpha(0)

    row.box = CreateFrame("Frame", nil, row, BackdropTemplateMixin and "BackdropTemplate" or nil)
    row.box:SetSize(15, 15)
    row.box:SetPoint("LEFT", 2, 0)
    if row.box.SetBackdrop then
        row.box:SetBackdrop({
            bgFile = ns.MEDIA.white, edgeFile = ns.MEDIA.white, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        row.box:SetBackdropColor(ns.Colors.cream[1], ns.Colors.cream[2], ns.Colors.cream[3], 1)
        row.box:SetBackdropBorderColor(ns.Colors.ink[1], ns.Colors.ink[2], ns.Colors.ink[3], 0.8)
    end
    row.mark = row.box:CreateTexture(nil, "ARTWORK")
    row.mark:SetTexture(ns.MEDIA.checkbox)
    row.mark:SetSize(14, 14)
    row.mark:SetPoint("CENTER")
    row.mark:SetVertexColor(ns.Colors.maroon[1], ns.Colors.maroon[2], ns.Colors.maroon[3])

    local textOffset = 24
    if iconPath then
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetTexture(iconPath)
        row.icon:SetSize(17, 17)
        row.icon:SetPoint("LEFT", 24, 0)
        textOffset = 46
    end

    row.label = Journal.Text(row, 14, label, ns.Colors.ink, "LEFT")
    row.label:SetPoint("LEFT", textOffset, 0)
    row.label:SetWidth(width - textOffset - 4)

    function row:Refresh()
        local enabled = getter()
        self.mark:SetShown(enabled)
        if enabled then
            self.label:SetTextColor(ns.Colors.ink[1], ns.Colors.ink[2], ns.Colors.ink[3])
        else
            self.label:SetTextColor(ns.Colors.inkMuted[1], ns.Colors.inkMuted[2], ns.Colors.inkMuted[3])
        end
    end

    row:SetScript("OnEnter", function(self) self.hover:SetAlpha(0.6) end)
    row:SetScript("OnLeave", function(self) self.hover:SetAlpha(0) end)
    row:SetScript("OnClick", function(self)
        setter(not getter())
        self:Refresh()
        ns:Refresh()
    end)
    row:Refresh()
    return row
end

function Journal.Input(parent, width, height)
    local input = CreateFrame("EditBox", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    input:SetAutoFocus(false)
    input:SetSize(width, height)
    if input.SetBackdrop then
        input:SetBackdrop({
            bgFile = ns.MEDIA.white, edgeFile = ns.MEDIA.white, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        input:SetBackdropColor(ns.Colors.cream[1], ns.Colors.cream[2], ns.Colors.cream[3], 1)
        input:SetBackdropBorderColor(ns.Colors.ink[1], ns.Colors.ink[2], ns.Colors.ink[3], 0.7)
    end
    input:SetFontObject(Journal.Font(14))
    input:SetTextColor(ns.Colors.ink[1], ns.Colors.ink[2], ns.Colors.ink[3])
    input:SetTextInsets(8, 8, 0, 0)
    input:SetMaxLetters(80)
    return input
end

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
    weapon = true,
    pet = true,
    otherTrainer = true,
    spirit = true,
    battlemaster = true,
    barber = true,
    transmog = true,
    tabard = true,
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

-- Show diagnostic output in a selectable edit box. WoW does not expose a general
-- clipboard API to addons, but EditBox text can be copied with Ctrl+A / Ctrl+C.
function ns:ShowCopyableReport(title, lines)
    if not self.copyReportFrame then
        local frame = CreateFrame("Frame", "ForeverWayfinderCopyReportFrame", UIParent,
            BackdropTemplateMixin and "BackdropTemplate" or nil)
        frame:SetSize(760, 520)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetClampedToScreen(true)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0.04, 0.035, 0.025, 0.98)
        frame:SetBackdropBorderColor(0.55, 0.44, 0.23, 1)

        local heading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        heading:SetPoint("TOPLEFT", 18, -16)
        heading:SetTextColor(0.95, 0.82, 0.48)
        frame.heading = heading

        local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        instructions:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -7)
        instructions:SetText("Click the report, press Ctrl+A, then Ctrl+C to copy. Press Esc to close.")

        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)

        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 18, -76)
        scroll:SetPoint("BOTTOMRIGHT", -38, 18)

        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(690)
        edit:SetTextInsets(6, 6, 6, 6)
        edit:SetScript("OnEscapePressed", function() frame:Hide() end)
        edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        scroll:SetScrollChild(edit)

        frame.editBox = edit
        frame.scrollFrame = scroll
        self.copyReportFrame = frame
    end

    local frame = self.copyReportFrame
    frame.heading:SetText(title or "Forever Wayfinder Report")
    local text = table.concat(lines or {}, "\n")
    frame.editBox:SetText(text)
    frame.editBox:SetHeight(math.max(480, (select(2, text:gsub("\n", "")) + 2) * 16))
    frame:Show()
    frame.editBox:SetFocus()
    frame.editBox:HighlightText()
end

function ns:CopyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = value
        end
    end
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
    db.schemaVersion = 1
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
    ns:Print("  /fw search - search NPCs by name, category, or zone")
    ns:Print("  /fw clear - clear the last Forever Wayfinder waypoint")
    ns:Print("  /fw status - show index statistics")
    ns:Print("  /fw map - diagnose map pins for the current map")
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
    elseif message == "search" then
        if ns.ToggleSearchUI then ns:ToggleSearchUI() end
    elseif message == "clear" then
        local ok, reason = ns.Waypoints:ClearLast()
        ns:Print(ok and "Waypoint cleared." or reason)
    elseif message == "status" then
        local lines = {}
        local function ReportLine(text)
            text = tostring(text)
            lines[#lines + 1] = text
            ns:Print(text)
        end

        local scan = ns.scan
        if ns.blocked then
            ReportLine("Disabled: " .. ns.blocked)
        elseif not ns.ready then
            local status = "Indexing"
            if scan then
                status = status .. (" (%d / %d NPCs"):format(scan.npcPos - 1, #scan.npcIds)
                if scan.phase == "objects" then
                    status = status .. (", %d / %d objects"):format(scan.objPos - 1, #scan.objIds)
                end
                status = status .. ")"
            elseif ns.lastScan and ns.lastScan.state then
                status = status .. " (last scan: " .. ns.lastScan.state .. ")"
            end
            ReportLine(status)
            if ns.lastScan and ns.lastScan.reason then ReportLine(ns.lastScan.reason) end
        else
            ReportLine(("%d pins across %d maps from %d NPCs and %d objects."):format(
                ns.stat.nodes, ns.stat.mapCount, ns.stat.npcs, ns.stat.objects))
            ReportLine(("%d invalid records, %d invalid spawns, %d unavailable positions, %d unmapped areas."):format(
                ns.stat.invalidRecords or 0, ns.stat.invalidSpawns or 0,
                ns.stat.unavailablePositions or 0, ns.stat.unmappedAreas or 0))
            for reason, count in pairs(ns.stat.invalidSpawnReasons or {}) do
                ReportLine(("Invalid spawn reason: %s = %d"):format(reason, count))
            end
            for index, item in ipairs(ns.stat.invalidSpawnSamples or {}) do
                ReportLine(("Invalid spawn %d: %s (NPC/Object %s), zone %s, map %s, x=%s, y=%s, reason=%s"):format(
                    index, tostring(item.name), tostring(item.id), tostring(item.zoneID),
                    tostring(item.mapID), tostring(item.x), tostring(item.y), tostring(item.reason)))
            end
            for index, item in ipairs(ns.stat.unavailablePositionSamples or {}) do
                ReportLine(("Unavailable position %d: %s (NPC/Object %s), area %s, map %s; QuestieDB has no coordinates."):format(
                    index, tostring(item.name), tostring(item.id), tostring(item.zoneID), tostring(item.mapID)))
            end
            for index, item in ipairs(ns.stat.unmappedAreaSamples or {}) do
                ReportLine(("Unmapped area %d: %s (NPC/Object %s), area %s, spawn records %d"):format(
                    index, tostring(item.name), tostring(item.id), tostring(item.areaID), item.spawnCount or 0))
            end
            if ns.lastScan then
                ReportLine(("Last scan: %s; enumeration %.3fs; duration %.3fs; NPC errors %d; object errors %d."):format(
                    ns.lastScan.state or "unknown", ns.lastScan.enumerationDuration or 0,
                    ns.lastScan.duration or 0, ns.stat.npcErrors or 0, ns.stat.objectErrors or 0))
                ReportLine(("Max scan slice: %.4fs / %d records."):format(
                    ns.lastScan.maxSliceDuration or 0, ns.lastScan.maxSliceProcessed or 0))
                for index, item in ipairs(ns.lastScan.errors or {}) do
                    ReportLine(("Sample error %d (%s %s): %s"):format(
                        index, item.kind, tostring(item.id), item.message))
                end
            end
        end
        ns:ShowCopyableReport("Forever Wayfinder - Status", lines)
    elseif message == "map" then
        local lines = {}
        local function ReportLine(msg)
            msg = tostring(msg)
            lines[#lines + 1] = msg
            ns:Print(msg)
        end
        local function Safe(label, fn)
            local ok, a = pcall(fn)
            if ok then return a end
            ReportLine(label .. " ERROR: " .. tostring(a))
            return nil
        end

        ReportLine(("ready=%s enabled=%s showWorldMap=%s showMinimap=%s showOnContinent=%s"):format(
            tostring(ns.ready), tostring(ns.db and ns.db.enabled), tostring(ns.db and ns.db.showWorldMap),
            tostring(ns.db and ns.db.showMinimap), tostring(ns.db and ns.db.showOnContinent)))
        ReportLine(("blocked=%s registered=%s plugin=%s"):format(
            tostring(ns.blocked), tostring(ns.registered), tostring(ns.PLUGIN)))
        if ns.lastScan then ReportLine("lastScan=" .. tostring(ns.lastScan.state)) end

        if HandyNotes then
            ReportLine(("HandyNotes enabled=%s pluginRegistered=%s"):format(
                tostring(HandyNotes.IsEnabled and HandyNotes:IsEnabled()),
                tostring(HandyNotes.plugins and HandyNotes.plugins[ns.PLUGIN] ~= nil)))
            local enabledPlugins = HandyNotes.db and HandyNotes.db.profile and HandyNotes.db.profile.enabledPlugins
            if enabledPlugins then
                ReportLine("enabledPlugins[plugin]=" .. tostring(enabledPlugins[ns.PLUGIN]))
            end
            local provider = HandyNotes.WorldMapDataProvider
            if provider and WorldMapFrame and WorldMapFrame.dataProviders then
                ReportLine("worldMapProviderRegistered=" .. tostring(WorldMapFrame.dataProviders[provider] ~= nil))
            end
        else
            ReportLine("HandyNotes missing")
        end

        local wmID = WorldMapFrame and WorldMapFrame.GetMapID and
            Safe("WorldMapFrame:GetMapID", function() return WorldMapFrame:GetMapID() end)
        local playerID = Safe("GetBestMapForUnit", function() return C_Map.GetBestMapForUnit("player") end)
        ReportLine(("worldMapShown=%s worldMapID=%s playerMapID=%s"):format(
            tostring(WorldMapFrame and WorldMapFrame:IsShown()), tostring(wmID), tostring(playerID)))

        local target = wmID or playerID
        if target then
            local info = Safe("GetMapInfo", function() return C_Map.GetMapInfo(target) end)
            if info then
                ReportLine(("target map %s: name=%s type=%s parent=%s"):format(
                    tostring(target), tostring(info.name), tostring(info.mapType), tostring(info.parentMapID)))
            end
            local nodeCount = 0
            if ns.index and ns.index[target] then
                for _ in pairs(ns.index[target]) do nodeCount = nodeCount + 1 end
            end
            ReportLine(("index[%s] nodes=%d"):format(tostring(target), nodeCount))

            local maps = Safe("GetMapsFor", function() return ns:GetMapsFor(target, false) end)
            if maps then
                ReportLine(("GetMapsFor -> %d maps: %s"):format(#maps, table.concat(maps, ",")))
                local iterOk, iter, state, var = pcall(ns.MakeNodeIterator, ns, maps)
                if not iterOk then
                    ReportLine("MakeNodeIterator ERROR: " .. tostring(iter))
                else
                    local yielded, samples = 0, {}
                    local loopOk, loopErr = pcall(function()
                        for coord, mapID, icon in iter, state, var do
                            yielded = yielded + 1
                            if #samples < 5 then
                                samples[#samples + 1] = ("coord=%s map=%s icon=%s"):format(
                                    tostring(coord), tostring(mapID), tostring(icon))
                            end
                            if yielded >= 500 then break end
                        end
                    end)
                    ReportLine(("iterator yielded=%d%s"):format(
                        yielded, (not loopOk) and (" ERROR: " .. tostring(loopErr)) or ""))
                    for _, s in ipairs(samples) do ReportLine("  " .. s) end
                end
            end
        end

        if ns.db and ns.db.categories then
            local enabledCats = {}
            for key, value in pairs(ns.db.categories) do
                if value == true then enabledCats[#enabledCats + 1] = key end
            end
            table.sort(enabledCats)
            ReportLine("enabled categories: " .. table.concat(enabledCats, ","))
        end
        if target and ns.index and ns.index[target] then
            local catTally, skippedTally = {}, {}
            local total, withIcon, skipped = 0, 0, 0
            local skippedSamples = {}
            for _, node in pairs(ns.index[target]) do
                total = total + 1
                for key in pairs(node.cats or {}) do
                    catTally[key] = (catTally[key] or 0) + 1
                end
                if ns:GetNodeIcon(node) then
                    withIcon = withIcon + 1
                else
                    skipped = skipped + 1
                    local keys = {}
                    for key in pairs(node.cats or {}) do
                        keys[#keys + 1] = key
                        skippedTally[key] = (skippedTally[key] or 0) + 1
                    end
                    if #skippedSamples < 6 then
                        local first = node.entries and node.entries[1]
                        skippedSamples[#skippedSamples + 1] = ("%s cats=[%s]"):format(
                            (first and first.name) or "?", table.concat(keys, ","))
                    end
                end
            end
            ReportLine(("target nodes: total=%d withIcon=%d skipped=%d"):format(total, withIcon, skipped))
            local catParts = {}
            for key, count in pairs(catTally) do catParts[#catParts + 1] = key .. "=" .. count end
            table.sort(catParts)
            ReportLine("node cats: " .. table.concat(catParts, " "))
            local skipParts = {}
            for key, count in pairs(skippedTally) do skipParts[#skipParts + 1] = key .. "=" .. count end
            table.sort(skipParts)
            ReportLine("skipped-node cats: " .. table.concat(skipParts, " "))
            for _, s in ipairs(skippedSamples) do ReportLine("  skipped: " .. s) end
        end

        local sampleMaps = {}
        if ns.index then
            for mapID in pairs(ns.index) do
                sampleMaps[#sampleMaps + 1] = mapID
                if #sampleMaps >= 25 then break end
            end
            table.sort(sampleMaps)
        end
        ReportLine("index mapIDs sample: " .. table.concat(sampleMaps, ","))

        local tester = CreateFrame("Frame")
        local tex = tester:CreateTexture(nil, "ARTWORK")
        local badIcons, seen = {}, {}
        for _, category in ipairs(ns.categoryList) do
            local icon = category.icon
            if icon and not seen[icon] then
                seen[icon] = true
                if not tex:SetTexture(icon) then
                    badIcons[#badIcons + 1] = category.key .. "=" .. icon
                end
            end
        end
        if not tex:SetTexture("Interface\\Icons\\INV_Misc_Bag_10") then
            badIcons[#badIcons + 1] = "defaultVendor=Interface\\Icons\\INV_Misc_Bag_10"
        end
        tester:Hide()
        ReportLine(("icon check: %d invalid%s"):format(
            #badIcons, #badIcons > 0 and (": " .. table.concat(badIcons, "; ")) or ""))

        if HandyNotes and HandyNotes.WorldMapDataProvider and WorldMapFrame and WorldMapFrame:IsShown() then
            local ok, err = pcall(HandyNotes.WorldMapDataProvider.RefreshPlugin,
                HandyNotes.WorldMapDataProvider, ns.PLUGIN)
            ReportLine("RefreshPlugin direct: " .. (ok and "ok" or ("ERROR: " .. tostring(err))))
        end

        ns:ShowCopyableReport("Forever Wayfinder - Map", lines)
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
        self.stat = { nodes = 0, mapCount = 0, npcs = 0, objects = 0 }
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
