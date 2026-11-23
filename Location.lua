local ADDON, ns = ...

-- Player location provider for the map sidebar. Kept free of UI objects so it
-- can be unit tested with stubs (see tests/run.lua).
local Location = {}
ns.Location = Location

local function ReadCoords(mapID)
    if not mapID or not C_Map or type(C_Map.GetPlayerMapPosition) ~= "function" then return nil, nil end
    local ok, position = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not ok or not position then return nil, nil end

    local x, y
    if type(position.GetXY) == "function" then
        local got, px, py = pcall(position.GetXY, position)
        if got then x, y = px, py end
    end
    -- Some client builds expose the vector as plain x/y fields.
    if not ns.ClassificationIsFiniteNumber(x) and ns.ClassificationIsFiniteNumber(position.x) then
        x, y = position.x, position.y
    end
    if not ns.ClassificationIsFiniteNumber(x) or not ns.ClassificationIsFiniteNumber(y) then return nil, nil end
    -- (0, 0) is the API's "not available" sentinel, not a real position.
    if x == 0 and y == 0 then return nil, nil end
    return x * 100, y * 100
end

function Location:Read()
    local mapID
    if C_Map and type(C_Map.GetBestMapForUnit) == "function" then
        local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
        if ok and ns.ClassificationIsPositiveInteger(id) then mapID = id end
    end

    -- GetZoneText names the zone; the best map can be a micro-map (inn, floor)
    -- whose name would mislabel the player.
    local zoneName
    if type(GetZoneText) == "function" then
        local ok, text = pcall(GetZoneText)
        if ok and type(text) == "string" and text ~= "" then zoneName = text end
    end
    if not zoneName and mapID and C_Map and type(C_Map.GetMapInfo) == "function" then
        local ok, info = pcall(C_Map.GetMapInfo, mapID)
        if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            zoneName = info.name
        end
    end

    local subZone
    if type(GetSubZoneText) == "function" then
        local ok, text = pcall(GetSubZoneText)
        if ok and type(text) == "string" and text ~= "" then subZone = text end
    end

    local x, y = ReadCoords(mapID)
    return { mapID = mapID, zoneName = zoneName, subZone = subZone, x = x, y = y }
end

-- Distances arrive from HereBeDragons in yards; nil when the target is on a
-- different instance/continent, which callers render as "no distance".
function Location:FormatDistance(distance)
    if not ns.ClassificationIsFiniteNumber(distance) or distance < 0 then return nil end
    if distance < 1000 then return ("%d yd"):format(distance) end
    return ("%.1fk yd"):format(distance / 1000)
end

-- Canvas-relative cursor to map percentages (both 0-100), Questie-style.
-- Inputs are in UI units: the cursor position and the map canvas rect.
-- Returns nil when the cursor is outside the canvas.
function Location:MapCursorPosition(cursorX, cursorY, left, top, width, height)
    if not (ns.ClassificationIsFiniteNumber(cursorX) and ns.ClassificationIsFiniteNumber(cursorY)
        and ns.ClassificationIsFiniteNumber(left) and ns.ClassificationIsFiniteNumber(top)
        and ns.ClassificationIsFiniteNumber(width) and ns.ClassificationIsFiniteNumber(height)) then
        return nil
    end
    if width <= 0 or height <= 0 then return nil end
    local x = (cursorX - left) / width * 100
    local y = (top - cursorY) / height * 100
    if x < 0 or x > 100 or y < 0 or y > 100 then return nil end
    return x, y
end

-- compact drops the "You" prefix for the collapsed rail; showCoords is false
-- when the user turns panel coordinates off.
function Location:Format(info, compact, showCoords)
    local prefix = compact and "" or "You  ·  "
    if type(info) ~= "table" then
        return compact and "Location unavailable" or (prefix .. "location unavailable")
    end

    local place = info.zoneName
    if type(info.subZone) == "string" and info.subZone ~= "" and #info.subZone <= 22 then
        place = info.subZone
    end
    if type(place) == "string" and place == "" then place = nil end

    local coords
    if showCoords ~= false and ns.ClassificationIsFiniteNumber(info.x)
        and ns.ClassificationIsFiniteNumber(info.y) then
        coords = ("%.1f, %.1f"):format(info.x, info.y)
    end

    if place and coords then return prefix .. place .. "  " .. coords end
    if place then return prefix .. place end
    if coords then return prefix .. coords end
    return compact and "Location unavailable" or (prefix .. "location unavailable")
end
