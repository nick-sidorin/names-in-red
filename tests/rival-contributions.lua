local addon = {}
for _, file in ipairs({ "Ledger", "SkirmishDeathEvidence", "PersonalSkirmishOutcomes", "RivalContributions" }) do
    assert(loadfile("NamesInRed/" .. file .. ".lua"))("NamesInRed", addon)
end
local Ledger = addon.Ledger
local me, brother, bystander = "Player-me", "Player-brother", "Player-bystander"
local mage, rogue, healer, warrior = "Player-mage", "Player-rogue", "Player-healer", "Player-warrior"

local function Segment(battle, offset, duration)
    local segment = { offset = offset, duration = duration, startedAt = battle.startedAt + offset,
        actions = {}, contributionLinks = {} }
    local segments = battle.observation.segments
    segments[#segments + 1] = segment
    return segment
end

local function Fight()
    local battle = { startedAt = 100, time = 100, outcome = "loss", origin = "world",
        allies = { { id = me, isSelf = true }, { id = brother }, { id = bystander } },
        enemies = { { id = mage, rivalID = mage }, { id = rogue, rivalID = rogue },
            { id = healer, rivalID = healer }, { id = warrior, rivalID = warrior } },
        events = {}, observation = { segments = {} } }
    return battle, Segment(battle, 0, 10)
end

local function Life(battle, kind, target, offset, actor)
    local event = { kind = kind, offset = offset, time = battle.startedAt + offset, targetID = target, actorID = actor }
    battle.events[#battle.events + 1] = event
    return event
end

local function Link(segment, category, actor, target, pet)
    local link = { actorID = actor, targetID = target, category = category, petEndpoint = pet }
    segment.contributionLinks[#segment.contributionLinks + 1] = link
    return link
end

local function Control(segment, actor, target, offset, pet)
    local row = { kind = "harmful-aura", first = offset, last = offset, actorID = actor, targetID = target,
        petEndpoint = pet, targetIsPlayer = pet ~= "target" }
    segment.actions[#segment.actions + 1] = row
    return row
end

local function Credits(battle, count)
    local result = addon.EvaluateRivalContributions(battle)
    assert(result.version == 1 and #result.credits == count, #result.credits .. " credits, expected " .. count)
    return result.credits
end

-- Damage by our character (including a verified pet) with the ally's finish.
-- Overlapping categories and a duplicate notification earn a single win.
local fight, phase = Fight()
Link(phase, "DamageDone", me, mage, "actor")
Link(phase, "EnemyDamageTaken", me, mage)
Life(fight, "kill", mage, 9, brother)
Life(fight, "kill", mage, 9.1, brother)
local credit = Credits(fight, 1)[1]
assert(credit.direction == "win" and credit.rivalID == mage and credit.actorID == me)
assert(credit.deathIndex == 1 and credit.evidence.kind == "meter" and credit.evidence.petEndpoint == "actor")

-- Positive healer-only, shield-only and protective dispel cases. A link to
-- another ally and a support chain reaching only a second opponent do not qualify.
for _, category in ipairs({ "HealingDone", "Absorbs", "Dispels" }) do
    fight, phase = Fight()
    Link(phase, category, me, brother)
    Link(phase, "HealingDone", me, bystander)
    Link(phase, "DamageDone", bystander, rogue)
    Life(fight, "kill", mage, 9, brother)
    credit = Credits(fight, 1)[1]
    assert(credit.rivalID == mage and credit.evidence.kind == "support" and credit.evidence.viaID == brother)
    assert(credit.evidence.category == category and credit.evidence.viaEvidence.kind == "finishing-blow")
    Link(phase, "DamageDone", brother, rogue)
    Credits(fight, 0) -- same healer/recipient, ambiguous rival
end

-- Earlier/later unrelated windows, passive presence, an unresolved pair, and
-- a duration-mismatch fallback never authorize a support claim.
fight, phase = Fight()
phase.duration = 4
Link(phase, "HealingDone", me, brother)
local lethalPhase = Segment(fight, 6, 4)
Link(lethalPhase, "HealingDone", me, bystander)
Link(lethalPhase, "HealingDone", me, brother).corroborated = true
Link(lethalPhase, "Absorbs", me, "Player-restricted")
Link(Segment(fight, 11, 4), "HealingDone", me, brother)
Life(fight, "kill", mage, 9, brother)
Credits(fight, 0)
fight, phase = Fight()
phase.duration = 16
Link(phase, "HealingDone", me, brother)
Life(fight, "kill", mage, 9, brother)
Credits(fight, 0) -- untimed support can be entirely after the death

-- Control and independently accepted meter interrupts work with an
-- unidentified finisher; a corpse alone or a known NPC death gives no win.
fight, phase = Fight()
Control(phase, me, mage, 2, "actor")
Life(fight, "death", mage, 4)
credit = Credits(fight, 1)[1]
assert(credit.evidence.kind == "harmful-aura" and credit.evidence.petEndpoint == "actor")
Life(fight, "revive", mage, 5)
Life(fight, "death", mage, 9)
Credits(fight, 1) -- no reuse of pre-revival action
local samePair = phase.actions[1]
samePair.last = 8
Credits(fight, 2) -- known times in both lives of the same target
Link(phase, "DamageDone", me, mage)
samePair.last = 2
Credits(fight, 1) -- aggregate straddles both deaths, cannot choose a life
-- Two independent, unambiguous meter windows can each support the same
-- rival's defeat after a verified revival separates them.
fight, phase = Fight()
phase.duration = 4
Link(phase, "HealingDone", me, brother)
Link(Segment(fight, 6, 4), "Absorbs", me, brother)
Life(fight, "kill", mage, 3, brother)
Life(fight, "revive", mage, 5)
Life(fight, "kill", mage, 9, brother)
local supported = Credits(fight, 2)
assert(supported[1].deathIndex == 1 and supported[1].evidence.segmentIndex == 1)
assert(supported[2].deathIndex == 3 and supported[2].evidence.segmentIndex == 2)

fight, phase = Fight()
Link(phase, "Interrupts", me, mage)
Life(fight, "death", mage, 9)
Credits(fight, 1)
fight.events[1].pvpLinked = false
Credits(fight, 0)

-- A confirmed anonymous corpse plus an exact directed meter pair is one
-- PvP casualty in both projections, even when a second opponent survives.
local function MeterCorpse(actor)
    local battle, segment = Fight()
    battle.outcome = nil
    local units = { [me] = { dead = false, combat = false }, [rogue] = { dead = false, combat = false },
        [mage] = { dead = true, combat = false } }
    battle.observation.assessment = {}
    battle.observation.participation = { state = "finalized", boundary = "quiet-timeout",
        first = { offset = 10, units = units }, last = { offset = 12, units = units } }
    Life(battle, "death", mage, 9)
    return battle, Link(segment, "DamageDone", actor, mage)
end

local consistent, pair = MeterCorpse(me)
Credits(consistent, 1)
local personal = addon.EvaluatePersonalSkirmish(consistent)
assert(personal.casualties.enemy == 1 and personal.outcome == "win" and personal.reason == "observed-disengagement",
    "a meter-linked PvP corpse must not produce a casualty-free Draw")
local meterDB = Ledger.Open()
Ledger.SaveSkirmish(meterDB, "world:1", consistent)
consistent.personalOutcome = { version = 1, lifecycle = "finalized", outcome = "draw", casualties = { enemy = 0, friendly = 0 } }
Ledger.Open(meterDB)
assert(consistent.personalOutcome.outcome == "win" and consistent.personalOutcome.casualties.enemy == 1)
Credits(consistent, 1)
consistent, pair = MeterCorpse(brother)
Credits(consistent, 0)
assert(addon.EvaluatePersonalSkirmish(consistent).casualties.enemy == 1) -- no local credit required
pair.corroborated = true
assert(addon.EvaluatePersonalSkirmish(consistent).casualties.enemy == 0)
consistent, pair = MeterCorpse(me)
consistent.events[1].pvpLinked = false -- verified NPC death
Credits(consistent, 0)
assert(addon.EvaluatePersonalSkirmish(consistent).casualties.enemy == 0)
consistent, pair = MeterCorpse(me)
table.insert(consistent.events, 1, { kind = "death", targetID = mage, offset = 2 })
table.insert(consistent.events, 2, { kind = "revive", targetID = mage, offset = 5 })
Credits(consistent, 0)
assert(addon.EvaluatePersonalSkirmish(consistent).casualties.enemy == 0)
consistent, pair = MeterCorpse(me)
table.insert(consistent.observation.segments, { offset = 8, duration = 2, contributionLinks = { pair } })
Credits(consistent, 0)
assert(addon.EvaluatePersonalSkirmish(consistent).casualties.enemy == 0)

-- Same fight and same rival can earn both directions, even on group Defeat.
-- Attributed damage from three rivals earns three losses for one local death.
fight, phase = Fight()
Control(phase, me, mage, 2)
Life(fight, "kill", mage, 4, brother)
Life(fight, "revive", mage, 5)
Control(phase, mage, me, 6)
Control(phase, healer, me, 7, "target") -- hostile effect on our pet
local lethal = Life(fight, "kill", me, 9, rogue)
lethal.source, lethal.recapTimestamp = "death-recap", 109
lethal.recapDamage = { [mage] = 107, [warrior] = 108, [healer] = 99 }
Life(fight, "kill", me, 9.1, rogue)
local all = Credits(fight, 4)
assert(all[1].direction == "win" and all[1].rivalID == mage)
assert(all[2].direction == "loss" and all[2].rivalID == mage and all[2].deathIndex == 3)
assert(all[3].rivalID == rogue and all[3].evidence.kind == "finishing-blow")
assert(all[4].rivalID == warrior and all[4].evidence.kind == "recap-damage")
local db = Ledger.Open()
fight.rewards = { [mage] = { honorableKills = 1, honor = 5 } }
Ledger.Add(db, mage, "Mock Mage")
Ledger.SaveSkirmish(db, "world:1", fight)
local wins, losses = Ledger.RivalContributionScore(db, mage)
assert(wins == 1 and losses == 1)
local kills, deaths = Ledger.PersonalCombatScore(db, mage)
assert(kills == 0 and deaths == 0)
assert(Ledger.PersonalScore(db, mage) == 0) -- public model still holds the legacy loss
local _, oldLosses, hk, honor = Ledger.PersonalScore(db, mage)
assert(oldLosses == 1 and hk == 1 and honor == 5 and Ledger.JournalRewards(db).honor == 5)

-- The adversary who shields a demonstrated attacker may receive a loss
-- credit, while a second heal recipient with no victim link does not.
fight, phase = Fight()
Link(phase, "Absorbs", healer, rogue)
Link(phase, "HealingDone", warrior, mage)
Life(fight, "kill", me, 9, rogue)
all = Credits(fight, 2)
assert(all[1].rivalID == rogue and all[2].rivalID == healer and all[2].evidence.viaID == rogue)
fight.events[1].kind, fight.events[1].actorID = "death", nil
Credits(fight, 0) -- local NPC death with no confirmed hostile finisher

-- Known repeat local lives. Native recap time must belong to the later life
-- even when a retained earlier row is attached to the next recap.
fight, phase = Fight()
Life(fight, "kill", me, 3, rogue)
Life(fight, "revive", me, 5)
lethal = Life(fight, "kill", me, 9, rogue)
lethal.source, lethal.recapTimestamp = "death-recap", 109
lethal.recapDamage = { [mage] = 105.9, [warrior] = 106, [healer] = 110 }
all = Credits(fight, 3)
assert(all[1].rivalID == rogue and all[2].rivalID == rogue and all[3].rivalID == warrior)
assert(all[1].deathIndex == 1 and all[2].deathIndex == 3 and all[3].deathIndex == 3)

-- Historical category qualification plus retained positive amounts can be
-- used without accepting an unscoped archive or changing an original result.
fight, phase = Fight()
phase.contributionLinks = nil
phase.meter = { selection = "new-archived", sessionID = 10 }
phase.reportMeter = { status = "sampled", meterSelection = "new-archived", meterSessionID = 10,
    categories = { HealingDone = { evidence = "eligible" } } }
phase.combatAggregates = { { actorID = me, targetID = brother, category = "HealingDone", amount = 5 } }
Life(fight, "kill", mage, 9, brother)
Credits(fight, 1)
phase.reportMeter.meterSessionID = 11
Credits(fight, 0)
fight.manual = true
Credits(fight, 0)
fight, phase = Fight()
Link(phase, "DamageDone", me, mage)
Credits(fight, 0) -- non-lethal encounters never become rival wins

fight, phase = Fight()
lethal = Life(fight, "kill", me, 9, rogue)
lethal.source, lethal.recapTimestamp = "death-recap", 109
fight.combatDiagnostics = { version = 1, recaps = {
    { actorID = mage, targetID = me, recapTime = 109, recapIndex = 2, effect = "SPELL_DAMAGE", amount = 12, eventTime = 108 },
    { actorID = warrior, targetID = me, recapTime = 108, recapIndex = 2, effect = "SPELL_DAMAGE", amount = 12, eventTime = 107 },
    { actorID = healer, targetID = me, recapTime = 109, recapIndex = 3, effect = "SPELL_DAMAGE", amount = 0, eventTime = 107 },
} }
Ledger.SaveSkirmish(db, "world:2", fight)
Ledger.Open(db)
fight.combatDiagnostics = nil
Ledger.Open(db)
all = Credits(fight, 2)
assert(all[1].rivalID == mage and all[2].rivalID == rogue and lethal.recapDamage[mage] == 108)
print("Rival contribution, evidence scope, multiple life episodes and historical replay passed")
