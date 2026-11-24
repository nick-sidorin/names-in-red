local _, addon = ...
local DeathEvidence = { timedActionAge = 12, lateWindowGrace = 2.5 }
addon.SkirmishDeathEvidence = DeathEvidence

local meterHostile = { DamageDone = true, DamageTaken = true, EnemyDamageTaken = true, Interrupts = true, Dispels = true }
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
    if not report or not meter or report.status ~= "sampled" or report.areaChanged or report.meterReset
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
    if not Number(deathAt) then return end
    local function Fits(phase)
        return phase.finish and phase.start <= deathAt
            and deathAt - phase.finish <= lateEvent
    end
    local index = (episode.kill or episode.event).segmentIndex
    if index then
        local phase = segments[index]
        if phase and Fits(phase) then return phase end
        return
    end
    local matched
    for _, phase in ipairs(segments) do
        if Fits(phase) then
            if matched then return end
            matched = phase
        end
    end
    return matched
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
    local phase = DeathWindow(segments, episode, episode.first.offset)
    if not phase or not DeathEvidence.SingleLife(life, episode.targetID, phase, episode) then return end
    local attacks = {}
    for _, link in ipairs(phase.links) do
        local actor = link.actorID
        if link.targetID == episode.targetID and not link.corroborated
            and DeathEvidence.IsHostileMeterLink(link) and DeathEvidence.Opponents(sides, actor, link.targetID)
            and not attacks[actor] and DeathEvidence.SingleLife(life, actor, phase) then
            attacks[actor] = link
        end
    end
    return phase, attacks
end
