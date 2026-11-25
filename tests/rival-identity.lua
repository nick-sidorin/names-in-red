local addon = {}
for _, file in ipairs({ "Ledger", "SkirmishDeathEvidence", "PersonalSkirmishOutcomes", "RivalContributions", "Encounter" }) do
    assert(loadfile("NamesInRed/" .. file .. ".lua"))("NamesInRed", addon)
end

local ledger = addon.Ledger
local home, rivalID = "Player-100-00000001", "Player-100-00000002"
function UnitGUID() return home end
function RegionalUniqueNamesEnabled() return true end
function GetServerTime() return 200 end

addon.db = ledger.Open()
ledger.Add(addon.db, rivalID, "Ёжик Лесной")
addon.RecordSkirmish("world:1", {
    time = 100, allies = { { id = home, isSelf = true } },
    enemies = { { id = rivalID, rivalID = rivalID, name = "Ёжик Лесной" } },
    events = { { kind = "kill", actorID = home, targetID = rivalID, time = 100, offset = 1 } },
    rewards = { [rivalID] = { honorableKills = 1, honor = 6 } },
})
assert(addon.AddManualEncounter("  ёжик\194\160 ЛЕСНОЙ ", "killsAgainstThem") == rivalID,
    "typed full name created a second profile for the known rival")
assert(not next(addon.db.rivals, rivalID))
assert(addon.db.rivals[rivalID].displayName == "Ёжик Лесной")

local targetID
function UnitGUID(unit) return unit == "player" and home or targetID end
function UnitIsPlayer(unit) return unit == "target" end
function UnitName() return "Старый", "Друг" end

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = Copy(item) end
    return result
end

local provisional = assert(addon.AddManualEncounter("Старый Друг", "killsAgainstThem"))
assert(provisional:match("^manual:"))
assert(addon.AddManualEncounter("СТАРЫЙ  ДРУГ", "deathsToThem") == provisional)
targetID = "Player-200-00000003"
addon.ResolveRivalName("target")
assert(not addon.db.rivals[provisional] and #addon.db.rivals[targetID].encounters == 2)
assert(addon.db.rivals[targetID].displayName == "Старый Друг")
assert(addon.AddManualEncounter("старый друг", "deathsToThem") == targetID)

local liveID = "Player-100-00000004"
local beforeCombat = addon.AddManualEncounter("Glowing Ember", "killsAgainstThem")
local battle = {
    rosterComplete = false, time = 300, allies = { { id = home, isSelf = true } },
    enemies = { { id = liveID, rivalID = liveID, name = "Glowing Ember" } },
    events = { { kind = "kill", actorID = home, targetID = liveID } },
    rewards = { [liveID] = { honorableKills = 1, honor = 4 } },
}
addon.RecordSkirmish("world:10", battle)
assert(not addon.db.rivals[beforeCombat] and #addon.db.rivals[liveID].encounters == 1)

-- Reproduce the previously written split profile, including an old spelling
-- of its manual key and a previously computed history index.
local db = addon.db
local duplicate = "manual:Ёжик лесной"
db.rivals[duplicate] = { displayName = "Ёжик  Лесной", killsAgainstThem = 0, deathsToThem = 1, encounters = {
    { manual = true, outcome = "loss", direction = "deathsToThem", sequence = 11, recordedAt = 400,
        honorableKills = 2, honor = 9 },
} }
ledger.AddSkirmishRewards(battle, liveID, 1, 3)
ledger.SaveSkirmish(db, "world:10", battle)
db.encounterSequence = 11
db.unassignedRewards = { honorableKills = 1, honor = 5 }
local function Verify(saved)
    assert(saved.encounterSequence == 11 and not saved.rivals[duplicate])
    local wins, losses = ledger.RivalHistoryContext(saved, rivalID)
    assert(wins == 1 and losses == 1)
    assert(saved.rivals[rivalID].killsAgainstThem == 1 and saved.rivals[rivalID].deathsToThem == 1)
    local history = addon.RivalEncounters(saved, rivalID)
    assert(#history == 3 and history[1].sequence == 11 and history[1].manual and history[1].outcome == "loss")
    assert(history[3].skirmishID == "world:1" and ledger.PersonalCombatScore(saved, rivalID) == 1)
    local hk, honor = ledger.RivalRewards(saved, rivalID)
    assert(hk == 3 and honor == 15)
    local liveHistory = addon.RivalEncounters(saved, liveID)
    assert(#liveHistory == 2 and liveHistory[1].skirmishID == "world:10")
    assert(ledger.SkirmishOutcome(saved.skirmishes["world:10"]) == "win")
    hk, honor = ledger.RivalRewards(saved, liveID)
    assert(hk == 2 and honor == 7)
    assert(ledger.PersonalCombatScore(saved, liveID) == 1)
    local povWins, povLosses = ledger.RivalContributionScore(saved, rivalID)
    assert(povWins == 1 and povLosses == 0)
    local total = ledger.JournalRewards(saved)
    assert(total.honorableKills == 6 and total.honor == 27 and total.unassignedHonor == 5)
end
assert(ledger.RivalRewards(db, rivalID) == 1 and ledger.RivalRewards(db, duplicate) == 2)
addon.ReconcileManualRivals(db)
Verify(db)
for _ = 1, 2 do
    db = ledger.Open(Copy(db))
    Verify(db)
end

-- Known namesakes stay separate, including when a correctly named target
-- explicitly selects one GUID. An ambiguous typed entry stays provisional.
addon.db = ledger.Open()
local namesakeA, namesakeB = "Player-100-00000005", "Player-200-00000006"
ledger.Add(addon.db, namesakeA, "Старый Друг")
ledger.Add(addon.db, namesakeB, "старый друг")
provisional = addon.AddManualEncounter("Старый Друг", "killsAgainstThem")
assert(provisional:match("^manual:"))
targetID = namesakeB
local target = assert(addon.ManualTarget())
assert(addon.AddManualEncounter("СТАРЫЙ ДРУГ", "deathsToThem", target) == namesakeB)
addon.db = ledger.Open(Copy(addon.db))
assert(addon.db.rivals[provisional] and addon.db.rivals[namesakeA] and addon.db.rivals[namesakeB])
assert(#addon.db.rivals[provisional].encounters == 1 and #addon.db.rivals[namesakeB].encounters == 1)

-- Without regional uniqueness, the typed lookup has only home-realm scope.
function RegionalUniqueNamesEnabled() return false end
addon.db = ledger.Open()
ledger.Add(addon.db, namesakeB, "Старый Друг")
provisional = addon.AddManualEncounter("Старый Друг", "killsAgainstThem")
assert(provisional:match("^manual:") and not addon.FindVisibleRival("Player-200-00000007", "target"))
local remote = addon.db.rivals[namesakeB]
addon.db = ledger.Open(addon.db)
assert(addon.db.rivals[namesakeB] == remote and addon.db.rivals[provisional])
assert(not addon.db.rivals[namesakeB].encounters)
ledger.Add(addon.db, namesakeA, "Старый Друг")
assert(addon.AddManualEncounter("Старый Друг", "deathsToThem") == namesakeA)
assert(not addon.db.rivals[provisional] and #addon.db.rivals[namesakeA].encounters == 2)

-- Reload of an older ambiguous sequence or shared-battle layout is conservative.
for _, conflict in ipairs({ "sequence", "battle-link", "non-manual" }) do
    local manualID = "manual:same name"
    local legacy = { version = 1, rivals = {
        [liveID] = { displayName = "Same Name", encounters = { { sequence = 1 } } },
        [manualID] = { displayName = "Same Name", encounters = { { manual = true, sequence = 2 } } },
    } }
    if conflict == "sequence" then legacy.rivals[manualID].encounters[1].sequence = 1 end
    if conflict == "battle-link" then
        legacy.skirmishes = { ["saved"] = { allies = {}, enemies = { { rivalID = manualID } }, events = {} } }
    end
    if conflict == "non-manual" then legacy.rivals[manualID].encounters[1].manual = nil end
    assert(ledger.Open(legacy).rivals[manualID] and #legacy.rivals[liveID].encounters == 1)
end

print("Manual identity, scope, promotion, historical migration, rewards and repeated reload checks passed")
