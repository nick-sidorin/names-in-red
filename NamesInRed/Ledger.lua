local _, addon = ...
local Ledger = {}
addon.Ledger = Ledger
local skirmishIndexes = setmetatable({}, { __mode = "k" })
local legacyIndexes = setmetatable({}, { __mode = "k" })
local UpdateIndex

local recapDamageEvents = { SWING_DAMAGE = true, RANGE_DAMAGE = true, SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true }

function Ledger.IsDeathRecapDamage(effect)
    return type(effect) == "string" and recapDamageEvents[effect] == true
end

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

function Ledger.Open(saved, diagnostics)
    if saved == nil then
        return { version = 1, rivals = {} }
    end
    if type(saved) == "table" and saved.version == 1 and type(saved.rivals) == "table" then
        local changed
        if type(saved.skirmishes) == "table" then
            changed = addon.RestoreLegacyPetRecaps and addon.RestoreLegacyPetRecaps(saved.skirmishes, diagnostics)
            if addon.RestoreSplitSkirmishes then addon.RestoreSplitSkirmishes(saved.skirmishes, diagnostics) end
        end
        local meterWindows = addon.IndexMeterSourceTotalWindows and addon.IndexMeterSourceTotalWindows(diagnostics, saved.skirmishes or {})
        if meterWindows and addon.RestoreMissingOutgoingSkirmishes then addon.RestoreMissingOutgoingSkirmishes(saved, meterWindows) end
        if type(saved.skirmishes) == "table" then
            for id, battle in pairs(saved.skirmishes) do
                if IsSkirmish(battle) then
                    RestoreMeterAggregates(battle)
                    local meterChanged = meterWindows and addon.RestoreMeterSourceTotals(battle, meterWindows, saved.recoveredMeterWindows)
                    UpdateWorldRoster(id, battle)
                    if addon.RestoreRivalContributionEvidence then addon.RestoreRivalContributionEvidence(battle) end
                    if addon.RefreshPersonalSkirmish then
                        addon.RefreshPersonalSkirmish(battle, true, meterChanged or (changed and changed[battle]))
                    end
                end
            end
        end
        if addon.RestoreCombatDiagnostics then addon.RestoreCombatDiagnostics(saved) end
        skirmishIndexes[saved], legacyIndexes[saved] = nil, nil
        return saved
    end
end

function Ledger.Clear(db)
    db.rivals = {}
    db.skirmishes = nil
    db.encounterSequence = nil
    db.lastDeathTimestamp = nil
    db.unassignedRewards = nil
    db.recoveredMeterWindows = nil
    if addon.RestoreCombatDiagnostics then addon.RestoreCombatDiagnostics(db) end
    skirmishIndexes[db], legacyIndexes[db] = nil, nil
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

function Ledger.InvalidateRivalHistory(db, id)
    local index = legacyIndexes[db]
    if index then index[id] = nil end
end

function Ledger.Remove(db, id)
    if type(id) ~= "string" then return end
    db.rivals[id] = nil
    Ledger.InvalidateRivalHistory(db, id)
    -- Keep the shared battle and its timeline when removing a rival's history.
    local index = skirmishIndexes[db]
    for battleID, battle in pairs(db.skirmishes or {}) do
        local changed
        for _, opponent in ipairs(battle.enemies) do
            if opponent.rivalID == id then
                opponent.rivalID = nil
                changed = true
            end
        end
        local cached = index and index.battles[battleID]
        if index and (changed or (cached and cached.summaries[id])) then UpdateIndex(index, battleID, battle) end
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
    if skirmishIndexes[db] then UpdateIndex(skirmishIndexes[db], id, skirmish) end
    return skirmish
end

function Ledger.RemoveSkirmish(db, id)
    if db.skirmishes then
        if addon.ForgetCombatDiagnostics then addon.ForgetCombatDiagnostics(db, db.skirmishes[id]) end
        db.skirmishes[id] = nil
        if skirmishIndexes[db] then UpdateIndex(skirmishIndexes[db], id) end
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

function Ledger.AddSkirmishRewards(battle, opponentID, hk, honor)
    if opponentID then
        battle.rewards = battle.rewards or {}
        Ledger.AddRewards(battle.rewards, opponentID, hk, honor)
    else
        Ledger.AddRewards(battle, "unassignedRewards", hk, honor)
    end
end

function Ledger.MoveUnassignedRewards(owner, battle, hk, honor, opponentID)
    local rewards = owner.unassignedRewards
    if not rewards or (rewards.honorableKills or 0) < hk or (rewards.honor or 0) < honor then return end
    if owner == battle and not opponentID then return end
    Ledger.AddRewards(owner, "unassignedRewards", -hk, -honor)
    if owner == battle and rewards.honorableKills == 0 and rewards.honor == 0 then owner.unassignedRewards = nil end
    Ledger.AddSkirmishRewards(battle, opponentID, hk, honor)
    return true
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

-- UI and reports distinguish a retained side/manual verdict from a POV result.
function Ledger.JournalOutcome(battle)
    local personal = battle.personalOutcome
    if not battle.manual and type(personal) == "table" then
        if personal.lifecycle == "active" or personal.lifecycle == "awaiting" then return "ongoing" end
        local outcome = personal.outcome
        if outcome == "win" or outcome == "loss" or outcome == "draw" then return outcome end
        return "unknown"
    end
    local outcome = Ledger.EncounterOutcome(battle) or Ledger.SkirmishOutcome(battle)
    if battle.manual then return outcome or "unknown", "manual" end
    if outcome or battle.outcome or battle.resolution then return outcome or "unknown", "legacy" end
    return "unknown"
end

function Ledger.LegacyContribution(encounter, id)
    -- A timestamped old directional record with a resolved opponent is a
    -- literal encounter, independent of later side-outcome summaries.
    if encounter.manual or encounter.outcome or type(encounter.time) ~= "number"
        or not (encounter.time > 0 and encounter.time < math.huge)
        or type(id) ~= "string" or not id:match("^Player%-.+") then return end
    if encounter.direction == "killsAgainstThem" then return "win" end
    if encounter.direction == "deathsToThem" then return "loss" end
end

local function LegacyStats(db, id)
    local index = legacyIndexes[db]
    if not index then index = {}; legacyIndexes[db] = index end
    local rival = db.rivals[id]
    local entries = rival and rival.encounters
    local count = entries and #entries or 0
    local stats = index[id]
    if stats and stats.entries == entries and stats.count == count then return stats end
    stats = { entries = entries, count = count, wins = 0, losses = 0, manualWins = 0, manualLosses = 0,
        legacyWins = 0, legacyLosses = 0, kills = 0, deaths = 0, honorableKills = 0, honor = 0 }
    for _, encounter in ipairs(entries or {}) do
        local outcome = Ledger.EncounterOutcome(encounter)
        if outcome then
            local field = (encounter.manual and "manual" or "legacy") .. (outcome == "win" and "Wins" or "Losses")
            stats[field] = stats[field] + 1
        elseif not encounter.manual and not encounter.outcome then
            if encounter.direction == "killsAgainstThem" then stats.kills = stats.kills + 1
            elseif encounter.direction == "deathsToThem" then stats.deaths = stats.deaths + 1 end
            local credit = Ledger.LegacyContribution(encounter, id)
            if credit == "win" then stats.wins = stats.wins + 1
            elseif credit == "loss" then stats.losses = stats.losses + 1 end
        end
        stats.honorableKills = stats.honorableKills + (encounter.honorableKills or 0)
        stats.honor = stats.honor + (encounter.honor or 0)
    end
    index[id] = stats
    return stats
end

local indexedStats = { "wins", "losses", "personalKills", "personalDeaths", "honorableKills", "honor",
    "contributionWins", "contributionLosses", "legacyWins", "legacyLosses" }

local function ContributionEvidence(battle)
    if addon.EvaluateRivalContributions then return addon.EvaluateRivalContributions(battle) end
end

local function SummarizeSkirmish(id, battle)
    local outcome, player = Ledger.SkirmishOutcome(battle)
    local firstDeath, life = Ledger.FirstDeaths(battle), Ledger.ParticipantLife(battle)
    local kills, deaths, credits, summaries = {}, {}, {}, {}
    local projection = ContributionEvidence(battle)
    for _, credit in ipairs(projection and projection.credits or {}) do
        local totals = credits[credit.rivalID] or { win = 0, loss = 0 }
        totals[credit.direction] = totals[credit.direction] + 1
        credits[credit.rivalID] = totals
    end
    if player then
        for _, event in ipairs(battle.events) do
            -- A verified owner can be displayed for a pet finisher on a death event.
            -- These counters use only literal player kill events.
            if event.kind == "kill" and event.actorID and event.targetID then
                if event.actorID == player.id then
                    kills[event.targetID] = (kills[event.targetID] or 0) + 1
                elseif event.targetID == player.id then
                    deaths[event.actorID] = (deaths[event.actorID] or 0) + 1
                end
            end
        end
    end
    for _, opponent in ipairs(battle.enemies) do
        local rivalID = opponent.rivalID
        if rivalID and opponent.id and not summaries[rivalID] then
            local reward = battle.rewards and battle.rewards[opponent.id]
            local tally = credits[rivalID]
            local legacy = not battle.manual and not battle.personalOutcome and not tally
            summaries[rivalID] = {
                skirmishID = id, time = battle.time or battle.startedAt, sequence = battle.sequence,
                zone = battle.zone, mapID = battle.mapID, x = battle.x, y = battle.y, origin = battle.origin,
                playerLevel = player and player.level, rivalLevel = opponent.level,
                player = player, opponent = opponent, outcome = outcome, manual = battle.manual,
                playerDeathIndex = player and firstDeath[player.id], opponentDeathIndex = firstDeath[opponent.id],
                playerRevived = player and life[player.id] and life[player.id].kind == "revive",
                opponentRevived = life[opponent.id] and life[opponent.id].kind == "revive",
                honorableKills = reward and reward.honorableKills or 0, honor = reward and reward.honor or 0,
                wins = outcome == "win" and 1 or 0, losses = outcome == "loss" and 1 or 0,
                personalKills = kills[opponent.id] or 0, personalDeaths = deaths[opponent.id] or 0,
                contributionWins = tally and tally.win or 0, contributionLosses = tally and tally.loss or 0,
                legacyWins = legacy and outcome == "win" and 1 or 0, legacyLosses = legacy and outcome == "loss" and 1 or 0,
                legacyResult = legacy and outcome or nil,
            }
        end
    end
    return { summaries = summaries, projection = projection }
end

-- Keep numeric snapshots by battle ID so an in-place evidence edit can
-- subtract the previous projection before adding the replacement.
local function ApplySummaries(index, battleID, record, sign)
    for id, summary in pairs(record.summaries) do
        local rival = index.rivals[id]
        if not rival then rival = { encounters = {} }; index.rivals[id] = rival end
        for _, field in ipairs(indexedStats) do
            rival[field] = (rival[field] or 0) + sign * summary[field]
        end
        rival.encounters[battleID] = sign == 1 and summary or nil
        if not next(rival.encounters) then index.rivals[id] = nil end
    end
end

UpdateIndex = function(index, id, battle)
    local previous = index.battles[id]
    if previous then ApplySummaries(index, id, previous, -1) end
    local record = IsSkirmish(battle) and SummarizeSkirmish(id, battle) or nil
    index.battles[id] = record
    if record then ApplySummaries(index, id, record, 1) end
end

local function RivalSkirmishIndex(db, id)
    local index = skirmishIndexes[db]
    if not index then
        index = { battles = {}, rivals = {} }
        for battleID, battle in pairs(db.skirmishes or {}) do UpdateIndex(index, battleID, battle) end
        skirmishIndexes[db] = index
    end
    return index.rivals[id]
end

function Ledger.SkirmishContributionEvidence(db, id, battle)
    local index = skirmishIndexes[db]
    local record = index and index.battles[id]
    if record then return record.projection end
    if IsSkirmish(battle) then return ContributionEvidence(battle) end
end

function Ledger.PersonalScore(db, id)
    local old = LegacyStats(db, id)
    local battles = RivalSkirmishIndex(db, id)
    return (battles and battles.wins or 0) + old.manualWins + old.legacyWins,
        (battles and battles.losses or 0) + old.manualLosses + old.legacyLosses,
        battles and battles.honorableKills or 0, battles and battles.honor or 0
end

function Ledger.RivalSkirmishes(db, id)
    local battles = RivalSkirmishIndex(db, id)
    local entries = {}
    for _, encounter in pairs(battles and battles.encounters or {}) do entries[#entries + 1] = encounter end
    return entries
end

function Ledger.PersonalCombatScore(db, id)
    local old, battles = LegacyStats(db, id), RivalSkirmishIndex(db, id)
    return old.kills + (battles and battles.personalKills or 0), old.deaths + (battles and battles.personalDeaths or 0)
end

function Ledger.RivalContributionScore(db, id)
    local old, battles = LegacyStats(db, id), RivalSkirmishIndex(db, id)
    return old.wins + (battles and battles.contributionWins or 0), old.losses + (battles and battles.contributionLosses or 0)
end

function Ledger.RivalRewards(db, id)
    local old, battles = LegacyStats(db, id), RivalSkirmishIndex(db, id)
    return old.honorableKills + (battles and battles.honorableKills or 0), old.honor + (battles and battles.honor or 0)
end

function Ledger.RivalHistoryContext(db, id)
    local old, battles = LegacyStats(db, id), RivalSkirmishIndex(db, id)
    return old.manualWins, old.manualLosses, old.legacyWins + (battles and battles.legacyWins or 0),
        old.legacyLosses + (battles and battles.legacyLosses or 0)
end
