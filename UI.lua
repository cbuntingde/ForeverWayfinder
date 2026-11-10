local ADDON, ns = ...

local FRAME_WIDTH = 520
local FRAME_HEIGHT = 640
local CONTENT_LEFT = 18
local CONTENT_RIGHT = 266
local ROW_WIDTH = 232
local ROW_HEIGHT = 24
local PROGRESS_WIDTH = FRAME_WIDTH - CONTENT_LEFT * 2

local function SetBackdrop(frame, background, border)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = ns.MEDIA.white,
        edgeFile = ns.MEDIA.tooltipBorder,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(background[1], background[2], background[3], background[4] or 1)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

local function CreateButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    button:SetSize(width, 22)
    SetBackdrop(button, { 0.12, 0.10, 0.07, 1 }, ns.Colors.frameBorder)

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    button.label:SetTextColor(0.93, 0.86, 0.66)

    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.22, 0.18, 0.10, 1)
        self.label:SetTextColor(1.00, 0.82, 0.00)
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.12, 0.10, 0.07, 1)
        self.label:SetTextColor(0.93, 0.86, 0.66)
    end)
    button:SetScript("OnClick", onClick)

    return button
end

local function CreateRow(parent, x, y, label, iconPath, getter, setter)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(ROW_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", x, y)

    row.hover = row:CreateTexture(nil, "BACKGROUND")
    row.hover:SetAllPoints()
    row.hover:SetColorTexture(0.20, 0.16, 0.09, 1)
    row.hover:SetAlpha(0)

    row.box = CreateFrame("Frame", nil, row, BackdropTemplateMixin and "BackdropTemplate" or nil)
    row.box:SetSize(16, 16)
    row.box:SetPoint("LEFT", 0, 0)
    SetBackdrop(row.box, { 0.04, 0.04, 0.03, 1 }, { 0.45, 0.37, 0.20, 1 })

    row.mark = row.box:CreateTexture(nil, "ARTWORK")
    row.mark:SetTexture(ns.MEDIA.checkbox)
    row.mark:SetSize(15, 15)
    row.mark:SetPoint("CENTER")
    row.mark:SetVertexColor(0.95, 0.78, 0.35)

    local textOffset = 24
    if iconPath then
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetTexture(iconPath)
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 24, 0)
        textOffset = 48
    end

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", textOffset, 0)
    row.label:SetWidth(ROW_WIDTH - textOffset)
    row.label:SetJustifyH("LEFT")
    row.label:SetText(label)

    function row:Refresh()
        local enabled = getter()
        self.mark:SetShown(enabled)
        if enabled then
            self.label:SetTextColor(0.90, 0.87, 0.78)
        else
            self.label:SetTextColor(0.55, 0.53, 0.47)
        end
    end

    row:SetScript("OnEnter", function(self)
        self.hover:SetAlpha(1)
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:SetAlpha(0)
    end)
    row:SetScript("OnClick", function(self)
        setter(not getter())
        self:Refresh()
        ns:Refresh()
    end)

    row:Refresh()
    return row
end

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
    SetBackdrop(frame, ns.Colors.dark, ns.Colors.frameBorder)

    local position = self.db.uiPosition
    if position and position.point and type(position.x) == "number" and type(position.y) == "number" then
        frame:SetPoint(position.point, UIParent, position.relativePoint or position.point, position.x, position.y)
    else
        frame:SetPoint("CENTER")
    end

    local header = frame:CreateTexture(nil, "BACKGROUND")
    header:SetColorTexture(0.14, 0.11, 0.07, 0.9)
    header:SetPoint("TOPLEFT", 8, -8)
    header:SetPoint("TOPRIGHT", -8, -8)
    header:SetHeight(50)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -17)
    title:SetText("|cffd4af37FOREVER WAYFINDER|r")

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOP", 0, -37)
    subtitle:SetText("Vendors · Trainers · Services")
    subtitle:SetTextColor(0.62, 0.59, 0.52)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() frame:Hide() end)

    frame.categoryRows = {}

    local y = -72
    for _, group in ipairs(ns.categoryGroups) do
        local headerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        headerText:SetPoint("TOPLEFT", CONTENT_LEFT, y)
        headerText:SetText("|cffd4af37" .. group.title .. "|r")

        y = y - 18
        for index, key in ipairs(group.keys) do
            local category = ns.categoryByKey[key]
            local column = (index - 1) % 2
            local rowIndex = math.floor((index - 1) / 2)
            local x = column == 0 and CONTENT_LEFT or CONTENT_RIGHT
            local rowY = y - rowIndex * ROW_HEIGHT

            local row = CreateRow(frame, x, rowY, category.name, category.icon,
                function() return ns.db.categories[key] end,
                function(value) ns.db.categories[key] = value end)
            frame.categoryRows[key] = row
        end

        y = y - math.ceil(#group.keys / 2) * ROW_HEIGHT - 12
    end

    local displayHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    displayHeader:SetPoint("TOPLEFT", CONTENT_LEFT, y)
    displayHeader:SetText("|cffd4af37DISPLAY|r")
    y = y - 18

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
        frame.toggleRows[key] = CreateRow(frame, x, rowY, toggle.label, nil,
            function() return ns.db[key] end,
            function(value) ns.db[key] = value end)
    end

    local minimapRowY = y - math.ceil(#toggles / 2) * ROW_HEIGHT
    frame.minimapButtonRow = CreateRow(frame, CONTENT_LEFT, minimapRowY, "Minimap button", nil,
        function() return not ns.db.hideMinimapButton end,
        function(value)
            ns.db.hideMinimapButton = not value
            ns:UpdateMinimapButton()
        end)

    local scaleLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleLabel:SetPoint("TOPLEFT", CONTENT_LEFT, minimapRowY - 28)
    scaleLabel:SetText("Pin scale")
    scaleLabel:SetTextColor(0.86, 0.83, 0.74)

    local slider = CreateFrame("Slider", nil, frame)
    slider:SetPoint("TOPLEFT", CONTENT_LEFT, minimapRowY - 46)
    slider:SetSize(210, 14)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(0.5, 1.5)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    slider:SetThumbTexture(ns.MEDIA.sliderThumb)

    local sliderBackground = slider:CreateTexture(nil, "BACKGROUND")
    sliderBackground:SetTexture(ns.MEDIA.sliderBg)
    sliderBackground:SetAllPoints()

    local scaleValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleValue:SetPoint("LEFT", slider, "RIGHT", 10, 0)
    scaleValue:SetTextColor(0.83, 0.69, 0.32)
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

    local footerLine = frame:CreateTexture(nil, "BACKGROUND")
    footerLine:SetColorTexture(0.55, 0.44, 0.23, 0.7)
    footerLine:SetPoint("BOTTOMLEFT", 10, 62)
    footerLine:SetPoint("BOTTOMRIGHT", -10, 62)
    footerLine:SetHeight(1)

    frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.status:SetPoint("BOTTOMLEFT", CONTENT_LEFT, 44)
    frame.status:SetTextColor(0.62, 0.59, 0.52)
    frame.status:SetText("Starting...")

    local progressBackground = frame:CreateTexture(nil, "BACKGROUND")
    progressBackground:SetColorTexture(0.12, 0.10, 0.07, 1)
    progressBackground:SetPoint("BOTTOMLEFT", CONTENT_LEFT, 35)
    progressBackground:SetSize(PROGRESS_WIDTH, 3)

    frame.progressBar = frame:CreateTexture(nil, "ARTWORK")
    frame.progressBar:SetColorTexture(0.83, 0.69, 0.32, 0.9)
    frame.progressBar:SetPoint("BOTTOMLEFT", CONTENT_LEFT, 35)
    frame.progressBar:SetSize(0, 3)

    frame.refreshButton = CreateButton(frame, "Refresh", 88, function()
        ns:StartScan()
    end)
    frame.refreshButton:SetPoint("BOTTOMLEFT", CONTENT_LEFT, 10)

    frame.defaultsButton = CreateButton(frame, "Defaults", 88, function()
        ns:ResetSettings()
    end)
    frame.defaultsButton:SetPoint("LEFT", frame.refreshButton, "RIGHT", 8, 0)

    frame.searchButton = CreateButton(frame, "Search NPCs", 112, function()
        ns:ToggleSearchUI()
    end)
    frame.searchButton:SetPoint("LEFT", frame.defaultsButton, "RIGHT", 8, 0)

    local version = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    version:SetPoint("BOTTOMRIGHT", -CONTENT_LEFT, 15)
    version:SetFormattedText("v%s", ns.VERSION)
    version:SetTextColor(0.40, 0.38, 0.33)

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
