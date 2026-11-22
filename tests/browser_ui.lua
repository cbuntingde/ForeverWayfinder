-- Lightweight WoW-frame mock for the world map browser lifecycle.
-- Run standalone with Lua 5.1: lua tests/browser_ui.lua
local ns = {
    MEDIA = {
        white = "white",
        addonIcon = "icon",
        minimapBg = "bg",
        minimapHighlight = "highlight",
        trackingBorder = "border",
    },
    Colors = {
        gold = { 0.83, 0.69, 0.32 }, muted = { 0.62, 0.59, 0.52 },
        pageHover = { 0.80, 0.72, 0.53 }, ink = { 0.24, 0.17, 0.10 },
        inkMuted = { 0.47, 0.40, 0.29 }, goldLine = { 0.72, 0.58, 0.30 },
        leatherDark = { 0.10, 0.07, 0.045 }, leather = { 0.16, 0.11, 0.07 },
        maroon = { 0.45, 0.10, 0.10 }, maroonHover = { 0.60, 0.16, 0.14 },
        parchment = { 0.95, 0.92, 0.82 }, cream = { 0.86, 0.80, 0.63 },
        brightGold = { 1.00, 0.82, 0.00 },
    },
    db = {},
    ready = true,
    blocked = nil,
    stat = { nodes = 10, mapCount = 2 },
}
ns.ClassificationNormalizeText = function(value)
    return type(value) == "string" and value:lower() or ""
end
ns.ClassificationIsPositiveInteger = function(value)
    return type(value) == "number" and value > 0 and value % 1 == 0
end
ns.ValidateSavedPosition = function(_, position)
    if type(position) ~= "table" or type(position.point) ~= "string" then return nil end
    return position
end

local messages = {}
ns.Print = function(_, message) messages[#messages + 1] = message end

local waypoint, focusedMapID
ns.Waypoints = {
    Set = function(_, mapID, x, y, title)
        waypoint = { mapID = mapID, x = x, y = y, title = title }
        return true
    end,
    ClearLast = function() return true end,
}
ns.FocusMap = function(_, mapID) focusedMapID = mapID; return true end

local searchToggles = 0
ns.ToggleSearchUI = function() searchToggles = searchToggles + 1 end

local browseCalls = {}
local function fixtureSections(query)
    local empty = query ~= nil and query ~= ""
    return {
        { key = "vendor", group = "services", name = "Vendors", icon = "vendor-icon",
            total = empty and 0 or 2, capped = false, rows = empty and {} or {
                { key = "vendor", mapID = 100, coord = 1, node = { x = 0.4, y = 0.6 },
                    entry = { id = 1 }, name = "Marshal Dughan", sub = "General Goods",
                    title = "Marshal Dughan - General Goods", zoneName = "Elwynn Forest" },
                { key = "vendor", mapID = 100, coord = 2, node = { x = 0.5, y = 0.5 },
                    entry = { id = 2 }, name = "Bags and Things", sub = "Trade Supplies",
                    title = "Bags and Things - Trade Supplies", zoneName = "Elwynn Forest" },
            } },
        { key = "flight", group = "services", name = "Flight Masters", icon = "flight-icon",
            total = 0, capped = false, rows = {} },
    }
end
ns.BrowseEntries = function(_, options)
    browseCalls[#browseCalls + 1] = options
    return fixtureSections(options.query)
end

local function mockObject(parent, name)
    local object = {
        scripts = {}, hooks = {}, points = {}, shown = false, frameLevel = 1,
        parent = parent, name = name,
    }
    function object:GetName() return self.name end
    function object:SetScript(name, callback) self.scripts[name] = callback end
    function object:HookScript(name, callback)
        self.hooks[name] = self.hooks[name] or {}
        self.hooks[name][#self.hooks[name] + 1] = callback
    end
    function object:SetPoint(point, relativeTo, relativePoint, x, y)
        if type(relativeTo) == "number" then
            x, y = relativeTo, relativePoint
            relativeTo, relativePoint = self.parent, point
        end
        self.points = { point, relativeTo, relativePoint, x, y }
    end
    function object:GetPoint()
        local point = self.points or {}
        return point[1], point[2], point[3], point[4], point[5]
    end
    function object:ClearAllPoints() self.points = {} end
    function object:SetSize() end
    function object:SetHeight() end
    function object:SetWidth() end
    function object:GetHeight() return 600 end
    function object:GetWidth() return 300 end
    function object:SetText(value) self.text = value end
    function object:SetFormattedText(format, ...) self.text = format:format(...) end
    function object:GetText() return self.text or "" end
    function object:SetTextColor() end
    function object:SetTexture() end
    function object:SetColorTexture() end
    function object:SetVertexColor() end
    function object:SetTexCoord() end
    function object:SetHighlightTexture() end
    function object:GetHighlightTexture() return mockObject(self) end
    function object:SetAlpha() end
    function object:SetAllPoints() end
    function object:SetAutoFocus() end
    function object:SetTextInsets() end
    function object:SetMaxLetters() end
    function object:SetJustifyH() end
    function object:SetFontObject() end
    function object:SetMultiLine() end
    function object:SetBackdrop() end
    function object:SetBackdropColor() end
    function object:SetBackdropBorderColor() end
    function object:SetClampedToScreen() end
    function object:SetMovable() end
    function object:EnableMouse() end
    function object:RegisterForDrag() end
    function object:RegisterForClicks() end
    function object:RegisterEvent() end
    function object:UnregisterEvent() end
    function object:UnregisterAllEvents() end
    function object:SetScrollChild(child) self.scrollChild = child end
    function object:SetFrameStrata(value) self.frameStrata = value end
    function object:GetFrameStrata() return self.frameStrata or "MEDIUM" end
    function object:SetFrameLevel(value) self.frameLevel = value end
    function object:GetFrameLevel() return self.frameLevel end
    function object:SetFocus() self.focused = true end
    function object:ClearFocus() self.focused = false end
    function object:StartMoving() end
    function object:StopMovingOrSizing() end
    function object:GetMapID() return 100 end
    function object:GetCanvasContainer() return nil end
    function object:IsShown() return self.shown end
    function object:SetWordWrap() end
    function object:GetLeft() return nil end
    function object:GetRight() return nil end
    function object:GetTop() return nil end
    function object:GetBottom() return nil end
    function object:Show()
        self.shown = true
        local callbacks = self.hooks.OnShow or {}
        for index = 1, #callbacks do callbacks[index](self) end
    end
    function object:Hide() self.shown = false end
    function object:CreateTexture() return mockObject(self) end
    function object:CreateFontString() return mockObject(self) end
    return object
end

UIParent = mockObject(nil, "UIParent")
WorldMapFrame = mockObject(nil, "WorldMapFrame")
WorldMapFrame.OnMapChanged = function() end
local canvas = mockObject(WorldMapFrame, "Canvas")
WorldMapFrame.GetCanvasContainer = function() return canvas end
BackdropTemplateMixin = nil
UISpecialFrames = {}
C_Timer = nil
C_Map = { GetMapInfo = function() return { name = "Elwynn Forest" } end }
GameTooltip = {
    SetOwner = function() end, AddLine = function() end, AddDoubleLine = function() end,
    Show = function() end, Hide = function() end,
}
GameTooltip_SetDefaultAnchor = function() end
hooksecurefunc = function(target, name, hook)
    if type(target) == "table" and type(target[name]) == "function" then
        local original = target[name]
        target[name] = function(...)
            local results = { original(...) }
            hook(...)
            return unpack(results)
        end
    end
end
InCombatLockdown = function() return false end
CreateFrame = function(_, name, parent, template)
    return mockObject(parent, name)
end

ns.Journal = {
    Decorate = function() end,
    Header = function() end,
    Text = function() return mockObject() end,
    Body = function() return mockObject() end,
    Input = function() return mockObject() end,
    Page = function() return mockObject() end,
    Solid = function() return mockObject() end,
    Button = function() return mockObject() end,
    CloseButton = function(parent, onClick)
        local button = mockObject(parent)
        button:SetScript("OnClick", onClick)
        return button
    end,
}

local chunk, err = loadfile("Browser.lua")
assert(chunk, err)
chunk("ForeverWayfinder", ns)

WorldMapTrackingPinButtonMixin = { OnLoad = function() end }
local pin = mockObject(WorldMapFrame, "WorldMapTrackingPinButton")
pin.OnLoad = WorldMapTrackingPinButtonMixin.OnLoad
pin:Show()
WorldMapFrame.overlayFrames = { pin }

-- Scenario 1: Questie's library is absent (or still loading). The icon must be
-- created lazily and anchored under Blizzard's pin without covering it.
LibStub = nil
ns:CreateBrowserUI()
local browser = ns.browser
assert(type(browser) == "table" and browser.panel, "browser panel is created")
assert(not browser.panel:IsShown(), "panel stays hidden while the map is closed")
assert(browser.icon == nil, "no map icon exists before the map is built")

local fallbackLines = browser:DescribeIcon()
assert(table.concat(fallbackLines, "\n"):find("open the world map once", 1, true),
    "diagnostics explain that the icon is not created yet")

WorldMapFrame:Show()
assert(browser.panel:IsShown(), "panel auto-shows with the map")
assert(browser.icon and browser.icon:IsShown(), "icon is created lazily and shown with the map")
assert(browser.icon.managed == false, "icon is self-anchored without Krowi")
assert(browser.icon.points[2] == pin, "icon hangs off Blizzard's pin button")
assert(browser.icon.points[3] == "BOTTOMLEFT", "icon starts at the pin's bottom edge")
assert(browser.icon.frameStrata == "HIGH", "icon uses the map button strata")
assert(browser.icon.background.points[1] == "TOPLEFT" and browser.icon.background.points[4] == 3,
    "medallion uses the pin template inset")
assert(browser.icon.glyph.points[4] == 7 and browser.icon.glyph.points[5] == -6,
    "glyph uses the pin template inset")
assert(browser.panel.context.text == "ELWYNN FOREST", "header shows the displayed map")
assert(browser.panel.placeholder.shown, "filter placeholder shows while the filter is empty")

local rowLine, sectionLine
for _, line in ipairs(browser.panel.lines) do
    if line.kind == "row" and not rowLine then rowLine = line end
    if line.kind == "section" then sectionLine = line end
end
assert(#browser.panel.lines == 3, "section header plus two rows rendered")
assert(browser.panel.status.text and browser.panel.status.text:find("2 locations", 1, true),
    "status reports the location count")
assert(browseCalls[#browseCalls].maps[1] == 100, "browse is scoped to the displayed map")

assert(rowLine and rowLine.row.name == "Marshal Dughan", "first row carries its entry")
assert(rowLine.title.text == "Marshal Dughan", "row title is the NPC name")
rowLine.scripts.OnClick(rowLine, "LeftButton")
assert(waypoint and waypoint.mapID == 100, "left click sets a waypoint on the row map")
assert(waypoint.title == "Marshal Dughan - General Goods", "waypoint keeps the full title")
rowLine.scripts.OnClick(rowLine, "RightButton")
assert(focusedMapID == 100, "right click focuses the row map")

assert(browser.scopeButtons and browser.scopeButtons.map and browser.scopeButtons.all,
    "scope buttons are created")
assert(browser.scopeButtons.map.points[2] == browser.scopeBar,
    "scope buttons live inside the segmented bar")
browser.scopeButtons.all.scripts.OnClick(browser.scopeButtons.all)
assert(ns.db.browserMode == "all", "all-zones scope is recorded")
assert(browseCalls[#browseCalls].maps == nil, "all-zones browse is not map-scoped")
assert(browser.panel.status.text:find("All zones", 1, true), "status reports all-zones scope")
assert(browser.panel.context.text == "ALL ZONES", "header reports the all-zones scope")
local zoneLine
for _, line in ipairs(browser.panel.lines) do
    if line.kind == "zone" then zoneLine = line end
end
assert(zoneLine and zoneLine.heading.text == "Elwynn Forest",
    "all-zones rows are grouped under zone headers")

browser.scopeButtons.map.scripts.OnClick(browser.scopeButtons.map)
assert(ns.db.browserMode == "map", "map scope is recorded again")
assert(browseCalls[#browseCalls].maps[1] == 100, "map scope browses the displayed map")

sectionLine.scripts.OnClick(sectionLine, "LeftButton")
assert(browser.panel.lines[2].shown == false, "collapsing a section hides its rows")
sectionLine.scripts.OnClick(sectionLine, "LeftButton")
assert(browser.panel.lines[2].shown == true, "expanding a section restores its rows")

browser.panel.filter.text = "zzz"
browser.panel.filter.scripts.OnTextChanged()
browser:ScheduleRefresh(0)
assert(browser.panel.status.text:find("No matches", 1, true), "empty filter result is reported")
assert(not browser.panel.placeholder.shown, "placeholder hides once the filter has text")

browser.closeButton.scripts.OnClick(browser.closeButton)
assert(not browser.panel:IsShown(), "close button hides the panel")
assert(browser.icon:IsShown(), "close leaves the icon on the map")
assert(ns.db.browserEnabled == false, "close records the preference")
assert(type(ns.db.browserPosition) == "table", "close saves the panel position")

browser.icon.scripts.OnClick(browser.icon, "LeftButton")
assert(browser.panel:IsShown(), "icon click reopens the panel")
assert(ns.db.browserEnabled == true, "icon click restores the preference")

browser.icon.scripts.OnClick(browser.icon, "RightButton")
assert(searchToggles == 1, "right click opens the NPC search")
assert(browser.panel:IsShown(), "right click leaves the panel state alone")

browser.icon.scripts.OnClick(browser.icon, "LeftButton")
assert(not browser.panel:IsShown(), "a second icon click hides the panel")

WorldMapFrame:Hide()
WorldMapFrame:Show()
assert(not browser.panel:IsShown(), "a closed panel stays closed when the map reopens")
assert(browser.icon:IsShown(), "the icon is available when the map reopens")

-- Scenario 2: Questie is installed and Krowi_WorldMapButtons owns the stack.
-- The icon must be registered through the library and must not be repositioned
-- by our own fallback code.
ns.browser = nil
local Browser = ns.Browser
Browser.panel = nil
Browser.icon = nil
Browser.scopeButtons = nil
Browser.collapsed = {}

local krowiLib
do
    local lib = { Buttons = {}, HasNoOverlay = false, IsForever = true }
    function lib.SetPoints()
        local y = 0
        for _, button in ipairs(lib.Buttons) do
            if button:IsShown() then
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", canvas, "TOPLEFT", 3, y)
                y = y - 32
            end
        end
    end
    function lib.Add(_, templateName, templateType)
        if not lib.Hooked then
            table.insert(lib.Buttons, pin)
            lib.Hooked = true
        end
        local button = mockObject(WorldMapFrame)
        button:SetPoint("TOPLEFT", canvas, "TOPLEFT", 3, -#lib.Buttons * 32)
        button:Show()
        button.Refresh = function() end
        table.insert(lib.Buttons, button)
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            button:Refresh()
            lib.SetPoints()
        end)
        return button
    end
    krowiLib = lib
end
LibStub = setmetatable({}, {
    __call = function(_, name)
        if name ~= "Krowi_WorldMapButtons-1.4" then error("unknown library") end
        return krowiLib
    end,
})

ns:CreateBrowserUI()
browser = ns.browser
assert(browser.icon and browser.icon.managed, "icon registers through Krowi when Questie is present")
assert(krowiLib.Buttons[1] == pin and krowiLib.Buttons[2] == browser.icon,
    "Krowi owns the pin and our icon, in that order")
assert(browser.icon.points[2] == canvas, "Krowi anchors the icon to the map canvas")
assert(browser.icon.points[4] == 3 and browser.icon.points[5] == -32,
    "Krowi places the icon in the first slot below the pin")
assert(browser.icon.Refresh and type(browser.icon.Refresh) == "function",
    "icon exposes the Refresh method Krowi calls")

local questieButton = krowiLib.Add(krowiLib, nil, "Button")
krowiLib.SetPoints()
assert(browser.icon.points[5] == -32, "a later sibling does not displace our slot")
assert(questieButton.points[5] == -64, "the later sibling stacks below ours")
WorldMapFrame.OnMapChanged()
assert(browser.icon.points[5] == -32, "map changes keep the icon in its Krowi slot")

local function SetRect(frame, left, top)
    frame.GetLeft = function() return left end
    frame.GetRight = function() return left + 32 end
    frame.GetTop = function() return top end
    frame.GetBottom = function() return top - 32 end
end
SetRect(pin, 3, 200)
SetRect(browser.icon, 3, 168)
SetRect(questieButton, 3, 136)

local managedLines = table.concat(browser:DescribeIcon(), "\n")
assert(managedLines:find("Krowi-managed", 1, true), "diagnostics report the managed mode")
assert(managedLines:find("Overlap check: clear.", 1, true), "diagnostics report no overlaps")

assert(#messages == 0, "no errors were printed")

print("Forever Wayfinder browser UI lifecycle tests passed.")
