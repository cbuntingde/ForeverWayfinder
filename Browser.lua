local ADDON, ns = ...

-- World-map location browser. The panel is a child of WorldMapFrame and docks to
-- the map's right edge; a round icon in the map's top-left icon stack toggles it.
local Browser = {}
ns.Browser = Browser
Browser.collapsed = {}

local Journal = ns.Journal
local PANEL_WIDTH = 320
local SECTION_HEIGHT = 22
local ZONE_HEIGHT = 18
local LINE_HEIGHT = 34
local MAX_LINES = 420
local ICON_SIZE = 32

local function GetWorldMapID()
    if WorldMapFrame and type(WorldMapFrame.GetMapID) == "function" then
        local ok, mapID = pcall(WorldMapFrame.GetMapID, WorldMapFrame)
        if ok and ns.ClassificationIsPositiveInteger(mapID) then return mapID end
    end
    if C_Map and type(C_Map.GetBestMapForUnit) == "function" then
        local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
        if ok and ns.ClassificationIsPositiveInteger(mapID) then return mapID end
    end
    return nil
end
ns.GetWorldMapID = GetWorldMapID

local function DesiredHeight()
    local height = WorldMapFrame and WorldMapFrame.GetHeight and WorldMapFrame:GetHeight() or 0
    if type(height) ~= "number" or height <= 0 then height = 640 end
    return math.max(420, math.min(height - 96, 880))
end

local function RaiseTo(region, parent, offset)
    region:SetFrameStrata("FULLSCREEN_DIALOG")
    if parent and parent.GetFrameLevel then
        local ok, level = pcall(parent.GetFrameLevel, parent)
        if ok and type(level) == "number" then region:SetFrameLevel(level + offset) end
    end
end

--------------------------------------------------------------------------------------------
-- Panel construction
--------------------------------------------------------------------------------------------

function Browser:PlaceDefault()
    self.panel:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -14, -56)
end

function Browser:RestorePosition()
    local position = ns.ValidateSavedPosition and ns.ValidateSavedPosition(ns.db.browserPosition) or nil
    if not position then
        self:PlaceDefault()
        return
    end
    local parent = position.relative == "ui" and UIParent or WorldMapFrame
    self.panel:SetPoint(position.point, parent, position.relativePoint, position.x, position.y)
end

function Browser:SavePosition()
    local point, relativeTo, relativePoint, x, y = self.panel:GetPoint(1)
    if type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then return end
    ns.db.browserPosition = {
        point = point,
        relativePoint = type(relativePoint) == "string" and relativePoint or point,
        x = x,
        y = y,
        relative = relativeTo == UIParent and "ui" or "frame",
    }
end

local function GetMapLabel(mapID)
    if C_Map and type(C_Map.GetMapInfo) == "function" and mapID then
        local ok, info = pcall(C_Map.GetMapInfo, mapID)
        if ok and type(info) == "table" and type(info.name) == "string" then return info.name end
    end
    return nil
end

-- Questie's Krowi_WorldMapButtons library owns the top-left icon stack shared with
-- Blizzard's map-pin button on this client. Registering through it is the only way
-- to guarantee the stack order, because it reflows every managed button whenever
-- the map changes. LibStub is a table with a __call metamethod, so test for
-- presence rather than type.
local function GetKrowiLib()
    if LibStub == nil then return nil end
    local ok, lib = pcall(LibStub, "Krowi_WorldMapButtons-1.4", true)
    if ok and type(lib) == "table" then return lib end
    return nil
end

local function FindStackLast()
    local lib = GetKrowiLib()
    if not lib or type(lib.Buttons) ~= "table" then return nil end
    local last
    for index = 1, #lib.Buttons do
        local button = lib.Buttons[index]
        if button then
            local shown = true
            if type(button.IsShown) == "function" then
                local shownOk, value = pcall(button.IsShown, button)
                shown = shownOk and value or true
            end
            if shown then last = button end
        end
    end
    return last
end

local function FindPinButton()
    local member = WorldMapFrame and WorldMapFrame.WorldMapTrackingPinButton
    if member then return member end
    local frames = WorldMapFrame and WorldMapFrame.overlayFrames
    if type(frames) ~= "table" or not WorldMapTrackingPinButtonMixin then return nil end
    for _, frame in pairs(frames) do
        if frame and frame.OnLoad == WorldMapTrackingPinButtonMixin.OnLoad then return frame end
    end
    return nil
end

function Browser:PlaceIcon()
    local icon = self.icon
    if not icon or icon.managed then return end
    local target = FindStackLast() or FindPinButton()
    icon.anchorTarget = target
    icon:ClearAllPoints()
    local shown = target and (type(target.IsShown) ~= "function" or target:IsShown())
    icon.anchorShown = shown
    if target and shown then
        icon:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 0, 0)
        return
    end
    local canvas = WorldMapFrame and WorldMapFrame.GetCanvasContainer and WorldMapFrame:GetCanvasContainer()
    if canvas then
        -- A hidden pin does not reserve its slot, so start at the canvas corner.
        icon:SetPoint("TOPLEFT", canvas, "TOPLEFT", 3, shown and -36 or 0)
    else
        icon:SetPoint("TOPLEFT", WorldMapFrame, "TOPLEFT", 14, shown and -72 or -36)
    end
end

-- Blizzard's pin template and Questie's button are both 32 px frames: a 25 px
-- minimap medallion at (3, -4), a 20 px glyph at (7, -6) and a 54 px tracking
-- border. Copy that geometry exactly so the icons read as one stack.
function Browser:StyleIcon(icon)
    icon.background = icon:CreateTexture(nil, "BACKGROUND")
    icon.background:SetTexture(ns.MEDIA.minimapBg)
    icon.background:SetSize(25, 25)
    icon.background:SetPoint("TOPLEFT", 3, -4)

    icon.glyph = icon:CreateTexture(nil, "ARTWORK")
    icon.glyph:SetTexture(ns.MEDIA.addonIcon)
    icon.glyph:SetSize(20, 20)
    icon.glyph:SetPoint("TOPLEFT", 7, -6)

    icon.border = icon:CreateTexture(nil, "OVERLAY", nil, 1)
    icon.border:SetTexture(ns.MEDIA.trackingBorder)
    icon.border:SetSize(54, 54)
    icon.border:SetPoint("TOPLEFT")

    icon:SetHighlightTexture(ns.MEDIA.minimapHighlight)
    local highlight = type(icon.GetHighlightTexture) == "function" and icon:GetHighlightTexture()
    if highlight and type(highlight.SetBlendMode) == "function" then highlight:SetBlendMode("ADD") end
end

function Browser:SetupIconScripts(icon)
    local browser = self
    icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    icon:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            if GameTooltip then GameTooltip:Hide() end
            if ns.ToggleSearchUI then ns:ToggleSearchUI() end
            return
        end
        if browser.panel:IsShown() then
            browser:Hide()
        else
            browser:Show()
        end
    end)
    icon:SetScript("OnEnter", function(self)
        if GameTooltip_SetDefaultAnchor then
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
        elseif GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        end
        if not GameTooltip then return end
        GameTooltip:AddLine("Forever Wayfinder", 1.00, 0.82, 0.00)
        if ns.ready and type(ns.stat) == "table" then
            GameTooltip:AddLine(("%d pins across %d maps"):format(ns.stat.nodes or 0, ns.stat.mapCount or 0),
                0.70, 0.67, 0.60)
        elseif not ns.ready then
            GameTooltip:AddLine("Indexing NPC data...", 0.70, 0.67, 0.60)
        end
        GameTooltip:AddLine(" ")
        local action = browser.panel:IsShown() and "Hide locations" or "Browse locations"
        GameTooltip:AddDoubleLine("Left Click", action, 0.30, 0.70, 1.00, 1.00, 1.00, 1.00)
        GameTooltip:AddDoubleLine("Right Click", "Search NPCs", 0.30, 0.70, 1.00, 1.00, 1.00, 1.00)
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    icon:SetScript("OnShow", function() browser:PlaceIcon() end)
    -- Sibling addons can join the stack after login. A once-a-second identity
    -- check converges self-anchored icons even when no map-change event fires.
    icon:SetScript("OnUpdate", function(self, delta)
        if self.managed then return end
        self.placementElapsed = (self.placementElapsed or 0) + (delta or 0)
        if self.placementElapsed < 1 then return end
        self.placementElapsed = 0
        local target = FindStackLast() or FindPinButton()
        local shown = target and (type(target.IsShown) ~= "function" or target:IsShown())
        if target ~= self.anchorTarget or shown ~= self.anchorShown then
            browser:PlaceIcon()
        end
    end)
end

function Browser:CreateIcon()
    local lib = GetKrowiLib()
    local icon
    -- Krowi's Add assigns the next slot, hooks map changes and reflows the stack.
    -- Its overlay table must exist so the Blizzard pin is captured before our
    -- button joins the stack; a pin-disabled game rule simply yields slot zero.
    if lib and lib.HasNoOverlay ~= true and type(lib.Add) == "function"
        and type(WorldMapFrame.overlayFrames) == "table" then
        local ok, created = pcall(lib.Add, lib, nil, "Button")
        if ok and created then
            icon = created
            icon.managed = true
            -- Krowi calls Refresh on every managed button after a map change.
            icon.Refresh = icon.Refresh or function() end
        end
    end
    if not icon then
        icon = CreateFrame("Button", "ForeverWayfinderBrowserIcon", WorldMapFrame)
        icon.managed = false
    end
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetFrameStrata("HIGH")
    self:StyleIcon(icon)
    self:SetupIconScripts(icon)
    self.icon = icon
    if icon.managed and type(lib.SetPoints) == "function" then
        pcall(lib.SetPoints)
    else
        self:PlaceIcon()
    end
    return icon
end

function Browser:EnsureIcon()
    if not WorldMapFrame then return nil end
    local icon = self.icon or self:CreateIcon()
    icon:Show()
    if icon.managed then
        -- Showing a previously hidden button can collapse a reserved slot;
        -- let Krowi reflow the stack now that visibility is final.
        local lib = GetKrowiLib()
        if lib and type(lib.SetPoints) == "function" then pcall(lib.SetPoints) end
    end
    return icon
end

function Browser:SkinScrollBar(scroll)
    local bar = scroll.ScrollBar
    if not bar and scroll.GetName then
        local name = scroll:GetName()
        if name then bar = _G[name .. "ScrollBar"] end
    end
    if not bar then return end
    if bar.ScrollUpButton then bar.ScrollUpButton:Hide() end
    if bar.ScrollDownButton then bar.ScrollDownButton:Hide() end
    local thumb = bar.ThumbTexture
    if thumb then
        thumb:SetTexture(ns.MEDIA.white)
        thumb:SetVertexColor(ns.Colors.goldLine[1], ns.Colors.goldLine[2], ns.Colors.goldLine[3], 0.45)
        if thumb.SetWidth then thumb:SetWidth(5) end
    end
    if bar.SetWidth then bar:SetWidth(8) end
end

function Browser:CreateLine(index)
    local panel = self.panel
    local line = CreateFrame("Button", nil, panel.content)
    line:SetPoint("TOPLEFT", 0, 0)
    line:SetPoint("TOPRIGHT", 0, 0)
    line:SetHeight(LINE_HEIGHT)

    line.background = Journal.Solid(line, ns.Colors.gold)
    line.background:SetAllPoints()
    line.background:SetAlpha(0)

    line.icon = line:CreateTexture(nil, "ARTWORK")
    line.icon:SetSize(16, 16)
    line.icon:SetPoint("TOPLEFT", 6, -4)

    line.title = Journal.Body(line, 12, "", ns.Colors.parchment, "LEFT")
    line.title:SetPoint("TOPLEFT", 28, -4)
    line.title:SetPoint("TOPRIGHT", -34, -4)

    -- Serif headings are reserved for section and zone labels; row copy stays
    -- in the UI face for legibility at this size.
    line.heading = Journal.Text(line, 12, "", ns.Colors.gold, "LEFT")
    line.heading:SetPoint("TOPLEFT", 28, -4)
    line.heading:SetPoint("TOPRIGHT", -34, -4)
    line.heading:Hide()

    line.detail = Journal.Body(line, 10, "", ns.Colors.muted, "LEFT")
    line.detail:SetPoint("TOPLEFT", 28, -19)
    line.detail:SetPoint("TOPRIGHT", -8, -19)

    line.count = Journal.Body(line, 10, "", ns.Colors.goldLine, "RIGHT")
    line.count:SetPoint("TOPRIGHT", -8, -5)
    line.count:Hide()

    line.rule = Journal.Solid(line, ns.Colors.goldLine)
    line.rule:SetHeight(1)
    line.rule:SetPoint("BOTTOMLEFT", 4, 0)
    line.rule:SetPoint("BOTTOMRIGHT", -4, 0)
    line.rule:SetAlpha(0.22)
    line.rule:Hide()

    line:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    line:SetScript("OnEnter", function(self)
        if self.kind == "row" then self.background:SetAlpha(0.10) end
    end)
    line:SetScript("OnLeave", function(self) self.background:SetAlpha(0) end)
    line:SetScript("OnClick", function(self, button)
        if self.kind == "section" then
            Browser.collapsed[self.sectionKey] = not Browser.collapsed[self.sectionKey]
            Browser:ScheduleRefresh(0)
            return
        end
        local row = self.row
        if not row then return end
        if button == "RightButton" then
            ns:FocusMap(row.mapID)
            return
        end
        local ok, reason = ns.Waypoints:Set(row.mapID, row.node.x, row.node.y, row.title)
        if not ok then ns:Print(reason) end
    end)

    panel.lines[index] = line
    return line
end

function Browser:GetMode()
    return ns.db.browserMode == "all" and "all" or "map"
end

function Browser:CreateScopeBar()
    local bar = CreateFrame("Frame", nil, self.panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    bar:SetSize(PANEL_WIDTH - 24, 26)
    bar:SetPoint("TOPLEFT", 12, -50)
    if bar.SetBackdrop then
        bar:SetBackdrop({
            bgFile = ns.MEDIA.white, edgeFile = ns.MEDIA.white, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        bar:SetBackdropColor(ns.Colors.leatherDark[1], ns.Colors.leatherDark[2],
            ns.Colors.leatherDark[3], 1)
        bar:SetBackdropBorderColor(ns.Colors.goldLine[1], ns.Colors.goldLine[2],
            ns.Colors.goldLine[3], 0.55)
    end
    local divider = Journal.Solid(bar, ns.Colors.goldLine)
    divider:SetPoint("TOP", bar, "TOP", 0, 0)
    divider:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
    divider:SetWidth(1)
    divider:SetAlpha(0.55)
    self.scopeBar = bar
    return bar
end

function Browser:CreateScopeButton(text, mode)
    local owner = self
    local width = math.floor((PANEL_WIDTH - 25) / 2)
    local button = CreateFrame("Button", nil, self.scopeBar)
    button:SetSize(width, 24)
    button.fill = Journal.Solid(button, ns.Colors.leatherDark)
    button.fill:SetAllPoints()
    button.label = Journal.Text(button, 12, text, ns.Colors.muted)
    button.label:SetPoint("CENTER", 0, 1)
    button.mark = Journal.Solid(button, ns.Colors.gold)
    button.mark:SetPoint("BOTTOMLEFT", 4, 0)
    button.mark:SetPoint("BOTTOMRIGHT", -4, 0)
    button.mark:SetHeight(2)
    button:SetScript("OnEnter", function(self)
        if owner:GetMode() ~= mode then
            self.label:SetTextColor(ns.Colors.gold[1], ns.Colors.gold[2], ns.Colors.gold[3])
            self.fill:SetColorTexture(ns.Colors.leather[1], ns.Colors.leather[2],
                ns.Colors.leather[3], 1)
        end
    end)
    button:SetScript("OnLeave", function() owner:UpdateScope() end)
    button:SetScript("OnClick", function()
        if owner:GetMode() == mode then return end
        ns.db.browserMode = mode
        owner:UpdateScope()
        owner:ScheduleRefresh(0)
    end)
    self.scopeButtons = self.scopeButtons or {}
    self.scopeButtons[mode] = button
    return button
end

function Browser:UpdateScope()
    local mode = self:GetMode()
    for key, button in pairs(self.scopeButtons or {}) do
        local active = key == mode
        local fill = active and ns.Colors.maroon or ns.Colors.leatherDark
        button.fill:SetColorTexture(fill[1], fill[2], fill[3], 1)
        local color = active and ns.Colors.brightGold or ns.Colors.muted
        button.label:SetTextColor(color[1], color[2], color[3])
        if active then button.mark:Show() else button.mark:Hide() end
    end
end

function ns:CreateBrowserUI()
    if self.browser and self.browser.panel then return self.browser end
    if not WorldMapFrame then return nil end

    local browser = Browser
    self.browser = browser
    browser.collapsed = browser.collapsed or {}

    local panel = CreateFrame("Frame", "ForeverWayfinderBrowserFrame", WorldMapFrame,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    browser.panel = panel
    panel:SetSize(PANEL_WIDTH, DesiredHeight())
    RaiseTo(panel, WorldMapFrame, 10)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        browser:SavePosition()
    end)
    Journal.Decorate(panel)
    Journal.Header(panel, 38)
    browser:RestorePosition()

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ns.MEDIA.addonIcon)
    icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", 12, -13)

    local title = Journal.Text(panel, 15, "LOCATIONS", ns.Colors.gold)
    title:SetPoint("TOPLEFT", 38, -13)

    local close = Journal.CloseButton(panel, function() browser:Hide() end)
    browser.closeButton = close
    close:SetPoint("TOPRIGHT", -14, -16)

    local context = Journal.Text(panel, 11, "", ns.Colors.goldLine, "RIGHT")
    context:SetPoint("TOPRIGHT", -38, -17)
    context:SetWidth(140)
    panel.context = context

    browser:CreateScopeBar()
    local scopeMap = browser:CreateScopeButton("THIS MAP", "map")
    scopeMap:SetPoint("TOPLEFT", 1, -1)
    local scopeAll = browser:CreateScopeButton("ALL ZONES", "all")
    scopeAll:SetPoint("TOPLEFT", 148, -1)
    browser:UpdateScope()

    local caption = Journal.Body(panel, 9, "FILTER", ns.Colors.goldLine, "LEFT")
    caption:SetPoint("TOPLEFT", 13, -82)

    local filter = Journal.Input(panel, PANEL_WIDTH - 24, 22)
    filter:SetPoint("TOPLEFT", 12, -96)
    local placeholder = Journal.Text(panel, 13, "Filter by name or category", ns.Colors.inkMuted, "LEFT")
    placeholder:SetPoint("LEFT", filter, "LEFT", 10, 0)
    placeholder:SetPoint("RIGHT", filter, "RIGHT", -8, 0)
    local function UpdatePlaceholder()
        local empty = (filter:GetText() or "") == ""
        local focused = type(filter.HasFocus) == "function" and filter:HasFocus()
        if empty and not focused then placeholder:Show() else placeholder:Hide() end
    end
    filter:SetScript("OnTextChanged", function()
        UpdatePlaceholder()
        browser:ScheduleRefresh(0.15)
    end)
    filter:SetScript("OnEditFocusGained", function() placeholder:Hide() end)
    filter:SetScript("OnEditFocusLost", UpdatePlaceholder)
    filter:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    filter:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    UpdatePlaceholder()
    panel.filter = filter
    panel.placeholder = placeholder

    local page = Journal.Page(panel, 8, -122, -8, 64)
    -- The browser is a dark drawer on the map frame, not a parchment book page.
    if page.SetBackdropColor then
        page:SetBackdropColor(ns.Colors.leatherDark[1], ns.Colors.leatherDark[2],
            ns.Colors.leatherDark[3], 1)
        page:SetBackdropBorderColor(ns.Colors.goldLine[1], ns.Colors.goldLine[2],
            ns.Colors.goldLine[3], 0.55)
    end
    local scroll = CreateFrame("ScrollFrame", "ForeverWayfinderBrowserScroll", page,
        "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -20, 6)
    browser:SkinScrollBar(scroll)
    panel.content = CreateFrame("Frame", nil, scroll)
    panel.content:SetSize(PANEL_WIDTH - 52, 1)
    scroll:SetScrollChild(panel.content)
    panel.lines = {}
    panel.scroll = scroll

    local footerRule = Journal.Solid(panel, ns.Colors.goldLine)
    footerRule:SetPoint("BOTTOMLEFT", 10, 58)
    footerRule:SetPoint("BOTTOMRIGHT", -10, 58)
    footerRule:SetHeight(1)
    footerRule:SetAlpha(0.5)

    panel.status = Journal.Body(panel, 10, "", ns.Colors.goldLine, "LEFT")
    panel.status:SetPoint("BOTTOMLEFT", 14, 34)
    panel.status:SetWidth(PANEL_WIDTH - 28)
    if panel.status.SetWordWrap then panel.status:SetWordWrap(false) end
    panel.status:SetHeight(12)

    local clear = Journal.Button(panel, "Clear waypoint", 112, function()
        local ok, reason = ns.Waypoints:ClearLast()
        ns:Print(ok and "Waypoint cleared." or reason)
    end)
    clear:SetPoint("BOTTOMRIGHT", -12, 6)

    -- Map changes do not consistently fire a hook on this client family; the 0.25 s
    -- poll only runs while the panel is visible and catches the gaps.
    local elapsed = 0
    panel:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed < 0.25 then return end
        elapsed = 0
        if not self:IsShown() or ns.blocked or not ns.ready then return end
        if browser:GetMode() == "map" and GetWorldMapID() ~= self.mapID then
            browser:ScheduleRefresh(0)
        end
    end)

    if WorldMapFrame.HookScript then
        WorldMapFrame:HookScript("OnShow", function()
            if ns.browser == browser then browser:AutoShow() end
        end)
    end
    if type(hooksecurefunc) == "function" and type(WorldMapFrame.SetMapID) == "function" then
        pcall(hooksecurefunc, WorldMapFrame, "SetMapID", function()
            if ns.browser == browser then
                browser:PlaceIcon()
                browser:ScheduleRefresh(0)
            end
        end)
    end

    -- Self-anchored icons need to follow a stack that other addons extend after
    -- login; Krowi-managed icons are reflowed by the library itself.
    local krowi = GetKrowiLib()
    if krowi and type(krowi.SetPoints) == "function" and type(hooksecurefunc) == "function" then
        pcall(hooksecurefunc, krowi, "SetPoints", function()
            if ns.browser == browser then browser:PlaceIcon() end
        end)
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(1, function()
            if ns.browser == browser then browser:PlaceIcon() end
        end)
    end

    panel:Hide()
    if WorldMapFrame:IsShown() then
        browser:AutoShow()
    elseif GetKrowiLib() and type(WorldMapFrame.overlayFrames) == "table" and not browser.icon then
        -- The map frame exists even while closed. Register now so Krowi assigns
        -- our slot after Blizzard's pin and reflows it on the first map change.
        browser:CreateIcon()
        browser.icon:Hide()
    end
    return browser
end

function ns:SetupBrowser()
    if self.browser and self.browser.panel then return self.browser end
    if WorldMapFrame then return self:CreateBrowserUI() end
    if not self.browserWaiter then
        local waiter = CreateFrame("Frame")
        waiter:RegisterEvent("ADDON_LOADED")
        waiter:RegisterEvent("PLAYER_LOGIN")
        waiter:SetScript("OnEvent", function(frame)
            if not WorldMapFrame then return end
            frame:UnregisterAllEvents()
            ns.browserWaiter = nil
            ns:CreateBrowserUI()
        end)
        self.browserWaiter = waiter
    end
    return nil
end

--------------------------------------------------------------------------------------------
-- Visibility
--------------------------------------------------------------------------------------------

function Browser:UpdateIcon()
    -- The icon lives on the map frame. Create it lazily: WorldMapFrame's overlay
    -- frames and Questie's button library may not exist until the map is built.
    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
    self:EnsureIcon()
    self:PlaceIcon()
end

function Browser:Show()
    ns.db.browserEnabled = true
    self:UpdateScope()
    self.panel:SetHeight(DesiredHeight())
    self.panel:Show()
    self:UpdateIcon()
    self:ScheduleRefresh(0)
end

function Browser:Hide()
    ns.db.browserEnabled = false
    self:SavePosition()
    self.panel:Hide()
    self:UpdateIcon()
end

function Browser:AutoShow()
    if ns.db.browserEnabled == false then
        self.panel:Hide()
        self:UpdateIcon()
        return
    end
    self:UpdateScope()
    self.panel:SetHeight(DesiredHeight())
    self.panel:Show()
    self:UpdateIcon()
    self:ScheduleRefresh(0)
end

function ns:ToggleBrowser()
    self:SetupBrowser()
    local browser = self.browser
    if not browser or not browser.panel then
        self:Print("The world map is not available yet; open the map once and try again.")
        return
    end
    if WorldMapFrame and WorldMapFrame:IsShown() and browser.panel:IsShown() then
        browser:Hide()
        return
    end
    if WorldMapFrame and not WorldMapFrame:IsShown() then
        if InCombatLockdown and InCombatLockdown() then
            self:Print("Cannot open the map during combat.")
            return
        end
        local opened = false
        if C_Map and type(C_Map.OpenWorldMap) == "function" then
            local mapID = GetWorldMapID()
            if mapID then opened = pcall(C_Map.OpenWorldMap, mapID) end
        end
        if not opened and type(WorldMapFrame.Show) == "function" then
            pcall(WorldMapFrame.Show, WorldMapFrame)
            opened = WorldMapFrame:IsShown()
        end
        if not opened then
            self:Print("Open the world map to browse its locations.")
            return
        end
    end
    browser:Show()
end

--------------------------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------------------------

function Browser:ScheduleRefresh(delay)
    self.generation = (self.generation or 0) + 1
    local generation = self.generation
    local function run()
        if generation ~= self.generation then return end
        self:Render()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0, run)
    else
        run()
    end
end

function Browser:HideLines()
    for index = 1, #self.panel.lines do self.panel.lines[index]:Hide() end
end

function Browser:Render()
    local panel = self.panel
    if not panel or not panel:IsShown() then return end

    if ns.blocked then
        panel.status:SetText("|cffff5555Disabled:|r " .. ns.blocked)
        panel.context:SetText("")
        self:HideLines()
        panel.content:SetHeight(1)
        panel.mapID = nil
        return
    end
    if not ns.ready then
        panel.status:SetText("Index is still loading. Locations appear when indexing completes.")
        panel.context:SetText("")
        self:HideLines()
        panel.content:SetHeight(1)
        panel.mapID = nil
        return
    end

    local mode = self:GetMode()
    panel.mode = mode

    local mapID
    if mode == "map" then
        mapID = GetWorldMapID()
        panel.mapID = mapID
        panel.context:SetText((GetMapLabel(mapID) or "THIS MAP"):upper())
        if not mapID then
            panel.status:SetText("Open the world map to browse its locations.")
            self:HideLines()
            panel.content:SetHeight(1)
            return
        end
    else
        panel.mapID = nil
        panel.context:SetText("ALL ZONES")
    end

    local query = panel.filter:GetText() or ""
    local sections = ns:BrowseEntries({
        maps = mode == "map" and { mapID } or nil,
        query = query,
        categories = ns.db and ns.db.categories,
    })

    local items, truncated = {}, false
    local function Push(item)
        if #items >= MAX_LINES then truncated = true; return false end
        items[#items + 1] = item
        return true
    end
    local full = false
    for sectionIndex = 1, #sections do
        local section = sections[sectionIndex]
        if section.total > 0 then
            if not Push({ kind = "section", section = section }) then full = true; break end
            if not self.collapsed[section.key] then
                local lastZone
                for rowIndex = 1, #section.rows do
                    local row = section.rows[rowIndex]
                    if mode == "all" and row.zoneName ~= lastZone then
                        lastZone = row.zoneName
                        if not Push({ kind = "zone", section = section, zone = row.zoneName }) then
                            full = true
                            break
                        end
                    end
                    if not Push({ kind = "row", section = section, row = row }) then
                        full = true
                        break
                    end
                end
            end
            if full then break end
        end
    end

    local y = 0
    for index = 1, #items do
        local item = items[index]
        local line = panel.lines[index] or self:CreateLine(index)
        local section = item.section
        line.kind = item.kind
        line.row = item.row
        line.sectionKey = section.key
        line.icon:SetTexture(section.icon)
        line.icon:SetAlpha(1)
        line.background:SetAlpha(0)
        line.count:Hide()
        line.detail:Hide()
        line.rule:Hide()
        line.title:Hide()
        line.heading:Hide()
        line:SetPoint("TOPLEFT", 0, -y)
        line:SetPoint("TOPRIGHT", 0, -y)

        if item.kind == "section" then
            line:SetHeight(SECTION_HEIGHT)
            line.icon:SetAlpha(0.85)
            local marker = self.collapsed[section.key] and "+" or "-"
            line.heading:ClearAllPoints()
            line.heading:SetPoint("TOPLEFT", 28, -4)
            line.heading:SetPoint("TOPRIGHT", -34, -4)
            line.heading:SetFormattedText("%s  %s", marker, section.name:upper())
            line.heading:SetTextColor(ns.Colors.gold[1], ns.Colors.gold[2], ns.Colors.gold[3])
            line.heading:Show()
            line.count:SetFormattedText("%d%s", section.total, section.capped and "+" or "")
            line.count:Show()
            line.rule:Show()
            y = y + SECTION_HEIGHT
        elseif item.kind == "zone" then
            line:SetHeight(ZONE_HEIGHT)
            line.icon:SetAlpha(0)
            line.heading:ClearAllPoints()
            line.heading:SetPoint("TOPLEFT", 34, -2)
            line.heading:SetPoint("TOPRIGHT", -30, -2)
            line.heading:SetText(item.zone)
            line.heading:SetTextColor(ns.Colors.goldLine[1], ns.Colors.goldLine[2], ns.Colors.goldLine[3])
            line.heading:Show()
            y = y + ZONE_HEIGHT
        else
            local row = item.row
            line:SetHeight(LINE_HEIGHT)
            line.title:SetText(row.name)
            line.title:SetTextColor(ns.Colors.parchment[1], ns.Colors.parchment[2], ns.Colors.parchment[3])
            line.title:Show()
            local detail = type(row.sub) == "string" and row.sub ~= "" and (row.sub .. "  ·  ") or ""
            line.detail:SetFormattedText("%s%.1f, %.1f", detail, row.node.x * 100, row.node.y * 100)
            line.detail:Show()
            y = y + LINE_HEIGHT
        end
        line:Show()
    end
    for index = #items + 1, #panel.lines do panel.lines[index]:Hide() end
    panel.content:SetHeight(math.max(y, 1))

    local total, categories, capped = 0, 0, false
    for index = 1, #sections do
        local section = sections[index]
        if section.total > 0 then
            total = total + section.total
            categories = categories + 1
            if section.capped then capped = true end
        end
    end

    if total == 0 then
        if query ~= "" then
            if mode == "all" then
                panel.status:SetFormattedText("No matches for \"%s\" in any zone.", query)
            else
                panel.status:SetFormattedText("No matches for \"%s\" on this map.", query)
            end
        elseif mode == "all" then
            panel.status:SetText("No indexed locations for the enabled categories.")
        else
            panel.status:SetText("No indexed locations on this map.")
        end
        return
    end

    local parts = {}
    if mode == "all" then parts[#parts + 1] = "All zones" end
    parts[#parts + 1] = ("%d location%s"):format(total, total == 1 and "" or "s")
    parts[#parts + 1] = ("%d categor%s"):format(categories, categories == 1 and "y" or "ies")
    if capped then parts[#parts + 1] = "capped" end
    if truncated then parts[#parts + 1] = "filter to narrow" end
    panel.status:SetText(table.concat(parts, " · "))
end

--------------------------------------------------------------------------------------------
-- Diagnostics
--------------------------------------------------------------------------------------------

local function GetRegionRect(region)
    if not region or type(region.GetLeft) ~= "function" then return nil end
    local ok, left, right, top, bottom = pcall(function()
        return region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
    end)
    if not ok or type(left) ~= "number" or type(right) ~= "number" then return nil end
    return left, right, top, bottom
end

local function RegionLabel(region)
    if not region then return "<none>" end
    if region == WorldMapFrame then return "WorldMapFrame" end
    local name = type(region.GetName) == "function" and region:GetName()
    return name or "<unnamed>"
end

local function OverlapSize(a, b)
    local aLeft, aRight, aTop, aBottom = GetRegionRect(a)
    local bLeft, bRight, bTop, bBottom = GetRegionRect(b)
    if not (aLeft and bLeft) then return nil end
    local width = math.min(aRight, bRight) - math.max(aLeft, bLeft)
    local height = math.min(aTop, bTop) - math.max(aBottom, bBottom)
    if width > 0.5 and height > 0.5 then return width, height end
    return 0, 0
end

-- Reports the real stack state: which library (if any) owns the icon, every
-- sibling's rect, and whether any two overlap. Run with /fw icon.
function Browser:DescribeIcon()
    local lines = {}
    local function Add(text) lines[#lines + 1] = tostring(text) end

    if not WorldMapFrame then
        Add("WorldMapFrame is not available on this client.")
        return lines
    end
    Add(("WorldMapFrame shown: %s"):format(WorldMapFrame:IsShown() and "yes" or "no"))
    local frames = WorldMapFrame.overlayFrames
    Add(("Overlay frames: %d"):format(type(frames) == "table" and #frames or 0))

    local lib = GetKrowiLib()
    if lib then
        Add(("Krowi_WorldMapButtons: present (Forever=%s, HasNoOverlay=%s, buttons=%d)"):format(
            tostring(lib.IsForever), tostring(lib.HasNoOverlay),
            type(lib.Buttons) == "table" and #lib.Buttons or 0))
        for index = 1, #(lib.Buttons or {}) do
            local button = lib.Buttons[index]
            local left, _, top = GetRegionRect(button)
            Add(("  [%d] %s shown=%s rect=%s"):format(index, RegionLabel(button),
                tostring(button:IsShown()),
                left and ("%.0f, %.0f"):format(left, top) or "unresolved"))
        end
    else
        Add("Krowi_WorldMapButtons: not loaded (Questie absent or still loading)")
    end

    local icon = self.icon
    if not icon then
        Add("Wayfinder icon: not created yet; open the world map once, then run /fw icon.")
        return lines
    end

    local point, relativeTo, relativePoint, x, y = icon:GetPoint(1)
    local strata = type(icon.GetFrameStrata) == "function" and icon:GetFrameStrata() or "?"
    Add(("Wayfinder icon: %s, shown=%s, strata=%s"):format(
        icon.managed and "Krowi-managed" or "self-anchored",
        tostring(icon:IsShown()), tostring(strata)))
    Add(("  anchor: %s -> %s %s offset %s, %s"):format(
        tostring(point), RegionLabel(relativeTo), tostring(relativePoint),
        tostring(x), tostring(y)))
    local left, right, top, bottom = GetRegionRect(icon)
    if left then
        Add(("  rect: %.0f..%.0f x %.0f..%.0f"):format(left, right, bottom, top))
    else
        Add("Overlap check: skipped (the map is not laid out; open it and retry).")
        return lines
    end

    local checked, overlaps = {}, 0
    local function Check(region, name)
        if not region or region == icon or checked[region] then return end
        checked[region] = true
        local width, height = OverlapSize(icon, region)
        if width and width > 0 then
            overlaps = overlaps + 1
            Add(("  OVERLAP with %s: %.0fx%.0f px"):format(name, width, height))
        end
    end
    Check(FindPinButton(), "Blizzard Map Pin")
    if lib and type(lib.Buttons) == "table" then
        for index = 1, #lib.Buttons do
            Check(lib.Buttons[index], "map button " .. index)
        end
    end
    Add(overlaps == 0 and "Overlap check: clear." or ("Overlap check: %d overlapping frame(s)."):format(overlaps))
    return lines
end
