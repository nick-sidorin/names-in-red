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

for _, file in ipairs({ "Locale", "Ledger", "SkirmishOutcomes", "SkirmishDeathEvidence", "PersonalSkirmishOutcomes", "RivalContributions", "Encounter", "Core", "SkirmishEvidence", "MeterSourceTotals", "CombatDiagnostics",
    "WorldSkirmishes", "SkirmishGapHistory", "Honor", "Kills", "Deaths", "IssueReport", "Debug" }) do
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

local function SavedCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, field in pairs(value) do copy[key] = SavedCopy(field) end
    return copy
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
            local attempts = death.petFinisher.ownerAttempts
            assert(#attempts == 4 and attempts[1].petToken == "unavailable")
            assert(attempts[1].delay == 0 and attempts[2].delay == 0)
            assert(math.abs(attempts[3].delay - 0.3) < 0.001 and math.abs(attempts[4].delay - 1) < 0.001)
            local report = addon.BuildIssueReport(addon.db, nil, "world:1")
            assert(report:find('"finisher": "pet"', 1, true) and not report:find(pet.id, 1, true))
            local attribution = scenario.owner and "verified-player-owner" or "unknown-player"
            assert(report:find('"finisherAttribution": "' .. attribution .. '"', 1, true))
            assert(report:find('"personalCombatScope": "direct-player"', 1, true))
            assert(not report:find('"section": "personal"', 1, true))
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
            local reloaded = addon.Ledger.Open(SavedCopy(addon.db))
            local saved = reloaded.skirmishes["world:1"]
            assert(saved.personalOutcome.outcome == "loss" and #saved.events == 1)
            local savedPet = assert(saved.events[1].petFinisher)
            assert(savedPet.ownerID == death.petFinisher.ownerID and #savedPet.ownerAttempts == 4)
            for index, attempt in ipairs(attempts) do
                assert(savedPet.ownerAttempts[index].delay == attempt.delay)
                assert(savedPet.ownerAttempts[index].decision == attempt.decision)
            end
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

-- The 71037 GUID-to-token and token-to-owner API contract. Mocked values
-- stand in for the readable, absent and restricted client responses.
if not arg[1] or arg[1] == "pet-owner-api" then
    for _, scenario in ipairs({
        { mode = "direct", owner = two },
        { mode = "logout", owner = two },
        { mode = "post-combat", owner = two },
        { mode = "aura-observation", owner = two },
        { mode = "secret-token" }, { mode = "reused-token" }, { mode = "error" },
        { mode = "conflict" }, { mode = "conflict-observed", noDamage = true },
        { mode = "conflict-history", pastRival = true }, { mode = "conflict-damage", independentOwner = true },
        { mode = "out-of-scope" }, { mode = "unknown-opponent" },
    }) do
        Reset()
        units.party1, units.target, units.mouseover = nil, first, second
        local secret = {}
        function issecretvalue(value) return rawequal(value, secret) end
        local pet = { id = "Pet-owner-api-fixture", name = "Private Pet Label", faction = "Horde" }
        local mode = scenario.mode
        local conflict = mode:match("^conflict") ~= nil
        local manual, pastRival, pastBattle
        if scenario.pastRival then
            manual = { manual = true, time = GetServerTime() - 120 }
            addon.RecordEncounter(two, second.name, "deathsToThem", manual)
            pastRival = assert(addon.db.rivals[two])
            pastBattle = { time = GetServerTime() - 60, origin = "world",
                allies = { { id = me, isSelf = true } }, enemies = { { id = two, rivalID = two, name = second.name } },
                events = { { kind = "kill", actorID = me, targetID = two } } }
            addon.RecordSkirmish("world:8000", pastBattle)
        end
        local fightID = "world:" .. ((addon.db.encounterSequence or 0) + 1)
        local ownerReads = 0
        local function GuidForToken(id)
            if id == two then return "mouseover" end
            if id == one then return "target" end
            if id ~= pet.id or mode == "aura-observation" then return end
            if mode == "secret-token" then return secret end
            return "focus"
        end
        UnitTokenFromGUID = GuidForToken
        function UnitOwnerGUID(token)
            assert(token == "focus")
            ownerReads = ownerReads + 1
            if mode == "error" then error("Private native error") end
            if mode == "reused-token" then units.focus = first; return two end
            if mode == "unknown-opponent" then return me end
            if (mode == "post-combat" or mode == "out-of-scope") and inCombat then return secret end
            if conflict and not inCombat then return one end
            return two
        end
        Begin()
        units.focus = pet -- a token the nameplate enumerator does not see
        if mode == "aura-observation" then
            Aura("focus", "player")
            units.focus = nil
        end
        Advance(5)
        local stamp = GetServerTime()
        localPlayer.dead = true
        recap = {
            { sourceGUID = pet.id, sourceFlags = 0x1148, timestamp = stamp, currentHP = 12, amount = 56,
                overkill = 44, event = "SWING_DAMAGE", sourceName = mode == "secret-token" and secret
                    or (mode ~= "error" and pet.name or nil) },
            { sourceGUID = one, sourceFlags = 0x10548, timestamp = stamp - 0.75,
                amount = 80, event = "SPELL_PERIODIC_DAMAGE" },
        }
        if scenario.noDamage then recap[2] = nil end
        if scenario.independentOwner then
            recap[3] = { sourceGUID = two, sourceFlags = 0x10548, timestamp = stamp - 0.5,
                amount = 31, event = "SPELL_PERIODIC_DAMAGE" }
        end
        Fire("PLAYER_DEAD")
        if conflict then
            local pending = assert(addon.db.skirmishes[fightID])
            assert(not pending.events[1].petFinisher.ownerID)
            for _, enemy in ipairs(pending.enemies) do
                assert(enemy.id ~= two or scenario.independentOwner)
            end
            if not scenario.independentOwner then assert(addon.db.rivals[two] == pastRival) end
        end
        End()
        if mode == "out-of-scope" then Fire("PLAYER_LEAVING_WORLD") end
        if mode == "logout" then
            Advance(0.5)
            Fire("PLAYER_LOGOUT")
            local reloaded = addon.Ledger.Open(SavedCopy(addon.db))
            local savedFight = reloaded.skirmishes[fightID]
            local savedPet = savedFight.events[1].petFinisher
            assert(savedFight.observation.participation.state == "finalized")
            assert(savedPet.ownerID == two and #savedPet.ownerAttempts == 2)
            local _, savedLosses = addon.Ledger.RivalContributionScore(reloaded, two)
            assert(savedLosses == 1)
        end
        local readsAtEnd = ownerReads
        Advance(13)
        local fight = assert(addon.db.skirmishes[fightID])
        local evidence = assert(fight.events[1].petFinisher)
        local attempts = evidence.ownerAttempts
        assert(#attempts > 0 and #attempts <= 4 and evidence.ownerID == scenario.owner, mode)
        assert(fight.personalOutcome.outcome == "loss" and #fight.events == 1 and not fight.events[1].actorID)
        for _, enemy in ipairs(fight.enemies) do assert(enemy.id:match("^Player%-")) end
        assert(not addon.db.rivals[pet.id])
        local _, ownerLosses = addon.Ledger.RivalContributionScore(addon.db, two)
        assert(ownerLosses == ((scenario.owner or scenario.independentOwner) and 1 or 0))
        local _, standaloneLosses = addon.Ledger.RivalContributionScore(addon.db, one)
        assert(standaloneLosses == (scenario.noDamage and 0 or 1))
        if mode == "post-combat" then
            assert(attempts[1].ownerGUID == "secret" and attempts[2].phase == "post-combat"
                and attempts[2].decision == "unit-owner-guid")
            assert(evidence.ownerEvidence == "unit-owner-guid")
        elseif mode == "secret-token" then
            assert(attempts[1].petToken == "secret" and not evidence.sourceName and ownerReads == 0)
        elseif mode == "reused-token" then
            assert(attempts[1].petAfter == "mismatch")
        elseif mode == "error" then
            assert(attempts[1].ownerGUID == "error" and not evidence.sourceName)
        elseif mode == "aura-observation" then
            assert(evidence.ownerEvidence == "scoped-observation")
        elseif conflict then
            assert(evidence.ownerAmbiguous and attempts[2].decision == "ambiguous-owner")
            local reloaded = addon.Ledger.Open(SavedCopy(addon.db))
            local savedPet = reloaded.skirmishes[fightID].events[1].petFinisher
            assert(savedPet.ownerAmbiguous and not savedPet.ownerID and #savedPet.ownerAttempts == 4)
            assert(savedPet.ownerAttempts[1].decision == "unit-owner-guid"
                and savedPet.ownerAttempts[2].decision == "ambiguous-owner")
            local _, savedLosses = addon.Ledger.RivalContributionScore(reloaded, two)
            assert(savedLosses == (scenario.independentOwner and 1 or 0))
            local rivalCount = scenario.noDamage and 0 or (scenario.independentOwner and 2 or 1)
            assert(#fight.enemies == rivalCount, mode .. " left an unsupported rival on the roster")
            if pastRival then
                assert(addon.db.rivals[two] == pastRival and pastRival.encounters[1] == manual)
                assert(addon.db.skirmishes["world:8000"] == pastBattle)
                local wins = addon.Ledger.RivalContributionScore(addon.db, two)
                assert(wins == 1)
                local history = addon.RivalEncounters(addon.db, two)
                assert(#history == 2 and history[1].skirmishID == "world:8000" and history[2] == manual)
            elseif not scenario.independentOwner then
                assert(not addon.db.rivals[two])
            end
        elseif mode == "out-of-scope" then
            assert(ownerReads == readsAtEnd and attempts[2].decision == "scope-unavailable")
        elseif mode == "direct" then
            assert(evidence.sourceName == pet.name and evidence.ownerEvidence == "unit-owner-guid")
            assert(#attempts == 4 and attempts[1].phase == "combat" and attempts[4].phase == "post-combat")
        end
        local report = addon.BuildIssueReport(addon.db, nil, fightID)
        assert(report:find('"section": "petOwnerProbe"', 1, true))
        for _, private in ipairs({ pet.id, pet.name, "Private native error", '"focus"', two }) do
            assert(not report:find(private, 1, true), private)
        end
        UnitTokenFromGUID, UnitOwnerGUID, issecretvalue, units.focus = nil, nil, nil, nil
    end
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
    assert(fight.personalOutcome.version == 5 and addon.Ledger.JournalOutcome(fight) == "unknown")
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
    journal, fight, log = LegacyRecap()
    log.rows[2].events[1].sourceName = "Restricted Local Name"
    log.rows[2].events[1].status.sourceName = "secret"
    addon.Ledger.Open(journal, log)
    assert(not fight.recoveredDeathRecaps[1].petFinisher.sourceName and Losses(one) == 1)
end

-- The owner's original pre-offset record and its retained native reads.
if not arg[1] or arg[1] == "world16-original" then
    local journal, log = dofile("tests/fixtures/world16-anonymized.lua")
    for _, row in ipairs(log.rows) do
        if row.player then
            assert(row.player.status.name == "readable" and row.player.status.surname == "readable")
        end
        for _, hit in ipairs(row.events or {}) do assert(hit.status.sourceName == "readable") end
    end
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
    assert(battle.personalOutcome ~= old and battle.personalOutcome.version == 5)
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
        assert(pet.sourceName == "Fixture Pet")
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

if not arg[1] or arg[1] == "world-join-history" then
    local function Fixture()
        return dofile("tests/fixtures/world19-21-anonymized.lua")
    end
    local function CombatEnd(log, sequence)
        for _, row in ipairs(log.rows) do
            if row.kind == "COMBAT_END" and row.combatSequence == sequence then return row end
        end
    end
    local ledger = addon.Ledger
    local saved, log = Fixture()
    local retained = {}
    local participant = saved.skirmishes["world:19"].allies[2]
    for number = 19, 21 do
        local fight = saved.skirmishes["world:" .. number]
        local segment = fight.observation.segments[1]
        assert(fight.personalOutcome.version == 3 and #fight.allies == (number == 19 and 2 or 1))
        assert(#fight.enemies == 1 and #fight.events == 1)
        retained[number] = { fight.events[1], fight.rewards }
        local row = assert(CombatEnd(log, segment.reportMeter.combatSequence))
        local spell = row.meter.EnemyDamageTaken.sources[1].spells[1]
        assert(spell.spellID == 0 and spell.totalAmount > 0 and spell.target.amount == 0)
        assert(spell.target.unitClassFilename == "" and spell.target.status.unitClassFilename == "readable")
        local wins = ledger.RivalContributionScore(saved, fight.enemies[1].rivalID)
        assert(wins == (number == 19 and 0 or 1))
    end

    ledger.Open(saved, log)
    local expected = { [19] = { 704, 462 }, [20] = { 171, 132 }, [21] = { 317, 234 } }
    local function Verify(db, number, fromOriginal)
        local key = "world:" .. number
        local fight = db.skirmishes[key]
        assert(#fight.allies == 2 and #fight.enemies == 1 and #fight.events == 1, key .. " roster")
        assert(fight.allies[2].id == participant.id and fight.allies[2].name == participant.name)
        assert(ledger.JournalOutcome(fight) == "win" and fight.personalOutcome.reason == "enemy-elimination", key .. " outcome")
        local rival = fight.enemies[1].rivalID
        local wins, losses = ledger.RivalContributionScore(db, rival)
        assert(wins == 1 and losses == 0 and addon.RivalEncounters(db, rival)[1].skirmishID == key, key .. " score")
        local kills, deaths = ledger.PersonalCombatScore(db, rival)
        assert(kills == (number == 19 and 0 or 1) and deaths == 0, key .. " direct combat")
        local totals = {}
        for _, aggregate in ipairs(fight.observation.segments[1].combatAggregates) do
            if aggregate.amountBasis == "source-total-matched" then
                assert(aggregate.targetID == fight.enemies[1].id and not aggregate.spellID and not aggregate.offset)
                assert(not totals[aggregate.actorID], key .. " duplicate amount")
                totals[aggregate.actorID] = aggregate.amount
            end
        end
        assert(totals[fight.allies[1].id] == expected[number][1] and totals[participant.id] == expected[number][2])
        if fromOriginal then
            assert(fight.events[1] == retained[number][1] and fight.rewards == retained[number][2])
            assert(fight.personalOutcome.version == 5)
        end
    end
    for number = 19, 21 do Verify(saved, number, true) end
    ledger.Open(saved, log)
    for number = 19, 21 do Verify(saved, number, true) end
    local noDebug = ledger.Open(SavedCopy(saved))
    for number = 19, 21 do Verify(noDebug, number) end
    local report = addon.BuildIssueReport(noDebug, nil, "world:20")
    assert(report:find('"amountBasis": "source-total-matched"', 1, true))

    for _, corrupt in ipairs({
        function(row) row.meter.DamageDone.sources[1].totalAmount = 1234 end,
        function(row) row.meter.EnemyDamageTaken.sources[1].spells[1].target.status.unitName = "secret" end,
        function(row) row.meter.EnemyDamageTaken.sources[1].spells[1].target.isMob = true end,
        function(row) row.meter.EnemyDamageTaken.sources[1].spellCount = 20 end,
        function(row) row.meter.EnemyDamageTaken.sources[1].sourceGUID = "Creature-1" end,
        function(row) row.meterUpdates["0:10"].firstUptime = row.meterUpdates["0:10"].firstUptime - 1 end,
        function(row) row.meterUpdates["0:10"].uptime = row.uptime + 2 end,
        function(row) row.meter.DamageTaken.sources = {} end,
        function(row) row.newMeterSessionIDs[1] = 7 end,
        function(row) row.areaChanged = true end,
        function(row) row.meterReset = true end,
        function(row)
            local duplicate = SavedCopy(row.contacts[participant.id])
            local replacement = "Player-duplicate"
            duplicate.latest.guid, duplicate.latest.class = replacement, "MAGE"
            row.contacts[replacement] = duplicate
        end,
        function(row, rows) CombatEnd(rows, 40).uptime = row.uptime - 8 end,
        function(row, rows) rows.rows[#rows.rows + 1] = SavedCopy(row) end,
        function(row) row.session = row.session + 1 end,
        function(row)
            for _, contact in pairs(row.contacts) do
                local function Unlink(unit) if unit.targetGUID == participant.id then unit.targetGUID = nil end end
                Unlink(contact.latest)
                for _, previous in ipairs(contact.changes or {}) do Unlink(previous) end
            end
        end,
    }) do
        local broken, diagnostics = Fixture()
        local row = assert(CombatEnd(diagnostics, 41))
        corrupt(row, diagnostics)
        ledger.Open(broken, diagnostics)
        local fight = broken.skirmishes["world:20"]
        assert(#fight.allies == 1 and #fight.enemies == 1 and ledger.JournalOutcome(fight) == "win")
        local wins, losses = ledger.RivalContributionScore(broken, fight.enemies[1].rivalID)
        assert(wins == 1 and losses == 0)
    end
    local copied, sharedLog = Fixture()
    copied.skirmishes["world:200"] = SavedCopy(copied.skirmishes["world:20"])
    ledger.Open(copied, sharedLog)
    assert(#copied.skirmishes["world:20"].allies == 1 and #copied.skirmishes["world:200"].allies == 1)

    -- The actual late ally combat is insufficient to reopen an elimination.
    -- A linked action after the early samples invalidates that same ending.
    local linked = Fixture()
    local fight = linked.skirmishes["world:19"]
    fight.observation.assessment.lastAction = { actorID = fight.allies[2].id, targetID = fight.enemies[1].id, offset = 22 }
    ledger.Open(linked)
    assert(ledger.JournalOutcome(fight) == "unknown")
    linked = Fixture()
    fight = linked.skirmishes["world:19"]
    local state = fight.observation.assessment
    state.lastMeterActivity = 22
    state.meterPair = { actorID = fight.allies[2].id, targetID = fight.enemies[1].id }
    ledger.Open(linked)
    assert(ledger.JournalOutcome(fight) == "unknown")
    linked = Fixture()
    fight = linked.skirmishes["world:19"]
    local other = "Player-active"
    fight.enemies[2] = { id = other }
    fight.observation.participation.lateFirst.units[other] = { dead = false, combat = true }
    ledger.Open(linked)
    assert(ledger.JournalOutcome(fight) == "unknown")
    linked = Fixture()
    fight = linked.skirmishes["world:19"]
    fight.observation.participation.lateFirst.units[fight.enemies[1].id] = { dead = false, combat = true }
    ledger.Open(linked)
    assert(ledger.JournalOutcome(fight) == "unknown")
    print("Original world:19–21 replay restores three 2v1 victories and preserves scoped credit across reload")
end

if not arg[1] or arg[1] == "world-join-capture" then
    local saved, log = dofile("tests/fixtures/world19-21-anonymized.lua")
    local member = saved.skirmishes["world:19"].allies[2].id
    local function Player(unit)
        local name = unit.name .. (unit.surname ~= "" and (" " .. unit.surname) or "")
        return { id = unit.guid, name = name, class = unit.class, faction = unit.faction, active = unit.inCombat }
    end
    for number = 20, 21 do
        Reset()
        -- Establish a preceding, closed local window before replaying the
        -- raw meter values through the live API and its settling callbacks.
        Begin()
        Advance(3)
        End()
        Advance(20)

        local original = saved.skirmishes["world:" .. number]
        local initial = original.observation.segments[1]
        local window
        for _, row in ipairs(log.rows) do
            if row.kind == "COMBAT_END" and row.combatSequence == initial.reportMeter.combatSequence then window = row end
        end
        local selfID, enemyID = original.allies[1].id, original.enemies[1].id
        units.player, units.party1 = Player(window.contacts[selfID].latest), Player(window.contacts[member].latest)
        units.target = Player(window.contacts[enemyID].latest)
        units.targettarget, units.playertarget = units.party1, units.target
        units.party1.active = true
        if number == 20 then
            for id, contact in pairs(window.contacts) do
                if contact.latest.opponent and id ~= enemyID then
                    units.nameplate2 = Player(contact.latest)
                    Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
                end
            end
        end

        local oldAPI = C_DamageMeter
        local categories = {}
        for name, key in pairs(Enum.DamageMeterType) do categories[key] = window.meter[name] end
        C_DamageMeter = {
            GetAvailableCombatSessions = oldAPI.GetAvailableCombatSessions,
            GetCombatSessionFromType = function(_, category)
                local group = categories[category]
                return { combatSources = group and group.sources or {}, durationSeconds = window.meterCurrentDuration,
                    totalAmount = group and group.totalAmount or 0 }
            end,
            GetCombatSessionSourceFromType = function(_, category, guid)
                for _, source in ipairs(categories[category].sources) do
                    if source.sourceGUID == guid then
                        local spells = {}
                        for _, spell in ipairs(source.spells) do
                            local native = SavedCopy(spell)
                            native.combatSpellDetails = spell.target
                            spells[#spells + 1] = native
                        end
                        return { combatSpells = spells }
                    end
                end
            end,
        }
        local done, enemyTaken = Enum.DamageMeterType.DamageDone, Enum.DamageMeterType.EnemyDamageTaken
        local updates = window.meterUpdates["0:" .. done]
        local beginOffset = window.uptime - initial.duration
        local killAt, firstUpdate = original.events[1].offset, updates.firstUptime - beginOffset
        Begin()
        if firstUpdate <= killAt then
            Advance(firstUpdate)
            Update(done, enemyTaken)
            Advance(killAt - firstUpdate)
        else
            Advance(killAt)
        end
        Kill(selfID, units.target)
        if firstUpdate > killAt then
            Advance(firstUpdate - killAt)
            Update(done, enemyTaken)
        end
        local lastUpdate = updates.uptime - beginOffset
        if lastUpdate < initial.duration then
            Advance(lastUpdate - math.max(killAt, firstUpdate))
            Update(done, enemyTaken)
            Advance(initial.duration - lastUpdate)
            End()
        else
            Advance(initial.duration - math.max(killAt, firstUpdate))
            End()
            Advance(lastUpdate - initial.duration)
            Update(done, enemyTaken)
        end
        units.party1.active = nil
        Advance(13)
        local db = addon.Ledger.Open(SavedCopy(addon.db))
        local fight = assert(db.skirmishes["world:1"])
        assert(#fight.allies == 2 and #fight.enemies == 1 and #fight.events == 1, "live capture " .. number)
        assert(fight.allies[2].id == member and fight.enemies[1].id == enemyID)
        assert(addon.Ledger.JournalOutcome(fight) == "win")
        local wins, losses = addon.Ledger.RivalContributionScore(db, enemyID)
        assert(wins == 1 and losses == 0)
        assert(#fight.observation.segments[1].combatAggregates == 2)
        C_DamageMeter = oldAPI
        units.player, units.party1 = localPlayer, friend
        units.targettarget, units.playertarget, units.nameplate2 = nil, nil, nil
        Fire("NAME_PLATE_UNIT_REMOVED", "nameplate2")
    end
    print("Native Damage Meter API replay records the ally through the live window and retry")
end

-- Replay the captured combat timings and native recap through the event
-- handlers. Negative cases vary the signal that would qualify the join.
if not arg[1] or arg[1] == "control-gap" then
    local journal, log = dofile("tests/fixtures/world22-24-anonymized.lua")
    local before = journal.skirmishes["world:23"].observation.segments[1]
    local after = journal.skirmishes["world:24"].observation.segments[1]
    local nativeEnd, nativeStart, capturedRecap
    for _, row in ipairs(log.rows) do
        if row.combatSequence == 27 and row.kind == "COMBAT_END" then nativeEnd = row.uptime end
        if row.combatSequence == 28 and row.kind == "COMBAT_START" then nativeStart = row.uptime end
        if row.combatSequence == 28 and row.kind == "RECAP" and row.delay == 0 and not capturedRecap then
            capturedRecap = row.events
        end
    end
    for _, scenario in ipairs({ "recap", "recap-retry", "meter", "idle", "settled", "other", "other-while-held",
        "pve", "expired", "revenge" }) do
        Reset()
        units.party1, units.target, units.targettarget = nil, first, localPlayer
        first.active = nil
        local damageTaken = Enum.DamageMeterType.DamageTaken
        duration = before.duration
        Begin()
        if scenario == "revenge" then
            Advance(4)
            Kill(me, first)
            Advance(before.duration - 4)
        else
            Advance(8)
            Link(damageTaken, me, first, 330)
            Update(damageTaken)
            Advance(before.duration - 8)
        end
        first.active = scenario ~= "idle" and scenario ~= "revenge" or nil
        End()
        first.active = nil
        Advance(1.6)
        local original = assert(addon.db.skirmishes["world:1"])
        if scenario == "settled" then
            -- This time both independent disengagement samples fit before
            -- the next combat entry.
            Advance(0.5)
        elseif scenario ~= "revenge" then
            units.target = nil
        end
        Advance(nativeStart - nativeEnd - 1.6)
        if scenario == "revenge" then first.dead = false end
        local target = (scenario == "other" or scenario == "other-while-held") and second or first
        units.target, units.targettarget = target, localPlayer
        if scenario == "other-while-held" then units.mouseover, units.mouseovertarget = first, localPlayer end
        sources = {}
        Begin()
        if scenario == "pve" then
            units.mouseover = { id = "Creature-unrelated", faction = "Horde" }
            Aura("mouseover", "player")
        end
        Advance(scenario == "expired" and 15 or after.duration)
        local continued = scenario == "recap" or scenario == "recap-retry"
        assert(original.personalOutcome.lifecycle == ((continued or scenario == "meter" or scenario == "pve"
            or scenario == "other-while-held")
            and "awaiting" or "finalized"), scenario .. " predecessor at successor qualification")
        if scenario == "pve" then
            End()
            Advance(15)
            assert(original.personalOutcome.lifecycle == "finalized" and not addon.db.skirmishes["world:2"])
        elseif scenario == "meter" then
            Link(damageTaken, me, target, 1135)
            Update(damageTaken)
            duration = after.duration
            End()
            Advance(15)
            assert(not addon.db.skirmishes["world:2"] and #original.observation.segments == 2)
        else
            localPlayer.dead = true
            recap = SavedCopy(capturedRecap)
            local shift = GetServerTime() - math.floor(recap[1].timestamp)
            for _, hit in ipairs(recap) do
                hit.sourceGUID, hit.sourceName = target.id, target.name
                if hit.timestamp then hit.timestamp = hit.timestamp + shift end
            end
            local lateRecap
            if scenario == "recap-retry" then lateRecap, recap = recap, nil end
            Fire("PLAYER_DEAD")
            End()
            if lateRecap then recap = lateRecap end
            Advance(15)
            local death = continued and original or addon.db.skirmishes["world:2"]
            assert(death and #death.observation.segments == (continued and 2 or 1), scenario .. " segment count")
            assert(death.personalOutcome.outcome == "loss" and #death.events == 1, scenario .. " death")
            if continued then assert(not addon.db.skirmishes["world:2"]) end
            if scenario == "revenge" then
                assert(original.personalOutcome.outcome == "win")
                local wins, losses = addon.Ledger.RivalContributionScore(addon.db, first.id)
                assert(wins == 1 and losses == 1)
            end
        end
        units.targettarget, units.mouseovertarget, first.active = nil, nil, nil
    end
end

if not arg[1] or arg[1] == "control-gap-history" then
    local function Fixture()
        return dofile("tests/fixtures/world22-24-anonymized.lua")
    end
    local function Row(log, sequence, kind)
        for index, row in ipairs(log.rows) do
            if row.combatSequence == sequence and row.kind == kind then return row, index end
        end
    end
    local ledger = addon.Ledger
    local saved, log = Fixture()
    local win, before, after = saved.skirmishes["world:22"], saved.skirmishes["world:23"], saved.skirmishes["world:24"]
    local rival, me = win.enemies[1].id, win.allies[1].id
    local nativeStart = assert(Row(log, 28, "COMBAT_START"))
    local nativeClose = assert(Row(log, 27, "COMBAT_END"))
    local seconds = nativeStart.uptime - nativeClose.uptime
    local shift = nativeStart.uptime - assert(Row(log, 27, "COMBAT_START")).uptime
    assert(math.abs(seconds - 3.179) < 0.0001)
    assert(before.personalOutcome.outcome == "unknown" and win.personalOutcome.outcome == "win")
    assert(after.personalOutcome.outcome == "loss" and #ledger.RivalSkirmishes(saved, rival) == 3)
    local earlier, later = before.observation.segments[1], after.observation.segments[1]
    local oldEnding, oldParticipation = before.observation.assessment, before.observation.participation
    local originalDeath = after.events[1]
    local nativeOffset, stamp = originalDeath.offset, originalDeath.recapTimestamp
    local nativeWitness = later.localDeathWitnesses[rival]
    local beforeCounts = { #before.combatDiagnostics.windows, #after.combatDiagnostics.windows, #after.combatDiagnostics.recaps }
    ledger.Open(saved, log)
    assert(saved.skirmishes["world:22"] == win and not saved.skirmishes["world:24"])
    assert(saved.skirmishes["world:23"] == before and #before.events == 1 and before.events[1] == originalDeath)
    assert(before.observation.segments[1] == earlier and before.observation.segments[2] == later)
    assert(before.recoveredContinuation.assessment == oldEnding and before.recoveredContinuation.participation == oldParticipation)
    assert(later.offset == shift and later.continuation == "recovered-combat-gap")
    assert(originalDeath.offset == shift + nativeOffset and originalDeath.segmentIndex == 2 and originalDeath.recapTimestamp == stamp)
    if nativeWitness then assert(later.localDeathWitnesses[rival] == nativeWitness + shift) end
    assert(#before.combatDiagnostics.windows == beforeCounts[1] + beforeCounts[2]
        and #before.combatDiagnostics.recaps == beforeCounts[3])
    assert(before.combatDiagnostics.windows[1].index == 1 and before.combatDiagnostics.windows[2].index == 2)
    assert(before.observation.life[1].offset == originalDeath.offset and before.observation.life[2].state == "ghost")
    assert(before.personalOutcome.casualties.friendly == 1 and before.personalOutcome.casualties.enemy == 0)
    for _, db in ipairs({ saved, ledger.Open(SavedCopy(saved), log), ledger.Open(SavedCopy(saved)) }) do
        local outcomes = ledger.RivalSkirmishes(db, rival)
        assert(#outcomes == 2 and not db.skirmishes["world:24"])
        assert(ledger.JournalOutcome(db.skirmishes["world:22"]) == "win"
            and ledger.JournalOutcome(db.skirmishes["world:23"]) == "loss")
        local wins, losses = ledger.RivalContributionScore(db, rival)
        local kills, deaths = ledger.PersonalCombatScore(db, rival)
        local hk, honor = ledger.RivalRewards(db, rival)
        assert(wins == 1 and losses == 1 and kills == 1 and deaths == 1)
        assert(hk == 1 and honor == 6)
        assert(#db.skirmishes["world:23"].observation.segments == 2)
    end
    local text = addon.BuildIssueReport(saved, nil, "world:23")
    assert(text:find('"recoveredContinuationFrom": "world:24"', 1, true))
    assert(not text:find(before.enemies[1].name, 1, true) and not text:find(before.allies[1].name, 1, true))

    local extra, extraLog = Fixture()
    extra.skirmishes["world:23"].rewards = { [rival] = { honorableKills = 1, honor = 2 } }
    extra.skirmishes["world:24"].rewards = { [rival] = { honorableKills = 2, honor = 3 } }
    extra.skirmishes["world:24"].unassignedRewards = { honorableKills = 1, honor = 1 }
    local originalTotals = ledger.JournalRewards(extra)
    ledger.Open(extra, extraLog)
    local totals = ledger.JournalRewards(extra)
    assert(totals.honorableKills == originalTotals.honorableKills and totals.honor == originalTotals.honor)
    local kept = extra.skirmishes["world:23"]
    assert(kept.rewards[rival].honorableKills == 3 and kept.rewards[rival].honor == 5)
    assert(kept.unassignedRewards.honorableKills == 1 and kept.unassignedRewards.honor == 1)

    for _, mutate in ipairs({
        function(b) b.skirmishes["world:23"].observation.participation.boundary = "independent-engagement" end,
        function(b) b.skirmishes["world:23"].observation.participation.closedAt = b.skirmishes["world:24"].startedAt - 1 end,
        function(b)
            local state = b.skirmishes["world:23"].observation.assessment
            state.last = SavedCopy(state.first)
            state.last.offset = state.last.offset + 1
        end,
        function(b) b.skirmishes["world:24"].enemies[1].id = "Player-another" end,
        function(b) b.skirmishes["world:23"].observation.segments[1].localNpcPressure = true end,
        function(b) b.skirmishes["world:24"].observation.segments[1].contributionLinks = {} end,
        function(b) b.skirmishes["world:299"] = SavedCopy(b.skirmishes["world:24"]) end,
        function(_, rows) Row(rows, 28, "COMBAT_END").contacts[rival].initial.status.targetGUID = "secret" end,
        function(_, rows) Row(rows, 27, "COMBAT_END").contacts[rival].latest.targetGUID = "Player-another" end,
        function(_, rows) Row(rows, 28, "COMBAT_START").session = 100 end,
        function(_, rows) rows.rows[#rows.rows + 1] = SavedCopy((Row(rows, 27, "COMBAT_END"))) end,
        function(_, rows)
            for _, row in ipairs(rows.rows) do
                if row.kind == "RECAP" then row.events[1].timestamp = row.events[1].timestamp - 1 end
            end
        end,
        function(_, rows) rows.rows = {} end,
    }) do
        local db, debugLog = Fixture()
        mutate(db, debugLog)
        ledger.Open(db, debugLog)
        assert(db.skirmishes["world:23"] and db.skirmishes["world:24"] and #db.skirmishes["world:23"].observation.segments == 1)
    end
    print("Original world:22–24 replay preserves two fights, both combat segments, recorded deaths, rewards and 1:1 credit")
end

local function OutgoingFixture()
    local saved, log = dofile("tests/fixtures/outgoing-only-anonymized.lua")
    local start, finish = log.rows[1], log.rows[#log.rows]
    local me, enemy = start.player.guid, start.target.guid
    local ally = finish.contacts[enemy].initial.targetGUID
    return saved, log, start, finish, me, enemy, ally
end

if not arg[1] or arg[1] == "outgoing-history" then
    local saved, log, start, finish, me, enemy, ally = OutgoingFixture()
    local ledger = addon.Ledger
    assert(finish.status.meterWindow == "no-linked-pvp" and not next(saved.skirmishes))
    assert(saved.unassignedRewards.honorableKills == 1 and saved.unassignedRewards.honor == 4)
    local before = ledger.JournalRewards(saved)
    local function Verify(db)
        local b = assert(db.skirmishes["world:26"])
        assert(#b.allies == 2 and #b.enemies == 1 and #b.events == 1)
        assert(b.allies[1].id == me and b.allies[1].isSelf and b.allies[2].id == ally)
        assert(b.enemies[1].id == enemy and ledger.JournalOutcome(b) == "win")
        assert(b.events[1].kind == "death" and b.events[1].targetID == enemy and b.events[1].actorID == nil)
        assert(math.abs(b.events[1].offset - 5.839) < 0.0001 and not b.events[1].time)
        local segment = b.observation.segments[1]
        assert(segment.engagedAlly.allyID == ally and segment.engagedAlly.opponentID == enemy)
        assert(#segment.combatAggregates == 1 and segment.combatAggregates[1].amount == 630)
        assert(segment.combatAggregates[1].actorID == me and not segment.combatAggregates[1].offset)
        local wins, losses = ledger.RivalContributionScore(db, enemy)
        local kills, deaths = ledger.PersonalCombatScore(db, enemy)
        local hks, honor = ledger.SkirmishRewards(b)
        local rivalHK, rivalHonor = ledger.RivalRewards(db, enemy)
        assert(wins == 1 and losses == 0 and kills == 0 and deaths == 0)
        assert(hks == 1 and honor == 4 and rivalHK == 1 and rivalHonor == 4 and not b.unassignedRewards)
        local totals = ledger.JournalRewards(db)
        assert(totals.honorableKills == before.honorableKills and totals.honor == before.honor
            and totals.unassignedHK == 0 and totals.unassignedHonor == 0)
        return b
    end
    assert(Verify(ledger.Open(saved, log)) == Verify(ledger.Open(saved, log)))
    Verify(ledger.Open(SavedCopy(saved)))
    local report = addon.BuildIssueReport(saved, log, "world:26")
    assert(report:find('"evidence": "corroborated-targeting"', 1, true))
    assert(not report:find('"section": "rewardUnassignedOpponent"', 1, true))
    assert(not report:find(finish.contacts[ally].initial.name, 1, true))
    ledger.RemoveSkirmish(saved, "world:26")
    ledger.Open(saved, log)
    assert(not next(saved.skirmishes))

    for _, attempt in ipairs({ "verified", "outside-death-time", "second-opponent", "missing-tombstone" }) do
        local db, rows = OutgoingFixture()
        db.encounterSequence = 26
        local battle = ledger.Open(db, rows).skirmishes["world:27"]
        -- The earlier preview had these exact awards on the battle, with no
        -- opponent in its reward bucket. Keep its original identity and proof.
        battle.unassignedRewards, battle.rewards = battle.rewards[enemy], nil
        if attempt == "outside-death-time" then
            for _, reward in ipairs(rows.rows) do
                if reward.kind == "CHAT_MSG_COMBAT_HONOR_GAIN" then reward.uptime = reward.uptime + 3 end
            end
        elseif attempt == "second-opponent" then
            battle.enemies[2] = { id = "Player-unrelated", name = "Other Player" }
        elseif attempt == "missing-tombstone" then
            db.recoveredMeterWindows = nil
        end
        assert(ledger.RivalRewards(ledger.Open(db), enemy) == 0)
        ledger.Open(db, rows)
        ledger.Open(db, rows)
        ledger.Open(db)
        local hk, honor = ledger.RivalRewards(db, enemy)
        assert(hk == (attempt == "verified" and 1 or 0) and honor == (attempt == "verified" and 4 or 0))
        local total = ledger.JournalRewards(db)
        assert(total.honorableKills == 1 and total.honor == 4 and next(db.skirmishes) == "world:27"
            and not next(db.skirmishes, "world:27") and db.skirmishes["world:27"] == battle and db.encounterSequence == 27)
        assert(ledger.PersonalCombatScore(db, enemy) == 0 and battle.mapID == nil and battle.x == nil and battle.y == nil)
        if attempt == "verified" then
            ledger.RemoveSkirmish(db, "world:27")
            assert(not next(ledger.Open(db, rows).skirmishes))
        end
    end

    for _, location in ipairs({ "valid", "absent", "out-of-range", "invalid-map", "origin", "wrong-window" }) do
        local db, rows, first = OutgoingFixture()
        if location == "valid" then
            first.mapID, first.x, first.y = 1431, 0.45, 0.67
        elseif location == "out-of-range" then
            first.mapID, first.x, first.y = 1431, 1.45, 0.67
        elseif location == "invalid-map" then
            first.mapID, first.x, first.y = 0, 0.45, 0.67
        elseif location == "origin" then
            first.mapID, first.x, first.y = 1431, 0, 0
        elseif location == "wrong-window" then
            local other = SavedCopy(first)
            other.combatSequence, other.mapID, other.x, other.y = first.combatSequence + 1, 1431, 0.45, 0.67
            rows.rows[#rows.rows + 1] = other
        end
        local b = ledger.Open(db, rows).skirmishes["world:26"]
        if location == "valid" then
            assert(b.mapID == 1431 and b.x == 0.45 and b.y == 0.67)
            local reloaded = ledger.Open(SavedCopy(db)).skirmishes["world:26"]
            assert(reloaded.mapID == b.mapID and reloaded.x == b.x and reloaded.y == b.y)
        else
            assert(b.mapID == nil and b.x == nil and b.y == nil)
        end
    end

    for _, alter in ipairs({
        function(_, _, _, row) row.meter.DamageDone.sources[1].totalAmount = 629 end,
        function(_, _, _, row) row.meter.EnemyDamageTaken.sources[1].spells[1].target.status.unitName = "secret" end,
        function(_, _, _, row) row.meter.EnemyDamageTaken.sources[1].sourceGUID = "Creature-unrelated" end,
        function(_, _, _, row) row.meterEvidence.EnemyDamageTaken = "duration-mismatch" end,
        function(_, _, first, row) row.meterUpdates["0:10"].firstUptime = first.uptime - 0.1 end,
        function(_, rows) rows.rows[#rows.rows + 1] = SavedCopy(rows.rows[1]) end,
        function(_, _, first, row) row.player.guid = "Player-unrelated" end,
        function(_, _, _, row)
            local other = SavedCopy(row.contacts[me])
            other.latest.guid = "Player-ambiguous"
            row.contacts[other.latest.guid] = other
        end,
        function(db, _, first, row)
            db.skirmishes["world:1"] = { startedAt = first.time, time = row.time, allies = {}, enemies = {}, events = {} }
        end,
    }) do
        local db, rows, first, row = OutgoingFixture()
        alter(db, rows, first, row)
        ledger.Open(db, rows)
        assert(not db.skirmishes["world:26"] and db.unassignedRewards.honorableKills == 1)
    end

    for _, alter in ipairs({
        function(row) row.contacts[ally].initial.status.targetGUID = "secret" end,
        function(row) row.contacts[ally].initial.status.faction = "secret" end,
        function(row) row.contacts[ally].initial.inCombat = false end,
        function(row) row.contacts[ally].initial.uptime = row.uptime end,
        function(row) row.contacts[enemy].initial.targetGUID = "Player-bystander" end,
    }) do
        local db, rows, _, row = OutgoingFixture()
        alter(row)
        local b = ledger.Open(db, rows).skirmishes["world:26"]
        assert(#b.allies == 1 and #b.enemies == 1 and ledger.JournalOutcome(b) == "win")
    end

    local db, rows, _, row = OutgoingFixture()
    for _, unit in ipairs(row.contacts[enemy].changes) do if unit.dead then unit.feign = true end end
    row.contacts[enemy].latest.feign = true
    local b = ledger.Open(db, rows).skirmishes["world:26"]
    assert(b and #b.events == 0 and #b.allies == 1 and ledger.JournalOutcome(b) == "unknown")
    assert(db.unassignedRewards.honorableKills == 1 and db.unassignedRewards.honor == 4)

    db, rows, _, row = OutgoingFixture()
    local observed = row.contacts[enemy]
    local revived = SavedCopy(observed.initial)
    revived.uptime = row.uptime - 0.1
    observed.changes[#observed.changes + 1] = revived
    b = ledger.Open(db, rows).skirmishes["world:26"]
    assert(b and #b.events == 0 and ledger.JournalOutcome(b) == "unknown")

    db, rows = OutgoingFixture()
    db.unassignedRewards.honor = 9
    b = ledger.Open(db, rows).skirmishes["world:26"]
    assert(b and ledger.SkirmishRewards(b) == 0 and db.unassignedRewards.honor == 9)

    db, rows, _, row = OutgoingFixture()
    local unrelated = SavedCopy(row)
    unrelated.session, unrelated.status.meterWindow = row.session + 1, "other-window"
    rows.rows[#rows.rows + 1] = unrelated
    b = ledger.Open(db, rows).skirmishes["world:26"]
    assert(b and ledger.SkirmishRewards(b) == 0 and db.unassignedRewards.honor == 4)
    print("Original outgoing-only fight recovered as 2x1 Victory with one credit and exactly 1 HK / 4 honor")
end

if not arg[1] or arg[1] == "outgoing-capture" then
    local _, _, start, finish, selfID, enemyID, allyID = OutgoingFixture()
    local function Player(unit)
        local suffix = unit.surname and unit.surname ~= "" and (" " .. unit.surname) or ""
        return { id = unit.guid, name = unit.name .. suffix, faction = unit.faction, class = unit.class }
    end
    for case, scenario in ipairs({ "confirmed-later", "award-after-confirmation", "outside-death-time", "no-corpse" }) do
        local death = scenario ~= "no-corpse"
        Reset()
        units.player = Player(finish.contacts[selfID].initial)
        units.target = Player(finish.contacts[enemyID].initial)
        units.targettarget = Player(finish.contacts[allyID].initial)
        units.party1 = nil
        local oldAPI = C_DamageMeter
        local categories = {}
        for name, key in pairs(Enum.DamageMeterType) do categories[key] = finish.meter[name] end
        C_DamageMeter = {
            GetAvailableCombatSessions = oldAPI.GetAvailableCombatSessions,
            GetCombatSessionFromType = function(_, category)
                local group = categories[category]
                return { combatSources = group and group.sources or {}, durationSeconds = finish.meterCurrentDuration,
                    totalAmount = group and group.totalAmount or 0 }
            end,
            GetCombatSessionSourceFromType = function(_, category, guid)
                for _, source in ipairs(categories[category].sources) do
                    if source.sourceGUID == guid then
                        local spells = {}
                        for _, spell in ipairs(source.spells) do
                            local native = SavedCopy(spell)
                            native.combatSpellDetails = spell.target
                            spells[#spells + 1] = native
                        end
                        return { combatSpells = spells }
                    end
                end
            end,
        }
        C_Map = { GetBestMapForUnit = function() return 1431 end,
            GetPlayerMapPosition = function()
                return { GetXY = function() return 0.45, 0.67 end }
            end }
        Begin()
        local combatStart = NamesInRedDebugDB.rows[#NamesInRedDebugDB.rows]
        assert(combatStart.kind == "COMBAT_START" and combatStart.mapID == 1431
            and combatStart.x == 0.45 and combatStart.y == 0.67)
        C_Map = nil
        local done, taken = Enum.DamageMeterType.DamageDone, Enum.DamageMeterType.EnemyDamageTaken
        local updates = finish.meterUpdates["0:" .. done]
        Advance(updates.firstUptime - start.uptime)
        Update(done, taken)
        Advance(updates.uptime - updates.firstUptime)
        Update(done, taken)
        if death and scenario ~= "award-after-confirmation" then
            Advance(11385.849 - updates.uptime)
            HK()
            Fire("PLAYER_PVP_KILLS_CHANGED", "player")
            Advance(11386.002 - 11385.849)
            units.target.dead = true
            Fire("UNIT_FLAGS", "target")
            Advance(11386.748 - 11386.002)
            if scenario ~= "outside-death-time" then Chat(4, 49000 + case) end
            Advance(11388.084 - 11386.748)
            units.mouseover = units.targettarget
            units.mouseover.active = true
            Fire("UPDATE_MOUSEOVER_UNIT")
            if scenario == "outside-death-time" then
                Advance(0.3)
                Chat(4, 49000 + case)
                Advance(finish.uptime - 11388.384)
            else
                Advance(finish.uptime - 11388.084)
            end
            assert(addon.db.unassignedRewards.honorableKills == 1 and not addon.db.skirmishes)
        elseif death then
            Advance(finish.uptime - updates.uptime - 0.1)
            units.target.dead = true
            Fire("UNIT_FLAGS", "target")
            Advance(0.1)
        else
            Advance(finish.uptime - updates.uptime)
        end
        End()
        if death then units.mouseover = nil end
        if scenario == "award-after-confirmation" then
            Advance(0.75)
            assert(addon.db.skirmishes["world:1"])
            HK()
            Chat(4, 49000 + case)
        end
        Advance(14)
        local b = assert(addon.db.skirmishes["world:1"])
        assert(#b.enemies == 1 and b.enemies[1].id == enemyID)
        local allyExpected = death and scenario ~= "award-after-confirmation"
        assert(#b.allies == (allyExpected and 2 or 1))
        local wins, losses = addon.Ledger.RivalContributionScore(addon.db, enemyID)
        assert(wins == (death and 1 or 0) and losses == 0)
        if death then
            assert(addon.Ledger.JournalOutcome(b) == "win" and b.events[1].kind == "death" and not b.events[1].actorID)
            local hks, honor = addon.Ledger.SkirmishRewards(b)
            assert(#b.events == 1 and hks == 1 and honor == 4 and addon.Ledger.PersonalCombatScore(addon.db, enemyID) == 0)
            local rivalHK, rivalHonor = addon.Ledger.RivalRewards(addon.db, enemyID)
            local attributable = scenario ~= "outside-death-time"
            assert(rivalHK == (attributable and 1 or 0) and rivalHonor == (attributable and 4 or 0))
        else
            assert(#b.events == 0 and addon.Ledger.SkirmishRewards(b) == 0)
        end
        C_DamageMeter = oldAPI
        units.player, units.targettarget = localPlayer, nil
    end
    print("Live outgoing-only capture starts a battle with or without a corpse and moves the same-window award once")
end
