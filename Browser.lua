local ADDON, ns = ...

-- World-map location browser. The panel is a child of WorldMapFrame, so it lives and
-- dies with the map; the tab reopens it after the close button records the preference.
local Browser = {}
ns.Browser = Browser
Browser.collapsed = {}

local Journal = ns.Journal
local PANEL_WIDTH = 300
local SECTION_HEIGHT = 20
local ZONE_HEIGHT = 18
local LINE_HEIGHT = 34
local MAX_LINES = 400
local SCOPE_WIDTH = 70

local VALID_ANCHORS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
    RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

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

local function GetCanvas()
    if WorldMapFrame and type(WorldMapFrame.GetCanvasContainer) == "function" then
        local ok, canvas = pcall(WorldMapFrame.GetCanvasContainer, WorldMapFrame)
        if ok and canvas then return canvas end
    end
    return nil
end

local function DesiredHeight(canvas)
    local height
    if canvas and canvas.GetHeight then height = canvas:GetHeight() end
    if type(height) ~= "number" or height <= 0 then
        height = WorldMapFrame.GetHeight and WorldMapFrame:GetHeight() or 0
    end
    if type(height) ~= "number" or height <= 0 then height = 520 end
    return math.max(320, math.min(height, 640))
end

local function RaiseTo(region, parent, offset)
    region:SetFrameStrata("FULLSCREEN_DIALOG")
    if parent.GetFrameLevel then
        local ok, level = pcall(parent.GetFrameLevel, parent)
        if ok and type(level) == "number" then region:SetFrameLevel(level + offset) end
    end
end

--------------------------------------------------------------------------------------------
-- Panel construction
--------------------------------------------------------------------------------------------

function Browser:PlaceDefault()
    if self.canvas then
        self.panel:SetPoint("TOPLEFT", self.canvas, "TOPRIGHT", 8, 0)
    else
        -- The map frame is usually full-screen; dock inside its right edge, below the
        -- navigation bar, where there is the least overlap with map controls.
        self.panel:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -24, -90)
    end
end

function Browser:RestorePosition()
    local position = type(ns.db.browserPosition) == "table" and ns.db.browserPosition or nil
    if not position or not VALID_ANCHORS[position.point] or not VALID_ANCHORS[position.relativePoint]
        or type(position.x) ~= "number" or type(position.y) ~= "number" then
        self:PlaceDefault()
        return
    end
    local parent = self.anchorParent
    if position.anchor == "canvas" and self.canvas then parent = self.canvas end
    self.panel:SetPoint(position.point, parent, position.relativePoint, position.x, position.y)
end

function Browser:SavePosition()
    local point, relativeTo, relativePoint, x, y = self.panel:GetPoint(1)
    if not VALID_ANCHORS[point] or not VALID_ANCHORS[relativePoint]
        or type(x) ~= "number" or type(y) ~= "number" then
        return
    end
    ns.db.browserPosition = {
        point = point, relativePoint = relativePoint, x = x, y = y,
        anchor = relativeTo == self.canvas and "canvas" or "frame",
    }
end

function Browser:PlaceTab()
    local point, relativeTo, relativePoint, x, y = self.panel:GetPoint(1)
    self.tab:ClearAllPoints()
    if point and relativeTo and relativePoint then
        self.tab:SetPoint(point, relativeTo, relativePoint, x, y)
    elseif point then
        self.tab:SetPoint(point, x or 0, y or 0)
    else
        self.tab:SetPoint("CENTER")
    end
end

function Browser:CreateLine(index)
    local panel = self.panel
    local line = CreateFrame("Button", nil, panel.content)
    line:SetPoint("TOPLEFT", 0, 0)
    line:SetPoint("TOPRIGHT", 0, 0)
    line:SetHeight(LINE_HEIGHT)

    line.background = Journal.Solid(line, ns.Colors.pageHover)
    line.background:SetAllPoints()
    line.background:SetAlpha(0)

    line.icon = line:CreateTexture(nil, "ARTWORK")
    line.icon:SetSize(16, 16)
    line.icon:SetPoint("TOPLEFT", 6, -4)

    line.title = Journal.Text(line, 13, "", ns.Colors.ink, "LEFT")
    line.title:SetPoint("TOPLEFT", 28, -4)
    line.title:SetPoint("TOPRIGHT", -6, -4)

    line.detail = Journal.Text(line, 11, "", ns.Colors.inkMuted, "LEFT")
    line.detail:SetPoint("TOPLEFT", 28, -19)
    line.detail:SetPoint("TOPRIGHT", -6, -19)

    line.rule = Journal.Solid(line, ns.Colors.inkMuted)
    line.rule:SetHeight(1)
    line.rule:SetPoint("BOTTOMLEFT", 4, 0)
    line.rule:SetPoint("BOTTOMRIGHT", -4, 0)
    line.rule:SetAlpha(0.35)
    line.rule:Hide()

    line:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    line:SetScript("OnEnter", function(self)
        if self.kind == "row" then self.background:SetAlpha(0.6) end
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

function Browser:CreateScopeButton(text, mode)
    local button = CreateFrame("Button", nil, self.panel,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    button:SetSize(SCOPE_WIDTH, 20)
    if button.SetBackdrop then
        button:SetBackdrop({
            bgFile = ns.MEDIA.white, edgeFile = ns.MEDIA.white, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
    end
    button.label = Journal.Text(button, 12, text, ns.Colors.inkMuted)
    button.label:SetPoint("CENTER")
    button:SetScript("OnClick", function()
        if self:GetMode() == mode then return end
        ns.db.browserMode = mode
        self:UpdateScope()
        self:ScheduleRefresh(0)
    end)
    self.scopeButtons = self.scopeButtons or {}
    self.scopeButtons[mode] = button
    return button
end

function Browser:UpdateScope()
    local mode = self:GetMode()
    for key, button in pairs(self.scopeButtons or {}) do
        local active = key == mode
        if button.SetBackdropColor then
            local fill = active and ns.Colors.maroon or ns.Colors.leatherDark
            button:SetBackdropColor(fill[1], fill[2], fill[3], 1)
        end
        local color = active and ns.Colors.brightGold or ns.Colors.muted
        button.label:SetTextColor(color[1], color[2], color[3])
    end
end

function ns:CreateBrowserUI()
    if self.browser and self.browser.panel then return self.browser end
    if not WorldMapFrame then return nil end

    local browser = Browser
    self.browser = browser

    browser.anchorParent = WorldMapFrame
    -- Dock beside the map canvas only when the frame leaves room for the panel;
    -- otherwise anchor inside the map frame's right edge so the panel is never offscreen.
    local canvas = GetCanvas()
    if canvas and canvas.GetWidth and WorldMapFrame.GetWidth then
        local canvasWidth, frameWidth = canvas:GetWidth(), WorldMapFrame:GetWidth()
        if type(canvasWidth) ~= "number" or type(frameWidth) ~= "number"
            or frameWidth <= 0 or canvasWidth + PANEL_WIDTH + 48 > frameWidth then
            canvas = nil
        end
    end
    browser.canvas = canvas
    browser.anchorKind = browser.canvas and "canvas" or "frame"
    browser.collapsed = browser.collapsed or {}

    local panel = CreateFrame("Frame", "ForeverWayfinderBrowserFrame", WorldMapFrame,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    browser.panel = panel
    panel:SetSize(PANEL_WIDTH, DesiredHeight(browser.canvas))
    RaiseTo(panel, WorldMapFrame, 10)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        browser:SavePosition()
        browser:PlaceTab()
    end)
    Journal.Decorate(panel)
    Journal.Header(panel, 44)
    browser:RestorePosition()

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ns.MEDIA.addonIcon)
    icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", 12, -13)

    local title = Journal.Text(panel, 16, "Locations", ns.Colors.gold)
    title:SetPoint("TOPLEFT", 36, -14)

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() browser:Hide() end)

    local caption = Journal.Text(panel, 11, "FILTER", ns.Colors.muted)
    caption:SetPoint("TOPLEFT", 12, -58)

    local filter = Journal.Input(panel, PANEL_WIDTH - 24, 22)
    filter:SetPoint("TOPLEFT", 12, -84)
    filter:SetScript("OnTextChanged", function() browser:ScheduleRefresh(0.15) end)
    filter:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    filter:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    panel.filter = filter

    local scopeMap = browser:CreateScopeButton("This map", "map")
    scopeMap:SetPoint("TOPRIGHT", -84, -58)
    local scopeAll = browser:CreateScopeButton("All zones", "all")
    scopeAll:SetPoint("TOPRIGHT", -10, -58)
    browser:UpdateScope()

    local page = Journal.Page(panel, 8, -114, -8, 40)
    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    panel.content = CreateFrame("Frame", nil, scroll)
    panel.content:SetSize(PANEL_WIDTH - 64, 1)
    scroll:SetScrollChild(panel.content)
    panel.lines = {}

    panel.status = Journal.Text(panel, 12, "", ns.Colors.muted, "LEFT")
    panel.status:SetPoint("BOTTOMLEFT", 12, 14)
    panel.status:SetWidth(PANEL_WIDTH - 136)

    local clear = Journal.Button(panel, "Clear waypoint", 112, function()
        local ok, reason = ns.Waypoints:ClearLast()
        ns:Print(ok and "Waypoint cleared." or reason)
    end)
    clear:SetPoint("BOTTOMRIGHT", -10, 10)

    local tab = CreateFrame("Button", "ForeverWayfinderBrowserTab", WorldMapFrame)
    browser.tab = tab
    tab:SetSize(28, 28)
    RaiseTo(tab, WorldMapFrame, 11)
    Journal.Solid(tab, ns.Colors.goldLine):SetAllPoints()
    local fill = Journal.Solid(tab, ns.Colors.leatherDark)
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", -1, 1)
    local tabIcon = tab:CreateTexture(nil, "ARTWORK")
    tabIcon:SetTexture(ns.MEDIA.addonIcon)
    tabIcon:SetSize(18, 18)
    tabIcon:SetPoint("CENTER")
    tab:SetScript("OnClick", function() browser:Show() end)
    tab:SetScript("OnEnter", function(self)
        if GameTooltip_SetDefaultAnchor then
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
        elseif GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        end
        if GameTooltip then
            GameTooltip:AddLine("Forever Wayfinder locations", 1.00, 0.82, 0.00)
            GameTooltip:AddLine("Click to browse locations.", 0.86, 0.83, 0.74)
            GameTooltip:Show()
        end
    end)
    tab:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

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
            if ns.browser == browser then browser:ScheduleRefresh(0) end
        end)
    end

    browser:PlaceTab()
    panel:Hide()
    tab:Hide()
    if WorldMapFrame:IsShown() then browser:AutoShow() end
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

function Browser:UpdateTab()
    if self.panel:IsShown() then self.tab:Hide() else self.tab:Show() end
end

function Browser:Show()
    ns.db.browserEnabled = true
    self:UpdateScope()
    self.panel:Show()
    self.tab:Hide()
    self:ScheduleRefresh(0)
end

function Browser:Hide()
    ns.db.browserEnabled = false
    self:SavePosition()
    self.panel:Hide()
    self:PlaceTab()
    self:UpdateTab()
end

function Browser:AutoShow()
    if ns.db.browserEnabled == false then
        self.panel:Hide()
        self:UpdateTab()
        return
    end
    self:UpdateScope()
    self.panel:Show()
    self.tab:Hide()
    self:ScheduleRefresh(0)
end

function ns:ToggleBrowser()
    self:SetupBrowser()
    local browser = self.browser
    if not browser or not browser.panel then
        self:Print("The world map is not available yet; open the map once and try again.")
        return
    end
    if browser.panel:IsShown() then
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
        self:HideLines()
        panel.content:SetHeight(1)
        panel.mapID = nil
        return
    end
    if not ns.ready then
        panel.status:SetText("Index is still loading. Locations appear when indexing completes.")
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
        if not mapID then
            panel.status:SetText("Open the world map to browse its locations.")
            self:HideLines()
            panel.content:SetHeight(1)
            return
        end
    else
        panel.mapID = nil
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
        line.title:SetTextColor(ns.Colors.ink[1], ns.Colors.ink[2], ns.Colors.ink[3])
        line.background:SetAlpha(0)
        line:SetPoint("TOPLEFT", 0, -y)
        line:SetPoint("TOPRIGHT", 0, -y)

        if item.kind == "section" then
            line:SetHeight(SECTION_HEIGHT)
            local marker = self.collapsed[section.key] and "+" or "-"
            line.title:SetFormattedText("%s  %s  (%d%s)", marker, section.name:upper(),
                section.total, section.capped and "+" or "")
            line.detail:Hide()
            line.rule:Show()
            y = y + SECTION_HEIGHT
        elseif item.kind == "zone" then
            line:SetHeight(ZONE_HEIGHT)
            line.icon:SetAlpha(0)
            line.title:SetTextColor(ns.Colors.inkMuted[1], ns.Colors.inkMuted[2], ns.Colors.inkMuted[3])
            line.title:SetText(item.zone or "Unknown zone")
            line.detail:Hide()
            line.rule:Hide()
            y = y + ZONE_HEIGHT
        else
            local row = item.row
            line:SetHeight(LINE_HEIGHT)
            line.title:SetText(row.name)
            local detail = type(row.sub) == "string" and row.sub ~= "" and (row.sub .. "  ·  ") or ""
            line.detail:SetFormattedText("%s%.1f, %.1f", detail, row.node.x * 100, row.node.y * 100)
            line.detail:Show()
            line.rule:Hide()
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
    if capped then parts[#parts + 1] = "capped per category" end
    if truncated then parts[#parts + 1] = "narrow the filter" end
    panel.status:SetText(table.concat(parts, " · "))
end
