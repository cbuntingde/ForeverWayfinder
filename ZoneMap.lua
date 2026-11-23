local ADDON, ns = ...

local IsPositiveInteger = ns.ClassificationIsPositiveInteger
local IsNonNegativeInteger = ns.ClassificationIsNonNegativeInteger

local function DecodeTable(source, chunkName)
    if type(source) ~= "string" or source == "" then
        return nil, "source is missing or is not a non-empty string"
    end
    if #source > 2 * 1024 * 1024 then
        return nil, "source exceeds the 2 MiB safety limit"
    end
    if source:byte(1) == 27 then
        return nil, "binary Lua chunks are not accepted"
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

local function ValidateMapping(mapping, label)
    local valid, invalid = {}, 0
    for areaID, mapID in pairs(mapping) do
        -- QuestieDB maps deliberately hidden areas to map 0; that is a suppression marker,
        -- not a malformed entry.
        if IsPositiveInteger(areaID) and IsNonNegativeInteger(mapID) then
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

function ns:BuildZoneMap()
    local support = _G.LibQuestieDB and _G.LibQuestieDB.Support
    local zoneData = support and support.Get and support.Get("ZoneDB")
    local private = zoneData and zoneData.private
    if type(private) ~= "table" then return false, "QuestieDB zone support data is unavailable." end

    local baseRaw, baseError = DecodeTable(private.areaIdToUiMapId, "QuestieDB.ZoneDB.areaIdToUiMapId")
    if not baseRaw then return false, "QuestieDB base map failed to decode: " .. tostring(baseError) end
    local base, baseErrorMessage = ValidateMapping(baseRaw, "QuestieDB base map")
    if not base then return false, baseErrorMessage end

    local override = {}
    if private.areaIdToUiMapIdOverride ~= nil and private.areaIdToUiMapIdOverride ~= "" then
        local overrideRaw, overrideError = DecodeTable(private.areaIdToUiMapIdOverride,
            "QuestieDB.ZoneDB.areaIdToUiMapIdOverride")
        if not overrideRaw then return false, "QuestieDB map override failed to decode: " .. tostring(overrideError) end
        if next(overrideRaw) ~= nil then
            local validated, validationError = ValidateMapping(overrideRaw, "QuestieDB map override")
            if not validated then return false, validationError end
            override = validated
        end
    end

    local areaToMap, suppressedAreas = {}, {}
    local function Apply(mapping)
        for areaID, mapID in pairs(mapping) do
            if mapID == 0 then
                areaToMap[areaID] = nil
                suppressedAreas[areaID] = true
            else
                areaToMap[areaID] = mapID
                suppressedAreas[areaID] = nil
            end
        end
    end
    Apply(base)
    Apply(override)
    self.areaToMap, self.suppressedAreas = areaToMap, suppressedAreas

    local baseEntries, overrideEntries = 0, 0
    for _ in pairs(base) do baseEntries = baseEntries + 1 end
    for _ in pairs(override) do overrideEntries = overrideEntries + 1 end
    return true, baseEntries + overrideEntries
end
