local _, addon = ...
local Ledger = addon.Ledger
local DeathEvidence = addon.SkirmishDeathEvidence
local episodeAge, lateEvent = DeathEvidence.timedActionAge, DeathEvidence.lateWindowGrace
local Number, Opponents = DeathEvidence.IsNumber, DeathEvidence.Opponents
local meterSupport = { HealingDone = true, Absorbs = true, Dispels = true }

-- Recap timestamps remain in native server seconds, attached to one lethal
-- event. They cannot be converted to exact offsets on the local action clock.
local function RecapInEpisode(battle, episode, time)
    local kill, after = episode.recap or episode.kill or episode.event, episode.after
    if not kill or not Number(kill.recapTimestamp) or not Number(time) or not Number(battle.startedAt)
        or time < battle.startedAt or time > kill.recapTimestamp or kill.recapTimestamp - time > episodeAge then return end
    -- A coarse clock cannot decide whether an earlier row and a revival in
    -- the same second belong to the same life.
    return not after or (Number(after.time) and math.floor(time) > math.floor(after.time))
end

function addon.RestoreRivalContributionEvidence(battle)
    local journal = battle.combatDiagnostics
    if type(journal) ~= "table" or journal.version ~= 1 or type(journal.recaps) ~= "table" then return end
    local deaths = {}
    for _, event in ipairs(battle.events) do
        if event.kind == "kill" and event.source == "death-recap" and Number(event.recapTimestamp) then
            local key = event.recapTimestamp
            deaths[key] = deaths[key] == nil and event or false
        end
    end
    local restored = {}
    for _, row in ipairs(journal.recaps) do
        local death = type(row) == "table" and deaths[row.recapTime]
        if death and not death.recapDamage and row.targetID == death.targetID and type(row.actorID) == "string"
            and Number(row.recapIndex) and row.recapIndex > 1 and Ledger.IsDeathRecapDamage(row.effect)
            and Number(row.amount) and row.amount > 0 and Number(row.eventTime) and row.eventTime <= death.recapTimestamp then
            local hits = restored[death] or {}
            hits[row.actorID] = math.max(hits[row.actorID] or row.eventTime, row.eventTime)
            restored[death] = hits
        end
    end
    for death, hits in pairs(restored) do death.recapDamage = hits end
end

local function CollectActions(segments, sides, me)
    for _, phase in ipairs(segments) do
        local start = phase.start
        phase.actions = {}
        if start then
            for _, action in ipairs(phase.evidence.actions or {}) do
                if action.kind == "harmful-aura" and Opponents(sides, action.actorID, action.targetID)
                    and action.petEndpoint ~= "target" and (action.targetID ~= me or action.targetIsPlayer == true) then
                    local function Add(offset)
                        if Number(offset) then
                            phase.actions[#phase.actions + 1] = {
                                actorID = action.actorID, targetID = action.targetID, offset = start + offset,
                                kind = action.kind, petEndpoint = action.petEndpoint, segmentIndex = phase.index,
                            }
                        end
                    end
                    if action.first ~= action.last then Add(action.first) end
                    for _, offset in ipairs(action.intermediateOffsets or {}) do Add(offset) end
                    Add(action.last)
                end
            end
        end
    end
end

local function TimedInEpisode(phase, episode, offset, deathAt)
    if not Number(deathAt) then return end
    local after = episode.after
    -- Legacy server-second segment starts have a one-second uncertainty.
    local uncertainty = Number(phase.evidence.offset) and 0 or 1
    return offset + uncertainty <= deathAt and deathAt - offset + uncertainty <= episodeAge
        and (not after or (Number(after.offset) and offset - uncertainty > after.offset))
end

local function Put(map, actor, evidence)
    if not map[actor] then map[actor] = evidence end
end

local function AddWindowEvidence(battle, analysis, phase, episode, deathAt, direct)
    local sides, targetID = analysis.sides, episode.targetID
    local qualifying, opponent = {}, {}
    local function Note(a, b)
        if not Opponents(sides, a, b) then return end
        if opponent[a] == nil then opponent[a] = b
        elseif opponent[a] ~= b then opponent[a] = false end
        if opponent[b] == nil then opponent[b] = a
        elseif opponent[b] ~= a then opponent[b] = false end
    end
    for _, link in ipairs(phase.evidence.meter and phase.evidence.meter.hostileLinks or {}) do
        Note(link.allyID, link.opponentID)
    end
    for _, action in ipairs(phase.actions) do
        Note(action.actorID, action.targetID)
        if action.targetID == targetID and TimedInEpisode(phase, episode, action.offset, deathAt) then
            Put(qualifying, action.actorID, action)
        end
    end
    for index, event in ipairs(battle.events) do
        if event.kind == "kill" and Number(event.offset) and event.offset >= phase.start
            and (event.segmentIndex == phase.index or event.offset <= phase.finish + lateEvent) then
            Note(event.actorID, event.targetID)
            if event == episode.kill then
                qualifying[event.actorID] = { kind = "finishing-blow", eventIndex = index }
            end
        end
    end
    for _, link in ipairs(phase.links) do
        if DeathEvidence.IsHostileMeterLink(link) then Note(link.actorID, link.targetID) end
    end
    for actor, link in pairs(episode.meterAttacks) do
        local proof = { kind = "meter", category = link.category, segmentIndex = phase.index, petEndpoint = link.petEndpoint }
        Put(qualifying, actor, proof)
        Put(direct, actor, proof)
    end
    local recap = episode.recap or episode.kill or episode.event
    if recap then
        local owner = recap.petFinisher and recap.petFinisher.ownerID
        if Opponents(sides, owner, targetID) then
            Note(owner, targetID)
            Put(qualifying, owner, direct[owner])
        end
        for actor, time in pairs(recap.recapDamage or {}) do
            if Opponents(sides, actor, targetID) and RecapInEpisode(battle, episode, time)
                and Number(phase.evidence.startedAt) and time >= phase.evidence.startedAt then
                Note(actor, targetID)
                Put(qualifying, actor, { kind = "recap-damage", eventTime = time, eventIndex = episode.killIndex or episode.index })
            end
        end
    end

    -- A window-aggregate heal or protection has no opponent or ordering.
    -- Only a single independently linked opponent of the recipient can
    -- supply that relation. Do not propagate credit through a roster graph.
    local assists = {}
    if phase.finish - deathAt > lateEvent then return assists end
    for _, link in ipairs(phase.links) do
        local actor, recipient = link.actorID, link.targetID
        if meterSupport[link.category] and not link.corroborated and link.petEndpoint ~= "target" and actor ~= recipient
            and sides[actor] and sides[actor] == sides[recipient] and qualifying[recipient] and opponent[recipient] == targetID
            and DeathEvidence.SingleLife(analysis.life, actor, phase)
            and DeathEvidence.SingleLife(analysis.life, recipient, phase) then
            Put(assists, actor, { kind = "support", category = link.category, segmentIndex = phase.index,
                petEndpoint = link.petEndpoint, viaID = recipient, viaEvidence = qualifying[recipient] })
        end
    end
    return assists
end

-- Derived on demand from the permanent ledger. Each result refers to an
-- episode's first durable death and one positive, attributable proof.
function addon.EvaluateRivalContributions(battle)
    local result = { version = 1, credits = {} }
    if battle.manual or #battle.events == 0 then return result end
    local analysis = addon.AnalyzeSkirmishLives(battle)
    local sides, me = analysis.sides, analysis.me
    if not me then return result end
    local phases = analysis.segments
    CollectActions(phases, sides, me)
    local function Credit(rival, episode, actor, direction, evidence, credited)
        if not evidence or not rival.rivalID or credited[rival.rivalID] then return end
        credited[rival.rivalID] = true
        result.credits[#result.credits + 1] = { rivalID = rival.rivalID, direction = direction, deathIndex = episode.index,
            victimID = episode.targetID, actorID = actor, evidence = evidence }
    end
    for _, episode in ipairs(analysis.episodes) do
        local victim = episode.targetID
        local personalLoss = victim == me
        local death = episode.event
        if episode.pvpDeath and (sides[victim] == "enemy" or personalLoss) then
            local direct, credited = {}, {}
            local deathAt = episode.first.offset
            if episode.kill then
                Put(direct, episode.kill.actorID, { kind = "finishing-blow", eventIndex = episode.killIndex })
            end
            local recap = episode.recap or episode.kill or death
            local owner = recap.petFinisher and recap.petFinisher.ownerID
            if Opponents(sides, owner, victim) then
                Put(direct, owner, { kind = "pet-finishing-blow", eventIndex = episode.index, petEndpoint = "actor" })
            end
            for actor, time in pairs(recap.recapDamage or {}) do
                if Opponents(sides, actor, victim) and RecapInEpisode(battle, episode, time) then
                    Put(direct, actor, { kind = "recap-damage", eventTime = time, eventIndex = episode.killIndex or episode.index })
                end
            end
            for _, phase in ipairs(phases) do
                for _, action in ipairs(phase.actions) do
                    if action.targetID == victim and TimedInEpisode(phase, episode, action.offset, deathAt) then
                        Put(direct, action.actorID, action)
                    end
                end
            end
            local window = episode.meterPhase
            local support = window and AddWindowEvidence(battle, analysis, window, episode, deathAt, direct) or {}
            if personalLoss then
                for _, rival in ipairs(battle.enemies) do
                    Credit(rival, episode, rival.id, "loss", direct[rival.id] or support[rival.id], credited)
                end
            else
                for _, rival in ipairs(battle.enemies) do
                    if rival.id == victim then Credit(rival, episode, me, "win", direct[me] or support[me], credited) end
                end
            end
        end
    end
    return result
end
