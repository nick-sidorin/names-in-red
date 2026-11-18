local addon = {}
for _, name in ipairs({ "Ledger", "Encounter" }) do
    assert(loadfile("NamesInRed/" .. name .. ".lua"))("NamesInRed", addon)
end

local now = 1000
local rows, onEvent
local timers = {}
local secret = {}
function issecretvalue(value) return value == secret end
function IsInInstance() return false, "none" end
function UnitGUID(unit)
    if unit == "player" then return "Player-self" end
    if unit == "target" then return "Player-rival" end
end
function UnitLevel(unit) return unit == "player" and 25 or 30 end
function GetRealZoneText() return "Test Zone" end
function GetServerTime() return now end
C_Map = {
    GetBestMapForUnit = function() return 123 end,
    GetPlayerMapPosition = function() return { GetXY = function() return 0.4, 0.6 end } end,
}
C_DeathRecap = { GetRecapEvents = function() return rows end }
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
bit = { band = function(flags, mask) return flags == 66888 and mask or 0 end }

function CreateFrame()
    return {
        RegisterEvent = function(_, event) assert(event == "PLAYER_DEAD") end,
        SetScript = function(_, _, handler) onEvent = handler end,
    }
end

local function Hit(stamp, overkill)
    return { sourceGUID = "Player-rival", sourceName = "Rival", sourceFlags = 66888,
        timestamp = stamp, overkill = overkill }
end

local function Setup(saved)
    addon.db = assert(addon.Ledger.Open(saved))
    assert(loadfile("NamesInRed/Deaths.lua"))("NamesInRed", addon)
end

Setup()
rows = { Hit(1000.848, 87), Hit(999, -1), Hit(998, -1) }
onEvent()
onEvent()
local rival = assert(addon.db.rivals["Player-rival"])
assert(rival.deathsToThem == 1 and rival.killsAgainstThem == 0)
assert(#rival.encounters == 1 and rival.encounters[1].rivalLevel == 30)
assert(rival.encounters[1].x == 0.4 and rival.encounters[1].y == 0.6)
assert(rival.encounters[1].playerLevel == 25 and rival.encounters[1].zone == "Test Zone")

Setup(addon.db)
onEvent()
assert(rival.deathsToThem == 1)
now = 1010
onEvent()
assert(rival.deathsToThem == 1)
rows = { Hit(1010.1, 0), Hit(1009, -1) }
rows[2].sourceGUID = "Player-other"
onEvent()
assert(rival.deathsToThem == 1)
rows[2].sourceGUID = secret
onEvent()
assert(rival.deathsToThem == 1)
rows[2].sourceGUID = "Player-rival"
for _, retry in ipairs(timers) do retry() end
assert(rival.deathsToThem == 2 and #rival.encounters == 2)
print("Confirmed world death checks passed")
