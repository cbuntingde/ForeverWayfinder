local ADDON, ns = ...

-- Waypoint provider interface. TomTom is the only supported provider and stays optional;
-- callers get a plain ok/reason result and never touch TomTom directly.
local Waypoints = {}
ns.Waypoints = Waypoints

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
        from = "ForeverWayfinder",
    })
    if not ok then
        return false, "TomTom could not create a waypoint for this location."
    end
    self.lastWaypoint = uid
    return true
end

function Waypoints:ClearLast()
    if not self.lastWaypoint then
        return false, "No Forever Wayfinder waypoint has been set."
    end
    if not (TomTom and type(TomTom.RemoveWaypoint) == "function") then
        self.lastWaypoint = nil
        return false, "TomTom is not installed; waypoint navigation is unavailable."
    end
    local ok = pcall(TomTom.RemoveWaypoint, TomTom, self.lastWaypoint)
    self.lastWaypoint = nil
    if not ok then
        return false, "TomTom could not clear the waypoint."
    end
    return true
end