local addon, frames, timers = {}, {}, {}
local now, instanceType, inCombat, ghost, hk = 1000, "pvp", false, false, 0
local match, recap, archive = 3, nil, {}
local me, rival, healer, remote = "Player-self", "Player-rival", "Player-healer", "Player-remote"
local units = {
    player = { id = me, name = "Local Hunter", faction = "Alliance", class = "HUNTER" },
    target = { id = rival, name = "Enemy Shaman", faction = "Horde", class = "SHAMAN" },
    raid1 = { id = healer, name = "Local Healer", faction = "Alliance", class = "PRIEST" },
    raid2 = { id = remote, name = "Remote Ally", faction = "Alliance", class = "PALADIN" },
    mouseover = { id = "Player-other", name = "Other Enemy", faction = "Horde", class = "MAGE" },
}
function GetLocale() return "enUS" end
function GetBuildInfo() return "1.60.1", "70959", "", 16001 end
function IsInInstance() return instanceType ~= "none", instanceType end
function GetInstanceInfo() return "Warsong Gulch", instanceType, 0, nil, 10, nil, false, 489 end
function GetRealZoneText() return "Warsong Gulch" end
function GetTime() return now end
function GetServerTime() return math.floor(now) end
function InCombatLockdown() return inCombat end
function UnitAffectingCombat(unit) return units[unit] and inCombat end
function UnitIsDeadOrGhost(unit) return units[unit] and (units[unit].dead == true or (unit == "player" and ghost)) end
function UnitIsFeignDeath() return false end
function UnitIsGhost(unit) return unit == "player" and ghost end
function UnitIsVisible(unit) return units[unit] ~= nil end
function UnitIsPlayer(unit) return units[unit] ~= nil end
function UnitIsPVP(unit) return units[unit] ~= nil end
function UnitGUID(unit) return units[unit] and units[unit].id end
function UnitName(unit) return units[unit] and units[unit].name end
function UnitClass(unit) return nil, units[unit] and units[unit].class end
function UnitFactionGroup(unit) return units[unit] and units[unit].faction end
function UnitCanAttack(_, unit) return UnitFactionGroup(unit) == "Horde" end
function GetPVPSessionStats() return hk end
function IsInRaid() return true end
function GetNumGroupMembers() return 2 end

C_PvP = { GetActiveMatchState = function() return match end }
C_DeathRecap = { GetRecapEvents = function() return recap end }
bit = { band = function() return 0x440 end }
Enum = { PvPMatchState = { Complete = 5 }, DamageMeterType = { HealingDone = 2 },
    DamageMeterSessionType = { Current = 0 } }
C_DamageMeter = {
    GetAvailableCombatSessions = function() return archive end,
    GetCombatSessionFromID = function()
        return { durationSeconds = 8, combatSources = { { sourceGUID = healer } } }
    end,
    GetCombatSessionSourceFromID = function()
        return { combatSpells = { { combatSpellDetails = { unitName = "Local Hunter", unitClassFilename = "HUNTER",
            amount = 25, isPet = false, isMob = false } } } }
    end,
}
SlashCmdList = {}

function CreateFrame()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(_, fn) self.handler = fn end
    frames[#frames + 1] = frame
    return frame
end

local function Fire(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] then frame.handler(frame, event, ...) end
    end
end
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { at = now + delay, run = fn } end }
local function Advance(delta)
    local stop = now + delta
    while #timers > 0 do
        table.sort(timers, function(a, b) return a.at < b.at end)
        if timers[1].at > stop then break end
        local nextTimer = table.remove(timers, 1)
        now = nextTimer.at
        nextTimer.run()
    end
    now = stop
end
local function Begin()
    inCombat = true
    Fire("PLAYER_REGEN_DISABLED")
end
local function End()
    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
end
local function Aura(source, target)
    Fire("UNIT_AURA", target, { addedAuras = { { sourceUnit = source, isHarmful = true, spellId = 55 } } })
end

for _, file in ipairs({ "Locale", "Ledger", "SkirmishOutcomes", "PersonalSkirmishOutcomes", "Encounter", "Core", "SkirmishEvidence",
    "WorldSkirmishes", "Honor", "Kills", "Deaths", "IssueReport", "Debug" }) do
    assert(loadfile("NamesInRed/" .. file .. ".lua"))("NamesInRed", addon)
end
addon.db = addon.Ledger.Open()
Fire("ADDON_LOADED", "NamesInRed")
Fire("PLAYER_ENTERING_WORLD")
assert(addon.IsBattlegroundTrackingEnabled() and addon.RecordingPvPOrigin() == "battleground")
assert(addon.BattlegroundMapID() == 489)

-- Two local segments in one connected fight. A teammate's unrelated raid kill
-- near the start, with a visible victim, cannot start a battle or seed its roster.
Begin()
Fire("PARTY_KILL", remote, units.mouseover.id)
assert(not addon.db.skirmishes)
Aura("player", "target")
Aura("raid2", "target")
End()
Advance(1)
Aura("target", "raid2")
Begin()
Aura("player", "target")
Advance(4)
units.target.dead = true
Fire("PARTY_KILL", me, rival)
local first = assert(addon.db.skirmishes["bg:1"])
assert(#first.observation.segments == 2 and first.observation.segments[2].continuation == "observed-hostility")
assert(first.instanceMapID == 489 and not addon.db.rivals[remote] and not addon.db.rivals[units.mouseover.id])
hk = 1
Fire("PLAYER_PVP_KILLS_CHANGED", "player")
Fire("CHAT_MSG_COMBAT_HONOR_GAIN", "You have been awarded 7 honor points.")
Advance(0.8)
units.target.dead = false
Fire("UNIT_FLAGS", "target")
Advance(2.3)
units.target.dead = true
Fire("PARTY_KILL", me, rival)
Fire("PARTY_KILL", me, rival)
assert(#first.events == 3 and first.events[2].kind == "revive")
local hkEarned, honor = addon.Ledger.SkirmishRewards(first)
assert(hkEarned == 1 and honor == 7)

-- A fresh archived meter session explicitly links the healing-only ally.
Advance(0.9)
archive = { { sessionID = 11 } }
Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 2, 11)
End()
Advance(3.0)
assert(#first.allies == 3 and first.allies[3].id == healer)
assert(#first.enemies == 1 and not first.rosterComplete and first.origin == "battleground")
assert(first.observation.segments[2].meter.sessionID == 11)
local report = addon.BuildIssueReport(addon.db, NamesInRedDebugDB, "bg:1")
assert(report:find('"origin": "Battleground"', 1, true) and report:find("exact-combat-window", 1, true))
assert(not report:find(units.raid1.name, 1, true))

-- A separate fight against the same enemy can reuse the same instance, zone
-- and meter history. A fresh local window does not inherit those participants.
units.target.dead = false
Begin()
Aura("player", "target")
recap = { { sourceGUID = rival, sourceName = units.target.name, sourceFlags = 0x440, timestamp = now, overkill = 5 } }
units.player.dead = true
Fire("PLAYER_DEAD")
End()
local second = assert(addon.db.skirmishes["bg:2"])
assert(#second.allies == 1 and #second.events == 1 and second.events[1].targetID == me)
ghost = true
Fire("PLAYER_ALIVE")
Fire("AREA_SPIRIT_HEALER_IN_RANGE")
units.player.dead, ghost = false, false
Advance(0.1)
Fire("UNIT_FLAGS", "player")
assert(#second.events == 1)
Fire("PLAYER_UNGHOST")
assert(#second.events == 1 and second.resolution.reason == "battleground-spirit-respawn")
assert(second.personalOutcome.outcome == "loss" and second.personalOutcome.boundary == "battleground-spirit-respawn")
Begin()
Aura("player", "target")
units.target.dead = true
Fire("PARTY_KILL", me, rival)
End()
Advance(3)
local third = assert(addon.db.skirmishes["bg:3"])
assert(#third.events == 1 and addon.Ledger.SkirmishOutcome(third) == "win")
match = 5
Fire("PVP_MATCH_COMPLETE", 0, 1500) -- the local Alliance lost the overall match
assert(addon.Ledger.SkirmishOutcome(third) == "win")
assert(third.personalOutcome.outcome == "win" and third.personalOutcome.casualties.enemy == 1)
assert(not addon.Ledger.SkirmishOutcome(second))
Fire("PARTY_KILL", me, rival)
assert(not addon.db.skirmishes["bg:4"])
match = 3
Fire("PVP_MATCH_ACTIVE")

-- Turning BG tracking off leaves the old ledger and recognition intact.
Begin()
units.target.dead = false
Aura("player", "target")
addon.SetBattlegroundTrackingEnabled(false)
local diagnosticCount = #NamesInRedDebugDB.rows
Fire("PARTY_KILL", me, rival)
Fire("PLAYER_DEAD")
hk = 2
Fire("PLAYER_PVP_KILLS_CHANGED", "player")
Fire("CHAT_MSG_COMBAT_HONOR_GAIN", "You have been awarded 12 honor points.")
End()
Advance(3)
assert(#NamesInRedDebugDB.rows == diagnosticCount and not addon.db.skirmishes["bg:4"])
assert(addon.FindVisibleRival(rival, "target") == addon.db.rivals[rival])
local kills, deaths = addon.Ledger.PersonalCombatScore(addon.db, rival)
assert(kills == 3 and deaths == 1)
assert(addon.Ledger.Open(addon.db) == addon.db and addon.db.skirmishes["bg:1"] == first)
assert(not addon.IsBattlegroundTrackingEnabled())

for _, context in ipairs({ "arena", "party", "raid", "scenario" }) do
    instanceType = context
    Fire("PLAYER_LEAVING_WORLD")
    Fire("PLAYER_ENTERING_WORLD")
    Begin()
    Aura("player", "target")
    Fire("PARTY_KILL", me, rival)
    Fire("PLAYER_DEAD")
    End()
    Advance(3)
    assert(addon.db.encounterSequence == 3 and not addon.RecordingPvPOrigin())
end
instanceType = "none"
Fire("PLAYER_ENTERING_WORLD")
assert(addon.RecordingPvPOrigin() == "world")
Begin()
Aura("player", "target")
units.target.dead = true
Fire("PARTY_KILL", me, rival)
assert(addon.db.skirmishes["world:4"].origin == "world")
assert(addon.db.skirmishes["bg:1"] == first and addon.FindVisibleRival(rival, "target") == addon.db.rivals[rival])

print("Battleground settings, linked support, continuations, respawn, repeated kills, outcomes, and legacy records passed")
