local addon = {}
for _, file in ipairs({ "Ledger", "SkirmishOutcomes", "SkirmishDeathEvidence", "PersonalSkirmishOutcomes" }) do
    assert(loadfile("NamesInRed/" .. file .. ".lua"))("NamesInRed", addon)
end
local me, ally, enemy, second, third = "Player-me", "Player-ally", "Player-enemy", "Player-second", "Player-third"
local function Battle(friend, ...)
    local battle = { origin = "world", startedAt = 100, allies = { { id = me, isSelf = true } },
        enemies = { { id = enemy } }, events = {},
        observation = { assessment = {}, segments = { { startedAt = 100, confirmedBy = "harmful-aura" } } } }
    if friend then battle.allies[2] = { id = ally } end
    for _, id in ipairs({ ... }) do battle.enemies[#battle.enemies + 1] = { id = id } end
    return battle
end

local function Event(battle, kind, offset, target, actor, source)
    local event = { kind = kind, time = 100 + offset, offset = offset, targetID = target, actorID = actor, source = source }
    battle.events[#battle.events + 1] = event
    return event
end

local function Ending(battle, at, ...)
    local units = {}
    for _, id in ipairs({ ... }) do units[id] = { combat = false, dead = false } end
    local state = battle.observation.participation or battle.observation.assessment
    state.first = { at = 100 + at, offset = at, units = units }
    state.last = { at = 102 + at, offset = at + 2, units = units }
    return units
end

local function Verify(battle, expected, reason, friendly, enemyDeaths)
    local result = addon.EvaluatePersonalSkirmish(battle)
    assert(result.lifecycle == "finalized" and result.version == 2)
    assert(result.outcome == expected, tostring(result.outcome) .. " instead of " .. expected .. " (" .. reason .. ")")
    assert(result.reason == reason, result.reason .. " instead of " .. reason)
    assert(result.casualties.friendly == friendly and result.casualties.enemy == enemyDeaths)
    return result
end

-- Solo terminal death takes precedence over the favorable partial tally.
local fight = Battle(false, second, third)
Event(fight, "kill", 1, enemy, me)
Event(fight, "kill", 2, second, me)
Event(fight, "kill", 3, me, third, "death-recap")
Verify(fight, "loss", "terminal-personal-death", 1, 2)
Ending(fight, 4, third)
Verify(fight, "loss", "friendly-elimination", 1, 2)

-- Two losses in the same ally's lives, followed by real enemy elimination.
fight = Battle(true)
Event(fight, "kill", 1, ally, enemy)
Event(fight, "revive", 2, ally)
Event(fight, "kill", 3, ally, enemy)
Event(fight, "death", 3.1, ally) -- duplicate corpse
Event(fight, "kill", 4, enemy, me)
Ending(fight, 5, me)
Verify(fight, "win", "enemy-elimination", 2, 1)

fight = Battle(true)
Event(fight, "kill", 1, me, enemy)
Event(fight, "kill", 2, enemy, ally)
Ending(fight, 4, ally)
Verify(fight, "win", "enemy-elimination", 1, 1)
local samples = fight.observation.assessment
samples.last = nil
Verify(fight, "loss", "terminal-personal-death", 1, 1)

-- Missing final reads preserve an earlier observed ending; readable renewed
-- combat by the revived rival invalidates the earlier snapshots.
fight = Battle(true)
Event(fight, "kill", 1, me, enemy)
Event(fight, "kill", 2, enemy, ally)
fight.observation.participation = { state = "finalized", boundary = "quiet-timeout" }
Ending(fight, 3, ally)
local participation = fight.observation.participation
participation.lateFirst = { offset = 10, units = {} }
participation.lateLast = { offset = 12, units = {} }
Verify(fight, "win", "enemy-elimination", 1, 1)
participation.lateLast.units[enemy] = { dead = false, combat = true }
Verify(fight, "loss", "terminal-personal-death", 1, 1)

-- A dead character may observe an ordinary ending with surviving enemies.
fight = Battle(true, second, third)
Event(fight, "kill", 1, enemy, me)
Event(fight, "kill", 2, me, third, "death-recap")
Event(fight, "kill", 3, second, ally)
Ending(fight, 4, ally)
Verify(fight, "loss", "terminal-personal-death", 1, 2)
Ending(fight, 4, ally, third)
Verify(fight, "win", "observed-disengagement", 1, 2)

fight = Battle(false)
Event(fight, "kill", 1, me, enemy)
Event(fight, "kill", 1.1, enemy, me) -- a previously launched attack can be lethal
Ending(fight, 2)
Verify(fight, "draw", "mutual-elimination", 1, 1)

fight = Battle(false, second)
Event(fight, "kill", 1, enemy, me)
Ending(fight, 2, me, second)
Verify(fight, "win", "observed-disengagement", 0, 1)
fight = Battle(false)
Ending(fight, 2, me, enemy)
Verify(fight, "draw", "observed-disengagement", 0, 0)
fight.observation.assessment.last = nil
Verify(fight, "unknown", "insufficient-ending-evidence", 0, 0)
fight.observation.participation = { state = "active" }
assert(addon.EvaluatePersonalSkirmish(fight).lifecycle == "active" and not addon.EvaluatePersonalSkirmish(fight).outcome)
fight.observation.participation.state = "awaiting"
assert(addon.EvaluatePersonalSkirmish(fight).lifecycle == "awaiting" and not addon.EvaluatePersonalSkirmish(fight).outcome)

-- The same tally has different meanings after an observed revival and a live return.
fight = Battle(false, second)
Event(fight, "kill", 1, me, enemy, "death-recap").recapTimestamp = 101
Event(fight, "kill", 1.2, me, second, "death-recap").recapTimestamp = 101
Event(fight, "revive", 3, me)
fight.observation.participation = { state = "finalized", boundary = "left-world" }
Ending(fight, 5, me)
local outcome = Verify(fight, "loss", "terminal-personal-death", 1, 0)
assert(outcome.life[me] == "alive" and outcome.boundary == "left-world")
fight.observation.participation.returnedAt = 4
Verify(fight, "loss", "observed-disengagement", 1, 0)
fight.observation.participation.last = nil
Verify(fight, "unknown", "insufficient-ending-evidence", 1, 0)

-- A participant's unrelated NPC death and a bystander's death do not enter the tally.
fight = Battle(true, second)
Event(fight, "death", 1, ally, nil, "unit-flags")
Event(fight, "kill", 2, "Player-bystander", enemy)
Event(fight, "death", 3, me, nil, "unit-flags")
Event(fight, "death", 4, enemy, nil, "corroborated-corpse").pvpLinked = true
Event(fight, "kill", 4.1, enemy, ally)
Event(fight, "revive", 5, enemy)
Event(fight, "kill", 6, enemy, me)
Ending(fight, 7, me, second)
Verify(fight, "win", "observed-disengagement", 0, 2)

-- Older pair summaries retain their two witnessed endpoints. An unknown
-- middle action cannot link a corpse in the next life.
fight = Battle(false, second)
fight.observation.segments[1].actions = {
    { actorID = me, targetID = enemy, kind = "harmful-aura", first = 1, last = 9, count = 3 },
}
Event(fight, "death", 2, enemy)
Event(fight, "revive", 4, enemy)
Event(fight, "death", 5, enemy)
Ending(fight, 10, me, second)
Verify(fight, "win", "observed-disengagement", 0, 1)

-- A stale alive read just after PARTY_KILL cannot split duplicate kills into
-- two lives during evaluation of retained observations.
fight = Battle(false)
Event(fight, "kill", 1, enemy, me, "party-kill")
Event(fight, "kill", 1.4, enemy, me, "party-kill")
local stale = fight.observation.assessment
stale.first = { offset = 1.1, units = { [enemy] = { dead = false, combat = false } } }
stale.last = { offset = 1.35, units = { [enemy] = { dead = false, combat = false } } }
Verify(fight, "unknown", "insufficient-ending-evidence", 0, 1)

-- Replay the durable historical shapes recorded in Forever validation.
-- world:4 has an uncorroborated Paladin snapshot and one confirmed killing blow.
local world4 = Battle(true, second)
world4.enemies[2].class = "PALADIN"
local phase = world4.observation.segments[1]
phase.endedAt, phase.endReason = 139, "local-combat-ended"
phase.contacts = { [second] = { signal = "nameplate-removed", last = 28.043, dead = true } }
Event(world4, "kill", 32.494, enemy, ally, "party-kill")
world4.observation.assessment.lastAction = { actorID = ally, targetID = enemy, offset = 32.494, kind = "kill" }
local holders = Ending(world4, 39.631, me, ally)
holders[me].position, holders[ally].position = { x = -5073, y = 779, map = 0 }, { x = -5078, y = 778, map = 0 }
world4.observation.assessment.last.offset = 41.628
Verify(world4, "win", "observed-disengagement", 0, 1)

local world7 = Battle(true, second, third)
Event(world7, "kill", 3.483, enemy, ally, "party-kill")
Event(world7, "kill", 6.262, me, third, "death-recap")
Event(world7, "death", 16.970, second, nil, "unit-flags")
Event(world7, "death", 17.528, ally, nil, "unit-flags")
world7.observation.assessment.lastAction = { kind = "harmful-aura", actorID = third, targetID = ally, offset = 13.524 }
world7.observation.assessment.lastMeterActivity = 18.651
world7.observation.assessment.interrupted = "area-changed"
Verify(world7, "loss", "terminal-personal-death", 2, 1)

local world14 = Battle(false, second, third)
Event(world14, "kill", 16.166, me, enemy, "death-recap")
world14.observation.assessment.interrupted = "area-changed"
Verify(world14, "loss", "terminal-personal-death", 1, 0)

local saved = { version = 1, rivals = {}, skirmishes = {
    ["world:4"] = world4, ["world:7"] = world7, ["world:14"] = world14,
    ["manual:1"] = { manual = true, outcome = "win", allies = {}, enemies = {}, events = {}, observation = { assessment = {} } },
} }
addon.Ledger.Open(saved)
assert(world4.resolution.reason == "site-anchor-missing" and not world4.resolution.outcome)
assert(not world7.resolution.outcome and not world14.resolution.outcome)
assert(not saved.skirmishes["manual:1"].personalOutcome)
assert(#world4.events == 1 and world4.personalOutcome.outcome == "win")
assert(#world7.events == 4 and world7.personalOutcome.outcome == "loss")
assert(#world14.events == 1 and world14.personalOutcome.outcome == "loss")
local shown, qualifier = addon.Ledger.JournalOutcome(world4)
assert(shown == "win" and not qualifier)
assert(addon.Ledger.JournalOutcome(world7) == "loss")
assert(addon.Ledger.JournalOutcome(world14) == "loss")
shown, qualifier = addon.Ledger.JournalOutcome(saved.skirmishes["manual:1"])
assert(shown == "win" and qualifier == "manual")
local derived = world7.personalOutcome
addon.Ledger.Open(saved)
assert(world7.personalOutcome == derived and world7.personalOutcome.boundary == "area-changed")

fight = Battle(false)
fight.observation.participation = { state = "awaiting" }
addon.Ledger.SaveSkirmish(saved, "world:15", fight)
assert(fight.personalOutcome.lifecycle == "awaiting")
addon.Ledger.Open(saved)
assert(fight.personalOutcome.outcome == "unknown" and fight.personalOutcome.boundary == "reload")
print("Personal outcome priorities, distinct casualties and historical projections passed")
