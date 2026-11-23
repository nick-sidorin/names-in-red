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
function UnitIsFeignDeath(unit) return Field(unit, "feign") == true end
function UnitIsVisible(unit) return units[unit] ~= nil end
function UnitIsGhost(unit) return unit == "player" and ghost end
function UnitIsPlayer(unit) return units[unit] ~= nil end
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
bit = { band = function(flags) return flags == 0x440 and flags or 0 end }
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

for _, file in ipairs({ "Locale", "Ledger", "SkirmishOutcomes", "Encounter", "Core", "SkirmishEvidence", "CombatDiagnostics",
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
    assert(recoveredReport:find('"section": "meterSpellSample"', 1, true))
    assert(recoveredReport:find('"section": "primaryEvidence"', 1, true))
    assert(not recoveredReport:find("Cast-diagnostic-private", 1, true))
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
    Fire("ZONE_CHANGED_NEW_AREA")
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
print("Anonymized Gnomeregan event replays passed")
