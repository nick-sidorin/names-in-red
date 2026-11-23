local addon = {}
assert(loadfile("NamesInRed/Ledger.lua"))("NamesInRed", addon)
assert(loadfile("NamesInRed/SkirmishOutcomes.lua"))("NamesInRed", addon)

local ledger = addon.Ledger
local me = { id = "me", isSelf = true }
local helper = { id = "helper" }
local firstEnemy = { id = "a", rivalID = "a" }
local secondEnemy = { id = "b", rivalID = "b" }
local thirdEnemy = { id = "c", rivalID = "c" }

local function Kill(actor, target, at)
    return { kind = "kill", actorID = actor.id, targetID = target.id, time = at or 110 }
end

local function Seen(x, dead, combat, map)
    local position = x and { x = x, y = 100, map = map or 1 }
    return { dead = dead, combat = combat, position = position }
end

local function Battle(allies, enemies, events, first, last, pressures)
    local state = { site = { x = 100, y = 100, map = 1 }, lastAction = { offset = 10 }, checkStatus = "sampled",
        pressure = pressures, first = { at = 112, offset = 12, units = first },
        last = { at = 114, offset = 14, units = last } }
    return { allies = allies, enemies = enemies, events = events, rosterComplete = false,
        observation = { assessment = state, life = {}, segments = {} } }
end

local function Expect(battle, outcome, ending, reason)
    local resolution = addon.EvaluateWorldSkirmish(battle)
    assert(resolution.outcome == outcome, tostring(resolution.outcome) .. " from " .. resolution.reason)
    assert(resolution.ending == ending, resolution.reason)
    if reason then assert(resolution.reason == reason, resolution.reason) end
    return resolution
end

local alive = Seen(100, false, false)
local corpse = Seen(100, true, false)
local retreat, farther = Seen(159, false, false), Seen(168, false, false)
local west = Seen(40, false, false)

-- A directly observed 1 × 1 ending can use terminal life/combat states if
-- coordinates are unavailable. A death by itself cannot supply a score.
local visibleSurvivor = Seen(nil, false, false)
local soloWin = Battle({ me }, { firstEnemy }, { Kill(me, firstEnemy) }, { me = visibleSurvivor }, { me = visibleSurvivor })
soloWin.observation.assessment.site = nil
Expect(soloWin, "win", "observed", "defeated-side-observed")
local soloLoss = Battle({ me }, { firstEnemy }, { Kill(firstEnemy, me) },
    { a = visibleSurvivor }, { a = visibleSurvivor })
soloLoss.observation.assessment.site = nil
Expect(soloLoss, "loss", "observed", "defeated-side-observed")
soloLoss.observation.assessment.last = nil
Expect(soloLoss, nil, "unknown", "missing-terminal-observations")

local groupWin = Battle({ me, helper }, { firstEnemy, secondEnemy, thirdEnemy },
    { Kill(me, firstEnemy), Kill(me, secondEnemy) },
    { me = alive, helper = alive, c = retreat }, { me = alive, helper = alive, c = farther },
    { c = { actorID = "helper", offset = 10 } })
local resolution = Expect(groupWin, "win", "observed", "pressured-withdrawal")
assert(resolution.enemies.dead == 2 and resolution.enemies.away == 1 and resolution.favorsVictory)
assert(not groupWin.rosterComplete and not ledger.FirstDeaths(groupWin).c)

-- Two old, confirmed kills must still count at a late ending. A later
-- visible survivor or explicit resurrection defeats only the current death state.
local longFight = Battle({ me, helper }, { firstEnemy, secondEnemy, thirdEnemy },
    { Kill(me, firstEnemy, 110), Kill(helper, secondEnemy, 120) },
    { me = alive, helper = alive, c = retreat }, { me = alive, helper = alive, c = farther },
    { c = { actorID = "me", offset = 40 } })
local ending = longFight.observation.assessment
ending.lastAction.offset = 40
ending.first.at, ending.first.offset, ending.last.at, ending.last.offset = 142, 42, 144, 44
assert(Expect(longFight, "win", "observed", "pressured-withdrawal").enemies.dead == 2)
ending.first.units.a = Seen(nil, false, false)
assert(Expect(longFight, nil, "unknown").enemies.dead == 1)
ending.first.units.a = nil
longFight.events[3] = { kind = "revive", targetID = "b", time = 135 }
assert(Expect(longFight, nil, "unknown").enemies.dead == 1)
longFight.events[3] = { kind = "revive", targetID = "b", time = 150 }
assert(Expect(longFight, "win", "observed").enemies.dead == 2)
longFight.events[3] = nil

-- The withdrawing player is only briefly readable around the measured
-- range boundary. The final sample observes the holders, with no enemy token.
local exit = Seen(nil, false, false)
exit.rangeExit = true
ending.first.units.c, ending.last.units.c = exit, nil
ending.pressure.c.range = { upper = 40, spell = 681, origin = alive.position }
local rangeResult = Expect(longFight, "win", "observed", "pressured-range-withdrawal")
assert(rangeResult.enemies.dead == 2 and rangeResult.enemies.rangeWithdrawn == 1)
assert(not ledger.FirstDeaths(longFight).c)

ending.pressure.c.offset = 25
assert(Expect(longFight, nil, "unknown", "withdrawal-not-corroborated").enemies.dead == 2)
ending.pressure.c.offset = 40
ending.last.units.c = Seen(nil, false, false)
ending.last.units.c.rangeExit = false
Expect(longFight, nil, "unknown")
ending.last.units.c = Seen(104, false, false)
ending.last.units.c.rangeExit = true
Expect(longFight, nil, "unknown") -- contradictory direct position
ending.last.units.c = nil

ending.first.units.c = nil
Expect(longFight, nil, "unknown", "participant-state-or-position-unavailable") -- vanished with no visible exit
ending.lastAction.offset = 43
Expect(longFight, nil, "ongoing", "later-hostility") -- stealth followed by re-entry
ending.lastAction.offset, ending.first.units.c = 40, exit

ending.first.units.me, ending.last.units.me = west, west
ending.first.units.helper, ending.last.units.helper = west, west
Expect(longFight, nil, "unknown") -- retreating observer cannot establish the point was held
ending.first.units.me, ending.last.units.me = corpse, corpse
ending.first.units.helper, ending.last.units.helper = nil, nil
longFight.observation.playerState = "ghost"
ending.interrupted = "area-changed"
Expect(longFight, nil, "unknown", "area-changed")

local groupLoss = Battle({ me, helper }, { firstEnemy, secondEnemy }, { Kill(firstEnemy, helper) },
    { me = retreat, a = alive, b = alive }, { me = farther, a = alive, b = alive },
    { me = { actorID = "a", offset = 10 } })
Expect(groupLoss, "loss", "observed", "pressured-withdrawal")

local corpseWin = Battle({ me, helper }, { firstEnemy, secondEnemy },
    { Kill(firstEnemy, me, 106), Kill(helper, firstEnemy, 109), Kill(helper, secondEnemy, 112) },
    { me = corpse, helper = alive }, { me = corpse, helper = alive })
corpseWin.observation.playerState = "ghost"
assert(Expect(corpseWin, "win", "observed").localLife == "ghost")

local advantageAtDeath = Battle({ me, helper }, { firstEnemy, secondEnemy, thirdEnemy },
    { Kill(me, firstEnemy), Kill(me, secondEnemy), Kill(thirdEnemy, me) },
    { me = corpse }, { me = corpse })
advantageAtDeath.observation.playerState = "ghost"
assert(Expect(advantageAtDeath, nil, "unknown").coverage == "partial")
advantageAtDeath.observation.assessment.interrupted = "area-changed"
Expect(advantageAtDeath, nil, "unknown", "area-changed")

local reversed = Battle({ me, helper }, { firstEnemy, secondEnemy, thirdEnemy },
    { Kill(me, firstEnemy, 110), Kill(me, secondEnemy, 120), Kill(thirdEnemy, helper, 140) },
    { me = retreat, c = alive }, { me = farther, c = alive },
    { me = { actorID = "c", offset = 41 } })
local lateLoss = reversed.observation.assessment
lateLoss.lastAction.offset, lateLoss.first.at, lateLoss.first.offset = 41, 142, 42
lateLoss.last.at, lateLoss.last.offset = 144, 44
assert(Expect(reversed, "loss", "observed", "pressured-withdrawal").enemies.dead == 2)

local mutual = Battle({ me }, { firstEnemy }, {},
    { me = west, a = retreat }, { me = west, a = farther })
Expect(mutual, nil, "observed", "both-sides-left-site")

local stealth = Battle({ me, helper }, { firstEnemy, secondEnemy }, { Kill(me, firstEnemy) },
    { me = alive, helper = alive }, { me = alive, helper = alive })
Expect(stealth, nil, "unknown", "participant-state-or-position-unavailable")
stealth.observation.assessment.lastAction.offset = 13
Expect(stealth, nil, "ongoing", "later-hostility")
stealth.observation.assessment.lastAction.offset = 10
stealth.observation.assessment.last.units.b = Seen(101, false, true)
Expect(stealth, nil, "unknown", "participants-still-in-combat")

local noKillWin = Battle({ me }, { firstEnemy }, {}, { me = alive, a = retreat }, { me = alive, a = farther },
    { a = { actorID = "me", offset = 10 } })
Expect(noKillWin, "win", "observed", "pressured-withdrawal")
local noKillLoss = Battle({ me }, { firstEnemy }, {}, { me = retreat, a = alive }, { me = farther, a = alive },
    { me = { actorID = "a", offset = 10 } })
Expect(noKillLoss, "loss", "observed", "pressured-withdrawal")
noKillWin.observation.assessment.offense = { a = 11 }
Expect(noKillWin, nil, "unknown", "withdrawal-not-corroborated")
noKillWin.observation.assessment.pressure = {}
Expect(noKillWin, nil, "unknown", "withdrawal-not-corroborated")
noKillWin.observation.assessment.last.units.a = Seen(60, false, false)
Expect(noKillWin, nil, "unknown", "participant-state-or-position-unavailable")

-- A late live sample can invalidate a death or a once-plausible ending.
local revived = Battle({ me }, { firstEnemy }, { Kill(me, firstEnemy) }, { me = alive, a = corpse },
    { me = alive, a = alive })
Expect(revived, nil, "unknown")

local saved = ledger.Open(nil)
local rewards = { a = { honorableKills = 2, honor = 5 } }
groupWin.rewards = rewards
local first, last = groupWin.observation.assessment.first, groupWin.observation.assessment.last
groupWin.observation.assessment.last = nil
ledger.SaveSkirmish(saved, "world:1", groupWin)
local wins, losses, hk, honor = ledger.PersonalScore(saved, "a")
assert(wins == 0 and losses == 0 and hk == 2 and honor == 5)
groupWin.observation.assessment.first, groupWin.observation.assessment.last = first, last
ledger.SaveSkirmish(saved, "world:1", groupWin)
ledger.SaveSkirmish(saved, "world:1", groupWin)
for _, enemy in ipairs(groupWin.enemies) do
    wins, losses = ledger.PersonalScore(saved, enemy.rivalID)
    assert(wins == 1 and losses == 0 and #ledger.RivalSkirmishes(saved, enemy.rivalID) == 1)
end
wins, losses, hk, honor = ledger.PersonalScore(saved, "a")
assert(wins == 1 and losses == 0 and hk == 2 and honor == 5)

local legacy = { allies = { me }, enemies = { firstEnemy }, events = { Kill(me, firstEnemy) },
    observation = { segments = {}, life = {} } }
ledger.SaveSkirmish(saved, "world:2", legacy)
ledger.SaveSkirmish(saved, "manual:1", { manual = true, outcome = "loss",
    allies = { me }, enemies = { firstEnemy }, events = {} })
assert(ledger.Open(saved) == saved)
assert(ledger.SkirmishOutcome(legacy) == "win")
wins, losses = ledger.PersonalScore(saved, "a")
assert(wins == 2 and losses == 1)
print("Terminal evidence, unresolved endings, withdrawal rules, idempotent statistics and legacy scores passed")
