local ADDON, ns = ...

-- Search is deliberately independent of frame code so filtering remains testable.
local function Contains(haystack, needle)
    return haystack:find(needle, 1, true) ~= nil
end

local function MapName(mapID)
    if C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, mapID)
        if ok and type(info) == "table" and type(info.name) == "string" then
            return info.name
        end
    end
    return "Map " .. tostring(mapID)
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

    local results = {}
    for mapID, nodes in pairs(self.index) do
        local mapName = MapName(mapID)
        local zoneMatches = zoneFilter == "" or Contains(tostring(mapID), zoneFilter)
            or Contains(ns.ClassificationNormalizeText(mapName), zoneFilter)

        if zoneMatches and type(nodes) == "table" then
            for coord, node in pairs(nodes) do
                if type(node) == "table" and type(node.entries) == "table" then
                    for index = 1, #node.entries do
                        local entry = node.entries[index]
                        if type(entry) == "table" then
                            local name = ns.ClassificationNormalizeText(entry.name)
                            local sub = ns.ClassificationNormalizeText(entry.sub)
                            local textMatches = query == "" or Contains(name, query) or Contains(sub, query)
                            local categoryMatches = categoryFilter == ""
                            local matchedCategory = nil

                            if not categoryMatches then
                                for key in pairs(entry.categories or {}) do
                                    local category = self.categoryByKey and self.categoryByKey[key]
                                    local categoryName = category and ns.ClassificationNormalizeText(category.name) or key
                                    if Contains(key, categoryFilter) or Contains(categoryName, categoryFilter) then
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
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(results, function(a, b)
        local an = ns.ClassificationNormalizeText(a.entry.name)
        local bn = ns.ClassificationNormalizeText(b.entry.name)
        if an ~= bn then return an < bn end
        local as = ns.ClassificationNormalizeText(a.entry.sub)
        local bs = ns.ClassificationNormalizeText(b.entry.sub)
        if as ~= bs then return as < bs end
        if a.mapID ~= b.mapID then return a.mapID < b.mapID end
        if a.coord ~= b.coord then return a.coord < b.coord end
        return (a.entry.id or 0) < (b.entry.id or 0)
    end)

    while #results > limit do results[#results] = nil end
    return results
end

--------------------------------------------------------------------------------------------
-- Search window
--------------------------------------------------------------------------------------------

local SEARCH_WIDTH, SEARCH_HEIGHT = 560, 590
local RESULT_LIMIT = 100
local ROW_HEIGHT = 54

local function CreateFilter(parent, label, x, y, width)
    local caption = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    caption:SetPoint("TOPLEFT", x, y)
    caption:SetText(label)
    caption:SetTextColor(0.83, 0.69, 0.32)

    local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    input:SetAutoFocus(false)
    input:SetSize(width, 24)
    input:SetPoint("TOPLEFT", x, y - 18)
    input:SetTextInsets(6, 6, 0, 0)
    input:SetMaxLetters(80)
    return input
end

function ns:CreateSearchUI()
    if self.searchFrame then return self.searchFrame end

    local frame = CreateFrame("Frame", "ForeverWayfinderSearchFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(SEARCH_WIDTH, SEARCH_HEIGHT)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = ns.MEDIA.white, edgeFile = ns.MEDIA.tooltipBorder, edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        frame:SetBackdropColor(0.05, 0.04, 0.03, 0.97)
        frame:SetBackdropBorderColor(0.55, 0.44, 0.23, 1)
    end

    local header = frame:CreateTexture(nil, "BACKGROUND")
    header:SetColorTexture(0.14, 0.11, 0.07, 0.9)
    header:SetPoint("TOPLEFT", 8, -8)
    header:SetPoint("TOPRIGHT", -8, -8)
    header:SetHeight(48)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 22, -20)
    title:SetText("|cffd4af37WAYFINDER SEARCH|r")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() frame:Hide() end)

    frame.queryInput = CreateFilter(frame, "NPC NAME", 22, -72, 250)
    frame.categoryInput = CreateFilter(frame, "CATEGORY", 300, -72, 110)
    frame.zoneInput = CreateFilter(frame, "ZONE / MAP ID", 430, -72, 105)
    frame.queryInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    frame.categoryInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    frame.zoneInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.status:SetPoint("TOPLEFT", 22, -132)
    frame.status:SetTextColor(0.70, 0.67, 0.60)
    frame.status:SetText("Enter a name, category, or zone to search.")

    frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 18, -154)
    frame.scroll:SetPoint("BOTTOMRIGHT", -36, 18)
    frame.content = CreateFrame("Frame", nil, frame.scroll)
    frame.content:SetSize(SEARCH_WIDTH - 64, 1)
    frame.scroll:SetScrollChild(frame.content)
    frame.resultRows = {}
    frame.searchGeneration = 0

    local function FocusMap(result)
        if WorldMapFrame and type(WorldMapFrame.SetMapID) == "function" then
            local ok = pcall(WorldMapFrame.SetMapID, WorldMapFrame, result.mapID)
            if ok and type(WorldMapFrame.Show) == "function" then
                WorldMapFrame:Show()
            end
        end
        if TomTom and type(TomTom.AddWaypoint) == "function" then
            local ok = pcall(TomTom.AddWaypoint, TomTom, result.mapID, result.node.x, result.node.y, {
                title = ns:GetNodeTitle(result.node),
                crazy = true,
                from = "ForeverWayfinder",
            })
            if not ok then ns:Print("TomTom could not create a waypoint for this location.") end
        end
    end

    local function RefreshResults()
        frame.searchGeneration = frame.searchGeneration + 1
        local generation = frame.searchGeneration
        local function run()
            if not frame:IsShown() or generation ~= frame.searchGeneration then return end
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
                    row.background = row:CreateTexture(nil, "BACKGROUND")
                    row.background:SetAllPoints()
                    row.background:SetColorTexture(0.20, 0.16, 0.09, 0.55)
                    row.background:SetAlpha(0)
                    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    row.name:SetPoint("TOPLEFT", 9, -7)
                    row.name:SetPoint("TOPRIGHT", -8, -7)
                    row.name:SetJustifyH("LEFT")
                    row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    row.detail:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
                    row.detail:SetPoint("TOPRIGHT", -8, -27)
                    row.detail:SetJustifyH("LEFT")
                    row.detail:SetTextColor(0.70, 0.67, 0.60)
                    row:SetScript("OnEnter", function(self) self.background:SetAlpha(1) end)
                    row:SetScript("OnLeave", function(self) self.background:SetAlpha(0) end)
                    row:SetScript("OnClick", function(self, button)
                        if self.result then
                            if button == "RightButton" then
                                if TomTom and type(TomTom.AddWaypoint) == "function" then
                                    FocusMap(self.result)
                                else
                                    ns:Print("TomTom is not installed; open the result's zone on the world map.")
                                end
                            else
                                FocusMap(self.result)
                            end
                        end
                    end)
                    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                    frame.resultRows[index] = row
                end

                local entry = result.entry
                row.result = result
                row.name:SetText(entry.name or "Unknown NPC")
                local sub = type(entry.sub) == "string" and entry.sub ~= "" and (" · " .. entry.sub) or ""
                local cats = ns:GetNodeCategoryNames(result.node, false)
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
        frame:Show()
        frame.queryInput:SetFocus()
    end
end
