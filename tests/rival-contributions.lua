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

-- Build a long existing history before the first hot-path demand. Repeated
-- nameplate/tooltip queries must reuse each battle's projected evidence.
local evaluate = addon.EvaluateRivalContributions
local evaluations = 0
addon.EvaluateRivalContributions = function(battle)
    evaluations = evaluations + 1
    return evaluate(battle)
end
local archive = Ledger.Open()
local rival = Ledger.Add(archive, mage, "Mock Mage")
local legacyGroup = { time = 80, outcome = "loss", honor = 12 }
local manualWin = { manual = true, direction = "killsAgainstThem" }
local legacyDirect = { time = 90, direction = "killsAgainstThem", honorableKills = 1, honor = 3 }
local undated = { direction = "deathsToThem" }
rival.encounters = { legacyGroup, manualWin, legacyDirect, undated }
local length = 1050
for index = 1, length do
    local battle = Fight()
    battle.startedAt, battle.time = index * 100, index * 100
    battle.outcome, battle.observation = nil, nil
    battle.enemies = { battle.enemies[1] }
    battle.personalOutcome = { version = 2, lifecycle = "finalized", outcome = "loss" }
    battle.rewards = { [mage] = { honorableKills = 1, honor = 2 } }
    Life(battle, "kill", mage, 4, me)
    Ledger.SaveSkirmish(archive, "archive:" .. index, battle)
end
assert(evaluations == 0)

local function Score(w, l)
    local wins, losses = Ledger.RivalContributionScore(archive, mage)
    assert(wins == w and losses == l, ("%d, %d; expected %d, %d"):format(wins, losses, w, l))
end

Score(length + 1, 0)
assert(evaluations == length and #Ledger.RivalSkirmishes(archive, mage) == length)
local function AssertTotals(w, l, directKills, directDeaths)
    Score(w, l)
    local kills, deaths = Ledger.PersonalCombatScore(archive, mage)
    assert(kills == directKills and deaths == directDeaths)
    local hk, honor = Ledger.RivalRewards(archive, mage)
    assert(hk == length + 1 and honor == 2 * length + 15)
    local manualWins, manualLosses, legacyWins, legacyLosses = Ledger.RivalHistoryContext(archive, mage)
    assert(manualWins == 1 and manualLosses == 0 and legacyWins == 0 and legacyLosses == 1)
end
for _ = 1, 300 do
    AssertTotals(length + 1, 0, length + 1, 1)
    assert(Ledger.RivalContributionScore(archive, "Player-absent") == 0)
end

local first = archive.skirmishes["archive:1"]
assert(Ledger.SkirmishContributionEvidence(archive, "archive:1", first).credits[1].rivalID == mage)
assert(evaluations == length)

-- A late qualification on a reused table adds one assisted win after a
-- revive and one loss. It leaves the original direct kill and side untouched.
Life(first, "revive", mage, 5)
Life(first, "kill", mage, 9, brother)
Life(first, "kill", me, 11, mage)
first.observation = { segments = {} }
Link(Segment(first, 6, 4), "HealingDone", me, brother)
Ledger.SaveSkirmish(archive, "archive:1", first)
assert(evaluations == length + 1 and first.personalOutcome.outcome == "loss")
AssertTotals(length + 2, 1, length + 1, 2)
local last = Fight()
last.time, last.startedAt = 200000, 200000
last.enemies = { last.enemies[2] }
Life(last, "kill", rogue, 7, me)
Ledger.SaveSkirmish(archive, "archive:new", last)
assert(evaluations == length + 2 and Ledger.RivalContributionScore(archive, rogue) == 1)
Ledger.RemoveSkirmish(archive, "archive:1")
Score(length, 0)
assert(evaluations == length + 2 and #Ledger.RivalSkirmishes(archive, mage) == length - 1)

-- Repeat reload from the same SavedVariables. The original rows and their
-- fields survive, and a cold rebuild yields the same score each time.
for i = 1, 2 do
    assert(Ledger.Open(archive) == archive and rival.encounters[4] == undated)
    assert(rival.encounters[1] == legacyGroup and legacyGroup.outcome == "loss")
    assert(rival.encounters[2] == manualWin and manualWin.time == nil)
    assert(rival.encounters[3] == legacyDirect and legacyDirect.outcome == nil)
    Score(length, 0)
    assert(evaluations == length + 2 + length * i)
end
Ledger.Remove(archive, rogue)
assert(Ledger.RivalContributionScore(archive, rogue) == 0)
assert(evaluations == 3 * length + 3)
assert(archive.skirmishes["archive:new"] == last and #last.events == 1 and last.enemies[1].id == rogue)
Score(length, 0)
Ledger.Clear(archive)
Score(0, 0)
assert(not next(archive.rivals) and not archive.skirmishes)
assert(evaluations == 3 * length + 3)
print("Character POV score index keeps 1,050 battles, updates affected records only, and rebuilds on reload")

local world16 = dofile("tests/fixtures/world16.lua")
local function RetainedLocalDeath()
    return world16(me, mage)
end

local stored, storedPhase, rawDeath = RetainedLocalDeath()
local oldProjection = stored.personalOutcome
local archiveID = "world:16"
local restored = Ledger.Open()
restored.skirmishes = { [archiveID] = stored }
Ledger.Add(restored, mage, "Mock Warlock")
-- Seed the already warmed index with the previous evaluator's known zero.
local currentEvaluator = addon.EvaluateRivalContributions
addon.EvaluateRivalContributions = function() return { version = 1, credits = {} } end
local win, loss = Ledger.RivalContributionScore(restored, mage)
assert(win == 0 and loss == 0)
addon.EvaluateRivalContributions = currentEvaluator
for _ = 1, 2 do
    assert(Ledger.Open(restored) == restored)
    assert(stored.personalOutcome ~= oldProjection and stored.personalOutcome.version == 3)
    assert(stored.personalOutcome.finalizedBy == "historical" and stored.personalOutcome.boundary == "area-changed")
    assert(Ledger.JournalOutcome(stored) == "loss" and stored.personalOutcome.casualties.friendly == 1)
    win, loss = Ledger.RivalContributionScore(restored, mage)
    assert(win == 0 and loss == 1)
    local credits = Ledger.SkirmishContributionEvidence(restored, archiveID, stored).credits
    assert(#credits == 1 and credits[1].evidence.category == "DamageTaken" and credits[1].deathIndex == 1)
    local summary = Ledger.RivalSkirmishes(restored, mage)[1]
    assert(summary.contributionLosses == 1 and summary.contributionWins == 0)
    local hk, honor = Ledger.RivalRewards(restored, mage)
    assert(hk == 1 and honor == 5 and Ledger.PersonalCombatScore(restored, mage) == 0)
    assert(#stored.events == 1 and stored.events[1] == rawDeath and not rawDeath.actorID and not rawDeath.pvpLinked)
    assert(#storedPhase.combatAggregates == 6 and storedPhase.combatAggregates[1].amount == 716)
end

local function Rejected(change)
    local battle, segment, death = RetainedLocalDeath()
    change(battle, segment, death)
    local analysis = addon.AnalyzeSkirmishLives(battle)
    assert(analysis.counts.friendly == 0, analysis.episodes[1] and analysis.episodes[1].qualification)
    Credits(battle, 0)
end
Rejected(function(_, segment) segment.reportMeter.meterSelection = "new-archived" end)
Rejected(function(_, segment) segment.reportMeter.categories.DamageTaken.evidence = "eligible-corroborated" end)
Rejected(function(_, segment) segment.reportMeter.categories.DamageTaken.counts["target-not-player"] = 1 end)
Rejected(function(_, segment) segment.duration = 18 end) -- prior unrelated damage
Rejected(function(_, segment)
    segment.contributionLinks = {}
    Link(segment, "DamageDone", mage, me, "target") -- our pet
end)
Rejected(function(_, segment)
    segment.contributionLinks = {}
    Link(segment, "Interrupts", mage, me) -- hostile, but no incoming damage
    Link(segment, "DamageTaken", mage, me).corroborated = true -- weaker duration-mismatch fallback
end)
Rejected(function(battle, segment) Segment(battle, 0, segment.duration) end) -- two plausible windows
Rejected(function(battle)
    battle.observation.assessment.first.units[mage].combat = false
end)
Rejected(function(battle)
    table.insert(battle.events, 1, { kind = "death", targetID = me, offset = 8 })
    table.insert(battle.events, 2, { kind = "revive", targetID = me, offset = 12 })
end)
Rejected(function(battle, _, death)
    Life(battle, "kill", me, death.offset, "Creature-lethal")
end)
Rejected(function(_, _, death) death.pvpLinked = false end)

-- Preserve the already established credit from a previous life after a
-- genuine return clears the previous global sample. Outcome then uses the
-- actual later ending rather than the old personal-death boundary.
local resumed, priorPhase = RetainedLocalDeath()
priorPhase.localDeathWitnesses = { [mage] = 26.274 }
Life(resumed, "revive", me, 29)
local resumedPhase = Segment(resumed, 31, 12)
Control(resumedPhase, me, mage, 2)
Life(resumed, "kill", mage, 38, me)
Life(resumed, "revive", mage, 40)
local terminalUnits = { [me] = { dead = false, combat = false }, [mage] = { dead = false, combat = false } }
resumed.observation.assessment = {}
resumed.observation.participation = { state = "finalized", boundary = "quiet-timeout", returnedAt = 33,
    first = { offset = 45, units = terminalUnits }, last = { offset = 47, units = terminalUnits } }
local afterReturn = addon.EvaluatePersonalSkirmish(resumed)
assert(afterReturn.outcome == "draw" and afterReturn.casualties.friendly == 1 and afterReturn.casualties.enemy == 1)
local opposite = Credits(resumed, 2)
assert(opposite[1].direction == "loss" and opposite[2].direction == "win")
resumed.observation.participation.boundary = nil
assert(addon.EvaluatePersonalSkirmish(resumed).finalizedBy == "boundary-unavailable")
print("Local PvP death from terminal incoming damage, negative evidence guards and preview history upgrade passed")
