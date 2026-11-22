-- Lightweight WoW-frame mock for the world map browser lifecycle.
-- Run standalone with Lua 5.1: lua tests/browser_ui.lua
local ns = {
    MEDIA = { addonIcon = "icon" },
    Colors = {
        gold = { 0.83, 0.69, 0.32 }, muted = { 0.62, 0.59, 0.52 },
        pageHover = { 0.80, 0.72, 0.53 }, ink = { 0.24, 0.17, 0.10 },
        inkMuted = { 0.47, 0.40, 0.29 }, goldLine = { 0.72, 0.58, 0.30 },
        leatherDark = { 0.10, 0.07, 0.045 },
    },
    db = {},
    ready = true,
    blocked = nil,
}
ns.ClassificationNormalizeText = function(value)
    return type(value) == "string" and value:lower() or ""
end
ns.ClassificationIsPositiveInteger = function(value)
    return type(value) == "number" and value > 0 and value % 1 == 0
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

local function mockObject(parent)
    local object = { scripts = {}, hooks = {}, points = {}, shown = false, frameLevel = 1, parent = parent }
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
    function object:SetFrameLevel(value) self.frameLevel = value end
    function object:GetFrameLevel() return self.frameLevel end
    function object:SetFocus() self.focused = true end
    function object:ClearFocus() self.focused = false end
    function object:StartMoving() end
    function object:StopMovingOrSizing() end
    function object:GetMapID() return 100 end
    function object:GetCanvasContainer() return nil end
    function object:IsShown() return self.shown end
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

UIParent = mockObject()
WorldMapFrame = mockObject()
BackdropTemplateMixin = nil
UISpecialFrames = {}
C_Timer = nil
GameTooltip = { SetOwner = function() end, AddLine = function() end, Show = function() end, Hide = function() end }
GameTooltip_SetDefaultAnchor = function() end
hooksecurefunc = function() end
InCombatLockdown = function() return false end
CreateFrame = function(_, _, parent)
    return mockObject(parent)
end

ns.Journal = {
    Decorate = function() end,
    Header = function() end,
    Text = function() return mockObject() end,
    Input = function() return mockObject() end,
    Page = function() return mockObject() end,
    Solid = function() return mockObject() end,
    Button = function() return mockObject() end,
}

local chunk, err = loadfile("Browser.lua")
assert(chunk, err)
chunk("ForeverWayfinder", ns)

ns:CreateBrowserUI()
local browser = ns.browser
assert(type(browser) == "table" and browser.panel, "browser panel is created")
assert(not browser.panel:IsShown(), "panel stays hidden while the map is closed")
assert(not browser.tab:IsShown(), "tab stays hidden while the map is closed")

WorldMapFrame:Show()
assert(browser.panel:IsShown(), "panel auto-shows with the map")
assert(not browser.tab:IsShown(), "tab hides while the panel is open")
assert(#browser.panel.lines == 3, "section header plus two rows rendered")
assert(browser.panel.status.text and browser.panel.status.text:find("2 locations", 1, true),
    "status reports the location count")
assert(browseCalls[#browseCalls].maps[1] == 100, "browse is scoped to the displayed map")

local rowLine, sectionLine
for _, line in ipairs(browser.panel.lines) do
    if line.kind == "row" and not rowLine then rowLine = line end
    if line.kind == "section" then sectionLine = line end
end
assert(rowLine and rowLine.row.name == "Marshal Dughan", "first row carries its entry")
assert(rowLine.title.text == "Marshal Dughan", "row title is the NPC name")
rowLine.scripts.OnClick(rowLine, "LeftButton")
assert(waypoint and waypoint.mapID == 100, "left click sets a waypoint on the row map")
assert(waypoint.title == "Marshal Dughan - General Goods", "waypoint keeps the full title")
rowLine.scripts.OnClick(rowLine, "RightButton")
assert(focusedMapID == 100, "right click focuses the row map")

sectionLine.scripts.OnClick(sectionLine, "LeftButton")
assert(browser.panel.lines[2].shown == false, "collapsing a section hides its rows")
sectionLine.scripts.OnClick(sectionLine, "LeftButton")
assert(browser.panel.lines[2].shown == true, "expanding a section restores its rows")

browser.panel.filter.text = "zzz"
browser:ScheduleRefresh(0)
assert(browser.panel.status.text:find("No matches", 1, true), "empty filter result is reported")

browser:Hide()
assert(not browser.panel:IsShown(), "close hides the panel")
assert(browser.tab:IsShown(), "close leaves the tab on the map")
assert(ns.db.browserEnabled == false, "close records the preference")
assert(type(ns.db.browserPosition) == "table", "close saves the panel position")

browser.tab.scripts.OnClick(browser.tab)
assert(browser.panel:IsShown(), "tab click reopens the panel")
assert(ns.db.browserEnabled == true, "tab click restores the preference")

browser:Hide()
WorldMapFrame:Hide()
WorldMapFrame:Show()
assert(not browser.panel:IsShown(), "a closed panel stays closed when the map reopens")
assert(browser.tab:IsShown(), "the tab is available when the map reopens")
assert(#messages == 0, "no errors were printed")

print("Forever Wayfinder browser UI lifecycle tests passed.")
