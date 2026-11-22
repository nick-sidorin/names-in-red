local addon = {}
assert(loadfile("NamesInRed/Encounter.lua"))("NamesInRed", addon)
assert(loadfile("NamesInRed/Portraits.lua"))("NamesInRed", addon)
assert(loadfile("NamesInRed/EncounterCards.lua"))("NamesInRed", addon)

local available, accept, restricted = true, true, nil
local point, opened
local catalogReads = 0
C_Map = {
    GetMapChildrenInfo = function(rootID, mapType, allDescendants)
        assert(rootID == 947 and mapType == Enum.UIMapType.Zone and allDescendants)
        catalogReads = catalogReads + 1
        return {
            { mapID = 123, name = "Test Zone" },
            { mapID = 234, name = "Shared Name" },
            { mapID = 345, name = "Shared Name" },
        }
    end,
    CanSetUserWaypointOnMap = function(mapID)
        assert(mapID == 123)
        return available
    end,
    SetUserWaypoint = function(waypoint)
        if not accept then return false end
        point = waypoint
        return true
    end,
}
UiMapPoint = {
    CreateFromCoordinates = function(mapID, x, y)
        return { uiMapID = mapID, x = x, y = y }
    end,
}
Enum = {
    GameRule = { WorldMapDisabled = 1, WorldMapTrackingPinDisabled = 2 },
    UIMapType = { Zone = 3 },
}
C_GameRules = { IsGameRuleActive = function(rule) return rule == restricted end }
function OpenMapToUserWaypoint() opened = point.uiMapID end

local encounter = { mapID = 123, x = 0.4, y = 0.6 }
assert(not addon.ShowEncounterWaypoint({ zone = "Unknown Zone", x = 0.4, y = 0.6 }))
assert(not addon.ShowEncounterWaypoint({ zone = "Shared Name", x = 0.4, y = 0.6 }))
assert(not addon.ShowEncounterWaypoint({ zone = "Test Zone" }))
assert(not addon.ShowEncounterWaypoint({ mapID = 123, x = 40, y = 0.6 }))
assert(not addon.ShowEncounterWaypoint({ mapID = 123, x = 0, y = 0 }))
available = false
assert(not addon.ShowEncounterWaypoint(encounter))
available, accept = true, false
assert(not addon.ShowEncounterWaypoint(encounter))
accept = true
for _, rule in pairs(Enum.GameRule) do
    restricted = rule
    assert(not addon.ShowEncounterWaypoint(encounter))
end
assert(not point and not opened)

restricted = nil
assert(addon.ShowEncounterWaypoint(encounter))
assert(opened == 123 and point.x == 0.4 and point.y == 0.6)
local legacy = { zone = "Test Zone", x = 0.2, y = 0.7 }
assert(addon.ShowEncounterWaypoint(legacy))
assert(opened == 123 and point.x == 0.2 and point.y == 0.7)
assert(legacy.mapID == nil and catalogReads == 1)
print("Encounter waypoint checks passed")
