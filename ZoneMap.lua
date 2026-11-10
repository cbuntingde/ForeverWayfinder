local ADDON, ns = ...

local function IsPositiveInteger(value)
    return type(value) == "number" and value == value and value ~= math.huge
        and value ~= -math.huge and value > 0 and value % 1 == 0
end

local function DecodeTable(source, chunkName)
    if type(source) ~= "string" or source == "" then
        return nil, "source is missing or is not a non-empty string"
    end
    local chunk, compileError
    if type(loadstring) == "function" then
        local compiled, result, reason = pcall(loadstring, source, "=" .. tostring(chunkName))
        if not compiled then return nil, tostring(result) end
        chunk, compileError = result, reason
        if chunk then
            if type(setfenv) ~= "function" then
                return nil, "cannot sandbox the Lua chunk on this client"
            end
            local sandboxed, sandboxError = pcall(setfenv, chunk, {})
            if not sandboxed then return nil, tostring(sandboxError) end
        end
    elseif type(load) == "function" then
        -- Lua 5.2+ accepts an explicit environment in load's fourth argument.
        local compiled, result, reason = pcall(load, source, "=" .. tostring(chunkName), "t", {})
        if not compiled then return nil, tostring(result) end
        chunk, compileError = result, reason
    else
        return nil, "no supported Lua chunk loader is available"
    end
    if not chunk then return nil, tostring(compileError) end
    local ok, value = pcall(chunk)
    if not ok then return nil, tostring(value) end
    if type(value) ~= "table" then return nil, "decoded value is not a table" end
    return value
end
ns.DecodeZoneMapTable = DecodeTable

local function ValidateMapping(mapping, label)
    local valid, invalid = {}, 0
    for areaID, mapID in pairs(mapping) do
        if IsPositiveInteger(areaID) and IsPositiveInteger(mapID) then
            valid[areaID] = mapID
        else
            invalid = invalid + 1
        end
    end
    if next(valid) == nil then
        return nil, ("%s contains no valid entries (%d invalid)."):format(label, invalid)
    end
    return valid, nil, invalid
end
ns.ValidateZoneMapMapping = ValidateMapping

function ns:BuildZoneMap()
    local support = _G.LibQuestieDB and _G.LibQuestieDB.Support
    local zoneData = support and support.Get and support.Get("ZoneDB")
    local private = zoneData and zoneData.private
    if type(private) ~= "table" then return false, "QuestieDB zone support data is unavailable." end

    local baseRaw, baseError = DecodeTable(private.areaIdToUiMapId, "QuestieDB.ZoneDB.areaIdToUiMapId")
    if not baseRaw then return false, "QuestieDB base map failed to decode: " .. tostring(baseError) end
    local base, baseErrorMessage, invalidBase = ValidateMapping(baseRaw, "QuestieDB base map")
    if not base then return false, baseErrorMessage end

    local override, invalidOverride = {}, 0
    if private.areaIdToUiMapIdOverride ~= nil and private.areaIdToUiMapIdOverride ~= "" then
        local overrideRaw, overrideError = DecodeTable(private.areaIdToUiMapIdOverride,
            "QuestieDB.ZoneDB.areaIdToUiMapIdOverride")
        if not overrideRaw then return false, "QuestieDB map override failed to decode: " .. tostring(overrideError) end
        if next(overrideRaw) ~= nil then
            local validated, validationError, invalidCount = ValidateMapping(overrideRaw, "QuestieDB map override")
            if not validated then return false, validationError end
            override, invalidOverride = validated, invalidCount or 0
        end
    end

    local areaToMap = {}
    for areaID, mapID in pairs(base) do areaToMap[areaID] = mapID end
    for areaID, mapID in pairs(override) do areaToMap[areaID] = mapID end
    local mapToArea = {}
    for areaID, mapID in pairs(areaToMap) do
        if not mapToArea[mapID] then mapToArea[mapID] = areaID end
    end
    self.areaToMap, self.mapToArea = areaToMap, mapToArea

    self.zoneMapDiagnostics = { baseEntries = 0, overrideEntries = 0,
        invalidBaseEntries = invalidBase or 0, invalidOverrideEntries = invalidOverride }
    for _ in pairs(base) do self.zoneMapDiagnostics.baseEntries = self.zoneMapDiagnostics.baseEntries + 1 end
    for _ in pairs(override) do self.zoneMapDiagnostics.overrideEntries = self.zoneMapDiagnostics.overrideEntries + 1 end
    return true, self.zoneMapDiagnostics.baseEntries + self.zoneMapDiagnostics.overrideEntries
end
