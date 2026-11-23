local _, addon = ...

local holderRadius, withdrawalRadius, pressureAge = 30, 55, 12
local checkedExit, maxProbeRange, anchorDrift = 40, 45, 5

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

local function CheckedDistance(unit)
    if type(UnitDistanceSquared) ~= "function" then return end
    local ok, squared, checked = pcall(UnitDistanceSquared, unit)
    if not ok or addon.Readable(checked) ~= true then return end
    squared = addon.Readable(squared)
    if type(squared) == "number" and squared > 0 and squared < math.huge then return squared end
end

local function SpellRange(spell)
    local info = C_Spell and ReadUnit(C_Spell.GetSpellInfo, spell)
    if type(info) ~= "table" or (canaccesstable and not canaccesstable(info)) then return end
    local upper = addon.Readable(info.maxRange)
    if addon.Readable(info.minRange) == 0 and type(upper) == "number"
        and upper >= checkedExit and upper <= maxProbeRange then return upper end
end

local function ReadRangeExit(unit, probe)
    if probe.distance then
        local squared = CheckedDistance(unit)
        if squared then return squared >= checkedExit^2 end
    elseif C_Spell and ReadUnit(UnitCanAttack, "player", unit) == true and SpellRange(probe.spell) == probe.upper then
        local inRange = ReadUnit(C_Spell.IsSpellInRange, probe.spell, unit)
        if type(inRange) == "boolean" then return not inRange end
    end
end

function addon.ReadWorldOutcomeUnits(ids, pressure)
    local units = {}
    VisitUnits(function(unit)
        local guid = ReadUnit(UnitGUID, unit)
        if type(guid) ~= "string" or not ids[guid] or units[guid] then return end
        local state = addon.ReadWorldOutcomeState(unit)
        if not state then return end
        state.position = Position(unit)
        local probe = pressure and pressure[guid] and pressure[guid].range
        if probe and state.dead == false and state.combat == false then
            state.rangeExit = ReadRangeExit(unit, probe)
        end
        units[guid] = state
    end)
    return units
end

local function RangeAtAction(unit, origin, spell)
    if not origin or type(unit) ~= "string" or ReadUnit(UnitIsVisible, unit) ~= true then return end
    local squared = CheckedDistance(unit)
    if squared and squared <= holderRadius^2 then return { distance = true, origin = origin } end
    if C_Spell and type(spell) == "number" and ReadUnit(UnitCanAttack, "player", unit) == true
        and ReadUnit(C_Spell.IsSpellHarmful, spell) == true then
        local upper = SpellRange(spell)
        if upper and ReadUnit(C_Spell.IsSpellInRange, spell, unit) == true then
            return { spell = spell, upper = upper, origin = origin }
        end
    end
end

-- Anchor the outcome to a witnessed action. A local range probe can establish
-- proximity without access to the opponent's coordinates.
function addon.NoteWorldOutcomeAction(state, actor, target, offset, kind, spell, targetUnit)
    state.lastAction = { actorID = actor, targetID = target, offset = offset, kind = kind }
    state.offense = state.offense or {}
    state.offense[actor] = offset
    local units = addon.ReadWorldOutcomeUnits({ [actor] = true, [target] = true })
    local from, to = units[actor] and units[actor].position, units[target] and units[target].position
    local range
    if actor == ReadUnit(UnitGUID, "player") and targetUnit and ReadUnit(UnitGUID, targetUnit) == target then
        range = RangeAtAction(targetUnit, from, spell)
    end
    local distance = Distance(from, to)
    if not state.site then
        if distance and distance <= 2 * holderRadius then
            state.site = { x = (from.x + to.x) / 2, y = (from.y + to.y) / 2, map = from.map }
        elseif range then
            state.site = from
        end
    end
    local fromSite, toSite = Distance(state.site, from), Distance(state.site, to)
    if fromSite and fromSite <= holderRadius and ((toSite and toSite <= holderRadius) or range) then
        state.pressure = state.pressure or {}
        state.pressure[target] = { actorID = actor, offset = offset, range = range }
    end
end

local function ConfirmedDeaths(battle, first, last)
    local dead = {}
    for _, event in ipairs(battle.events) do
        local id, at = event.targetID, event.time
        if id and (type(at) ~= "number" or type(last.at) ~= "number" or at <= last.at) then
            if event.kind == "kill" then dead[id] = event
            elseif event.kind == "revive" then dead[id] = nil end
        end
    end
    for _, sample in ipairs({ first, last }) do
        for id, unit in pairs(sample.units) do
            local death = dead[id]
            if unit.dead == false and death and type(sample.at) == "number" and type(death.time) == "number"
                and sample.at > death.time then dead[id] = nil end
        end
    end
    return dead
end

local function ObservedRangeExit(state, id, first, last)
    local pressure = state.pressure and state.pressure[id]
    local probe = pressure and pressure.range
    if not probe or not first or first.rangeExit ~= true or first.dead ~= false or first.combat ~= false
        or (last and (last.rangeExit ~= true or last.dead ~= false or last.combat ~= false)) then return end
    for _, sample in ipairs({ state.first, state.last }) do
        local holder = sample.units[pressure.actorID]
        local departing = sample.units[id]
        local position = departing and departing.position
        if position then
            local distance = Distance(probe.origin, position)
            if not distance or distance < checkedExit - anchorDrift then return end
        end
        local drift = holder and Distance(probe.origin, holder.position)
        if not drift or drift > anchorDrift or holder.dead ~= false or holder.combat ~= false then return end
    end
    return true
end

local function Classify(side, state, dead, solo)
    local result = { dead = 0, holding = 0, away = 0, unresolved = 0, active = 0, heldBy = {}, withdrawn = {}, rangeWithdrawn = 0 }
    for _, player in ipairs(side) do
        local id = player.id
        local first, last = state.first.units[id], state.last.units[id]
        if dead[id] or (first and last and first.dead == true and last.dead == true) then
            result.dead = result.dead + 1
        elseif (first and first.combat == true) or (last and last.combat == true) then
            result.active = result.active + 1
        elseif ObservedRangeExit(state, id, first, last) then
            result.away = result.away + 1
            result.rangeWithdrawn = result.rangeWithdrawn + 1
            result.withdrawn[#result.withdrawn + 1] = id
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
    return other.rangeWithdrawn > 0 and "pressured-range-withdrawal" or "pressured-withdrawal"
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
    local dead = ConfirmedDeaths(battle, state.first, state.last)
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
