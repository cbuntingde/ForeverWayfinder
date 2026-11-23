local ADDON, ns = ...

-- The settings window shares the Cartographer's Column language with the map
-- sidebar: a branded spine down the left edge, a banded leather page, leather
-- section bands and ledger rows that carry the category badge on the left and
-- the control on the right.
local FRAME_WIDTH = 700
local FRAME_HEIGHT = 780
local SPINE_WIDTH = 28
local GUTTER = 16
local HEADER_HEIGHT = 64
local FOOTER_HEIGHT = 64

local CONTENT_LEFT = SPINE_WIDTH + GUTTER
local CONTENT_RIGHT = FRAME_WIDTH - GUTTER
local CONTENT_WIDTH = CONTENT_RIGHT - CONTENT_LEFT
-- The scrolling viewport is narrower than the page: the scroll bar sits on the
-- right edge, so the rows inside it must not reach under the bar.
local SCROLL_WIDTH = CONTENT_WIDTH - 32
-- Three columns keep every group on one page at the smallest UI scale; 22 px
-- rows still clear the 20 px badge and checkbox.
local GRID_COLUMNS = 3
local COLUMN_GAP = 16
local COLUMN_WIDTH = (SCROLL_WIDTH - COLUMN_GAP * (GRID_COLUMNS - 1)) / GRID_COLUMNS
local ROW_HEIGHT = 22
local LABEL_SIZE = 12
local SECTION_HEIGHT = 28
local SECTION_GAP = 8
local SCALE_ROW_HEIGHT = 30
local CONTENT_PAD = 16

local Journal = ns.Journal

-- Rows that switch a whole surface on or off. The map sidebar calls them
-- pins, so the window says the same thing.
local PIN_TOGGLES = {
    { key = "enabled", label = "Pins enabled" },
    { key = "showWorldMap", label = "World map pins" },
    { key = "showMinimap", label = "Minimap pins" },
    { key = "showOnContinent", label = "Continent pins" },
    { key = "factionFilter", label = "Hide enemy services" },
}

function ns:CreateUI()
    if self.uiFrame then return self.uiFrame end

    local frame = CreateFrame("Frame", "ForeverWayfinderFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    local screenHeight = UIParent:GetHeight() or FRAME_HEIGHT
    frame:SetSize(FRAME_WIDTH, math.min(FRAME_HEIGHT, screenHeight - 40))
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

    -- The page: a banded leather sheet with a printed border, the same
    -- treatment the map column carries.
    local backdrop = Journal.Solid(frame, ns.Colors.leatherDark)
    backdrop:SetAllPoints()
    frame.bands = Journal.Bands(frame, 12, ns.Column.pageTop)

    local spine = Journal.Spine(frame, "WAYFINDER", SPINE_WIDTH)
    frame.spine = spine
    Journal.HairlineRect(frame, 0, ns.Colors.goldLine, 0.85)

    -- The page and the spine are stacks of flat bands; they need the real
    -- window height before the falloff reads as a page and not as a stripe.
    local function LayoutBands()
        local height = frame:GetHeight() or 0
        if height <= 0 then return end
        Journal.LayoutBands(frame, frame.bands, ns.Column.pageTop, ns.Column.pageBottom, height)
        if frame.spine then
            Journal.LayoutBands(frame.spine, frame.spine.bands, ns.Column.spineTop,
                ns.Column.spineBottom, height)
        end
    end

    local position = self.db.uiPosition
    if position and position.point and type(position.x) == "number" and type(position.y) == "number" then
        frame:SetPoint(position.point, UIParent, position.relativePoint or position.point, position.x, position.y)
    else
        frame:SetPoint("CENTER")
    end

    -- Header: the product name, what it lists, and the close button.
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", SPINE_WIDTH, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(HEADER_HEIGHT)
    local headerFill = Journal.Solid(header, ns.Colors.leatherDark)
    headerFill:SetAllPoints()
    local headerRule = Journal.Solid(header, ns.Colors.goldLine)
    headerRule:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    headerRule:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    headerRule:SetHeight(1)
    headerRule:SetAlpha(0.85)
    frame.header = header

    local title = Journal.Text(header, 20, "Forever Wayfinder", ns.Colors.gold, "LEFT")
    title:SetPoint("TOPLEFT", GUTTER, -14)

    local subtitle = Journal.Text(header, 11, "Vendors · Trainers · Services · Points of interest",
        ns.Colors.muted, "LEFT")
    subtitle:SetPoint("TOPLEFT", GUTTER + 1, -42)

    local close = Journal.CloseButton(header, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT", -12, -14)

    -- The content page. It scrolls, so a group added later cannot silently
    -- push rows out of the window.
    local page = CreateFrame("Frame", nil, frame)
    page:SetPoint("TOPLEFT", CONTENT_LEFT, -(HEADER_HEIGHT + 8))
    page:SetPoint("BOTTOMRIGHT", -GUTTER, FOOTER_HEIGHT)
    local pageFill = Journal.Solid(page, ns.Column.pageFill)
    pageFill:SetAllPoints()
    local pageRule = Journal.Solid(page, ns.Colors.goldLine)
    pageRule:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    pageRule:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
    pageRule:SetHeight(1)
    pageRule:SetAlpha(0.4)
    frame.page = page

    local scroll = CreateFrame("ScrollFrame", "ForeverWayfinderSettingsScroll", page,
        "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -10)
    scroll:SetPoint("BOTTOMRIGHT", -22, 10)
    local scrollBar = Journal.SkinScrollBar(scroll)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(SCROLL_WIDTH, 1)
    scroll:SetScrollChild(content)
    frame.scroll = scroll
    frame.content = content

    -- Category sections: one band per group, a three-column grid of rows.
    local function GridPosition(index)
        local column = (index - 1) % GRID_COLUMNS
        local rowIndex = math.floor((index - 1) / GRID_COLUMNS)
        return column * (COLUMN_WIDTH + COLUMN_GAP), rowIndex * ROW_HEIGHT
    end
    local function GridRows(count)
        return math.ceil(count / GRID_COLUMNS)
    end

    frame.categoryRows = {}
    local y = 0
    for _, group in ipairs(ns.categoryGroups or {}) do
        Journal.SectionBand(content, 0, y, SCROLL_WIDTH, group.title)
        y = y - SECTION_HEIGHT - 6
        local keys = group.keys or {}
        for index, key in ipairs(keys) do
            local category = ns.categoryByKey[key]
            if category then
                local x, offset = GridPosition(index)
                frame.categoryRows[key] = Journal.LedgerRow(content,
                    x, y - offset, COLUMN_WIDTH, ROW_HEIGHT,
                    category.name, category.icon,
                    function() return ns.db.categories[key] end,
                    function(value) ns.db.categories[key] = value end, LABEL_SIZE)
            end
        end
        y = y - GridRows(#keys) * ROW_HEIGHT - SECTION_GAP
    end

    -- Display section: the five surface toggles and the four panel switches
    -- share one grid, so the whole page stays inside a single screen.
    Journal.SectionBand(content, 0, y, SCROLL_WIDTH, "DISPLAY")
    y = y - SECTION_HEIGHT - 6

    frame.toggleRows = {}
    for index, toggle in ipairs(PIN_TOGGLES) do
        local x, offset = GridPosition(index)
        local key = toggle.key
        frame.toggleRows[key] = Journal.LedgerRow(content,
            x, y - offset, COLUMN_WIDTH, ROW_HEIGHT, toggle.label, nil,
            function() return ns.db[key] end,
            function(value)
                ns.db[key] = value
                -- Faction filtering is applied while indexing, so pins only
                -- reflect the toggle after a rebuild.
                if key == "factionFilter" then ns:StartScan() end
            end, LABEL_SIZE)
    end

    local gridIndex = #PIN_TOGGLES
    local function NextGridRow(label, getter, setter)
        gridIndex = gridIndex + 1
        local x, offset = GridPosition(gridIndex)
        return Journal.LedgerRow(content, x, y - offset, COLUMN_WIDTH, ROW_HEIGHT,
            label, nil, getter, setter, LABEL_SIZE)
    end

    frame.minimapButtonRow = NextGridRow("Minimap button",
        function() return ns.db.showMinimapButton ~= false end,
        function(value)
            ns.db.showMinimapButton = value
            ns:UpdateMinimapButton()
        end)

    frame.browserRow = NextGridRow("Show panel with map",
        function() return ns.db.browserEnabled ~= false end,
        function(value)
            ns.db.browserEnabled = value
            local browser = ns.browser
            if browser and browser.panel and WorldMapFrame and WorldMapFrame:IsShown() then
                if value then browser:Show() else browser:Hide() end
            end
        end)

    frame.coordsRow = NextGridRow("Panel coordinates",
        function() return ns.db.browserCoords ~= false end,
        function(value)
            ns.db.browserCoords = value
            if ns.browser and ns.browser.UpdateLocation then ns.browser:UpdateLocation() end
        end)

    frame.nearMeRow = NextGridRow("Sort by distance",
        function() return ns.db.browserNearMe == true end,
        function(value)
            ns.db.browserNearMe = value
            if ns.browser and ns.browser.StyleNearButton then ns.browser:StyleNearButton() end
            ns:Refresh()
        end)

    y = y - GridRows(gridIndex) * ROW_HEIGHT - 8

    -- The active waypoint: the window says whether TomTom still holds one
    -- and clears it when the row is clicked.
    local waypointRow = CreateFrame("Button", nil, content)
    waypointRow:SetSize(SCROLL_WIDTH, ROW_HEIGHT)
    waypointRow:SetPoint("TOPLEFT", 0, y)
    waypointRow.hover = Journal.Solid(waypointRow, ns.Colors.pageHover)
    waypointRow.hover:SetAllPoints()
    waypointRow.hover:SetAlpha(0)
    local waypointLabel = Journal.Body(waypointRow, 13, "Waypoint", ns.Colors.text, "LEFT")
    waypointLabel:SetPoint("LEFT", 8, 0)
    waypointRow.label = waypointLabel
    waypointRow.state = Journal.Body(waypointRow, 11, "", ns.Colors.gold, "RIGHT")
    waypointRow.state:SetPoint("RIGHT", -8, 0)

    function waypointRow:Refresh()
        local hasWaypoint = ns.Waypoints and ns.Waypoints.HasWaypoint and ns.Waypoints:HasWaypoint()
        if hasWaypoint then
            self.state:SetText("SET · CLICK TO CLEAR")
            self.state:SetTextColor(ns.Colors.brightGold[1], ns.Colors.brightGold[2], ns.Colors.brightGold[3])
            self.label:SetTextColor(ns.Colors.text[1], ns.Colors.text[2], ns.Colors.text[3])
        else
            self.state:SetText("NONE")
            self.state:SetTextColor(ns.Colors.textMuted[1], ns.Colors.textMuted[2], ns.Colors.textMuted[3])
            self.label:SetTextColor(ns.Colors.textMuted[1], ns.Colors.textMuted[2], ns.Colors.textMuted[3])
        end
    end

    waypointRow:SetScript("OnEnter", function(self) self.hover:SetAlpha(0.45) end)
    waypointRow:SetScript("OnLeave", function(self) self.hover:SetAlpha(0) end)
    waypointRow:SetScript("OnClick", function(self)
        local ok, reason = ns.Waypoints:ClearLast()
        ns:Print(ok and "Waypoint cleared." or reason)
        self:Refresh()
    end)
    frame.waypointRow = waypointRow

    y = y - ROW_HEIGHT - 10

    -- Pin scale: the same slider the client uses in its own options.
    local scaleLabel = Journal.Body(content, 12, "Pin scale", ns.Colors.text, "LEFT")
    scaleLabel:SetPoint("TOPLEFT", 0, y)

    local slider = Journal.Slider(content, 220, 0.5, 1.5, 0.05)
    slider:SetPoint("LEFT", scaleLabel, "RIGHT", 12, 0)

    local scaleValue = Journal.Body(content, 12, "", ns.Colors.brightGold, "LEFT")
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
    y = y - SCALE_ROW_HEIGHT

    local contentHeight = math.max(-y + CONTENT_PAD, 1)
    content:SetHeight(contentHeight)

    -- The page fits at current UI scales; the scroll bar is only kept for
    -- screens too short to hold the page.
    if scrollBar and type(scrollBar.SetShown) == "function" then
        local viewport = (frame:GetHeight() or 0) - HEADER_HEIGHT - 8 - FOOTER_HEIGHT - 20
        scrollBar:SetShown(contentHeight > viewport)
    end

    -- Footer: what the index is doing, and the three actions.
    local footerRule = Journal.Solid(frame, ns.Colors.goldLine)
    footerRule:SetPoint("BOTTOMLEFT", SPINE_WIDTH, FOOTER_HEIGHT)
    footerRule:SetPoint("BOTTOMRIGHT", 0, FOOTER_HEIGHT)
    footerRule:SetHeight(1)
    footerRule:SetAlpha(0.5)
    frame.footerRule = footerRule

    frame.status = Journal.Body(frame, 12, "Starting...", ns.Colors.muted, "LEFT")
    frame.status:SetPoint("BOTTOMLEFT", CONTENT_LEFT, 48)
    frame.status:SetWidth(CONTENT_WIDTH)

    local progressBackground = Journal.Solid(frame, ns.Colors.leather)
    progressBackground:SetPoint("BOTTOMLEFT", CONTENT_LEFT, 38)
    progressBackground:SetSize(CONTENT_WIDTH, 3)

    frame.progressBar = Journal.Solid(frame, ns.Colors.gold, "ARTWORK")
    frame.progressBar:SetPoint("BOTTOMLEFT", CONTENT_LEFT, 38)
    frame.progressBar:SetSize(0, 3)

    frame.refreshButton = Journal.Button(frame, "Refresh", 96, function()
        ns:StartScan()
    end)
    frame.refreshButton:SetPoint("BOTTOMLEFT", CONTENT_LEFT, 12)

    frame.defaultsButton = Journal.Button(frame, "Defaults", 96, function()
        ns:ResetSettings()
    end)
    frame.defaultsButton:SetPoint("LEFT", frame.refreshButton, "RIGHT", 8, 0)

    frame.searchButton = Journal.Button(frame, "Search NPCs", 120, function()
        ns:ToggleSearchUI()
    end)
    frame.searchButton:SetPoint("LEFT", frame.defaultsButton, "RIGHT", 8, 0)

    local version = Journal.Text(frame, 12, "", ns.Colors.muted, "RIGHT")
    version:SetPoint("BOTTOMRIGHT", -GUTTER, 18)
    version:SetFormattedText("v%s", ns.VERSION)
    frame.version = version

    frame:Hide()
    self.uiFrame = frame

    table.insert(UISpecialFrames, "ForeverWayfinderFrame")

    LayoutBands()
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
    if frame.browserRow then
        frame.browserRow:Refresh()
    end
    if frame.coordsRow then
        frame.coordsRow:Refresh()
    end
    if frame.nearMeRow then
        frame.nearMeRow:Refresh()
    end
    if frame.waypointRow then
        frame.waypointRow:Refresh()
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
    local width = CONTENT_WIDTH

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
            bar:SetWidth(width * math.min(done / total, 1))
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
        bar:SetWidth(width)
        return
    end

    status:SetFormattedText("|cffd4af37%d|r pins · %d maps · %d NPCs · %d mailboxes",
        self.stat.nodes, self.stat.mapCount, self.stat.npcs, self.stat.mailboxes)
    bar:SetWidth(width)
end

function ns:ToggleUI()
    local frame = self.uiFrame or self:CreateUI()
    if frame:IsShown() then
        frame:Hide()
    else
        self:OpenSettings()
    end
end

-- Show the settings window without toggling it: the map sidebar opens this
-- from its own header button.
function ns:OpenSettings()
    local frame = self.uiFrame or self:CreateUI()
    self:UpdateUI()
    frame:Show()
    return frame
end
