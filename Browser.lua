local ADDON, ns = ...

-- World-map location browser. The panel is a child of WorldMapFrame and docks to
-- the map's right edge; a round icon in the map's top-left icon stack toggles it.
local Browser = {}
ns.Browser = Browser
Browser.collapsed = {}

local Journal = ns.Journal

-- Cartographer's Column: the map sidebar carries its own chrome instead of
-- reusing the settings dialog, because it is a narrow docked column that has
-- to read as part of the map rather than as a window floating over it.
local SPINE_WIDTH = 28
local GUTTER = 14
local PANEL_WIDTH = 380
local COLLAPSED_WIDTH = 220
local COLLAPSED_HEIGHT = 84

-- Spacing scale on a 4 px base. Every gap in the column comes from this table
-- so the vertical rhythm survives a change in one block's height.
local SPACE_XS, SPACE_SM, SPACE_MD, SPACE_LG = 4, 8, 12, 16

local HEADER_HEIGHT = 44
local STRIP_HEIGHT = 28
local FILTER_HEIGHT = 28
local SCOPE_HEIGHT = 24
local CHIP_HEIGHT = 24
local CHIP_GAP = 8
local FACET_COLUMNS = 3
local NEAR_WIDTH = 84
local FOOTER_HEIGHT = 32

-- The map draws its cursor strip and title bar over the top of the frame; the
-- column starts below that band instead of covering it.
local MAP_TOP_INSET = 112

local CONTENT_LEFT = SPINE_WIDTH + GUTTER
local CONTENT_RIGHT = PANEL_WIDTH - GUTTER
local CONTENT_WIDTH = CONTENT_RIGHT - CONTENT_LEFT

local SECTION_HEIGHT = 28
local ZONE_HEIGHT = 22
local LINE_HEIGHT = 38
local MAX_LINES = 420
local ICON_SIZE = 32

-- Rows carry a fixed right-hand column: the distance beside the name and the
-- map coordinates under it. Keeping them out of the text column is what stops
-- a long role from wrapping the coordinates onto a second line.
local ROW_RIGHT = 72
local ROW_INDENT = 36
local LIST_WIDTH = CONTENT_WIDTH - 20
local ROW_TEXT_WIDTH = LIST_WIDTH - ROW_INDENT - ROW_RIGHT

-- Page and spine falloffs, top to bottom. The page is opaque so the map art
-- behind the column never bleeds through it.
local PAGE_TOP = ns.Column.pageTop
local PAGE_BOTTOM = ns.Column.pageBottom
local SPINE_TOP = ns.Column.spineTop
local SPINE_BOTTOM = ns.Column.spineBottom
local PAGE_FILL = ns.Column.pageFill

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

-- HereBeDragons ships inside HandyNotes, a hard dependency, so yard distances
-- need no extra dependency. Targets on another instance/continent return nil.
local function GetHBD()
    if LibStub == nil then return nil end
    local ok, lib = pcall(LibStub, "HereBeDragons-2.0", true)
    if ok and type(lib) == "table" then return lib end
    return nil
end

local function GetPlayerZonePosition()
    local hbd = GetHBD()
    if hbd and type(hbd.GetPlayerZonePosition) == "function" then
        local ok, x, y, mapID = pcall(hbd.GetPlayerZonePosition, hbd)
        if ok and type(mapID) == "number" and ns.ClassificationIsFiniteNumber(x)
            and ns.ClassificationIsFiniteNumber(y) then
            return mapID, x, y
        end
    end
    local info = ns.Location and ns.Location:Read()
    if info and info.mapID and info.x and info.y then
        return info.mapID, info.x / 100, info.y / 100
    end
end

local function DistanceTo(playerMap, playerX, playerY, mapID, x, y)
    if not playerMap or not mapID then return nil end
    local hbd = GetHBD()
    if not hbd or type(hbd.GetZoneDistance) ~= "function" then return nil end
    local ok, distance = pcall(hbd.GetZoneDistance, hbd, playerMap, playerX, playerY, mapID, x, y)
    if ok and ns.ClassificationIsFiniteNumber(distance) and distance >= 0 then return distance end
    return nil
end

local function CursorUI()
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    return x / scale, y / scale
end

-- Blizzard's map quest sidebar owns the right edge when shown. Docking to it
-- keeps the two panels side by side instead of stacked.
local function GetQuestSidebar()
    local frame = _G.QuestMapFrame
    if not frame or type(frame.IsShown) ~= "function" or type(frame.GetWidth) ~= "function" then
        return nil
    end
    local shownOk, shown = pcall(frame.IsShown, frame)
    if not shownOk or not shown then return nil end
    local widthOk, width = pcall(frame.GetWidth, frame)
    if not widthOk or type(width) ~= "number" or width < 40 then return nil end
    return frame
end

-- Exposed so the status report can name the live dock target instead of
-- whatever was docked when the panel was first placed.
ns.GetQuestSidebar = GetQuestSidebar

local function DesiredHeight()
    local height = WorldMapFrame and WorldMapFrame.GetHeight and WorldMapFrame:GetHeight() or 0
    if type(height) ~= "number" or height <= 0 then height = 640 end
    return math.max(440, math.min(height - MAP_TOP_INSET - 16, 880))
end

local function RaiseTo(region, parent, offset)
    region:SetFrameStrata("FULLSCREEN_DIALOG")
    if parent and parent.GetFrameLevel then
        local ok, level = pcall(parent.GetFrameLevel, parent)
        if ok and type(level) == "number" then region:SetFrameLevel(level + offset) end
    end
end

--------------------------------------------------------------------------------------------
-- Column chrome
--------------------------------------------------------------------------------------------

-- The column's own chrome: a dark leather page with a soft falloff, a printed
-- double rule, and a branded spine down the map-facing edge.
function Browser:StyleColumn(panel)
    panel.bands = Journal.Bands(panel, 12, PAGE_TOP)

    local spine = Journal.Spine(panel, "LOCATIONS", SPINE_WIDTH)
    panel.spine = spine
    panel.spineLabel = spine.label

    -- Gutter rule: a second hairline just inside the spine, like the fold of
    -- a printed sheet.
    local gutter = Journal.Solid(panel, ns.Colors.goldLine)
    gutter:SetPoint("TOPLEFT", SPINE_WIDTH + 4, 4)
    gutter:SetPoint("BOTTOMLEFT", SPINE_WIDTH + 4, -4)
    gutter:SetWidth(1)
    gutter:SetAlpha(0.18)

    Journal.HairlineRect(panel, 0, ns.Colors.goldLine, 0.85)
end

--------------------------------------------------------------------------------------------
-- Panel construction
--------------------------------------------------------------------------------------------

function Browser:PlaceDefault()
    self.panel:ClearAllPoints()
    local sidebar = GetQuestSidebar()
    if sidebar then
        self.questSidebar = sidebar
        local ok = pcall(self.panel.SetPoint, self.panel, "TOPRIGHT", sidebar, "TOPLEFT", -8, 0)
        if ok then return end
    end
    self.questSidebar = nil
    self.panel:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -14, -MAP_TOP_INSET)
end

-- A saved position can put the column under the map's cursor strip and title
-- bar, so a restored anchor is pulled down until its top clears that band.
function Browser:KeepBelowMapHeader()
    local panel = self.panel
    local frame = WorldMapFrame
    if not panel or not frame or type(panel.GetTop) ~= "function" then return end
    local mapTop = type(frame.GetTop) == "function" and frame:GetTop() or nil
    local panelTop = panel:GetTop()
    if type(mapTop) ~= "number" or type(panelTop) ~= "number" then return end
    local limit = mapTop - MAP_TOP_INSET
    if panelTop <= limit then return end
    local mapRight = type(frame.GetRight) == "function" and frame:GetRight() or nil
    local panelRight = type(panel.GetRight) == "function" and panel:GetRight() or nil
    if type(mapRight) ~= "number" or type(panelRight) ~= "number" then return end
    panel:ClearAllPoints()
    panel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", panelRight - mapRight, -MAP_TOP_INSET)
end

function Browser:RestorePosition()
    local position = ns.ValidateSavedPosition and ns.ValidateSavedPosition(ns.db.browserPosition) or nil
    if not position then
        self:PlaceDefault()
        return
    end
    self.panel:ClearAllPoints()
    local parent = position.relative == "ui" and UIParent or WorldMapFrame
    self.panel:SetPoint(position.point, parent, position.relativePoint, position.x, position.y)
    if position.relative ~= "ui" then self:KeepBelowMapHeader() end
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
    Journal.SkinScrollBar(scroll)
end

-- Font strings wrap by default, and a wrapped row spills into the row below
-- it. Trim the label to the room the row gives it so every line stays single
-- line and the right-hand column keeps its place.
local FitText = Journal.FitText

function Browser:CreateLine(index)
    local panel = self.panel
    local line = CreateFrame("Button", nil, panel.content)
    line:SetPoint("TOPLEFT", 0, 0)
    line:SetPoint("TOPRIGHT", 0, 0)
    line:SetHeight(LINE_HEIGHT)

    line.background = Journal.Solid(line, ns.Colors.pageHover)
    line.background:SetAllPoints()
    line.background:SetAlpha(0)

    -- Two-unit gold bar at the hovered row's edge, the list's only motion cue.
    line.accent = Journal.Solid(line, ns.Colors.gold)
    line.accent:SetPoint("TOPLEFT", 0, -6)
    line.accent:SetPoint("BOTTOMLEFT", 0, 6)
    line.accent:SetWidth(2)
    line.accent:Hide()

    -- Icon badge: the category glyph sits in a dark socket, so it reads as a
    -- token on the ledger rather than a loose picture.
    line.badge = CreateFrame("Frame", nil, line)
    line.badge:SetSize(22, 22)
    line.badge:SetPoint("LEFT", 6, 0)
    line.badgeFill = Journal.Solid(line.badge, ns.Colors.leatherDark)
    line.badgeFill:SetAllPoints()

    line.icon = line.badge:CreateTexture(nil, "ARTWORK")
    line.icon:SetSize(16, 16)
    line.icon:SetPoint("CENTER")

    -- Serif headings are reserved for section and zone labels; row copy stays
    -- in the UI face for legibility at this size. The name and the role share
    -- the left column, the distance and the coordinates share a fixed column
    -- on the right, so nothing ever wraps into a second line.
    line.title = Journal.Body(line, 12, "", ns.Colors.parchment, "LEFT")
    line.title:SetPoint("TOPLEFT", ROW_INDENT, -7)
    line.title:SetPoint("TOPRIGHT", -ROW_RIGHT, -7)
    if line.title.SetWordWrap then line.title:SetWordWrap(false) end

    line.distance = Journal.Body(line, 10, "", ns.Colors.brightGold, "RIGHT")
    line.distance:SetPoint("TOPRIGHT", -8, -7)
    if line.distance.SetWordWrap then line.distance:SetWordWrap(false) end
    line.distance:Hide()

    line.heading = Journal.Text(line, 12, "", ns.Colors.gold, "LEFT")
    line.heading:Hide()

    line.detail = Journal.Body(line, 10, "", ns.Colors.muted, "LEFT")
    line.detail:SetPoint("TOPLEFT", ROW_INDENT, -23)
    line.detail:SetPoint("TOPRIGHT", -ROW_RIGHT, -23)
    if line.detail.SetWordWrap then line.detail:SetWordWrap(false) end

    line.coords = Journal.Body(line, 10, "", ns.Colors.goldLine, "RIGHT")
    line.coords:SetPoint("TOPRIGHT", -8, -23)
    if line.coords.SetWordWrap then line.coords:SetWordWrap(false) end
    line.coords:Hide()

    line.count = Journal.Body(line, 10, "", ns.Colors.goldLine, "RIGHT")
    line.count:SetPoint("RIGHT", -8, 0)
    line.count:Hide()

    line.rule = Journal.Solid(line, ns.Colors.goldLine)
    line.rule:SetHeight(1)
    line.rule:SetPoint("BOTTOMLEFT", 6, 0)
    line.rule:SetPoint("BOTTOMRIGHT", -6, 0)
    line.rule:Hide()

    -- Collapse marker for a section band. A child button consumes its own
    -- clicks, so the marker folds a section without also filtering by it.
    line.marker = CreateFrame("Button", nil, line)
    line.marker:SetSize(16, SECTION_HEIGHT - 6)
    line.marker:SetPoint("LEFT", 6, 0)
    line.marker.mark = Journal.Text(line.marker, 12, "-", ns.Colors.gold, "CENTER")
    line.marker.mark:SetPoint("CENTER", 0, 1)
    line.marker:SetScript("OnEnter", function(self)
        self.mark:SetTextColor(ns.Colors.brightGold[1], ns.Colors.brightGold[2], ns.Colors.brightGold[3])
    end)
    line.marker:SetScript("OnLeave", function(self)
        self.mark:SetTextColor(ns.Colors.gold[1], ns.Colors.gold[2], ns.Colors.gold[3])
    end)
    line.marker:SetScript("OnClick", function()
        Browser.collapsed[line.sectionKey] = not Browser.collapsed[line.sectionKey]
        Browser:ScheduleRefresh(0)
    end)
    line.marker:Hide()

    line:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    line:SetScript("OnEnter", function(self)
        if self.kind == "row" then
            self.background:SetAlpha(self.selected and 0.16 or 0.10)
            self.accent:Show()
            self.badgeFill:SetColorTexture(0.16, 0.13, 0.08, 1)
            Browser:ShowRowTooltip(self)
        end
    end)
    line:SetScript("OnLeave", function(self)
        if self.kind == "row" then
            self.background:SetAlpha(self.selected and 0.08 or 0)
            self.accent:SetShown(self.selected == true)
        end
        self.badgeFill:SetColorTexture(ns.Colors.leatherDark[1], ns.Colors.leatherDark[2],
            ns.Colors.leatherDark[3], 1)
        Browser:HideRowTooltip(self)
    end)
    line:SetScript("OnClick", function(self, button)
        if self.kind == "section" then
            -- The band filters the list by its category; the marker beside it
            -- folds the section away.
            local key = self.sectionKey
            -- A category the user switched off in the settings is not in the
            -- index, so filtering by it would empty the list. The settings
            -- window can be open while the column is, so the band can outlive
            -- the category.
            if ns.db and ns.db.categories and ns.db.categories[key] == false then return end
            -- "(cond and nil or key)" never yields nil, so the toggle is
            -- written out: a second click on the active band clears it.
            if Browser:GetCategory() == key then
                ns.db.browserCategory = nil
            else
                ns.db.browserCategory = key
            end
            Browser:StyleFacets()
            Browser:ScheduleRefresh(0)
            return
        end
        local row = self.row
        if not row then return end
        -- Clicking a row is a finished action: return the keyboard to the
        -- bindings instead of leaving it captured by the filter box.
        if Browser.panel and Browser.panel.filter then Browser.panel.filter:ClearFocus() end
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

-- Hover card for list rows. The map pins already get HandyNotes tooltips; this
-- card is for our own list, where the row can also show the distance.
function Browser:ShowRowTooltip(line)
    local row = line.row
    if not row or not row.node or not GameTooltip then return end
    self.tooltipLine = line
    GameTooltip:SetOwner(line, "ANCHOR_RIGHT")
    GameTooltip:AddLine(row.name or "Unknown NPC", 1.00, 0.82, 0.00)
    if type(row.sub) == "string" and row.sub ~= "" then
        GameTooltip:AddLine(row.sub, 0.85, 0.85, 0.85)
    end
    if line.sectionName then
        GameTooltip:AddLine(line.sectionName, 0.75, 0.75, 0.75)
    end
    GameTooltip:AddLine(("%s  ·  %.1f, %.1f"):format(
        tostring(row.zoneName), row.node.x * 100, row.node.y * 100), 0.75, 0.75, 0.75)
    local playerMap, playerX, playerY = GetPlayerZonePosition()
    local distance = ns.Location:FormatDistance(DistanceTo(playerMap, playerX, playerY,
        row.mapID, row.node.x, row.node.y))
    if distance then
        GameTooltip:AddLine("Distance: " .. distance, 0.75, 0.75, 0.75)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: set waypoint", 0.65, 0.65, 0.65)
    GameTooltip:AddLine("Right-click: open map", 0.65, 0.65, 0.65)
    GameTooltip:Show()
end

function Browser:HideRowTooltip(line)
    if line and self.tooltipLine ~= line then return end
    self.tooltipLine = nil
    if GameTooltip then GameTooltip:Hide() end
end

function Browser:GetMode()
    return ns.db.browserMode == "all" and "all" or "map"
end

-- Framed container for the scope switch; the segments carry the state.
function Browser:CreateScopeBar()
    local bar = CreateFrame("Frame", nil, self.panel)
    bar:SetSize(CONTENT_WIDTH - NEAR_WIDTH - SPACE_MD, SCOPE_HEIGHT)
    local fill = Journal.Solid(bar, ns.Colors.leatherDark)
    fill:SetAllPoints()
    Journal.HairlineRect(bar, 0, ns.Colors.goldLine, 0.5)
    self.scopeBar = bar
    return bar
end

-- The scope switch is a two-segment control: the active segment carries a
-- gold wash and gold lettering, the inactive one stays muted.
function Browser:CreateScopeButton(text, mode, width)
    local owner = self
    local button = CreateFrame("Button", nil, self.scopeBar)
    button:SetSize(width, SCOPE_HEIGHT - 4)
    button.label = Journal.Text(button, 11, text, ns.Colors.muted, "CENTER")
    button.label:SetPoint("CENTER", 0, 1)
    button.fill = Journal.Solid(button, ns.Colors.gold)
    button.fill:SetAllPoints()
    button.fill:SetAlpha(0)
    button:SetScript("OnEnter", function()
        if owner:GetMode() ~= mode then
            button.label:SetTextColor(ns.Colors.gold[1], ns.Colors.gold[2], ns.Colors.gold[3])
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
        local color = active and ns.Colors.brightGold or ns.Colors.muted
        button.label:SetTextColor(color[1], color[2], color[3])
        button.fill:SetAlpha(active and 0.16 or 0)
    end
end

-- Shared pill for the group chips and the near-me toggle: dark fill inside a
-- gold hairline, inverted to a gold fill with dark lettering while selected.
function Browser:CreatePill(parent, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    button.border = Journal.Solid(button, ns.Colors.goldLine)
    button.border:SetAllPoints()
    button.fill = Journal.Solid(button, ns.Colors.leatherDark)
    button.fill:SetPoint("TOPLEFT", 1, -1)
    button.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    button.label = Journal.Body(button, 10, "", nil, "CENTER")
    button.label:SetPoint("CENTER", 0, 1)
    button.active = false

    function button:Restyle()
        local fill = self.active and ns.Colors.gold or ns.Colors.leatherDark
        self.fill:SetColorTexture(fill[1], fill[2], fill[3], 1)
        self.border:SetAlpha(self.active and 1 or 0.35)
        local color = self.active and ns.Colors.leatherDark or ns.Colors.textMuted
        self.label:SetTextColor(color[1], color[2], color[3])
    end
    button:SetScript("OnEnter", function(self)
        if self.active then return end
        self.border:SetAlpha(0.9)
        self.label:SetTextColor(ns.Colors.gold[1], ns.Colors.gold[2], ns.Colors.gold[3])
    end)
    button:SetScript("OnLeave", function(self) self:Restyle() end)
    button:Restyle()
    return button
end

function Browser:StyleNearButton()
    local button = self.panel and self.panel.nearButton
    if not button then return end
    button.active = ns.db and ns.db.browserNearMe == true
    button:Restyle()
end

function Browser:GetGroup()
    local group = ns.db and ns.db.browserGroup
    if group and group ~= "all" then return group end
    return "all"
end

-- The second filter tier: a single category inside the selected group. It is
-- empty until the user picks one, and clicking the same category again
-- clears it.
function Browser:GetCategory()
    local key = ns.db and ns.db.browserCategory
    if type(key) ~= "string" or key == "" then return nil end
    -- A category the user switched off in the settings is no longer a filter.
    if ns.db.categories and ns.db.categories[key] == false then return nil end
    return key
end

-- Four-digit counts would overflow a chip, so large ones go to "1.2k".
local function ShortCount(count)
    if count >= 1000 then
        local text = ("%.1fk"):format(count / 1000)
        return (text:gsub("%.0k$", "k"))
    end
    return tostring(count)
end

-- Category chip: the group name on the left, the live count on the right.
-- Selected chips invert to a gold plate with dark lettering.
function Browser:CreateGroupChip(parent, key, title)
    local owner = self
    local button = CreateFrame("Button", nil, parent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    button:SetSize(100, CHIP_HEIGHT)
    button.key = key
    button.title = title
    button.count = 0

    if button.SetBackdrop then
        button:SetBackdrop({
            bgFile = ns.MEDIA.white, edgeFile = ns.MEDIA.white, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
    end

    button.titleText = Journal.Body(button, 11, title, ns.Colors.text, "LEFT")
    button.titleText:SetPoint("LEFT", 8, 0)
    button.countText = Journal.Body(button, 11, "0", ns.Colors.goldLine, "RIGHT")
    button.countText:SetPoint("RIGHT", -8, 0)

    function button:Restyle()
        local active = self.key == owner:GetGroup()
        if self.SetBackdropColor then
            if active then
                self:SetBackdropColor(ns.Colors.gold[1], ns.Colors.gold[2], ns.Colors.gold[3], 1)
            else
                self:SetBackdropColor(ns.Colors.leatherDark[1], ns.Colors.leatherDark[2],
                    ns.Colors.leatherDark[3], 1)
            end
        end
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(ns.Colors.brightGold[1], ns.Colors.brightGold[2],
                ns.Colors.brightGold[3], active and 1 or 0.45)
        end
        local color = active and ns.Colors.leatherDark or ns.Colors.text
        self.titleText:SetTextColor(color[1], color[2], color[3])
        local countColor = active and ns.Colors.leatherDark or ns.Colors.goldLine
        self.countText:SetTextColor(countColor[1], countColor[2], countColor[3])
    end

    button:SetScript("OnEnter", function()
        if key ~= owner:GetGroup() then
            button.titleText:SetTextColor(ns.Colors.gold[1], ns.Colors.gold[2], ns.Colors.gold[3])
        end
        if GameTooltip then
            GameTooltip:SetOwner(button, "ANCHOR_LEFT")
            GameTooltip:AddLine(title, 1.00, 0.82, 0.00)
            GameTooltip:AddLine(("%d location%s"):format(button.count or 0,
                (button.count or 0) == 1 and "" or "s"), 0.85, 0.85, 0.85)
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function()
        button:Restyle()
        if GameTooltip then GameTooltip:Hide() end
    end)
    button:SetScript("OnClick", function()
        ns.db.browserGroup = owner:GetGroup() == key and "all" or key
        -- A category only belongs to the group it was picked from.
        ns.db.browserCategory = nil
        owner:StyleGroups()
        owner:StyleFacets()
        owner:ScheduleRefresh(0)
    end)
    button:Restyle()
    return button
end

function Browser:StyleGroups()
    local buttons = self.groupButtons
    if not buttons then return end
    for _, button in pairs(buttons) do
        button.countText:SetText(ShortCount(button.count))
        button:Restyle()
    end
end

-- The chip grid: the master filter spans the full width on the first row and
-- the groups follow in two columns. The grid is generated from the group
-- table, so a new group appears without touching the layout code.
function Browser:LayoutGroupChips(quickBar)
    local order = ns.groupOrder or { "all" }
    local chipWidth = (CONTENT_WIDTH - CHIP_GAP) / 2
    local chipRow = CHIP_HEIGHT + CHIP_GAP
    local buttons, rows = {}, 0

    for index, key in ipairs(order) do
        local info = ns.groupInfo[key] or {}
        local button = self:CreateGroupChip(quickBar, key, info.chip or key)
        buttons[key] = button
        button:ClearAllPoints()
        if index == 1 then
            button:SetSize(CONTENT_WIDTH, CHIP_HEIGHT)
            button:SetPoint("TOPLEFT", 0, 0)
            rows = 1
        else
            local slot = index - 2
            local column = slot % 2
            local rowIndex = math.floor(slot / 2)
            button:SetSize(chipWidth, CHIP_HEIGHT)
            button:SetPoint("TOPLEFT", column * (chipWidth + CHIP_GAP), -(1 + rowIndex) * chipRow)
            rows = math.max(rows, 2 + rowIndex)
        end
    end

    self.groupButtons = buttons
    self.groupRows = rows
    local height = rows * CHIP_HEIGHT + math.max(rows - 1, 0) * CHIP_GAP
    quickBar:SetSize(CONTENT_WIDTH, height)
    return height
end

--- Category chip: the second filter tier under the group chips. Only the
-- categories of the selected group are shown, so the tier never grows with the
-- size of the category list.
function Browser:CreateFacetChip(parent, category)
    local owner = self
    local key = category.key
    local button = CreateFrame("Button", nil, parent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    button:SetSize(100, CHIP_HEIGHT)
    button.key = key
    button.count = 0

    if button.SetBackdrop then
        button:SetBackdrop({
            bgFile = ns.MEDIA.white, edgeFile = ns.MEDIA.white, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
    end

    local short = ns.categoryShort and ns.categoryShort[key] or category.name
    button.fullLabel = short
    button.titleText = Journal.Body(button, 9, short, ns.Colors.text, "LEFT")
    button.titleText:SetPoint("LEFT", 6, 0)
    if button.titleText.SetWordWrap then button.titleText:SetWordWrap(false) end
    button.countText = Journal.Body(button, 9, "0", ns.Colors.goldLine, "RIGHT")
    button.countText:SetPoint("RIGHT", -6, 0)

    function button:Restyle()
        local active = owner:GetCategory() == self.key
        if self.SetBackdropColor then
            if active then
                self:SetBackdropColor(ns.Colors.gold[1], ns.Colors.gold[2], ns.Colors.gold[3], 1)
            else
                self:SetBackdropColor(ns.Colors.leatherDark[1], ns.Colors.leatherDark[2],
                    ns.Colors.leatherDark[3], 1)
            end
        end
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(ns.Colors.brightGold[1], ns.Colors.brightGold[2],
                ns.Colors.brightGold[3], active and 1 or 0.4)
        end
        local color = active and ns.Colors.leatherDark or ns.Colors.text
        self.titleText:SetTextColor(color[1], color[2], color[3])
        local countColor = active and ns.Colors.leatherDark or ns.Colors.goldLine
        self.countText:SetTextColor(countColor[1], countColor[2], countColor[3])
    end

    button:SetScript("OnEnter", function()
        if owner:GetCategory() == key then return end
        button.titleText:SetTextColor(ns.Colors.gold[1], ns.Colors.gold[2], ns.Colors.gold[3])
        if GameTooltip then
            GameTooltip:SetOwner(button, "ANCHOR_LEFT")
            GameTooltip:AddLine(category.name, 1.00, 0.82, 0.00)
            GameTooltip:AddLine(("%d location%s"):format(button.count or 0,
                (button.count or 0) == 1 and "" or "s"), 0.85, 0.85, 0.85)
            GameTooltip:AddLine("Show only these", 0.85, 0.85, 0.85)
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function()
        button:Restyle()
        if GameTooltip then GameTooltip:Hide() end
    end)
    button:SetScript("OnClick", function()
        -- A category the user switched off contributes nothing to the list,
        -- so the filter must not be written for it either.
        if ns.db and ns.db.categories and ns.db.categories[key] == false then return end
        local current = owner:GetCategory()
        -- "(cond and nil or key)" never yields nil, so the toggle is written
        -- out: a second click on the active chip clears the filter.
        if current == key then
            ns.db.browserCategory = nil
        else
            ns.db.browserCategory = key
        end
        owner:StyleFacets()
        owner:ScheduleRefresh(0)
    end)
    button:Restyle()
    button:Hide()
    return button
end

function Browser:StyleFacets()
    local buttons = self.facetButtons
    if not buttons then return end
    for _, button in pairs(buttons) do button:Restyle() end
end

-- Lay the category chips of the selected group out in a grid and move the
-- list below them. The tier is empty while the ALL group is selected, so the
-- list keeps its full height in the default view.
function Browser:UpdateFacets(sections, updateCounts)
    local buttons = self.facetButtons
    if not buttons then return end

    local group = self:GetGroup()
    -- A category the user switched off is not in the index, so it gets no
    -- chip either: the grid stays free of rows that cannot be selected.
    local categories = ns.db and ns.db.categories
    local visible, visibleSet = {}, {}
    for _, key in ipairs(ns.GetGroupKeys(group)) do
        if not (categories and categories[key] == false) then
            visible[#visible + 1] = key
            visibleSet[key] = true
        end
    end

    local counts = {}
    if updateCounts and type(sections) == "table" then
        for index = 1, #sections do
            local section = sections[index]
            counts[section.key] = section.total
        end
    end

    local chipWidth = (CONTENT_WIDTH - CHIP_GAP * (FACET_COLUMNS - 1)) / FACET_COLUMNS
    for index, key in ipairs(visible) do
        local button = buttons[key]
        if button then
            if updateCounts then
                button.count = counts[key] or 0
                button.countText:SetText(ShortCount(button.count))
            end
            local column = (index - 1) % FACET_COLUMNS
            local rowIndex = math.floor((index - 1) / FACET_COLUMNS)
            button:ClearAllPoints()
            button:SetSize(chipWidth, CHIP_HEIGHT)
            button:SetPoint("TOPLEFT", column * (chipWidth + CHIP_GAP),
                -rowIndex * (CHIP_HEIGHT + CHIP_GAP))
            -- The count keeps its room; a long name is trimmed instead of
            -- pushing the count out of the chip.
            Journal.FitText(button.titleText, button.fullLabel or "", chipWidth - 34)
            button:Show()
            button:Restyle()
        end
    end
    for key, button in pairs(buttons) do
        if not visibleSet[key] then button:Hide() end
    end

    local rows = math.ceil(#visible / FACET_COLUMNS)
    local height = rows > 0 and (rows * CHIP_HEIGHT + (rows - 1) * CHIP_GAP) or 0
    local panel = self.panel
    if panel.facetBar then
        panel.facetBar:SetSize(CONTENT_WIDTH, height)
        panel.facetBar:SetShown(height > 0)
    end
    if panel.page and panel.facetTop then
        panel.page:SetPoint("TOPLEFT", CONTENT_LEFT, panel.facetTop - height - SPACE_MD)
    end
end

function Browser:UpdateGroups(sections, meta)
    local buttons = self.groupButtons
    if not buttons then return end
    -- The browse pass counts locations per group, so a place that sits in two
    -- categories of the same group is counted once.
    local counts = meta and meta.groupCounts or {}
    for key, button in pairs(buttons) do
        button.count = counts[key] or 0
    end
    self:StyleGroups()
    self:StyleNearButton()
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

    -- Clicking the collapsed rail expands it; dragging still moves the panel.
    local pressedX, pressedY
    panel:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        pressedX, pressedY = CursorUI()
    end)
    panel:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then return end
        local x, y = CursorUI()
        local moved = math.abs(x - (pressedX or x)) + math.abs(y - (pressedY or y)) > 4
        pressedX, pressedY = nil, nil
        if not moved and ns.db and ns.db.browserCollapsed then
            browser:ToggleCollapsed()
        end
    end)
    browser:StyleColumn(panel)
    browser:RestorePosition()

    -- Vertical rhythm: every block below is placed from the one above it, so
    -- the column keeps its spacing when a block changes height.
    local filterY = -(HEADER_HEIGHT + STRIP_HEIGHT + SPACE_MD)
    local scopeY = filterY - FILTER_HEIGHT - SPACE_MD
    local chipsY = scopeY - SCOPE_HEIGHT - SPACE_MD

    -- Header: the browsed scope on the left, the column controls on the right.
    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT", SPINE_WIDTH, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(HEADER_HEIGHT)
    local headerFill = Journal.Solid(header, ns.Colors.leatherDark)
    headerFill:SetAllPoints()
    headerFill:SetAlpha(1)
    local headerRule = Journal.Solid(header, ns.Colors.goldLine)
    headerRule:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    headerRule:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    headerRule:SetHeight(1)
    headerRule:SetAlpha(0.85)
    panel.header = header

    panel.scopeTitle = Journal.Text(header, 15, "", ns.Colors.gold, "LEFT")
    panel.scopeTitle:SetPoint("TOPLEFT", GUTTER, -13)
    panel.scopeTitle:SetPoint("TOPRIGHT", -88, -13)
    if panel.scopeTitle.SetWordWrap then panel.scopeTitle:SetWordWrap(false) end

    local close = Journal.CloseButton(header, function() browser:Hide() end)
    browser.closeButton = close
    close:SetPoint("TOPRIGHT", -10, -11)

    -- Borderless glyph beside the close button; the header stays uncluttered.
    local collapse = CreateFrame("Button", nil, header)
    collapse:SetSize(18, 18)
    collapse.mark = Journal.Text(collapse, 13, "<", ns.Colors.gold)
    collapse.mark:SetPoint("CENTER", 0, 1)
    collapse:SetScript("OnEnter", function(self)
        self.mark:SetTextColor(ns.Colors.brightGold[1], ns.Colors.brightGold[2], ns.Colors.brightGold[3])
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine(ns.db.browserCollapsed and "Expand locations" or "Collapse to a rail",
                1.00, 0.82, 0.00)
            GameTooltip:Show()
        end
    end)
    collapse:SetScript("OnLeave", function(self)
        self.mark:SetTextColor(ns.Colors.gold[1], ns.Colors.gold[2], ns.Colors.gold[3])
        if GameTooltip then GameTooltip:Hide() end
    end)
    collapse:SetScript("OnClick", function() browser:ToggleCollapsed() end)
    collapse:SetPoint("TOPRIGHT", -38, -12)
    panel.collapseButton = collapse

    -- Settings live behind the minimap button too, but the column is where
    -- the user is when they want to change what it lists.
    local settings = CreateFrame("Button", nil, header)
    settings:SetSize(22, 18)
    settings.mark = Journal.Text(settings, 10, "SET", ns.Colors.gold)
    settings.mark:SetPoint("CENTER", 0, 1)
    settings:SetScript("OnEnter", function(self)
        self.mark:SetTextColor(ns.Colors.brightGold[1], ns.Colors.brightGold[2], ns.Colors.brightGold[3])
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("Wayfinder settings", 1.00, 0.82, 0.00)
            GameTooltip:Show()
        end
    end)
    settings:SetScript("OnLeave", function(self)
        self.mark:SetTextColor(ns.Colors.gold[1], ns.Colors.gold[2], ns.Colors.gold[3])
        if GameTooltip then GameTooltip:Hide() end
    end)
    settings:SetScript("OnClick", function()
        if ns.OpenSettings then ns:OpenSettings() end
    end)
    settings:SetPoint("TOPRIGHT", -60, -12)
    panel.settingsButton = settings

    -- Location strip: the player on the left, the cursor over the map art on
    -- the right. Stays visible when the column is collapsed to its rail.
    local strip = CreateFrame("Frame", nil, panel)
    strip:SetPoint("TOPLEFT", SPINE_WIDTH, -HEADER_HEIGHT)
    strip:SetPoint("TOPRIGHT", 0, -HEADER_HEIGHT)
    strip:SetHeight(STRIP_HEIGHT)
    local stripFill = Journal.Solid(strip, ns.Colors.leather)
    stripFill:SetAllPoints()
    stripFill:SetAlpha(0.8)
    local stripRule = Journal.Solid(strip, ns.Colors.goldLine)
    stripRule:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, 0)
    stripRule:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", 0, 0)
    stripRule:SetHeight(1)
    stripRule:SetAlpha(0.4)
    panel.strip = strip

    local youTag = Journal.Text(strip, 10, "YOU", ns.Colors.gold, "LEFT")
    youTag:SetPoint("TOPLEFT", GUTTER, -9)
    youTag:SetWidth(26)

    local locationLabel = Journal.Body(strip, 11, "locating...", ns.Colors.muted, "LEFT")
    locationLabel:SetPoint("TOPLEFT", GUTTER + 30, -8)
    locationLabel:SetPoint("TOPRIGHT", -68, -8)
    locationLabel:SetHeight(12)
    if locationLabel.SetWordWrap then locationLabel:SetWordWrap(false) end
    panel.locationLabel = locationLabel

    -- Cursor position over the map art, right-aligned in the strip. It shares
    -- the "Panel coordinates" opt-out with the player coordinates.
    local cursorLabel = Journal.Body(strip, 10, "", ns.Colors.goldLine, "RIGHT")
    cursorLabel:SetPoint("TOPRIGHT", -GUTTER, -9)
    if cursorLabel.SetWordWrap then cursorLabel:SetWordWrap(false) end
    cursorLabel:Hide()
    panel.cursorLabel = cursorLabel
    panel.cursorText = ""

    -- Filter box with the client's search glyph inside its leading edge.
    local filter = Journal.Input(panel, CONTENT_WIDTH, FILTER_HEIGHT)
    filter:SetPoint("TOPLEFT", CONTENT_LEFT, filterY)
    local textInset = 8
    if Journal.AtlasInfo("common-search-magnifyingglass") then
        local searchIcon = filter:CreateTexture(nil, "ARTWORK")
        searchIcon:SetAtlas("common-search-magnifyingglass", true)
        searchIcon:SetSize(14, 14)
        searchIcon:SetPoint("LEFT", 8, 0)
        searchIcon:SetAlpha(0.75)
        textInset = 26
        filter:SetTextInsets(textInset, 8, 0, 0)
    end
    local placeholder = Journal.Body(panel, 11, "Filter by name or category", ns.Colors.textMuted, "LEFT")
    placeholder:SetPoint("LEFT", filter, "LEFT", textInset, 0)
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
    filter:SetScript("OnEnterPressed", function(self)
        local line = browser.selectedLine
        if line and line.row then
            local ok, reason = ns.Waypoints:Set(line.row.mapID, line.row.node.x, line.row.node.y,
                line.title)
            if not ok then ns:Print(reason) end
        end
        self:ClearFocus()
    end)
    filter:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    -- The filter box is the only keyboard surface in the panel; it receives
    -- keys only while focused, so bindings such as M keep working.
    filter:SetScript("OnKeyDown", function(_, key)
        if key == "UP" then
            browser:MoveSelection(-1)
        elseif key == "DOWN" then
            browser:MoveSelection(1)
        end
    end)
    UpdatePlaceholder()
    panel.filter = filter
    panel.placeholder = placeholder
    panel.UpdatePlaceholder = UpdatePlaceholder

    -- One row for scope (left) and the near-me toggle (right).
    local scopeBar = browser:CreateScopeBar()
    scopeBar:SetPoint("TOPLEFT", CONTENT_LEFT, scopeY)
    panel.scopeBar = scopeBar
    local segmentWidth = (scopeBar:GetWidth() - 4) / 2
    local scopeMap = browser:CreateScopeButton("THIS MAP", "map", segmentWidth)
    scopeMap:SetPoint("TOPLEFT", 2, -2)
    local scopeAll = browser:CreateScopeButton("ALL ZONES", "all", segmentWidth)
    scopeAll:SetPoint("TOPLEFT", 2 + segmentWidth, -2)
    browser:UpdateScope()

    local nearButton = browser:CreatePill(panel, NEAR_WIDTH, SCOPE_HEIGHT)
    nearButton:SetPoint("TOPRIGHT", -GUTTER, scopeY)
    nearButton.label:SetText("NEAR ME")
    nearButton:SetScript("OnEnter", function(self)
        if not self.active then
            self.border:SetAlpha(0.9)
            self.label:SetTextColor(ns.Colors.gold[1], ns.Colors.gold[2], ns.Colors.gold[3])
        end
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Sort by distance from you", 1.00, 0.82, 0.00)
            GameTooltip:AddLine("Rows are re-sorted inside each category. Distances cover your current continent.",
                0.85, 0.85, 0.85)
            GameTooltip:Show()
        end
    end)
    nearButton:SetScript("OnLeave", function(self)
        self:Restyle()
        if GameTooltip then GameTooltip:Hide() end
    end)
    nearButton:SetScript("OnClick", function()
        ns.db.browserNearMe = not ns.db.browserNearMe
        browser:StyleNearButton()
        browser:ScheduleRefresh(0)
    end)
    panel.nearButton = nearButton
    browser:StyleNearButton()

    -- Category chips: ALL spans the full width as the master filter, the
    -- groups follow in a two-column grid, each with the live count on the
    -- right. The grid is generated from the group table.
    local quickBar = CreateFrame("Frame", nil, panel)
    quickBar:SetPoint("TOPLEFT", CONTENT_LEFT, chipsY)
    panel.quickBar = quickBar
    local chipsHeight = browser:LayoutGroupChips(quickBar)
    browser:StyleGroups()

    -- Facet tier: the categories of the selected group, each with its own
    -- count. It is empty under ALL, so the default view keeps the full list
    -- height and a group selection buys the finer filter.
    local facetY = chipsY - chipsHeight - SPACE_MD
    local listY = facetY - SPACE_MD
    local facetBar = CreateFrame("Frame", nil, panel)
    facetBar:SetPoint("TOPLEFT", CONTENT_LEFT, facetY)
    facetBar:SetSize(CONTENT_WIDTH, 0)
    panel.facetBar = facetBar
    panel.facetTop = facetY
    browser.facetButtons = {}
    for _, category in ipairs(ns.categoryList or {}) do
        browser.facetButtons[category.key] = browser:CreateFacetChip(facetBar, category)
    end

    -- List well: an inset page with a gold rule along its top edge. The fill
    -- is opaque so the map art behind the column cannot show through it.
    local page = CreateFrame("Frame", nil, panel)
    page:SetPoint("TOPLEFT", CONTENT_LEFT, listY)
    page:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -GUTTER, FOOTER_HEIGHT)
    local pageFill = Journal.Solid(page, PAGE_FILL)
    pageFill:SetAllPoints()
    local pageRule = Journal.Solid(page, ns.Colors.goldLine)
    pageRule:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    pageRule:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
    pageRule:SetHeight(1)
    pageRule:SetAlpha(0.4)

    local scroll = CreateFrame("ScrollFrame", "ForeverWayfinderBrowserScroll", page,
        "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -6)
    scroll:SetPoint("BOTTOMRIGHT", -16, 4)
    browser:SkinScrollBar(scroll)
    panel.content = CreateFrame("Frame", nil, scroll)
    panel.content:SetSize(CONTENT_WIDTH - 20, 1)
    scroll:SetScrollChild(panel.content)
    panel.lines = {}
    panel.scroll = scroll
    panel.page = page

    local footerRule = Journal.Solid(panel, ns.Colors.goldLine)
    footerRule:SetPoint("BOTTOMLEFT", SPINE_WIDTH, FOOTER_HEIGHT)
    footerRule:SetPoint("BOTTOMRIGHT", 0, FOOTER_HEIGHT)
    footerRule:SetHeight(1)
    footerRule:SetAlpha(0.5)
    panel.footerRule = footerRule

    panel.status = Journal.Body(panel, 10, "", ns.Colors.goldLine, "LEFT")
    panel.status:SetPoint("BOTTOMLEFT", CONTENT_LEFT, 10)
    panel.status:SetWidth(CONTENT_WIDTH - 82)
    if panel.status.SetWordWrap then panel.status:SetWordWrap(false) end
    panel.status:SetHeight(12)

    -- Clears the category filter. It only exists while a filter is active, so
    -- the footer never carries a control that does nothing.
    local filterClear = CreateFrame("Button", nil, panel)
    filterClear:SetSize(18, 18)
    filterClear:SetPoint("BOTTOMRIGHT", -GUTTER - 58, 8)
    filterClear.mark = Journal.Text(filterClear, 12, "×", ns.Colors.gold, "CENTER")
    filterClear.mark:SetPoint("CENTER", 0, 1)
    filterClear:SetScript("OnEnter", function(self)
        self.mark:SetTextColor(ns.Colors.brightGold[1], ns.Colors.brightGold[2], ns.Colors.brightGold[3])
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Clear the category filter", 1.00, 0.82, 0.00)
            GameTooltip:Show()
        end
    end)
    filterClear:SetScript("OnLeave", function(self)
        self.mark:SetTextColor(ns.Colors.gold[1], ns.Colors.gold[2], ns.Colors.gold[3])
        if GameTooltip then GameTooltip:Hide() end
    end)
    filterClear:SetScript("OnClick", function()
        ns.db.browserCategory = nil
        browser:StyleFacets()
        browser:ScheduleRefresh(0)
    end)
    filterClear:Hide()
    panel.filterClearButton = filterClear

    local clear = CreateFrame("Button", nil, panel)
    clear:SetSize(58, 18)
    clear:SetPoint("BOTTOMRIGHT", -GUTTER, 8)
    clear.label = Journal.Body(clear, 10, "WAYPOINT", ns.Colors.gold, "RIGHT")
    clear.label:SetPoint("RIGHT", 0, 0)
    clear:SetScript("OnEnter", function(self)
        self.label:SetTextColor(ns.Colors.brightGold[1], ns.Colors.brightGold[2], ns.Colors.brightGold[3])
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Clear the last waypoint", 1.00, 0.82, 0.00)
            GameTooltip:Show()
        end
    end)
    clear:SetScript("OnLeave", function(self)
        self.label:SetTextColor(ns.Colors.gold[1], ns.Colors.gold[2], ns.Colors.gold[3])
        if GameTooltip then GameTooltip:Hide() end
    end)
    clear:SetScript("OnClick", function()
        local ok, reason = ns.Waypoints:ClearLast()
        ns:Print(ok and "Waypoint cleared." or reason)
    end)
    panel.clearButton = clear

    -- The panel must never enable keyboard input: a visible keyboard-enabled
    -- frame consumes every key, which leaves M and ESC unable to reach the
    -- world map's bindings. Arrow and Enter navigation live on the filter box.
    --
    -- Map changes do not consistently fire a hook on this client family; the 0.25 s
    -- poll only runs while the panel is visible and catches the gaps.
    local elapsed, locationElapsed = 0, 0
    panel:SetScript("OnUpdate", function(self, delta)
        locationElapsed = locationElapsed + delta
        if locationElapsed >= 1 then
            locationElapsed = 0
            browser:UpdateLocation()
        end
        elapsed = elapsed + delta
        if elapsed < 0.25 then return end
        elapsed = 0
        browser:UpdateCursor()
        if not self:IsShown() or ns.blocked or not ns.ready then return end
        if browser:GetMode() == "map" and GetWorldMapID() ~= self.mapID then
            browser:ScheduleRefresh(0)
        end
    end)

    panel:RegisterEvent("ZONE_CHANGED")
    panel:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    panel:RegisterEvent("PLAYER_ENTERING_WORLD")
    panel:SetScript("OnEvent", function() browser:UpdateLocation() end)

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

function Browser:UpdateLocation()
    local panel = self.panel
    if not panel or not panel.locationLabel or not panel:IsShown() then return end

    local info = ns.Location:Read()
    local collapsed = ns.db and ns.db.browserCollapsed == true
    local showCoords = not (ns.db and ns.db.browserCoords == false)
    -- The strip carries its own "YOU" tag, so the location line is always the
    -- compact form.
    local text = ns.Location:Format(info, true, showCoords)
    if text ~= panel.locationText then
        panel.locationText = text
        panel.locationLabel:SetText(text)
    end

    -- Gold when the player stands on the map being browsed, muted otherwise.
    local sameMap = info.mapID and self:GetMode() == "map" and info.mapID == GetWorldMapID()
    local colorKey = sameMap and "gold" or "muted"
    if colorKey ~= panel.locationColor then
        panel.locationColor = colorKey
        local color = sameMap and ns.Colors.goldLine or ns.Colors.muted
        panel.locationLabel:SetTextColor(color[1], color[2], color[3])
    end
end

-- Cursor coordinates over the map canvas, Questie-style: the canvas rect is
-- the map art in UI units, so the cursor fraction is the map percentage.
function Browser:UpdateCursor()
    local panel = self.panel
    local label = panel and panel.cursorLabel
    if not label then return end

    local function clear()
        if panel.cursorText ~= "" then
            panel.cursorText = ""
            label:SetText("")
            label:Hide()
        end
    end

    local collapsed = ns.db and ns.db.browserCollapsed == true
    local showCoords = not (ns.db and ns.db.browserCoords == false)
    if collapsed or not showCoords or self:GetMode() ~= "map"
        or not WorldMapFrame or not WorldMapFrame:IsShown()
        or type(WorldMapFrame.GetCanvas) ~= "function" then
        return clear()
    end
    if type(panel.IsMouseOver) == "function" and panel:IsMouseOver() then return clear() end

    local ok, canvas = pcall(WorldMapFrame.GetCanvas, WorldMapFrame)
    if not ok or not canvas then return clear() end
    local rectOk, left, right, top, bottom = pcall(function()
        return canvas:GetLeft(), canvas:GetRight(), canvas:GetTop(), canvas:GetBottom()
    end)
    if not rectOk or not ns.ClassificationIsFiniteNumber(left)
        or not ns.ClassificationIsFiniteNumber(right)
        or not ns.ClassificationIsFiniteNumber(top)
        or not ns.ClassificationIsFiniteNumber(bottom) then
        return clear()
    end

    local scale
    if type(canvas.GetEffectiveScale) == "function" then
        local scaleOk, value = pcall(canvas.GetEffectiveScale, canvas)
        if scaleOk and ns.ClassificationIsFiniteNumber(value) and value > 0 then scale = value end
    end
    local cursorX, cursorY = GetCursorPosition()
    scale = scale or 1
    local x, y = ns.Location:MapCursorPosition(cursorX / scale, cursorY / scale,
        left, top, right - left, top - bottom)
    if not x then return clear() end

    local text = ("%.1f, %.1f"):format(x, y)
    if text ~= panel.cursorText then
        panel.cursorText = text
        label:SetText(text)
        label:Show()
    end
end

function Browser:ApplyLayout()
    local panel = self.panel
    if not panel then return end
    local collapsed = ns.db and ns.db.browserCollapsed == true
    local height = collapsed and COLLAPSED_HEIGHT or DesiredHeight()
    panel:SetWidth(collapsed and COLLAPSED_WIDTH or PANEL_WIDTH)
    panel:SetHeight(height)
    -- The spine fills the column, so both band stacks use the column's height
    -- rather than waiting for a layout pass.
    Journal.LayoutBands(panel, panel.bands, PAGE_TOP, PAGE_BOTTOM, height)
    if panel.spine then
        Journal.LayoutBands(panel.spine, panel.spine.bands, SPINE_TOP, SPINE_BOTTOM, height)
    end
    if panel.scopeBar then panel.scopeBar:SetShown(not collapsed) end
    if panel.nearButton then panel.nearButton:SetShown(not collapsed) end
    if panel.filter then panel.filter:SetShown(not collapsed) end
    if panel.quickBar then panel.quickBar:SetShown(not collapsed) end
    if panel.facetBar then panel.facetBar:SetShown(not collapsed) end
    if panel.cursorLabel and collapsed then
        panel.cursorLabel:Hide()
        panel.cursorText = ""
    end
    if panel.page then panel.page:SetShown(not collapsed) end
    if panel.footerRule then panel.footerRule:SetShown(not collapsed) end
    if panel.status then panel.status:SetShown(not collapsed) end
    if panel.clearButton then panel.clearButton:SetShown(not collapsed) end
    if panel.placeholder then
        if collapsed then
            panel.placeholder:Hide()
        elseif panel.UpdatePlaceholder then
            panel.UpdatePlaceholder()
        end
    end
    if collapsed and panel.filter and type(panel.filter.ClearFocus) == "function" then
        panel.filter:ClearFocus()
    end
    if panel.collapseButton then
        panel.collapseButton.mark:SetText(collapsed and ">" or "<")
    end
    -- The spine lettering needs room the collapsed rail does not have.
    if panel.spineLabel then panel.spineLabel:SetShown(not collapsed) end
    if panel.scopeTitle then
        panel.scopeTitle:SetFontObject(Journal.Font(collapsed and 11 or 15))
    end
    -- Collapsed, the cursor readout is gone, so the location line takes its room.
    if panel.locationLabel and panel.strip then
        panel.locationLabel:ClearAllPoints()
        panel.locationLabel:SetPoint("TOPLEFT", panel.strip, "TOPLEFT", GUTTER + 30, -8)
        panel.locationLabel:SetPoint("TOPRIGHT", panel.strip, "TOPRIGHT",
            collapsed and -GUTTER or -68, -8)
    end
end

function Browser:ToggleCollapsed()
    if not ns.db then return end
    ns.db.browserCollapsed = not ns.db.browserCollapsed
    self:ApplyLayout()
    self:UpdateLocation()
    if not ns.db.browserCollapsed then self:ScheduleRefresh(0) end
end

function Browser:Show()
    -- Opening the column is an action, not a setting change: whether it
    -- returns with the map stays under the user's control.
    self:UpdateScope()
    self:ApplyLayout()
    self.panel:Show()
    self:UpdateIcon()
    self:ScheduleRefresh(0)
end

function Browser:Hide()
    -- Closing the column closes it; whether it returns with the map stays a
    -- setting the user controls.
    self:SavePosition()
    self:HideRowTooltip()
    self.panel:Hide()
    self:UpdateIcon()
end

function Browser:AutoShow()
    if ns.db.browserEnabled == false then
        self.panel:Hide()
        self:UpdateIcon()
        return
    end
    local saved = ns.ValidateSavedPosition and ns.ValidateSavedPosition(ns.db.browserPosition)
    if not saved then self:PlaceDefault() end
    self:UpdateScope()
    self:ApplyLayout()
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
-- Filter palette
--------------------------------------------------------------------------------------------

-- Focus the panel's filter box from /fw find. It should work from anywhere:
-- open the map when it is closed, then focus once the map frame has finished
-- showing.
function ns:FocusBrowserFilter(text)
    self:SetupBrowser()
    local browser = self.browser
    if not browser or not browser.panel then
        self:Print("The location panel is not available yet; open the world map once and try again.")
        return false
    end

    local function Focus()
        if not WorldMapFrame or not WorldMapFrame:IsShown() then
            self:Print("Open the world map to use the location filter.")
            return
        end
        if ns.db.browserCollapsed then browser:ToggleCollapsed() end
        if not browser.panel:IsShown() then browser:Show() end
        local filter = browser.panel.filter
        if not filter then return end
        filter:SetText(text or "")
        filter:SetFocus()
        if type(filter.HighlightText) == "function" then filter:HighlightText() end
    end

    if WorldMapFrame and WorldMapFrame:IsShown() then
        Focus()
        return true
    end
    if InCombatLockdown and InCombatLockdown() then
        self:Print("Cannot open the map during combat.")
        return false
    end
    local opened = false
    if C_Map and type(C_Map.OpenWorldMap) == "function" then
        local mapID = self.GetWorldMapID and self.GetWorldMapID()
        if mapID then opened = pcall(C_Map.OpenWorldMap, mapID) end
    end
    if not opened and WorldMapFrame and type(WorldMapFrame.Show) == "function" then
        pcall(WorldMapFrame.Show, WorldMapFrame)
    end
    local function Delayed()
        if WorldMapFrame and WorldMapFrame:IsShown() then Focus() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.3, Delayed) else Delayed() end
    return true
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

--------------------------------------------------------------------------------------------
-- Keyboard navigation
--------------------------------------------------------------------------------------------

-- The list can be walked without the mouse: up and down move the selection,
-- Enter sets a waypoint on it and Escape closes the column.
function Browser:GetRowLines()
    local rows = {}
    local lines = self.panel and self.panel.lines or {}
    for index = 1, #lines do
        local line = lines[index]
        if line and line.kind == "row" and line:IsShown() then rows[#rows + 1] = line end
    end
    return rows
end

function Browser:SetSelection(line)
    local lines = self.panel and self.panel.lines or {}
    for index = 1, #lines do
        local other = lines[index]
        if other and other.selected then
            other.selected = false
            if other.kind == "row" then
                other.background:SetAlpha(0)
                other.accent:Hide()
            end
        end
    end
    self.selectedLine = line
    if not line then return end
    line.selected = true
    if line.kind == "row" then
        line.background:SetAlpha(0.16)
        line.accent:Show()
    end
    self:ScrollLineIntoView(line)
end

function Browser:MoveSelection(direction)
    local rows = self:GetRowLines()
    if #rows == 0 then return end
    local current = 0
    for index, line in ipairs(rows) do
        if line.selected then current = index break end
    end
    local target
    if current == 0 then
        target = direction > 0 and rows[1] or rows[#rows]
    else
        target = rows[current + direction]
    end
    if not target then target = rows[current > 0 and current or 1] end
    self:SetSelection(target)
end

function Browser:ScrollLineIntoView(line)
    local scroll = self.panel and self.panel.scroll
    if not scroll or not line then return end
    local ok, top, bottom = pcall(function()
        return line:GetTop(), line:GetBottom()
    end)
    if not ok or not top or not bottom then return end
    local viewOk, viewTop, viewBottom = pcall(function()
        return scroll:GetTop(), scroll:GetBottom()
    end)
    if not viewOk or not viewTop or not viewBottom then return end
    local offset = 0
    if type(scroll.GetVerticalScroll) == "function" then
        offset = scroll:GetVerticalScroll() or 0
    end
    if top > viewTop then
        scroll:SetVerticalScroll(offset + (top - viewTop))
    elseif bottom < viewBottom then
        scroll:SetVerticalScroll(offset - (viewBottom - bottom))
    end
end

function Browser:Render()
    local panel = self.panel
    if not panel or not panel:IsShown() then return end

    self:UpdateLocation()

    if ns.blocked then
        panel.status:SetText("|cffff5555Disabled:|r " .. ns.blocked)
        panel.scopeTitle:SetText("")
        self:HideLines()
        panel.content:SetHeight(1)
        panel.mapID = nil
        return
    end
    if not ns.ready then
        panel.status:SetText("Index is still loading. Locations appear when indexing completes.")
        panel.scopeTitle:SetText("")
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
        panel.scopeTitle:SetText((GetMapLabel(mapID) or "THIS MAP"):upper())
        if not mapID then
            panel.status:SetText("Open the world map to browse its locations.")
            self:HideLines()
            panel.content:SetHeight(1)
            return
        end
    else
        panel.mapID = nil
        panel.scopeTitle:SetText("ALL ZONES")
    end

    if ns.db.browserCollapsed then
        self:HideLines()
        panel.content:SetHeight(1)
        return
    end

    local query = panel.filter:GetText() or ""
    local sections, browseMeta = ns:BrowseEntries({
        maps = mode == "map" and { mapID } or nil,
        query = query,
        categories = ns.db and ns.db.categories,
    })
    -- Group counts describe the map, not the text query, so they keep the
    -- unfiltered numbers while the user types.
    if query == "" then self:UpdateGroups(sections, browseMeta) end
    self:UpdateFacets(sections, query == "")
    local group = self:GetGroup()
    local category = self:GetCategory()

    -- A section shows when it belongs to the selected group and, when a
    -- category filter is active, when it is that category.
    local function InScope(section)
        if group ~= "all" and section.group ~= group then return false end
        if category and section.key ~= category then return false end
        return true
    end

    -- Near-me mode reorders each section's fresh row tables by yard distance
    -- and adds the distance to the row detail. Rows on another continent have
    -- no distance and sort after the rest.
    local nearMe = ns.db and ns.db.browserNearMe == true
    if nearMe then
        local playerMap, playerX, playerY = GetPlayerZonePosition()
        for sectionIndex = 1, #sections do
            local section = sections[sectionIndex]
            if InScope(section) then
                for rowIndex = 1, #section.rows do
                    local row = section.rows[rowIndex]
                    row.distance = DistanceTo(playerMap, playerX, playerY,
                        row.mapID, row.node.x, row.node.y)
                end
                table.sort(section.rows, function(a, b)
                    local da, db = a.distance or math.huge, b.distance or math.huge
                    if da ~= db then return da < db end
                    if a.sortName ~= b.sortName then return a.sortName < b.sortName end
                    if a.sortSub ~= b.sortSub then return a.sortSub < b.sortSub end
                    if a.mapID ~= b.mapID then return a.mapID < b.mapID end
                    return a.coord < b.coord
                end)
            end
        end
    end

    local items, truncated = {}, false
    local function Push(item)
        if #items >= MAX_LINES then truncated = true; return false end
        items[#items + 1] = item
        return true
    end
    local full = false
    for sectionIndex = 1, #sections do
        local section = sections[sectionIndex]
        if section.total > 0 and InScope(section) then
            if not Push({ kind = "section", section = section }) then full = true; break end
            if not self.collapsed[section.key] then
                -- Near-me ordering interleaves zones, so a zone heading is
                -- emitted once per section and later rows of that zone render
                -- without a repeated heading.
                local seenZones = {}
                for rowIndex = 1, #section.rows do
                    local row = section.rows[rowIndex]
                    if mode == "all" and not seenZones[row.zoneName] then
                        seenZones[row.zoneName] = true
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
        line.sectionName = section.name
        line.icon:SetTexture(section.icon)
        line.icon:SetAlpha(1)
        line.background:SetAlpha(0)
        line.badge:Hide()
        line.count:Hide()
        line.detail:Hide()
        line.distance:Hide()
        line.coords:Hide()
        line.rule:Hide()
        line.title:Hide()
        line.heading:Hide()
        line.marker:Hide()
        line.selected = false
        line:SetPoint("TOPLEFT", 0, -y)
        line:SetPoint("TOPRIGHT", 0, -y)

        if item.kind == "section" then
            -- Ledger band: a leather plate with a gold edge, the group name
            -- and the live count. The band filters by its category; the
            -- marker beside it folds the section away.
            line:SetHeight(SECTION_HEIGHT)
            line.background:SetColorTexture(ns.Colors.leather[1], ns.Colors.leather[2],
                ns.Colors.leather[3], 0.55)
            line.background:SetAlpha(0.55)
            line.accent:Show()
            line.marker:Show()
            line.marker.mark:SetText(self.collapsed[section.key] and "+" or "-")
            line.heading:SetFontObject(Journal.Font(12))
            line.heading:SetPoint("LEFT", 30, 1)
            line.heading:SetText(section.name:upper())
            local active = self:GetCategory() == section.key
            line.heading:SetTextColor(ns.Colors.brightGold[1], ns.Colors.brightGold[2],
                ns.Colors.brightGold[3])
            if line.heading.SetAlpha then line.heading:SetAlpha(active and 1 or 0.75) end
            line.heading:Show()
            line.count:SetFormattedText("%d%s", section.total, section.capped and "+" or "")
            line.count:Show()
            y = y + SECTION_HEIGHT
        elseif item.kind == "zone" then
            line:SetHeight(ZONE_HEIGHT)
            line.heading:SetFont(STANDARD_TEXT_FONT, 10, "")
            line.heading:SetPoint("LEFT", 16, 1)
            line.heading:SetText(item.zone)
            line.heading:SetTextColor(ns.Colors.goldLine[1], ns.Colors.goldLine[2], ns.Colors.goldLine[3])
            line.heading:Show()
            y = y + ZONE_HEIGHT
        else
            local row = item.row
            line:SetHeight(LINE_HEIGHT)
            line.background:SetColorTexture(ns.Colors.pageHover[1], ns.Colors.pageHover[2],
                ns.Colors.pageHover[3], 1)
            line.background:SetAlpha(0)
            line.badge:Show()
            FitText(line.title, row.name or "", ROW_TEXT_WIDTH)
            line.title:SetTextColor(ns.Colors.parchment[1], ns.Colors.parchment[2], ns.Colors.parchment[3])
            line.title:Show()
            local sub = type(row.sub) == "string" and row.sub or ""
            FitText(line.detail, sub, ROW_TEXT_WIDTH)
            line.detail:Show()
            line.coords:SetFormattedText("%.1f, %.1f", row.node.x * 100, row.node.y * 100)
            line.coords:Show()
            local distance = nearMe and ns.Location:FormatDistance(row.distance)
            if distance then
                line.distance:SetText(distance)
                line.distance:Show()
            end
            line.rule:SetAlpha(0.08)
            line.rule:Show()
            y = y + LINE_HEIGHT
        end
        line:Show()
    end
    for index = #items + 1, #panel.lines do panel.lines[index]:Hide() end
    panel.content:SetHeight(math.max(y, 1))

    -- The tally counts the places on the map, so a location listed under two
    -- categories is only counted once.
    local total, capped = 0, false
    local counted = {}
    for index = 1, #sections do
        local section = sections[index]
        if section.total > 0 and InScope(section) then
            for node in pairs(section.nodes or {}) do
                if not counted[node] then
                    counted[node] = true
                    total = total + 1
                end
            end
            if section.capped then capped = true end
        end
    end

    if panel.filterClearButton then
        panel.filterClearButton:SetShown(category ~= nil)
    end

    if total == 0 then
        if query ~= "" then
            if mode == "all" then
                panel.status:SetFormattedText("No matches for \"%s\" in any zone.", query)
            else
                panel.status:SetFormattedText("No matches for \"%s\" on this map.", query)
            end
        elseif category then
            panel.status:SetText("No locations in that category.")
        elseif group ~= "all" then
            local groupName = string.lower((ns.groupInfo[group] and ns.groupInfo[group].short) or group)
            panel.status:SetFormattedText("No %s %s.", groupName,
                mode == "all" and "in any zone" or "on this map")
        elseif mode == "all" then
            panel.status:SetText("No indexed locations for the enabled categories.")
        else
            panel.status:SetText("No indexed locations on this map.")
        end
        return
    end

    local parts = {}
    -- The header already names the scope, so the footer line only carries the
    -- active filter, the sort mode and the tally.
    if category then
        local categoryInfo = ns.categoryByKey[category]
        parts[#parts + 1] = ((ns.categoryShort and ns.categoryShort[category])
            or (categoryInfo and categoryInfo.name) or category) .. " only"
    elseif group ~= "all" then
        parts[#parts + 1] = (ns.groupInfo[group] and ns.groupInfo[group].short) or group
    end
    if nearMe then parts[#parts + 1] = "near me" end
    parts[#parts + 1] = ("%d location%s"):format(total, total == 1 and "" or "s")
    if capped then parts[#parts + 1] = "capped" end
    if truncated then parts[#parts + 1] = "more" end
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
