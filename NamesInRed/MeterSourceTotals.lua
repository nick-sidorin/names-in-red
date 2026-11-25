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

-- Shared or delayed meter sessions need their existing independent target
-- anchor. A normally scoped window can qualify from its outgoing pair alone.
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

local function ObservedCorpse(contact, id, first, finish)
    local initial, latest = contact.initial, contact.latest
    if not initial or initial.guid ~= id or initial.dead ~= false or not Number(initial.uptime)
        or not ReadableFields(initial, "guid", "dead") or initial.uptime > first
        or not latest or latest.guid ~= id or latest.dead ~= true or contact.changeOverflow then return end
    local function Confirmed(unit)
        return unit.guid == id and unit.isPlayer == true and unit.opponent == true and unit.dead == true and unit.feign == false
            and ReadableFields(unit, "guid", "dead", "feign", "opponent")
            and Number(unit.uptime) and unit.uptime >= first and unit.uptime <= finish
    end
    local corpse = Confirmed(latest) and latest or nil
    for _, unit in ipairs(contact.changes or {}) do
        if Confirmed(unit) and (not corpse or unit.uptime < corpse.uptime) then corpse = unit end
    end
    if not corpse then return end
    for _, unit in ipairs(contact.changes or {}) do
        if unit.dead == false and Number(unit.uptime) and unit.uptime > corpse.uptime then return end
    end
    return corpse
end

local function TargetedAlly(evidence, enemy, corpse, finish)
    local initial = enemy.initial
    local id = initial.targetGUID
    if id == evidence.localID or id ~= corpse.targetGUID or initial.inCombat ~= true
        or not ReadableFields(initial, "targetGUID", "inCombat")
        or not ReadableFields(corpse, "targetGUID") then return end
    for _, unit in ipairs(enemy.changes or {}) do
        if unit.targetGUID and unit.targetGUID ~= id and Number(unit.uptime) and unit.uptime <= corpse.uptime then return end
    end
    local ally = evidence.player[id]
    local seen = ally and evidence.contacts[id].initial
    if seen and ally.player.faction == evidence.faction and seen.faction == evidence.faction and seen.guid == id
        and seen.isPlayer == true and seen.opponent == false and seen.dead == false and seen.inCombat == true
        and seen.pvp == true and ReadableFields(seen, "guid", "isPlayer", "opponent", "faction", "inCombat", "dead", "pvp")
        and (seen.status.targetGUID == "absent" or (ReadableFields(seen, "targetGUID") and seen.targetGUID == corpse.guid))
        and Number(seen.uptime)
        and seen.uptime <= finish and math.abs(seen.uptime - corpse.uptime) <= addon.SkirmishDeathEvidence.lateWindowGrace then
        return ally, seen.uptime
    end
end

local function ObserveOutgoingWindow(evidence, links, row, start, first)
    local exits, victims = {}, {}
    local me = evidence.localID
    local localUnit = evidence.contacts[me] and evidence.contacts[me].latest
    local survived = localUnit and localUnit.guid == me and localUnit.reason == "combat-end"
        and localUnit.dead == false and localUnit.inCombat == false
        and ReadableFields(localUnit, "guid", "dead", "inCombat")
        and Number(localUnit.uptime) and math.abs(localUnit.uptime - row.uptime) <= 0.05
    for _, link in ipairs(links) do
        if link.attacker.guid == me then victims[#victims + 1] = link.victim.guid end
    end
    for _, id in ipairs(victims) do
        local contact = evidence.contacts[id]
        local corpse = ObservedCorpse(contact, id, first, row.uptime)
        if corpse then
            local item = { opponentID = id, deathOffset = corpse.uptime - start, source = corpse.reason }
            if #victims == 1 and row.instanceType == "none" and not evidence.localNpcDamage then
                local ally, seen = TargetedAlly(evidence, contact, corpse, row.uptime)
                if ally then
                    item.ally, item.allyOffset = ally, seen - start
                    item.targetOffset = contact.initial.uptime - start
                end
            end
            exits[#exits + 1] = item
        end
    end
    if #exits > 0 then return { corpses = exits, localSurvivor = survived or nil } end
end

function addon.MatchMeterSourceTotals(evidence, row, victims, start, previousEnd, doneUpdate, takenUpdate)
    if not Number(start) or not Number(row.uptime) or row.uptime <= start or row.meterReset
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
        local victim = (not long or victims[victimID]) and evidence.player[victimID]
        if victim and victim.player.opponent == true and victim.player.pvp ~= false
            and victim.player.faction ~= evidence.faction and amounts[evidence.localID]
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
    return links, not long and ObserveOutgoingWindow(evidence, links, row, start, first) or nil
end

function addon.RecordOutgoingWindowContext(battle, segment, index, context, faction)
    if not context then return end
    segment.outgoingLocalSurvivor = context.localSurvivor
    local offset = addon.SkirmishDeathEvidence.SegmentStart(battle, segment)
    for _, item in ipairs(context.corpses) do
        local deathAt = offset + item.deathOffset
        local found, insertAt
        for i, event in ipairs(battle.events) do
            if event.targetID == item.opponentID and addon.Ledger.IndicatesDeath(event)
                and Number(event.offset) and event.offset >= offset and event.offset <= offset + segment.duration then
                found = true
                break
            end
            if not insertAt and Number(event.offset) and event.offset > deathAt then insertAt = i end
        end
        if not found then
            table.insert(battle.events, insertAt or #battle.events + 1, { kind = "death", source = item.source,
                targetID = item.opponentID, offset = deathAt, segmentIndex = index, observedDead = true })
        end
        if item.ally and not segment.engagedAlly then
            addon.RecordWorldMeterParticipant(battle, item.ally, faction)
            segment.engagedAlly = { allyID = item.ally.guid, opponentID = item.opponentID,
                targetOffset = item.targetOffset, corpseOffset = item.deathOffset, allyOffset = item.allyOffset }
        end
    end
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
            local window = session[row.combatSequence] or { rewards = {} }
            session[row.combatSequence] = window
            if row.kind == "COMBAT_START" then
                window.start = window.start == nil and row or false
                window.previous = previous[row.session]
            elseif row.kind == "COMBAT_END" then
                window.finish = window.finish == nil and row or false
                previous[row.session] = row
            elseif row.kind == "CHAT_MSG_COMBAT_HONOR_GAIN" or row.kind == "PLAYER_PVP_KILLS_CHANGED" then
                window.rewards[#window.rewards + 1] = row
            elseif row.kind == "PARTY_KILL" then
                window.hadKill = true
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

local function RecoveredWindow(window, battles, me)
    local start, finish = window.start, window.finish
    if window.owner ~= nil or not start or not finish or not Number(start.time) or not Number(finish.time)
        or not Number(start.uptime) or not Number(finish.uptime) or start.uptime >= finish.uptime
        or math.abs((finish.time - start.time) - (finish.uptime - start.uptime)) > 1
        or not start.player or start.player.guid ~= me or not finish.player or finish.player.guid ~= me
        or start.player.faction ~= finish.player.faction
        or start.instanceType ~= "none" or finish.instanceType ~= "none" or type(start.zone) ~= "string" or start.zone ~= finish.zone
        or not finish.status or finish.status.meter ~= "sampled" or finish.status.meterWindow ~= "no-linked-pvp"
        or not ReadableFields(start, "availableSessions") or type(finish.contacts) ~= "table"
        or type(finish.meterUpdates) ~= "table" or type(finish.meter) ~= "table" or type(finish.meterEvidence) ~= "table"
        or finish.meterEvidence.DamageDone ~= "eligible" or finish.meterEvidence.EnemyDamageTaken ~= "eligible" then return end
    local ids = finish.newMeterSessionIDs
    local selector = finish.meterSessionID
    if type(ids) ~= "table" or not ((finish.meterSelection == "current-fallback" and selector == nil and #ids == 0)
        or (finish.meterSelection == "new-archived" and Number(selector) and #ids == 1 and ids[1] == selector)) then return end
    -- Some legacy records lack a report link. Their overlap is still enough
    -- to make the claimed orphan ambiguous.
    for _, battle in pairs(battles) do
        if type(battle) == "table" and not battle.manual and battle.origin ~= "battleground"
            and Number(battle.startedAt) and Number(battle.time) then
            local last = battle.time
            for _, segment in ipairs(battle.observation and battle.observation.segments or {}) do
                if Number(segment.endedAt) then last = math.max(last, segment.endedAt) end
            end
            if battle.startedAt <= finish.time and last >= start.time then return end
        end
    end
    local previous = window.previous
    local before = previous and previous.uptime
    return start, finish, before
end

local function HistoricalRewards(db, window, start, finish, context)
    local root, signals = db.unassignedRewards, finish.pvpReasons
    if not root or root.honorableKills ~= 1 or not Positive(root.honor) or not signals
        or signals["reward-unassigned-skirmish"] ~= 1 or window.hadKill or finish.restrictedPartyKills ~= 0
        or not context or #context.corpses ~= 1 or not addon.HonorFromChat
        or not ReadableFields(start, "sessionHK") or not ReadableFields(finish, "sessionHK")
        or not Number(start.sessionHK) or finish.sessionHK ~= start.sessionHK + 1 then return end
    local hkAt, honorAt, amount, lineID
    for _, row in ipairs(window.rewards) do
        if not Number(row.uptime) or row.uptime < start.uptime or row.uptime > finish.uptime
            or row.zone ~= start.zone or row.instanceType ~= start.instanceType
            or not row.player or row.player.guid ~= start.player.guid then return end
        if row.kind == "PLAYER_PVP_KILLS_CHANGED" then
            if not ReadableFields(row, "sessionHK") or row.unit ~= "player" or row.sessionHK ~= finish.sessionHK
                or (hkAt and hkAt ~= row.uptime) then return end
            hkAt = row.uptime
        else
            local parsed = addon.HonorFromChat(row.message)
            if not ReadableFields(row, "message", "lineID") or not Positive(row.lineID)
                or (lineID and (lineID ~= row.lineID or honorAt ~= row.uptime or amount ~= parsed)) then return end
            amount, honorAt, lineID = parsed, row.uptime, row.lineID
        end
    end
    if not hkAt or not honorAt or amount ~= root.honor then return end
    local deathAt = start.uptime + context.corpses[1].deathOffset
    if math.max(hkAt, honorAt, deathAt) - math.min(hkAt, honorAt, deathAt) <= 2 then return amount end
end

local function BuildRecoveredBattle(db, start, finish, evidence, links, context)
    local segment = { startedAt = start.time, endedAt = finish.time, offset = 0, duration = finish.uptime - start.uptime,
        startReason = "local-combat", endReason = "local-combat-ended", confirmedBy = "meter",
        reportMeter = addon.ReportMeterSnapshot(finish), meter = { scope = "aggregate", selection = finish.meterSelection,
            sessionID = finish.meterSessionID } }
    local battle = { startedAt = start.time, time = finish.time, zone = start.zone, origin = "world",
        allies = {}, enemies = {}, events = {}, observation = { coverage = "local", segments = { segment },
            playerState = context and context.localSurvivor and "alive" or nil,
            participation = { state = "finalized", boundary = "recovered-meter-window" }, assessment = {} } }
    addon.RecordWorldMeterParticipant(battle, evidence.player[evidence.localID], evidence.faction)
    battle.allies[1].isSelf = true
    for _, link in ipairs(links) do
        addon.RecordWorldMeterParticipant(battle, link.attacker, evidence.faction)
        addon.RecordWorldMeterParticipant(battle, link.victim, evidence.faction)
        local rival = addon.Ledger.Add(db, link.victim.guid, link.victim.name)
        if rival and not addon.HasFullName(rival.displayName) then rival.displayName = link.victim.name end
    end
    addon.RecordMeterSourceTotals(segment, links)
    addon.RecordOutgoingWindowContext(battle, segment, 1, context, evidence.faction)
    return battle
end

function addon.RestoreMissingOutgoingSkirmishes(db, windows)
    if not windows then return end
    local battles = db.skirmishes or {}
    local candidates, unmatchedWindows = {}, 0
    for sessionID, session in pairs(windows) do
        for sequence, window in pairs(session) do
            local finish = window.finish
            local reasons = finish and finish.pvpReasons
            if reasons and reasons["reward-unassigned-skirmish"] then unmatchedWindows = unmatchedWindows + 1 end
            local localUnit = window.start and window.start.player
            local me, faction = localUnit and localUnit.guid, localUnit and localUnit.faction
            if type(me) == "string" and me:match("^Player%-.+") and (faction == "Alliance" or faction == "Horde") then
                local start, finish, before = RecoveredWindow(window, battles, me)
                local key = finish and table.concat({ sessionID, sequence, start.uptime, start.time }, ":")
                if key and not (db.recoveredMeterWindows and db.recoveredMeterWindows[key]) then
                    local evidence = addon.NewMeterParticipantEvidence(finish.contacts, finish.petOwners or {}, faction, me)
                    local prefix = (finish.meterSessionID or 0) .. ":"
                    local links, context = addon.MatchMeterSourceTotals(evidence, finish, {}, start.uptime, before,
                        finish.meterUpdates[prefix .. savedDamageDone], finish.meterUpdates[prefix .. savedEnemyTaken])
                    if links and #links > 0 and evidence.player[me] then
                        candidates[#candidates + 1] = { key = key, start = start, finish = finish, window = window,
                            evidence = evidence, links = links, context = context }
                    end
                end
            end
        end
    end
    table.sort(candidates, function(a, b) return a.start.time < b.start.time end)
    for index, item in ipairs(candidates) do
        local previous, following = candidates[index - 1], candidates[index + 1]
        if (not previous or previous.finish.time < item.start.time) and (not following or following.start.time > item.finish.time) then
            local battle = BuildRecoveredBattle(db, item.start, item.finish, item.evidence, item.links, item.context)
            local sequence = db.encounterSequence or 0
            repeat sequence = sequence + 1 until not battles["world:" .. sequence]
            battle.sequence = sequence
            db.encounterSequence, db.skirmishes = sequence, battles
            battles["world:" .. sequence] = battle
            db.recoveredMeterWindows = db.recoveredMeterWindows or {}
            db.recoveredMeterWindows[item.key] = true
            -- Only one candidate may claim the whole previously unmatched pool.
            local honor = #candidates == 1 and unmatchedWindows == 1
                and HistoricalRewards(db, item.window, item.start, item.finish, item.context)
            if honor then addon.Ledger.MoveUnassignedRewards(db, battle, 1, honor) end
        end
    end
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
