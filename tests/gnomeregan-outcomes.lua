local addon = {}
for _, file in ipairs({ "Ledger", "Encounter", "SkirmishOutcomes" }) do
    assert(loadfile("NamesInRed/" .. file .. ".lua"))("NamesInRed", addon)
end
local me, rival, friend, other = "Player-test-local", "Player-test-rival", "Player-test-ally", "Player-test-other"
local function Solo()
    return {
        origin = "world", rosterComplete = true,
        allies = { { id = me, isSelf = true } }, enemies = { { id = rival } },
        events = { { kind = "kill", actorID = rival, targetID = me, source = "death-recap", time = 99, offset = 0 } },
        observation = { playerState = "ghost", segments = {
            { startReason = "death", endReason = "standalone-event", confirmedBy = "kill" },
        }, assessment = { interrupted = "area-changed", checkStatus = "sampled",
            lastAction = { kind = "kill", actorID = rival, targetID = me, offset = 0 },
            last = { at = 103, offset = 2.75, units = { [me] = { dead = true },
                [rival] = { dead = false, combat = true } } },
        } },
    }
end
local battle = Solo()
local result = addon.EvaluateWorldSkirmish(battle)
assert(result.outcome == "loss" and result.reason == "isolated-lethal-recap" and result.interrupted == "area-changed")
battle.allies[2] = { id = friend }
assert(not addon.EvaluateWorldSkirmish(battle).outcome)
battle = Solo()
battle.observation.assessment.lastMeterActivity = 1
assert(not addon.EvaluateWorldSkirmish(battle).outcome)
battle = Solo()
battle.events[1].actorID = "Creature-npc"
assert(not addon.EvaluateWorldSkirmish(battle).outcome)
battle = Solo()
battle.events[2] = { kind = "revive", targetID = me, time = 101, offset = 1 }
assert(not addon.EvaluateWorldSkirmish(battle).outcome)

local function Holder(x, y)
    return { dead = false, combat = false, position = { x = x, y = y, map = 0 } }
end
battle = {
    origin = "world", allies = { { id = me, isSelf = true }, { id = friend } },
    enemies = { { id = rival }, { id = other } },
    events = {
        { kind = "death", targetID = other, time = 130, offset = 29, source = "nameplate-removed" },
        { kind = "kill", actorID = friend, targetID = rival, time = 134, offset = 32.5 },
    },
    observation = { segments = { { endedAt = 139, endReason = "local-combat-ended" } }, assessment = {
        lastAction = { kind = "kill", actorID = friend, targetID = rival, offset = 32.5 },
        first = { at = 140, offset = 37.75, units = { [me] = Holder(-5073, 779), [friend] = Holder(-5078, 778) } },
        last = { at = 142, offset = 39.75, units = { [me] = Holder(-5073, 779), [friend] = Holder(-5085, 772) } },
    } },
}
result = addon.EvaluateWorldSkirmish(battle)
assert(result.outcome == "win" and result.reason == "side-eliminated-stable-survivors")
battle.events[1] = { kind = "revive", targetID = other, offset = 29, time = 130 }
assert(not addon.EvaluateWorldSkirmish(battle).outcome)
battle.observation.assessment.last.units[other] = { dead = false, combat = true }
assert(addon.EvaluateWorldSkirmish(battle).reason == "participants-still-in-combat")

local raw, effective = 60, -1
function UnitLevel() return raw end
function UnitEffectiveLevel() return effective end
assert(addon.UnitAppearance("target").level == -1)
effective = 60
assert(addon.UnitAppearance("target").level == 60)
raw, effective = nil, nil
assert(addon.UnitAppearance("target").level == nil)
local secret = {}
function issecretvalue(value) return rawequal(value, secret) end
raw, effective = secret, secret
assert(addon.UnitAppearance("target").level == nil)
print("Gnomeregan isolated lethal recap, group elimination, and readable skull levels passed")
