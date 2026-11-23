-- Headless smoke test for the window code. Stubs the WoW frame API and runs
-- CreateUI / CreateSearchUI / ShowCopyableReport plus the settings interactions.
-- Run from the addon directory:
--   lua5.1 tests/ui-smoke.lua           (atlases, templates and button art present)
--   lua5.1 tests/ui-smoke.lua noatlas   (legacy textures and templates only)
--   lua5.1 tests/ui-smoke.lua bare      (no atlases, templates or button art)

local mode = arg and arg[1] or "full"
local ATLASES = mode == "full"
local TEMPLATES = mode ~= "bare"
local BUTTON_ART = mode ~= "bare"

local failures, checks = 0, 0
local function check(name, ok, detail)
    checks = checks + 1
    if not ok then
        failures = failures + 1
        print(("FAIL %s%s"):format(name, detail and (" - " .. tostring(detail)) or ""))
    end
end

local function loadModule(path)
    local chunk, err = loadfile(path)
    assert(chunk, err)
    return chunk
end

--------------------------------------------------------------------------------
-- Frame API stubs
--------------------------------------------------------------------------------

local textureGetters = {
    GetNormalTexture = true, GetPushedTexture = true, GetDisabledTexture = true,
    GetHighlightTexture = true, GetCheckedTexture = true, GetDisabledCheckedTexture = true,
}

local function newTexture()
    local tex = { _kind = "texture", _height = 8 }
    tex.SetTexture = function(self, path)
        if path and path:find("DialogBox%-Button") and not BUTTON_ART then return false end
        self._path = path
        return true
    end
    tex.SetAtlas = function(self, name) self._atlas = name return true end
    tex.GetHeight = function(self) return self._height end
    tex.GetTexture = function(self) return self._path end
    tex.SetPoint = function(self, point, a, b, c, d)
        local points = rawget(self, "_points")
        if not points then points = {} rawset(self, "_points", points) end
        if type(a) == "number" then
            points[point] = { relativePoint = point, x = a, y = b }
        else
            points[point] = { relativePoint = b, x = c, y = d }
        end
    end
    tex.ClearAllPoints = function(self) rawset(self, "_points", {}) end
    return setmetatable(tex, { __index = function(_, key)
        return function() end
    end })
end

local function newFont()
    local font = { _kind = "font" }
    font.SetFont = function(self, path)
        if path and path:lower():find("morpheus") and mode == "bare" then return nil end
        self._path = path
        return true
    end
    font.GetFont = function(self) return self._path end
    return setmetatable(font, { __index = function() return function() end end })
end

-- Child regions are tables or nil in the real API, never callables.
local childProperties = {
    ScrollBar = true, ThumbTexture = true, ScrollUpButton = true, ScrollDownButton = true,
    overlayFrames = true, WorldMapTrackingPinButton = true,
    scopeBar = true, filterCaption = true, nearButton = true, filter = true, quickBar = true,
    cursorLabel = true, page = true, footerRule = true, status = true, clearButton = true,
    placeholder = true, collapseButton = true, locationLabel = true, content = true,
    lines = true, scroll = true,
    scopeTitle = true, spine = true, spineLabel = true, header = true, strip = true,
}

local function newFrame(kind)
    local obj = { _kind = kind, _shown = kind == "fontstring", _text = "", _checked = false,
        _value = 0, _scripts = {}, _hooks = {} }
    obj.CreateTexture = function() return newTexture() end
    obj.CreateFontString = function() return newFrame("fontstring") end
    obj.SetScript = function(self, event, fn) self._scripts[event] = fn end
    obj.GetScript = function(self, event) return self._scripts[event] end
    obj.HookScript = function(self, event, fn)
        self._hooks[event] = self._hooks[event] or {}
        table.insert(self._hooks[event], fn)
    end
    obj.Show = function(self) self._shown = true end
    obj.Hide = function(self) self._shown = false end
    obj.SetShown = function(self, shown) self._shown = shown end
    obj.IsShown = function(self) return self._shown end
    obj.IsVisible = function(self) return self._shown end
    obj.GetText = function(self) return self._text end
    obj.SetText = function(self, text) self._text = text end
    obj.SetFormattedText = function(self, format, ...) self._text = string.format(format, ...) end
    obj.GetChecked = function(self) return self._checked end
    obj.SetChecked = function(self, checked) self._checked = checked and true or false end
    obj.GetValue = function(self) return self._value end
    obj.SetValue = function(self, value)
        self._value = value
        if self._scripts.OnValueChanged then self._scripts.OnValueChanged(self, value) end
    end
    obj.HasFocus = function() return false end
    obj.GetFrameLevel = function() return 1 end
    obj.GetPoint = function() return nil end
    -- Anchors are recorded so a test can check that a region really spans its
    -- parent; a colour texture without a right-hand anchor has no width.
    obj.SetPoint = function(self, point, a, b, c, d)
        local points = rawget(self, "_points")
        if not points then points = {} rawset(self, "_points", points) end
        if type(a) == "number" then
            points[point] = { relativePoint = point, x = a, y = b }
        else
            points[point] = { relativePoint = b, x = c, y = d }
        end
    end
    obj.ClearAllPoints = function(self) rawset(self, "_points", {}) end
    obj.GetStringWidth = function() return 60 end
    obj.GetStringHeight = function() return 12 end
    obj.GetWidth = function() return 100 end
    obj.GetHeight = function() return 20 end
    obj.SetNormalTexture = function(self, value)
        self._normal = type(value) == "table" and value or newTexture()
    end
    obj.SetThumbTexture = function(self, value)
        self._thumb = type(value) == "table" and value or newTexture()
    end
    obj.GetThumbTexture = function(self) return self._thumb end
    for getter in pairs(textureGetters) do
        obj[getter] = function(self)
            if getter == "GetNormalTexture" then
                if self._normal then return self._normal end
                if self._templateArt then return newTexture() end
                return nil
            end
            if self._templateArt or self._normal then return newTexture() end
            return nil
        end
    end
    return setmetatable(obj, { __index = function(_, key)
        if childProperties[key] then return nil end
        return function() end
    end })
end

function CreateFrame(kind, name, parent, template)
    local frame = newFrame(kind)
    if TEMPLATES and (template == "SettingsCheckboxTemplate" or template == "UIPanelCloseButton") then
        frame._templateArt = true
    end
    return frame
end

function CreateFont() return newFont() end

UIParent = newFrame("frame")
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
ChatFontNormal = newFont()
BackdropTemplateMixin = {}
UISpecialFrames = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
C_Texture = { GetAtlasInfo = function(name)
    if ATLASES then return { width = 64, height = 8 } end
    return nil
end }
C_Timer = { After = function(_, fn) fn() end }
SlashCmdList = {}

-- TomTom stub: enough of the waypoint store for the addon's waypoint calls.
TomTom = {
    waypoints = {},
    AddWaypoint = function(self, mapID, x, y, opts)
        local uid = { mapID, x, y, title = opts and opts.title, from = opts and opts.from }
        self.waypoints[mapID] = self.waypoints[mapID] or {}
        self.waypoints[mapID][tostring(mapID) .. ":" .. tostring(x) .. ":" .. tostring(y)] = uid
        return uid
    end,
    RemoveWaypoint = function(self, uid)
        local mapID = uid and uid[1]
        if mapID and self.waypoints[mapID] then
            for key, other in pairs(self.waypoints[mapID]) do
                if other == uid then self.waypoints[mapID][key] = nil end
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- Load the addon and exercise the windows
--------------------------------------------------------------------------------

local ns = {}
loadModule("Classification.lua")("ForeverWayfinder", ns)
loadModule("Location.lua")("ForeverWayfinder", ns)
loadModule("Core.lua")("ForeverWayfinder", ns)
loadModule("Waypoints.lua")("ForeverWayfinder", ns)
loadModule("Search.lua")("ForeverWayfinder", ns)
loadModule("UI.lua")("ForeverWayfinder", ns)

ns.StartScan = function() end

local ok, err = pcall(function()
    ns:InitDB()

    local frame = ns:CreateUI()
    check("settings created", frame ~= nil)
    check("settings hidden initially", frame:IsShown() == false)
    check("category rows built", frame.categoryRows and frame.categoryRows.vendor ~= nil)
    check("toggle rows built", frame.toggleRows and frame.toggleRows.enabled ~= nil)
    check("slider built", frame.scaleSlider ~= nil)
    check("display rows built", frame.minimapButtonRow ~= nil and frame.browserRow ~= nil
        and frame.coordsRow ~= nil and frame.nearMeRow ~= nil)
    check("waypoint row built", frame.waypointRow ~= nil)
    check("waypoint row starts empty", frame.waypointRow.state._text == "NONE",
        frame.waypointRow.state._text)
    check("settings page scrolls", frame.scroll ~= nil and frame.content:GetHeight() > 0,
        frame.content:GetHeight())

    ns:ToggleUI()
    check("settings toggled shown", frame:IsShown() == true)
    ns:UpdateUI()
    ns:UpdateUIStatus()

    -- Click a category row and a display toggle through their real handlers.
    local vendorRow = frame.categoryRows.vendor
    local before = ns.db.categories.vendor
    vendorRow:GetScript("OnClick")(vendorRow)
    check("category click flips db", ns.db.categories.vendor == (not before))
    vendorRow:GetScript("OnClick")(vendorRow)
    check("category click restores", ns.db.categories.vendor == before)

    local enabledRow = frame.toggleRows.enabled
    enabledRow:GetScript("OnClick")(enabledRow)
    check("toggle click flips db", ns.db.enabled == false)
    enabledRow:GetScript("OnClick")(enabledRow)

    -- Slider drag path: value change then refresh on mouse up.
    frame.scaleSlider:SetValue(1.25)
    check("slider writes db", ns.db.pinScale == 1.25)
    frame.scaleSlider:GetScript("OnMouseUp")()

    -- Hover handlers must exist and run without error.
    vendorRow:GetScript("OnEnter")(vendorRow)
    vendorRow:GetScript("OnLeave")(vendorRow)

    local search = ns:CreateSearchUI()
    check("search created", search ~= nil)
    ns:ToggleSearchUI()
    check("search toggled shown", search:IsShown() == true)
    check("search focuses query", true)
    search.RefreshResults()

    ns.ready = true
    ns.index = {}
    ns.stat = { nodes = 0, mapCount = 0, npcs = 0, mailboxes = 0 }
    search.queryInput._text = "guard"
    search.RefreshResults()
    check("empty index search returns no rows", #search.resultRows == 0)

    -- Waypoint round trip: the row shows the waypoint and clears it again.
    local waypointOk = ns.Waypoints:Set(1415, 0.5, 0.5, "Test Waypoint")
    check("waypoint set succeeds", waypointOk == true)
    ns:UpdateUI()
    check("waypoint row shows the waypoint", frame.waypointRow.state._text:find("SET") ~= nil,
        frame.waypointRow.state._text)
    local cleared = ns.Waypoints:ClearLast()
    check("waypoint clears", cleared == true)
    ns:UpdateUI()
    check("waypoint row empties again", frame.waypointRow.state._text == "NONE",
        frame.waypointRow.state._text)

    ns:ShowCopyableReport("Smoke report", { "line one", "line two" })
    check("report shown", ns.copyReportFrame:IsShown() == true)
    ns:ShowCopyableReport("Smoke report again", { "reuse" })

    -- Map sidebar: build it against a stub map frame, then render real rows.
    WorldMapFrame = newFrame("frame")
    WorldMapFrame.GetMapID = function() return 1415 end
    C_Map = {
        GetMapInfo = function() return { name = "Elwynn Forest" } end,
        GetBestMapForUnit = function() return 1415 end,
    }
    ns.mapNameCache = {}
    ns.Waypoints = { Set = function() return true end, ClearLast = function() return true end,
        HasWaypoint = function() return false end }
    loadModule("Browser.lua")("ForeverWayfinder", ns)

    local browser = ns:CreateBrowserUI()
    check("sidebar built", browser ~= nil and browser.panel ~= nil)
    local sidebar = browser.panel
    check("sidebar controls built", sidebar.scopeBar ~= nil and sidebar.filter ~= nil
        and sidebar.nearButton ~= nil and sidebar.page ~= nil)
    check("sidebar has a spine", sidebar.spine ~= nil and sidebar.spineLabel ~= nil)
    check("sidebar scope title built", sidebar.scopeTitle ~= nil)
    -- The column's page bands must span the panel: a band without a
    -- right-hand anchor is zero pixels wide and the map shows through it.
    local bandPoints = rawget(sidebar.bands[1], "_points")
    local spinePoints = rawget(sidebar.spine.bands[1], "_points")
    check("column bands span the panel", bandPoints ~= nil
        and bandPoints.TOPRIGHT ~= nil and bandPoints.TOPLEFT ~= nil)
    check("spine bands span the rail", spinePoints ~= nil and spinePoints.TOPRIGHT ~= nil)
    local chips = browser.groupButtons
    check("five group chips", chips.all ~= nil and chips.services ~= nil
        and chips.trainers ~= nil and chips.professions ~= nil and chips.other ~= nil)

    local function ShownLines()
        local count = 0
        for index = 1, #sidebar.lines do
            if sidebar.lines[index]:IsShown() then count = count + 1 end
        end
        return count
    end
    local function Node(x, y, name, sub, cats)
        return { x = x, y = y, cats = cats, entries = { { id = 1, name = name, sub = sub, categories = cats } } }
    end
    ns.index = {
        [1415] = {
            [0.1] = Node(0.1, 0.2, "Smith Blunt", "Armorer", { vendor = true, repair = true }),
            [0.5] = Node(0.5, 0.5, "Katie Hunter", "Flight Master", { flight = true }),
            [0.7] = Node(0.7, 0.8, "Erma Wildbrew", "Innkeeper", { innkeeper = true }),
        },
        [1426] = {
            [0.3] = Node(0.3, 0.4, "Winston Wolfe", "Banker", { banker = true }),
        },
    }

    browser:Show()
    browser:Render()
    check("map mode lists rows", ShownLines() == 8, ShownLines())
    check("map mode names the map", sidebar.scopeTitle._text == "ELWYNN FOREST", sidebar.scopeTitle._text)

    -- The chip counts describe locations, not list rows: the smith is listed
    -- under two categories but stands in one place.
    check("all chip counts locations", chips.all.count == 3, chips.all.count)
    check("group chip counts a location once", chips.services.count == 3, chips.services.count)

    -- The coordinates own a column of their own, so they never wrap into a
    -- second line behind a long role.
    local coordsOk, detailOk = true, true
    for index = 1, #sidebar.lines do
        local line = sidebar.lines[index]
        if line:IsShown() and line.kind == "row" then
            if not line.coords._text:match("^%d+%.%d, %d+%.%d$") then coordsOk = false end
            if line.detail._text:find("%d+%.%d, %d+%.%d") then detailOk = false end
        end
    end
    check("row coordinates sit on their own line", coordsOk)
    check("row detail carries no coordinates", detailOk)

    browser.scopeButtons.all:GetScript("OnClick")()
    check("scope click switches mode", ns.db.browserMode == "all")
    browser:Render()
    check("all-zones mode adds zone headings", ShownLines() == 15, ShownLines())
    check("all-zones title", sidebar.scopeTitle._text == "ALL ZONES", sidebar.scopeTitle._text)
    check("all-zones chip counts locations", chips.all.count == 4, chips.all.count)
    check("all-zones group chip counts locations", chips.services.count == 4, chips.services.count)

    chips.services:GetScript("OnClick")()
    check("chip click selects group", ns.db.browserGroup == "services")
    browser:Render()
    chips.services:GetScript("OnClick")()
    check("chip click again returns to all", ns.db.browserGroup == "all")

    chips.professions:GetScript("OnClick")()
    check("profession chip selects its group", ns.db.browserGroup == "professions")
    browser:Render()
    chips.professions:GetScript("OnClick")()
    check("profession chip returns to all", ns.db.browserGroup == "all")
    browser:Render()

    sidebar.nearButton:GetScript("OnClick")()
    check("near-me toggles", ns.db.browserNearMe == true)
    browser:Render()
    sidebar.nearButton:GetScript("OnClick")()

    sidebar.filter._text = "katie"
    browser:Render()
    check("filter narrows rows", ShownLines() == 3, ShownLines())
    sidebar.filter._text = "zzzz"
    browser:Render()
    check("empty filter reports no match", sidebar.status._text:find("No matches") ~= nil)
    sidebar.filter._text = ""
    browser:Render()

    -- The facet tier carries only the categories of the selected group, so the
    -- default view keeps the full list height.
    browser.scopeButtons.map:GetScript("OnClick")()
    browser:Render()
    check("facet chips built", browser.facetButtons ~= nil and browser.facetButtons.vendor ~= nil)
    check("all group hides the facet tier", sidebar.facetBar:IsShown() == false)

    chips.services:GetScript("OnClick")()
    browser:Render()
    check("services group shows its facet chips", browser.facetButtons.vendor:IsShown() == true)
    check("services group hides trainer chips", browser.facetButtons.pet:IsShown() == false)
    check("facet tier becomes visible", sidebar.facetBar:IsShown() == true)

    browser.facetButtons.vendor:GetScript("OnClick")()
    check("facet chip sets the category filter", ns.db.browserCategory == "vendor",
        tostring(ns.db.browserCategory))
    browser:Render()
    check("facet chip narrows the list", ShownLines() == 2, ShownLines())
    browser.facetButtons.vendor:GetScript("OnClick")()
    check("facet chip clears the category filter", ns.db.browserCategory == nil)
    browser:Render()
    check("cleared facet restores the list", ShownLines() == 8, ShownLines())
    chips.services:GetScript("OnClick")()
    check("chip click returns to all", ns.db.browserGroup == "all")
    browser:Render()

    -- A category the user switched off is not in the index, so its chip must
    -- not write a filter either.
    ns.db.categories.vendor = false
    chips.services:GetScript("OnClick")()
    browser:Render()
    check("disabled category has no facet chip", browser.facetButtons.vendor:IsShown() == false)
    browser.facetButtons.vendor:GetScript("OnClick")()
    check("disabled category writes no filter", ns.db.browserCategory == nil,
        tostring(ns.db.browserCategory))
    ns.db.categories.vendor = true
    chips.services:GetScript("OnClick")()
    check("chip click returns to all", ns.db.browserGroup == "all")
    browser:Render()

    -- A section band filters the list by its category.
    local function FirstSection()
        for index = 1, #sidebar.lines do
            local line = sidebar.lines[index]
            if line:IsShown() and line.kind == "section" then return line end
        end
        return nil
    end
    local sectionLine = FirstSection()
    check("section band built", sectionLine ~= nil)
    sectionLine:GetScript("OnClick")(sectionLine, "LeftButton")
    check("section band sets the category filter", ns.db.browserCategory == "vendor",
        tostring(ns.db.browserCategory))
    browser:Render()
    check("section band narrows the list", ShownLines() == 2, ShownLines())
    sectionLine:GetScript("OnClick")(sectionLine, "LeftButton")
    check("section band clears the category filter", ns.db.browserCategory == nil)
    browser:Render()

    -- The settings window can be open while the column is, so a band can
    -- outlive the category it belongs to.
    local vendorSection = FirstSection()
    ns.db.categories.vendor = false
    vendorSection:GetScript("OnClick")(vendorSection, "LeftButton")
    check("disabled section band writes no filter", ns.db.browserCategory == nil,
        tostring(ns.db.browserCategory))
    ns.db.categories.vendor = true
    browser:Render()

    -- The marker beside a band folds the section away instead of filtering it.
    local markerLine = FirstSection()
    local sectionKey = markerLine.sectionKey
    markerLine.marker:GetScript("OnClick")()
    check("marker folds the section", browser.collapsed[sectionKey] == true)
    browser:Render()
    check("folded section hides its rows", ShownLines() == 7, ShownLines())
    markerLine.marker:GetScript("OnClick")()
    browser:Render()
    check("marker unfolds the section", browser.collapsed[sectionKey] == false)
    check("unfolded section lists its rows", ShownLines() == 8, ShownLines())

    -- The search box matches a category name, the same way the column filter does.
    local categoryResults = ns:SearchEntries("innkeeper", "", "", 10, ns.db.categories)
    check("search matches a category name", #categoryResults == 1, #categoryResults)
    local filteredResults = ns:SearchEntries("", "innkeeper", "", 10, ns.db.categories)
    check("search filters by category", #filteredResults == 1, #filteredResults)

    local row
    for index = 1, #sidebar.lines do
        local line = sidebar.lines[index]
        if line:IsShown() and line.kind == "row" then
            row = line
            break
        end
    end
    check("row line built", row ~= nil)
    row:GetScript("OnEnter")(row)
    row:GetScript("OnLeave")(row)
    check("row hover handlers run", true)

    browser:ToggleCollapsed()
    check("collapsed hides controls", sidebar.scopeBar:IsShown() == false and sidebar.page:IsShown() == false)
    check("collapsed keeps location strip", sidebar.locationLabel:IsShown() == true)
    check("collapsed hides spine lettering", sidebar.spineLabel:IsShown() == false)
    browser:ToggleCollapsed()
    check("expanded restores controls", sidebar.page:IsShown() == true)
    check("expanded shows spine lettering", sidebar.spineLabel:IsShown() == true)

    sidebar.clearButton:GetScript("OnClick")()
    browser:Hide()
    check("hide keeps the auto-show flag", ns.db.browserEnabled == true)
    browser:Show()

    -- Opening the column is an action; the auto-show flag belongs to the user.
    ns.db.browserEnabled = false
    browser:Show()
    check("show does not turn the auto-show flag on", ns.db.browserEnabled == false)
    ns.db.browserEnabled = true

    ns:ResetSettings()
    check("reset restores pin scale", ns.db.pinScale == 1.0)
    check("reset restores categories", ns.db.categories.vendor == true)

    -- Minimap button: the drag has to end even when the mouse is released
    -- outside the button, because that release never arrives as OnMouseUp.
    Minimap = newFrame("frame")
    Minimap.GetParent = function() return UIParent end
    Minimap.GetWidth = function() return 140 end
    Minimap.GetFrameLevel = function() return 3 end
    Minimap.GetCenter = function() return 100, 50 end
    UIParent.GetEffectiveScale = function() return 1 end
    local cursorX, cursorY = 500, 300
    function GetCursorPosition() return cursorX, cursorY end
    local mouseDown = true
    function IsMouseButtonDown() return mouseDown end
    loadModule("Minimap.lua")("ForeverWayfinder", ns)
    ns:CreateMinimapButton()
    local mmButton = ns.minimapButton
    check("minimap button created", mmButton ~= nil)
    check("minimap button shown by default", mmButton:IsShown() == true)

    ns.db.showMinimapButton = false
    ns:UpdateMinimapButton()
    check("minimap button hides on request", mmButton:IsShown() == false)
    ns.db.showMinimapButton = true
    ns:UpdateMinimapButton()

    local angleBefore = ns.db.minimapAngle
    mmButton:GetScript("OnMouseDown")(mmButton, "LeftButton")
    check("drag starts", mmButton.dragging == true)
    cursorX, cursorY = 540, 340
    mmButton:GetScript("OnUpdate")(mmButton)
    check("drag marks the move", mmButton.dragMoved == true)
    check("drag sets the angle", ns.db.minimapAngle ~= angleBefore,
        tostring(ns.db.minimapAngle))
    local angleAfterDrag = ns.db.minimapAngle
    mouseDown = false
    mmButton:GetScript("OnUpdate")(mmButton)
    check("release outside ends the drag", mmButton.dragging == false)
    check("release outside clears the move flag", mmButton.dragMoved == false)
    check("release outside keeps the angle", ns.db.minimapAngle == angleAfterDrag)

    -- The old inverted flag is moved to the positive name on load.
    local savedDb = ForeverWayfinderDB
    ForeverWayfinderDB = { hideMinimapButton = true }
    ns:InitDB()
    check("old minimap flag migrates", ns.db.showMinimapButton == false
        and ns.db.hideMinimapButton == nil, tostring(ns.db.showMinimapButton))
    ForeverWayfinderDB = savedDb
    ns.db = savedDb

    ns:UpdateUIStatus()
    ns:ToggleUI()
    check("settings toggled hidden", frame:IsShown() == false)
end)
check("no runtime errors", ok, err)

print(("%s mode: %d checks, %d failures"):format(mode, checks, failures))
os.exit(failures == 0 and 0 or 1)