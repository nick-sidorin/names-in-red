local _, addon = ...
local DeathEvidence = { timedActionAge = 12, lateWindowGrace = 2.5 }
addon.SkirmishDeathEvidence = DeathEvidence

local meterHostile = { DamageDone = true, DamageTaken = true, EnemyDamageTaken = true, Interrupts = true, Dispels = true }
local meterDamage = { DamageDone = true, DamageTaken = true, EnemyDamageTaken = true }
local lateEvent = DeathEvidence.lateWindowGrace

function DeathEvidence.IsNumber(value)
    return type(value) == "number" and value > -math.huge and value < math.huge
end

function DeathEvidence.Opponents(sides, a, b)
    return sides[a] and sides[b] and sides[a] ~= sides[b]
end

function DeathEvidence.IsHostileMeterLink(link)
    return meterHostile[link.category] and link.petEndpoint ~= "target"
end

function DeathEvidence.IsCreatureSource(id)
    return type(id) == "string" and id:match("^Creature%-.+") ~= nil
end

local Number = DeathEvidence.IsNumber

local function SegmentStart(battle, segment)
    if Number(segment.offset) then return segment.offset end
    if Number(segment.startedAt) and Number(battle.startedAt) then return segment.startedAt - battle.startedAt end
end

local function MeterLinks(segment)
    if segment.contributionLinks then return segment.contributionLinks end
    -- Older accepted samples carry amounts and a separate qualification
    -- summary. Use exact category scope only when both survived.
    local report, meter = segment.reportMeter, segment.meter
    local accepted = {}
    if not report or not meter or not meter.selection or report.status ~= "sampled" or report.areaChanged or report.meterReset
        or report.meterSelection ~= meter.selection or report.meterSessionID ~= meter.sessionID then return accepted end
    for _, link in ipairs(segment.combatAggregates or {}) do
        local category = report.categories and report.categories[link.category]
        if category and category.evidence == "eligible" and Number(link.amount) and link.amount > 0 then
            accepted[#accepted + 1] = link
        end
    end
    return accepted
end

function DeathEvidence.Segments(battle)
    local segments = {}
    for index, segment in ipairs(battle.observation and battle.observation.segments or {}) do
        local start = SegmentStart(battle, segment)
        local phase = { index = index, start = start, evidence = segment, links = MeterLinks(segment) }
        if Number(segment.offset) and Number(segment.duration) and segment.duration >= 0 then
            phase.finish = start + segment.duration
        end
        segments[index] = phase
    end
    return segments
end

local function DeathWindow(segments, episode, deathAt)
    if not Number(deathAt) then return nil, "no-death-offset" end
    local function Fits(phase)
        return phase.finish and phase.start <= deathAt
            and deathAt - phase.finish <= lateEvent
    end
    local index = (episode.kill or episode.event).segmentIndex
    if index then
        local phase = segments[index]
        if phase and Fits(phase) then return phase end
        return nil, "bound-window-mismatch"
    end
    local matched
    for _, phase in ipairs(segments) do
        if Fits(phase) then
            if matched then return nil, "ambiguous-death-window" end
            matched = phase
        end
    end
    if matched then return matched end
    return nil, "no-death-window"
end

function DeathEvidence.SingleLife(life, id, phase, victimEpisode)
    local state = life[id]
    if not state then return true end
    for _, episode in ipairs(state.episodes or {}) do
        local died, revived = episode.first.offset, episode.revival and episode.revival.offset
        if not Number(died) or (episode.revival and not Number(revived)) then return false end
        if episode == victimEpisode then
            if revived and revived <= phase.finish then return false end
            if episode.after and (not Number(episode.after.offset) or episode.after.offset >= phase.start) then return false end
        elseif died <= phase.finish and (not revived or revived >= phase.start) then
            return false
        end
    end
    return true
end

-- A positive directed link is usable only on a unique death window and
-- one life of each endpoint. The returned proof remains an aggregate.
function DeathEvidence.MeterForEpisode(segments, sides, life, episode)
    local phase, reason = DeathWindow(segments, episode, episode.first.offset)
    if not phase then return nil, nil, reason end
    if not DeathEvidence.SingleLife(life, episode.targetID, phase, episode) then
        return nil, nil, "multiple-target-lives-in-window", phase.index
    end
    local attacks = {}
    for _, link in ipairs(phase.links) do
        local actor = link.actorID
        if link.targetID == episode.targetID and not link.corroborated
            and DeathEvidence.IsHostileMeterLink(link) and DeathEvidence.Opponents(sides, actor, link.targetID)
            and (not attacks[actor] or (meterDamage[link.category] and not meterDamage[attacks[actor].category]))
            and DeathEvidence.SingleLife(life, actor, phase) then
            attacks[actor] = link
        end
    end
    return phase, attacks
end

-- A local death needs more than an aggregate in the same fight. Require
-- the end of that local window and a corroborating read of the same life.
function DeathEvidence.ConfirmLocalMeterDeath(observation, episode)
    local event, phase = episode.event, episode.meterPhase
    if not phase then return nil, episode.meterRejection end
    if phase.evidence.endReason ~= "local-combat-ended" or not Number(event.offset)
        or math.abs(phase.finish - event.offset) > lateEvent then return nil, "away-from-combat-end" end
    local signaled = event.source == "player-dead"
    for _, row in ipairs(observation.life or {}) do
        if row.state == "dead" and row.source == "player-dead" and Number(row.offset)
            and math.abs(row.offset - event.offset) <= 0.5
            and (not episode.after or (Number(episode.after.offset) and row.offset > episode.after.offset)) then
            signaled = true
        end
    end
    if not signaled then return nil, "no-local-death-signal" end
    local segment = phase.evidence
    local incoming = segment.reportMeter and segment.reportMeter.categories
    incoming = incoming and incoming.DamageTaken
    if segment.localNpcPressure or segment.localNpcDamage == true or (segment.localNpcDamage == nil and incoming and incoming.counts
        and (incoming.counts["target-not-player"] or 0) > 0) then return nil, "mixed-incoming-damage" end
    local damage = {}
    for actor, link in pairs(episode.meterAttacks) do
        if meterDamage[link.category] and type(actor) == "string" and actor:match("^Player%-.+") then damage[actor] = true end
    end
    if not next(damage) then return nil, "no-qualified-incoming-damage" end
    local function InLife(offset)
        return Number(offset) and offset >= event.offset and offset - event.offset <= lateEvent
            and (not episode.revival or (Number(episode.revival.offset) and offset < episode.revival.offset))
    end
    for actor, offset in pairs(segment.localDeathWitnesses or {}) do
        if damage[actor] and InLife(offset) then return event, "terminal-incoming-damage" end
    end
    for _, source in ipairs({ observation.participation or {}, observation.assessment or {} }) do
        for _, key in ipairs({ "first", "last", "lateFirst", "lateLast" }) do
            local sample = source[key]
            local units = sample and sample.units
            local localUnit = units and units[episode.targetID]
            if localUnit and localUnit.dead == true and InLife(sample.offset) then
                for actor in pairs(damage) do
                    local rival = units[actor]
                    if rival and rival.dead == false and rival.combat == true then
                        return event, "terminal-incoming-damage"
                    end
                end
            end
        end
    end
    return nil, "no-corroborating-terminal-read"
end
