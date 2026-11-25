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
    local totalWins, totalLosses = ledger.RivalScore(saved, rivalID)
    assert(totalWins == 2 and totalLosses == 1)
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
targetID = nil
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
targetID = nil
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

-- Manual saves use readable observations from the current unit and the
-- existing roster. One GUID may supply complementary data through two tokens.
function RegionalUniqueNamesEnabled() return true end
local secret = {}
function issecretvalue(value) return value == secret end
local units = {}
function UnitGUID(unit) return unit == "player" and home or units[unit] and units[unit].guid end
function UnitIsPlayer(unit) return units[unit] ~= nil end
function UnitName(unit) return units[unit].name end
function UnitLevel(unit) return units[unit] and units[unit].level end
function UnitRace(unit)
    local race = units[unit] and units[unit].race
    return race, race
end
function UnitSex(unit) return units[unit] and units[unit].sex end
function UnitClass(unit)
    local class = units[unit] and units[unit].class
    return class, class
end
function UnitFactionGroup(unit)
    local faction = units[unit] and units[unit].faction
    return faction, faction
end
local function Plate(unit, forbidden)
    return { unitToken = unit, IsForbidden = function() return forbidden end }
end
local plates = { Plate("nameplate1"), Plate("nameplate2", true) }
C_NamePlate = { GetNamePlates = function() return plates end }
addon.db = ledger.Open()

local mouse = { guid = namesakeA, name = "Frost Weaver", level = secret, race = "Orc", sex = 2 }
local plate = { guid = namesakeA, name = "Frost Weaver", level = 44, class = "MAGE", faction = "Horde" }
units.mouseover, units.nameplate1 = mouse, plate
units.nameplate2 = { guid = namesakeB, name = plate.name, level = 60 }
assert(addon.AddManualEncounter(" frost  WEAVER ", "killsAgainstThem") == namesakeA)
local enriched = addon.db.rivals[namesakeA]
assert(enriched.race == "orc" and enriched.sex == 2 and enriched.class == "MAGE")
assert(enriched.faction == "Horde" and enriched.factionLabel == "Horde")
assert(enriched.encounters[1].rivalLevel == 44 and enriched.observedLevel == 44)
units.mouseover, units.nameplate1 = nil, nil
assert(addon.AddManualEncounter("Frost Weaver", "deathsToThem") == namesakeA)
assert(enriched.encounters[1].rivalLevel == nil and enriched.observedLevel == 44)
local w, l = ledger.RivalScore(addon.db, namesakeA)
assert(w == 1 and l == 1)
assert(ledger.RivalContributionScore(addon.db, namesakeA) == 0)
local k, d = ledger.PersonalCombatScore(addon.db, namesakeA)
local hk, honor = ledger.RivalRewards(addon.db, namesakeA)
assert(k == 0 and d == 0 and hk == 0 and honor == 0)

local plateOnly = "Player-100-00000009"
units.nameplate1 = { guid = plateOnly, name = "Visible Rival", class = "DRUID", level = 37 }
assert(addon.AddManualEncounter("Visible Rival", "killsAgainstThem") == plateOnly)
assert(addon.db.rivals[plateOnly].class == "DRUID" and addon.db.rivals[plateOnly].encounters[1].rivalLevel == 37)
units.nameplate1 = nil

-- Reuse a level from older battle evidence for the matched GUID and never
-- timestamp the historical observation as part of the new manual encounter.
local prior = "Player-100-00000010"
addon.RecordSkirmish("earlier-sight", {
    time = 100, allies = { { id = home, isSelf = true } },
    enemies = { { id = prior, rivalID = prior, name = "Earlier Rival", level = 29, race = "orc", sex = 2 } },
    events = {},
})
assert(addon.AddManualEncounter("Earlier Rival", "killsAgainstThem") == prior)
local profile = addon.db.rivals[prior]
assert(profile.race == "orc" and profile.observedLevel == 29 and profile.encounters[1].rivalLevel == nil)

-- A changed target with the same name can be two different people.
local freshID, staleID = "Player-100-00000011", "Player-100-00000012"
units.target = { guid = staleID, name = "Changed Target", race = "Human", level = 30 }
local opening = assert(addon.ManualTarget())
units.target = { guid = freshID, name = "Changed Target", race = "Orc", level = 41 }
local changed = addon.AddManualEncounter("Changed Target", "killsAgainstThem", opening)
assert(changed:match("^manual:") and addon.db.rivals[changed].manualIdentityAmbiguous)
assert(not addon.db.rivals[staleID] and not addon.db.rivals[freshID])
assert(addon.AddManualEncounter("Changed Target", "deathsToThem", addon.ManualTarget()) == freshID)
assert(addon.db.rivals[freshID].race == "orc" and addon.db.rivals[freshID].encounters[1].rivalLevel == 41)

units.target = { guid = staleID, name = "Opening Name", race = "Human", level = 30 }
opening = assert(addon.ManualTarget())
units.target, units.mouseover = { guid = freshID, name = "Different Name" },
    { guid = freshID, name = "Opening Name", level = 41 }
local staleMouseover = addon.AddManualEncounter("Opening Name", "deathsToThem", opening)
assert(staleMouseover:match("^manual:") and addon.db.rivals[staleMouseover].manualIdentityAmbiguous)

-- A name-only match with two readable GUIDs stays provisional even when
-- only one of the two rivals has a profile at the next reload.
local twinA, twinB = "Player-100-00000021", "Player-100-00000022"
units.target = nil
units.mouseover = { guid = twinA, name = "Two Twins", race = "Human", level = 25 }
units.nameplate1 = { guid = twinB, name = "Two Twins", race = "Orc", level = 31 }
local conflicting = addon.AddManualEncounter("Two Twins", "killsAgainstThem")
assert(conflicting:match("^manual:") and addon.db.rivals[conflicting].manualIdentityAmbiguous)
assert(not addon.FindVisibleRival(twinA, "mouseover"))
ledger.Add(addon.db, twinA, "Two Twins")
addon.db = ledger.Open(Copy(addon.db))
assert(addon.db.rivals[conflicting] and addon.db.rivals[changed])
assert(ledger.RivalScore(addon.db, twinA) == 0)
w, l = ledger.RivalScore(addon.db, namesakeA)
assert(w == 1 and l == 1)
ledger.Remove(addon.db, namesakeA)
assert(ledger.RivalScore(addon.db, namesakeA) == 0 and ledger.RivalRewards(addon.db, namesakeA) == 0)

-- A direct target identifies only the newly entered result when a previously
-- unresolved entry could refer to either of two currently readable GUIDs.
units.mouseover, units.nameplate1 = nil, nil
local earlierManual = addon.AddManualEncounter("Later Conflict", "killsAgainstThem")
units.target = { guid = "Player-100-00000023", name = "Later Conflict" }
units.mouseover = { guid = "Player-100-00000024", name = "Later Conflict" }
local exact = assert(addon.ManualTarget())
assert(addon.AddManualEncounter(exact.name, "deathsToThem", exact) == exact.guid)
addon.db = ledger.Open(Copy(addon.db))
assert(addon.db.rivals[earlierManual].manualIdentityAmbiguous)
w, l = ledger.RivalScore(addon.db, exact.guid)
assert(w == 0 and l == 1)

-- Restricted or reused unit tokens supply no guessed identity or appearance.
local pendingID = "Player-100-00000031"
units.target, units.mouseover = nil, nil
units.nameplate1 = { guid = secret, name = "Hidden Name", level = secret, race = secret, faction = secret }
local pending = addon.AddManualEncounter("Hidden Name", "deathsToThem")
local unknown = addon.db.rivals[pending]
assert(pending:match("^manual:") and not unknown.race and not unknown.observedLevel and not unknown.faction)
units.mouseover = { guid = pendingID, name = "Hidden Name", class = "PRIEST", level = 22 }
addon.ResolveRivalName("mouseover")
profile = assert(addon.db.rivals[pendingID])
assert(not addon.db.rivals[pending] and profile.class == "PRIEST" and profile.observedLevel == 22)
assert(profile.encounters[1].manual and profile.encounters[1].rivalLevel == nil)
units.mouseover.race, units.mouseover.sex, units.mouseover.faction = "Orc", 2, "Horde"
addon.ResolveRivalName("mouseover")
assert(profile.race == "orc" and profile.sex == 2 and profile.faction == "Horde")
w, l = ledger.RivalScore(addon.db, pendingID)
assert(w == 0 and l == 1)

local unitRace = UnitRace
units.nameplate1 = { guid = pendingID, name = "Reused Token", race = "Orc", level = 22 }
function UnitRace(unit)
    if unit == "nameplate1" then units[unit] = { guid = twinB, name = "Other Character" } end
    return unitRace(unit)
end
local reused = addon.AddManualEncounter("Reused Token", "killsAgainstThem")
assert(reused:match("^manual:") and not addon.db.rivals[reused].race)
UnitRace = unitRace
print("Manual identity, live observations, scope, promotion, migration and score reload checks passed")
