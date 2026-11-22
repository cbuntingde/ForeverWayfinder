local ADDON, ns = ...

-- Search is deliberately independent of frame code so filtering remains testable.
local function Contains(haystack, needle)
    return haystack:find(needle, 1, true) ~= nil
end

-- Map names are stable for the life of an index; ResetIndex clears the cache.
function ns:GetMapName(mapID)
    local cached = self.mapNameCache[mapID]
    if cached then return cached end
    local name = "Map " .. tostring(mapID)
    if C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, mapID)
        if ok and type(info) == "table" and type(info.name) == "string" then
            name = info.name
        end
    end
    self.mapNameCache[mapID] = name
    return name
end

function ns:SearchEntries(query, categoryFilter, zoneFilter, limit)
    if not self.ready or type(self.index) ~= "table" then
        return {}, "index-not-ready"
    end

    query = ns.ClassificationNormalizeText(query)
    categoryFilter = ns.ClassificationNormalizeText(categoryFilter)
    zoneFilter = ns.ClassificationNormalizeText(zoneFilter)
    limit = ns.ClassificationIsPositiveInteger(limit) and math.min(limit, 200) or 100

    if query == "" and categoryFilter == "" and zoneFilter == "" then
        return {}, "query-required"
    end

    local numericZoneID = tonumber(zoneFilter)
    local exactMapID = numericZoneID and ns.ClassificationIsPositiveInteger(numericZoneID)

    local categoryNames
    if categoryFilter ~= "" then
        categoryNames = {}
        for key, category in pairs(self.categoryByKey or {}) do
            categoryNames[key] = {
                key = ns.ClassificationNormalizeText(key),
                name = ns.ClassificationNormalizeText(category.name),
            }
        end
    end

    local results = {}
    for mapID, nodes in pairs(self.index) do
        local mapName = self:GetMapName(mapID)
        local zoneMatches = zoneFilter == ""
            or (exactMapID and mapID == numericZoneID)
            or (not exactMapID and Contains(ns.ClassificationNormalizeText(mapName), zoneFilter))

        if zoneMatches and type(nodes) == "table" then
            for coord, node in pairs(nodes) do
                if type(node) == "table" and type(node.entries) == "table" then
                    for index = 1, #node.entries do
                        local entry = node.entries[index]
                        if type(entry) == "table" then
                            -- Index-time normalized text keeps broad queries cheap; the
                            -- fallback covers entries built without it.
                            local name = entry.searchName or ns.ClassificationNormalizeText(entry.name)
                            local sub = entry.searchSub or ns.ClassificationNormalizeText(entry.sub)
                            local textMatches = query == "" or Contains(name, query) or Contains(sub, query)
                            local categoryMatches = categoryFilter == ""
                            local matchedCategory = nil

                            if not categoryMatches then
                                for key in pairs(entry.categories or {}) do
                                    local names = categoryNames[key]
                                    if names and (Contains(names.key, categoryFilter)
                                        or Contains(names.name, categoryFilter)) then
                                        categoryMatches = true
                                        matchedCategory = key
                                        break
                                    end
                                end
                            end

                            if textMatches and categoryMatches then
                                results[#results + 1] = {
                                    entry = entry, node = node, mapID = mapID, coord = coord,
                                    mapName = mapName, matchedCategory = matchedCategory,
                                    sortName = name, sortSub = sub,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(results, function(a, b)
        if a.sortName ~= b.sortName then return a.sortName < b.sortName end
        if a.sortSub ~= b.sortSub then return a.sortSub < b.sortSub end
        if a.mapID ~= b.mapID then return a.mapID < b.mapID end
        if a.coord ~= b.coord then return a.coord < b.coord end
        return (a.entry.id or 0) < (b.entry.id or 0)
    end)

    while #results > limit do results[#results] = nil end
    return results
end

--------------------------------------------------------------------------------------------
-- Browse: category-grouped listing for the world map browser
--------------------------------------------------------------------------------------------

-- options = {
--   maps       = array or map-set of UI map IDs; nil browses every indexed map,
--                an empty table browses nothing.
--   query      = optional name/sub-name substring, normalized like search.
--   categories = optional enabled-category set (db.categories); nil enables all.
--   limit      = rows kept per category after sorting (default 100).
-- }
-- Returns sections in category-group order plus meta { shown = n, capped = boolean }.
-- Rows are per indexed entry so the categories shown always match the entry itself;
-- the waypoint target stays the shared node.
function ns:BrowseEntries(options)
    if not self.ready or type(self.index) ~= "table" then
        return {}, { shown = 0, capped = false, reason = "index-not-ready" }
    end
    if type(options) ~= "table" then options = {} end

    local query = ns.ClassificationNormalizeText(options.query)
    local limit = ns.ClassificationIsPositiveInteger(options.limit) and options.limit or 100
    local enabled = type(options.categories) == "table" and options.categories or nil

    local mapScope
    if type(options.maps) == "table" then
        mapScope = {}
        for key, value in pairs(options.maps) do
            local mapID = key
            if type(key) == "number" and type(value) == "number" then mapID = value end
            if ns.ClassificationIsPositiveInteger(mapID) then mapScope[mapID] = true end
        end
    end

    local order, ordered = {}, {}
    local function AddCategory(key, group)
        if ordered[key] then return end
        local category = self.categoryByKey and self.categoryByKey[key]
        if not category then return end
        ordered[key] = true
        order[#order + 1] = { key = key, group = group or category.group,
            name = category.name or key, icon = category.icon }
    end
    if type(self.categoryGroups) == "table" then
        for index = 1, #self.categoryGroups do
            local group = self.categoryGroups[index]
            local keys = group.keys or {}
            for keyIndex = 1, #keys do AddCategory(keys[keyIndex], group.key) end
        end
    end
    if type(self.categoryList) == "table" then
        for index = 1, #self.categoryList do
            local category = self.categoryList[index]
            AddCategory(category.key, category.group)
        end
    end

    local sections, sectionByKey = {}, {}
    for index = 1, #order do
        local category = order[index]
        if enabled == nil or enabled[category.key] == true then
            local section = { key = category.key, group = category.group, name = category.name,
                icon = category.icon, total = 0, capped = false, rows = {} }
            sections[#sections + 1] = section
            sectionByKey[category.key] = section
        end
    end

    local function ScanMap(mapID, nodes)
        local mapName = self:GetMapName(mapID)
        for coord, node in pairs(nodes) do
            if type(node) == "table" and type(node.entries) == "table" then
                for index = 1, #node.entries do
                    local entry = node.entries[index]
                    if type(entry) == "table" then
                        local name = entry.searchName or ns.ClassificationNormalizeText(entry.name)
                        local sub = entry.searchSub or ns.ClassificationNormalizeText(entry.sub)
                        if query == "" or Contains(name, query) or Contains(sub, query) then
                            local cats = type(entry.categories) == "table" and entry.categories or node.cats
                            if type(cats) == "table" then
                                for key in pairs(cats) do
                                    local section = sectionByKey[key]
                                    if section then
                                        local display = type(entry.name) == "string" and entry.name ~= ""
                                            and entry.name or "Unknown NPC"
                                        local title = display
                                        if type(entry.sub) == "string" and entry.sub ~= "" then
                                            title = display .. " - " .. entry.sub
                                        end
                                        section.rows[#section.rows + 1] = {
                                            key = key, mapID = mapID, coord = coord,
                                            node = node, entry = entry,
                                            name = display, sub = entry.sub, title = title,
                                            zoneName = mapName,
                                            sortName = name, sortSub = sub,
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if mapScope then
        for mapID in pairs(mapScope) do
            local nodes = self.index[mapID]
            if type(nodes) == "table" then ScanMap(mapID, nodes) end
        end
    else
        for mapID, nodes in pairs(self.index) do
            if type(mapID) == "number" and type(nodes) == "table" then ScanMap(mapID, nodes) end
        end
    end

    local function LessRow(a, b)
        if a.zoneName ~= b.zoneName then return a.zoneName < b.zoneName end
        if a.sortName ~= b.sortName then return a.sortName < b.sortName end
        if a.sortSub ~= b.sortSub then return a.sortSub < b.sortSub end
        if a.mapID ~= b.mapID then return a.mapID < b.mapID end
        if a.coord ~= b.coord then return a.coord < b.coord end
        return (a.entry.id or 0) < (b.entry.id or 0)
    end

    local shown, capped = 0, false
    for index = 1, #sections do
        local section = sections[index]
        table.sort(section.rows, LessRow)
        section.total = #section.rows
        if section.total > limit then
            for rowIndex = section.total, limit + 1, -1 do section.rows[rowIndex] = nil end
            section.capped = true
            capped = true
        end
        shown = shown + #section.rows
    end

    return sections, { shown = shown, capped = capped }
end

--------------------------------------------------------------------------------------------
-- Search window
--------------------------------------------------------------------------------------------

local SEARCH_WIDTH, SEARCH_HEIGHT = 620, 620
local RESULT_LIMIT = 100
local ROW_HEIGHT = 54

local Journal = ns.Journal

local function CreateFilter(parent, label, x, y, width)
    local caption = Journal.Text(parent, 12, label, ns.Colors.gold)
    caption:SetPoint("TOPLEFT", x, y)

    local input = Journal.Input(parent, width, 24)
    input:SetPoint("TOPLEFT", x, y - 18)
    return input
end

function ns:CreateSearchUI()
    if self.searchFrame then return self.searchFrame end

    local frame = CreateFrame("Frame", "ForeverWayfinderSearchFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)

    frame:SetSize(SEARCH_WIDTH, SEARCH_HEIGHT)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    -- Frames without an anchor can be created successfully but appear at an
    -- unintended location. Always give the search window a visible initial anchor.
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetClampedToScreen(true)

    -- The settings panel and search window share FULLSCREEN_DIALOG strata.
    -- Set the level after the strata so the search window is above its opener.
    local settingsButton = self.uiFrame and self.uiFrame.searchButton
    if settingsButton then
        frame:SetFrameLevel(settingsButton:GetFrameLevel() + 10)
    end
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    Journal.Decorate(frame)

    Journal.Header(frame, 48)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ns.MEDIA.addonIcon)
    icon:SetSize(22, 22)
    icon:SetPoint("TOPLEFT", 24, -22)

    local title = Journal.Text(frame, 20, "Wayfinder Search", ns.Colors.gold)
    title:SetPoint("TOPLEFT", 54, -24)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -8, -8)
    close:SetScript("OnClick", function() frame:Hide() end)

    frame.queryInput = CreateFilter(frame, "NPC NAME", 24, -72, 250)
    frame.categoryInput = CreateFilter(frame, "CATEGORY", 292, -72, 140)
    frame.zoneInput = CreateFilter(frame, "ZONE / MAP ID", 448, -72, 148)
    frame.queryInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    frame.categoryInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    frame.zoneInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    frame.status = Journal.Text(frame, 13, "Enter a name, category, or zone to search.", ns.Colors.muted, "LEFT")
    frame.status:SetPoint("TOPLEFT", 24, -128)
    frame.status:SetWidth(SEARCH_WIDTH - 48)

    local page = Journal.Page(frame, 16, -150, -16, 16)
    frame.scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 8, -8)
    frame.scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    frame.content = CreateFrame("Frame", nil, frame.scroll)
    frame.content:SetSize(SEARCH_WIDTH - 80, 1)
    frame.scroll:SetScrollChild(frame.content)
    frame.resultRows = {}
    frame.searchGeneration = 0

    local function FocusMap(result)
        -- Same selection pattern Questie uses on this client family: the C_Map opener
        -- when present (protected in combat), otherwise show the frame and set the map.
        if C_Map and type(C_Map.OpenWorldMap) == "function" then
            if InCombatLockdown and InCombatLockdown() then
                ns:Print("Cannot open the map during combat.")
                return
            end
            local ok = pcall(C_Map.OpenWorldMap, result.mapID)
            if ok then return end
        end
        if WorldMapFrame and type(WorldMapFrame.SetMapID) == "function" then
            if not WorldMapFrame:IsShown() then
                WorldMapFrame:Show()
            end
            local ok = pcall(WorldMapFrame.SetMapID, WorldMapFrame, result.mapID)
            if ok then return end
        end
        ns:Print("This client does not expose world-map selection from addons.")
    end

    local function SetWaypoint(result)
        local ok, reason = ns.Waypoints:Set(result.mapID, result.node.x, result.node.y,
            result.entry.name or ns:GetNodeTitle(result.node))
        if not ok then ns:Print(reason) end
    end

    local function EntryCategoryNames(entry)
        local names = {}
        for index = 1, #(ns.categoryList or {}) do
            local category = ns.categoryList[index]
            if entry.categories and entry.categories[category.key] then
                names[#names + 1] = category.name
            end
        end
        return table.concat(names, " · ")
    end

    local function RefreshResults()
        frame.searchGeneration = frame.searchGeneration + 1
        local generation = frame.searchGeneration
        local function run()
            if not frame:IsShown() or generation ~= frame.searchGeneration then return end
            if ns.blocked then
                frame.status:SetText("|cffff5555Disabled:|r " .. ns.blocked)
                return
            end
            if not ns.ready then
                frame.status:SetText("Index is still loading. Search will be available when indexing completes.")
                return
            end

            local results, reason = ns:SearchEntries(
                frame.queryInput:GetText(), frame.categoryInput:GetText(),
                frame.zoneInput:GetText(), RESULT_LIMIT)

            for index = 1, #results do
                local result = results[index]
                local row = frame.resultRows[index]
                if not row then
                    row = CreateFrame("Button", nil, frame.content)
                    row:SetHeight(ROW_HEIGHT)
                    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
                    row:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)
                    row.background = Journal.Solid(row, ns.Colors.pageHover)
                    row.background:SetAllPoints()
                    row.background:SetAlpha(0)
                    row.name = Journal.Text(row, 15, "", ns.Colors.ink, "LEFT")
                    row.name:SetPoint("TOPLEFT", 9, -7)
                    row.name:SetPoint("TOPRIGHT", -8, -7)
                    row.detail = Journal.Text(row, 12, "", ns.Colors.inkMuted, "LEFT")
                    row.detail:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
                    row.detail:SetPoint("TOPRIGHT", -8, -27)
                    row:SetScript("OnEnter", function(self) self.background:SetAlpha(1) end)
                    row:SetScript("OnLeave", function(self) self.background:SetAlpha(0) end)
                    row:SetScript("OnClick", function(self, button)
                        if not self.result then return end
                        if button == "RightButton" then
                            SetWaypoint(self.result)
                        else
                            FocusMap(self.result)
                        end
                    end)
                    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                    frame.resultRows[index] = row
                end

                local entry = result.entry
                row.result = result
                row.name:SetText(entry.name or "Unknown NPC")
                local sub = type(entry.sub) == "string" and entry.sub ~= "" and (" · " .. entry.sub) or ""
                local cats = EntryCategoryNames(entry)
                row.detail:SetText(("%s%s  |  %s  |  %.1f, %.1f"):format(
                    result.mapName, sub, cats, result.node.x * 100, result.node.y * 100))
                row:Show()
            end

            for index = #results + 1, #frame.resultRows do
                frame.resultRows[index]:Hide()
                frame.resultRows[index].result = nil
            end
            frame.content:SetHeight(math.max(#results * ROW_HEIGHT, 1))
            if reason == "query-required" then
                frame.status:SetText("Enter a name, category, or zone to begin.")
            elseif #results == 0 then
                frame.status:SetText("No matching NPCs or service locations.")
            else
                frame.status:SetFormattedText("%d result%s%s", #results,
                    #results == 1 and "" or "s", #results == RESULT_LIMIT and " · showing first 100" or "")
            end
        end

        if C_Timer and C_Timer.After then
            C_Timer.After(0.15, run)
        else
            run()
        end
    end

    frame.queryInput:SetScript("OnTextChanged", RefreshResults)
    frame.categoryInput:SetScript("OnTextChanged", RefreshResults)
    frame.zoneInput:SetScript("OnTextChanged", RefreshResults)
    frame:SetScript("OnShow", RefreshResults)

    frame.RefreshResults = RefreshResults
    self.RefreshSearchResults = function(owner)
        local searchFrame = owner.searchFrame
        if searchFrame and searchFrame:IsShown() then
            searchFrame.RefreshResults()
        end
    end
    frame:Hide()
    self.searchFrame = frame
    table.insert(UISpecialFrames, "ForeverWayfinderSearchFrame")
    return frame
end

function ns:ToggleSearchUI()
    local frame = self.searchFrame or self:CreateSearchUI()
    if frame:IsShown() then
        frame:Hide()
    else
        -- Recheck the relative level in case the settings panel was recreated.
        local settingsButton = self.uiFrame and self.uiFrame.searchButton
        if settingsButton and frame:GetFrameLevel() <= settingsButton:GetFrameLevel() then
            frame:SetFrameLevel(settingsButton:GetFrameLevel() + 10)
        end
        frame:Show()
        frame.queryInput:SetFocus()
    end
end
