local registered, timers = {}, {}
local onEvent
local secret = {}
local restricted = {}
local rejectedEvent = "PVP_MATCH_COMPLETE"

function issecretvalue(value) return value == secret end
function canaccesstable(value) return value ~= restricted end
function GetBuildInfo() return "1.60.1", "70959", "", 16001 end
function GetServerTime() return 100 end
function GetTime() return 15 end
function IsInInstance() return true, "pvp" end
function UnitGUID(unit) return unit == "player" and "Player-test" or secret end
function UnitName(unit) if unit == "player" then return "Test", "Rival" end end
function GetPVPSessionStats() return 2 end

C_PvP = { GetScoreInfoByPlayerGuid = function() return { killingBlows = secret } end }
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { delay, callback } end }
local recap = restricted
C_DeathRecap = {
    HasRecapEvents = function() return true end,
    GetRecapEvents = function() return recap end,
}
SlashCmdList = {}

local frame = {
    RegisterEvent = function(_, event)
        assert(event ~= rejectedEvent)
        registered[event] = true
    end,
    UnregisterEvent = function(_, event) registered[event] = nil end,
    SetScript = function(_, _, callback) onEvent = callback end,
}
function CreateFrame() return frame end

local function Event(name, ...)
    assert(registered[name])
    onEvent(frame, name, ...)
end

local function Login(addon)
    assert(loadfile("NamesInRed/Debug.lua"))("NamesInRed", addon)
    Event("ADDON_LOADED", "OtherAddon")
    Event("ADDON_LOADED", "NamesInRed")
    return NamesInRedDebugDB
end

local db = Login()
assert(db.rows[1].registration[rejectedEvent] == "unavailable")
assert(db.rows[1].score.status.killingBlows == "secret")
assert(db.rows[1].score.killingBlows == nil)

Event("PLAYER_DEAD")
assert(db.rows[3].status.events == "restricted-table")
Event("PLAYER_DEAD")
timers[1][2]()
assert(#db.rows == 5)
recap = {
    { sourceGUID = "Player-a", amount = 10, event = "SWING_DAMAGE" },
    { sourceGUID = secret, amount = secret },
}
for i = 4, 6 do timers[i][2]() end
assert(db.rows[6].delay == 0.3 and db.rows[8].delay == 2)
assert(db.rows[8].events[1].sourceGUID == "Player-a")
assert(db.rows[8].events[2].status.sourceGUID == "secret")
assert(db.rows[8].events[2].sourceGUID == nil)

Event("PARTY_KILL", "Player-test", secret)
assert(db.rows[9].attacker == "Player-test")
assert(db.rows[9].player.name == "Test" and db.rows[9].player.surname == "Rival")
assert(db.rows[9].victim == nil and db.rows[9].status.victim == "secret")
Event("CHAT_MSG_COMBAT_HONOR_GAIN", "Test message", nil, nil, nil, nil, nil, nil, nil, nil, nil, 42, secret)
assert(db.rows[10].message == "Test message")
assert(db.rows[10].lineID == 42 and db.rows[10].status.chatGUID == "secret")
Event("PARTY_KILL", "Player-test", "Creature-test")
assert(#db.rows == 10)
for _ = 1, 1000 do Event("PLAYER_PVP_KILLS_CHANGED", "player") end
assert(#db.rows == 1000 and db.dropped == 10)
assert(Login() == db and db.session == 2 and db.rows[1000].kind == "SESSION")
assert(NamesInRedDB == nil)
Login({ db = {} })
SlashCmdList.NAMESINREDDEBUG("seed")
SlashCmdList.NAMESINREDDEBUG("clear-seed")
SlashCmdList.NAMESINREDDEBUG("sample")
assert(db.rows[1000].kind == "MANUAL_SAMPLE")
print("Debug capture checks passed")

local addon = {}
assert(loadfile("NamesInRed/Ledger.lua"))("NamesInRed", addon)
assert(loadfile("NamesInRed/Encounter.lua"))("NamesInRed", addon)
assert(loadfile("debug/DebugSeeds.lua"))("NamesInRed", addon)
addon.db = assert(addon.Ledger.Open(nil))
local existing = addon.Ledger.Add(addon.db, "Player-existing", "Existing")
local existingManual = addon.Ledger.Add(addon.db, "manual:existing", "Existing")
Login(addon)
SlashCmdList.NAMESINREDDEBUG("seed")
SlashCmdList.NAMESINREDDEBUG("seed")

local automatic, manual = 0, 0
for key, rival in pairs(addon.db.rivals) do
    if key:match("^seed:manual:") then
        manual = manual + 1
        assert(rival.encounters[1].manual and #rival.encounters == 1)
        assert(rival.killsAgainstThem + rival.deathsToThem == 1)
    elseif key:match("^seed:") then
        automatic = automatic + 1
        assert(rival.race and rival.class and rival.raceLabel and rival.classLabel)
        assert(#rival.encounters == rival.killsAgainstThem + rival.deathsToThem)
        for _, encounter in ipairs(rival.encounters) do
            assert(encounter.rivalLevel and encounter.playerLevel and encounter.time)
            assert(encounter.zone and encounter.mapID and encounter.x and encounter.y and not encounter.manual)
        end
    end
end
assert(manual == 6 and automatic == 24)
local seeded = addon.db.skirmishes
assert(#seeded["seed:battle:1"].allies == 2 and #seeded["seed:battle:1"].enemies == 2)
assert(seeded["seed:battle:1"].events[1].actorID == "ally:1")
assert(#seeded["seed:battle:2"].allies == 1 and #seeded["seed:battle:2"].enemies == 1)
local dargunHistory = addon.RivalEncounters(addon.db, "seed:4")
local mutual = dargunHistory[2]
assert(mutual.skirmishID == "seed:battle:2" and mutual.wins == 1 and mutual.losses == 1)
local assisted = dargunHistory[5]
assert(assisted.skirmishID == "seed:battle:5" and assisted.wins == 1 and assisted.losses == 1)
assert(seeded[assisted.skirmishID].events[2].actorID == "ally:1")
assert(#seeded["seed:battle:3"].enemies == 6 and not seeded["seed:battle:4"].rosterComplete)
local borin = addon.RivalEncounters(addon.db, "seed:2")[1]
assert(borin.skirmishID == "seed:battle:3" and borin.wins == 0 and borin.losses == 0)
assert(borin.opponentDeathIndex == 2 and borin.playerDeathIndex == 3)
addon.Ledger.SaveSkirmish(addon.db, "existing-battle", { allies = {}, enemies = {}, events = {} })
SlashCmdList.NAMESINREDDEBUG("clear-seed")
for key in pairs(addon.db.rivals) do assert(not key:match("^seed:")) end
assert(next(seeded) == "existing-battle" and next(seeded, "existing-battle") == nil)
assert(addon.db.rivals["Player-existing"] == existing)
assert(addon.db.rivals["manual:existing"] == existingManual)
print("Debug seed checks passed")

local inCombat, groupSize = false, 1
local visibleTarget = "Player-rival"
function InCombatLockdown() return inCombat end
function GetNumSubgroupMembers() return groupSize end
function GetNumGroupMembers() return groupSize > 0 and groupSize + 1 or 0 end
function IsInRaid() return false end
function UnitGUID(unit)
    if unit == "player" then return "Player-test" end
    if unit == "party1" then return "Player-ally" end
    if unit == "nameplate1" then return "Player-rival" end
    if unit == "nameplate1target" then return visibleTarget end
end

Enum = {
    DamageMeterType = { DamageDone = 1, DamageTaken = 2, HealingDone = 3, EnemyDamageTaken = 4 },
    DamageMeterSessionType = { Current = 0 },
}
local sessions = { { sessionID = 1 } }
local archivedReads = 0
C_DamageMeter = {
    GetAvailableCombatSessions = function() return sessions end,
    GetCombatSessionFromID = function(id, meterType)
        assert(id == 2)
        archivedReads = archivedReads + 1
        if meterType == 2 then return restricted end
        return { combatSources = {
            { sourceGUID = "Player-ally", totalAmount = 40 },
            { sourceGUID = secret, name = secret },
        } }
    end,
    GetCombatSessionSourceFromID = function(id, _, guid)
        assert(id == 2 and guid == "Player-ally")
        return { combatSpells = { { spellID = 42, combatSpellDetails = {
            unitName = "Enemy Rival", unitClassFilename = "WARRIOR", isMob = false, amount = secret,
        } } } }
    end,
    GetCombatSessionFromType = function(sessionType)
        assert(sessionType == 0)
        return { combatSources = {} }
    end,
}

Event("NAME_PLATE_UNIT_ADDED", "nameplate1")
inCombat = true
Event("PLAYER_REGEN_DISABLED")
local started = db.rows[#db.rows]
assert(started.kind == "COMBAT_START" and started.group[1].guid == "Player-ally")
Event("PARTY_KILL", "Player-ally", "Player-rival")
assert(db.rows[#db.rows].combatSequence == started.combatSequence)
local function countKills()
    local count = 0
    for _, row in ipairs(db.rows) do
        if row.kind == "PARTY_KILL" and row.combatSequence == started.combatSequence then count = count + 1 end
    end
    return count
end
for _ = 1, 12 do Event("PARTY_KILL", secret, secret) end
assert(countKills() == 9)
visibleTarget = "Player-ally"
Event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
Event("GROUP_ROSTER_UPDATE")
Event("DAMAGE_METER_COMBAT_SESSION_UPDATED", 1, 2)
Event("DAMAGE_METER_COMBAT_SESSION_UPDATED", 1, 2)
sessions[2] = { sessionID = 2 }
inCombat = false
Event("PLAYER_REGEN_ENABLED")
local ended = db.rows[#db.rows]
timers[#timers][2]()
assert(ended.kind == "COMBAT_END" and ended.combatSequence == started.combatSequence)
local observed = ended.contacts["Player-rival"]
assert(observed.changes[1].targetGUID == "Player-rival" and observed.latest.targetGUID == "Player-ally")
assert(observed.signals["combat-start"] == 1 and observed.signals["nameplate-removed"] == 1)
assert(#ended.groupChanges == 1 and ended.groupChanges[1].group[1].guid == "Player-ally")
assert(ended.meterUpdates["2:1"].count == 2 and ended.restrictedPartyKills == 12)
assert(ended.meterSelection == "new-archived" and ended.meterSessionID == 2 and archivedReads == 4)
assert(ended.meter.DamageTaken.status.session == "restricted-table")
local sources = ended.meter.DamageDone.sources
assert(sources[2].sourceGUID == nil and sources[2].status.sourceGUID == "secret")
local target = sources[1].spells[1].target
assert(target.unitName == "Enemy Rival" and target.unitClassFilename == "WARRIOR")
assert(target.amount == nil and target.status.amount == "secret")

groupSize = 0
Event("PLAYER_REGEN_DISABLED")
Event("PLAYER_REGEN_ENABLED")
ended = db.rows[#db.rows]
timers[#timers][2]()
assert(#ended.group == 0 and ended.meterSelection == "current-fallback" and archivedReads == 4)

Event("PLAYER_REGEN_DISABLED")
Event("PLAYER_REGEN_ENABLED")
ended = db.rows[#db.rows]
Event("PLAYER_REGEN_DISABLED")
timers[#timers][2]()
assert(ended.status.meter == "interrupted" and ended.meter == nil)
print("Post-combat diagnostic capture checks passed")
