local addon, frames, timers = {}, {}, {}
local time, hk, inCombat = 1000, 4, true
local units = {
    player = { "Player-self", "Alden Dawnshield", "Alliance" },
    party1 = { "Player-brother", "Thoren Ironbrook", "Alliance" },
    target = { "Player-fenrik", "Fenrik Coldwater", "Horde" },
    mouseover = { "Player-ghash", "Ghash Emberfang", "Horde" },
}
function UnitGUID(unit) return units[unit] and units[unit][1] end
function UnitName(unit) return units[unit][2] end
function UnitFactionGroup(unit) return units[unit][3] end
function UnitIsPlayer(unit) return units[unit] ~= nil end
function UnitCanAttack(_, unit) return UnitIsPlayer(unit) and UnitFactionGroup(unit) == "Horde" end
function GetNumSubgroupMembers() return 1 end
function GetTime() return time end
function GetServerTime() return math.floor(time) end
function GetPVPSessionStats() return hk end
function InCombatLockdown() return inCombat end
function IsInInstance() return false, "none" end
function GetRealZoneText() return "Tanaris" end

function CreateFrame()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(_, handler) self.handler = handler end
    frames[#frames + 1] = frame
    return frame
end

local function Fire(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] then frame.handler(frame, event, ...) end
    end
end

C_Timer = { After = function(delay, callback)
    timers[#timers + 1] = { time = time + delay, callback = callback }
end }
local function Advance(seconds)
    local finish = time + seconds
    while #timers > 0 do
        table.sort(timers, function(a, b) return a.time < b.time end)
        if timers[1].time > finish then break end
        local timer = table.remove(timers, 1)
        time = timer.time
        timer.callback()
    end
    time = finish
end

Constants = { CurrencyConsts = { CLASSIC_HONOR_CURRENCY_ID = 1901 } }
for _, file in ipairs({ "Ledger", "SkirmishOutcomes", "SkirmishDeathEvidence", "PersonalSkirmishOutcomes", "Encounter", "Core", "SkirmishEvidence", "MeterSourceTotals", "CombatDiagnostics", "WorldSkirmishes", "Honor", "Kills" }) do
    assert(loadfile("NamesInRed/" .. file .. ".lua"))("NamesInRed", addon)
end
addon.db = addon.Ledger.Open(nil)
Fire("PLAYER_ENTERING_WORLD")

local fenrik, ghash, brother = units.target[1], units.mouseover[1], units.party1[1]
do
    local original = units.target
    units.target = units.player
    local self = assert(addon.ManualTarget())
    assert(addon.AddManualEncounter(self.name, "killsAgainstThem", self) == self.guid)
    assert(addon.Ledger.RivalScore(addon.db, self.guid) == 1)
    assert(not addon.RecordWorldEncounter(self.guid, self.name, "killsAgainstThem", addon.EncounterContext("target")))
    Fire("PARTY_KILL", brother, self.guid)
    assert(not addon.db.skirmishes)
    assert(addon.Ledger.PersonalCombatScore(addon.db, self.guid) == 0)
    addon.ResetData()
    units.target = original
end
local function GainHK()
    hk = hk + 1
    Fire("PLAYER_PVP_KILLS_CHANGED", "player")
    Fire("PLAYER_PVP_KILLS_CHANGED", "player")
end
local function HonorChat(message, lineID)
    Fire("CHAT_MSG_COMBAT_HONOR_GAIN", message, nil, nil, nil, nil, nil, nil, nil, nil, nil, lineID)
end
local function CheckReward(id, expectedHK, expectedHonor)
    local wins, losses, actualHK, honor = addon.Ledger.PersonalScore(addon.db, id)
    assert(wins == 0 and losses == 0 and actualHK == expectedHK and honor == expectedHonor)
end

-- Replay the observed order of the live Forever signals for a grouped kill.
Fire("PARTY_KILL", brother, fenrik)
Fire("PARTY_KILL", brother, fenrik) -- duplicate must not spoil legitimate reward attribution
Advance(0.317)
GainHK()
Advance(0.685)
local message = "Вы получили 6 |4очко чести:очка чести:очков чести;."
HonorChat(message, 71)
HonorChat(message, 71)
Advance(2.1)
CheckReward(fenrik, 1, 6)
local battle = assert(addon.db.skirmishes["world:1"])
assert(#battle.allies == 2 and battle.allies[2].id == brother and battle.events[1].actorID == brother)

local context = addon.EncounterContext("target")
context.attackers = { { guid = fenrik }, { guid = ghash } }
addon.RecordWorldEncounter(fenrik, units.target[2], "deathsToThem", context)
local encounter = addon.Ledger.RivalSkirmishes(addon.db, ghash)[1]
assert(encounter.playerDeathIndex == 2 and not encounter.outcome)

local initialLife = {}
function UnitIsVisible(unit) return initialLife[UnitGUID(unit)] ~= nil end
function UnitIsDeadOrGhost(unit) return initialLife[UnitGUID(unit)] end
function UnitIsFeignDeath() return false end
initialLife[fenrik] = false
Fire("UNIT_FLAGS", "target")
assert(battle.events[3].kind == "revive")

-- Two eligible targets in one burst leave the grant unassigned.
inCombat = false
Fire("PLAYER_REGEN_ENABLED")
local observedRival = units.mouseover
units.mouseover = nil
Fire("PARTY_KILL", brother, ghash)
units.mouseover = observedRival
assert(battle.events[4].targetID == ghash)
GainHK()
initialLife[fenrik] = true
Fire("PARTY_KILL", brother, fenrik)
initialLife[fenrik] = nil
HonorChat(message, 72)
Advance(2.1)
CheckReward(fenrik, 1, 6)
CheckReward(ghash, 0, 0)

-- A new combat session, with a currency amount and the HK notification first.
Advance(9)
inCombat = true
Fire("PLAYER_REGEN_DISABLED")
GainHK()
Advance(0.1)
Fire("PARTY_KILL", brother, ghash)
Fire("CURRENCY_DISPLAY_UPDATE", 1901, 100, 7)
HonorChat("Unrecognized localized award", 73)
Advance(2.1)
CheckReward(ghash, 1, 7)
assert(#addon.db.skirmishes["world:2"].events == 1)

Fire("PARTY_KILL", brother, fenrik)
GainHK()
HonorChat(message, 74)
addon.ResetHonorTracking()
addon.ResetWorldTracking()
addon.Ledger.Clear(addon.db)
Advance(2.1)
assert(next(addon.db.rivals) == nil and not addon.db.skirmishes)
print("Live world skirmish grouping, isolated honor attribution, and reset checks passed")

-- The lethal player's unit is visible on a nameplate, without being targeted.
units.target, units.mouseover = nil, nil
units.nameplate1 = { "Player-rogue", "Test Rogue", "Horde" }
units.nameplate2 = { "Player-bystander", "Other Player", "Horde" }
function UnitLevel(unit) return units[unit] and 32 end
function UnitRace(unit)
    if unit == "player" then return "Night Elf", "NightElf" end
    if unit == "nameplate1" then return "Undead", "Scourge" end
end
function UnitSex(unit) return unit == "player" and 3 or 2 end
function UnitClass(unit)
    if unit == "player" then return "Hunter", "HUNTER" end
    if unit == "nameplate1" then return "Rogue", "ROGUE" end
end
C_NamePlate = { GetNamePlates = function() return {
    { unitToken = "nameplate1", IsForbidden = function() return false end },
    { unitToken = "nameplate2", IsForbidden = function() return false end },
    { IsForbidden = function() return true end },
} end }
bit = { band = function() return 0x440 end }
local recap
C_DeathRecap = { GetRecapEvents = function() return recap end }
assert(loadfile("NamesInRed/Deaths.lua"))("NamesInRed", addon)
Fire("PLAYER_DEAD")
assert(not addon.db.skirmishes)
units.nameplate1 = nil
recap = { { sourceGUID = "Player-rogue", sourceName = "Test Rogue", sourceFlags = 0x440,
    timestamp = time, overkill = 2 } }
Advance(0.3)
local recorded = assert(addon.db.skirmishes["world:1"])
assert(#recorded.enemies == 1 and recorded.enemies[1].id == "Player-rogue")
local rogue, player = recorded.enemies[1], recorded.allies[1]
assert(rogue.level == 32 and rogue.class == "ROGUE" and rogue.race == "scourge" and rogue.sex == 2)
assert(player.level == 32 and player.class == "HUNTER" and player.race == "nightelf" and player.sex == 3)
assert(recorded.rosterComplete and not addon.Ledger.SkirmishOutcome(recorded))
local wins, losses = addon.Ledger.PersonalScore(addon.db, rogue.id)
assert(wins == 0 and losses == 0)
print("Delayed death recap retains previously visible nameplate appearance")

-- If a teammate later lands a blow, the same record is no longer a duel.
addon.RecordWorldEncounter(rogue.id, rogue.name, "killsAgainstThem", {
    time = GetServerTime(), zone = "Tanaris", actorID = brother, actorName = "Thoren Ironbrook",
})
assert(#recorded.allies == 2 and not recorded.rosterComplete and not addon.Ledger.SkirmishOutcome(recorded))
wins, losses = addon.Ledger.PersonalScore(addon.db, rogue.id)
assert(wins == 0 and losses == 0)

-- Reopen a pre-upgrade record matching the solo kill signal in the live log.
local saved = { version = 1, rivals = addon.db.rivals, skirmishes = {} }
local direct = { kind = "kill", actorID = player.id, targetID = rogue.id }
local indirect = { kind = "kill", actorID = "Player-other", targetID = rogue.id }
local reciprocal = { kind = "kill", actorID = rogue.id, targetID = player.id }
local function SavedBattle(events)
    return { rosterComplete = false, allies = { player }, enemies = { rogue }, events = events }
end
saved.skirmishes["world:1"] = SavedBattle({ direct })
saved.skirmishes["world:2"] = SavedBattle({ indirect })
saved.skirmishes["world:3"] = SavedBattle({ direct, reciprocal })
saved.skirmishes["seed:incomplete"] = SavedBattle({ direct })
assert(addon.Ledger.Open(saved) == saved)
assert(saved.skirmishes["world:1"].rosterComplete and not saved.skirmishes["world:2"].rosterComplete)
assert(saved.skirmishes["world:3"].rosterComplete and not addon.Ledger.SkirmishOutcome(saved.skirmishes["world:3"]))
assert(not saved.skirmishes["seed:incomplete"].rosterComplete)
wins, losses = addon.Ledger.PersonalScore(saved, rogue.id)
assert(wins == 1 and losses == 0)
print("Observed world duels recalculate on load and when participants change")

-- Anonymized replay of the attached Duskwood log. The meter snapshot uses
-- Current, with two DamageTaken sources and an attacker absent from the kills.
do
    addon.ResetHonorTracking()
    addon.ResetWorldTracking()
    addon.Ledger.Clear(addon.db)
    time, inCombat = 2000, true
    local third = "Player-paladin"
    local unrelated = "Player-unrelated"
    local outsider = "Player-outsider"
    units.target = { fenrik, "First Enemy", "Horde", "HUNTER" }
    units.mouseover = { ghash, "Second Enemy", "Horde", "SHAMAN" }
    units.nameplate1 = { third, "Third Enemy", "Horde", "PALADIN" }
    units.nameplate2 = { unrelated, "Other Ally", "Alliance", "MAGE" }
    units.nameplate3 = { outsider, "Other Enemy", "Horde", "ROGUE" }
    units.player[4], units.party1[4] = "HUNTER", "PRIEST"
    function UnitClass(unit) return nil, units[unit] and units[unit][4] end
    function UnitAffectingCombat() return inCombat end
    function GetRealZoneText() return "Duskwood" end
    function GetBuildInfo() return "1.60.1", "70959", "", 16001 end
    local length = 40
    local function Taken(name, class, amount, isMob)
        return { combatSpellDetails = { unitName = name, unitClassFilename = class,
            amount = amount, isPet = false, isMob = isMob == true } }
    end
    local sources = {
        [player.id] = { Taken("Third Enemy", "PALADIN", 122), Taken("Third Enemy", "PALADIN", 71) },
        [brother] = { Taken("Second Enemy", "SHAMAN", 22), Taken("Third Enemy", "PALADIN", 2) },
        [unrelated] = { Taken("Other Enemy", "ROGUE", 50) },
    }
    local secret = {}
    function issecretvalue(value) return value == secret end
    sources[player.id][3] = Taken("Other Enemy", "ROGUE", secret)
    sources[player.id][4] = Taken("Other Enemy", "ROGUE", 50, true)
    Enum = { DamageMeterType = { DamageTaken = 1 }, DamageMeterSessionType = { Current = 0 } }
    C_DamageMeter = {
        GetAvailableCombatSessions = function() return {} end,
        GetCombatSessionFromType = function(sessionType, category)
            assert(sessionType == 0 and category == 1)
            return { durationSeconds = length, combatSources = {
                { sourceGUID = unrelated }, { sourceGUID = brother }, { sourceGUID = player.id },
            } }
        end,
        GetCombatSessionSourceFromType = function(_, _, guid) return { combatSpells = sources[guid] } end,
    }
    SlashCmdList = {}
    assert(loadfile("NamesInRed/Debug.lua"))("NamesInRed", addon)
    Fire("ADDON_LOADED", "NamesInRed")
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
    Fire("PLAYER_REGEN_DISABLED")
    Advance(13)
    Fire("PARTY_KILL", player.id, fenrik)
    GainHK()
    HonorChat("You have been awarded 2 honor points.", 100)
    Advance(8)
    Fire("PARTY_KILL", player.id, ghash)
    GainHK()
    HonorChat("You have been awarded 3 honor points.", 101)
    Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 1, 0)
    Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    units.nameplate1 = nil
    Advance(19)
    local result = assert(addon.db.skirmishes["world:1"])
    assert(#result.allies == 1 and #result.enemies == 2)
    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    Advance(1.5)
    assert(#result.allies == 2 and result.allies[2].id == brother)
    assert(#result.enemies == 3 and result.enemies[3].id == third and result.enemies[3].class == "PALADIN")
    assert(#result.events == 2 and not addon.Ledger.FirstDeaths(result)[third])
    assert(not result.rosterComplete and not addon.Ledger.SkirmishOutcome(result))
    local kills, honor = addon.Ledger.SkirmishRewards(result)
    assert(kills == 2 and honor == 5 and addon.db.rivals[third] and not addon.db.rivals[outsider])
    local directFirst, deathsFirst = addon.Ledger.PersonalCombatScore(addon.db, fenrik)
    local directSecond, deathsSecond = addon.Ledger.PersonalCombatScore(addon.db, ghash)
    assert(directFirst == 1 and directSecond == 1 and deathsFirst == 0 and deathsSecond == 0)
    Advance(3)
    assert(result.resolution.ending == "unknown" and not addon.Ledger.SkirmishOutcome(result))

    -- An older Current slot must not enrich the next fight.
    Advance(10)
    assert(result.personalOutcome.outcome == "unknown" and result.personalOutcome.casualties.enemy == 2)
    units.nameplate1 = { third, "Third Enemy", "Horde", "PALADIN" }
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    inCombat = true
    Fire("PLAYER_REGEN_DISABLED")
    Fire("PARTY_KILL", player.id, fenrik)
    Advance(13)
    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    Advance(1.5)
    local later = assert(addon.db.skirmishes["world:2"])
    assert(#later.allies == 1 and #later.enemies == 1 and #later.events == 1)

    -- A healer who neither damages nor belongs to the group; an exact
    -- controller for a separately reported pet; and other readable actions.
    local healer, shield, purge, interrupt, owner = "Player-healer", "Player-shield", "Player-purge",
        "Player-interrupt", "Player-owner"
    local hidden, stale, pet = "Player-hidden", "Player-stale", "Pet-individual"
    units.nameplate4 = { healer, "Field Healer", "Alliance", "PRIEST" }
    units.nameplate5 = { shield, "Field Shield", "Alliance", "PRIEST" }
    units.nameplate6 = { purge, "Field Purge", "Alliance", "SHAMAN" }
    units.nameplate7 = { interrupt, "Field Kick", "Alliance", "ROGUE" }
    units.nameplate8 = { owner, "Field Hunter", "Alliance", "HUNTER" }
    units.nameplate9 = { pet }
    units.nameplate10 = { hidden, "Hidden Healer", "Alliance", "PRIEST" }
    units.nameplate11 = { stale, "Stale Caster", "Alliance", "MAGE" }
    units.partypet1 = { "Pet-group" }
    function UnitName(unit) return units[unit] and units[unit][2] end
    function UnitIsPlayer(unit)
        local guid = UnitGUID(unit)
        return guid ~= nil and guid:match("^Player%-") ~= nil
    end
    local contestedOwner = false
    function UnitIsOwnerOrControllerOfUnit(controller, controlled)
        return controlled == "nameplate9" and (controller == "nameplate8"
            or (contestedOwner and controller == "party1"))
    end
    local fake = {
        [2] = {
            [healer] = { Taken(units.player[2], "HUNTER", 24) },
            [hidden] = { { totalAmount = 217, combatSpellDetails = {
                unitName = "", unitClassFilename = "", amount = 0, isPet = false, isMob = false,
            } }, Taken("Other Ally", "MAGE", 25) },
            [unrelated] = { Taken("Other Enemy", "ROGUE", 10, true) },
        },
        [4] = { [shield] = { Taken("Field Healer", "PRIEST", 12) } },
        [5] = { [interrupt] = { Taken("First Enemy", "HUNTER", 1) } },
        [6] = { [purge] = { Taken("Field Healer", "PRIEST", 1) } },
        [0] = { [pet] = { Taken("First Enemy", "HUNTER", 24) } },
        [10] = { [fenrik] = { Taken("Stale Caster", "MAGE", 50) } },
    }
    local ids = {}
    Enum.DamageMeterType = { HealingDone = 2, Absorbs = 4, Interrupts = 5, Dispels = 6, DamageDone = 0, EnemyDamageTaken = 10 }
    C_DamageMeter.GetAvailableCombatSessions = function() return ids end
    C_DamageMeter.GetCombatSessionFromID = function(id, category)
        assert(id == 77)
        local simulated = {}
        for guid in pairs(fake[category]) do simulated[#simulated + 1] = { sourceGUID = guid } end
        return { durationSeconds = 15, combatSources = simulated }
    end
    C_DamageMeter.GetCombatSessionSourceFromID = function(id, category, guid)
        assert(id == 77)
        return { combatSpells = fake[category][guid] }
    end
    local function StartFight()
        Advance(10)
        inCombat = true
        Fire("PLAYER_REGEN_DISABLED")
        Fire("PARTY_KILL", player.id, fenrik)
        Advance(15)
        inCombat = false
        Fire("PLAYER_REGEN_ENABLED")
    end
    for index = 4, 11 do Fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. index) end
    inCombat = true
    Advance(10)
    Fire("PLAYER_REGEN_DISABLED")
    Fire("UNIT_AURA", "player", { addedAuras = { {
        spellId = 32, sourceUnit = "nameplate4", isHelpful = true,
    } } })
    Fire("UNIT_AURA", "player", secret)
    Fire("PARTY_KILL", player.id, fenrik)
    Advance(15)
    ids = { { sessionID = 77 } }
    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED")
    Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 10, 0)
    Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 0, 77)
    Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 2, 77)
    Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 4, 77)
    Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 5, 77)
    Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 6, 77)
    Advance(1.5)
    local aided = assert(addon.db.skirmishes["world:3"])
    local actual = {}
    for _, ally in ipairs(aided.allies) do actual[ally.id] = true end
    assert(#aided.allies == 6 and actual[healer] and actual[shield] and actual[purge] and actual[interrupt] and actual[owner])
    assert(#aided.enemies == 1 and #aided.events == 1 and not actual[brother] and not actual[unrelated] and not actual[hidden] and not actual[stale])
    local endRow = NamesInRedDebugDB.rows[#NamesInRedDebugDB.rows]
    assert(endRow.meterSelection == "new-archived" and endRow.meterEvidence.HealingDone == "eligible")
    assert(endRow.meterCurrentUpdates.count == 1 and endRow.auraSignals.secret == 1)
    assert(endRow.auraUpdates[1].sourceGUID == healer and endRow.auraUpdates[1].targetGUID == player.id)
    assert(endRow.contacts[brother].latest.petGUID == "Pet-group" and endRow.petOwners[pet][owner])

    -- The collector can start from GUIDs supplied by other PvP observations.
    -- Changing which owners claim a pet invalidates only that ownership.
    endRow.petOwners[pet][brother] = true
    local anchors = { [fenrik] = true }
    local function ConnectedPet()
        local evidence = addon.NewMeterParticipantEvidence(endRow.contacts, endRow.petOwners, "Alliance")
        local actor = evidence:Source("DamageDone", { sourceGUID = pet, status = {} })
        if actor then
            evidence:Link("DamageDone", actor, {
                unitName = "First Enemy", unitClassFilename = "HUNTER", amount = 7, isMob = false, isPet = false,
                status = { row = "readable" },
            })
        end
        return evidence:Connected(anchors)
    end
    assert(#ConnectedPet() == 0)
    endRow.petOwners[pet][brother] = nil
    local connected = ConnectedPet()
    assert(#connected == 1 and connected[1].guid == owner)

    -- A recent Current update is not an update for the archived category.
    ids = {}
    contestedOwner = true
    StartFight()
    ids = { { sessionID = 77 } }
    Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 2, 0)
    Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 0, 77)
    Advance(1.5)
    local staleFight = assert(addon.db.skirmishes["world:4"])
    endRow = NamesInRedDebugDB.rows[#NamesInRedDebugDB.rows]
    assert(#staleFight.allies == 1 and endRow.meterEvidence.HealingDone == "no-matching-update")

    ids = {}
    StartFight()
    ids = { { sessionID = 77 } }
    Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 2, 77)
    Fire("DAMAGE_METER_RESET")
    Advance(1.5)
    endRow = NamesInRedDebugDB.rows[#NamesInRedDebugDB.rows]
    assert(endRow.meterReset and #addon.db.skirmishes["world:5"].allies == 1)

    ids = {}
    StartFight()
    local previousZone = GetRealZoneText
    function GetRealZoneText() return "Elwynn Forest" end
    Fire("PLAYER_LEAVING_WORLD")
    Advance(1.5)
    GetRealZoneText = previousZone
    endRow = NamesInRedDebugDB.rows[#NamesInRedDebugDB.rows]
    assert(endRow.areaChanged and endRow.status.meter == "interrupted")
    assert(#addon.db.skirmishes["world:6"].allies == 1)

    -- Stress the limits of the diagnostic sample without depending on its order.
    -- The only valid heal appears after source 12, spell 16, target 4 and contact 32.
    local lateHealer = "Player-late-healer"
    local lateOwner = "Player-late-owner"
    local noOwnerPet, latePet, pastPartyPet = "Pet-owner-unseen", "Pet-late", "Pet-after-history"
    local otherHealer, otherFighter, otherEnemy = "Player-unrelated-healer", "Player-unrelated-fighter", "Player-unrelated-enemy"
    local mockSources, mockDetails = {}, {}
    local function Entry(name, class, amount)
        return Taken(name, class, amount).combatSpellDetails
    end
    local function Meter(category, source, spells)
        mockSources[category] = mockSources[category] or {}
        mockDetails[category] = mockDetails[category] or {}
        mockSources[category][#mockSources[category] + 1] = source
        if source.sourceGUID and source.sourceGUID ~= secret then mockDetails[category][source.sourceGUID] = spells end
    end
    local function MeterData(id, category)
        assert(id == 0 or id == 77 or id == 78)
        return { durationSeconds = 15, combatSources = mockSources[category] or {} }
    end
    C_DamageMeter.GetCombatSessionFromID = MeterData
    C_DamageMeter.GetCombatSessionFromType = MeterData
    local blockedDetail, detailReads = false, 0
    local function MeterDetail(_, category, guid)
        detailReads = detailReads + 1
        if blockedDetail and guid == lateHealer then return secret end
        return { combatSpells = mockDetails[category] and mockDetails[category][guid] or {} }
    end
    C_DamageMeter.GetCombatSessionSourceFromID = MeterDetail
    C_DamageMeter.GetCombatSessionSourceFromType = MeterDetail
    Enum.DamageMeterType = { HealingDone = 2, DamageDone = 0 }
    local function Updates(id)
        Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 2, id)
        Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 0, id)
    end

    ids = {}
    Advance(10)
    inCombat = true
    Fire("PLAYER_REGEN_DISABLED")
    for i = 1, 40 do
        local token = "nameplate" .. (20 + i)
        units[token] = { "Player-crowd-" .. i, "Crowd Member" .. i, "Alliance", "PRIEST" }
        Fire("NAME_PLATE_UNIT_ADDED", token)
        if i <= 14 then Meter(2, { sourceGUID = units[token][1] }, {}) end
    end
    units.nameplate61 = { lateHealer, "Late Healer", "Alliance", "PRIEST" }
    units.nameplate62 = { lateOwner, "Late Owner", "Alliance", "HUNTER" }
    units.nameplate63 = { latePet }
    units.nameplate64 = { otherHealer, "Other Healer", "Alliance", "PRIEST" }
    units.nameplate65 = { otherFighter, "Other Fighter", "Alliance", "WARRIOR" }
    units.nameplate66 = { otherEnemy, "Other Target", "Horde", "ROGUE" }
    function UnitIsOwnerOrControllerOfUnit(controller, controlled)
        return controller == "nameplate62" and UnitGUID(controlled) == latePet
    end
    -- See the pet before the owner. Lose the pet, then reuse its nameplate token.
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate63")
    for i = 61, 66 do if i ~= 63 then Fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. i) end end
    Fire("NAME_PLATE_UNIT_REMOVED", "nameplate63")
    units.nameplate63 = { noOwnerPet }
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate63")
    units.nameplate63 = nil
    Fire("NAME_PLATE_UNIT_REMOVED", "nameplate63")
    -- Fill the diagnostic change history before the grouped pet is observed.
    units.partypet1 = nil
    for i = 1, 10 do
        units.party1target = { "Creature-" .. i }
        Fire("UNIT_TARGET", "party1")
    end
    units.partypet1 = { pastPartyPet }
    Fire("UNIT_PET", "party1")
    units.partypet1 = nil
    Fire("UNIT_PET", "party1")

    local lateSpells = {
        Taken("", "HUNTER", 10),
        Taken("Missing Contact", "HUNTER", 20),
        Taken(units.player[2], "HUNTER", secret),
        { combatSpellDetails = secret },
    }
    for i = 5, 17 do lateSpells[i] = Taken("", "HUNTER", 10) end
    local manyTargets = {}
    for i = 1, 5 do manyTargets[i] = Entry("", "HUNTER", 5) end
    manyTargets[6] = Entry(units.player[2], "HUNTER", 18)
    lateSpells[18] = { combatSpellDetails = manyTargets }
    Meter(2, { sourceGUID = lateHealer }, lateSpells)
    Meter(2, { sourceGUID = secret }, {})
    Meter(2, {}, {})
    Meter(2, { sourceGUID = "Player-unseen-healer" }, {})
    Meter(2, { sourceGUID = otherHealer }, { Taken("Other Fighter", "WARRIOR", 25) })
    Meter(0, { sourceGUID = otherFighter }, { Taken("Other Target", "ROGUE", 20) })
    Meter(0, { sourceGUID = latePet }, { Taken("First Enemy", "HUNTER", 11) })
    Meter(0, { sourceGUID = noOwnerPet }, { Taken("First Enemy", "HUNTER", 12) })
    Meter(0, { sourceGUID = pastPartyPet }, { Taken("First Enemy", "HUNTER", 13) })
    Fire("PARTY_KILL", player.id, fenrik)
    Advance(15)
    inCombat = false
    ids = { { sessionID = 77 } }
    Updates(77)
    Fire("PLAYER_REGEN_ENABLED")
    Advance(1.5)
    local massive = assert(addon.db.skirmishes["world:7"])
    actual = {}
    for _, ally in ipairs(massive.allies) do actual[ally.id] = true end
    assert(#massive.allies == 4 and actual[lateHealer] and actual[lateOwner] and actual[brother])
    assert(#massive.enemies == 1 and not actual[otherHealer] and not actual[otherFighter])
    endRow = NamesInRedDebugDB.rows[#NamesInRedDebugDB.rows]
    assert(endRow.contactCount > 32 and endRow.contactOverflow > 0 and not endRow.contacts[lateHealer])
    local healing = endRow.meter.HealingDone
    assert(#healing.sources == 12 and healing.sourceCount == 19)
    assert(healing.resolution["target-contact-missing"] == 1 and healing.resolution["target-amount-secret"] == 1)
    assert(healing.resolution["details-secret"] == 1 and healing.resolution["target-name-missing"] > 1)
    assert(healing.resolution["source-guid-secret"] == 1 and healing.resolution["source-guid-absent"] == 1)
    assert(healing.resolution["source-contact-missing"] == 1)
    assert(healing.resolution["source-connected"] == 1 and healing.resolution["source-disconnected"] == 1)
    assert(endRow.meter.DamageDone.resolution["pet-owner-unresolved"] == 1)

    -- Check native restriction and source detail can each clear during the
    -- bounded retry, without stale data being published after the first read.
    mockSources[2], mockDetails[2] = { { sourceGUID = lateHealer } }, {
        [lateHealer] = { { combatSpellDetails = manyTargets } },
    }
    mockSources[0], mockDetails[0] = {}, {}
    Enum.AddOnRestrictionType, Enum.AddOnRestrictionState = { Combat = 0 }, { Inactive = 0 }
    local restriction = 2
    C_RestrictedActions = { GetAddOnRestrictionState = function(kind)
        assert(kind == 0)
        return restriction
    end }
    ids = {}
    StartFight()
    Updates(0)
    local before = detailReads
    Advance(0.5)
    endRow = NamesInRedDebugDB.rows[#NamesInRedDebugDB.rows]
    assert(endRow.meterRestrictionWaits == 1 and detailReads == before)
    restriction = 0
    Advance(1)
    assert(endRow.meterAttempts == 2 and #addon.db.skirmishes["world:8"].allies == 2)
    local retained = endRow.meter.HealingDone.sources[1].spells[1]
    assert(retained.targetCount == 6 and #retained.targets == 4)

    ids = {}
    StartFight()
    Updates(0)
    blockedDetail = true
    Advance(0.5)
    assert(#addon.db.skirmishes["world:9"].allies == 1)
    blockedDetail = false
    Advance(1)
    endRow = NamesInRedDebugDB.rows[#NamesInRedDebugDB.rows]
    assert(endRow.meterAttempts == 2 and #addon.db.skirmishes["world:9"].allies == 2)

    -- A later archive may replace an unsampled Current candidate. A selected
    -- archive changing underneath a retry cannot be folded into this fight.
    ids = {}
    StartFight()
    Advance(0.5)
    ids = { { sessionID = 77 } }
    Updates(77)
    Advance(1)
    endRow = NamesInRedDebugDB.rows[#NamesInRedDebugDB.rows]
    local archivedBattle = addon.db.skirmishes["world:10"]
    assert(endRow.meterSessionID == 77 and #archivedBattle.allies == 2)
    local archivedProbe = assert(archivedBattle.combatDiagnostics.windows[1].meter)
    assert(archivedProbe.sessionID == 77 and archivedProbe.selection == "new-archived" and archivedProbe.retained > 0)

    ids = {}
    StartFight()
    ids = { { sessionID = 77 } }
    Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 2, 77)
    Advance(0.5)
    ids = { { sessionID = 78 } }
    Updates(78)
    Advance(1)
    endRow = NamesInRedDebugDB.rows[#NamesInRedDebugDB.rows]
    local ambiguousBattle = addon.db.skirmishes["world:11"]
    assert(endRow.status.meter == "session-changed-or-ambiguous" and #ambiguousBattle.allies == 1)
    assert(not ambiguousBattle.combatDiagnostics.windows[1].meter)

    ids = {}
    StartFight()
    Advance(0.5)
    Updates(0)
    Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED")
    Advance(1)
    endRow = NamesInRedDebugDB.rows[#NamesInRedDebugDB.rows]
    local changedBattle = addon.db.skirmishes["world:12"]
    assert(endRow.status.meter == "current-changed" and #changedBattle.allies == 1)
    assert(not changedBattle.combatDiagnostics.windows[1].meter)

    -- A separate engagement starts before the earlier archive is published.
    -- Even with a valid party heal touching a shared player, the late window
    -- may not overwrite or enrich either record with those aggregates.
    ids = {}
    StartFight()
    Advance(0.5)
    local previousRow = NamesInRedDebugDB.rows[#NamesInRedDebugDB.rows]
    addon.ResetWorldTracking()
    inCombat = true
    Fire("PLAYER_REGEN_DISABLED")
    ids = { { sessionID = 77 } }
    Updates(77)
    Fire("PARTY_KILL", player.id, ghash)
    Advance(15)
    inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    Advance(1.5)
    endRow = NamesInRedDebugDB.rows[#NamesInRedDebugDB.rows]
    assert(previousRow.status.meter == "interrupted" and endRow.status.meterWindow == "previous-window-pending")
    assert(#addon.db.skirmishes["world:13"].allies == 1 and #addon.db.skirmishes["world:14"].allies == 1)

    -- Raid observation follows the readable roster count independently of
    -- the ten roster entries preserved in the diagnostic snapshot.
    local raidMember, raidPet = "Player-raid-eleven", "Pet-raid-eleven"
    function IsInRaid() return true end
    function GetNumGroupMembers() return 11 end
    units.raid11 = { raidMember, "Raid Hunter", "Alliance", "HUNTER" }
    units.raidpet11 = { raidPet }
    mockSources[2], mockDetails[2] = {}, {}
    Meter(0, { sourceGUID = raidPet }, { Taken("First Enemy", "HUNTER", 15) })
    ids = {}
    StartFight()
    Updates(0)
    Advance(1.5)
    endRow = NamesInRedDebugDB.rows[#NamesInRedDebugDB.rows]
    local raidFight = assert(addon.db.skirmishes["world:15"])
    assert(#endRow.group == 10 and endRow.groupSize == 11)
    assert(#raidFight.allies == 2 and raidFight.allies[2].id == raidMember)
end
print("Duskwood replay and participant links cover uncapped support, pets, ambiguous sessions and delayed reads")

do
    -- Exercise the real event entry points on both the meter and live paths.
    addon.ResetData()
    inCombat, recap = false, nil
    Advance(10)
    local localID = units.player[1]
    units.target = { fenrik, "First Enemy", "Horde", "HUNTER" }
    units.mouseover = { ghash, "Second Enemy", "Horde", "SHAMAN" }
    units.party1 = { brother, "Thoren Ironbrook", "Alliance", "PRIEST" }
    units.nameplate1 = units.target
    units.nameplate2 = { "Player-other-ally", "Other Ally", "Alliance", "MAGE" }
    units.nameplate3 = { "Player-other-enemy", "Other Enemy", "Horde", "ROGUE" }
    function IsInRaid() return false end
    function UnitIsPVP(unit) return UnitIsPlayer(unit) and UnitCanAttack("player", unit) end
    local dead, ghost = false, false
    function UnitIsDeadOrGhost(unit) return unit == "player" and (dead or ghost) end
    function UnitIsGhost(unit) return unit == "player" and ghost end
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")

    local meterSources, meterSpells
    local secretMeter = {}
    function issecretvalue(value) return value == secretMeter end
    C_RestrictedActions = nil
    Enum.DamageMeterType = { DamageTaken = 7, HealingDone = 2 }
    local elapsed, restricted = 8, false
    C_DamageMeter.GetAvailableCombatSessions = function() return {} end
    C_DamageMeter.GetCombatSessionFromType = function(id, category)
        assert(id == 0)
        if restricted then return secretMeter end
        return { durationSeconds = elapsed, combatSources = meterSources[category] or {} }
    end
    C_DamageMeter.GetCombatSessionSourceFromType = function(_, category, guid)
        return { combatSpells = meterSpells[category] and meterSpells[category][guid] or {} }
    end
    local function ResetSnapshot()
        meterSources, meterSpells = {}, {}
    end
    local function Link(kind, guid, name, class, amount, mob)
        meterSources[kind] = meterSources[kind] or {}
        meterSpells[kind] = meterSpells[kind] or {}
        local spells = meterSpells[kind][guid]
        if not spells then
            spells = {}
            meterSpells[kind][guid] = spells
            meterSources[kind][#meterSources[kind] + 1] = { sourceGUID = guid }
        end
        spells[#spells + 1] = { combatSpellDetails = {
            unitName = name, unitClassFilename = class, amount = amount, isMob = mob == true, isPet = false,
        } }
    end
    local function Begin()
        inCombat = true
        Fire("PLAYER_REGEN_DISABLED")
    end
    local function End(duration)
        Advance(duration)
        inCombat = false
        Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 7, 0)
        Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 2, 0)
        Fire("PLAYER_REGEN_ENABLED")
    end
    local function Aura(actor, target, spell)
        Fire("UNIT_AURA", target, { addedAuras = { { sourceUnit = actor, isHarmful = true, spellId = spell } } })
    end
    local function Battle(id)
        return assert(addon.db.skirmishes["world:" .. id])
    end
    local function NoRewards(battle)
        local kills, honor = addon.Ledger.SkirmishRewards(battle)
        assert(#battle.events == 0 and kills == 0 and honor == 0)
        assert(not addon.Ledger.SkirmishOutcome(battle))
    end

    -- Targeting friendly players and fighting NPCs near a hostile player
    -- produce no record, even if the meter has positive unrelated PvP rows.
    ResetSnapshot()
    Fire("PLAYER_TARGET_CHANGED")
    Fire("UNIT_TARGET", "party1")
    assert(not addon.db.skirmishes)
    Begin()
    Aura("party1", "player", 101)
    Link(7, localID, "Forest Bear", "WARRIOR", 20, true)
    Link(7, brother, "First Enemy", "HUNTER", 5)
    End(elapsed)
    Advance(1.5)
    assert(not addon.db.skirmishes)

    -- A pure incoming PvP hit opens a reciprocal-history entry despite zero
    -- deaths, HKs and honor and no feed from the combat-log event.
    ResetSnapshot()
    Link(7, localID, "First Enemy", "HUNTER", 48)
    Begin()
    End(elapsed)
    Advance(1.5)
    local duel = Battle(1)
    assert(#duel.allies == 1 and #duel.enemies == 1 and duel.enemies[1].id == fenrik)
    assert(duel.origin == "world" and duel.observation.segments[1].confirmedBy == "meter")
    assert(duel.observation.segments[1].meter.hostileLinks[1].opponentID == fenrik)
    local duelSegment = duel.observation.segments[1]
    assert(duelSegment.endReason == "local-combat-ended")
    assert(duelSegment.contacts[fenrik].first <= duelSegment.contacts[fenrik].last)
    assert(duelSegment.contacts[fenrik].signal == "combat-end")
    NoRewards(duel)
    local rival = addon.Ledger.Find(addon.db, fenrik)
    assert(rival.displayName == "First Enemy" and rival.killsAgainstThem == 0 and rival.deathsToThem == 0)
    CheckReward(fenrik, 0, 0)
    addon.RecordSkirmish("world:1", duel)
    assert(#addon.Ledger.RivalSkirmishes(addon.db, fenrik) == 1)
    assert(addon.Ledger.Open(addon.db).skirmishes["world:1"] == duel)

    -- The same Current slot contains another local window. A heal links the
    -- player to the new engagement, and a disconnected fight is left out.
    ResetSnapshot()
    Link(2, localID, "Thoren Ironbrook", "PRIEST", 30)
    Link(7, brother, "Second Enemy", "SHAMAN", 24)
    Link(7, brother, "First Enemy", "HUNTER", 15)
    Link(7, units.nameplate2[1], "Other Enemy", "ROGUE", 20)
    Begin()
    End(elapsed)
    Advance(1.5)
    local group = Battle(2)
    assert(#group.allies == 2 and #group.enemies == 2)
    assert(#group.observation.segments == 1 and group ~= duel)
    NoRewards(group)

    -- Start a real interaction, then confirm a killing blow in the same
    -- window. A loss of nameplate visibility never adds a death or a fight.
    ResetSnapshot()
    Begin()
    Aura("player", "target", 666)
    Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    Advance(0.2)
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Aura("player", "target", 666)
    Fire("PARTY_KILL", localID, fenrik)
    End(elapsed - 0.2)
    Advance(1.5)
    local kill = Battle(3)
    local phase = kill.observation.segments[1]
    assert(#kill.events == 1 and not addon.db.skirmishes["world:4"])
    assert(phase.confirmedBy == "harmful-aura" and phase.actions[1].count == 2)
    assert(phase.actions[1].first < phase.actions[1].last)

    -- An observed attack between known participants during the pause is
    -- independent corroboration. A second local window can join the same
    -- battle; a different hostile player in the next window cannot.
    ResetSnapshot()
    Begin()
    Aura("player", "target", 667)
    Aura("party1", "target", 668)
    End(elapsed)
    Advance(0.1)
    Aura("party1", "target", 668)
    Begin()
    Aura("target", "player", 669)
    End(elapsed)
    Advance(1.5)
    local pause = Battle(4)
    assert(#pause.observation.segments == 2 and #pause.allies == 2)
    assert(pause.observation.segments[2].continuation == "observed-hostility")
    assert(not addon.db.skirmishes["world:5"])
    NoRewards(pause)

    -- Two disconnected windows with the same player, Current slot and a
    -- very short gap stay separate. Safe live evidence survives a canceled
    -- meter read and pending read in the following window.
    ResetSnapshot()
    Begin()
    Aura("player", "target", 670)
    End(elapsed)
    Advance(0.1)
    Begin()
    Aura("player", "mouseover", 671)
    End(elapsed)
    Advance(1.5)
    assert(Battle(5).enemies[1].id == fenrik and Battle(6).enemies[1].id == ghash)
    NoRewards(Battle(5))
    NoRewards(Battle(6))

    -- Death itself keeps the observed roster; release records a gap.
    -- A readable hostile action by those same allies after return can
    -- establish continuity, without fabricating actions while ghosted.
    ResetSnapshot()
    Begin()
    Aura("player", "target", 672)
    Aura("party1", "target", 673)
    Advance(2)
    dead = true
    recap = { { sourceGUID = fenrik, sourceName = "First Enemy", sourceFlags = 0x440,
        timestamp = GetServerTime(), overkill = 3 } }
    Fire("PLAYER_DEAD")
    assert(Battle(7).observation.segments[1].endReason == nil)
    End(2)
    Advance(0.2)
    ghost = true
    Fire("PLAYER_ALIVE")
    Aura("party1", "target", 674)
    Advance(1)
    dead, ghost = false, false
    Fire("PLAYER_UNGHOST")
    Aura("party1", "target", 675)
    Begin()
    Aura("target", "player", 676)
    End(elapsed)
    Advance(1.5)
    local returned = Battle(7)
    assert(#returned.events == 2 and returned.events[2].kind == "revive" and #returned.observation.segments == 2)
    assert(not returned.observation.visibilityGap)
    local life = returned.observation.life
    assert(life[1].state == "dead" and life[2].state == "ghost" and life[3].state == "alive")
    assert(returned.observation.segments[1].actions[2].count == 3)
    assert(not addon.db.skirmishes["world:8"])

    -- After a longer unobserved interval, a fresh action involving the same
    -- rival cannot by itself establish continuity with the earlier fight.
    ResetSnapshot()
    Begin()
    Aura("player", "target", 677)
    Advance(2)
    dead = true
    recap = { { sourceGUID = fenrik, sourceName = "First Enemy", sourceFlags = 0x440,
        timestamp = GetServerTime(), overkill = 1 } }
    Fire("PLAYER_DEAD")
    End(2)
    ghost = true
    Fire("PLAYER_ALIVE")
    Advance(12)
    dead, ghost = false, false
    Fire("PLAYER_UNGHOST")
    Aura("party1", "target", 678)
    Begin()
    Aura("player", "target", 679)
    End(elapsed)
    Advance(1.5)
    assert(#Battle(8).events == 1 and not Battle(8).observation.visibilityGap)
    assert(not addon.Ledger.SkirmishOutcome(Battle(8)))
    assert(Battle(9).enemies[1].id == fenrik and #Battle(9).observation.segments == 1)
    NoRewards(Battle(9))

    -- A restricted snapshot and secret aura are not evidence. A fresh late
    -- read within the known window can later confirm a different candidate.
    ResetSnapshot()
    restricted = true
    Begin()
    Fire("UNIT_AURA", "player", { addedAuras = { { sourceUnit = secretMeter, isHarmful = true } } })
    Fire("UNIT_AURA", "player", { isFullUpdate = true, addedAuras = {
        { sourceUnit = "target", isHarmful = true },
    } })
    End(elapsed)
    Advance(1.5)
    assert(not addon.db.skirmishes["world:10"])

    ResetSnapshot()
    Link(7, localID, "Second Enemy", "SHAMAN", 17)
    Begin()
    End(elapsed)
    Advance(0.5)
    assert(not addon.db.skirmishes["world:10"])
    restricted = false
    Advance(1)
    assert(Battle(10).enemies[1].id == ghash)
    NoRewards(Battle(10))

    -- Native formal-duel completion before settling vetoes a provisional record.
    ResetSnapshot()
    Begin()
    Aura("player", "target", 680)
    End(elapsed)
    Fire("DUEL_FINISHED")
    Advance(1.5)
    assert(not addon.db.skirmishes["world:11"])

    -- A confirmed death recap is bound to the window captured at PLAYER_DEAD,
    -- including when a zone transition and a new fight precede the callback.
    ResetSnapshot()
    Begin()
    Aura("player", "target", 681)
    Advance(2)
    recap = nil
    Fire("PLAYER_DEAD")
    local deathAt = GetServerTime()
    End(0)
    local previousZone = GetRealZoneText
    function GetRealZoneText() return "Elwynn Forest" end
    Fire("PLAYER_LEAVING_WORLD")
    local oldFight = Battle(11)
    assert(#oldFight.events == 1 and oldFight.events[1].kind == "death"
        and not oldFight.events[1].actorID and oldFight.observation.visibilityGap)
    Begin()
    Aura("player", "mouseover", 682)
    recap = { { sourceGUID = fenrik, sourceName = "First Enemy", sourceFlags = 0x440,
        timestamp = deathAt, overkill = 2 } }
    End(elapsed)
    Advance(1.5)
    assert(#oldFight.events == 1 and oldFight.events[1].actorID == fenrik)
    assert(Battle(12).enemies[1].id == ghash)
    NoRewards(Battle(12))
    GetRealZoneText = previousZone
end
print("Validated kill-free journal records, connected continuations, ghost gaps and independent combat windows")

do
    addon.ResetData()
    inCombat, recap = false, nil
    Advance(10)

    local ally, enemy, localID = brother, fenrik, units.player[1]
    units.target = { enemy, "First Enemy", "Horde", "HUNTER" }
    units.mouseover = nil
    units.party1 = { ally, "Thoren Ironbrook", "Alliance", "PRIEST" }
    units.nameplate1, units.nameplate2, units.nameplate3 = nil, nil, nil

    local dead, fighting, hidden, position = {}, {}, {}, {}
    local spirit = false
    local function ResetStates()
        dead, fighting, hidden = {}, {}, {}
        position = { [localID] = 100, [ally] = 109, [enemy] = 112 }
        spirit = false
    end
    function UnitPosition(unit)
        local x = position[UnitGUID(unit)]
        if x then return x, 100, 0, 1 end
    end
    function UnitIsVisible(unit) local guid = UnitGUID(unit); return guid ~= nil and not hidden[guid] end
    function UnitIsDeadOrGhost(unit) return dead[UnitGUID(unit)] == true end
    function UnitIsGhost(unit) return unit == "player" and spirit end
    function UnitIsFeignDeath() return false end
    function UnitAffectingCombat(unit) return fighting[UnitGUID(unit)] == true end
    local function Aura(actor, target)
        Fire("UNIT_AURA", target, { addedAuras = { { sourceUnit = actor, isHarmful = true, spellId = 681 } } })
    end
    local function BeginFight()
        inCombat = true
        Fire("PLAYER_REGEN_DISABLED")
        Aura("player", "target")
        Aura("party1", "target")
    end
    local function Death()
        dead[localID] = true
        recap = { { sourceGUID = enemy, sourceName = "First Enemy", sourceFlags = 0x440,
            timestamp = GetServerTime(), overkill = 4 } }
        Fire("PLAYER_DEAD")
    end
    local function EndFight()
        inCombat = false
        Fire("PLAYER_REGEN_ENABLED")
    end
    local function Battle(id) return assert(addon.db.skirmishes["world:" .. id]) end

    for _, linkedTarget in ipairs({ "party1", "player", "unrelated" }) do
        addon.ResetData()
        ResetStates()
        BeginFight()
        fighting[ally], fighting[enemy] = true, true
        units.unrelated = { "Player-unrelated", "Other Player", "Alliance" }
        units.targettarget = units[linkedTarget]
        Fire("PLAYER_LEAVING_WORLD")
        units.targettarget, units.unrelated = nil, nil
        local interrupted = Battle(1)
        assert(interrupted.observation.visibilityGap and not interrupted.rosterComplete)
        assert(addon.Ledger.HasRosterGap(interrupted) == (linkedTarget == "party1"))
        local verdict = addon.Ledger.JournalOutcome(interrupted)
        assert(addon.Ledger.Open(addon.db).skirmishes["world:1"] == interrupted)
        assert(addon.Ledger.JournalOutcome(interrupted) == verdict)
        assert(addon.Ledger.HasRosterGap(interrupted) == (linkedTarget == "party1"))
    end
    addon.ResetData()

    -- Continue while lying in the corpse. A late party kill joins the
    -- original battle and the visible ally, not the dead player, holds it.
    C_DamageMeter = nil
    ResetStates()
    BeginFight()
    Advance(2)
    Death()
    fighting[ally], fighting[enemy] = true, true
    EndFight()
    Advance(3)
    local corpse = Battle(1)
    assert(corpse.observation.playerState == "dead" and not corpse.observation.visibilityGap)
    assert(not addon.Ledger.SkirmishOutcome(corpse) and corpse.resolution.reason == "participants-still-in-combat")
    Aura("party1", "target")
    Advance(1)
    dead[enemy], fighting[enemy], fighting[ally] = true, false, false
    Fire("PARTY_KILL", ally, enemy)
    Advance(3)
    assert(#corpse.events == 2 and not addon.db.skirmishes["world:2"])
    assert(addon.Ledger.SkirmishOutcome(corpse) == "win" and corpse.resolution.ending == "observed")

    -- A released spirit can still receive readable native rows. A strictly
    -- comparable post-combat delta extends observation without becoming a
    -- kill, a retreat, or a verdict. Missing visible positions remain unknown.
    Advance(10)
    ResetStates()
    local damage, length, restricted = 22, 8, false
    local secretSample = {}
    function issecretvalue(value) return value == secretSample end
    Enum.DamageMeterType = { DamageTaken = 7 }
    Enum.DamageMeterSessionType = { Current = 1 }
    C_DamageMeter = {
        GetAvailableCombatSessions = function() return {} end,
        GetCombatSessionFromType = function(selector, category)
            assert(selector == 1 and category == 7)
            if restricted then return secretSample end
            return { durationSeconds = length, combatSources = { { sourceGUID = ally } } }
        end,
        GetCombatSessionSourceFromType = function(_, _, guid)
            assert(guid == ally)
            return { combatSpells = { { combatSpellDetails = {
                unitName = "First Enemy", unitClassFilename = "HUNTER", isMob = false, isPet = false,
                amount = damage,
            } } } }
        end,
    }

    BeginFight()
    Advance(8)
    Death()
    fighting[ally], fighting[enemy] = true, true
    Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 7, 0)
    EndFight()
    Advance(1.5)
    local ghostFight = Battle(2)
    assert(ghostFight.resolution.meter == "baseline-ready")
    spirit = true
    Fire("PLAYER_ALIVE")
    Fire("ZONE_CHANGED_NEW_AREA") -- the signal without any actual area change
    hidden[ally], hidden[enemy] = true, true
    Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 7, 0)
    Advance(1.1)
    local state = ghostFight.observation.assessment
    assert(ghostFight.observation.playerState == "ghost" and not ghostFight.observation.visibilityGap)
    assert(state.meterStatus == "unchanged" and not state.lastMeterActivity)
    length, damage = 11, 35
    Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 7, 88)
    Advance(1.1)
    assert(not state.lastMeterActivity)
    Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 7, 0)
    Advance(1.1)
    local observed = state.lastMeterActivity
    assert(observed and state.meterPair.actorID == enemy and state.meterPair.targetID == ally)
    assert(#ghostFight.events == 1 and not addon.Ledger.SkirmishOutcome(ghostFight))
    local probe = NamesInRedDebugDB.rows[#NamesInRedDebugDB.rows]
    assert(probe.kind == "POST_COMBAT_METER_UPDATE" and probe.playerGhost and probe.status.meter == "linked-increase")
    local followups = ghostFight.combatDiagnostics.windows[1].meterFollowups
    local sample = followups[#followups]
    assert(sample.readOffset >= observed and sample.sessionID == 0 and sample.localGhost)
    assert(sample.status == "linked-increase" and sample.amountIncrease == 13 and sample.pairTotal == 35)
    assert(sample.actorID == enemy and sample.targetID == ally and not sample.offset)
    restricted = true
    Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 7, 0)
    Advance(1.1)
    assert(state.lastMeterActivity == observed and state.meterStatus == "secret")
    assert(followups[#followups].status == "secret" and not followups[#followups].amountIncrease)
    Advance(3)
    assert(not addon.Ledger.SkirmishOutcome(ghostFight) and ghostFight.resolution.coverage == "partial")

    -- A new corroborated action can still decide the outcome while ghosted.
    -- Resurrection later does not re-adjudicate the previously observed end.
    restricted = false
    hidden[ally], hidden[enemy] = false, false
    Aura("party1", "target")
    Advance(1)
    dead[enemy], fighting[ally], fighting[enemy] = true, false, false
    Fire("PARTY_KILL", ally, enemy)
    Advance(3)
    assert(#ghostFight.events == 2 and addon.Ledger.SkirmishOutcome(ghostFight) == "win")
    spirit, dead[localID] = false, false
    Fire("PLAYER_UNGHOST")
    assert(ghostFight.observation.playerState == "alive" and not ghostFight.observation.visibilityGap)
    assert(addon.Ledger.SkirmishOutcome(ghostFight) == "win")

    -- Actual movement away from the known area interrupts unfinished
    -- observation. Delayed reads from the old selector do not change it.
    Advance(10)
    ResetStates()
    BeginFight()
    Advance(8)
    Death()
    Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 7, 0)
    EndFight()
    Advance(1.5)
    local lost = Battle(3)
    spirit = true
    Fire("PLAYER_ALIVE")
    local previousZone = GetRealZoneText
    function GetRealZoneText() return "Elwynn Forest" end
    Fire("PLAYER_LEAVING_WORLD")
    length, damage = 15, 100
    Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 7, 0)
    Advance(3)
    GetRealZoneText = previousZone
    assert(lost.observation.visibilityGap and lost.resolution.reason == "left-world")
    assert(not addon.Ledger.SkirmishOutcome(lost) and #lost.events == 1)

    -- A later visible unit-state transition can trigger terminal reads even
    -- when no meter update or new aura is available after the local exit.
    C_DamageMeter = nil
    Advance(10)
    ResetStates()
    BeginFight()
    Advance(2)
    fighting[enemy] = true
    EndFight()
    Advance(3)
    local pressureWin = Battle(4)
    assert(not addon.Ledger.SkirmishOutcome(pressureWin))
    position[enemy], fighting[enemy] = 178, false
    Fire("UNIT_FLAGS", "target")
    Advance(3)
    assert(#pressureWin.events == 0 and addon.Ledger.SkirmishOutcome(pressureWin) == "win")
    assert(pressureWin.resolution.reason == "pressured-withdrawal")

    -- The native position API returns nothing for this hostile target.
    -- Only one terminal sample can still identify the withdrawing player.
    local inRange, checkedDistance, checked, minRange
    function UnitDistanceSquared(unit)
        if unit == "target" then return checkedDistance, checked end
    end
    C_Spell = {
        GetSpellInfo = function(id)
            assert(id == 681)
            return { minRange = minRange, maxRange = 40 }
        end,
        IsSpellHarmful = function(id) return id == 681 end,
        IsSpellInRange = function(_, unit)
            assert(unit == "target")
            return inRange
        end,
    }
    local function LateRangeRead(distance, probeIsChecked, atExit, minimum, vanishEarly)
        Advance(10)
        ResetStates()
        position[enemy] = nil
        inRange, minRange = true, minimum
        checkedDistance, checked = 16^2, probeIsChecked
        BeginFight()
        Advance(4)
        checkedDistance, inRange = distance, atExit
        EndFight()
        if not vanishEarly then Advance(1) end
        hidden[enemy] = true
        Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
        Advance(3)
    end

    LateRangeRead(41^2, true, nil, 8, false)
    local checkedWin = Battle(5)
    assert(checkedWin.resolution.reason == "pressured-range-withdrawal")
    assert(checkedWin.observation.assessment.first.units[enemy].position == nil)
    assert(checkedWin.observation.assessment.last.units[enemy] == nil)

    LateRangeRead(0, false, false, 0, false)
    assert(addon.Ledger.SkirmishOutcome(Battle(6)) == "win")

    LateRangeRead(0, false, secretSample, 0, false)
    assert(not addon.Ledger.SkirmishOutcome(Battle(7)))

    LateRangeRead(0, false, false, 0, true)
    assert(not addon.Ledger.SkirmishOutcome(Battle(8))) -- lost before a readable exit

    LateRangeRead(0, false, false, 8, false)
    assert(not addon.Ledger.SkirmishOutcome(Battle(9))) -- false could mean too close

    -- Full 2 × 3 sequence using real event entry points. The two bodies
    -- leave the observable roster long before the last enemy withdraws.
    Advance(10)
    ResetStates()
    local third = "Player-third-range"
    position[enemy] = nil
    checked, minRange, inRange = false, 0, true
    BeginFight()
    Advance(10)
    dead[enemy] = true
    Fire("PARTY_KILL", localID, enemy)
    units.target = { ghash, "Second Enemy", "Horde", "SHAMAN" }
    Aura("party1", "target")
    Advance(10)
    dead[ghash] = true
    Fire("PARTY_KILL", localID, ghash)
    units.target = { third, "Last Enemy", "Horde", "PALADIN" }
    Advance(15)
    Aura("player", "target")
    Advance(5)
    inRange = false
    EndFight()
    Advance(1)
    hidden[third] = true
    Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    Advance(3)
    local longWin = Battle(10)
    assert(#longWin.allies == 2 and #longWin.enemies == 3 and #longWin.events == 2)
    assert(longWin.resolution.outcome == "win" and longWin.resolution.enemies.dead == 2)
    assert(longWin.resolution.reason == "pressured-range-withdrawal")
    assert(not addon.Ledger.FirstDeaths(longWin)[third])

    -- A witnessed resurrection changes life state without deleting either
    -- actor's finishing blow or deciding the group result.
    Advance(10)
    ResetStates()
    C_DamageMeter, C_Spell, UnitDistanceSquared = nil, nil, nil
    local druid = "Player-druid-life"
    units.target = { enemy, "First Enemy", "Horde", "HUNTER" }
    units.mouseover = { druid, "Hostile Druid", "Horde", "DRUID" }
    position[druid] = 115
    BeginFight()
    Aura("mouseover", "player")
    Advance(1)
    dead[enemy] = true
    Fire("PARTY_KILL", localID, enemy)
    Fire("PARTY_KILL", localID, enemy)
    local reciprocal = Battle(11)
    assert(#reciprocal.events == 1)
    Fire("INCOMING_RESURRECT_CHANGED", "target")
    Fire("UNIT_FLAGS", "target")
    assert(#reciprocal.events == 1) -- an offer and a corpse are insufficient
    Advance(1)
    dead[enemy], hidden[enemy] = false, true
    Fire("UNIT_FLAGS", "target")
    assert(#reciprocal.events == 1)
    hidden[enemy] = false
    Fire("UNIT_FLAGS", "target")
    Fire("NAME_PLATE_UNIT_ADDED", "target")
    assert(#reciprocal.events == 2 and reciprocal.events[2].kind == "revive")
    assert(not reciprocal.events[2].actorID and not reciprocal.events[2].spellID)
    Advance(1)
    dead[druid] = true
    Fire("PARTY_KILL", ally, druid)
    Advance(1)
    Death()
    Fire("PLAYER_DEAD") -- same lethal recap
    Aura("party1", "target")
    Advance(5)
    position[enemy] = 177
    EndFight()
    Advance(3)
    assert(#reciprocal.events == 4 and addon.Ledger.SkirmishOutcome(reciprocal) == "win")
    assert(addon.Ledger.ParticipantLife(reciprocal)[enemy].kind == "revive")
    assert(addon.Ledger.ParticipantLife(reciprocal)[localID].kind == "kill")
    assert(addon.Ledger.FirstDeaths(reciprocal)[enemy] == 1)
    local personalKills, personalDeaths = addon.Ledger.PersonalCombatScore(addon.db, enemy)
    -- Isolate a save of the same real battle to verify that indexing is idempotent.
    local savedAgain = addon.Ledger.Open(nil)
    addon.Ledger.SaveSkirmish(savedAgain, "world:1", reciprocal)
    addon.Ledger.SaveSkirmish(savedAgain, "world:1", reciprocal)
    local direct, received = addon.Ledger.PersonalCombatScore(savedAgain, enemy)
    assert(direct == 1 and received == 1)
    local victories, defeats, earned, points = addon.Ledger.PersonalScore(savedAgain, enemy)
    assert(victories == 1 and defeats == 0 and earned == 0 and points == 0)
    local summary = addon.Ledger.RivalSkirmishes(savedAgain, enemy)[1]
    assert(summary.opponentRevived and summary.opponentDeathIndex and not summary.playerRevived)

    -- An old notification can arrive even after revival. The corpse check
    -- prevents it while the target lives and tolerates delayed native flags
    -- on a genuine second killing blow.
    Advance(10)
    ResetStates()
    BeginFight()
    Advance(1)
    dead[enemy] = true
    Fire("PARTY_KILL", localID, enemy)
    Advance(1)
    dead[enemy] = false
    Fire("PLAYER_TARGET_CHANGED")
    Fire("PARTY_KILL", localID, enemy) -- still alive through the retry
    Advance(0.4)
    local repeated = Battle(12)
    assert(#repeated.events == 2 and repeated.events[2].kind == "revive")
    Fire("PARTY_KILL", localID, enemy)
    Advance(0.1)
    dead[enemy] = true
    Fire("UNIT_FLAGS", "target")
    Fire("PARTY_KILL", localID, enemy)
    Advance(0.3)
    assert(#repeated.events == 3 and repeated.events[3].kind == "kill")
    EndFight()
    Advance(4)
    Fire("PARTY_KILL", localID, enemy) -- delayed delivery after the window
    assert(not addon.db.skirmishes["world:13"] and #repeated.events == 3)
    direct, received = addon.Ledger.PersonalCombatScore(addon.db, enemy)
    assert(direct == personalKills + 2 and received == personalDeaths)
    local earnedHK, earnedHonor = addon.Ledger.SkirmishRewards(repeated)
    assert(earnedHK == 0 and earnedHonor == 0)

    -- Same battle after the local character rejoins. Only linked hostility
    -- carries the candidate into the previous record.
    Advance(10)
    ResetStates()
    BeginFight()
    Advance(1)
    Death()
    EndFight()
    Advance(0.3)
    spirit = true
    Fire("PLAYER_ALIVE")
    Aura("party1", "target")
    Advance(0.5)
    spirit, dead[localID] = false, false
    Fire("PLAYER_UNGHOST")
    BeginFight()
    Advance(1)
    dead[enemy] = true
    Fire("PARTY_KILL", localID, enemy)
    EndFight()
    Advance(3)
    local joined = Battle(13)
    assert(#joined.observation.segments == 2 and #joined.events == 3 and not addon.db.skirmishes["world:14"])
    assert(joined.events[2].kind == "revive" and joined.events[2].targetID == localID)
    assert(addon.Ledger.SkirmishOutcome(joined) == "win")


    -- Player state can be confirmed before a delayed recap arrives. Both
    -- facts must keep their original high-resolution order.
    Advance(10)
    ResetStates()
    BeginFight()
    Advance(1)
    dead[localID], recap = true, nil
    local killedAt = GetServerTime()
    Fire("PLAYER_DEAD")
    Advance(0.1)
    dead[localID] = false
    Fire("PLAYER_ALIVE") -- direct combat resurrection, without release
    recap = { { sourceGUID = enemy, sourceName = "First Enemy", sourceFlags = 0x440,
        timestamp = killedAt, overkill = 4 } }
    Advance(0.25)
    local delayed = Battle(14)
    assert(#delayed.events == 2 and delayed.events[1].kind == "kill" and delayed.events[2].kind == "revive")
    assert(delayed.events[1].time == delayed.events[2].time and delayed.events[1].offset < delayed.events[2].offset)

    -- No corpse snapshot was available. An early alive flag can be stale,
    -- but a new visible alive sighting in the same fight may confirm recovery.
    hidden[enemy] = true
    Fire("PARTY_KILL", localID, enemy)
    hidden[enemy] = false
    Advance(0.1)
    Fire("UNIT_FLAGS", "target")
    assert(#delayed.events == 3)
    Advance(0.6)
    Fire("NAME_PLATE_UNIT_ADDED", "target")
    assert(#delayed.events == 4 and delayed.events[4].kind == "revive")
    assert(delayed.events[4].source == "nameplate-sighting" and not delayed.events[4].actorID)


    -- A druid can revive an ally whose corpse was seen but whose killer
    -- was unavailable. The life transition never becomes a personal kill.
    dead[ally] = true
    Fire("UNIT_FLAGS", "party1")
    Fire("INCOMING_RESURRECT_CHANGED", "party1")
    assert(#delayed.events == 5 and delayed.events[5].kind == "death")
    assert(not delayed.events[5].actorID)
    Advance(0.6)
    dead[ally] = false
    Fire("UNIT_FLAGS", "party1")
    assert(#delayed.events == 6 and delayed.events[6].kind == "revive")
    assert(delayed.events[6].targetID == ally and not delayed.events[6].actorID)

    -- The native kill can confirm a corpse we already observed without
    -- creating a second historical death event for the same life.
    dead[enemy] = true
    Fire("UNIT_FLAGS", "target")
    assert(#delayed.events == 7 and delayed.events[7].kind == "death")
    Advance(0.1)
    Fire("PARTY_KILL", localID, enemy)
    assert(#delayed.events == 7 and delayed.events[7].kind == "kill")

    -- A distinct validated lethal recap identifies a new local death even
    -- when the intervening return to life was missed.
    Advance(1)
    Death()
    Advance(2)
    dead[localID] = false
    Death()
    Fire("PLAYER_DEAD")
    assert(#delayed.events == 9 and delayed.events[8].kind == "kill" and delayed.events[9].kind == "kill")
    assert(delayed.events[8].recapTimestamp < delayed.events[9].recapTimestamp)

end
print("Corpse and spirit observations, range exits, revivals, repeat kills and independent scores passed")
