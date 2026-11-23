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
    { Kill(me, firstEnemy, 105), Kill(me, secondEnemy, 106), Kill(thirdEnemy, helper, 110) },
    { me = retreat, c = alive }, { me = farther, c = alive },
    { me = { actorID = "c", offset = 11 } })
Expect(reversed, "loss", "observed", "pressured-withdrawal")

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
