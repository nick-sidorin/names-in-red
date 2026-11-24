local _, addon = ...
local Ledger = {}
addon.Ledger = Ledger
local skirmishIndexes = setmetatable({}, { __mode = "k" })

local function ObservedDuel(battle)
    if #battle.allies ~= 1 or #battle.enemies ~= 1 then return false end
    local segments = battle.observation and battle.observation.segments
    if segments and segments[1] and segments[1].endReason == "standalone-event"
        and segments[1].startReason == "death" then return false end
    local player, rival = battle.allies[1], battle.enemies[1]
    if not player.isSelf or not player.id or not rival.id or player.id == rival.id then return false end
    local directKill = false
    for _, event in ipairs(battle.events) do
        if event.kind == "kill" then
            local won = event.actorID == player.id and event.targetID == rival.id
            local lost = event.actorID == rival.id and event.targetID == player.id
            if not won and not lost then return false end
            directKill = true
        end
    end
    return directKill
end

local function UpdateWorldRoster(id, battle)
    if type(id) == "string" and (id:match("^world:%d+$") or id:match("^bg:%d+$")) then
        battle.rosterComplete = battle.origin ~= "battleground" and ObservedDuel(battle)
        if battle.observation and battle.observation.assessment and addon.EvaluateWorldSkirmish then
            battle.resolution = addon.EvaluateWorldSkirmish(battle)
        end
    end
end

local function IsSkirmish(battle)
    return type(battle) == "table" and type(battle.allies) == "table"
        and type(battle.enemies) == "table" and type(battle.events) == "table"
end

local meterHistoryCategories = { "DamageDone", "DamageTaken", "EnemyDamageTaken", "HealingDone", "Absorbs" }

-- Preserve linked amounts as separate aggregates per segment and category.
-- Other fields in the diagnostic probe describe API reads and restrictions.
function Ledger.RecordMeterAggregates(battle, segment, probe)
    if segment.combatAggregates or type(probe) ~= "table" or type(probe.categories) ~= "table" then return end
    local roster, aggregates = {}, {}
    for _, side in ipairs({ battle.allies, battle.enemies }) do
        for _, player in ipairs(side) do if player.id then roster[player.id] = true end end
    end
    for _, category in ipairs(meterHistoryCategories) do
        local group = probe.categories[category]
        if type(group) == "table" and type(group.rows) == "table" then
            for _, row in ipairs(group.rows) do
                if type(row) == "table" and row.resolution == "link" and roster[row.meterUnitID] and roster[row.otherID]
                    and type(row.amount) == "number" and row.amount > 0 and row.amount < math.huge then
                    local actor, target = row.meterUnitID, row.otherID
                    local taken = category == "DamageTaken" or category == "EnemyDamageTaken"
                    if taken then actor, target = target, actor end
                    local spell = row.spellID
                    if type(spell) ~= "number" or not (spell > 0 and spell < math.huge) then spell = nil end
                    aggregates[#aggregates + 1] = { category = category, actorID = actor, targetID = target,
                        spellID = spell, amount = row.amount,
                        petEndpoint = row.petOwner == true and (taken and "target" or "actor") or nil }
                end
            end
        end
    end
    if #aggregates > 0 then segment.combatAggregates = aggregates end
end

local function RestoreMeterAggregates(battle)
    local journal = battle.combatDiagnostics
    local segments = battle.observation and battle.observation.segments
    if type(journal) ~= "table" or journal.version ~= 1 or type(journal.windows) ~= "table"
        or type(segments) ~= "table" then return end
    -- Prior builds saved the probe by local window. Only promote a read
    -- when both the window and the meter read match one saved segment.
    local byStart = {}
    for _, segment in ipairs(segments) do
        local started = segment.localCombatAt or segment.startedAt
        if type(started) == "number" and type(segment.meter) == "table" then
            byStart[started] = byStart[started] == nil and segment or false
        end
    end
    local matches = {}
    for _, window in ipairs(journal.windows) do
        local segment = byStart[window.time]
        local meter = window.meter
        if segment and type(meter) == "table" and meter.selection
            and meter.selection == segment.meter.selection and meter.sessionID == segment.meter.sessionID then
            matches[segment] = matches[segment] == nil and meter or false
        end
    end
    for segment, meter in pairs(matches) do
        if meter then Ledger.RecordMeterAggregates(battle, segment, meter) end
    end
end

function Ledger.Open(saved)
    if saved == nil then
        return { version = 1, rivals = {} }
    end
    if type(saved) == "table" and saved.version == 1 and type(saved.rivals) == "table" then
        if type(saved.skirmishes) == "table" then
            for id, battle in pairs(saved.skirmishes) do
                if IsSkirmish(battle) then
                    UpdateWorldRoster(id, battle)
                    RestoreMeterAggregates(battle)
                    if addon.RefreshPersonalSkirmish then addon.RefreshPersonalSkirmish(battle, true) end
                end
            end
        end
        if addon.RestoreCombatDiagnostics then addon.RestoreCombatDiagnostics(saved) end
        skirmishIndexes[saved] = nil
        return saved
    end
end

function Ledger.Clear(db)
    db.rivals = {}
    db.skirmishes = nil
    db.encounterSequence = nil
    db.lastDeathTimestamp = nil
    db.unassignedRewards = nil
    if addon.RestoreCombatDiagnostics then addon.RestoreCombatDiagnostics(db) end
    skirmishIndexes[db] = nil
end

-- The caller resolves a stable identifier before writing to the ledger.
function Ledger.Find(db, id)
    return db.rivals[id]
end

function Ledger.Add(db, id, displayName)
    if type(id) ~= "string" or id == "" then return end
    if displayName == nil and id:match("^Player%-.+") then
        displayName = ""
    elseif type(displayName) ~= "string" or displayName == "" then
        return nil
    end
    if not db.rivals[id] then
        db.rivals[id] = { displayName = displayName, deathsToThem = 0, killsAgainstThem = 0 }
    end
    return db.rivals[id]
end

function Ledger.Remove(db, id)
    if type(id) == "string" then
        db.rivals[id] = nil
        -- Keep the shared battle and its timeline when removing a rival's history.
        for _, battle in pairs(db.skirmishes or {}) do
            for _, opponent in ipairs(battle.enemies) do
                if opponent.rivalID == id then opponent.rivalID = nil end
            end
        end
        skirmishIndexes[db] = nil
    end
end

-- One battle record owns its roster and events. IDs in events are local to
-- that battle, and rival IDs are optional links to the personal ledger.
function Ledger.SaveSkirmish(db, id, skirmish)
    if type(id) ~= "string" or id == "" or not IsSkirmish(skirmish) then return end
    UpdateWorldRoster(id, skirmish)
    if addon.RefreshPersonalSkirmish then addon.RefreshPersonalSkirmish(skirmish) end
    db.skirmishes = db.skirmishes or {}
    db.skirmishes[id] = skirmish
    skirmishIndexes[db] = nil
    return skirmish
end

function Ledger.RemoveSkirmish(db, id)
    if db.skirmishes then
        if addon.ForgetCombatDiagnostics then addon.ForgetCombatDiagnostics(db, db.skirmishes[id]) end
        db.skirmishes[id] = nil
        skirmishIndexes[db] = nil
    end
end

function Ledger.EncounterOutcome(encounter)
    if encounter.outcome == "win" or encounter.outcome == "loss" then return encounter.outcome end
    if encounter.manual then
        if encounter.direction == "killsAgainstThem" then return "win" end
        if encounter.direction == "deathsToThem" then return "loss" end
    end
end

-- Live observations use a monotonic offset. Older rows retain their
-- server timestamp and existing timeline order when two stamps tie.
function Ledger.LaterBattleEvent(a, b)
    if type(a.offset) == "number" and type(b.offset) == "number" then return a.offset > b.offset end
    return type(a.time) == "number" and type(b.time) == "number" and a.time > b.time
end

function Ledger.IndicatesDeath(event)
    return event and (event.kind == "kill" or event.kind == "death")
end

-- A fresh PARTY_KILL can precede the victim's unit-state update.
function Ledger.CanObserveRevival(death, stamp)
    if not Ledger.IndicatesDeath(death) or not Ledger.LaterBattleEvent(stamp, death) then return false end
    return death.source ~= "party-kill" or death.observedDead == true
        or type(death.offset) ~= "number" or type(stamp.offset) ~= "number" or stamp.offset - death.offset >= 0.5
end

local function IsLifeEvent(event)
    return event.targetID and (Ledger.IndicatesDeath(event) or event.kind == "revive")
end

function Ledger.LatestParticipantLife(battle, id, cutoff)
    for index = #battle.events, 1, -1 do
        local event = battle.events[index]
        if event.targetID == id and IsLifeEvent(event) and (not cutoff or not Ledger.LaterBattleEvent(event, cutoff)) then
            return event
        end
    end
end

function Ledger.ParticipantLife(battle, cutoff)
    local life = {}
    for _, event in ipairs(battle.events) do
        if IsLifeEvent(event) and (not cutoff or not Ledger.LaterBattleEvent(event, cutoff)) then
            life[event.targetID] = event
        end
    end
    return life
end

local function Deaths(battle)
    local dead = {}
    for id, event in pairs(Ledger.ParticipantLife(battle)) do
        if Ledger.IndicatesDeath(event) then dead[id] = true end
    end
    return dead
end

local function SideEliminated(side, dead)
    for _, participant in ipairs(side) do
        if not dead[participant.id] then return false end
    end
    return #side > 0
end

local function LocalParticipant(battle)
    for _, ally in ipairs(battle.allies) do
        if ally.isSelf and ally.id then return ally end
    end
end

function Ledger.SkirmishOutcome(battle)
    local player = LocalParticipant(battle)
    if not player then return end
    local outcome = Ledger.EncounterOutcome(battle)
    if not outcome and battle.observation and battle.observation.assessment then
        outcome = battle.resolution and battle.resolution.outcome
    elseif not outcome and battle.rosterComplete == true and #battle.enemies > 0 then
        local dead = Deaths(battle)
        local alliesEliminated = SideEliminated(battle.allies, dead)
        local enemiesEliminated = SideEliminated(battle.enemies, dead)
        if alliesEliminated ~= enemiesEliminated then
            outcome = enemiesEliminated and "win" or "loss"
        end
    end
    return outcome, player
end

-- Use deaths across the whole battle for the portrait markers, including
-- players who were later resurrected. The outcome uses the final known state.
function Ledger.FirstDeaths(battle)
    local firstDeath = {}
    for index, event in ipairs(battle.events) do
        if Ledger.IndicatesDeath(event) and event.targetID then
            firstDeath[event.targetID] = firstDeath[event.targetID] or index
        end
    end
    return firstDeath
end

function Ledger.AddRewards(owner, key, honorableKills, honor)
    if honorableKills == 0 and honor == 0 then return end
    local rewards = owner[key] or { honorableKills = 0, honor = 0 }
    rewards.honorableKills = (rewards.honorableKills or 0) + honorableKills
    rewards.honor = (rewards.honor or 0) + honor
    owner[key] = rewards
end

function Ledger.SkirmishRewards(battle)
    local unassigned = battle.unassignedRewards or {}
    local honorableKills, honor = unassigned.honorableKills or 0, unassigned.honor or 0
    for _, reward in pairs(battle.rewards or {}) do
        honorableKills = honorableKills + (reward.honorableKills or 0)
        honor = honor + (reward.honor or 0)
    end
    return honorableKills, honor
end

function Ledger.JournalRewards(db)
    local unassigned = db.unassignedRewards or {}
    local total = {
        honorableKills = unassigned.honorableKills or 0, honor = unassigned.honor or 0,
        unassignedHK = unassigned.honorableKills or 0, unassignedHonor = unassigned.honor or 0,
    }
    for _, battle in pairs(db.skirmishes or {}) do
        local hk, honor = Ledger.SkirmishRewards(battle)
        total.honorableKills, total.honor = total.honorableKills + hk, total.honor + honor
    end
    for _, rival in pairs(db.rivals) do
        for _, encounter in ipairs(rival.encounters or {}) do
            total.honorableKills = total.honorableKills + (encounter.honorableKills or 0)
            total.honor = total.honor + (encounter.honor or 0)
        end
    end
    return total
end

local function IndexSkirmish(index, id, battle)
    local outcome, player = Ledger.SkirmishOutcome(battle)
    local firstDeath = Ledger.FirstDeaths(battle)
    local life = Ledger.ParticipantLife(battle)
    local kills, deaths = {}, {}
    if player then
        for _, event in ipairs(battle.events) do
            if event.kind == "kill" and event.actorID and event.targetID then
                if event.actorID == player.id then
                    kills[event.targetID] = (kills[event.targetID] or 0) + 1
                elseif event.targetID == player.id then
                    deaths[event.actorID] = (deaths[event.actorID] or 0) + 1
                end
            end
        end
    end
    local counted = {}
    for _, opponent in ipairs(battle.enemies) do
        local rivalID = opponent.rivalID
        if rivalID and opponent.id and not counted[rivalID] then
            counted[rivalID] = true
            local rival = index[rivalID]
            if not rival then
                rival = { wins = 0, losses = 0, personalKills = 0, personalDeaths = 0,
                    honorableKills = 0, honor = 0, encounters = {} }
                index[rivalID] = rival
            end
            local reward = battle.rewards and battle.rewards[opponent.id]
            local honorableKills, honor = reward and reward.honorableKills or 0, reward and reward.honor or 0
            local summary = {
                skirmishID = id, time = battle.time or battle.startedAt, sequence = battle.sequence,
                zone = battle.zone, mapID = battle.mapID, x = battle.x, y = battle.y,
                playerLevel = player and player.level, rivalLevel = opponent.level,
                player = player, opponent = opponent, outcome = outcome,
                playerDeathIndex = player and firstDeath[player.id], opponentDeathIndex = firstDeath[opponent.id],
                playerRevived = player and life[player.id] and life[player.id].kind == "revive",
                opponentRevived = life[opponent.id] and life[opponent.id].kind == "revive",
                honorableKills = honorableKills, honor = honor,
            }
            if outcome == "win" then rival.wins = rival.wins + 1 end
            if outcome == "loss" then rival.losses = rival.losses + 1 end
            rival.personalKills = rival.personalKills + (kills[opponent.id] or 0)
            rival.personalDeaths = rival.personalDeaths + (deaths[opponent.id] or 0)
            rival.honorableKills = rival.honorableKills + honorableKills
            rival.honor = rival.honor + honor
            rival.encounters[#rival.encounters + 1] = summary
        end
    end
end

local function RivalSkirmishIndex(db, id)
    local index = skirmishIndexes[db]
    if not index then
        index = {}
        for battleID, battle in pairs(db.skirmishes or {}) do
            IndexSkirmish(index, battleID, battle)
        end
        skirmishIndexes[db] = index
    end
    return index[id]
end

function Ledger.PersonalScore(db, id)
    local rival = db.rivals[id]
    local battles = RivalSkirmishIndex(db, id)
    local wins, losses = battles and battles.wins or 0, battles and battles.losses or 0
    for _, encounter in ipairs(rival and rival.encounters or {}) do
        local outcome = Ledger.EncounterOutcome(encounter)
        if outcome == "win" then wins = wins + 1 end
        if outcome == "loss" then losses = losses + 1 end
    end
    return wins, losses, battles and battles.honorableKills or 0, battles and battles.honor or 0
end

function Ledger.RivalSkirmishes(db, id)
    local battles = RivalSkirmishIndex(db, id)
    return battles and battles.encounters or {}
end

-- Direct finishing blows are independent of the side's outcome and rewards.
-- Old directional combat rows remain usable; manual outcomes have no actor.
function Ledger.PersonalCombatScore(db, id)
    local scored = RivalSkirmishIndex(db, id)
    local kills, deaths = scored and scored.personalKills or 0, scored and scored.personalDeaths or 0
    local rival = db.rivals[id]
    for _, encounter in ipairs(rival and rival.encounters or {}) do
        if not encounter.manual and not encounter.outcome then
            if encounter.direction == "killsAgainstThem" then kills = kills + 1
            elseif encounter.direction == "deathsToThem" then deaths = deaths + 1 end
        end
    end
    return kills, deaths
end
