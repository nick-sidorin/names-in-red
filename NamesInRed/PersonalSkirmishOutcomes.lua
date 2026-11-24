local _, addon = ...
local Ledger = addon.Ledger
local version = 1
-- Scope a witnessed action on the victim to the same life episode.
local deathLinkAge = 12

local function LastSegment(observation)
    local segments = observation.segments
    return segments and segments[#segments]
end

local function Hostility(battle, observation, sides, me)
    local last, lastLocalAction, targets = nil, nil, {}
    local function Add(actor, target, offset)
        if sides[actor] and sides[target] and sides[actor] ~= sides[target] and type(offset) == "number" then
            last = math.max(last or offset, offset)
            local offsets = targets[target] or {}
            offsets[#offsets + 1] = offset
            targets[target] = offsets
        end
    end
    for _, segment in ipairs(observation.segments or {}) do
        local start = segment.offset
        if not start and type(segment.startedAt) == "number" and type(battle.startedAt) == "number" then
            start = segment.startedAt - battle.startedAt
        end
        for _, action in ipairs(segment.actions or {}) do
            if start and type(action.last) == "number" then
                local offset = start + action.last
                Add(action.actorID, action.targetID, offset)
                if action.actorID == me then lastLocalAction = math.max(lastLocalAction or offset, offset) end
            end
        end
    end
    local action = observation.assessment and observation.assessment.lastAction
    if action then Add(action.actorID, action.targetID, action.offset) end
    for _, event in ipairs(battle.events) do
        if event.kind == "kill" then Add(event.actorID, event.targetID, event.offset) end
    end
    return last, targets, lastLocalAction
end

local function OpposedKill(event, sides)
    return event.kind == "kill" and sides[event.actorID] and sides[event.targetID] ~= sides[event.actorID]
end

local function LinkedCorpse(event, attacks, prior)
    if event.pvpLinked ~= nil then return event.pvpLinked == true end
    if type(event.offset) ~= "number" then return end
    for _, offset in ipairs(attacks or {}) do
        if offset <= event.offset and event.offset - offset <= deathLinkAge
            and (not prior or type(prior.offset) ~= "number" or offset > prior.offset) then return true end
    end
end

local function Casualties(battle, sides, me, attacks, first, last, lateFirst, lateLast)
    local timeline, life = {}, {}
    local counts = { friendly = 0, enemy = 0 }
    for _, event in ipairs(battle.events) do
        if sides[event.targetID] and (Ledger.IndicatesDeath(event) or event.kind == "revive") then
            timeline[#timeline + 1] = event
        end
    end
    -- Samples refine the latest life state. They do not attribute a death
    -- to PvP or rewrite earlier timeline rows.
    local function AddSample(sample)
        for id, unit in pairs(sample and sample.units or {}) do
            if sides[id] and type(unit.dead) == "boolean" then
                local event = { targetID = id, kind = unit.dead and "death" or "revive",
                    offset = sample.offset, time = sample.at, pvpLinked = false }
                local index = #timeline + 1
                while index > 1 and Ledger.LaterBattleEvent(timeline[index - 1], event) do index = index - 1 end
                table.insert(timeline, index, event)
            end
        end
    end
    AddSample(first)
    AddSample(last)
    AddSample(lateFirst)
    AddSample(lateLast)
    for _, event in ipairs(timeline) do
        local id = event.targetID
        local state = life[id] or {}
        life[id] = state
        if event.kind == "revive" then
            if state.dead then
                state.revival = event
                state.priorDeath = state.death or state.priorDeath
            end
            state.dead, state.linked, state.recap, state.death = false, nil, nil, nil
        else
            if event.source == "death-recap" and type(event.recapTimestamp) == "number"
                and state.recap and event.recapTimestamp > state.recap then
                -- Distinct validated server recaps imply a new local life.
                state.linked = nil
            end
            local linked = OpposedKill(event, sides)
                or (event.kind == "death" and id ~= me and LinkedCorpse(event, attacks[id], state.revival))
            if linked and not state.linked then
                counts[sides[id]] = counts[sides[id]] + 1
                state.linked, state.death = true, event
            end
            state.dead = true
            if event.source == "death-recap" then state.recap = event.recapTimestamp or state.recap end
        end
    end
    return counts, life
end

local function TerminalEvidence(battle, segment, first, last, lastAction, life, unreturned)
    if not first or not last or type(first.offset) ~= "number" or type(last.offset) ~= "number"
        or last.offset <= first.offset or (lastAction and first.offset < lastAction) then return end
    local summary, visibleOpposition = {}, false
    for key, side in pairs({ friendly = battle.allies, enemy = battle.enemies }) do
        local eliminated, survivor = #side > 0, false
        for _, player in ipairs(side) do
            local id = player.id
            local a, b = (first.units or {})[id], (last.units or {})[id]
            local dead = life[id] and life[id].linked
            if key == "enemy" and ((a and a.dead == false and a.combat == false)
                or (b and b.dead == false and b.combat == false)) then visibleOpposition = true end
            if not dead then
                eliminated = false
                if (a and a.dead ~= true and a.combat == true) or (b and b.dead ~= true and b.combat == true) then
                    return nil, nil, true
                end
                local contact = segment and segment.contacts and segment.contacts[id]
                if not a and not b and contact and contact.signal == "nameplate-removed" and contact.inCombat == true then
                    return
                end
                if id ~= unreturned and a and b and a.dead == false and b.dead == false
                    and a.combat == false and b.combat == false then
                    survivor = true
                end
            end
        end
        summary[key] = { eliminated = eliminated, survivor = survivor }
    end
    local friendly, enemy = summary.friendly, summary.enemy
    if friendly.eliminated and enemy.eliminated then return "draw", "mutual-elimination" end
    if enemy.eliminated and friendly.survivor then return "win", "enemy-elimination" end
    if friendly.eliminated and enemy.survivor then return "loss", "friendly-elimination" end
    if (friendly.survivor or enemy.survivor) and (not unreturned or visibleOpposition) then
        return nil, "observed-disengagement"
    end
end

-- Operates on saved records and plain evidence. No client state or clock reads.
function addon.EvaluatePersonalSkirmish(battle)
    local observation = battle.observation
    local participation = observation and observation.participation
    if participation and participation.state ~= "finalized" then
        return { version = version, lifecycle = participation.state }
    end
    local sides, me = {}, nil
    for key, side in pairs({ friendly = battle.allies, enemy = battle.enemies }) do
        for _, player in ipairs(side) do
            if player.id then sides[player.id] = key end
            if key == "friendly" and player.isSelf then me = player.id end
        end
    end
    local assessment = observation and observation.assessment or {}
    local segment = observation and LastSegment(observation)
    local first, last, lateFirst, lateLast
    if participation then
        first, last = participation.first, participation.last
        lateFirst, lateLast = participation.lateFirst, participation.lateLast
    else
        first, last = assessment.first, assessment.last
    end
    local boundary = participation and participation.boundary or assessment.interrupted
        or (segment and segment.observationStopped)
    local lastAction, attacks, historicalReturn = Hostility(battle, observation or {}, sides, me)
    if participation and participation.lifeChangedAt then
        lastAction = math.max(lastAction or 0, participation.lifeChangedAt)
    end
    local counts, life = Casualties(battle, sides, me, attacks, first, last, lateFirst, lateLast)
    local result = { version = version, lifecycle = "finalized",
        finalizedBy = participation and participation.boundary or "historical",
        coverage = "insufficient", outcome = "unknown", reason = "insufficient-ending-evidence",
        casualties = counts, life = {} }
    for id, state in pairs(life) do
        result.life[id] = state.dead and (state.linked and "pvp-dead" or "dead") or "alive"
    end
    result.boundary = boundary
    if not me or #battle.enemies == 0 then return result end
    local localLife = life[me]
    -- A resurrection by itself is not a return to the confrontation.
    local personalDeath = localLife and (localLife.death or localLife.priorDeath)
    local returned = participation and participation.returnedAt
    if not participation and localLife and localLife.revival and historicalReturn
        and type(localLife.revival.offset) == "number" and historicalReturn > localLife.revival.offset then
        returned = historicalReturn
    end
    if personalDeath and returned and type(personalDeath.offset) == "number" and returned > personalDeath.offset then
        personalDeath = nil
    end
    local unreturned = personalDeath and me
    local outcome, ending, active = TerminalEvidence(battle, segment, lateFirst, lateLast, lastAction, life, unreturned)
    if not ending and not active then
        -- Later loss of visibility does not erase an already observed ending.
        outcome, ending = TerminalEvidence(battle, segment, first, last, lastAction, life, unreturned)
    end
    if not outcome and personalDeath and battle.rosterComplete == true and #battle.allies == 1 and #battle.enemies == 1 then
        local rival = battle.enemies[1].id
        local sample = lateLast and lateLast.units and lateLast.units[rival] and lateLast or last
        local survivor = sample and sample.units and sample.units[rival]
        if personalDeath.actorID == rival and survivor and survivor.dead == false
            and Ledger.LaterBattleEvent({ time = sample.at, offset = sample.offset }, personalDeath) then
            outcome, ending = "loss", "friendly-elimination"
        end
    end
    if ending then
        result.coverage, result.reason = "observed-ending", ending
        if boundary == "quiet-timeout" then result.boundary = "observed-ending" end
        if not outcome then
            outcome = counts.friendly < counts.enemy and "win" or (counts.friendly > counts.enemy and "loss" or "draw")
        end
        result.outcome = outcome
    elseif personalDeath then
        result.coverage, result.reason, result.outcome = "partial", "terminal-personal-death", "loss"
    end
    if result.boundary == "quiet-timeout" then result.boundary = "observation-expired" end
    return result
end

function addon.RefreshPersonalSkirmish(battle, loading)
    local observation = battle.observation
    if battle.manual or battle.outcome or not observation or not observation.assessment then return end
    local participation = observation.participation
    if loading and participation and participation.state ~= "finalized" then
        participation.state, participation.boundary = "finalized", "reload"
    elseif loading and battle.personalOutcome and type(battle.personalOutcome.version) == "number"
        and battle.personalOutcome.version >= version then
        return
    end
    if participation or loading then battle.personalOutcome = addon.EvaluatePersonalSkirmish(battle) end
end
