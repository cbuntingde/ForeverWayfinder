local ADDON, ns = ...

-- Area ID -> UI map ID for the Forever client, read from QuestieDB's support data at runtime.
-- The tables ship as Lua source strings, the same form Questie decodes before merging the
-- display override over the base map.

local function DecodeTable(source, chunkName)
    if type(source) ~= "string" then return nil end
    local loader = loadstring or load
    local chunk, compileError = loader(source, "=" .. chunkName)
    if not chunk then
        return nil, tostring(compileError)
    end
    local ok, value = pcall(chunk)
    if not ok then
        return nil, tostring(value)
    end
    if type(value) ~= "table" then
        return nil, "decoded value is not a table"
    end
    return value
end

function ns:BuildZoneMap()
    local support = _G.LibQuestieDB and _G.LibQuestieDB.Support
    local zoneData = support and support.Get and support.Get("ZoneDB")
    local private = zoneData and zoneData.private
    if not private then
        return false, "QuestieDB zone support data is unavailable."
    end

    local base, baseError = DecodeTable(private.areaIdToUiMapId, "QuestieDB.ZoneDB.areaIdToUiMapId")
    if not base then
        return false, "QuestieDB area-to-map table failed to load: " .. tostring(baseError)
    end
    local override = DecodeTable(private.areaIdToUiMapIdOverride,
        "QuestieDB.ZoneDB.areaIdToUiMapIdOverride")

    local areaToMap = {}
    for area, map in pairs(base) do
        areaToMap[area] = map
    end
    if override then
        for area, map in pairs(override) do
            areaToMap[area] = map
        end
    end

    local mapToArea = {}
    for area, map in pairs(areaToMap) do
        mapToArea[map] = mapToArea[map] or area
    end

    self.areaToMap = areaToMap
    self.mapToArea = mapToArea

    local count = 0
    for _ in pairs(areaToMap) do count = count + 1 end
    return true, count
end
