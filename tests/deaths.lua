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
function UnitIsPlayer(unit) return unit == "target" end
function UnitName() return "Rival", "Emberfang" end
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
assert(rival.displayName == "Rival Emberfang")
assert(rival.deathsToThem == 1 and rival.killsAgainstThem == 0)
assert(#rival.encounters == 1 and rival.encounters[1].rivalLevel == 30)
assert(rival.encounters[1].mapID == 123 and rival.encounters[1].x == 0.4 and rival.encounters[1].y == 0.6)
assert(rival.encounters[1].playerLevel == 25 and rival.encounters[1].zone == "Test Zone")

Setup(addon.db)
onEvent()
assert(rival.deathsToThem == 1)
now = 1010
onEvent()
assert(rival.deathsToThem == 1)
rows = { Hit(1010.1, 0), Hit(1009, -1) }
rows[2].sourceGUID, rows[2].sourceName, rows[2].amount = "Player-other", "Other Attacker", 121
rows[3] = rows[2]
rows[4] = { sourceGUID = secret, amount = 25 }
rows[5] = { sourceGUID = "Creature-other", sourceFlags = 66888, amount = 19 }
onEvent()
onEvent()
for _, retry in ipairs(timers) do retry() end
assert(rival.deathsToThem == 2 and #rival.encounters == 2)
local attackers = rival.encounters[1].attackers
assert(#attackers == 2 and attackers[1].guid == "Player-rival" and attackers[1].name == "Rival Emberfang")
assert(attackers[2].guid == "Player-other" and attackers[2].name == "Other Attacker")
assert(addon.db.rivals["Player-other"] == nil)
print("Confirmed world death checks passed")

assert(addon.AddManualEncounter("   ", "killsAgainstThem") == nil)
assert(addon.AddManualEncounter("Rival", "killsAgainstThem") == nil)
assert(addon.AddManualEncounter("Rival", "invalid") == nil)
local manualID = assert(addon.AddManualEncounter(" Rival Emberfang ", "killsAgainstThem"))
assert(addon.AddManualEncounter("rival emberfang", "deathsToThem") == manualID)
local manual = addon.db.rivals[manualID]
assert(manual ~= rival and manual.killsAgainstThem == 1 and manual.deathsToThem == 1)
assert(manual.encounters[1].manual and manual.encounters[1].time == nil and manual.encounters[1].zone == nil)
assert(rival.deathsToThem == 2 and rival.killsAgainstThem == 0)
print("Manual encounter checks passed")

function GetPlayerInfoByGUID(guid)
    assert(guid == "Player-rival")
    return "Warrior", "WARRIOR", "Orc", "Orc", 2
end

addon.RecordEncounter("Player-rival", "Rival", "killsAgainstThem", {})
assert(rival.race == "orc" and rival.sex == 2 and rival.class == "WARRIOR")
function GetPlayerInfoByGUID() return nil, secret, nil, secret, secret end
addon.RecordEncounter("Player-rival", "Rival", "killsAgainstThem", {})
assert(rival.race == "orc" and rival.sex == 2 and rival.class == "WARRIOR")
assert(addon.RivalAppearance("manual:rival") == nil)
print("Rival portrait metadata checks passed")

local oldest = rival.encounters[#rival.encounters]
for timestamp = 1011, 1040 do
    addon.RecordEncounter("Player-rival", "Rival Emberfang", "killsAgainstThem", { time = timestamp })
end
assert(#rival.encounters == 34 and rival.encounters[1].time == 1040)
assert(rival.encounters[30].time == 1011 and rival.encounters[34] == oldest)
print("Complete newest-first encounter history checks passed")

addon.db = assert(addon.Ledger.Open(nil))
now = 1100
addon.RecordEncounter("Player-one", "First Rival", "killsAgainstThem", { time = now })
local manualID = assert(addon.AddManualEncounter("Second Rival", "deathsToThem"))
addon.RecordEncounter("Player-unknown", nil, "killsAgainstThem", { time = now })
local legacy = addon.Ledger.Add(addon.db, "manual:old rival", "Old Rival")
legacy.encounters = { { manual = true } }
local recent = addon.RecentEncounters(addon.db, 100)
assert(#recent == 4)
assert(recent[1].id == "Player-unknown" and not addon.IsRosterRival(recent[1].id, recent[1].rival))
assert(recent[2].id == manualID and recent[2].encounter.manual and recent[2].encounter.time == nil)
assert(recent[2].encounter.recordedAt == now and recent[3].id == "Player-one")
assert(recent[4].encounter == legacy.encounters[1])
addon.Ledger.Remove(addon.db, "Player-unknown")
for timestamp = 1101, 1210 do
    addon.RecordEncounter("Player-one", "First Rival", "killsAgainstThem", { time = timestamp })
end
recent = addon.RecentEncounters(addon.db, 100)
assert(#recent == 100 and recent[1].time == 1210 and recent[100].time == 1111)
assert(#addon.db.rivals["Player-one"].encounters == 111 and addon.db.rivals[manualID])
print("Cross-rival skirmish order and display limit checks passed")
