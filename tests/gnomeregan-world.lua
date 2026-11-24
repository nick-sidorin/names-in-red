-- Anonymized timing and signal shapes from the two Gnomeregan captures.
local addon, frames, timers = {}, {}, {}
local now, inCombat, ghost, hk = 1000, false, false, 0
local zone, recap, duration = "Fixture Grove", nil, 0
local me, ally, one, two = "Player-fixture-local", "Player-fixture-ally", "Player-fixture-one", "Player-fixture-two"
local localPlayer = { id = me, name = "Mock Paladin", faction = "Alliance", class = "PALADIN", x = 10 }
local friend = { id = ally, name = "Mock Druid", faction = "Alliance", class = "DRUID", x = 15 }
local first = { id = one, name = "Mock Mage", faction = "Horde", class = "MAGE", x = 20 }
local second = { id = two, name = "Mock Rogue", faction = "Horde", class = "ROGUE", x = 24 }
local units = { player = localPlayer, party1 = friend }
local function Field(unit, key) return units[unit] and units[unit][key] end

function GetLocale() return "enUS" end
function GetBuildInfo() return "1.60.1", "70959", "", 16001 end
function GetTime() return now end
function GetServerTime() return math.floor(now) end
function GetRealZoneText() return zone end
function IsInInstance() return false, "none" end
function InCombatLockdown() return inCombat end
function UnitAffectingCombat(unit) return units[unit] and (Field(unit, "active") or inCombat) end
function UnitIsDeadOrGhost(unit) return units[unit] and (Field(unit, "dead") == true or (unit == "player" and ghost)) end
function UnitIsFeignDeath(unit)
    if not Field(unit, "feignUnavailable") then return Field(unit, "feign") == true end
end
function UnitIsVisible(unit) return units[unit] ~= nil end
function UnitIsGhost(unit) return unit == "player" and ghost end
function UnitIsPlayer(unit) return units[unit] ~= nil and Field(unit, "id"):match("^Player%-") ~= nil end
function UnitIsPVP(unit) return units[unit] ~= nil end
function UnitGUID(unit) return Field(unit, "id") end
function UnitName(unit) return Field(unit, "name") end
function UnitClass(unit) return nil, Field(unit, "class") end
function UnitFactionGroup(unit) return Field(unit, "faction") end
function UnitCanAttack(_, unit) return UnitFactionGroup(unit) == "Horde" end
function UnitEffectiveLevel(unit) return Field(unit, "level") end
function GetNumSubgroupMembers() return units.party1 and 1 or 0 end
function GetPVPSessionStats() return hk end
function UnitPosition(unit)
    local x = Field(unit, "x")
    if x then return x, 10, 0, 0 end
end

C_DeathRecap = { GetRecapEvents = function() return recap end }
bit = { band = function(left, right)
    local value, weight = 0, 1
    while left > 0 and right > 0 do
        if left % 2 == 1 and right % 2 == 1 then value = value + weight end
        left, right, weight = math.floor(left / 2), math.floor(right / 2), weight * 2
    end
    return value
end }
Enum = { DamageMeterType = { DamageDone = 0, DamageTaken = 7, EnemyDamageTaken = 10, HealingDone = 2 },
    DamageMeterSessionType = { Current = 0 } }
local sources = {}
C_DamageMeter = {
    GetAvailableCombatSessions = function() return {} end,
    GetCombatSessionFromType = function(_, category)
        local rows = {}
        for guid in pairs(sources[category] or {}) do rows[#rows + 1] = { sourceGUID = guid } end
        return { combatSources = rows, durationSeconds = duration }
    end,
    GetCombatSessionSourceFromType = function(_, category, guid)
        local spells = sources[category] and sources[category][guid]
        return { combatSpells = spells or {} }
    end,
}
local function Link(category, actor, target, amount)
    sources[category] = sources[category] or {}
    sources[category][actor] = { { combatSpellDetails = { unitName = target.name, unitClassFilename = target.class,
        amount = amount, isPet = false, isMob = false } } }
end
C_NamePlate = { GetNamePlates = function()
    local result = {}
    for token in pairs(units) do
        if token:match("^nameplate") then result[#result + 1] = { unitToken = token, IsForbidden = function() return false end } end
    end
    return result
end }
SlashCmdList = {}
function CreateFrame()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(_, callback) self.dispatch = callback end
    frames[#frames + 1] = frame
    return frame
end
local function Fire(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] then frame.dispatch(frame, event, ...) end
    end
end
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { at = now + delay, run = callback } end }
local function Advance(delta)
    local stop = now + delta
    while #timers > 0 do
        table.sort(timers, function(a, b) return a.at < b.at end)
        if timers[1].at > stop then break end
        local timer = table.remove(timers, 1)
        now = timer.at
        timer.run()
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
local function Update(...)
    for _, category in ipairs({ ... }) do Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", category, 0) end
end
local function Chat(amount, line)
    Fire("CHAT_MSG_COMBAT_HONOR_GAIN", ("You have been awarded %d honor points."):format(amount),
        nil, nil, nil, nil, nil, nil, nil, nil, nil, line)
end
local function HK()
    hk = hk + 1
    Fire("PLAYER_PVP_KILLS_CHANGED", "player")
end

for _, file in ipairs({ "Locale", "Ledger", "SkirmishOutcomes", "SkirmishDeathEvidence", "PersonalSkirmishOutcomes", "RivalContributions", "Encounter", "Core", "SkirmishEvidence", "CombatDiagnostics",
    "WorldSkirmishes", "Honor", "Kills", "Deaths", "IssueReport", "Debug" }) do
    assert(loadfile("NamesInRed/" .. file .. ".lua"))("NamesInRed", addon)
end
Fire("ADDON_LOADED", "NamesInRed")
Fire("PLAYER_ENTERING_WORLD")
assert(addon.db)
local function Reset()
    Advance(10)
    addon.ResetData()
    units.target, units.mouseover, units.nameplate1 = nil, nil, nil
    units.party1 = friend
    localPlayer.dead, first.dead, second.dead, second.feign = nil, nil, nil, nil
    sources, recap, inCombat, ghost = {}, nil, false, false
end
local function Kill(actor, player)
    player.dead = true
    Fire("PARTY_KILL", actor, player.id)
end
local function Aura(source, target)
    Fire("UNIT_AURA", target, { addedAuras = { { isHarmful = true, sourceUnit = source, spellId = 14 } } })
end

-- 22:22 exactly one lethal player hit. Other recap rows belong to NPCs.
if not arg[1] or arg[1] == "solo" then
    units.party1 = nil
    recap = {
        { sourceGUID = one, sourceName = first.name, sourceFlags = 0x440, timestamp = now, overkill = 140, amount = 175, event = "SPELL_DAMAGE", spellId = 40 },
        { sourceGUID = "Creature-fixture-npc", sourceFlags = 0, timestamp = now - 1, overkill = -1, amount = 500 },
    }
    localPlayer.dead = true
    Fire("PLAYER_DEAD")
    local solo = assert(addon.db.skirmishes["world:1"])
    assert(not solo.enemies[1].level and not solo.rosterComplete)
    local hit = assert(solo.combatDiagnostics.recaps[1])
    assert(hit.actorID == one and hit.targetID == me and hit.spellID == 40 and hit.amount == 175)
    Fire("PLAYER_DEAD")
    assert(#solo.combatDiagnostics.recaps == 1)
    units.target, first.level = second, 49
    Fire("PLAYER_TARGET_CHANGED")
    assert(not solo.enemies[1].level)
    units.target, first.level = first, -1
    Fire("PLAYER_TARGET_CHANGED")
    assert(solo.enemies[1].level == -1)
    ghost = true
    Fire("PLAYER_ALIVE")
    zone = "Fixture Graveyard"
    Fire("ZONE_CHANGED_NEW_AREA")
    assert(addon.Ledger.SkirmishOutcome(solo) == "loss" and solo.resolution.reason == "isolated-lethal-recap")
    assert(addon.Ledger.Open(addon.db) == addon.db and addon.Ledger.SkirmishOutcome(solo) == "loss")
    assert(solo.personalOutcome.outcome == "loss" and solo.personalOutcome.casualties.friendly == 1)
end
Reset()

-- NPC lethal hit with a nearby enemy must not manufacture a PvP loss.
if not arg[1] or arg[1] == "npc" then
    units.target = first
    recap = { { sourceGUID = "Creature-lethal", sourceFlags = 0x440, timestamp = now, overkill = 1 },
        { sourceGUID = one, sourceFlags = 0x440, timestamp = now, overkill = -1, amount = 10 } }
    localPlayer.dead = true
    Fire("PLAYER_DEAD")
    Advance(3)
    assert(not addon.db.skirmishes)
end
Reset()

-- 20:09: off-target victim's identity was captured before nameplate removal.
-- The teammate linked to our known opponent by actual DamageTaken details.
if not arg[1] or arg[1] == "off-target" then
    duration = 21
    units.target, units.nameplate1 = first, second
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Begin()
    Advance(0.9)
    Update(0, 7, 10)
    Advance(12)
    Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    units.nameplate1 = nil
    Advance(2)
    Kill(ally, second)
    Fire("PARTY_KILL", ally, two)
    Advance(3.37)
    Kill(me, first)
    Update(0, 7, 10)
    Chat(2, 101)
    HK()
    Link(7, ally, first, 283)
    Advance(6.55)
    End()
    Advance(3)
    local twoKills = assert(addon.db.skirmishes["world:1"])
    assert(#twoKills.allies == 2 and #twoKills.enemies == 2 and #twoKills.events == 2)
    assert(twoKills.events[1].actorID == ally and twoKills.events[1].targetID == two)
    assert(twoKills.events[2].actorID == me and twoKills.events[2].targetID == one)
    assert(addon.Ledger.JournalRewards(addon.db).honor == 2)
end
Reset()

-- 20:20: mismatched 11-second Current, 8.56-second window. One precise
-- participant edge has independent category updates and a known victim.
if not arg[1] or arg[1] == "meter" then
    duration = 11
    units.target = first
    Begin()
    Fire("UNIT_COMBAT", "target", "WOUND", "CRITICAL", 42, 1)
    Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-diagnostic-private", 102)
    Advance(0.79)
    Update(0, 7, 10)
    Advance(1.65)
    Kill(me, first)
    Update(0, 10)
    Link(7, ally, first, 45)
    Advance(6.12)
    End()
    Advance(3)
    local recovered = assert(addon.db.skirmishes["world:1"])
    assert(#recovered.allies == 2 and recovered.allies[2].id == ally and #recovered.enemies == 1)
    local recoveredReport = addon.BuildIssueReport(addon.db, NamesInRedDebugDB, "world:1")
    assert(recoveredReport:find("eligible-corroborated", 1, true))
    local diagnostics = recovered.combatDiagnostics.windows[1]
    assert(diagnostics.streams.unitCombat.rows[1].targetID == one)
    assert(diagnostics.streams.spellCast.rows[1].spellID == 102)
    assert(diagnostics.meter.categories.DamageTaken.rows[1].amount == 45)
    local history = recovered.observation.segments[1].combatAggregates
    assert(#history == 1 and history[1].category == "DamageTaken" and history[1].amount == 45)
    assert(history[1].actorID == one and history[1].targetID == ally)
    assert(recoveredReport:find('"section": "meterSpellSample"', 1, true))
    assert(recoveredReport:find('"section": "primaryEvidence"', 1, true))
    assert(not recoveredReport:find("Cast-diagnostic-private", 1, true))
    local outcome = addon.Ledger.SkirmishOutcome(recovered)
    addon.ClearDiagnostics()
    assert(#NamesInRedDebugDB.rows == 0 and #recovered.events == 1)
    assert(addon.Ledger.Open(addon.db) == addon.db and addon.Ledger.SkirmishOutcome(recovered) == outcome)
    assert(addon.db.skirmishes["world:1"] == recovered and recovered.observation.segments[1].combatAggregates == history)
    local reportAfterClear = addon.BuildIssueReport(addon.db, NamesInRedDebugDB, "world:1")
    assert(reportAfterClear:find('"section": "combatAggregate"', 1, true))
end
Reset()

-- Known corpse from a departing plate, paired with terminal survivors. Only
-- the actual PARTY_KILL is an attributed blow. A feign snapshot is discarded.
if not arg[1] or arg[1] == "corpse" then
    duration = 38
    units.target, units.nameplate1 = first, second
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Begin()
    Aura("player", "target")
    Aura("party1", "target")
    Aura("player", "nameplate1")
    Advance(15)
    second.dead, second.feign = true, true
    Fire("UNIT_FLAGS", "nameplate1")
    Advance(2)
    second.feign = false
    Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    units.nameplate1 = nil
    Advance(3)
    Kill(ally, first)
    Advance(18)
    End()
    Advance(3)
    local grouped = assert(addon.db.skirmishes["world:1"])
    assert(#grouped.events == 2 and grouped.events[1].kind == "death" and not grouped.events[1].actorID)
    assert(grouped.events[1].targetID == two and grouped.events[2].actorID == ally)
    assert(addon.Ledger.SkirmishOutcome(grouped) == "win")
end
Reset()

-- 20:21: chat arrives before close. Reading a confirmed edge on the first
-- pass must not wait for an unrelated HealingDone update or use the next slot.
if not arg[1] or arg[1] == "replacement" then
    duration = 15
    units.target = first
    Begin()
    Advance(13)
    Link(0, me, first, 780)
    Update(0, 7, 10)
    Chat(5, 102)
    Advance(1.05)
    End()
    Advance(0.69)
    Begin()
    assert(addon.db.skirmishes["world:1"].enemies[1].id == one)
    units.target = second
    Advance(5.36)
    duration = 21
    Update(0, 10)
    End()
    Advance(3)
    local killFree = addon.db.skirmishes["world:1"]
    assert(not addon.db.skirmishes["world:2"] and #killFree.events == 0)
    assert(killFree.unassignedRewards and killFree.unassignedRewards.honor == 5)
    assert(addon.Ledger.PersonalScore(addon.db, one) == 0)
end
Reset()

-- Honor-only signals, including a duplicate delivered after quiet settlement.
if not arg[1] or arg[1] == "honor" then
    Chat(4, 120)
    Advance(2.1)
    Chat(4, 120)
    Chat(1, 121)
    Advance(2.1)
    Chat(5, 122)
    Advance(2.1)
    Chat(4, 123)
    Advance(2.1)
    assert(not addon.db.skirmishes and addon.db.unassignedRewards.honor == 14)
    local general = addon.BuildIssueReport(addon.db, NamesInRedDebugDB)
    assert(general:find('"unassignedHonor": 14', 1, true) and general:find("reward-unassigned-skirmish", 1, true))
    assert(not general:find(first.name, 1, true) and not general:find(one, 1, true))
end
Reset()
if not arg[1] or arg[1] == "shared-reward" then
    units.target = first
    Begin()
    Kill(me, first)
    HK()
    Chat(5, 127)
    Chat(4, 128)
    Advance(2.1)
    local battle = assert(addon.db.skirmishes["world:1"])
    local hkCount, honor = addon.Ledger.SkirmishRewards(battle)
    assert(hkCount == 1 and honor == 9 and battle.rewards[one].honor == 0)
    assert(battle.unassignedRewards.honor == 9 and not addon.db.unassignedRewards)
    addon.RecordSkirmish("world:1", battle)
    assert(addon.Ledger.JournalRewards(addon.db).honor == 9)
end
Reset()
if not arg[1] or arg[1] == "nearby-independent" then
    duration = 16
    units.target, units.nameplate1 = first, second
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Begin()
    Advance(5)
    End()
    Advance(1.6)
    Begin()
    Advance(0.8)
    Update(0, 7, 10)
    Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    units.nameplate1 = nil
    Kill(ally, second)
    Advance(1.6)
    Kill(me, first)
    Update(0, 7, 10)
    Link(7, ally, first, 45)
    Advance(6.2)
    End()
    Advance(3)
    local battle = assert(addon.db.skirmishes["world:1"])
    assert(#battle.allies == 1 and #battle.enemies == 1 and #battle.events == 1)
    assert(not addon.db.skirmishes["world:2"])
    local report = addon.BuildIssueReport(addon.db, NamesInRedDebugDB)
    assert(report:find("kill-staged", 1, true))
end
Reset()
if not arg[1] or arg[1] == "diagnostic-scope" then
    units.target = first
    Begin()
    Fire("UNIT_COMBAT", "target", "WOUND", "", 112, 1)
    Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-unconfirmed", 98)
    End()
    Advance(3)
    assert(not addon.db.skirmishes)
    Begin()
    Aura("player", "target")
    Fire("UNIT_COMBAT", "target", "WOUND", "", 99, 1)
    zone = "Another Area"
    Fire("PLAYER_LEAVING_WORLD")
    Fire("UNIT_COMBAT", "target", "WOUND", "", 301, 1)
    End()
    Advance(3)
    local captured = assert(addon.db.skirmishes["world:1"]).combatDiagnostics.windows[1]
    assert(captured.ending == "area-changed" and #captured.streams.unitCombat.rows == 1)
    assert(captured.streams.unitCombat.rows[1].amount == 99)
    assert(not captured.streams.spellCast)
end
Reset()
if not arg[1] or arg[1] == "recap-context" then
    units.target = first
    Begin()
    Aura("player", "target")
    local before = GetServerTime() - 1
    Advance(4)
    localPlayer.dead = true
    recap = {
        { sourceGUID = one, sourceFlags = 0x440, timestamp = GetServerTime(), overkill = 2,
            amount = 105, event = "SPELL_DAMAGE", spellId = 42 },
        { sourceGUID = one, sourceFlags = 0x440, timestamp = GetServerTime() - 1,
            amount = 50, event = "SPELL_PERIODIC_DAMAGE", spellId = 44 },
        { sourceGUID = one, sourceFlags = 0x440, timestamp = before,
            amount = 500, event = "SWING_DAMAGE" },
    }
    Fire("PLAYER_DEAD")
    local captured = assert(addon.db.skirmishes["world:1"]).combatDiagnostics.recaps
    assert(#captured == 2 and captured[1].recapIndex == 2 and captured[1].amount == 50)
    assert(captured[2].recapIndex == 1 and captured[2].amount == 105)
    Fire("PLAYER_DEAD")
    assert(#captured == 2)
end
Reset()
if not arg[1] or arg[1] == "pov-continuation" then
    zone = "Fixture Grove"
    local map = 1
    C_Map = {
        GetBestMapForUnit = function() return map end,
        GetPlayerMapPosition = function() return { GetXY = function() return 0.01, 0.02 end } end,
    }
    units.target, units.nameplate1 = first, second
    Begin()
    Aura("player", "target")
    Aura("party1", "target")
    Aura("player", "nameplate1")
    -- An ordinary map/zone border while active retains the same window.
    zone, map = "Fixture Border", 2
    Fire("ZONE_CHANGED_NEW_AREA")
    Aura("target", "player")
    End()
    Advance(1)
    local fight = assert(addon.db.skirmishes["world:1"])
    assert(fight.personalOutcome.lifecycle == "awaiting" and not fight.personalOutcome.outcome)
    units.target = nil -- stealth / loss of the local target during the gap
    Advance(2)
    units.target = first
    Aura("party1", "target") -- same linked fight is still observed
    Begin()
    Aura("target", "player")
    Advance(1)
    localPlayer.dead = true
    recap = { { sourceGUID = one, sourceName = first.name, sourceFlags = 0x440, timestamp = now, overkill = 1 },
        { sourceGUID = two, sourceFlags = 0x440, timestamp = now - 0.5, amount = 18 } }
    Fire("PLAYER_DEAD")
    End()
    ghost = true
    Fire("PLAYER_ALIVE")
    Advance(8) -- beyond the old five-second bridge limit
    Aura("party1", "target")
    Advance(1)
    localPlayer.dead, ghost = false, false
    Fire("PLAYER_UNGHOST")
    assert(fight.personalOutcome.lifecycle == "awaiting")
    Begin()
    Aura("player", "target")
    Advance(0.6)
    assert(fight.personalOutcome.lifecycle == "active" and not fight.personalOutcome.outcome)
    Kill(me, first)
    End()
    Advance(12.1)
    assert(#fight.observation.segments == 3 and not addon.db.skirmishes["world:2"])
    assert(fight.mapID == 1 and fight.zone == "Fixture Grove" and not fight.observation.visibilityGap)
    assert(#fight.events == 3 and fight.events[2].kind == "revive")
    assert(fight.personalOutcome.outcome == "draw" and fight.personalOutcome.reason == "observed-disengagement")
    assert(fight.personalOutcome.casualties.friendly == 1 and fight.personalOutcome.casualties.enemy == 1)

    -- A revenge engagement at the same site with the same GUID is independent.
    first.dead = false
    Begin()
    Aura("player", "target")
    End()
    Advance(12.1)
    local revenge = assert(addon.db.skirmishes["world:2"])
    assert(revenge.personalOutcome.outcome == "draw" and #revenge.events == 0 and #fight.events == 3)
    C_Map = nil
end

Reset()
if not arg[1] or arg[1] == "pov-observation" then
    units.target, units.party1 = first, friend
    Begin()
    Aura("player", "target")
    Aura("party1", "target")
    Advance(2)
    localPlayer.dead = true
    recap = { { sourceGUID = one, sourceName = first.name, sourceFlags = 0x440, timestamp = now, overkill = 1 } }
    Fire("PLAYER_DEAD")
    End()
    ghost = true
    Fire("PLAYER_ALIVE")
    Advance(6)
    Kill(ally, first) -- linked finish without an intervening aura or meter delta
    Advance(3)
    units.target, units.party1 = nil, nil -- the verified ending survives later loss of coverage
    Advance(9.1)
    local observed = assert(addon.db.skirmishes["world:1"])
    assert(observed.personalOutcome.outcome == "win" and observed.personalOutcome.reason == "enemy-elimination")
end

Reset()
if not arg[1] or arg[1] == "pov-pve" then
    local npc = { id = "Creature-fixture", name = "Mock Creature", faction = "Horde", x = 40 }
    units.target, units.mouseover = first, npc
    Begin()
    Aura("player", "target")
    Aura("player", "mouseover") -- a mixed encounter remains in progress
    End()
    Advance(6)
    local old = assert(addon.db.skirmishes["world:1"])
    assert(old.personalOutcome.lifecycle == "awaiting")
    Begin()
    Aura("player", "mouseover") -- a later local window with verified NPC activity
    Advance(3)
    assert(old.personalOutcome.finalizedBy == "unrelated-pve" and old.personalOutcome.outcome == "draw")
    assert(not addon.db.skirmishes["world:2"])
    End()
    units.mouseover = nil
end

Reset()
if not arg[1] or arg[1] == "pov-feign" then
    units.target, units.nameplate1 = first, second
    second.feignUnavailable = true
    Begin()
    Aura("player", "target")
    Aura("player", "nameplate1")
    second.dead = true
    Fire("UNIT_FLAGS", "nameplate1")
    Advance(0.6)
    units.nameplate1 = first -- this token now belongs to another GUID
    Fire("UNIT_FLAGS", "nameplate1")
    units.nameplate1 = second
    second.dead, second.feignUnavailable, second.feign = false, false, true
    Fire("UNIT_FLAGS", "nameplate1")
    second.dead = true
    Fire("UNIT_FLAGS", "nameplate1")
    Advance(0.6)
    Fire("UNIT_FLAGS", "nameplate1")
    second.feignUnavailable, second.feign = true, false
    Fire("UNIT_FLAGS", "nameplate1")
    Advance(0.6)
    Fire("UNIT_FLAGS", "nameplate1")
    End()
    Advance(12.1)
    local observed = assert(addon.db.skirmishes["world:1"])
    assert(#observed.events == 1 and observed.events[1].source == "corroborated-corpse")
    assert(observed.events[1].targetID == two and not observed.events[1].actorID)
    assert(observed.personalOutcome.outcome == "win" and observed.personalOutcome.casualties.enemy == 1)
    second.feignUnavailable = false
end

Reset()
if not arg[1] or arg[1] == "pov-late" then
    units.target = first
    Begin()
    local window = assert(addon.WorldCombatWindow(now))
    Aura("player", "target")
    Advance(1)
    localPlayer.dead = true
    recap = nil
    Fire("PLAYER_DEAD")
    local deathAt = now
    End()
    Fire("PLAYER_LEAVING_WORLD")
    local previous = assert(addon.db.skirmishes["world:1"])
    assert(previous.personalOutcome.outcome == "unknown" and previous.personalOutcome.boundary == "left-world")
    localPlayer.dead = false
    Begin()
    Aura("player", "target")
    recap = { { sourceGUID = one, sourceName = first.name, sourceFlags = 0x440, timestamp = deathAt, overkill = 2 } }
    Advance(0.4)
    End()
    Advance(11)
    local current = assert(addon.db.skirmishes["world:2"])
    assert(previous.personalOutcome.outcome == "loss" and #previous.events == 1 and #current.events == 0)
    assert(not addon.WorldCanObserveMeter(window))
    local currentWindow = assert(addon.WorldCombatWindow(now - 11.4))
    addon.WorldMeterObservation(currentWindow, "linked-increase", me, one)
    Advance(1.1)
    assert(current.personalOutcome.lifecycle == "finalized" and current.personalOutcome.outcome == "draw")
end

Reset()
if not arg[1] or arg[1] == "pov-life-evidence" then
    local npc = { id = "Creature-fixture-caster", name = "Mock Creature", faction = "Alliance" }
    units.target, units.nameplate1, units.mouseover = first, second, npc
    first.feignUnavailable = true
    Begin()
    Aura("player", "target")
    Aura("nameplate1", "player") -- linked opponent, with no opposing player action on this victim
    Advance(13) -- the first aura is too old to explain the corpse
    Aura("player", "target")
    Advance(1)
    first.dead = true
    Fire("UNIT_FLAGS", "target")
    Advance(0.6)
    Fire("UNIT_FLAGS", "target")
    Fire("UNIT_FLAGS", "target")
    Advance(1)
    first.dead = false
    Fire("UNIT_FLAGS", "target")
    Advance(0.2)
    Aura("player", "target")
    Advance(1)
    first.feignUnavailable = false
    Kill(me, first)
    Fire("PARTY_KILL", me, one)

    Aura("mouseover", "nameplate1")
    second.dead = true
    Fire("UNIT_FLAGS", "nameplate1")
    End()
    Advance(12.1)
    local fight = assert(addon.db.skirmishes["world:1"])
    assert(#fight.events == 4 and fight.events[1].source == "corroborated-corpse" and not fight.events[1].actorID)
    assert(fight.events[2].kind == "revive" and fight.events[2].targetID == one)
    assert(fight.events[3].kind == "kill" and fight.events[3].targetID == one)
    assert(fight.events[4].kind == "death" and fight.events[4].targetID == two)
    assert(fight.personalOutcome.casualties.enemy == 2, "the middle aura should qualify the corpse in the first life")
    local action = fight.observation.segments[1].actions[1]
    assert(action.count == 3 and action.first == 0 and action.intermediateOffsets[1] == 13
        and not action.intermediateOffsets[2] and action.last > fight.events[2].offset)
    addon.ClearDiagnostics()
    addon.Ledger.Open(addon.db)
    assert(addon.EvaluatePersonalSkirmish(fight).casualties.enemy == 2)
    first.feignUnavailable = false
end

for _, readable in ipairs({ true, false }) do
    Reset()
    if not arg[1] or arg[1] == "pov-sampled-revival" then
        units.target = first
        Begin()
        Aura("player", "target")
        Aura("party1", "target")
        Advance(1)
        Kill(me, first)
        End()
        Advance(9)
        first.dead = false
        if not readable then units.target = second end -- the same token now refers to a different GUID
        Advance(1.2) -- the first late sample at +10s, with no UNIT_FLAGS or target events
        local fight = assert(addon.db.skirmishes["world:1"])
        assert(#fight.events == (readable and 2 or 1), "commit a verified revival when it is sampled")
        units.target = first
        Kill(ally, first)
        Fire("PARTY_KILL", ally, one)
        assert(#fight.events == (readable and 3 or 1), "only an observed return permits another kill")
        if readable then
            assert(fight.events[2].kind == "revive" and fight.events[2].source == "terminal-sample")
            assert(fight.events[3].actorID == ally and fight.events[3].targetID == one)
            assert(fight.events[2].offset < fight.events[3].offset and fight.personalOutcome.lifecycle == "awaiting")
        end
        Advance(12.1)
        assert(fight.personalOutcome.casualties.enemy == (readable and 2 or 1))
        assert(not addon.db.skirmishes["world:2"])
    end
end

Reset()
if not arg[1] or arg[1] == "pov-sampled-death" then
    units.target, units.nameplate1, units.party1 = first, second, nil
    second.dead = true -- already-dead bystander
    Begin()
    Aura("player", "target")
    End()
    Advance(0.25)
    first.dead = true -- no kill, flags, target or nameplate event
    Advance(0.6)
    local fight = assert(addon.db.skirmishes["world:1"])
    assert(#fight.events == 1, "a definitive scheduled corpse read must immediately record the death")
    local death = fight.events[1]
    assert(death.kind == "death" and death.targetID == one and death.source == "terminal-sample" and not death.actorID)
    assert(fight.personalOutcome.lifecycle == "awaiting")
    Advance(12)
    assert(#fight.events == 1 and #fight.enemies == 1)
    assert(fight.personalOutcome.outcome == "win" and fight.personalOutcome.reason == "enemy-elimination")
    assert(fight.personalOutcome.casualties.enemy == 1)
    addon.ClearDiagnostics()
    addon.Ledger.Open(addon.db)
    assert(fight.events[1] == death and addon.EvaluatePersonalSkirmish(fight).casualties.enemy == 1)
end

Reset()
if not arg[1] or arg[1] == "pov-sampled-death" then
    local npc = { id = "Creature-fixture-caster", name = "Mock Creature", faction = "Alliance" }
    units.target, units.nameplate1, units.mouseover = first, second, npc
    Begin()
    Aura("player", "target")
    Aura("party1", "target")
    Aura("nameplate1", "player") -- linked opponent with no opposed action on this victim
    End()
    Advance(0.25)
    first.dead = true
    second.dead, second.feign = true, true
    Advance(3)
    local fight = assert(addon.db.skirmishes["world:1"])
    assert(#fight.events == 1 and fight.events[1].targetID == one, "Feign Death must not produce a life event")
    first.dead = false
    Advance(7)
    assert(#fight.events == 2 and fight.events[2].kind == "revive" and fight.events[2].targetID == one)
    Aura("party1", "target") -- a second timed PvP link in the new life
    Advance(0.25)
    second.dead, second.feign = false, false
    Aura("mouseover", "nameplate1")
    first.dead, second.dead = true, true
    Advance(12.1)
    assert(#fight.events == 4 and not addon.db.skirmishes["world:2"])
    local deaths = {}
    for _, event in ipairs(fight.events) do
        if event.kind == "death" then
            assert(event.source == "terminal-sample" and not event.actorID)
            deaths[event.targetID] = (deaths[event.targetID] or 0) + 1
        end
    end
    assert(deaths[one] == 2 and deaths[two] == 1)
    assert(fight.personalOutcome.outcome == "win" and fight.personalOutcome.reason == "observed-disengagement")
    assert(fight.personalOutcome.casualties.enemy == 2, "the unrelated NPC death is a life event, not a PvP casualty")
end

for _, scenario in ipairs({
    { pause = 4.9, opponentStillFighting = true, continues = true },
    { pause = 4.9, opponentStillFighting = false, continues = false },
    { pause = 5.1, opponentStillFighting = true, continues = false },
}) do
    Reset()
    if not arg[1] or arg[1] == "pov-solo-stealth" then
        units.target, units.party1 = first, nil
        Begin()
        Aura("player", "target")
        first.active = scenario.opponentStillFighting
        End()
        units.target = nil -- no allied bridge and no visible foe during the pause
        Advance(scenario.pause)
        local original = assert(addon.db.skirmishes["world:1"])
        assert(original.personalOutcome.lifecycle == "awaiting") -- inside the 12s settlement even after 5s
        units.target = first
        Begin()
        Aura("player", "target")
        first.active = false
        End()
        Advance(12.1)
        local nextFight = addon.db.skirmishes["world:2"]
        if scenario.continues then
            assert(#original.observation.segments == 2 and not nextFight)
            assert(original.personalOutcome.outcome == "draw")
        else
            assert(#original.observation.segments == 1 and nextFight and #nextFight.observation.segments == 1)
            assert(original.personalOutcome.finalizedBy == "independent-engagement")
        end
    end
end

Reset()
if not arg[1] or arg[1] == "rival-meter-healer" then
    duration = 10
    units.target, units.nameplate1 = first, second
    Begin()
    Advance(1)
    Link(2, me, friend, 87)
    Link(0, ally, first, 420)
    -- Seven rejected rows keep the only valid healing detail out of the
    -- bounded technical sample, but it still goes through meter validation.
    local heal = sources[2][me][1].combatSpellDetails
    local details = {}
    for i = 1, 7 do
        details[i] = { unitName = friend.name, unitClassFilename = friend.class, isPet = false, isMob = false, amount = 0 }
    end
    details[8] = heal
    sources[2][me][1].combatSpellDetails = details
    Update(0, 2, 7, 10)
    Advance(8)
    Kill(ally, first)
    Advance(1)
    End()
    Advance(3)
    local fight = assert(addon.db.skirmishes["world:1"])
    local phase = fight.observation.segments[1]
    assert(#phase.contributionLinks == 2 and #phase.combatAggregates == 1)
    local credit = assert(addon.EvaluateRivalContributions(fight).credits[1])
    assert(credit.rivalID == one and credit.evidence.kind == "support" and credit.evidence.viaID == ally)
    assert(addon.Ledger.RivalContributionScore(addon.db, one) == 1)
    assert(addon.Ledger.PersonalCombatScore(addon.db, one) == 0)
    assert(addon.Ledger.RivalContributionScore(addon.db, two) == 0)
    fight.combatDiagnostics = nil
    addon.ClearDiagnostics()
    addon.Ledger.Open(addon.db)
    assert(addon.Ledger.RivalContributionScore(addon.db, one) == 1)
end

Reset()
if not arg[1] or arg[1] == "rival-restricted-healer" then
    duration = 10
    units.target = first
    Begin()
    Advance(1)
    local secret = {}
    function issecretvalue(value) return rawequal(value, secret) end
    Link(2, me, friend, 87)
    sources[2][me][1].combatSpellDetails.unitName = secret
    sources[2][me][2] = { combatSpellDetails = { unitName = friend.name, unitClassFilename = friend.class,
        isPet = false, isMob = false, amount = math.huge } }
    Link(0, ally, first, 420)
    Update(0, 2, 7, 10)
    Advance(8)
    Kill(ally, first)
    Advance(1)
    End()
    Advance(3)
    local fight = assert(addon.db.skirmishes["world:1"])
    assert(#fight.observation.segments[1].contributionLinks == 1)
    assert(#addon.EvaluateRivalContributions(fight).credits == 0)
    issecretvalue = nil
end

Reset()
if not arg[1] or arg[1] == "rival-recap" then
    units.target, units.nameplate1 = first, second
    Begin()
    Aura("player", "target")
    Advance(4)
    local deathAt = GetServerTime()
    local third, early = "Player-fixture-third", "Player-fixture-earlier"
    recap = {
        { sourceGUID = one, sourceFlags = 0x440, timestamp = deathAt, overkill = 2, amount = 77, event = "SPELL_DAMAGE" },
        { sourceGUID = two, sourceFlags = 0x440, timestamp = deathAt - 1, amount = 25, event = "SWING_DAMAGE" },
        { sourceGUID = third, sourceFlags = 0x440, timestamp = deathAt - 2, amount = 15, event = "SPELL_DAMAGE" },
        { sourceGUID = early, sourceFlags = 0x440, timestamp = deathAt - 7, amount = 51, event = "SPELL_DAMAGE" },
    }
    localPlayer.dead = true
    Fire("PLAYER_DEAD")
    Fire("PLAYER_DEAD")
    End()
    Advance(3)
    local fight = assert(addon.db.skirmishes["world:1"])
    assert(#fight.events == 1 and fight.events[1].recapDamage[two] == deathAt - 1)
    local lostTo = {}
    for _, credit in ipairs(addon.EvaluateRivalContributions(fight).credits) do
        assert(credit.direction == "loss" and credit.deathIndex == 1)
        lostTo[credit.rivalID] = credit.evidence.kind
    end
    assert(lostTo[one] == "finishing-blow" and lostTo[two] == "recap-damage" and lostTo[third] == "recap-damage")
    assert(not lostTo[early] and select(2, addon.Ledger.PersonalCombatScore(addon.db, two)) == 0)
    fight.combatDiagnostics = nil
    addon.Ledger.Open(addon.db)
    assert(#addon.EvaluateRivalContributions(fight).credits == 3)
end

Reset()
if not arg[1] or arg[1] == "rival-unknown-finisher" then
    units.target, units.nameplate1 = first, second
    Begin()
    Aura("target", "player")
    Advance(2)
    local secret = {}
    function issecretvalue(value) return rawequal(value, secret) end
    local stamp = GetServerTime()
    recap = {
        { sourceGUID = secret, sourceFlags = 0x440, timestamp = stamp, overkill = 1, amount = 70, event = "SPELL_DAMAGE" },
        { sourceGUID = one, sourceFlags = 0x440, timestamp = stamp - 1, amount = 27, event = "SPELL_DAMAGE" },
    }
    localPlayer.dead = true
    Fire("PLAYER_DEAD")
    local fight = assert(addon.db.skirmishes["world:1"])
    assert(#fight.events == 1 and fight.events[1].kind == "death" and not fight.events[1].actorID)
    local deathOffset = fight.events[1].offset
    local credit = assert(addon.EvaluateRivalContributions(fight).credits[1])
    assert(credit.rivalID == one and credit.direction == "loss" and credit.evidence.kind == "recap-damage")
    assert(select(2, addon.Ledger.PersonalCombatScore(addon.db, one)) == 0)
    Advance(0.5) -- the first retry finds the same unnamed death
    assert(#fight.events == 1)
    recap[3] = { sourceGUID = two, sourceFlags = 0x440, timestamp = stamp - 1, amount = 10, event = "SWING_DAMAGE" }
    Fire("PLAYER_DEAD") -- same native stamp, different local observation time
    assert(#fight.events == 1 and fight.events[1].offset == deathOffset and fight.events[1].recapDamage[two] == stamp - 1)
    recap[1].sourceGUID = two
    recap[2], recap[3] = nil, nil -- keep earlier damage evidence across the upgrade
    Advance(0.6)
    assert(#fight.events == 1 and fight.events[1].kind == "kill" and fight.events[1].actorID == two)
    assert(fight.events[1].offset == deathOffset and fight.events[1].recapDamage[one] == stamp - 1)
    assert(#addon.EvaluateRivalContributions(fight).credits == 2)
    End()
    issecretvalue = nil
end

Reset()
if not arg[1] or arg[1] == "rival-meter-corpse" then
    duration = 10
    units.target, units.nameplate1 = first, second
    Begin()
    Aura("nameplate1", "player") -- a different opponent survives the ending
    Advance(1)
    Link(0, me, first, 100)
    Update(0, 2, 7, 10)
    Advance(9)
    End()
    first.dead = true -- only scheduled life reads see this death
    Advance(12.1)
    local fight = assert(addon.db.skirmishes["world:1"])
    local death = assert(fight.events[1])
    assert(#fight.events == 1 and death.kind == "death" and death.targetID == one and not death.actorID)
    assert(fight.personalOutcome.casualties.enemy == 1 and fight.personalOutcome.outcome == "win")
    assert(fight.personalOutcome.reason == "observed-disengagement")
    local credits = addon.EvaluateRivalContributions(fight).credits
    assert(#credits == 1 and credits[1].rivalID == one and credits[1].evidence.kind == "meter")
    addon.ClearDiagnostics()
    addon.Ledger.Open(addon.db)
    assert(fight.personalOutcome.casualties.enemy == 1 and addon.Ledger.RivalContributionScore(addon.db, one) == 1)
end

for _, knownSecond in ipairs({ false, true }) do
    Reset()
    if not arg[1] or arg[1] == "rival-distinct-recaps" then
        units.target, units.nameplate1 = first, second
        local secret = {}
        function issecretvalue(value) return rawequal(value, secret) end
        Begin()
        Aura("target", "player")
        Advance(4)
        local stamp = GetServerTime()
        local initial = {
            { sourceGUID = secret, sourceFlags = 0x440, timestamp = stamp, overkill = 1, event = "SPELL_DAMAGE" },
            { sourceGUID = one, sourceFlags = 0x440, timestamp = stamp - 1, amount = 10, event = "SPELL_DAMAGE" },
        }
        localPlayer.dead, recap = true, initial
        Fire("PLAYER_DEAD")
        local fight = assert(addon.db.skirmishes["world:1"])
        local firstDeath = fight.events[1]
        assert(firstDeath.kind == "death" and not firstDeath.actorID)
        Advance(2)
        localPlayer.dead = false -- the actual return did not emit a retained life transition
        Advance(0.1)
        local secondStamp = GetServerTime()
        local later = {
            { sourceGUID = knownSecond and two or secret, sourceFlags = 0x440, timestamp = secondStamp,
                overkill = 1, event = "SPELL_DAMAGE" },
            { sourceGUID = two, sourceFlags = 0x440, timestamp = secondStamp - 1, amount = 20, event = "SPELL_DAMAGE" },
        }
        localPlayer.dead, recap = true, later
        Fire("PLAYER_DEAD")
        assert(#fight.events == 2 and fight.events[1] == firstDeath,
            "a distinct validated native recap must preserve the first unknown-finisher death")
        assert(fight.events[2].kind == (knownSecond and "kill" or "death"))
        assert(fight.events[1].recapDamage[one] == stamp - 1 and not fight.events[1].recapDamage[two])
        assert(fight.events[2].recapDamage[two] == secondStamp - 1 and not fight.events[2].recapDamage[one])
        recap = initial -- outdated but still inside the native clock tolerance
        Fire("PLAYER_DEAD")
        recap = later
        Fire("PLAYER_DEAD") -- exact repeat of the second recap
        Advance(2.1)
        assert(#fight.events == 2 and fight.events[1] == firstDeath)
        End()
        Advance(12.1)
        local credits = addon.EvaluateRivalContributions(fight).credits
        assert(#credits == 2 and credits[1].rivalID == one and credits[2].rivalID == two)
        assert(credits[1].deathIndex == 1 and credits[2].deathIndex == 2)
        assert(fight.personalOutcome.casualties.friendly == 2 and fight.personalOutcome.outcome == "loss")
        assert(not addon.db.skirmishes["world:2"])
        issecretvalue = nil
    end
end

Reset()
if not arg[1] or arg[1] == "rival-pet-control" then
    local pet = { id = "Pet-fixture-local", name = "Mock Pet", faction = "Alliance" }
    units.target, units.nameplate1, units.pet = first, second, pet
    Begin()
    Aura("pet", "target")
    Aura("nameplate1", "pet") -- enemy has affected our pet, with no proof against its owner
    Advance(2)
    Kill(ally, first)
    local stamp = GetServerTime()
    recap = { { sourceGUID = two, sourceFlags = 0x440, timestamp = stamp, overkill = 1, event = "SPELL_DAMAGE" } }
    localPlayer.dead = true
    Fire("PLAYER_DEAD")
    End()
    Advance(3)
    local credits = addon.EvaluateRivalContributions(assert(addon.db.skirmishes["world:1"])).credits
    assert(#credits == 2 and credits[1].rivalID == one and credits[1].evidence.petEndpoint == "actor")
    assert(credits[2].rivalID == two and credits[2].evidence.kind == "finishing-blow")
    units.pet = nil
end

-- world:16-shaped Forever capture, with variants that change a single
-- piece of the incoming evidence or the lethal recap.
local revision = ("ab"):rep(20)
C_AddOns = { GetAddOnMetadata = function(_, key)
    if key == "X-Preview-Revision" then return revision end
    if key == "Version" then return "1.1.0" end
end }

local function World16(scenario)
    Reset()
    units.target, units.party1 = first, nil
    first.class, first.active = "WARLOCK", true
    duration = 25.002
    addon.db.encounterSequence = 15
    local pet = { id = "Pet-fixture-warlock", name = "Mock Demon", faction = "Horde" }
    if scenario.pet then
        units.nameplate1 = pet
        function UnitIsOwnerOrControllerOfUnit(owner, controlled)
            return scenario.verifiedPet and owner == "target" and controlled == "nameplate1"
        end
    end
    if scenario.npcAura then
        units.mouseover = { id = "Creature-fixture-mob", name = "Mock Creature", faction = "Horde" }
    end
    Begin()
    if scenario.pet then Fire("NAME_PLATE_UNIT_ADDED", "nameplate1") end
    Advance(23.829)
    Fire("UNIT_COMBAT", "player", "WOUND")
    Advance(0.407)
    Fire("UNIT_COMBAT", "player", "WOUND")
    if scenario.npcAura then Aura("mouseover", "player") end
    if scenario.pet then
        Link(0, pet.id, localPlayer, 716)
        Link(2, me, localPlayer, 15)
        -- Keep a card via outgoing damage; this cannot qualify our death.
        Link(10, one, localPlayer, 100)
    else
        Link(7, me, first, 716)
    end
    if scenario.mixed then
        local taken = sources[7][me][1].combatSpellDetails
        sources[7][me][1].combatSpellDetails = { taken, {
            unitName = "Mock Creature", isMob = true, isPet = false, amount = 50,
        } }
    end
    Update(0, 7, 10, 2)
    Advance(0.766)
    localPlayer.dead = true
    local stamp = GetServerTime()
    if scenario.staleNPC then addon.db.lastDeathTimestamp = stamp end
    if not scenario.lateNPC then
        recap = { { sourceGUID = (scenario.npc or scenario.staleNPC) and "Creature-private" or nil,
            timestamp = stamp, overkill = 1, event = scenario.environment and "ENVIRONMENTAL_DAMAGE" or "SPELL_DAMAGE" } }
    end
    Fire("PLAYER_DEAD")
    End()
    Advance(1.3)
    local fight = assert(addon.db.skirmishes["world:16"])
    local segment = fight.observation.segments[1]
    assert(fight.personalOutcome.lifecycle == "awaiting" and fight.captureRevision == revision)
    addon.Ledger.RivalContributionScore(addon.db, one) -- warm the index before settlement
    if scenario.lateNPC then
        addon.RecordSkirmish("world:16", fight)
        local _, provisional = addon.Ledger.RivalContributionScore(addon.db, one)
        assert(provisional == 1)
        recap = { { sourceGUID = "Creature-private", timestamp = stamp, overkill = 1, event = "SPELL_DAMAGE" } }
        Advance(0.8)
        local _, corrected = addon.Ledger.RivalContributionScore(addon.db, one)
        assert(corrected == 0)
    end
    units.target, units.nameplate1 = nil, nil
    Advance(2)
    local outside = IsInInstance
    function IsInInstance() return true, "party" end
    Fire("ZONE_CHANGED_NEW_AREA")
    IsInInstance = outside
    local expected = scenario.loss and 1 or 0
    assert(fight.personalOutcome.outcome == (scenario.loss and "loss" or "unknown"))
    assert(fight.personalOutcome.casualties.friendly == expected and fight.personalOutcome.casualties.enemy == 0)
    assert(fight.personalOutcome.finalizedBy == "area-changed")
    assert(#fight.events == 1 and fight.events[1].kind == "death" and not fight.events[1].actorID)
    assert(not fight.rosterComplete)
    local wins, losses = addon.Ledger.RivalContributionScore(addon.db, one)
    assert(wins == 0 and losses == expected)
    local summary = addon.Ledger.RivalSkirmishes(addon.db, one)[1]
    assert(summary.contributionWins == 0 and summary.contributionLosses == expected)
    local kills, direct = addon.Ledger.PersonalCombatScore(addon.db, one)
    assert(kills == 0 and direct == 0)
    if not scenario.pet then
        local link = assert(segment.contributionLinks[1])
        assert(link.category == "DamageTaken" and link.actorID == one and link.targetID == me)
    elseif scenario.loss then
        local credit = addon.Ledger.SkirmishContributionEvidence(addon.db, "world:16", fight).credits[1]
        assert(credit.evidence.petEndpoint == "actor" and credit.evidence.category == "DamageDone")
    end
    if scenario.mixed then assert(segment.localNpcDamage == true) end
    if scenario.npcAura then assert(segment.localNpcPressure == true) end
    local report = addon.BuildIssueReport(addon.db, nil, "world:16")
    for _, key in ipairs({ "previewRevision", "captureRevision", "participation", "contributionLink", "deathEpisode" }) do
        assert(report:find('"' .. key .. '"', 1, true), key)
    end
    assert(report:find(revision, 1, true) and not report:find(one, 1, true) and not report:find("Creature-private", 1, true))
    assert(report:find('"' .. scenario.qualification .. '"', 1, true))
    if scenario.loss then
        assert(report:find('"deathIndex": 1', 1, true) and report:find('"localDeathWitness"', 1, true))
    end

    -- The opponent's later death is outside our finalized observation.
    Kill(ally, first)
    ghost = true
    Fire("PLAYER_ALIVE")
    Advance(1)
    ghost, localPlayer.dead = false, false
    Fire("PLAYER_UNGHOST")
    assert(#fight.events == 1 and not addon.db.skirmishes["world:17"])
    first.class, first.active, first.dead = "MAGE", nil, nil
    UnitIsOwnerOrControllerOfUnit = nil
end

if not arg[1] or arg[1] == "world16" then
    World16({ loss = true, qualification = "terminal-incoming-damage" })
    World16({ npc = true, qualification = "non-pvp-lethal" })
    World16({ lateNPC = true, qualification = "non-pvp-lethal" })
    World16({ environment = true, qualification = "non-pvp-lethal" })
    World16({ mixed = true, qualification = "mixed-incoming-damage" })
    World16({ npcAura = true, qualification = "mixed-incoming-damage" })
    World16({ staleNPC = true, loss = true, qualification = "terminal-incoming-damage" })
    World16({ pet = true, verifiedPet = true, loss = true, qualification = "terminal-incoming-damage" })
    World16({ pet = true, qualification = "no-qualified-incoming-damage" })
end

if not arg[1] or arg[1] == "pet-recap" then
    for _, scenario in ipairs({
        { expected = true }, { expected = true, owner = true }, { expected = true, onlyPet = true },
        { expected = false, flags = 0x1248 }, { expected = false, flags = 0x1118 },
        { expected = false, flags = 0x1188 }, { expected = false, npc = true },
        { expected = false, environment = true },
    }) do
        Reset()
        units.party1, units.target = nil, first
        local pet = { id = "Pet-fixture-recap", name = "Mock Demon", faction = "Horde" }
        units.nameplate1, units.mouseover = pet, second
        function UnitIsOwnerOrControllerOfUnit(owner, controlled)
            return scenario.owner and owner == "mouseover" and controlled == "nameplate1"
        end
        Begin()
        Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
        -- Keep a PvP record in the negative cases so a rejected recap
        -- cannot silently become a rival loss via the tracked opponent.
        if not scenario.expected then Aura("player", "target") end
        Advance(5)
        localPlayer.dead = true
        local stamp = GetServerTime()
        recap = {
            { sourceGUID = scenario.npc and "Creature-fixture" or pet.id, sourceFlags = scenario.flags or 0x1148,
                timestamp = stamp, currentHP = 12, amount = 56, overkill = 44,
                event = scenario.environment and "ENVIRONMENTAL_DAMAGE" or "SWING_DAMAGE" },
        }
        if not scenario.onlyPet then
            recap[2] = { sourceGUID = one, sourceFlags = 0x10548, timestamp = stamp - 0.75,
                event = "SPELL_PERIODIC_DAMAGE", amount = 80 }
        end
        Fire("PLAYER_DEAD")
        Fire("PLAYER_DEAD")
        End()
        Advance(13)
        local fight = assert(addon.db.skirmishes["world:1"])
        local death = assert(fight.events[1])
        assert(#fight.events == 1 and death.kind == "death" and not death.actorID)
        if scenario.expected then
            assert(fight.personalOutcome.outcome == "loss" and fight.personalOutcome.casualties.friendly == 1)
            assert(death.petFinisher.sourceID == pet.id and death.petFinisher.overkill == 44)
            assert(death.petFinisher.ownerID == (scenario.owner and two or nil))
            local report = addon.BuildIssueReport(addon.db, nil, "world:1")
            assert(report:find('"finisher": "pet"', 1, true) and not report:find(pet.id, 1, true))
            if not scenario.onlyPet then
                assert(death.recapDamage[one] == stamp - 0.75)
                local wins, losses = addon.Ledger.RivalContributionScore(addon.db, one)
                assert(wins == 0 and losses == 1)
            end
            local _, ownerLosses = addon.Ledger.RivalContributionScore(addon.db, two)
            assert(ownerLosses == (scenario.owner and 1 or 0))
            local _, ownerDirect = addon.Ledger.PersonalCombatScore(addon.db, two)
            assert(ownerDirect == 0)
            addon.ClearDiagnostics()
            addon.Ledger.Open(addon.db)
            assert(fight.personalOutcome.outcome == "loss" and #fight.events == 1 and fight.events[1].petFinisher)
        else
            assert(not death.petFinisher and fight.personalOutcome.casualties.friendly == 0)
            local _, losses = addon.Ledger.RivalContributionScore(addon.db, one)
            assert(losses == 0)
        end
        UnitIsOwnerOrControllerOfUnit = nil
    end
end

if not arg[1] or arg[1] == "pet-recap" then
    Reset()
    units.party1, units.target = nil, first
    Begin()
    Advance(5)
    for life = 1, 2 do
        localPlayer.dead = true
        local stamp = GetServerTime()
        recap = {
            { sourceGUID = "Pet-repeat-fixture", sourceFlags = 0x1148, timestamp = stamp,
                currentHP = 12, amount = 56, overkill = 44, event = "SWING_DAMAGE" },
            { sourceGUID = one, sourceFlags = 0x10548, timestamp = stamp - 0.75,
                event = "SPELL_PERIODIC_DAMAGE", amount = 80 },
        }
        Fire("PLAYER_DEAD")
        if life == 1 then
            Advance(2)
            localPlayer.dead = false
            Fire("PLAYER_UNGHOST")
            Advance(3)
        end
    end
    End()
    Advance(13)
    local fight = assert(addon.db.skirmishes["world:1"])
    assert(#fight.events == 3 and fight.events[2].kind == "revive")
    assert(fight.events[1].petFinisher and fight.events[3].petFinisher)
    assert(fight.personalOutcome.casualties.friendly == 2)
    local wins, losses = addon.Ledger.RivalContributionScore(addon.db, one)
    assert(wins == 0 and losses == 2)
end

-- Synthetic store tests for raw diagnostic matching. These exercise
-- migration gates independently of the owner-provided encounter data.
if not arg[1] or arg[1] == "legacy-pet-recap" then
    local terminalLocalDeath = dofile("tests/fixtures/terminal-local-death.lua")
    local function LegacyRecap()
        local battle, segment, death = terminalLocalDeath(me, one)
        local journal = addon.Ledger.Open()
        addon.Ledger.Add(journal, one, "Mock Warlock")
        addon.Ledger.Add(journal, two, "Mock Rogue")
        battle.enemies[2] = { id = two, rivalID = two }
        journal.skirmishes = { ["world:508"] = battle }
        battle.zone, death.source = "Fixture Grove", "player-dead"
        segment.reportMeter = { session = 8, combatSequence = 4, time = 125, uptime = 542.502 }
        segment.combatAggregates = nil -- this suite isolates native recap recovery
        local source = "Pet-fixture-legacy"
        local signal = { kind = "PLAYER_DEAD", session = 8, combatSequence = 4, deathSequence = 3,
            time = 125, uptime = 542.502, instanceType = "none", zone = battle.zone,
            player = { guid = me, dead = true } }
        local function Read(delay)
            return { kind = "RECAP", session = 8, combatSequence = 4, deathSequence = 3, delay = delay,
                time = 125, uptime = 542.502 + delay, instanceType = "none", zone = battle.zone,
                status = { events = "readable" }, events = {
                    { sourceGUID = source, sourceFlags = 0x1148, timestamp = 125.75, overkill = 40, amount = 50,
                        currentHP = 10, event = "SWING_DAMAGE", status = { row = "readable" } },
                    { sourceGUID = one, sourceFlags = 0x10548, timestamp = 125.25, amount = 80,
                        event = "SPELL_PERIODIC_DAMAGE", status = { row = "readable" } },
                } }
        end
        local combatEnd = { kind = "COMBAT_END", session = 8, combatSequence = 4, time = 125,
            uptime = 542.502, instanceType = "none", zone = battle.zone,
            petOwners = { [source] = { [two] = true } },
            contacts = { [two] = { latest = { guid = two, isPlayer = true, opponent = true } } } }
        return journal, battle, { version = 1, rows = { signal, Read(0), Read(0.3), combatEnd } }, death
    end

    local journal, fight, log, rawDeath = LegacyRecap()
    assert(fight.personalOutcome.version == 3)
    addon.Ledger.Open(journal) -- migration can first see an archive without its diagnostics
    assert(fight.personalOutcome.version == 4 and addon.Ledger.JournalOutcome(fight) == "unknown")
    local function Losses(rival)
        local wins, losses = addon.Ledger.RivalContributionScore(journal, rival)
        assert(wins == 0)
        return losses
    end
    assert(Losses(one) == 0)
    for _ = 1, 2 do
        assert(addon.Ledger.Open(journal, log) == journal)
        local proof = assert(fight.recoveredDeathRecaps[1])
        assert(#fight.events == 1 and fight.events[1] == rawDeath and not rawDeath.recapTimestamp)
        assert(proof.petFinisher.ownerID == two and proof.recapDamage[one] == 125.25)
        assert(addon.Ledger.JournalOutcome(fight) == "loss" and Losses(one) == 1 and Losses(two) == 1)
        assert(addon.Ledger.PersonalCombatScore(journal, one) == 0)
    end
    addon.Ledger.Open(journal)
    assert(Losses(one) == 1)

    for _, change in ipairs({
        function(_, log) log.rows[1].player.guid = ally end,
        function(_, log) log.rows[1].session = 9 end,
        function(_, log) log.rows[1].combatSequence = 5 end,
        function(_, log) log.rows[1].uptime = 550 end,
        function(_, log) log.rows[2].deathSequence, log.rows[3].deathSequence = 2, 2 end,
        function(_, log) log.rows[3].events[1].timestamp = 125.875 end,
        function(_, log) log.rows[3].events[1].sourceGUID = "Creature-fixture" end,
        function(battle) battle.observation.segments[2] = battle.observation.segments[1] end,
        function(_, _, journal) journal.skirmishes["world:509"] = journal.skirmishes["world:508"] end,
    }) do
        journal, fight, log = LegacyRecap()
        change(fight, log, journal)
        addon.Ledger.Open(journal, log)
        assert(not fight.recoveredDeathRecaps and addon.Ledger.JournalOutcome(fight) == "unknown" and Losses(one) == 0)
    end
    journal, fight, log = LegacyRecap()
    log.rows[4].petOwners["Pet-fixture-legacy"][one] = true
    addon.Ledger.Open(journal, log)
    assert(fight.recoveredDeathRecaps[1].petFinisher.ownerID == nil)
    assert(Losses(one) == 1 and Losses(two) == 0)
end

-- The owner's original pre-offset record and its retained native reads.
if not arg[1] or arg[1] == "world16-original" then
    local journal, log = dofile("tests/fixtures/world16-anonymized.lua")
    local ledger = addon.Ledger
    local id = "world:16"
    local battle = journal.skirmishes[id]
    local rivalID = battle.enemies[1].rivalID
    local event = battle.events[1]
    local segment = battle.observation.segments[1]
    local old = battle.personalOutcome
    assert(old.version == 3 and old.outcome == "unknown" and event.source == "PLAYER_DEAD")
    assert(not segment.offset and not segment.contributionLinks and not battle.observation.participation)
    assert(not battle.rewards and #segment.combatAggregates == 6)

    assert(ledger.Open(journal) == journal)
    assert(battle.personalOutcome ~= old and battle.personalOutcome.version == 4)
    assert(ledger.JournalOutcome(battle) == "loss")
    local warm = ledger.SkirmishContributionEvidence(journal, id, battle)
    assert(warm.credits[1].evidence.kind == "meter")

    local proof
    for _ = 1, 2 do
        assert(ledger.Open(journal, log) == journal)
        assert(ledger.JournalOutcome(battle) == "loss")
        assert(battle.personalOutcome.casualties.friendly == 1 and battle.personalOutcome.casualties.enemy == 0)
        assert(#battle.events == 1 and battle.events[1] == event and not event.actorID and not event.recapTimestamp)
        assert(not segment.offset and not battle.rewards)
        proof = proof or battle.recoveredDeathRecaps[1]
        assert(battle.recoveredDeathRecaps[1] == proof and not battle.recoveredDeathRecaps[2])
        local pet = proof.petFinisher
        assert(pet.sourceID == "Pet-1" and pet.flags == 4424 and pet.effect == "SWING_DAMAGE")
        assert(pet.timestamp == 1795547079.822 and pet.amount == 56 and pet.currentHP == 12 and pet.overkill == 44)
        assert(not pet.ownerID and proof.recapDamage[rivalID] == 1795547079.056)
        local wins, losses = ledger.RivalContributionScore(journal, rivalID)
        assert(wins == 0 and losses == 1)
        local projection = ledger.SkirmishContributionEvidence(journal, id, battle)
        assert(projection ~= warm and #projection.credits == 1 and projection.credits[1].evidence.kind == "recap-damage")
        local kills, directDeaths = ledger.PersonalCombatScore(journal, rivalID)
        assert(kills == 0 and directDeaths == 0)
    end
    ledger.Open(journal)
    assert(battle.recoveredDeathRecaps[1] == proof and ledger.JournalOutcome(battle) == "loss")
    local cards, refs = addon.RecentSkirmishes(journal, 100)
    assert(cards[1] == battle and refs[battle] == id)
    print("Original world:16 replay recovered one pet lethal and one rival loss across reloads")
end

print("Anonymized Gnomeregan event replays passed")
