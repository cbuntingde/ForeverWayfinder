local ADDON, ns = ...

-- Search is deliberately independent of frame code so filtering remains testable.
local function Contains(haystack, needle)
    return haystack:find(needle, 1, true) ~= nil
end

-- Map names are stable for the life of an index; ResetIndex clears the cache.
-- Failed lookups are not cached because C_Map may not be ready during load.
function ns:GetMapName(mapID)
    local cached = self.mapNameCache[mapID]
    if cached then return cached end
    local name = "Map " .. tostring(mapID)
    if C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, mapID)
        if ok and type(info) == "table" and type(info.name) == "string" then
            name = info.name
            self.mapNameCache[mapID] = name
        end
    end
    return name
end

--------------------------------------------------------------------------------------------
-- Flat entry cache
--------------------------------------------------------------------------------------------

-- The category names a row belongs to, normalized for matching. The filter
-- box promises to match categories as well as names, so the row cache carries
-- the names with it.
local function CategoryNames(categories)
    if type(categories) ~= "table" then return "" end
    local names = {}
    for key in pairs(categories) do
        local category = ns.categoryByKey and ns.categoryByKey[key]
        if category then
            names[#names + 1] = ns.ClassificationNormalizeText(category.name)
        end
    end
    table.sort(names)
    return table.concat(names, " ")
end

-- One pre-sorted row per indexed entry. Search and browse both read this, so a
-- keystroke or panel refresh no longer re-walks every node in the index. The
-- owner-identity check ties the cache to one index generation.
function ns:GetIndexedRows()
    local index = self.index
    if self.rowCache and self.rowCache.owner == index then return self.rowCache.rows end

    local rows = {}
    if type(index) == "table" then
        for mapID, nodes in pairs(index) do
            if type(mapID) == "number" and type(nodes) == "table" then
                local mapName = self:GetMapName(mapID)
                local searchZone = ns.ClassificationNormalizeText(mapName)
                for coord, node in pairs(nodes) do
                    if type(node) == "table" and type(node.entries) == "table" then
                        for entryIndex = 1, #node.entries do
                            local entry = node.entries[entryIndex]
                            if type(entry) == "table" then
                                local name = entry.searchName or ns.ClassificationNormalizeText(entry.name)
                                local sub = entry.searchSub or ns.ClassificationNormalizeText(entry.sub)
                                local display = type(entry.name) == "string" and entry.name ~= ""
                                    and entry.name or "Unknown NPC"
                                local title = display
                                if type(entry.sub) == "string" and entry.sub ~= "" then
                                    title = display .. " - " .. entry.sub
                                end
                                local allCategories = type(entry.categories) == "table"
                                    and entry.categories or node.cats
                                rows[#rows + 1] = {
                                    mapID = mapID, coord = coord, node = node, entry = entry,
                                    mapName = mapName, searchZone = searchZone,
                                    searchName = name, searchSub = sub,
                                    searchCategories = CategoryNames(allCategories),
                                    name = display, sub = entry.sub, title = title,
                                    categories = entry.categories,
                                    allCategories = allCategories,
                                    sortName = name, sortSub = sub,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(rows, function(a, b)
        if a.sortName ~= b.sortName then return a.sortName < b.sortName end
        if a.sortSub ~= b.sortSub then return a.sortSub < b.sortSub end
        if a.mapID ~= b.mapID then return a.mapID < b.mapID end
        if a.coord ~= b.coord then return a.coord < b.coord end
        return (a.entry.id or 0) < (b.entry.id or 0)
    end)

    self.rowCache = { owner = index, rows = rows }
    return rows
end

-- query        - name or sub-name substring.
-- categoryFilter - category key or name.
-- zoneFilter   - zone name or map ID.
-- limit        - maximum number of results.
-- enabled      - optional set of enabled category keys; a row outside it is
--                not a result, so the search covers the same ground as the
--                map column.
function ns:SearchEntries(query, categoryFilter, zoneFilter, limit, enabled)
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

    local categoryNames = {}
    for key, category in pairs(self.categoryByKey or {}) do
        categoryNames[key] = {
            key = ns.ClassificationNormalizeText(key),
            name = ns.ClassificationNormalizeText(category.name),
        }
    end

    local rows = self:GetIndexedRows()
    local results = {}
    for index = 1, #rows do
        local row = rows[index]
        local zoneMatches = zoneFilter == ""
            or (exactMapID and row.mapID == numericZoneID)
            or (not exactMapID and Contains(row.searchZone, zoneFilter))

        local enabledMatches = true
        if type(enabled) == "table" then
            enabledMatches = false
            for key in pairs(row.allCategories or {}) do
                if enabled[key] == true then
                    enabledMatches = true
                    break
                end
            end
        end

        if zoneMatches and enabledMatches then
            local textMatches = query == "" or Contains(row.searchName, query)
                or Contains(row.searchSub, query)
            local matchedCategory = nil

            -- A category name is a valid search term: the map column filter
            -- matches those too, so both surfaces answer the same question.
            if not textMatches and query ~= "" then
                for key in pairs(row.allCategories or {}) do
                    local names = categoryNames[key]
                    if names and Contains(names.name, query) then
                        textMatches = true
                        matchedCategory = key
                        break
                    end
                end
            end

            local categoryMatches = categoryFilter == ""
            if not categoryMatches then
                for key in pairs(row.categories or {}) do
                    local names = categoryNames[key]
                    if names and (Contains(names.key, categoryFilter)
                        or Contains(names.name, categoryFilter)) then
                        categoryMatches = true
                        if not matchedCategory then matchedCategory = key end
                        break
                    end
                end
            end

            if textMatches and categoryMatches then
                results[#results + 1] = {
                    entry = row.entry, node = row.node, mapID = row.mapID, coord = row.coord,
                    mapName = row.mapName, matchedCategory = matchedCategory,
                    sortName = row.searchName, sortSub = row.searchSub,
                }
            end
        end
    end

    -- The cache is already in search order; only the per-query limit remains.
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
-- Returns sections in category-group order plus meta
-- { shown = n, capped = boolean, groupCounts = { all = n, [group] = n } }.
-- The counts are locations, so a place listed under two categories counts
-- once per group and once in total.
-- Rows are per indexed entry so the categories shown always match the entry itself;
-- the waypoint target stays the shared node.
function ns:BrowseEntries(options)
    if not self.ready or type(self.index) ~= "table" then
        return {}, { shown = 0, capped = false, reason = "index-not-ready" }
    end
    if type(options) ~= "table" then options = {} end

    local query = ns.ClassificationNormalizeText(options.query)
    local limit = ns.ClassificationIsPositiveInteger(options.limit) and math.min(options.limit, 200) or 100
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
                icon = category.icon, total = 0, rowCount = 0, capped = false, rows = {},
                nodes = {} }
            sections[#sections + 1] = section
            sectionByKey[category.key] = section
        end
    end

    local singleZone = nil
    if mapScope then
        local mapCount = 0
        for _ in pairs(mapScope) do mapCount = mapCount + 1 end
        singleZone = mapCount == 1
    end

    -- The counts describe places on the map, not list rows: one location that
    -- is listed under two categories is still one location.
    local groupCounts, groupNodes = {}, {}
    local allNodes = {}

    local rows = self:GetIndexedRows()
    for index = 1, #rows do
        local row = rows[index]
        local inScope = not mapScope or mapScope[row.mapID] == true
        if inScope and (query == "" or Contains(row.searchName, query)
            or Contains(row.searchSub, query)
            or Contains(row.searchCategories or "", query)) then
            local cats = row.allCategories
            if type(cats) == "table" then
                for key in pairs(cats) do
                    local section = sectionByKey[key]
                    if section then
                        section.rowCount = section.rowCount + 1
                        local node = row.node
                        if not section.nodes[node] then
                            section.nodes[node] = true
                            section.total = section.total + 1
                        end
                        local group = section.group
                        local nodes = groupNodes[group]
                        if not nodes then
                            nodes = {}
                            groupNodes[group] = nodes
                        end
                        if not nodes[node] then
                            nodes[node] = true
                            groupCounts[group] = (groupCounts[group] or 0) + 1
                        end
                        if not allNodes[node] then
                            allNodes[node] = true
                            groupCounts.all = (groupCounts.all or 0) + 1
                        end
                        -- Within one map the cache order already equals the
                        -- display order, so only the capped rows need tables.
                        if not singleZone or #section.rows < limit then
                            section.rows[#section.rows + 1] = {
                                key = key, mapID = row.mapID, coord = row.coord,
                                node = row.node, entry = row.entry,
                                name = row.name, sub = row.sub, title = row.title,
                                zoneName = row.mapName,
                                sortName = row.searchName, sortSub = row.searchSub,
                            }
                        end
                    end
                end
            end
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
        if not singleZone then
            table.sort(section.rows, LessRow)
            if #section.rows > limit then
                for rowIndex = #section.rows, limit + 1, -1 do section.rows[rowIndex] = nil end
            end
        end
        if section.rowCount > limit then
            section.capped = true
            capped = true
        end
        shown = shown + #section.rows
    end

    return sections, { shown = shown, capped = capped, groupCounts = groupCounts }
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

-- Same selection pattern Questie uses on this client family: the C_Map opener
-- when present (protected in combat), otherwise show the frame and set the map.
function ns:FocusMap(mapID)
    if not ns.ClassificationIsPositiveInteger(mapID) then return false end
    if C_Map and type(C_Map.OpenWorldMap) == "function" then
        if InCombatLockdown and InCombatLockdown() then
            ns:Print("Cannot open the map during combat.")
            return false
        end
        local ok = pcall(C_Map.OpenWorldMap, mapID)
        if ok then return true end
    end
    if WorldMapFrame and type(WorldMapFrame.SetMapID) == "function" then
        if not WorldMapFrame:IsShown() then
            WorldMapFrame:Show()
        end
        local ok = pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID)
        if ok then return true end
    end
    ns:Print("This client does not expose world-map selection from addons.")
    return false
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

    local close = Journal.CloseButton(frame, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT", -14, -16)

    frame.queryInput = CreateFilter(frame, "NPC NAME", 24, -72, 250)
    frame.categoryInput = CreateFilter(frame, "CATEGORY", 292, -72, 140)
    frame.zoneInput = CreateFilter(frame, "ZONE / MAP ID", 448, -72, 148)
    frame.queryInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    frame.categoryInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    frame.zoneInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    local hint = Journal.Body(frame, 11,
        "Search covers the categories enabled in the Wayfinder settings. The name box also matches a category such as \"auctioneer\". Right-click a result to set a waypoint.",
        ns.Colors.textMuted, "LEFT")
    hint:SetPoint("TOPLEFT", 24, -126)
    hint:SetWidth(SEARCH_WIDTH - 48)

    frame.status = Journal.Body(frame, 13, "Enter a name, category, or zone to search.", ns.Colors.muted, "LEFT")
    frame.status:SetPoint("TOPLEFT", 24, -150)
    frame.status:SetWidth(SEARCH_WIDTH - 48)

    local page = Journal.Page(frame, 16, -172, -16, 16)
    frame.scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 8, -8)
    frame.scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    frame.content = CreateFrame("Frame", nil, frame.scroll)
    frame.content:SetSize(SEARCH_WIDTH - 80, 1)
    frame.scroll:SetScrollChild(frame.content)
    frame.resultRows = {}
    frame.searchGeneration = 0

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
                frame.zoneInput:GetText(), RESULT_LIMIT, ns.db and ns.db.categories)

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
                    row.name = Journal.Body(row, 15, "", ns.Colors.text, "LEFT")
                    row.name:SetPoint("TOPLEFT", 9, -7)
                    row.name:SetPoint("TOPRIGHT", -8, -7)
                    row.detail = Journal.Body(row, 12, "", ns.Colors.textMuted, "LEFT")
                    row.detail:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
                    row.detail:SetPoint("TOPRIGHT", -8, -27)
                    row:SetScript("OnEnter", function(self) self.background:SetAlpha(1) end)
                    row:SetScript("OnLeave", function(self) self.background:SetAlpha(0) end)
                    row:SetScript("OnClick", function(self, button)
                        if not self.result then return end
                        if button == "RightButton" then
                            SetWaypoint(self.result)
                        else
                            ns:FocusMap(self.result.mapID)
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
                -- The category the query matched leads the line, so the reason
                -- for the hit is obvious.
                local matched = ""
                if result.matchedCategory then
                    local category = ns.categoryByKey and ns.categoryByKey[result.matchedCategory]
                    if category then matched = "|cffd4af37" .. category.name .. "|r · " end
                end
                row.detail:SetText(("%s%s%s  |  %s  |  %.1f, %.1f"):format(
                    matched, result.mapName, sub, cats, result.node.x * 100, result.node.y * 100))
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
                    #results == 1 and "" or "s",
                    #results == RESULT_LIMIT and (" · showing first " .. RESULT_LIMIT) or "")
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
