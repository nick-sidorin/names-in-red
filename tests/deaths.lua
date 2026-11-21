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
local battle = { time = 1212, allies = {}, enemies = {}, events = {} }
assert(addon.Ledger.SaveSkirmish(addon.db, "battle-one", battle) == battle)
recent = addon.RecentEncounters(addon.db, 2)
assert(#recent == 2 and recent[1].skirmish == battle and recent[2].time == 1210)
print("Cross-rival skirmish order and display limit checks passed")

local ledger = addon.Ledger
local orcID, shamanID, bystanderID = "Player-orc", "Player-shaman", "Player-bystander"
addon.RecordEncounter(orcID, "Orc Gruntsong", "killsAgainstThem", { time = 1080 })
local earlier = {
    time = 1090, allies = { { id = "me", isSelf = true, level = 51 }, { id = "brother" } },
    enemies = {
        { id = "orc", rivalID = orcID, name = "Orc Gruntsong", level = 52 },
        { id = "shaman", rivalID = shamanID, name = "Shaman Windsong" },
        { id = "bystander", rivalID = bystanderID, name = "Rogue Knifeblade" },
    },
    events = {
        { kind = "kill", actorID = "brother", targetID = "orc", contributors = { me = true } },
        { kind = "kill", actorID = "shaman", targetID = "me", contributors = { shaman = true, orc = false } },
        { kind = "kill", actorID = "brother", targetID = "bystander", contributors = { me = false } },
    },
}
assert(addon.RecordSkirmish("earlier-team-fight", earlier) == earlier)
local function CheckScore(id, expectedWins, expectedLosses)
    local wins, losses = ledger.PersonalScore(addon.db, id)
    assert(wins == expectedWins and losses == expectedLosses)
end
CheckScore(orcID, 2, 0)
CheckScore(shamanID, 0, 1)
CheckScore(bystanderID, 0, 0)
assert(ledger.Find(addon.db, shamanID).displayName == "Shaman Windsong")
local personalHistory = addon.RivalEncounters(addon.db, orcID)
assert(#personalHistory == 2 and personalHistory[2].direction == "killsAgainstThem")
local compact = personalHistory[1]
assert(compact.skirmishID == "earlier-team-fight" and compact.playerLevel == 51 and compact.rivalLevel == 52)
assert(compact.player == earlier.allies[1] and compact.opponent == earlier.enemies[1])
assert(compact.wins == 1 and compact.losses == 0 and addon.db.skirmishes[compact.skirmishID] == earlier)
assert(addon.RivalEncounters(addon.db, bystanderID)[1].skirmishID == compact.skirmishID)
assert(addon.RecentEncounters(addon.db, 100)[100].time > earlier.time)

addon.RecordSkirmish("earlier-team-fight", earlier)
CheckScore(orcID, 2, 0)
local followUp = {
    time = 1220, allies = earlier.allies, enemies = earlier.enemies,
    events = {
        { kind = "kill", actorID = "me", targetID = "orc" },
        { kind = "kill", targetID = "me", contributors = { shaman = true, bystander = true } },
    },
}
-- Missing alive/participation evidence in the timeline does not grant a score.
addon.RecordSkirmish("follow-up", followUp)
CheckScore(orcID, 2, 0)
CheckScore(shamanID, 0, 2)
CheckScore(bystanderID, 0, 1)
followUp.events[1].contributors = { me = true }
addon.RecordSkirmish("follow-up", followUp)
CheckScore(orcID, 3, 0)
assert(#addon.RivalEncounters(addon.db, orcID) == 3)
local reopened = assert(ledger.Open({ version = 1, rivals = addon.db.rivals, skirmishes = addon.db.skirmishes }))
assert(ledger.PersonalScore(reopened, orcID) == 3)
ledger.Remove(addon.db, orcID)
ledger.Add(addon.db, orcID, "Orc Gruntsong")
CheckScore(orcID, 0, 0)
CheckScore(shamanID, 0, 2)
assert(#addon.RivalEncounters(addon.db, orcID) == 0 and earlier.events[1].targetID == "orc")
print("Personal score, incomplete evidence and shared skirmish history checks passed")
