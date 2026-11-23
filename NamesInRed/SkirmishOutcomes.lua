local _, addon = ...

local holderRadius, withdrawalRadius, pressureAge = 30, 55, 12

local function Distance(a, b)
    if a and b and a.map == b.map then
        return math.sqrt((a.x - b.x)^2 + (a.y - b.y)^2)
    end
end

local function ReadUnit(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, ...)
    if ok then return addon.Readable(value) end
end

local function Position(unit)
    if type(UnitPosition) ~= "function" then return end
    local ok, x, y, _, map = pcall(UnitPosition, unit)
    if not ok then return end
    x, y, map = addon.Readable(x), addon.Readable(y), addon.Readable(map)
    if type(x) == "number" and type(y) == "number" and (x ~= 0 or y ~= 0)
        and math.abs(x) < math.huge and math.abs(y) < math.huge and type(map) == "number" then
        return { x = x, y = y, map = map }
    end
end

local function VisitUnits(visit)
    visit("player")
    visit("target")
    visit("mouseover")
    local raid = ReadUnit(IsInRaid) == true
    local count = ReadUnit(raid and GetNumGroupMembers or GetNumSubgroupMembers)
    if type(count) == "number" then
        local prefix = raid and "raid" or "party"
        for i = 1, count do visit(prefix .. i) end
    end
    addon.VisitVisibleNameplateUnits(visit)
end

function addon.ReadWorldOutcomeState(unit)
    if unit ~= "player" and ReadUnit(UnitIsVisible, unit) ~= true then return end
    local dead = ReadUnit(UnitIsDeadOrGhost, unit)
    if dead == true and ReadUnit(UnitIsFeignDeath, unit) ~= false then dead = nil end
    return { dead = dead, combat = ReadUnit(UnitAffectingCombat, unit) }
end

function addon.ReadWorldOutcomeUnits(ids)
    local units = {}
    VisitUnits(function(unit)
        local guid = ReadUnit(UnitGUID, unit)
        if type(guid) ~= "string" or not ids[guid] or units[guid] then return end
        local state = addon.ReadWorldOutcomeState(unit)
        if not state then return end
        state.position = Position(unit)
        units[guid] = state
    end)
    return units
end

-- Position is meaningful only for an identified pair during a witnessed action.
function addon.NoteWorldOutcomeAction(state, actor, target, offset, kind)
    state.lastAction = { actorID = actor, targetID = target, offset = offset, kind = kind }
    state.offense = state.offense or {}
    state.offense[actor] = offset
    local units = addon.ReadWorldOutcomeUnits({ [actor] = true, [target] = true })
    local from, to = units[actor] and units[actor].position, units[target] and units[target].position
    local distance = Distance(from, to)
    if not state.site and distance and distance <= 2 * holderRadius then
        state.site = { x = (from.x + to.x) / 2, y = (from.y + to.y) / 2, map = from.map }
    end
    local fromSite, toSite = Distance(state.site, from), Distance(state.site, to)
    if fromSite and fromSite <= holderRadius and toSite and toSite <= holderRadius then
        state.pressure = state.pressure or {}
        state.pressure[target] = { actorID = actor, offset = offset }
    end
end

local function ConfirmedDeaths(battle, last)
    local dead = {}
    for _, event in ipairs(battle.events) do
        if event.kind == "kill" and event.targetID and type(event.time) == "number" and type(last.at) == "number"
            and event.time <= last.at and last.at - event.time <= pressureAge then
            dead[event.targetID] = true
        elseif event.kind == "revive" and event.targetID then dead[event.targetID] = nil end
    end
    -- An alive state sampled after the last known action supersedes a kill.
    for id, unit in pairs(last.units) do
        if unit.dead == false then dead[id] = nil end
    end
    return dead
end

local function Classify(side, state, dead, solo)
    local result = { dead = 0, holding = 0, away = 0, unresolved = 0, active = 0, heldBy = {}, withdrawn = {} }
    for _, player in ipairs(side) do
        local id = player.id
        local first, last = state.first.units[id], state.last.units[id]
        if dead[id] or (first and last and first.dead == true and last.dead == true) then
            result.dead = result.dead + 1
        elseif (first and first.combat == true) or (last and last.combat == true) then
            result.active = result.active + 1
        elseif first and last and first.dead == false and last.dead == false
            and first.combat == false and last.combat == false then
            local near, finish = Distance(state.site, first.position), Distance(state.site, last.position)
            if (near and near <= holderRadius and finish and finish <= holderRadius) or (solo and not state.site) then
                result.holding = result.holding + 1
                result.heldBy[id] = true
            elseif near and near >= withdrawalRadius and finish and finish >= withdrawalRadius
                and finish >= near - holderRadius / 3 then
                result.away = result.away + 1
                result.withdrawn[#result.withdrawn + 1] = id
            else
                result.unresolved = result.unresolved + 1
            end
        else
            result.unresolved = result.unresolved + 1
        end
    end
    return result
end

local function Favors(holders, other, size, state)
    if holders.holding == 0 or holders.active + other.active > 0 or other.dead + other.away ~= size then return end
    if other.dead == size then return "defeated-side-observed" end
    -- Each living departure has to follow a witnessed action from a player
    -- still holding the site. Untimed Damage Meter totals cannot supply this.
    for _, id in ipairs(other.withdrawn) do
        local pressure = state.pressure and state.pressure[id]
        local reply = state.offense and state.offense[id]
        if not pressure or not holders.heldBy[pressure.actorID] or state.last.offset - pressure.offset > pressureAge
            or (reply and reply > pressure.offset) then return end
    end
    return "pressured-withdrawal"
end

function addon.EvaluateWorldSkirmish(battle)
    local observation = battle.observation
    local state = observation and observation.assessment
    local result = { ending = "unknown", reason = "missing-terminal-observations" }
    if not state then return result end
    result.meter = state.meterStatus
    result.localLife = observation.playerState
    if state.checkStatus == "watching" then
        result.ending, result.reason = "ongoing", "recent-hostility-or-open-window"
    end
    if state.interrupted then
        result.ending, result.reason = "unknown", state.interrupted
        return result
    end
    if not state.first or not state.last or #battle.allies == 0 or #battle.enemies == 0 then
        result.coverage = "no-terminal-samples"
        return result
    end
    local recent = math.max(state.lastAction and state.lastAction.offset or 0, state.lastMeterActivity or 0)
    if state.first.offset < recent or state.last.offset <= state.first.offset then
        result.ending, result.reason = "ongoing", "later-hostility"
        return result
    end
    local dead = ConfirmedDeaths(battle, state.last)
    local solo = #battle.allies == 1 and #battle.enemies == 1
    local allies = Classify(battle.allies, state, dead, solo)
    local enemies = Classify(battle.enemies, state, dead, solo)
    result.allies, result.enemies = allies, enemies
    local observed, noPosition, noState = 0, 0, 0
    for _, unit in pairs(state.last.units) do
        observed = observed + 1
        if not unit.position then noPosition = noPosition + 1 end
        if unit.dead == nil or unit.combat == nil then noState = noState + 1 end
    end
    result.unitsRead, result.positionsUnavailable, result.statesUnavailable = observed, noPosition, noState
    if allies.unresolved + enemies.unresolved > 0 then
        result.coverage = observed > 0 and "partial" or "unavailable"
    else
        result.coverage = "classified-observed-roster"
    end
    local wins = Favors(allies, enemies, #battle.enemies, state)
    local losses = Favors(enemies, allies, #battle.allies, state)
    result.favorsVictory, result.favorsDefeat = wins, losses
    if wins or losses then
        result.ending, result.reason, result.outcome = "observed", wins or losses, wins and "win" or "loss"
    elseif allies.active + enemies.active > 0 then
        result.reason = "participants-still-in-combat"
    elseif allies.unresolved + enemies.unresolved > 0 then
        result.reason = "participant-state-or-position-unavailable"
    elseif allies.away > 0 and enemies.away > 0 and allies.holding + enemies.holding == 0 then
        result.ending, result.reason = "observed", "both-sides-left-site"
    elseif (allies.holding > 0 and enemies.away > 0) or (enemies.holding > 0 and allies.away > 0) then
        result.reason = "withdrawal-not-corroborated"
    else
        result.reason = "no-decisive-end"
    end
    return result
end
