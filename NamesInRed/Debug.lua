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

local function CopyRow(input, fields)
    local output = { status = {} }
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
local spellFields = { "spellID", "totalAmount", "overkillAmount", "creatureName" }
local targetFields = { "unitName", "unitClassFilename", "classification", "isPet", "isMob", "amount" }

local function MeterSources(result, session, readSource)
    local sources = session.combatSources
    local readable, reason = AccessibleTable(sources)
    result.status.sources = readable and "readable" or reason
    if not readable then return end
    result.sourceCount = #sources
    result.sources = {}
    for index = 1, math.min(#sources, 12) do
        local source = CopyRow(sources[index], sourceFields)
        result.sources[index] = source
        local guid, creature = source.sourceGUID, source.sourceCreatureID
        if (source.isLocalPlayer and (guid or creature))
            or (type(guid) == "string" and (guid:match("^Player%-") or guid:match("^Pet%-"))) then
            local detail = readSource(source, guid, creature)
            local spells = detail and detail.combatSpells
            local hasSpells, why = AccessibleTable(spells)
            source.status.spells = hasSpells and "readable" or why
            if hasSpells then
                source.spellCount = #spells
                source.spells = {}
                for spellIndex = 1, math.min(#spells, 16) do
                    local entry = spells[spellIndex]
                    local spell = CopyRow(entry, spellFields)
                    if spell.status.row == "readable" then
                        spell.target = CopyRow(entry.combatSpellDetails, targetFields)
                    end
                    source.spells[spellIndex] = spell
                end
            end
        end
    end
end

local function CaptureMeter(row, baseline)
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
    if baseline and sessionIDs then
        for candidate in pairs(sessionIDs) do
            if not baseline[candidate] then candidates[#candidates + 1] = candidate end
        end
    end
    table.sort(candidates)
    local id = #candidates == 1 and candidates[1] or nil
    row.newMeterSessionIDs = candidates
    row.meterSessionID = id
    row.meterSelection = id and "new-archived" or "current-fallback"
    row.meter = {}
    for _, name in ipairs({
        "DamageDone", "DamageTaken", "EnemyDamageTaken", "HealingDone", "Absorbs", "Deaths", "Interrupts", "Dispels",
    }) do
        local meterType = types[name]
        local result = { status = {} }
        row.meter[name] = result
        if type(meterType) ~= "number" or (not id and current == nil) then
            result.status.session = "unavailable"
        else
            local getter = api.GetCombatSessionFromType
            local sourceGetter = api.GetCombatSessionSourceFromType
            if id then
                getter = api.GetCombatSessionFromID
                sourceGetter = api.GetCombatSessionSourceFromID
            end
            local selector = id or current
            local session = ReadResult(result, "session", getter, selector, meterType)
            if session then
                Capture(result, "duration", session.durationSeconds)
                Capture(result, "totalAmount", session.totalAmount)
                MeterSources(result, session, function(source, guid, creature)
                    return ReadResult(source, "detail", sourceGetter, selector, meterType, guid, creature)
                end)
            end
        end
    end
end

local handlers = {}

local function ObservePet(unit, guid)
    if type(UnitIsOwnerOrControllerOfUnit) ~= "function" or combat.petChecks >= 32 then return end
    combat.petChecks = combat.petChecks + 1
    local evidence = combat.petOwners[guid] or {}
    combat.petOwners[guid] = evidence
    for owner, contact in pairs(combat.contacts) do
        local token = contact.latest and contact.latest.token
        if token and Value(UnitGUID(token)) == owner then
            local ok, controls = pcall(UnitIsOwnerOrControllerOfUnit, token, unit)
            if ok and Value(controls) == true then evidence[owner] = true end
        end
    end
end

local function Observe(unit, reason)
    if not combat or type(unit) ~= "string" then return end
    local isPlayer = Value(UnitIsPlayer and UnitIsPlayer(unit))
    local guid, status = Value(UnitGUID and UnitGUID(unit))
    if isPlayer == false then
        if reason ~= "flags" and type(guid) == "string" and guid:match("^Pet%-.+") then ObservePet(unit, guid) end
        return
    end
    if type(guid) ~= "string" or not guid:match("^Player%-") then
        if isPlayer or status == "secret" then
            local key = reason .. ":" .. status
            combat.unresolved[key] = (combat.unresolved[key] or 0) + 1
        end
        return
    end
    local contact = combat.contacts[guid]
    if not contact then
        if combat.contactCount >= 32 then
            combat.contactOverflow = combat.contactOverflow + 1
            return
        end
        contact = { changes = {}, signals = {} }
        combat.contacts[guid] = contact
        combat.contactCount = combat.contactCount + 1
    end

    contact.signals[reason] = (contact.signals[reason] or 0) + 1
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
    if pet then Call(unitState, "petGUID", UnitGUID, pet) end
    Call(unitState, "inCombat", UnitAffectingCombat, unit)
    Call(unitState, "dead", UnitIsDeadOrGhost, unit)
    Call(unitState, "pvp", UnitIsPVP, unit)
    Capture(unitState, "race", Call(unitState, "raceName", UnitRace, unit))
    Call(unitState, "sex", UnitSex, unit)

    local previous = contact.latest
    contact.latest = unitState
    if previous and (previous.targetGUID ~= unitState.targetGUID or previous.petGUID ~= unitState.petGUID
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

local function ObserveCurrent(row, reason)
    Observe("player", reason)
    local prefix = row.inRaid and "raid" or "party"
    for index in ipairs(row.group) do Observe(prefix .. index, reason) end
    Observe("target", reason)
    Observe("mouseover", reason)
    for token in pairs(plateTokens) do Observe(token, reason) end
end

function handlers.PLAYER_REGEN_DISABLED()
    settling = nil
    combatSequence = combatSequence + 1
    local row = Add("COMBAT_START")
    Sample(row)
    CopyGroup(row)
    local baseline = C_DamageMeter and SessionIDs(row, C_DamageMeter)
    combat = {
        sequence = combatSequence, baseline = baseline, contacts = {}, unresolved = {},
        startedAt = row.time, startedUptime = row.uptime, startZone = row.zone, startInstanceType = row.instanceType,
        auraUpdates = {}, auraSignals = {}, currentUpdates = {}, petOwners = {}, petChecks = 0,
        contactCount = 0, contactOverflow = 0, meterUpdates = {}, meterUpdateCount = 0,
        groupChanges = {}, groupChangeCount = 0, restrictedKills = 0,
    }
    ObserveCurrent(row, "combat-start")
end

function handlers.PLAYER_REGEN_ENABLED()
    if not combat then return end
    local row = Add("COMBAT_END")
    Sample(row)
    CopyGroup(row)
    ObserveCurrent(row, "combat-end")
    local finished = combat
    combat, settling = nil, finished
    row.contacts, row.unresolvedContacts = finished.contacts, finished.unresolved
    row.contactOverflow = finished.contactOverflow
    row.groupChanges, row.groupChangeCount = finished.groupChanges, finished.groupChangeCount
    row.meterUpdates = finished.meterUpdates
    row.meterCurrentUpdates = finished.currentUpdates
    row.auraUpdates, row.auraSignals = finished.auraUpdates, finished.auraSignals
    row.petOwners, row.petChecks = finished.petOwners, finished.petChecks
    row.restrictedPartyKills = finished.restrictedKills
    local rows = db.rows
    local function ReadMeter()
        if rows ~= db.rows then return end
        local sameWindow = settling == finished
        if sameWindow then settling = nil end
        row.meterUpdateCount = finished.meterUpdateCount
        row.meterReset, row.areaChanged = finished.meterReset, finished.areaChanged
        local inCombat = Value(InCombatLockdown and InCombatLockdown())
        if not sameWindow or inCombat ~= false or finished.areaChanged then
            row.status.meter = "interrupted"
            return
        end
        CaptureMeter(row, finished.baseline)
        -- Current may outlive the local fight. Qualify each category independently.
        local types = Enum and Enum.DamageMeterType
        if not addon.EnrichWorldSkirmish or not types or not row.meter or not finished.baseline
            or row.instanceType ~= "none" or finished.startInstanceType ~= row.instanceType
            or not row.zone or finished.startZone ~= row.zone or finished.meterReset
            or row.status.availableSessions ~= "readable" or #row.newMeterSessionIDs > 1
            or not finished.startedAt or not finished.startedUptime or not row.uptime then return end
        local eligible = {}
        row.meterEvidence = {}
        for name, result in pairs(row.meter) do
            local meterType = types[name]
            local update = type(meterType) == "number" and finished.meterUpdates[(row.meterSessionID or 0) .. ":" .. meterType]
            if result.status.sources ~= "readable" then
                row.meterEvidence[name] = "sources-unreadable"
            elseif not update then
                row.meterEvidence[name] = "no-matching-update"
            elseif type(result.duration) ~= "number" or result.duration <= 0
                or math.abs(result.duration - (row.uptime - finished.startedUptime)) > 2 then
                row.meterEvidence[name] = "duration-mismatch"
            else
                row.meterEvidence[name] = "eligible"
                eligible[name] = result
            end
        end
        if next(eligible) then addon.EnrichWorldSkirmish(row, finished.startedAt, finished.startedUptime, eligible) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.5, ReadMeter) else ReadMeter() end
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
end

local function IsTracked(unit)
    return type(unit) == "string" and (plateTokens[unit] or unit == "target" or unit == "mouseover"
        or unit == "player" or unit:match("^party%d+$") or unit:match("^raid%d+$"))
end

local auraFields = { "spellId", "sourceUnit", "isHelpful", "isHarmful" }

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
    if #combat.groupChanges >= 6 then return end
    local row = { status = {}, uptime = Value(GetTime()) }
    CopyGroup(row)
    combat.groupChanges[#combat.groupChanges + 1] = row
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
        if window.meterUpdateCount > 80 then return end
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
