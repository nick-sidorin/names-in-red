local addonName, addon = ...
local L = addon.L
local frame = CreateFrame("Frame")
local db
local deathSequence = 0
local combatSequence = 0
local combat, settling, passive, lastCombatEnd
local limit = 1000
local plateTokens = {}
local diagnosticRegistration, diagnosticBuild
local demoFactions = { alliance = "Alliance", horde = "Horde" }

local function ClearDiagnostics()
    if not db then
        NamesInRedDebugDB = nil
        return
    end
    db.rows, db.dropped = {}, 0
    deathSequence = deathSequence + 1
    combatSequence, combat, settling, passive, lastCombatEnd = 0, nil, nil, nil, nil
end

local function ReadDeathLevel(row, victim, attacker)
    if not row.player or row.player.guid ~= victim then return end
    local player = row.contacts[victim] and row.contacts[victim].latest
    local rival = row.contacts[attacker] and row.contacts[attacker].latest
    if player and player.guid == victim and player.dead == true
        and rival and rival.guid == attacker and type(rival.level) == "number" and (rival.level > 0 or rival.level == -1) then
        return rival.level
    end
end

local function RestoreDeathLevels(journal, diagnostics)
    if type(journal.skirmishes) ~= "table" or type(diagnostics) ~= "table"
        or diagnostics.version ~= 1 or type(diagnostics.rows) ~= "table" then return end
    local combatEnds = {}
    for _, row in ipairs(diagnostics.rows) do
        if type(row) == "table" and row.kind == "COMBAT_END" and row.instanceType == "none" and type(row.time) == "number"
            and type(row.contacts) == "table" and type(row.zone) == "string" then
            -- Leave colliding timestamps ambiguous.
            local previous = combatEnds[row.time]
            combatEnds[row.time] = previous == nil and row or false
        end
    end
    if not next(combatEnds) then return end
    for id, battle in pairs(journal.skirmishes) do
        if type(id) == "string" and id:match("^world:%d+$") and type(battle) == "table"
            and type(battle.events) == "table" and type(battle.enemies) == "table" then
            for _, event in ipairs(battle.events) do
                local row = event.kind == "kill" and combatEnds[event.time]
                local level = row and row.zone == battle.zone and ReadDeathLevel(row, event.targetID, event.actorID)
                if level then
                    for _, rival in ipairs(battle.enemies) do
                        if rival.id == event.actorID and rival.level == nil then
                            rival.level = level
                            addon.Ledger.SaveSkirmish(journal, id, battle)
                            break
                        end
                    end
                end
            end
        end
    end
end

if addon then
    addon.ClearDiagnostics = ClearDiagnostics
    addon.RestoreDeathLevels = RestoreDeathLevels
end

local function Value(value)
    if issecretvalue and issecretvalue(value) then
        return nil, "secret"
    end
    local kind = type(value)
    if kind == "string" or kind == "number" or kind == "boolean" then
        return value, "readable"
    end
    return nil, value == nil and "absent" or "unsupported-type"
end

local function AccessibleTable(value)
    if issecretvalue and issecretvalue(value) then
        return false, "secret"
    end
    if type(value) ~= "table" then
        return false, value == nil and "absent" or "unsupported-type"
    end
    if canaccesstable and not canaccesstable(value) then
        return false, "restricted-table"
    end
    return true
end

local function Capture(result, key, value)
    local clean, status = Value(value)
    result[key] = clean
    result.status[key] = status
end

local function Call(result, key, fn, ...)
    if type(fn) ~= "function" then
        result.status[key] = "unavailable"
        return
    end
    local ok, value, second = pcall(fn, ...)
    if not ok then
        result.status[key] = "error"
        return
    end
    Capture(result, key, value)
    return second
end

local function Unit(unit)
    local data = { status = {} }
    Call(data, "guid", UnitGUID, unit)
    Capture(data, "surname", Call(data, "name", UnitName, unit))
    Call(data, "faction", UnitFactionGroup, unit)
    Call(data, "isPlayer", UnitIsPlayer, unit)
    Call(data, "opponent", UnitCanAttack, "player", unit)
    Call(data, "level", UnitLevel, unit)
    if addon.ReadUnitLevel then
        Call(data, "effectiveLevel", UnitEffectiveLevel, unit)
        local level = addon.ReadUnitLevel(unit)
        if level then data.level, data.status.level = level, "readable" end
    end
    Capture(data, "class", Call(data, "className", UnitClass, unit))
    return data
end

local function Add(kind)
    local row = {
        kind = kind, status = {}, session = db.session,
        combatSequence = combatSequence > 0 and combatSequence or nil,
    }
    Call(row, "time", GetServerTime)
    Call(row, "uptime", GetTime)
    Call(row, "instanceType", function()
        local _, instanceType = IsInInstance()
        return instanceType
    end)
    if row.instanceType == "pvp" then
        row.origin = "battleground"
        Call(row, "instanceMapID", addon.BattlegroundMapID)
    end
    Call(row, "inCombat", InCombatLockdown)
    Call(row, "zone", GetRealZoneText)
    if #db.rows >= limit then
        table.remove(db.rows, 1)
        db.dropped = db.dropped + 1
    end
    db.rows[#db.rows + 1] = row
    return row
end

local function Context(row)
    row.player = Unit("player")
    row.target = Unit("target")
    row.mouseover = Unit("mouseover")
end

local recapFields = {
    "sourceGUID", "sourceName", "sourceFlags", "event", "spellId", "spellName",
    "amount", "overkill", "absorbed", "timestamp", "currentHP",
}

local function Recap(sequence, delay)
    if sequence ~= deathSequence then
        return
    end
    local row = Add("RECAP")
    row.deathSequence, row.delay = sequence, delay
    local api = C_DeathRecap
    Call(row, "hasEvents", api and api.HasRecapEvents)
    if not api or not api.GetRecapEvents then
        row.status.events = "unavailable"
        return
    end
    local ok, events = pcall(api.GetRecapEvents)
    if not ok then
        row.status.events = "error"
        return
    end
    local accessible, status = AccessibleTable(events)
    row.status.events = accessible and "readable" or status
    if not accessible then
        return
    end
    row.eventCount = #events
    row.events = {}
    for index = 1, math.min(row.eventCount, 32) do
        local event = events[index]
        local hit = { status = {} }
        local readable, reason = AccessibleTable(event)
        hit.status.row = readable and "readable" or reason
        if readable then
            for _, field in ipairs(recapFields) do
                Capture(hit, field, event[field])
            end
        end
        row.events[index] = hit
    end
end

local function Score(row)
    local result = { status = {} }
    row.score = result
    local playerGUID = row.player.guid
    local api = C_PvP and C_PvP.GetScoreInfoByPlayerGuid
    if not playerGUID or not api then
        result.status.row = not api and "unavailable" or row.player.status.guid
        return
    end
    local ok, score = pcall(api, playerGUID)
    if not ok then
        result.status.row = "error"
        return
    end
    local readable, reason = AccessibleTable(score)
    result.status.row = readable and "readable" or reason
    if readable then
        Capture(result, "killingBlows", score.killingBlows)
        Capture(result, "honorableKills", score.honorableKills)
        Capture(result, "deaths", score.deaths)
        Capture(result, "healingDone", score.healingDone)
    end
end

local function Sample(row)
    Context(row)
    Call(row, "sessionHK", GetPVPSessionStats)
    Capture(row, "damageMeterFailure", Call(row, "damageMeterAvailable", C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable))
    if row.instanceType == "pvp" or row.instanceType == "arena" then
        Score(row)
    end
end

local function ReadResult(result, key, fn, ...)
    if type(fn) ~= "function" then
        result.status[key] = "unavailable"
        return
    end
    local ok, value = pcall(fn, ...)
    if not ok then
        result.status[key] = "error"
        return
    end
    local readable, reason = AccessibleTable(value)
    result.status[key] = readable and "readable" or reason
    if readable then return value end
end

local function CopyRow(input, fields, output)
    output = output or { status = {} }
    local readable, reason = AccessibleTable(input)
    output.status.row = readable and "readable" or reason
    if readable then
        for _, key in ipairs(fields) do Capture(output, key, input[key]) end
    end
    return output
end

local function PetToken(unit)
    if unit == "player" then return "pet" end
    local prefix, index = unit:match("^(party)(%d+)$")
    if not prefix then prefix, index = unit:match("^(raid)(%d+)$") end
    if prefix then return prefix .. "pet" .. index end
end

local function CopyGroup(row)
    Call(row, "groupSize", GetNumGroupMembers)
    Call(row, "subgroupSize", GetNumSubgroupMembers)
    Call(row, "inRaid", IsInRaid)
    local count = row.inRaid and row.groupSize or row.subgroupSize
    row.group = {}
    if type(count) ~= "number" then return end
    for index = 1, math.min(count, 10) do
        local token = (row.inRaid and "raid" or "party") .. index
        row.group[index] = Unit(token)
        Call(row.group[index], "targetGUID", UnitGUID, token .. "target")
        Call(row.group[index], "petGUID", UnitGUID, PetToken(token))
    end
end

local function SessionIDs(result, api)
    local sessions = ReadResult(result, "availableSessions", api.GetAvailableCombatSessions)
    if not sessions then return end
    local known = {}
    for _, session in ipairs(sessions) do
        local id = AccessibleTable(session) and Value(session.sessionID)
        if type(id) ~= "number" then
            result.status.availableSessions = "partial"
            return
        end
        known[id] = true
    end
    return known
end

local sourceFields = {
    "sourceGUID", "sourceCreatureID", "name", "classFilename", "classification",
    "factionGroup", "isLocalPlayer", "totalAmount", "deathRecapID", "deathTimeSeconds",
    "sourceDisplayType",
}
local sourceKeyFields = { "sourceGUID", "sourceCreatureID", "totalAmount" }
local spellFields = { "spellID", "totalAmount", "overkillAmount", "creatureName" }
local targetFields = { "unitName", "unitClassFilename", "classification", "isPet", "isMob", "amount" }

local meterCategories = {
    "DamageDone", "DamageTaken", "EnemyDamageTaken", "HealingDone", "Absorbs", "Interrupts", "Dispels", "Deaths",
}

local function Count(counts, reason)
    counts[reason] = (counts[reason] or 0) + 1
end

local function Retryable(reason)
    return reason == "secret" or reason == "restricted-table" or reason == "absent" or reason == "error"
end

local function SpellTargets(entry, sample, actor, category, evidence, counts, scratch, accept, probe, source)
    local details = entry.combatSpellDetails
    local readable, reason = AccessibleTable(details)
    if not readable then
        if sample then sample.detailStatus = reason end
        if actor then
            Count(counts, "details-" .. reason)
            if probe then addon.SampleCombatMeter(probe, category, actor, source, entry, nil, "details-" .. reason) end
        end
        return actor and Retryable(reason)
    end
    if next(details) == nil then
        if sample then sample.detailStatus = "empty" end
        if actor then
            Count(counts, "details-empty")
            if probe then addon.SampleCombatMeter(probe, category, actor, source, entry, nil, "details-empty") end
        end
        return
    end
    local listed = #details > 0
    local size = listed and #details or 1
    if sample then
        sample.detailStatus = "readable"
        sample.targetCount = size
        if listed then sample.targets = {} end
    end
    local retry = false
    for index = 1, actor and size or math.min(size, 4) do
        local retain = sample and index <= 4
        local input = details
        if listed then input = details[index] end
        local target = CopyRow(input, targetFields, not retain and scratch or nil)
        if retain then
            if listed then sample.targets[index] = target else sample.target = target end
        end
        if actor then
            local resolution, other = evidence:Link(category, actor, target, accept, source.sourceGUID ~= actor.guid)
            if probe then addon.SampleCombatMeter(probe, category, actor, source, entry, target, resolution, other) end
            Count(counts, resolution)
            retry = retry or resolution:match("%-secret$") ~= nil or resolution == "detail-restricted-table"
        end
    end
    return retry
end

local function MeterSources(result, sources, readSource, evidence, category, sampleLimit, accept, probe)
    local counts, linkedActors = {}, {}
    result.sourceCount = #sources
    result.sources = {}
    if evidence then result.resolution = counts end
    local sourceScratch, targetScratch = { status = {} }, { status = {} }
    local retry = false
    sampleLimit = sampleLimit or 12
    for index = 1, evidence and #sources or math.min(#sources, sampleLimit) do
        local retain = index <= sampleLimit
        local source = CopyRow(sources[index], retain and sourceFields or sourceKeyFields, not retain and sourceScratch or nil)
        local rowStatus = source.status.row
        if retain then result.sources[index] = source end
        if rowStatus == "readable" then
            local guid, creature = source.sourceGUID, source.sourceCreatureID
            local actor
            if evidence then
                local why
                actor, why = evidence:Source(category, source)
                if why then Count(counts, why) end
                retry = retry or why == "source-guid-secret"
            end
            local canSample = retain and ((source.isLocalPlayer and (guid or creature))
                or (type(guid) == "string" and (guid:match("^Player%-") or guid:match("^Pet%-"))))
            if actor or canSample then
                local detail = readSource(source, guid, creature)
                local spells = detail and detail.combatSpells
                local hasSpells, why = AccessibleTable(spells)
                source.status.spells = hasSpells and "readable" or why
                if hasSpells then
                    if retain then source.spellCount, source.spells = #spells, {} end
                    if actor and #spells == 0 then Count(counts, "no-spells") end
                    local previousLinks = counts.link
                    for spellIndex = 1, actor and #spells or math.min(#spells, 16) do
                        local entry = spells[spellIndex]
                        local readable, reason = AccessibleTable(entry)
                        local sample
                        if retain and spellIndex <= 16 then
                            sample = CopyRow(entry, spellFields)
                            source.spells[spellIndex] = sample
                        end
                        if readable then
                            local retryTarget = SpellTargets(entry, sample, actor, category, evidence, counts,
                                targetScratch, accept, probe, source)
                            retry = retry or retryTarget
                        elseif actor then
                            Count(counts, "spell-" .. reason)
                            if probe then addon.SampleCombatMeter(probe, category, actor, source, {}, nil, "spell-" .. reason) end
                            retry = retry or Retryable(reason)
                        end
                    end
                    if actor and counts.link ~= previousLinks then linkedActors[actor] = true end
                elseif actor then
                    local reason = detail and why or source.status.detail
                    Count(counts, "spells-" .. reason)
                    if probe then addon.SampleCombatMeter(probe, category, actor, source, {}, nil, "spells-" .. reason) end
                    retry = retry or Retryable(reason)
                end
            end
        elseif evidence then
            Count(counts, "source-row-" .. rowStatus)
            retry = retry or Retryable(rowStatus)
        end
    end
    return retry, linkedActors
end

local function ScopedMeterUpdate(window, signals, ended)
    return signals and signals.firstUptime and signals.uptime and ended
        and signals.firstUptime >= window.startedUptime and signals.uptime <= ended + 0.5
end

-- Only recover a duration-mismatched damage pair around an already confirmed
-- enemy. A nearby previous window or mixed Current slot invalidates it.
local function CorroboratedMeterPair(window, row, duration, selector, meterType, types, enemies, faction)
    if not enemies or not next(enemies) or not row.uptime or not window.startedUptime
        or type(duration) ~= "number" or duration <= 0 then return end
    if selector == 0 and (window.previousPending
        or (window.previousEnd and row.uptime - duration <= window.previousEnd + 0.5)) then return end
    if meterType ~= types.DamageTaken and meterType ~= types.DamageDone and meterType ~= types.EnemyDamageTaken then return end
    local updates, prefix = window.meterUpdates, selector .. ":"
    local signal = updates[prefix .. meterType]
    if not ScopedMeterUpdate(window, signal, row.uptime) then return end
    local peer
    for _, other in ipairs({ "DamageTaken", "DamageDone", "EnemyDamageTaken" }) do
        local kind = types[other]
        if kind and kind ~= meterType and ScopedMeterUpdate(window, updates[prefix .. kind], row.uptime) then
            peer = true
            break
        end
    end
    if not peer then return end
    return function(actor, target)
        local enemy, ally = actor, target
        if actor.player.faction == faction then enemy, ally = target, actor end
        local hostile = window.contacts[enemy.guid]
        local friendly = window.contacts[ally.guid]
        return enemies[enemy.guid] and hostile.firstSeen <= signal.uptime and friendly.firstSeen <= signal.uptime
            and hostile.lastSeen >= signal.firstUptime and friendly.lastSeen >= signal.firstUptime
    end
end

local function CaptureMeter(row, window, evidence, finalAttempt, enemies, faction, early, probe)
    local api = C_DamageMeter
    local types = Enum and Enum.DamageMeterType
    local current = Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current
    if not api or not types then
        row.status.meter = "unavailable"
        return
    end
    local sessionIDs = SessionIDs(row, api)
    if current ~= nil then Call(row, "meterCurrentDuration", api.GetSessionDurationSeconds, current) end
    local candidates = {}
    if window.baseline and sessionIDs then
        for candidate in pairs(sessionIDs) do
            if not window.baseline[candidate] then candidates[#candidates + 1] = candidate end
        end
    end
    table.sort(candidates)
    local id = #candidates == 1 and candidates[1] or nil
    row.newMeterSessionIDs = candidates
    row.meterSessionID = id
    row.meter, row.meterEvidence = nil, nil
    row.meterSelection = id and "new-archived" or "current-fallback"
    if evidence and window.previousPending then
        row.status.meterWindow = "previous-window-pending"
        evidence = nil
    end
    if #candidates > 1 or (window.archive and window.archive ~= id) then
        row.status.meter = "session-changed-or-ambiguous"
        return
    end
    window.archive = id
    local currentCount = window.currentUpdates.count or 0
    if not id and window.currentAtProbe and currentCount ~= window.currentAtProbe then
        row.status.meter = "current-changed"
        return
    end
    window.currentAtProbe = currentCount

    local selector = id or current
    local getter, sourceGetter = api.GetCombatSessionFromType, api.GetCombatSessionSourceFromType
    if id then getter, sourceGetter = api.GetCombatSessionFromID, api.GetCombatSessionSourceFromID end

    local scan, retry = {}, false
    local canQualify = evidence and window.baseline and sessionIDs
    if evidence and not window.baseline then row.status.meterWindow = "baseline-unreadable" end
    if evidence and not sessionIDs and finalAttempt then row.status.meterWindow = "session-list-unreadable" end
    local duration = row.uptime and window.startedUptime and row.uptime - window.startedUptime
    row.meter, row.meterEvidence = {}, {}
    for _, name in ipairs(meterCategories) do
        local meterType = types[name]
        local result = { status = {} }
        row.meter[name] = result
        if type(meterType) ~= "number" or selector == nil then
            result.status.session = "unavailable"
        else
            local session = ReadResult(result, "session", getter, selector, meterType)
            local sources
            if session then
                Capture(result, "duration", session.durationSeconds)
                Capture(result, "totalAmount", session.totalAmount)
                local readable, reason = AccessibleTable(session.combatSources)
                result.status.sources = readable and "readable" or reason
                if readable then sources = session.combatSources end
            end
            local status, accept
            if canQualify and name ~= "Deaths" then
                if not sources then
                    status = "sources-unreadable"
                    retry = retry or Retryable(result.status.sources or result.status.session)
                elseif not window.meterUpdates[(id or 0) .. ":" .. meterType] then
                    status, retry = "no-matching-update", true
                elseif not id and window.previousEnd and row.uptime and type(result.duration) == "number"
                    and row.uptime - result.duration <= window.previousEnd then
                    status = "current-overlaps-previous-window"
                elseif not duration or type(result.duration) ~= "number" or result.duration <= 0
                    or math.abs(result.duration - duration) > 2 then
                    accept = CorroboratedMeterPair(window, row, result.duration, id or 0, meterType, types, enemies, faction)
                    status = accept and "eligible-corroborated" or "duration-mismatch"
                    retry = retry or type(result.duration) ~= "number"
                else
                    status = "eligible"
                end
                row.meterEvidence[name] = status
            end
            if sources then scan[#scan + 1] = { name, meterType, result, sources, status == "eligible" or accept ~= nil, accept } end
        end
    end
    -- Wait once for late category updates or restricted tables before fetching
    -- source details. If details themselves are restricted, retry at most once.
    if evidence and not finalAttempt and not early and (retry or not sessionIDs) then return true end
    local linked = {}
    for _, entry in ipairs(scan) do
        local name, meterType, result, sources, eligible, accept = unpack(entry)
        local retrySource, actors = MeterSources(result, sources, function(source, guid, creature)
            return ReadResult(source, "detail", sourceGetter, selector, meterType, guid, creature)
        end, eligible and evidence, name, nil, accept, eligible and probe)
        retry = retry or retrySource
        if eligible then linked[name] = actors end
    end
    row.status.meter = "sampled"
    return evidence and not finalAttempt and retry, linked
end

local handlers = {}

local function RememberOwner(window, pet, owner)
    if type(pet) ~= "string" or not pet:match("^Pet%-.+") then return end
    local owners = window.petOwners[pet]
    if not owners then
        owners = {}
        window.petOwners[pet] = owners
        window.petCount = window.petCount + 1
        if window.petCount <= 32 then window.petSamples[pet] = owners end
    end
    owners[owner] = true
end

local function ReadIdentity(fn, ...)
    if type(fn) ~= "function" then return nil, "unavailable" end
    local ok, value = pcall(fn, ...)
    if not ok then return nil, "error" end
    return Value(value)
end

local function ReadPetOwner(unit, pet, probe)
    local before, beforeStatus = ReadIdentity(UnitGUID, unit)
    probe.petBefore = before and (before == pet and "matched" or "mismatch") or beforeStatus
    if before ~= pet then return end
    local owner, status = ReadIdentity(UnitOwnerGUID, unit)
    probe.ownerGUID = status
    local after, afterStatus = ReadIdentity(UnitGUID, unit)
    probe.petAfter = after and (after == pet and "matched" or "mismatch") or afterStatus
    if after ~= pet then return end
    if type(owner) == "string" and owner:match("^Player%-.+") then return owner end
    if owner then probe.ownerGUID = "non-player-or-invalid" end
end

local function CheckOwner(ownerUnit, owner, petUnit, pet)
    local owners = combat.petOwners[pet]
    if (owners and owners[owner]) or type(UnitIsOwnerOrControllerOfUnit) ~= "function" then return end
    if ReadIdentity(UnitGUID, ownerUnit) ~= owner or ReadIdentity(UnitGUID, petUnit) ~= pet then return end
    combat.petChecks = combat.petChecks + 1
    local ok, controls = pcall(UnitIsOwnerOrControllerOfUnit, ownerUnit, petUnit)
    if not ok then
        Count(combat.petSignals, "error")
    else
        local verdict, status = Value(controls)
        Count(combat.petSignals, status)
        if verdict == true and ReadIdentity(UnitGUID, ownerUnit) == owner and ReadIdentity(UnitGUID, petUnit) == pet then
            RememberOwner(combat, pet, owner)
        end
    end
end

local function Observe(unit, reason)
    if not combat or type(unit) ~= "string" then return end
    local isPlayer = ReadIdentity(UnitIsPlayer, unit)
    local guid, status = ReadIdentity(UnitGUID, unit)
    local oldPlayer, oldPet = combat.playerTokens[unit], combat.petTokens[unit]
    combat.playerTokens[unit], combat.petTokens[unit] = nil, nil
    if isPlayer == false then
        if type(guid) == "string" and guid:match("^Pet%-.+") then
            combat.petTokens[unit] = guid
            if oldPet ~= guid then
                local probe = {}
                local owner = ReadPetOwner(unit, guid, probe)
                if owner then RememberOwner(combat, guid, owner) end
                Count(combat.petSignals, "unit-owner-" .. (probe.ownerGUID or probe.petBefore))
                for ownerUnit, owner in pairs(combat.playerTokens) do CheckOwner(ownerUnit, owner, unit, guid) end
            end
        end
        return
    end
    if type(guid) ~= "string" or not guid:match("^Player%-.+") then
        if isPlayer or status == "secret" then
            local key = reason .. ":" .. status
            combat.unresolved[key] = (combat.unresolved[key] or 0) + 1
        end
        return
    end
    combat.playerTokens[unit] = guid
    if oldPlayer ~= guid then
        for petUnit, pet in pairs(combat.petTokens) do CheckOwner(unit, guid, petUnit, pet) end
    end
    local contact = combat.contacts[guid]
    if not contact then
        contact = {}
        combat.contacts[guid] = contact
        combat.contactCount = combat.contactCount + 1
        if combat.contactCount <= 32 then
            contact.changes, contact.signals = {}, {}
            combat.contactSamples[guid] = contact
        end
    end

    if contact.signals then Count(contact.signals, reason) end
    local now = Value(GetTime())
    if not now then return end
    contact.firstSeen = contact.firstSeen or now
    contact.lastSeen = now
    -- Flags can fire repeatedly. Keep meaningful changes and the latest sample.
    if reason == "flags" and now and contact.lastSample
        and now - contact.lastSample < 0.2 then return end
    contact.lastSample = now
    local unitState = Unit(unit)
    if unitState.guid ~= guid then return end
    if unitState.level then contact.level = unitState.level end
    unitState.uptime, unitState.token, unitState.reason = now, unit, reason
    Call(unitState, "targetGUID", UnitGUID, unit .. "target")
    local pet = PetToken(unit)
    if pet then
        Call(unitState, "petGUID", UnitGUID, pet)
        RememberOwner(combat, unitState.petGUID, guid)
    end
    Call(unitState, "inCombat", UnitAffectingCombat, unit)
    Call(unitState, "dead", UnitIsDeadOrGhost, unit)
    Call(unitState, "feign", UnitIsFeignDeath, unit)
    if Value(UnitGUID(unit)) ~= guid then return end
    if type(unitState.dead) == "boolean" and (not unitState.dead or unitState.feign == false) then
        local life = contact.life or {}
        if not life[#life] or life[#life].dead ~= unitState.dead then
            life[#life + 1] = { dead = unitState.dead, uptime = now, time = Value(GetServerTime()), source = reason }
            contact.life = life
        end
    end
    Call(unitState, "pvp", UnitIsPVP, unit)
    Capture(unitState, "race", Call(unitState, "raceName", UnitRace, unit))
    Call(unitState, "sex", UnitSex, unit)

    local previous = contact.latest
    contact.latest = unitState
    if combat.primary and not combat.areaChanged and (not previous or previous.dead ~= unitState.dead
        or previous.inCombat ~= unitState.inCombat or previous.feign ~= unitState.feign
        or previous.status.dead ~= unitState.status.dead or previous.status.inCombat ~= unitState.status.inCombat
        or previous.status.feign ~= unitState.status.feign) then
        addon.ObserveCombatState(combat.primary, unitState)
    end
    if contact.changes and previous and (previous.targetGUID ~= unitState.targetGUID or previous.petGUID ~= unitState.petGUID
        or previous.dead ~= unitState.dead or previous.inCombat ~= unitState.inCombat
        or previous.pvp ~= unitState.pvp or previous.name ~= unitState.name
        or previous.status.targetGUID ~= unitState.status.targetGUID) then
        if #contact.changes < 8 then
            contact.changes[#contact.changes + 1] = previous
        else
            contact.changeOverflow = (contact.changeOverflow or 0) + 1
        end
    end
end

local function ObserveGroup(row, reason)
    local prefix = row.inRaid and "raid" or "party"
    local count = (row.inRaid and row.groupSize or row.subgroupSize)
    if type(count) ~= "number" then return end
    for index = 1, count do Observe(prefix .. index, reason) end
end

local function ObserveCurrent(row, reason)
    Observe("player", reason)
    ObserveGroup(row, reason)
    Observe("target", reason)
    Observe("mouseover", reason)
    for token in pairs(plateTokens) do Observe(token, reason) end
end

function handlers.PLAYER_REGEN_DISABLED()
    passive = nil
    local previousPending = settling ~= nil
    settling = nil
    combatSequence = combatSequence + 1
    local row = Add("COMBAT_START")
    Sample(row)
    CopyGroup(row)
    local baseline = C_DamageMeter and SessionIDs(row, C_DamageMeter)
    combat = {
        baseline = baseline, contacts = {}, contactSamples = {}, unresolved = {}, previousPending = previousPending,
        startedAt = row.time, startedUptime = row.uptime, startInstanceType = row.instanceType, previousEnd = lastCombatEnd,
        startInstanceMapID = row.instanceMapID,
        auraUpdates = {}, auraSignals = {}, currentUpdates = {},
        petOwners = {}, petSamples = {}, petCount = 0, petChecks = 0, petSignals = {},
        playerTokens = {}, petTokens = {}, contactCount = 0, meterUpdates = {}, meterUpdateCount = 0,
        groupChanges = {}, groupChangeCount = 0, restrictedKills = 0,
    }
    if addon.NewCombatDiagnostics and addon.RecordingPvPOrigin() then
        combat.primary = addon.NewCombatDiagnostics(row.uptime, row.time, diagnosticBuild, diagnosticRegistration)
        local world = addon.WorldCombatWindow and addon.WorldCombatWindow(row.uptime)
        if world then addon.BindCombatDiagnostics(world, combat.primary) end
    end
    ObserveCurrent(row, "combat-start")
end

local function CombatRestricted(row)
    if Value(InCombatLockdown and InCombatLockdown()) ~= false then return true end
    local api = C_RestrictedActions and C_RestrictedActions.GetAddOnRestrictionState
    local combatType = Enum and Enum.AddOnRestrictionType and Enum.AddOnRestrictionType.Combat
    local inactive = Enum and Enum.AddOnRestrictionState and Enum.AddOnRestrictionState.Inactive
    if type(api) ~= "function" or combatType == nil or inactive == nil then return false end
    Call(row, "meterCombatRestriction", api, combatType)
    return row.meterCombatRestriction ~= inactive
end

local function BeginPassiveMeter(window, row, finished, evidence, reached)
    if not addon.WorldCanObserveMeter(window) then return end
    local ids = {}
    for entry in pairs(reached) do ids[entry.guid] = true end
    local categories = {}
    local types = Enum.DamageMeterType
    for name, totals in pairs(evidence.damage) do
        local pairsInBattle = {}
        for key, pair in pairs(totals) do
            if ids[pair.actorID] and ids[pair.targetID] then pairsInBattle[key] = pair end
        end
        if next(pairsInBattle) then
            categories[types[name]] = { name = name, totals = pairsInBattle, duration = row.meter[name].duration }
        end
    end
    if next(categories) then
        passive = { window = window, session = row.meterSessionID or 0, contacts = finished.contacts,
            owners = finished.petOwners, faction = row.player.faction, categories = categories }
        addon.WorldMeterObservation(window, "baseline-ready")
    else
        addon.WorldMeterObservation(window, "no-comparable-baseline")
    end
end

local function ReadPassiveMeter(watch, dirty)
    if passive ~= watch or combat or settling or not addon.WorldCanObserveMeter(watch.window) then return end
    local row = Add("POST_COMBAT_METER_UPDATE")
    Call(row, "playerDead", UnitIsDeadOrGhost, "player")
    Call(row, "playerGhost", UnitIsGhost, "player")
    row.meterSessionID = watch.session
    row.categories = {}
    local function Observe(status, signal, category, increase)
        if watch.window.combatDiagnostic then
            addon.RecordCombatMeterFollowup(watch.window.combatDiagnostic, row, signal, category, increase)
        end
        addon.WorldMeterObservation(watch.window, status, signal and signal.actorID, signal and signal.targetID)
    end
    if CombatRestricted(row) then
        row.status.meter = "restricted"
        Observe("restricted")
        return
    end

    local api = C_DamageMeter
    if not api then return end
    local getter, sourceGetter, selector = api.GetCombatSessionFromID, api.GetCombatSessionSourceFromID, watch.session
    if selector == 0 then
        getter, sourceGetter = api.GetCombatSessionFromType, api.GetCombatSessionSourceFromType
        selector = Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current
        if selector == nil then return end
    else
        local ids = SessionIDs(row, api)
        if not ids or not ids[selector] then
            row.status.meter = "archive-unavailable"
            Observe("archive-unavailable")
            passive = nil
            return
        end
    end

    local signal, signalCategory, signalIncrease
    local verdict = "unchanged"
    for kind in pairs(dirty) do
        local baseline = watch.categories[kind]
        local result = { status = {} }
        local session = ReadResult(result, "session", getter, selector, kind)
        if not session then
            result.status.delta = result.status.session
        else
            local duration = Value(session.durationSeconds)
            local sources = session.combatSources
            local readable, reason = AccessibleTable(sources)
            if type(duration) ~= "number" or duration < baseline.duration then
                result.status.delta = "duration-unverified"
            elseif not readable then
                result.status.delta = reason
            else
                local evidence = addon.NewMeterParticipantEvidence(watch.contacts, watch.owners, watch.faction)
                MeterSources(result, sources, function(source, guid, creature)
                    return ReadResult(source, "detail", sourceGetter, selector, kind, guid, creature)
                end, evidence, baseline.name, 0)
                local totals = evidence.damage[baseline.name] or {}
                local trustworthy, changed, increase = true, nil, nil
                for key, previous in pairs(baseline.totals) do
                    local current = totals[key]
                    if not current or current.amount < previous.amount then
                        trustworthy = false
                        break
                    elseif current.amount > previous.amount then
                        changed = current
                        increase = current.amount - previous.amount
                    end
                end
                if trustworthy then
                    baseline.duration = duration
                    for key in pairs(baseline.totals) do baseline.totals[key] = totals[key] end
                    if changed then signal, signalCategory, signalIncrease = changed, baseline.name, increase end
                    result.status.delta = changed and "linked-increase" or "unchanged"
                else
                    result.status.delta = "baseline-not-comparable"
                end
            end
        end
        row.categories[baseline.name] = result.status.delta
        if result.status.delta ~= "unchanged" then verdict = result.status.delta end
    end
    row.status.meter = signal and "linked-increase" or verdict
    Observe(row.status.meter, signal, signalCategory, signalIncrease)
end

local function QueuePassiveMeter(kind, id)
    local watch = passive
    if not watch or id ~= watch.session or not watch.categories[kind] or not C_Timer or not C_Timer.After
        or not addon.WorldCanObserveMeter(watch.window) then return end
    if watch.dirty then
        watch.dirty[kind] = true
        return
    end
    watch.dirty = { [kind] = true }
    local now = GetTime()
    local delay = math.max(0.4, (watch.nextRead or now) - now)
    C_Timer.After(delay, function()
        local dirty = watch.dirty
        watch.dirty = nil
        watch.nextRead = GetTime() + 1
        ReadPassiveMeter(watch, dirty)
    end)
end

function handlers.PLAYER_REGEN_ENABLED()
    if not combat then return end
    local row = Add("COMBAT_END")
    Sample(row)
    CopyGroup(row)
    ObserveCurrent(row, "combat-end")
    local finished = combat
    lastCombatEnd = row.uptime
    if addon.WorldCombatWindow then
        finished.worldWindow = addon.WorldCombatWindow(finished.startedUptime)
        addon.SnapshotWorldContacts(finished.worldWindow, finished.contacts)
    end
    if finished.primary then
        if not finished.areaChanged then addon.EndCombatDiagnostics(finished.primary, "combat-end") end
        addon.BindCombatDiagnostics(finished.worldWindow, finished.primary)
    end
    combat, settling = nil, finished
    row.pvpReasons = finished.reasons
    row.contacts, row.unresolvedContacts = {}, finished.unresolved
    for guid, contact in pairs(finished.contactSamples) do
        row.contacts[guid] = { firstSeen = contact.firstSeen, lastSeen = contact.lastSeen, latest = contact.latest,
            changes = contact.changes, changeOverflow = contact.changeOverflow, signals = contact.signals }
    end
    row.contactCount, row.contactOverflow = finished.contactCount, math.max(0, finished.contactCount - 32)
    row.groupChanges, row.groupChangeCount = finished.groupChanges, finished.groupChangeCount
    row.meterCurrentUpdates = finished.currentUpdates
    row.auraUpdates, row.auraSignals = finished.auraUpdates, finished.auraSignals
    row.petOwners, row.petChecks, row.petSignals = finished.petSamples, finished.petChecks, finished.petSignals
    row.petOwnerCount = finished.petCount
    row.restrictedPartyKills = finished.restrictedKills
    local rows = db.rows
    local function AttachReport()
        row.pvpReasons = finished.reasons
        if finished.primary then
            finished.primary.window.meterStatus = row.status.meter
            finished.primary.window.meterWindow = row.status.meterWindow
            finished.primary.window.meterInterruption = row.status.meterInterruption
        end
        if finished.worldWindow and addon.ReportMeterSnapshot then
            finished.worldWindow.segment.reportMeter = addon.ReportMeterSnapshot(row)
        end
    end
    AttachReport()
    local function ReadMeter(finalAttempt)
        if rows ~= db.rows then return end
        local sameWindow = settling == finished
        row.meterUpdateCount = finished.meterUpdateCount
        row.meterReset, row.areaChanged = finished.meterReset, finished.areaChanged
        if not sameWindow or finished.areaChanged or finished.meterReset then
            if sameWindow then settling = nil end
            row.status.meter = "interrupted"
            row.status.meterInterruption = finished.areaChanged and "area-changed"
                or finished.meterReset and "meter-reset" or "superseded"
            AttachReport()
            return
        end
        row.meterAttempts = (row.meterAttempts or 0) + 1
        if CombatRestricted(row) then
            row.meterRestrictionWaits = (row.meterRestrictionWaits or 0) + 1
            if not finalAttempt then
                C_Timer.After(1, function() ReadMeter(true) end)
            else
                settling = nil
                row.status.meter = "combat-restricted"
                AttachReport()
            end
            return
        end

        local context, anchors, faction, enemies
        if addon.WorldMeterContext and row.instanceType == finished.startInstanceType then
            context, anchors, faction, enemies = addon.WorldMeterContext(finished.worldWindow, row)
        end
        if finished.context and context ~= finished.context then
            settling = nil
            row.status.meter = "journal-context-changed"
            AttachReport()
            return
        end
        finished.context = context
        if not context and not row.status.meterWindow then row.status.meterWindow = "no-eligible-world-record" end
        local evidence = context and addon.NewMeterParticipantEvidence(finished.contacts, finished.petOwners, faction, context.self)
        local early = context and not context.record
        local probe = finished.primary and evidence and addon.NewCombatMeterProbe()
        local retry, linked = CaptureMeter(row, finished, evidence, finalAttempt, enemies, faction, early, probe)
        local additions, reached, links
        if evidence and linked and next(linked) then
            additions, reached = evidence:Connected(anchors)
            links = evidence:HostileLinks(reached)
        end
        -- Commit usable evidence before the next combat can replace Current.
        -- A read with incomplete details still gets the existing bounded retry.
        if retry and (not early or not links or #links == 0) then
            C_Timer.After(1, function() ReadMeter(true) end)
            return
        end
        settling = nil
        -- A superseded or interrupted attempt leaves only the existing status summary.
        if probe then addon.CommitCombatMeterProbe(finished.primary, probe, row.meterSessionID, row.meterSelection) end

        row.meterUpdates = {}
        local types = Enum and Enum.DamageMeterType
        for _, name in ipairs(meterCategories) do
            local kind = types and types[name]
            if type(kind) == "number" then
                local current = "0:" .. kind
                local archived = (row.meterSessionID or 0) .. ":" .. kind
                row.meterUpdates[current], row.meterUpdates[archived] = finished.meterUpdates[current], finished.meterUpdates[archived]
            end
        end
        if additions then
            for name, actors in pairs(linked) do
                local counts = row.meter[name].resolution
                for actor in pairs(actors) do
                    Count(counts, reached[actor] and "source-connected" or "source-disconnected")
                end
            end
            addon.ApplyWorldMeterEvidence(context, additions, faction, row, links, finished.contacts, probe,
                evidence:ContributionLinks(reached), evidence.localNpcDamage)
            addon.SnapshotWorldContacts(context, finished.contacts)
            BeginPassiveMeter(context, row, finished, evidence, reached)
        end
        if context then
            addon.ResolveStagedWorldKills(context, finished.contacts)
            if not context.record and not row.status.meterWindow then row.status.meterWindow = "no-linked-pvp" end
        end
        AttachReport()
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.5, function() ReadMeter(false) end) else ReadMeter(true) end
end

function handlers.PLAYER_TARGET_CHANGED() Observe("target", "target") end
function handlers.UPDATE_MOUSEOVER_UNIT() Observe("mouseover", "mouseover") end

function handlers.NAME_PLATE_UNIT_ADDED(unit)
    unit = Value(unit)
    if type(unit) ~= "string" then return end
    plateTokens[unit] = true
    Observe(unit, "nameplate-added")
end

function handlers.NAME_PLATE_UNIT_REMOVED(unit)
    unit = Value(unit)
    if type(unit) ~= "string" then return end
    Observe(unit, "nameplate-removed")
    plateTokens[unit] = nil
    if combat then combat.playerTokens[unit], combat.petTokens[unit] = nil, nil end
end

local function IsTracked(unit)
    return type(unit) == "string" and (plateTokens[unit] or unit == "target" or unit == "mouseover"
        or unit == "player" or unit:match("^party%d+$") or unit:match("^raid%d+$"))
end

local function DiagnosticUnit(unit)
    if not combat or not combat.primary or combat.areaChanged then return end
    unit = Value(unit)
    if IsTracked(unit) then return combat.primary, unit end
end

if addon.CombatCastDiagnosticsEvents then
    function handlers.UNIT_COMBAT(unit, effect, flag, amount, school)
        local capture, token = DiagnosticUnit(unit)
        if capture then addon.ObserveCombatFeedback(capture, token, effect, flag, amount, school) end
    end
    for name in addon.CombatCastDiagnosticsEvents() do
        local event = name
        handlers[event] = function(unit, castGUID, spellID, interruptedBy)
            local capture, token = DiagnosticUnit(unit)
            if capture then addon.ObserveCombatCast(capture, event, token, castGUID, spellID, interruptedBy) end
        end
    end
end

local auraFields = { "auraInstanceID", "spellId", "sourceUnit", "isHelpful", "isHarmful" }

function handlers.UNIT_AURA(unit, update)
    local capture, token = DiagnosticUnit(unit)
    if capture then addon.ObserveCombatAuras(capture, token, update) end
    unit = Value(unit)
    if not combat or combat.startInstanceType ~= "none" or not IsTracked(unit) then return end
    local stats = combat.auraSignals
    stats.count = (stats.count or 0) + 1
    local readable, reason = AccessibleTable(update)
    if not readable then
        stats[reason] = (stats[reason] or 0) + 1
        return
    end
    if Value(update.isFullUpdate) == true then
        stats.full = (stats.full or 0) + 1
        return
    end
    local auras = update.addedAuras
    readable, reason = AccessibleTable(auras)
    if not readable then
        stats["added:" .. reason] = (stats["added:" .. reason] or 0) + 1
        return
    end
    local rows = combat.auraUpdates
    local count = math.min(#auras, 20 - #rows)
    stats.omitted = (stats.omitted or 0) + (#auras - count)
    for index = 1, count do
        local aura = CopyRow(auras[index], auraFields)
        aura.uptime = Value(GetTime())
        aura.token = unit
        Call(aura, "targetGUID", UnitGUID, unit)
        if type(aura.sourceUnit) == "string" then
            Call(aura, "sourceGUID", UnitGUID, aura.sourceUnit)
            if type(aura.sourceGUID) == "string" and aura.sourceGUID:match("^Pet%-.+") then Observe(aura.sourceUnit, "aura-source") end
        end
        rows[#rows + 1] = aura
    end
end

function handlers.UNIT_FLAGS(unit)
    unit = Value(unit)
    if combat and IsTracked(unit) then Observe(unit, "flags") end
end

function handlers.UNIT_TARGET(unit)
    unit = Value(unit)
    if combat and IsTracked(unit) then Observe(unit, "unit-target") end
end

function handlers.UNIT_PET(unit)
    unit = Value(unit)
    if combat and IsTracked(unit) then Observe(unit, "pet") end
end

function handlers.GROUP_ROSTER_UPDATE()
    if not combat then return end
    combat.groupChangeCount = combat.groupChangeCount + 1
    local row = { status = {}, uptime = Value(GetTime()) }
    CopyGroup(row)
    ObserveGroup(row, "group")
    if #combat.groupChanges < 6 then combat.groupChanges[#combat.groupChanges + 1] = row end
end

function handlers.DAMAGE_METER_COMBAT_SESSION_UPDATED(meterType, sessionID)
    local window = combat or settling
    if window then window.meterUpdateCount = window.meterUpdateCount + 1 end
    local id, kind = Value(sessionID), Value(meterType)
    if type(id) ~= "number" or type(kind) ~= "number" then return end
    if not window then
        QueuePassiveMeter(kind, id)
        return
    end
    local key = id .. ":" .. kind
    local signal = window.meterUpdates[key]
    if not signal then
        signal = { sessionID = id, meterType = kind, count = 0 }
        window.meterUpdates[key] = signal
    end
    signal.count = signal.count + 1
    signal.uptime = Value(GetTime())
    signal.firstUptime = signal.firstUptime or signal.uptime
end

function handlers.DAMAGE_METER_CURRENT_SESSION_UPDATED()
    if passive and passive.session == 0 then
        addon.WorldMeterObservation(passive.window, "current-changed")
        passive = nil
    end
    local window = combat or settling
    if not window then return end
    local signal = window.currentUpdates
    signal.count = (signal.count or 0) + 1
    signal.uptime = Value(GetTime())
    signal.firstUptime = signal.firstUptime or signal.uptime
end

function handlers.DAMAGE_METER_RESET()
    if passive then
        addon.WorldMeterObservation(passive.window, "reset")
        passive = nil
    end
    local window = combat or settling
    if window then window.meterReset = true end
end

local function AreaChanged(event)
    passive, lastCombatEnd = nil, nil
    if combat and combat.primary and not combat.areaChanged then addon.EndCombatDiagnostics(combat.primary, "area-changed") end
    local window = combat or settling
    if window then window.areaChanged = true end
    if combat then Sample(Add(event)) end
end

local function CompatibleCombatScope(window)
    local _, instanceType = IsInInstance()
    if window.startInstanceType ~= Value(instanceType) then return false end
    local map = window.startInstanceMapID and addon.BattlegroundMapID()
    return not map or window.startInstanceMapID == map
end

function handlers.ZONE_CHANGED_NEW_AREA()
    local window = combat or settling
    if (window and not CompatibleCombatScope(window))
        or (passive and not addon.WorldCanObserveMeter(passive.window)) then
        AreaChanged("ZONE_CHANGED_NEW_AREA")
    end
end
function handlers.PLAYER_LEAVING_WORLD() AreaChanged("PLAYER_LEAVING_WORLD") end

local function LifeState(event)
    local row = Add(event)
    Sample(row)
    Call(row.player, "dead", UnitIsDeadOrGhost, "player")
    Call(row.player, "ghost", UnitIsGhost, "player")
    row.meterObservation = passive and "baseline-ready" or "no-comparable-baseline"
    if passive then row.meterSessionID = passive.session end
    if combat then Observe("player", event) end
    return row
end

function handlers.PLAYER_ALIVE() LifeState("PLAYER_ALIVE") end
function handlers.PLAYER_UNGHOST() LifeState("PLAYER_UNGHOST") end

function handlers.PLAYER_DEAD()
    deathSequence = deathSequence + 1
    local sequence = deathSequence
    local row = LifeState("PLAYER_DEAD")
    row.deathSequence = sequence
    Recap(sequence, 0)
    if C_Timer and C_Timer.After then
        for _, delay in ipairs({ 0.3, 1, 2 }) do
            C_Timer.After(delay, function() Recap(sequence, delay) end)
        end
    end
end

function handlers.PARTY_KILL(attacker, victim)
    local guid = Value(victim)
    if type(guid) == "string" and (guid:match("^Creature%-") or guid:match("^Vehicle%-")
        or guid:match("^Pet%-")) then
        return
    end
    if combat and combat.primary and not combat.areaChanged then addon.ObserveCombatPartyKill(combat.primary, attacker, victim) end
    if combat and not guid and not Value(attacker) then
        combat.restrictedKills = combat.restrictedKills + 1
        if combat.restrictedKills > 8 then return end
    end
    local row = Add("PARTY_KILL")
    Capture(row, "attacker", attacker)
    Capture(row, "victim", victim)
    Sample(row)
    row.pet = Unit("pet")
    CopyGroup(row)
end

function handlers.PLAYER_PVP_KILLS_CHANGED(unit)
    local row = Add("PLAYER_PVP_KILLS_CHANGED")
    Capture(row, "unit", unit)
    Sample(row)
end

function handlers.CHAT_MSG_COMBAT_HONOR_GAIN(message, sender, _, _, _, _, _, _, _, _, lineID, chatGUID)
    local row = Add("CHAT_MSG_COMBAT_HONOR_GAIN")
    Capture(row, "message", message)
    Capture(row, "lineID", lineID)
    Capture(row, "chatSender", sender)
    Capture(row, "chatGUID", chatGUID)
    Sample(row)
end

function handlers.PVP_MATCH_COMPLETE()
    Sample(Add("PVP_MATCH_COMPLETE"))
end

local function CurrentContactWindow()
    local window = combat or settling
    if not window or window.areaChanged or not CompatibleCombatScope(window) then return end
    if combat ~= window and (not lastCombatEnd or GetTime() - lastCombatEnd > 2.5) then return end
    return window
end

function addon.ReadCombatContact(guid)
    local window = CurrentContactWindow()
    if window then
        local contact = window.contacts[guid]
        return contact and contact.latest, window.startedUptime
    end
end

function addon.ActiveCombatContacts()
    local window = CurrentContactWindow()
    local result = {}
    for guid, contact in pairs(window and window.contacts or {}) do
        if contact.latest and contact.latest.guid == guid then
            result[guid] = contact.level
        end
    end
    return result
end

function addon.CombatRecapPetOwner(worldWindow, pet, probe)
    if not addon.WorldCanResolveRecapPet(worldWindow) then
        probe.decision = "scope-unavailable"
        return
    end
    local window = CurrentContactWindow()
    if window and (window.worldWindow or addon.WorldCombatWindow(window.startedUptime)) ~= worldWindow then window = nil end
    local scoped = window and addon.UniqueCombatPetOwner(window.petOwners[pet])
    local token, tokenStatus = ReadIdentity(UnitTokenFromGUID, pet)
    probe.petToken = tokenStatus
    probe.tokenSource = type(token) == "string" and token ~= "" and "guid-lookup" or nil
    if not probe.tokenSource and window then
        for unit, observed in pairs(window.petTokens) do
            if observed == pet and ReadIdentity(UnitGUID, unit) == pet then
                token, probe.tokenSource = unit, "window-observation"
                break
            end
        end
    end
    local direct
    if type(token) == "string" and token ~= "" then
        direct = ReadPetOwner(token, pet, probe)
    end
    if window and direct then RememberOwner(window, pet, direct) end
    if scoped == false or (scoped and direct and scoped ~= direct) then
        probe.decision = "ambiguous-owner"
        return
    end
    local owner = direct or scoped
    if not owner then
        probe.decision = "unresolved-owner"
        return
    end
    local contact = window and window.contacts[owner]
    local player = contact and contact.latest
    if not player and direct then
        local ownerToken, status = ReadIdentity(UnitTokenFromGUID, owner)
        probe.ownerToken = status
        if type(ownerToken) == "string" and ownerToken ~= "" then
            player = Unit(ownerToken)
            if ReadIdentity(UnitGUID, ownerToken) ~= owner then player = nil end
        end
    end
    if player and player.guid == owner and player.isPlayer == true and player.opponent == true then
        probe.decision = direct and "unit-owner-guid" or "scoped-observation"
        return owner, player
    end
    probe.decision = "unverified-opponent"
end

function addon.NotePvPDiagnostic(reason)
    if not db then return end
    local window = CurrentContactWindow()
    if window then
        window.reasons = window.reasons or {}
        Count(window.reasons, reason)
    else
        local row = Add("PVP_DECISION")
        row.reason = reason
    end
end

function addon.CancelDiagnosticCombat()
    combat, settling, passive, lastCombatEnd = nil, nil, nil, nil
    deathSequence = deathSequence + 1
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event ~= "ADDON_LOADED" then
        if addon.IsBattlegroundTrackingEnabled and not addon.IsBattlegroundTrackingEnabled() then
            local _, instanceType = IsInInstance()
            if Value(instanceType) == "pvp" then return end
        end
        handlers[event](...)
        return
    end
    if ... ~= addonName then
        return
    end
    self:UnregisterEvent(event)

    if NamesInRedDebugDB == nil then
        NamesInRedDebugDB = { version = 1, session = 0, dropped = 0, rows = {} }
    end
    local saved = NamesInRedDebugDB
    if type(saved) ~= "table" or saved.version ~= 1 or type(saved.rows) ~= "table"
        or type(saved.session) ~= "number" or type(saved.dropped) ~= "number" then
        return
    end
    db = saved
    db.session = db.session + 1
    local row = Add("SESSION")
    local _, build, _, interface = GetBuildInfo()
    Capture(row, "build", build)
    Capture(row, "interface", interface)
    Call(row, "locale", GetLocale)
    Call(row, "addonVersion", C_AddOns and C_AddOns.GetAddOnMetadata, addonName, "Version")
    Sample(row)
    row.registration = {}
    for name in pairs(handlers) do
        local ok, registered = pcall(self.RegisterEvent, self, name)
        row.registration[name] = ok and registered ~= false and "registered" or "unavailable"
    end

    SLASH_NAMESINREDDEBUG1 = "/nirdebug"
    diagnosticRegistration, diagnosticBuild = row.registration, row.build
    SlashCmdList.NAMESINREDDEBUG = function(message)
        local faction = message:lower():match("^faction%s+(%a+)%s*$")
        local demoFaction = faction and demoFactions[faction]
        local seed = message == "seed" or demoFaction ~= nil or faction == "auto"
        if seed or message == "clear-seed" then
            if not addon.db then return end
            local update = addon[seed and "AddDebugSeeds" or "ClearDebugSeeds"]
            if type(update) ~= "function" then return end
            local count = update(seed and GetServerTime() or nil, demoFaction)
            if addon.RefreshBook then addon.RefreshBook(seed) end
            print(addon.title, (seed and L.debugSeedsAdded or L.debugSeedsRemoved):format(count))
            return
        end
        if message == "sample" then
            Sample(Add("MANUAL_SAMPLE"))
        end
        print(addon.title, L.debugStatus:format(#db.rows, db.dropped, db.session))
    end
end)
