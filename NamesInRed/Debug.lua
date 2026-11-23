local addonName, addon = ...
local L = addon.L
local frame = CreateFrame("Frame")
local db
local deathSequence = 0
local combatSequence = 0
local combat, settling
local limit = 1000
local plateTokens = {}
local demoFactions = { alliance = "Alliance", horde = "Horde" }

local function ClearDiagnostics()
    if not db then
        NamesInRedDebugDB = nil
        return
    end
    db.rows, db.dropped = {}, 0
    deathSequence = deathSequence + 1
    combatSequence, combat, settling = 0, nil, nil
end

local function ReadDeathLevel(row, victim, attacker)
    if not row.player or row.player.guid ~= victim then return end
    local player = row.contacts[victim] and row.contacts[victim].latest
    local rival = row.contacts[attacker] and row.contacts[attacker].latest
    if player and player.guid == victim and player.dead == true
        and rival and rival.guid == attacker and type(rival.level) == "number" and rival.level > 0 then
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
local sourceKeyFields = { "sourceGUID", "sourceCreatureID" }
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

local function SpellTargets(entry, sample, actor, category, evidence, counts, scratch)
    local details = entry.combatSpellDetails
    local readable, reason = AccessibleTable(details)
    if not readable then
        if sample then sample.detailStatus = reason end
        if actor then Count(counts, "details-" .. reason) end
        return actor and Retryable(reason)
    end
    if next(details) == nil then
        if sample then sample.detailStatus = "empty" end
        if actor then Count(counts, "details-empty") end
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
            local resolution = evidence:Link(category, actor, target)
            Count(counts, resolution)
            retry = retry or resolution:match("%-secret$") ~= nil or resolution == "detail-restricted-table"
        end
    end
    return retry
end

local function MeterSources(result, sources, readSource, evidence, category)
    local counts, linkedActors = {}, {}
    result.sourceCount = #sources
    result.sources = {}
    if evidence then result.resolution = counts end
    local sourceScratch, targetScratch = { status = {} }, { status = {} }
    local retry = false
    for index = 1, evidence and #sources or math.min(#sources, 12) do
        local retain = index <= 12
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
                            local retryTarget = SpellTargets(entry, sample, actor, category, evidence, counts, targetScratch)
                            retry = retry or retryTarget
                        elseif actor then
                            Count(counts, "spell-" .. reason)
                            retry = retry or Retryable(reason)
                        end
                    end
                    if actor and counts.link ~= previousLinks then linkedActors[actor] = true end
                elseif actor then
                    local reason = detail and why or source.status.detail
                    Count(counts, "spells-" .. reason)
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

local function CaptureMeter(row, window, evidence, finalAttempt)
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
            local status
            if canQualify and name ~= "Deaths" then
                if not sources then
                    status = "sources-unreadable"
                    retry = retry or Retryable(result.status.sources or result.status.session)
                elseif not window.meterUpdates[(id or 0) .. ":" .. meterType] then
                    status, retry = "no-matching-update", true
                elseif not duration or type(result.duration) ~= "number" or result.duration <= 0
                    or math.abs(result.duration - duration) > 2 then
                    status = "duration-mismatch"
                    retry = retry or type(result.duration) ~= "number"
                else
                    status = "eligible"
                end
                row.meterEvidence[name] = status
            end
            if sources then scan[#scan + 1] = { name, meterType, result, sources, status == "eligible" } end
        end
    end
    -- Wait once for late category updates or restricted tables before fetching
    -- source details. If details themselves are restricted, retry at most once.
    if evidence and not finalAttempt and (retry or not sessionIDs) then return true end
    local linked = {}
    for _, entry in ipairs(scan) do
        local name, meterType, result, sources, eligible = unpack(entry)
        local retrySource, actors = MeterSources(result, sources, function(source, guid, creature)
            return ReadResult(source, "detail", sourceGetter, selector, meterType, guid, creature)
        end, eligible and evidence, name)
        retry = retry or retrySource
        if eligible then linked[name] = actors end
    end
    row.status.meter = "sampled"
    return evidence and not finalAttempt and retry, linked
end

local handlers = {}

local function RememberOwner(pet, owner)
    if type(pet) ~= "string" or not pet:match("^Pet%-.+") then return end
    local owners = combat.petOwners[pet]
    if not owners then
        owners = {}
        combat.petOwners[pet] = owners
        combat.petCount = combat.petCount + 1
        if combat.petCount <= 32 then combat.petSamples[pet] = owners end
    end
    owners[owner] = true
end

local function CheckOwner(ownerUnit, owner, petUnit, pet)
    local owners = combat.petOwners[pet]
    if (owners and owners[owner]) or type(UnitIsOwnerOrControllerOfUnit) ~= "function" then return end
    if Value(UnitGUID(ownerUnit)) ~= owner or Value(UnitGUID(petUnit)) ~= pet then return end
    combat.petChecks = combat.petChecks + 1
    local ok, controls = pcall(UnitIsOwnerOrControllerOfUnit, ownerUnit, petUnit)
    if not ok then
        Count(combat.petSignals, "error")
    else
        local verdict, status = Value(controls)
        Count(combat.petSignals, status)
        if verdict == true then RememberOwner(pet, owner) end
    end
end

local function Observe(unit, reason)
    if not combat or type(unit) ~= "string" then return end
    local isPlayer = Value(UnitIsPlayer and UnitIsPlayer(unit))
    local guid, status = Value(UnitGUID and UnitGUID(unit))
    local oldPlayer, oldPet = combat.playerTokens[unit], combat.petTokens[unit]
    combat.playerTokens[unit], combat.petTokens[unit] = nil, nil
    if isPlayer == false then
        if type(guid) == "string" and guid:match("^Pet%-.+") then
            combat.petTokens[unit] = guid
            if oldPet ~= guid then
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
    contact.firstSeen = contact.firstSeen or now
    contact.lastSeen = now
    -- Flags can fire repeatedly. Keep meaningful changes and the latest sample.
    if reason == "flags" and now and contact.lastSample
        and now - contact.lastSample < 0.2 then return end
    contact.lastSample = now
    local unitState = Unit(unit)
    unitState.uptime, unitState.token, unitState.reason = now, unit, reason
    Call(unitState, "targetGUID", UnitGUID, unit .. "target")
    local pet = PetToken(unit)
    if pet then
        Call(unitState, "petGUID", UnitGUID, pet)
        RememberOwner(unitState.petGUID, guid)
    end
    Call(unitState, "inCombat", UnitAffectingCombat, unit)
    Call(unitState, "dead", UnitIsDeadOrGhost, unit)
    Call(unitState, "pvp", UnitIsPVP, unit)
    Capture(unitState, "race", Call(unitState, "raceName", UnitRace, unit))
    Call(unitState, "sex", UnitSex, unit)

    local previous = contact.latest
    contact.latest = unitState
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
    local previousPending = settling ~= nil
    settling = nil
    combatSequence = combatSequence + 1
    local row = Add("COMBAT_START")
    Sample(row)
    CopyGroup(row)
    local baseline = C_DamageMeter and SessionIDs(row, C_DamageMeter)
    combat = {
        baseline = baseline, contacts = {}, contactSamples = {}, unresolved = {}, previousPending = previousPending,
        startedAt = row.time, startedUptime = row.uptime, startZone = row.zone, startInstanceType = row.instanceType,
        auraUpdates = {}, auraSignals = {}, currentUpdates = {},
        petOwners = {}, petSamples = {}, petCount = 0, petChecks = 0, petSignals = {},
        playerTokens = {}, petTokens = {}, contactCount = 0, meterUpdates = {}, meterUpdateCount = 0,
        groupChanges = {}, groupChangeCount = 0, restrictedKills = 0,
    }
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

function handlers.PLAYER_REGEN_ENABLED()
    if not combat then return end
    local row = Add("COMBAT_END")
    Sample(row)
    CopyGroup(row)
    ObserveCurrent(row, "combat-end")
    local finished = combat
    combat, settling = nil, finished
    row.contacts, row.unresolvedContacts = finished.contactSamples, finished.unresolved
    row.contactCount, row.contactOverflow = finished.contactCount, math.max(0, finished.contactCount - 32)
    row.groupChanges, row.groupChangeCount = finished.groupChanges, finished.groupChangeCount
    row.meterCurrentUpdates = finished.currentUpdates
    row.auraUpdates, row.auraSignals = finished.auraUpdates, finished.auraSignals
    row.petOwners, row.petChecks, row.petSignals = finished.petSamples, finished.petChecks, finished.petSignals
    row.petOwnerCount = finished.petCount
    row.restrictedPartyKills = finished.restrictedKills
    local rows = db.rows
    local function ReadMeter(finalAttempt)
        if rows ~= db.rows then return end
        local sameWindow = settling == finished
        row.meterUpdateCount = finished.meterUpdateCount
        row.meterReset, row.areaChanged = finished.meterReset, finished.areaChanged
        if not sameWindow or finished.areaChanged or finished.meterReset then
            if sameWindow then settling = nil end
            row.status.meter = "interrupted"
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
            end
            return
        end

        local context, anchors, faction
        if finished.previousPending then
            row.status.meterWindow = "previous-window-pending"
        elseif addon.WorldMeterContext and finished.startedAt and finished.startedUptime and row.uptime
            and row.instanceType == finished.startInstanceType and row.zone == finished.startZone then
            context, anchors, faction = addon.WorldMeterContext(row, finished.startedAt, finished.startedUptime)
        end
        if finished.context and context ~= finished.context then
            settling = nil
            row.status.meter = "journal-context-changed"
            return
        end
        finished.context = context
        if not context and not row.status.meterWindow then row.status.meterWindow = "no-eligible-world-record" end
        local evidence = context and addon.NewMeterParticipantEvidence(finished.contacts, finished.petOwners, faction)
        local retry, linked = CaptureMeter(row, finished, evidence, finalAttempt)
        if retry then
            C_Timer.After(1, function() ReadMeter(true) end)
            return
        end
        settling = nil

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
        if evidence and linked then
            local additions, reached = evidence:Connected(anchors)
            for name, actors in pairs(linked) do
                local counts = row.meter[name].resolution
                for actor in pairs(actors) do
                    Count(counts, reached[actor] and "source-connected" or "source-disconnected")
                end
            end
            addon.ApplyWorldMeterEvidence(context, additions, faction)
        end
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

local auraFields = { "auraInstanceID", "spellId", "sourceUnit", "isHelpful", "isHarmful" }

function handlers.UNIT_AURA(unit, update)
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
        if type(aura.sourceUnit) == "string" then Call(aura, "sourceGUID", UnitGUID, aura.sourceUnit) end
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
    if not window then return end
    window.meterUpdateCount = window.meterUpdateCount + 1
    local id, kind = Value(sessionID), Value(meterType)
    if type(id) ~= "number" or type(kind) ~= "number" then return end
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
    local window = combat or settling
    if not window then return end
    local signal = window.currentUpdates
    signal.count = (signal.count or 0) + 1
    signal.uptime = Value(GetTime())
    signal.firstUptime = signal.firstUptime or signal.uptime
end

function handlers.DAMAGE_METER_RESET()
    local window = combat or settling
    if window then window.meterReset = true end
end

local function AreaChanged(event)
    local window = combat or settling
    if window then window.areaChanged = true end
    if combat then Sample(Add(event)) end
end

function handlers.ZONE_CHANGED_NEW_AREA() AreaChanged("ZONE_CHANGED_NEW_AREA") end
function handlers.PLAYER_LEAVING_WORLD() AreaChanged("PLAYER_LEAVING_WORLD") end

local function LifeState(event)
    local row = Add(event)
    Sample(row)
    Call(row.player, "dead", UnitIsDeadOrGhost, "player")
    Call(row.player, "ghost", UnitIsGhost, "player")
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

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event ~= "ADDON_LOADED" then
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
