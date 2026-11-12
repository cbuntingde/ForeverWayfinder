local ADDON, ns = ...

local FRAME_WIDTH = 660
local FRAME_HEIGHT = 700
local CONTENT_LEFT = 18
local CONTENT_RIGHT = 322
local ROW_WIDTH = 292
local ROW_HEIGHT = 24
local PROGRESS_WIDTH = FRAME_WIDTH - 48

local Journal = ns.Journal

function ns:CreateUI()
    if self.uiFrame then return self.uiFrame end

    local frame = CreateFrame("Frame", "ForeverWayfinderFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        ns.db.uiPosition = { point = point, relativePoint = relativePoint, x = x, y = y }
    end)
    Journal.Decorate(frame)

    local position = self.db.uiPosition
    if position and position.point and type(position.x) == "number" and type(position.y) == "number" then
        frame:SetPoint(position.point, UIParent, position.relativePoint or position.point, position.x, position.y)
    else
        frame:SetPoint("CENTER")
    end

    Journal.Header(frame, 56)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ns.MEDIA.addonIcon)
    icon:SetSize(26, 26)
    icon:SetPoint("TOPLEFT", 24, -24)

    local title = Journal.Text(frame, 24, "Forever Wayfinder", ns.Colors.gold)
    title:SetPoint("TOPLEFT", 58, -24)

    local subtitle = Journal.Text(frame, 13, "Vendors · Trainers · Services", ns.Colors.muted)
    subtitle:SetPoint("TOPLEFT", 59, -48)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -8, -8)
    close:SetScript("OnClick", function() frame:Hide() end)

    local page = Journal.Page(frame, 16, -76, -16, 84)

    frame.categoryRows = {}
    local y = -16
    for _, group in ipairs(ns.categoryGroups) do
        Journal.Section(page, CONTENT_LEFT, y, FRAME_WIDTH - 32 - CONTENT_LEFT * 2 + 12, group.title)
        y = y - 24
        for index, key in ipairs(group.keys) do
            local category = ns.categoryByKey[key]
            local column = (index - 1) % 2
            local rowIndex = math.floor((index - 1) / 2)
            local x = column == 0 and CONTENT_LEFT or CONTENT_RIGHT
            local rowY = y - rowIndex * ROW_HEIGHT
            frame.categoryRows[key] = Journal.CheckRow(page, x, rowY, ROW_WIDTH, ROW_HEIGHT,
                category.name, category.icon,
                function() return ns.db.categories[key] end,
                function(value) ns.db.categories[key] = value end)
        end
        y = y - math.ceil(#group.keys / 2) * ROW_HEIGHT - 12
    end

    Journal.Section(page, CONTENT_LEFT, y, FRAME_WIDTH - 32 - CONTENT_LEFT * 2 + 12, "Display")
    y = y - 24

    frame.toggleRows = {}
    local toggles = {
        { key = "enabled", label = "Pins enabled" },
        { key = "showWorldMap", label = "World map pins" },
        { key = "showMinimap", label = "Minimap pins" },
        { key = "showOnContinent", label = "Continent pins" },
        { key = "factionFilter", label = "Hide enemy services" },
    }
    for index, toggle in ipairs(toggles) do
        local column = (index - 1) % 2
        local rowIndex = math.floor((index - 1) / 2)
        local x = column == 0 and CONTENT_LEFT or CONTENT_RIGHT
        local rowY = y - rowIndex * ROW_HEIGHT
        local key = toggle.key
        frame.toggleRows[key] = Journal.CheckRow(page, x, rowY, ROW_WIDTH, ROW_HEIGHT, toggle.label, nil,
            function() return ns.db[key] end,
            function(value) ns.db[key] = value end)
    end

    local minimapRowY = y - math.ceil(#toggles / 2) * ROW_HEIGHT
    frame.minimapButtonRow = Journal.CheckRow(page, CONTENT_LEFT, minimapRowY, ROW_WIDTH, ROW_HEIGHT,
        "Minimap button", nil,
        function() return not ns.db.hideMinimapButton end,
        function(value)
            ns.db.hideMinimapButton = not value
            ns:UpdateMinimapButton()
        end)

    local scaleLabel = Journal.Text(page, 14, "Pin scale", ns.Colors.ink)
    scaleLabel:SetPoint("TOPLEFT", CONTENT_LEFT, minimapRowY - 30)

    local slider = CreateFrame("Slider", nil, page)
    slider:SetPoint("TOPLEFT", CONTENT_LEFT, minimapRowY - 48)
    slider:SetSize(230, 14)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(0.5, 1.5)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    slider:SetThumbTexture(ns.MEDIA.sliderThumb)

    local sliderBackground = slider:CreateTexture(nil, "BACKGROUND")
    sliderBackground:SetTexture(ns.MEDIA.sliderBg)
    sliderBackground:SetAllPoints()

    local scaleValue = Journal.Text(page, 14, "", ns.Colors.maroon)
    scaleValue:SetPoint("LEFT", slider, "RIGHT", 12, 0)
    scaleValue:SetFormattedText("%.2fx", self.db.pinScale or 1)
    frame.scaleValue = scaleValue
    frame.scaleSlider = slider

    slider:SetScript("OnValueChanged", function(_, value)
        ns.db.pinScale = value
        if frame.scaleValue then
            frame.scaleValue:SetFormattedText("%.2fx", value)
        end
    end)
    slider:SetScript("OnMouseUp", function()
        ns:Refresh()
    end)
    slider:SetValue(self.db.pinScale or 1)

    local footer = Journal.Solid(frame, ns.Colors.leatherDark)
    footer:SetPoint("BOTTOMLEFT", 10, 10)
    footer:SetPoint("BOTTOMRIGHT", -10, 10)
    footer:SetHeight(64)
    local footerRule = Journal.Solid(frame, ns.Colors.goldLine)
    footerRule:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, 0)
    footerRule:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
    footerRule:SetHeight(1)

    frame.status = Journal.Text(frame, 13, "Starting...", ns.Colors.muted, "LEFT")
    frame.status:SetPoint("BOTTOMLEFT", 24, 56)
    frame.status:SetWidth(PROGRESS_WIDTH)

    local progressBackground = Journal.Solid(frame, ns.Colors.leather)
    progressBackground:SetPoint("BOTTOMLEFT", 24, 46)
    progressBackground:SetSize(PROGRESS_WIDTH, 3)

    frame.progressBar = Journal.Solid(frame, ns.Colors.gold, "ARTWORK")
    frame.progressBar:SetPoint("BOTTOMLEFT", 24, 46)
    frame.progressBar:SetSize(0, 3)

    frame.refreshButton = Journal.Button(frame, "Refresh", 96, function()
        ns:StartScan()
    end)
    frame.refreshButton:SetPoint("BOTTOMLEFT", 24, 16)

    frame.defaultsButton = Journal.Button(frame, "Defaults", 96, function()
        ns:ResetSettings()
    end)
    frame.defaultsButton:SetPoint("LEFT", frame.refreshButton, "RIGHT", 8, 0)

    frame.searchButton = Journal.Button(frame, "Search NPCs", 120, function()
        ns:ToggleSearchUI()
    end)
    frame.searchButton:SetPoint("LEFT", frame.defaultsButton, "RIGHT", 8, 0)

    local version = Journal.Text(frame, 12, "", ns.Colors.muted)
    version:SetPoint("BOTTOMRIGHT", -24, 20)
    version:SetFormattedText("v%s", ns.VERSION)

    frame:Hide()
    self.uiFrame = frame

    table.insert(UISpecialFrames, "ForeverWayfinderFrame")

    self:UpdateUI()
    return frame
end

function ns:UpdateUI()
    local frame = self.uiFrame
    if not frame then return end

    if frame.categoryRows then
        for _, row in pairs(frame.categoryRows) do row:Refresh() end
    end
    if frame.toggleRows then
        for _, row in pairs(frame.toggleRows) do row:Refresh() end
    end
    if frame.minimapButtonRow then
        frame.minimapButtonRow:Refresh()
    end
    if frame.scaleSlider then
        frame.scaleSlider:SetValue(self.db.pinScale or 1)
    end

    self:UpdateUIStatus()
end

function ns:UpdateUIStatus()
    local frame = self.uiFrame
    if not frame or not frame.status then return end

    local status, bar = frame.status, frame.progressBar

    if self.blocked then
        status:SetText("|cffff5555Disabled:|r " .. self.blocked)
        bar:SetWidth(0)
        return
    end

    if not self.ready then
        local scan = self.scan
        if scan then
            local done = scan.npcPos - 1
            local total = #scan.npcIds
            if scan.phase == "objects" then
                done = done + scan.objPos - 1
                total = total + #scan.objIds
            end
            if total < 1 then total = 1 end
            status:SetFormattedText("Indexing... %d / %d", done, total)
            bar:SetWidth(PROGRESS_WIDTH * math.min(done / total, 1))
        elseif self.lastScan and self.lastScan.state == "failed" then
            status:SetText("|cffff5555Indexing failed:|r " .. tostring(self.lastScan.reason or "see /fw status"))
            bar:SetWidth(0)
        elseif self.lastScan and self.lastScan.state == "blocked" then
            status:SetText("|cffff5555Disabled:|r " .. tostring(self.lastScan.reason or self.blocked or "dependency error"))
            bar:SetWidth(0)
        else
            status:SetText("Waiting to index QuestieDB data...")
            bar:SetWidth(0)
        end
        return
    end

    if self.db and self.db.enabled == false then
        status:SetFormattedText("Pins disabled · |cffd4af37%d|r indexed", self.stat.nodes)
        bar:SetWidth(PROGRESS_WIDTH)
        return
    end

    status:SetFormattedText("|cffd4af37%d|r pins · %d maps · %d NPCs · %d objects",
        self.stat.nodes, self.stat.mapCount, self.stat.npcs, self.stat.objects)
    bar:SetWidth(PROGRESS_WIDTH)
end

function ns:ToggleUI()
    local frame = self.uiFrame or self:CreateUI()
    if frame:IsShown() then
        frame:Hide()
    else
        self:UpdateUI()
        frame:Show()
    end
end