local _, addon = ...

local Number = addon.SkirmishDeathEvidence.IsNumber

local function ReadableFields(row, ...)
    if type(row) ~= "table" or type(row.status) ~= "table" then return false end
    for index = 1, select("#", ...) do
        if row.status[select(index, ...)] ~= "readable" then return false end
    end
    return true
end

local function Positive(amount)
    return Number(amount) and amount > 0
end

local function CompleteSources(category)
    return ReadableFields(category, "session", "sources", "duration", "totalAmount")
        and Positive(category.duration) and Positive(category.totalAmount)
        and type(category.sources) == "table" and category.sourceCount == #category.sources
end

local function PlayerTotal(source)
    return ReadableFields(source, "row", "sourceGUID", "totalAmount") and Positive(source.totalAmount)
        and type(source.sourceGUID) == "string" and source.sourceGUID:match("^Player%-.+")
end

-- Forever's EnemyDamageTaken can report a whole contribution as a native
-- no-spell row. Validate the complete matrix against the GUID-keyed DamageDone
-- view of the same selection before using any of its name-only endpoints.
local function MatchedDamageTotals(evidence, done, taken)
    if not CompleteSources(done) or not CompleteSources(taken) or done.duration ~= taken.duration
        or done.totalAmount ~= taken.totalAmount then return end
    local outgoing, byVictim, namedDamage = {}, {}, {}
    local total, received = 0, 0
    for _, source in ipairs(done.sources) do
        if not PlayerTotal(source) or outgoing[source.sourceGUID] then return end
        outgoing[source.sourceGUID] = source.totalAmount
        total = total + source.totalAmount
    end
    if total ~= done.totalAmount then return end
    for _, source in ipairs(taken.sources) do
        if not PlayerTotal(source) or byVictim[source.sourceGUID] or not ReadableFields(source, "spells")
            or type(source.spells) ~= "table" or #source.spells ~= source.spellCount then return end
        local attackerAmounts, sum = {}, 0
        for _, spell in ipairs(source.spells) do
            local detail = spell.target
            if not ReadableFields(spell, "row", "spellID", "totalAmount", "creatureName")
                or spell.spellID ~= 0 or spell.creatureName ~= "" or not Positive(spell.totalAmount)
                or spell.targetCount ~= 1 or spell.detailStatus ~= "readable"
                or not ReadableFields(detail, "row", "unitName", "unitClassFilename", "amount", "isMob", "isPet")
                or detail.unitClassFilename ~= "" or detail.amount ~= 0 or detail.isMob ~= false or detail.isPet ~= false then return end
            local attacker = evidence.fullNames[detail.unitName]
            local id = attacker and attacker.guid
            if not id or attacker.player.faction ~= evidence.faction or not outgoing[id] or attackerAmounts[id] then return end
            attackerAmounts[id] = spell.totalAmount
            namedDamage[id] = (namedDamage[id] or 0) + spell.totalAmount
            sum = sum + spell.totalAmount
        end
        if sum ~= source.totalAmount then return end
        byVictim[source.sourceGUID] = attackerAmounts
        received = received + sum
    end
    if received ~= taken.totalAmount then return end
    for id, amount in pairs(outgoing) do
        if namedDamage[id] ~= amount then return end
    end
    return byVictim
end

local function PairedUpdate(signal, selector, start, finish)
    return type(signal) == "table" and signal.sessionID == selector
        and Number(signal.firstUptime) and Number(signal.uptime)
        and signal.firstUptime >= start and signal.firstUptime <= finish and signal.uptime >= signal.firstUptime
        and signal.uptime <= finish + 1.5
end

local function SeenDuring(contact, first, last)
    return Number(contact.firstSeen) and Number(contact.lastSeen) and contact.firstSeen <= last and contact.lastSeen >= first
end

local function CombatAtStart(contact, start, targetID)
    local function Matches(unit)
        return unit and unit.uptime == start and unit.inCombat == true and unit.dead == false
            and (not targetID or unit.targetGUID == targetID)
    end
    if Matches(contact.initial) or Matches(contact.latest) then return true end
    for _, unit in ipairs(contact.changes or {}) do
        if Matches(unit) then return true end
    end
end

local function ReverseDamage(evidence, taken, duration, friendly, opponent)
    if not CompleteSources(taken) or taken.duration ~= duration then return end
    for _, source in ipairs(taken.sources) do
        if source.sourceGUID == friendly.guid and PlayerTotal(source) and ReadableFields(source, "spells") then
            for _, spell in ipairs(source.spells or {}) do
                local detail = spell.target
                if ReadableFields(spell, "row") and spell.detailStatus == "readable" and spell.targetCount == 1
                    and ReadableFields(detail, "row", "unitName", "unitClassFilename", "amount", "isMob", "isPet")
                    and detail.isMob == false and detail.isPet == false and Positive(detail.amount)
                    and type(detail.unitName) == "string" and type(detail.unitClassFilename) == "string"
                    and evidence.names[detail.unitName .. "\0" .. detail.unitClassFilename] == opponent then return true end
            end
        end
    end
end

-- Only the directly witnessed enemy death in this literal local segment
-- anchors this supplementary read. A different target in the shared meter
-- session helps reconcile the sums but cannot join the roster via this path.
function addon.MeterSegmentVictims(battle, segment)
    local result = {}
    if not battle then return result end
    local enemies, allies = {}, {}
    for _, player in ipairs(battle.allies) do if player.id then allies[player.id] = true end end
    for _, player in ipairs(battle.enemies) do if player.id then enemies[player.id] = true end end
    local phases = addon.SkirmishDeathEvidence.Segments(battle)
    for _, event in ipairs(battle.events) do
        if event.kind == "kill" and allies[event.actorID] and enemies[event.targetID] then
            local phase = addon.SkirmishDeathEvidence.LegacyDeathWindow(phases, event)
            if phase and phase.evidence == segment then result[event.targetID] = true end
        end
    end
    return result
end

function addon.MatchMeterSourceTotals(evidence, row, victims, start, previousEnd, doneUpdate, takenUpdate)
    if not next(victims) or not Number(start) or not Number(row.uptime) or row.uptime <= start or row.meterReset
        or row.areaChanged or not ReadableFields(row, "availableSessions") then return end
    local selector = row.meterSessionID or 0
    if not PairedUpdate(doneUpdate, selector, start, row.uptime) or not PairedUpdate(takenUpdate, selector, start, row.uptime) then return end
    local first = math.max(doneUpdate.firstUptime, takenUpdate.firstUptime)
    local last = math.min(doneUpdate.uptime, takenUpdate.uptime, row.uptime)
    if first > last then return end
    local done, taken = row.meter.DamageDone, row.meter.EnemyDamageTaken
    local byVictim = MatchedDamageTotals(evidence, done, taken)
    if not byVictim then return end
    local length = row.uptime - start
    if (selector == 0 and Number(previousEnd) and row.uptime - taken.duration <= previousEnd + 0.5)
        or taken.duration < length - 2 then return end
    local late = math.max(doneUpdate.uptime, takenUpdate.uptime) > row.uptime + 0.5
    local long = taken.duration > length + 2
    local status = row.meterEvidence
    if late then
        if not long or (selector == 0 and not Number(previousEnd))
            or status.DamageDone ~= "duration-mismatch" or status.EnemyDamageTaken ~= "duration-mismatch" then return end
    else
        local expected = long and "eligible-corroborated" or "eligible"
        if status.DamageDone ~= expected or status.EnemyDamageTaken ~= expected then return end
    end
    local links = {}
    for victimID, amounts in pairs(byVictim) do
        local victim = victims[victimID] and evidence.player[victimID]
        if victim and victim.player.opponent == true and victim.player.faction ~= evidence.faction and amounts[evidence.localID]
            and SeenDuring(evidence.contacts[victimID], first, last) then
            for id, amount in pairs(amounts) do
                local attacker = evidence.player[id]
                local join = not late or id == evidence.localID or
                    (CombatAtStart(evidence.contacts[id], start) and CombatAtStart(evidence.contacts[victimID], start, id)
                        and ReverseDamage(evidence, row.meter.DamageTaken, taken.duration, attacker, victim))
                if join and SeenDuring(evidence.contacts[id], first, last) then
                    links[#links + 1] = { attacker = attacker, victim = victim, amount = amount }
                end
            end
        end
    end
    table.sort(links, function(a, b)
        if a.victim.guid == b.victim.guid then return a.attacker.guid < b.attacker.guid end
        return a.victim.guid < b.victim.guid
    end)
    return links
end

-- The amount and its basis live beside any strict detail rows. Recovery
-- projects the same append-only proof without a dependency on the debug log.
function addon.RecordMeterSourceTotals(segment, links, existingLinks)
    if not links or #links == 0 then return end
    local hostile = segment.meter.hostileLinks or {}
    local contributions = segment.contributionLinks or existingLinks or {}
    local aggregates = segment.combatAggregates or {}
    local changed
    for _, link in ipairs(links) do
        local a, b = link.attacker.guid, link.victim.guid
        local recorded, paired
        for _, row in ipairs(contributions) do
            if row.category == "EnemyDamageTaken" and row.actorID == a and row.targetID == b and not row.petEndpoint then
                recorded = row
                break
            end
        end
        if not recorded then
            recorded = { category = "EnemyDamageTaken", actorID = a, targetID = b, amountBasis = "source-total-matched" }
            contributions[#contributions + 1] = recorded
            changed = true
        end
        for _, row in ipairs(hostile) do
            if row.allyID == a and row.opponentID == b then paired = true; break end
        end
        if not paired then
            hostile[#hostile + 1] = { allyID = a, opponentID = b }
            changed = true
        end
        if recorded.amountBasis == "source-total-matched" then
            local present
            for _, row in ipairs(aggregates) do
                if row.category == recorded.category and row.actorID == a and row.targetID == b and row.amountBasis == recorded.amountBasis then
                    present = true
                    break
                end
            end
            if not present then
                aggregates[#aggregates + 1] = { category = recorded.category, actorID = a, targetID = b,
                    amount = link.amount, amountBasis = recorded.amountBasis }
                changed = true
            end
        end
    end
    if changed then
        segment.meter.hostileLinks, segment.contributionLinks, segment.combatAggregates = hostile, contributions, aggregates
    end
    return changed
end

-- Native Forever DamageMeterType values used by diagnostic rows that predate
-- this projection. The live path uses the client enum when subscribing.
local savedDamageDone, savedEnemyTaken = 0, 10

function addon.IndexMeterSourceTotalWindows(diagnostics, skirmishes)
    if type(diagnostics) ~= "table" or diagnostics.version ~= 1 or type(diagnostics.rows) ~= "table" then return end
    local windows, previous = {}, {}
    for _, row in ipairs(diagnostics.rows) do
        if type(row) == "table" and Number(row.session) and Number(row.combatSequence) then
            local session = windows[row.session] or {}
            windows[row.session] = session
            local window = session[row.combatSequence] or {}
            session[row.combatSequence] = window
            if row.kind == "COMBAT_START" then
                window.start = window.start == nil and row or false
                window.previous = previous[row.session]
            elseif row.kind == "COMBAT_END" then
                window.finish = window.finish == nil and row or false
                previous[row.session] = row
            elseif row.kind == "ZONE_CHANGED_NEW_AREA" or row.kind == "PLAYER_LEAVING_WORLD" then
                previous[row.session] = nil
            end
        end
    end
    if not next(windows) then return end
    for _, battle in pairs(skirmishes) do
        if type(battle) == "table" and not battle.manual then
            for _, segment in ipairs(battle.observation and battle.observation.segments or {}) do
                local report = segment.reportMeter
                local session = report and windows[report.session]
                local window = session and session[report.combatSequence]
                if window then window.owner = window.owner == nil and segment or false end
            end
        end
    end
    return windows
end

local function MatchLegacyMeterWindow(battle, segment, phase, windows, me)
    local report = segment.reportMeter
    local session = report and report.status == "sampled" and not report.areaChanged and not report.meterReset
        and windows[report.session]
    local window = session and session[report.combatSequence]
    local start, row = window and window.start, window and window.finish
    if not start or not row or window.owner ~= segment or not phase.finish or not Number(start.uptime) or not Number(row.uptime)
        or not ReadableFields(start, "availableSessions") or start.time ~= (segment.localCombatAt or segment.startedAt)
        or row.time ~= segment.endedAt or not Number(report.uptime) or report.uptime ~= row.uptime or report.time ~= row.time
        or math.abs(row.uptime - start.uptime - segment.duration) > 0.001
        or not row.player or row.player.guid ~= me or not start.player or start.player.guid ~= me
        or not row.status or row.status.meter ~= "sampled" or row.status.meterWindow == "previous-window-pending"
        or type(row.contacts) ~= "table" or type(row.meter) ~= "table"
        or type(row.meterEvidence) ~= "table" or type(row.meterUpdates) ~= "table"
        or row.meterSelection ~= report.meterSelection or row.meterSessionID ~= report.meterSessionID then return end
    local candidates = row.newMeterSessionIDs
    if type(candidates) ~= "table" or (row.meterSelection == "current-fallback" and (#candidates ~= 0 or row.meterSessionID))
        or (row.meterSelection == "new-archived" and (#candidates ~= 1 or not Number(row.meterSessionID)
            or candidates[1] ~= row.meterSessionID))
        or (row.meterSelection ~= "new-archived" and row.meterSelection ~= "current-fallback") then return end
    local meter = segment.meter
    if meter and (meter.selection ~= row.meterSelection or meter.sessionID ~= row.meterSessionID) then return end
    local instance = battle.origin == "battleground" and "pvp" or "none"
    if row.instanceType ~= instance or start.instanceType ~= instance or start.zone ~= battle.zone or row.zone ~= battle.zone
        or (instance == "pvp" and (not battle.instanceMapID or row.instanceMapID ~= battle.instanceMapID
            or start.instanceMapID ~= battle.instanceMapID)) then return end
    local previous = window.previous
    local before = previous and previous.combatSequence == row.combatSequence - 1
        and session[previous.combatSequence].finish == previous and previous.instanceType == instance
        and previous.instanceMapID == row.instanceMapID and previous.zone == row.zone and previous.player
        and previous.player.guid == me and previous.uptime
    return row, start.uptime, before
end

function addon.RestoreMeterSourceTotals(battle, windows)
    if not windows or battle.manual then return end
    local me
    for _, player in ipairs(battle.allies) do if player.isSelf then me = player.id; break end end
    if not me then return end
    local changed
    for _, phase in ipairs(addon.SkirmishDeathEvidence.Segments(battle)) do
        local segment = phase.evidence
        local row, start, previousEnd = MatchLegacyMeterWindow(battle, segment, phase, windows, me)
        local faction = row and row.player.faction
        if faction == "Alliance" or faction == "Horde" then
            local evidence = addon.NewMeterParticipantEvidence(row.contacts, row.petOwners or {}, faction, me)
            local prefix = (row.meterSessionID or 0) .. ":"
            local links = addon.MatchMeterSourceTotals(evidence, row, addon.MeterSegmentVictims(battle, segment), start, previousEnd,
                row.meterUpdates[prefix .. savedDamageDone], row.meterUpdates[prefix .. savedEnemyTaken])
            if links and #links > 0 then
                segment.meter = segment.meter or { scope = "aggregate", selection = row.meterSelection, sessionID = row.meterSessionID }
                if addon.RecordMeterSourceTotals(segment, links, phase.links) then
                    local participants = {}
                    for _, unit in ipairs(battle.allies) do participants[unit.id] = true end
                    for _, link in ipairs(links) do
                        local unit = link.attacker
                        if not participants[unit.guid] then
                            addon.RecordWorldMeterParticipant(battle, unit, faction)
                            participants[unit.guid] = true
                        end
                    end
                    changed = true
                end
            end
        end
    end
    return changed
end
