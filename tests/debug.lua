local registered, timers = {}, {}
local onEvent
local secret = {}
local restricted = {}
local rejectedEvent = "PVP_MATCH_COMPLETE"

function issecretvalue(value) return value == secret end
function canaccesstable(value) return value ~= restricted end
function GetBuildInfo() return "1.60.1", "70959", "", 16001 end
function GetLocale() return "deDE" end
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
    addon = addon or {}
    assert(loadfile("NamesInRed/Locale.lua"))("NamesInRed", addon)
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
local standardAddon = { db = {} }
Login(standardAddon)
SlashCmdList.NAMESINREDDEBUG("faction horde")
assert(not next(standardAddon.db))
SlashCmdList.NAMESINREDDEBUG("seed")
SlashCmdList.NAMESINREDDEBUG("clear-seed")
local debugPrint, printed = print
print = function(title, message) printed = title .. " " .. message end
SlashCmdList.NAMESINREDDEBUG("sample")
print = debugPrint
assert(db.rows[1000].kind == "MANUAL_SAMPLE")
assert(printed:find("Names in Red Diagnose", 1, true) == 1)
print("Debug capture checks passed")

local addon = {}
assert(loadfile("NamesInRed/Ledger.lua"))("NamesInRed", addon)
assert(loadfile("NamesInRed/Encounter.lua"))("NamesInRed", addon)
assert(loadfile("debug/DebugSeeds.lua"))("NamesInRed", addon)
addon.db = assert(addon.Ledger.Open(nil))
local existing = addon.Ledger.Add(addon.db, "Player-existing", "Existing")
local existingManual = addon.Ledger.Add(addon.db, "manual:existing", "Existing")
Login(addon)

local self, rival = "Player-test", "Player-rival"
local function OldLoss(id, stamp, zone, level)
    local enemy = { id = rival, rivalID = rival, level = level }
    local fight = { zone = zone, allies = { { id = self, isSelf = true } }, enemies = { enemy },
        events = { { kind = "kill", actorID = rival, targetID = self, time = stamp } } }
    addon.Ledger.SaveSkirmish(addon.db, id, fight)
    return enemy
end
local match = OldLoss("world:1", 100, "Test Zone")
local known = OldLoss("world:2", 100, "Test Zone", 30)
local earlier = OldLoss("world:3", 99, "Test Zone")
local ambiguous = OldLoss("world:4", 101, "Test Zone")
local otherZone = OldLoss("world:5", 100, "Another Zone")
local function CombatEnd(stamp)
    return { kind = "COMBAT_END", instanceType = "none", time = stamp, zone = "Test Zone", player = { guid = self },
        contacts = { [self] = { latest = { guid = self, dead = true } },
            [rival] = { latest = { guid = rival, level = 32 } } } }
end
addon.RestoreDeathLevels(addon.db, { version = 1, rows = { CombatEnd(100), CombatEnd(101), CombatEnd(101) } })
assert(match.level == 32 and known.level == 30)
assert(not earlier.level and not ambiguous.level and not otherZone.level)
for i = 1, 5 do addon.Ledger.RemoveSkirmish(addon.db, "world:" .. i) end
print("Death levels restored only for matching combat observations")

local faction = "Alliance"
function UnitFactionGroup() return faction end
local originalServerTime = GetServerTime
GetServerTime = function() return 777600 end
C_Map = { GetMapInfo = function(mapID) return { name = "Map " .. mapID } end }
C_CreatureInfo = { GetRaceInfo = function(raceID) return { raceName = "Race " .. raceID } end }
LOCALIZED_CLASS_NAMES_MALE = { SHAMAN = "Schamane" }
addon.Ledger.SaveSkirmish(addon.db, "existing-battle", { allies = {}, enemies = {}, events = {} })
SlashCmdList.NAMESINREDDEBUG("seed")
SlashCmdList.NAMESINREDDEBUG("seed")

local profiles = 0
for key, rival in pairs(addon.db.rivals) do
    if key:match("^seed:rival:") then
        profiles = profiles + 1
        assert(rival.race and rival.class and rival.raceLabel and rival.classLabel)
        local history = addon.RivalEncounters(addon.db, key)
        assert(#history > 0)
        local latest = math.huge
        for _, encounter in ipairs(history) do
            assert(encounter.rivalLevel and encounter.playerLevel and encounter.time < latest)
            assert(encounter.zone and encounter.mapID and encounter.x and encounter.y and not encounter.manual)
            latest = encounter.time
        end
    end
end
assert(profiles == 12)
local seeded = addon.db.skirmishes
local seededCount, outcomes = 0, { win = 0, loss = 0, unknown = 0 }
for id, battle in pairs(seeded) do
    if id:match("^seed:battle:") then
        seededCount = seededCount + 1
        local outcome = addon.Ledger.SkirmishOutcome(battle) or "unknown"
        outcomes[outcome] = outcomes[outcome] + 1
        assert(battle.allies[1].name == "Alden Dawnshield" and battle.allies[1].isSelf)
        assert(battle.zone == "Map " .. battle.mapID and battle.startedAt < battle.time)
        local participants, dead = {}, {}
        for _, ally in ipairs(battle.allies) do participants[ally.id] = "ally" end
        for _, enemy in ipairs(battle.enemies) do participants[enemy.id] = "enemy" end
        local previous = battle.startedAt
        for _, event in ipairs(battle.events) do
            assert(event.time > previous and event.time <= battle.time)
            assert(participants[event.actorID] and participants[event.targetID] ~= participants[event.actorID])
            assert(participants[event.targetID] and not dead[event.actorID] and not dead[event.targetID])
            dead[event.targetID], previous = true, event.time
        end
        for id, reward in pairs(battle.rewards) do
            assert(participants[id] == "enemy" and dead[id] and reward.honorableKills == 1 and reward.honor > 0)
        end
    end
end
assert(seededCount == 12 and outcomes.win == 6 and outcomes.loss == 5 and outcomes.unknown == 1)
local dargun = addon.db.rivals["seed:rival:1"]
assert(dargun.displayName == "Dargun Ironjaw" and dargun.raceLabel == "Race 2" and dargun.classLabel == "Schamane")
local dargunHistory = addon.RivalEncounters(addon.db, "seed:rival:1")
local rematch = seeded[dargunHistory[1].skirmishID]
assert(#rematch.allies == 2 and #rematch.enemies == 2 and rematch.events[3].actorID == "ally2")
assert(dargunHistory[1].outcome == "win" and dargunHistory[1].playerDeathIndex == 2)
assert(dargunHistory[2].outcome == "loss" and dargunHistory[3].outcome == "win")
local wins, losses, honorableKills, honor = addon.Ledger.PersonalScore(addon.db, "seed:rival:1")
assert(wins == 2 and losses == 1 and honorableKills == 2 and honor == 35)
local chapel = seeded["seed:battle:chapel-road"]
assert(#chapel.allies == 5 and #chapel.enemies == 6 and addon.Ledger.SkirmishOutcome(chapel) == "loss")
assert(chapel.rewards["seed:rival:8"].honor == 13)
assert(not seeded["seed:battle:plaguelands-crossing"].rosterComplete)

SlashCmdList.NAMESINREDDEBUG("faction Horde")
local hordeRematch = seeded["seed:battle:winter-rematch"]
assert(hordeRematch.allies[1].name == "Dargun Ironjaw" and hordeRematch.demoFaction == "Horde")
assert(addon.db.rivals["seed:rival:1"].displayName == "Alden Dawnshield")
assert(addon.db.rivals["seed:rival:1"].demoFaction == "Horde" and UnitFactionGroup("player") == "Alliance")
SlashCmdList.NAMESINREDDEBUG("faction auto")
assert(seeded["seed:battle:winter-rematch"].demoFaction == "Alliance")
faction = "Horde"
SlashCmdList.NAMESINREDDEBUG("faction alliance")
assert(seeded["seed:battle:winter-rematch"].demoFaction == "Alliance" and UnitFactionGroup("player") == "Horde")
SlashCmdList.NAMESINREDDEBUG("seed")
assert(seeded["seed:battle:winter-rematch"].demoFaction == "Horde")
SlashCmdList.NAMESINREDDEBUG("clear-seed")
for key in pairs(addon.db.rivals) do assert(not key:match("^seed:")) end
assert(next(seeded) == "existing-battle" and next(seeded, "existing-battle") == nil)
assert(addon.db.rivals["Player-existing"] == existing)
assert(addon.db.rivals["manual:existing"] == existingManual)
C_Map, C_CreatureInfo, LOCALIZED_CLASS_NAMES_MALE = nil, nil, nil
GetServerTime = originalServerTime
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

Event("PLAYER_DEAD")
local firstPending = #timers - 2
addon.ClearDiagnostics()
for index = firstPending, #timers do timers[index][2]() end
Event("PLAYER_REGEN_ENABLED")
assert(#db.rows == 0 and db.dropped == 0)
Event("PLAYER_PVP_KILLS_CHANGED", "player")
assert(#db.rows == 1 and db.rows[1].kind == "PLAYER_PVP_KILLS_CHANGED" and not db.rows[1].combatSequence)
print("Diagnostic reset cancels pending recap and continues recording")
