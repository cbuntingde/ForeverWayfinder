local ADDON, ns = ...

-- Waypoint provider interface. TomTom is the only supported provider and stays optional;
-- callers get a plain ok/reason result and never touch TomTom directly.
local Waypoints = {}
ns.Waypoints = Waypoints

local WAYPOINT_SOURCE = "ForeverWayfinder"

function Waypoints:IsAvailable()
    return TomTom ~= nil and type(TomTom.AddWaypoint) == "function"
end

-- mapID is a UI map ID; x and y are normalized 0-1 coordinates, as TomTom expects.
function Waypoints:Set(mapID, x, y, title)
    if not self:IsAvailable() then
        return false, "TomTom is not installed; waypoint navigation is unavailable."
    end
    if not ns.ClassificationIsPositiveInteger(mapID)
        or not ns.ClassificationIsFiniteNumber(x) or x < 0 or x > 1
        or not ns.ClassificationIsFiniteNumber(y) or y < 0 or y > 1 then
        return false, "This location has no valid map coordinates for a waypoint."
    end
    local ok, uid = pcall(TomTom.AddWaypoint, TomTom, mapID, x, y, {
        title = title,
        crazy = true,
        from = WAYPOINT_SOURCE,
    })
    if not ok or type(uid) ~= "table" then
        return false, "TomTom could not create a waypoint for this location."
    end
    self.lastWaypoint = uid
    if ns.UpdateUI then ns:UpdateUI() end
    return true
end

-- TomTom owns the waypoint and keeps it in its own saved variables, so the
-- handle is looked up by source instead of being stored here: a reload
-- rebuilds TomTom's uid tables and a stored one would no longer match.
function Waypoints:FindWaypoint()
    local store = TomTom and TomTom.waypoints
    if type(store) ~= "table" then return nil end
    local fallback
    for _, entries in pairs(store) do
        if type(entries) == "table" then
            for _, uid in pairs(entries) do
                if type(uid) == "table" and uid.from == WAYPOINT_SOURCE then
                    if self.lastWaypoint and uid == self.lastWaypoint then return uid end
                    if not fallback then fallback = uid end
                end
            end
        end
    end
    return fallback
end

function Waypoints:HasWaypoint()
    return self:FindWaypoint() ~= nil
end

function Waypoints:ClearLast()
    local uid = self:FindWaypoint()
    if not uid then
        return false, "No Forever Wayfinder waypoint is set."
    end
    if not (TomTom and type(TomTom.RemoveWaypoint) == "function") then
        self.lastWaypoint = nil
        return false, "TomTom is not installed; waypoint navigation is unavailable."
    end
    local ok = pcall(TomTom.RemoveWaypoint, TomTom, uid)
    if not ok then
        -- Keep the handle: TomTom still owns that waypoint, so a retry can clear it.
        return false, "TomTom could not clear the waypoint."
    end
    self.lastWaypoint = nil
    if ns.UpdateUI then ns:UpdateUI() end
    return true
end
