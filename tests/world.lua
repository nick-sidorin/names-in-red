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
for _, file in ipairs({ "Ledger", "Encounter", "Core", "SkirmishEvidence", "WorldSkirmishes", "Honor", "Kills" }) do
    assert(loadfile("NamesInRed/" .. file .. ".lua"))("NamesInRed", addon)
end
addon.db = addon.Ledger.Open(nil)
Fire("PLAYER_ENTERING_WORLD")

local fenrik, ghash, brother = units.target[1], units.mouseover[1], units.party1[1]
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

-- Two eligible targets in one burst leave the grant unassigned.
inCombat = false
Fire("PLAYER_REGEN_ENABLED")
local observedRival = units.mouseover
units.mouseover = nil
Fire("PARTY_KILL", brother, ghash)
units.mouseover = observedRival
assert(battle.events[3].targetID == ghash)
GainHK()
Fire("PARTY_KILL", brother, fenrik)
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
assert(recorded.rosterComplete and addon.Ledger.SkirmishOutcome(recorded) == "loss")
local wins, losses = addon.Ledger.PersonalScore(addon.db, rogue.id)
assert(wins == 0 and losses == 1)
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

    -- An older Current slot must not enrich the next fight.
    Advance(10)
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
    Fire("ZONE_CHANGED_NEW_AREA")
    Advance(1.5)
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
    assert(endRow.meterSessionID == 77 and #addon.db.skirmishes["world:10"].allies == 2)

    ids = {}
    StartFight()
    ids = { { sessionID = 77 } }
    Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 2, 77)
    Advance(0.5)
    ids = { { sessionID = 78 } }
    Updates(78)
    Advance(1)
    endRow = NamesInRedDebugDB.rows[#NamesInRedDebugDB.rows]
    assert(endRow.status.meter == "session-changed-or-ambiguous" and #addon.db.skirmishes["world:11"].allies == 1)

    ids = {}
    StartFight()
    Advance(0.5)
    Updates(0)
    Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED")
    Advance(1)
    endRow = NamesInRedDebugDB.rows[#NamesInRedDebugDB.rows]
    assert(endRow.status.meter == "current-changed" and #addon.db.skirmishes["world:12"].allies == 1)

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
