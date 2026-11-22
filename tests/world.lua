local addon, frames, timers = {}, {}, {}
local time, hk, inCombat = 1000, 4, true
local units = {
    player = { "Player-self", "Alden Dawnshield", "Alliance" },
    party1 = { "Player-brother", "Thoren Ironbrook", "Alliance" },
    target = { "Player-fenrik", "Fenrik Coldwater", "Horde" },
    mouseover = { "Player-ghash", "Ghash Emberfang", "Horde" },
}
function UnitGUID(unit) return units[unit] and units[unit][1] end
function UnitName(unit) return units[unit][2] end
function UnitFactionGroup(unit) return units[unit][3] end
function UnitIsPlayer(unit) return units[unit] ~= nil end
function UnitCanAttack(_, unit) return UnitIsPlayer(unit) and UnitFactionGroup(unit) == "Horde" end
function GetNumSubgroupMembers() return 1 end
function GetTime() return time end
function GetServerTime() return math.floor(time) end
function GetPVPSessionStats() return hk end
function InCombatLockdown() return inCombat end
function IsInInstance() return false, "none" end
function GetRealZoneText() return "Tanaris" end

function CreateFrame()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(_, handler) self.handler = handler end
    frames[#frames + 1] = frame
    return frame
end

local function Fire(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] then frame.handler(frame, event, ...) end
    end
end

C_Timer = { After = function(delay, callback)
    timers[#timers + 1] = { time = time + delay, callback = callback }
end }
local function Advance(seconds)
    local finish = time + seconds
    while #timers > 0 do
        table.sort(timers, function(a, b) return a.time < b.time end)
        if timers[1].time > finish then break end
        local timer = table.remove(timers, 1)
        time = timer.time
        timer.callback()
    end
    time = finish
end

Constants = { CurrencyConsts = { CLASSIC_HONOR_CURRENCY_ID = 1901 } }
for _, file in ipairs({ "Ledger", "Encounter", "Core", "WorldSkirmishes", "Honor", "Kills" }) do
    assert(loadfile("NamesInRed/" .. file .. ".lua"))("NamesInRed", addon)
end
addon.db = addon.Ledger.Open(nil)
Fire("PLAYER_ENTERING_WORLD")

local fenrik, ghash, brother = units.target[1], units.mouseover[1], units.party1[1]
local function GainHK()
    hk = hk + 1
    Fire("PLAYER_PVP_KILLS_CHANGED", "player")
    Fire("PLAYER_PVP_KILLS_CHANGED", "player")
end
local function HonorChat(message, lineID)
    Fire("CHAT_MSG_COMBAT_HONOR_GAIN", message, nil, nil, nil, nil, nil, nil, nil, nil, nil, lineID)
end
local function CheckReward(id, expectedHK, expectedHonor)
    local wins, losses, actualHK, honor = addon.Ledger.PersonalScore(addon.db, id)
    assert(wins == 0 and losses == 0 and actualHK == expectedHK and honor == expectedHonor)
end

-- Replay the observed order of the live Forever signals for a grouped kill.
Fire("PARTY_KILL", brother, fenrik)
Advance(0.317)
GainHK()
Advance(0.685)
local message = "Вы получили 6 |4очко чести:очка чести:очков чести;."
HonorChat(message, 71)
HonorChat(message, 71)
Advance(2.1)
CheckReward(fenrik, 1, 6)
local battle = assert(addon.db.skirmishes["world:1"])
assert(#battle.allies == 2 and battle.allies[2].id == brother and battle.events[1].actorID == brother)

local context = addon.EncounterContext("target")
context.attackers = { { guid = fenrik }, { guid = ghash } }
addon.RecordWorldEncounter(fenrik, units.target[2], "deathsToThem", context)
local encounter = addon.Ledger.RivalSkirmishes(addon.db, ghash)[1]
assert(encounter.playerDeathIndex == 2 and not encounter.outcome)

-- Two eligible targets in one burst leave the grant unassigned.
inCombat = false
Fire("PLAYER_REGEN_ENABLED")
local observedRival = units.mouseover
units.mouseover = nil
Fire("PARTY_KILL", brother, ghash)
units.mouseover = observedRival
assert(battle.events[3].targetID == ghash)
GainHK()
Fire("PARTY_KILL", brother, fenrik)
HonorChat(message, 72)
Advance(2.1)
CheckReward(fenrik, 1, 6)
CheckReward(ghash, 0, 0)

-- A new combat session, with a currency amount and the HK notification first.
Advance(9)
inCombat = true
Fire("PLAYER_REGEN_DISABLED")
GainHK()
Advance(0.1)
Fire("PARTY_KILL", brother, ghash)
Fire("CURRENCY_DISPLAY_UPDATE", 1901, 100, 7)
HonorChat("Unrecognized localized award", 73)
Advance(2.1)
CheckReward(ghash, 1, 7)
assert(#addon.db.skirmishes["world:2"].events == 1)

Fire("PARTY_KILL", brother, fenrik)
GainHK()
HonorChat(message, 74)
addon.ResetHonorTracking()
addon.ResetWorldTracking()
addon.Ledger.Clear(addon.db)
Advance(2.1)
assert(next(addon.db.rivals) == nil and not addon.db.skirmishes)
print("Live world skirmish grouping, isolated honor attribution, and reset checks passed")

-- The lethal player's unit is visible on a nameplate, without being targeted.
units.target, units.mouseover = nil, nil
units.nameplate1 = { "Player-rogue", "Test Rogue", "Horde" }
units.nameplate2 = { "Player-bystander", "Other Player", "Horde" }
function UnitLevel(unit) return units[unit] and 32 end
function UnitRace(unit)
    if unit == "player" then return "Night Elf", "NightElf" end
    if unit == "nameplate1" then return "Undead", "Scourge" end
end
function UnitSex(unit) return unit == "player" and 3 or 2 end
function UnitClass(unit)
    if unit == "player" then return "Hunter", "HUNTER" end
    if unit == "nameplate1" then return "Rogue", "ROGUE" end
end
C_NamePlate = { GetNamePlates = function() return {
    { unitToken = "nameplate1", IsForbidden = function() return false end },
    { unitToken = "nameplate2", IsForbidden = function() return false end },
    { IsForbidden = function() return true end },
} end }
bit = { band = function() return 0x440 end }
local recap
C_DeathRecap = { GetRecapEvents = function() return recap end }
assert(loadfile("NamesInRed/Deaths.lua"))("NamesInRed", addon)
Fire("PLAYER_DEAD")
assert(not addon.db.skirmishes)
units.nameplate1 = nil
recap = { { sourceGUID = "Player-rogue", sourceName = "Test Rogue", sourceFlags = 0x440,
    timestamp = time, overkill = 2 } }
Advance(0.3)
local recorded = assert(addon.db.skirmishes["world:1"])
assert(#recorded.enemies == 1 and recorded.enemies[1].id == "Player-rogue")
local rogue, player = recorded.enemies[1], recorded.allies[1]
assert(rogue.level == 32 and rogue.class == "ROGUE" and rogue.race == "scourge" and rogue.sex == 2)
assert(player.level == 32 and player.class == "HUNTER" and player.race == "nightelf" and player.sex == 3)
assert(recorded.rosterComplete and addon.Ledger.SkirmishOutcome(recorded) == "loss")
local wins, losses = addon.Ledger.PersonalScore(addon.db, rogue.id)
assert(wins == 0 and losses == 1)
print("Delayed death recap retains previously visible nameplate appearance")

-- If a teammate later lands a blow, the same record is no longer a duel.
addon.RecordWorldEncounter(rogue.id, rogue.name, "killsAgainstThem", {
    time = GetServerTime(), zone = "Tanaris", actorID = brother, actorName = "Thoren Ironbrook",
})
assert(#recorded.allies == 2 and not recorded.rosterComplete and not addon.Ledger.SkirmishOutcome(recorded))
wins, losses = addon.Ledger.PersonalScore(addon.db, rogue.id)
assert(wins == 0 and losses == 0)

-- Reopen a pre-upgrade record matching the solo kill signal in the live log.
local saved = { version = 1, rivals = addon.db.rivals, skirmishes = {} }
local direct = { kind = "kill", actorID = player.id, targetID = rogue.id }
local indirect = { kind = "kill", actorID = "Player-other", targetID = rogue.id }
local reciprocal = { kind = "kill", actorID = rogue.id, targetID = player.id }
local function SavedBattle(events)
    return { rosterComplete = false, allies = { player }, enemies = { rogue }, events = events }
end
saved.skirmishes["world:1"] = SavedBattle({ direct })
saved.skirmishes["world:2"] = SavedBattle({ indirect })
saved.skirmishes["world:3"] = SavedBattle({ direct, reciprocal })
saved.skirmishes["seed:incomplete"] = SavedBattle({ direct })
assert(addon.Ledger.Open(saved) == saved)
assert(saved.skirmishes["world:1"].rosterComplete and not saved.skirmishes["world:2"].rosterComplete)
assert(saved.skirmishes["world:3"].rosterComplete and not addon.Ledger.SkirmishOutcome(saved.skirmishes["world:3"]))
assert(not saved.skirmishes["seed:incomplete"].rosterComplete)
wins, losses = addon.Ledger.PersonalScore(saved, rogue.id)
assert(wins == 1 and losses == 0)
print("Observed world duels recalculate on load and when participants change")
