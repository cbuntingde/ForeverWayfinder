local ADDON, ns = ...

local handler = {}

--------------------------------------------------------------------------------------------
-- Map lookup
--------------------------------------------------------------------------------------------

function ns:GetParentChain(mapID)
    local parents = {}
    local current = mapID
    for _ = 1, 4 do
        local info = C_Map.GetMapInfo(current)
        local parent = info and info.parentMapID
        if not parent or parent == 0 or parent == current then break end
        parents[#parents + 1] = parent
        current = parent
    end
    return parents
end

function ns:GetDescendantMaps(mapID)
    local cached = self.descCache[mapID]
    if cached then return cached end

    local maps, seen = {}, { [mapID] = true }
    local function walk(id, depth)
        if depth > 3 then return end
        local children = C_Map.GetMapChildrenInfo(id)
        if not children then return end
        for index = 1, #children do
            local childID = children[index].mapID
            if childID and not seen[childID] then
                seen[childID] = true
                if self.index[childID] then
                    maps[#maps + 1] = childID
                end
                walk(childID, depth + 1)
            end
        end
    end

    walk(mapID, 0)
    self.descCache[mapID] = maps
    return maps
end

function ns:GetMapsFor(uiMapID, minimap)
    if not minimap and self.db.showOnContinent then
        local info = C_Map.GetMapInfo(uiMapID)
        local mapType = info and info.mapType
        local isContinent = Enum and Enum.UIMapType and
            (mapType == Enum.UIMapType.Continent or mapType == Enum.UIMapType.World)

        if isContinent then
            local descendants = self:GetDescendantMaps(uiMapID)
            if #descendants > 0 then
                local maps = {}
                if self.index[uiMapID] then
                    maps[1] = uiMapID
                end
                for index = 1, #descendants do
                    maps[#maps + 1] = descendants[index]
                end
                return maps
            end
        end
    end

    if self.index[uiMapID] then
        return { uiMapID }
    end

    local parents = self:GetParentChain(uiMapID)
    for index = 1, #parents do
        if self.index[parents[index]] then
            return { parents[index] }
        end
    end

    return {}
end

--------------------------------------------------------------------------------------------
-- Node iterator
--------------------------------------------------------------------------------------------

function ns:MakeNodeIterator(maps)
    local state = { maps = maps, mapIndex = 0, mapID = nil, nodes = nil }
    local scale = self.db.pinScale or 1.0

    local function iterate(data, coord)
        while true do
            if data.nodes then
                local node
                coord, node = next(data.nodes, coord)
                if coord then
                    local icon = ns:GetNodeIcon(node)
                    if icon then
                        return coord, data.mapID, icon, scale, 1
                    end
                else
                    data.nodes = nil
                end
            end

            data.mapIndex = data.mapIndex + 1
            data.mapID = data.maps[data.mapIndex]
            if not data.mapID then return end
            data.nodes = ns.index[data.mapID]
            coord = nil
        end
    end

    return iterate, state, nil
end

--------------------------------------------------------------------------------------------
-- HandyNotes plugin
--------------------------------------------------------------------------------------------

function handler:GetNodes2(uiMapID, minimap)
    if not ns.ready or not ns.db or not ns.db.enabled then
        return next, {}
    end
    if minimap then
        if not ns.db.showMinimap then return next, {} end
    elseif not ns.db.showWorldMap then
        return next, {}
    end

    local maps = ns:GetMapsFor(uiMapID, minimap)
    if #maps == 0 then
        return next, {}
    end
    return ns:MakeNodeIterator(maps)
end

function handler:OnEnter(uiMapID, coord)
    local node = ns:GetNode(uiMapID, coord)
    if not node then return end

    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    elseif WorldMapFrame and WorldMapFrame:IsShown() then
        GameTooltip:SetOwner(WorldMapFrame, "ANCHOR_CURSOR")
    else
        GameTooltip:SetOwner(UIParent or WorldMapFrame, "ANCHOR_CURSOR")
    end

    local first = node.entries[1]
    if first then
        GameTooltip:AddLine(first.name, 1.00, 0.82, 0.00)
        if first.sub and first.sub ~= "" then
            GameTooltip:AddLine(first.sub, ns.Colors.muted[1], ns.Colors.muted[2], ns.Colors.muted[3])
        end
    else
        GameTooltip:AddLine("Service NPC", 1.00, 0.82, 0.00)
    end

    -- Keep map tooltips compact even when a crowded coordinate contains many NPCs.
    -- The search window remains the complete discovery surface for every indexed entry.
    local tooltipLimit = 12
    local lastVisible = math.min(#node.entries, tooltipLimit)
    for index = 2, lastVisible do
        local entry = node.entries[index]
        local text = entry.name
        if entry.sub and entry.sub ~= "" then
            text = text .. " - " .. entry.sub
        end
        GameTooltip:AddLine(text, 0.86, 0.83, 0.74)
    end
    local remaining = #node.entries - lastVisible
    if remaining > 0 then
        GameTooltip:AddLine(("%d more NPCs — use /fw search"):format(remaining),
            0.62, 0.59, 0.52)
    end

    local categories = ns:GetNodeCategoryNames(node, true)
    if categories ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(categories, ns.Colors.gold[1], ns.Colors.gold[2], ns.Colors.gold[3])
    end

    GameTooltip:AddLine(("Coordinates: %.1f, %.1f"):format(node.x * 100, node.y * 100), 0.55, 0.55, 0.50)
    if TomTom and TomTom.AddWaypoint then
        GameTooltip:AddLine("Right-click to set a waypoint", 0.45, 0.78, 0.45)
    end

    GameTooltip:Show()
end

function handler:OnLeave()
    GameTooltip:Hide()
end

function handler:OnClick(button, down, uiMapID, coord)
    if button ~= "RightButton" or down then return end

    local node = ns:GetNode(uiMapID, coord)
    if not node then return end

    if TomTom and TomTom.AddWaypoint then
        TomTom:AddWaypoint(uiMapID, node.x, node.y, {
            title = ns:GetNodeTitle(node),
            crazy = true,
            from = "ForeverWayfinder",
        })
    else
        ns:Print("TomTom is not installed; cannot set a waypoint.")
    end
end

function ns:RegisterHandyNotes()
    if self.registered then return end

    local options = {
        type = "toggle",
        name = "Forever Wayfinder",
        desc = "Vendors, trainers and service NPCs on the world map and minimap.",
        order = 100,
        get = function() return ns.db and ns.db.enabled end,
        set = function(_, value)
            ns.db.enabled = value
            ns:Refresh()
        end,
    }

    local ok, err = pcall(HandyNotes.RegisterPluginDB, HandyNotes, self.PLUGIN, handler, options)
    if not ok then
        self.blocked = "HandyNotes rejected the plugin registration: " .. tostring(err)
        self:Print("Disabled: " .. self.blocked)
        return
    end

    self.registered = true
end
