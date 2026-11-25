local _, addon = ...
local Ledger, Number = addon.Ledger, addon.SkirmishDeathEvidence.IsNumber

local function Index(diagnostics, battles)
    if type(diagnostics) ~= "table" or diagnostics.version ~= 1 or type(diagnostics.rows) ~= "table" then return end
    local sessions = {}
    for _, row in ipairs(diagnostics.rows) do
        if type(row) == "table" and Number(row.session) and Number(row.combatSequence)
            and (row.kind == "COMBAT_START" or row.kind == "COMBAT_END" or row.kind == "RECAP") then
            local session = sessions[row.session] or {}
            sessions[row.session] = session
            local window = session[row.combatSequence] or { recaps = {} }
            session[row.combatSequence] = window
            if row.kind == "RECAP" then
                window.recaps[#window.recaps + 1] = row
            else
                window[row.kind] = window[row.kind] == nil and row or false
            end
        end
    end
    if not next(sessions) then return end
    for id, battle in pairs(battles) do
        local observation = type(battle) == "table" and battle.observation
        local segments = type(observation) == "table" and observation.segments
        for _, segment in ipairs(type(segments) == "table" and segments or {}) do
            local report = type(segment) == "table" and segment.reportMeter
            local session = report and sessions[report.session]
            local window = session and session[report.combatSequence]
            if window then
                window.owner = window.owner == nil and id or false
            end
        end
    end
    return sessions
end

local function MatchRecord(id, battle, window)
    if type(id) ~= "string" or not id:match("^world:%d+$") or not window or window.owner ~= id
        or type(battle) ~= "table" or battle.manual or battle.outcome or not Number(battle.time)
        or battle.origin ~= "world" or type(battle.captureRevision) ~= "string" or type(battle.events) ~= "table"
        or type(battle.allies) ~= "table" or #battle.allies ~= 1 or type(battle.enemies) ~= "table" or #battle.enemies ~= 1 then return end
    local observation = battle.observation
    if type(observation) ~= "table" or type(observation.segments) ~= "table" or #observation.segments ~= 1
        or type(observation.assessment) ~= "table" or type(observation.participation) ~= "table"
        or observation.participation.state ~= "finalized" then return end
    local segment = observation.segments[1]
    local me, enemy = battle.allies[1], battle.enemies[1]
    if type(me) ~= "table" or type(enemy) ~= "table" or me.isSelf ~= true or enemy.rivalID ~= enemy.id
        or type(me.id) ~= "string" or type(enemy.id) ~= "string"
        or not me.id:match("^Player%-.+") or not enemy.id:match("^Player%-.+") or me.id == enemy.id
        or type(segment) ~= "table" or segment.startReason ~= "local-combat" or segment.offset ~= 0
        or segment.endReason ~= "local-combat-ended"
        or segment.localNpcPressure or segment.localNpcDamage then return end
    local start, finish, report = window.COMBAT_START, window.COMBAT_END, segment.reportMeter
    if not start or not finish or not report or not Number(start.uptime) or not Number(finish.uptime)
        or not Number(segment.duration) or math.abs(segment.duration - (finish.uptime - start.uptime)) > 0.05
        or not start.player or start.player.guid ~= me.id or not finish.player or finish.player.guid ~= me.id
        or start.instanceType ~= "none" or finish.instanceType ~= "none" or start.zone ~= battle.zone or finish.zone ~= battle.zone
        or start.time ~= battle.startedAt or start.time ~= segment.startedAt or finish.time ~= segment.endedAt
        or report.time ~= finish.time or report.uptime ~= finish.uptime or report.status ~= "sampled"
        or finish.areaChanged or finish.meterReset or not finish.status or finish.status.meter ~= "sampled"
        or report.meterSelection ~= finish.meterSelection or report.meterSessionID ~= finish.meterSessionID
        or type(finish.contacts) ~= "table" then return end
    return { id = id, battle = battle, segment = segment, start = start, finish = finish, me = me.id, enemy = enemy.id }
end

local function Contact(row, id, field, at, reason)
    local contact = row.contacts[id]
    local unit = contact and contact[field]
    if unit and unit.guid == id and unit.isPlayer == true and unit.uptime == at and unit.reason == reason
        and unit.status and unit.status.dead == "readable" and unit.status.guid == "readable" then return unit end
end

local function MatchedRecap(window, record, event)
    local stamp = record.start.uptime + event.offset
    for _, row in ipairs(window.recaps) do
        if row.status and row.status.events == "readable" and row.instanceType == "none" and row.zone == record.battle.zone
            and Number(row.uptime) and row.uptime >= stamp - 0.05 and row.uptime - stamp <= addon.SkirmishDeathEvidence.lateWindowGrace then
            local hit = row.events and row.events[1]
            if hit and hit.status and hit.status.row == "readable" and hit.status.sourceGUID == "readable"
                and hit.status.timestamp == "readable" and hit.status.overkill == "readable" and hit.sourceGUID == record.enemy
                and hit.timestamp == event.recapTimestamp and Number(hit.overkill) and hit.overkill >= 0
                and Ledger.IsDeathRecapDamage(hit.event) then return true end
        end
    end
end

local function ProvenGap(first, second, laterWindow)
    local a, b = first.battle, second.battle
    local gap = second.start.uptime - first.finish.uptime
    local boundary = a.observation.participation
    local event = b.events[1]
    if first.me ~= second.me or first.enemy ~= second.enemy or a.captureRevision ~= b.captureRevision or a.zone ~= b.zone
        or a.mapID ~= b.mapID or not Number(a.sequence) or b.sequence ~= a.sequence + 1
        or first.segment.observationStopped or not a.personalOutcome or a.personalOutcome.outcome ~= "unknown"
        or boundary.boundary ~= "quiet-timeout" or not Number(boundary.closedAt)
        or boundary.closedAt <= b.startedAt or #a.events ~= 0 or #(a.observation.life or {}) ~= 0
        or #b.events ~= 1 or event.kind ~= "kill" or event.actorID ~= first.enemy or event.targetID ~= first.me
        or event.source ~= "death-recap" or event.segmentIndex ~= 1 or not Number(event.offset)
        or not Number(event.recapTimestamp) or event.recapTimestamp <= boundary.closedAt
        or not addon.FitsWorldCombatGap(gap, event.offset)
        or not addon.SegmentLocalHostility(first.segment, first.me, first.enemy)
        or not addon.SegmentLocalHostility(second.segment, first.me, first.enemy) then return end
    local self = Contact(first.finish, first.me, "latest", first.finish.uptime, "combat-end")
    local enemy = Contact(first.finish, first.enemy, "latest", first.finish.uptime, "combat-end")
    local entry = Contact(second.finish, second.enemy, "initial", second.start.uptime, "combat-start")
    if not self or self.inCombat ~= false or not enemy or enemy.opponent ~= true or enemy.targetGUID ~= first.me
        or enemy.status.inCombat ~= "readable" or enemy.status.targetGUID ~= "readable"
        or not entry or entry.opponent ~= true or entry.dead ~= false or entry.targetGUID ~= first.me
        or entry.status.targetGUID ~= "readable" then return end
    local closing = { [first.me] = { dead = self.dead }, [first.enemy] = { dead = enemy.dead, combat = enemy.inCombat } }
    if not addon.OpenWorldGapPair(a, closing, first.me, first.enemy) or not MatchedRecap(laterWindow, second, event) then return end
    return gap
end

local function Append(a, b)
    for _, item in ipairs(b or {}) do a[#a + 1] = item end
end

local function MergeDiagnostics(before, after)
    if not before then return after end
    if not after then return before end
    local count = (before.windowsDropped or 0) + #before.windows
    for _, window in ipairs(after.windows) do window.index = count + window.index end
    Append(before.windows, after.windows)
    Append(before.recaps, after.recaps)
    before.windowsDropped = (before.windowsDropped or 0) + (after.windowsDropped or 0)
    before.recapsDropped = (before.recapsDropped or 0) + (after.recapsDropped or 0)
    return before
end

local function ShiftEnding(state, shift)
    for _, field in ipairs({ "first", "last", "lateFirst", "lateLast", "lastAction" }) do
        local sample = state[field]
        if sample and Number(sample.offset) then sample.offset = sample.offset + shift end
    end
    for _, field in ipairs({ "returnedAt", "lifeChangedAt", "lastMeterActivity" }) do
        if Number(state[field]) then state[field] = state[field] + shift end
    end
    for actor, offset in pairs(state.offense or {}) do
        if Number(offset) then state.offense[actor] = offset + shift end
    end
    for _, pressure in pairs(state.pressure or {}) do
        if Number(pressure.offset) then pressure.offset = pressure.offset + shift end
    end
end

local function Merge(battles, first, second, gap)
    local a, b = first.battle, second.battle
    local previous, observation = a.observation, b.observation
    local shift = second.start.uptime - first.start.uptime
    a.recoveredContinuation = { id = second.id, gap = gap, assessment = previous.assessment, participation = previous.participation,
        coverage = previous.coverage, playerState = previous.playerState, visibilityGap = previous.visibilityGap }
    second.segment.offset = shift
    second.segment.continuation = "recovered-combat-gap"
    for id, offset in pairs(second.segment.localDeathWitnesses or {}) do second.segment.localDeathWitnesses[id] = offset + shift end
    table.insert(observation.segments, 1, first.segment)
    for _, state in ipairs(observation.life or {}) do state.offset = state.offset + shift end
    ShiftEnding(observation.assessment, shift)
    ShiftEnding(observation.participation, shift)
    local event = b.events[1]
    event.offset, event.segmentIndex = event.offset + shift, 2
    a.events, a.observation, a.recoveredDeathRecaps = b.events, observation, b.recoveredDeathRecaps
    for _, recap in pairs(a.recoveredDeathRecaps or {}) do recap.offset = recap.offset + shift end
    a.time, a.personalOutcome = math.max(a.time, b.time), nil
    for _, side in ipairs({ "allies", "enemies" }) do
        for key, value in pairs(b[side][1]) do
            if a[side][1][key] == nil then a[side][1][key] = value end
        end
    end
    if b.rewards then
        a.rewards = a.rewards or {}
        for id, reward in pairs(b.rewards) do Ledger.AddRewards(a.rewards, id, reward.honorableKills or 0, reward.honor or 0) end
    end
    local unassigned = b.unassignedRewards
    if unassigned then Ledger.AddRewards(a, "unassignedRewards", unassigned.honorableKills or 0, unassigned.honor or 0) end
    a.combatDiagnostics = MergeDiagnostics(a.combatDiagnostics, b.combatDiagnostics)
    battles[second.id] = nil
end

-- Repair only a uniquely captured live-exit / pursued-entry pair from the
-- same native session when the old deadline demonstrably interrupted it.
function addon.RestoreSplitSkirmishes(battles, diagnostics)
    local sessions = Index(diagnostics, battles)
    for _, session in pairs(sessions or {}) do
        for sequence, window in pairs(session) do
            local later = session[sequence + 1]
            if window.owner and later and later.owner and window.owner ~= later.owner then
                local first = MatchRecord(window.owner, battles[window.owner], window)
                local second = MatchRecord(later.owner, battles[later.owner], later)
                local gap = first and second and ProvenGap(first, second, later)
                if gap then Merge(battles, first, second, gap) end
            end
        end
    end
end
