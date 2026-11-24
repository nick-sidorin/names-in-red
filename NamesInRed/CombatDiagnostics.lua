local _, addon = ...

-- This journal observes combat without feeding participant or outcome decisions.
local maxWindows, maxRecaps = 4, 8
local maxJournals, maxJournalBytes = 24, 64 * 1024
local retained = setmetatable({}, { __mode = "k" })
local streams = {
    unitCombat = { 16, 12 },
    spellCast = { 16, 12 },
    aura = { 16, 12 },
    unitState = { 12, 10 },
    partyKill = { 8, 8 },
}
local casts = {
    UNIT_SPELLCAST_START = "start",
    UNIT_SPELLCAST_SUCCEEDED = "succeeded",
    UNIT_SPELLCAST_INTERRUPTED = "interrupted",
    UNIT_SPELLCAST_CHANNEL_START = "channel-start",
    UNIT_SPELLCAST_CHANNEL_STOP = "channel-stop",
}
local effects = { WOUND = true, HEAL = true, ENERGIZE = true, MISS = true, DODGE = true,
    PARRY = true, BLOCK = true, RESIST = true, ABSORB = true, IMMUNE = true, EVADE = true,
    DEFLECT = true, REFLECT = true, INTERRUPT = true }
local feedbackFlags = { CRITICAL = true, CRUSHING = true, GLANCING = true, BLOCK_REDUCED = true,
    ABSORB = true, BLOCK = true, RESIST = true }

local function Value(value, expected)
    if issecretvalue and issecretvalue(value) then return nil, "secret" end
    if value == nil then return nil, "absent" end
    if type(value) ~= expected then return nil, "unsupported-type" end
    if expected == "number" and (value ~= value or math.abs(value) == math.huge) then return nil, "invalid-number" end
    if expected == "table" and canaccesstable and not canaccesstable(value) then return nil, "restricted-table" end
    return value, "readable"
end

local function SetField(row, key, value, expected)
    local clean, status = Value(value, expected)
    row[key], row[key .. "Status"] = clean, status
end

local function Player(value)
    local guid, status = Value(value, "string")
    if guid and not guid:match("^Player%-.+") then return nil, guid == "" and "absent" or "non-player" end
    if guid and (#guid > 64 or not guid:match("^[%w%-]+$")) then return nil, "invalid-identity" end
    return guid, status
end

local function UnitPlayer(unit)
    if not unit then return nil, "absent" end
    if not UnitGUID then return nil, "unavailable" end
    local ok, guid = pcall(UnitGUID, unit)
    if not ok then return nil, "error" end
    return Player(guid)
end

local function RoundedOffset(capture, now)
    return math.floor(math.max(0, now - capture.start) * 1000 + 0.5) / 1000
end

-- Budget the named fields, escaped strings, punctuation and indentation of
-- a Lua SavedVariables table. This is a conservative estimate, not heap size.
local function SavedBytes(value, depth)
    local kind = type(value)
    if kind == "string" then return #string.format("%q", value) end
    if kind == "number" then return 32 end
    if kind == "boolean" then return 5 end
    if kind ~= "table" or depth >= 12 then return math.huge end
    local bytes = depth + 4
    for key, item in pairs(value) do
        bytes = bytes + depth + 9 + SavedBytes(key, depth) + SavedBytes(item, depth + 1)
        if bytes > maxJournalBytes then break end
    end
    return bytes
end

local function Recent(rows, limit, eligible)
    local selected = {}
    for index = #rows, 1, -1 do
        if eligible(rows[index]) then
            table.insert(selected, 1, rows[index])
            if #selected == limit then break end
        end
    end
    return selected
end

local function Compact(battle)
    local journal = battle.combatDiagnostics
    local roster = {}
    for _, player in ipairs(battle.allies or {}) do if player.id then roster[player.id] = true end end
    for _, player in ipairs(battle.enemies or {}) do if player.id then roster[player.id] = true end end
    local function Linked(row)
        if row.actorStatus == "non-player" or row.targetStatus == "non-player"
            or (row.isMob and not row.otherID) then return false end
        local linked
        for _, id in pairs({ row.actorID, row.targetID, row.interrupterID, row.meterUnitID, row.otherID }) do
            if not roster[id] then return false end
            linked = true
        end
        return linked
    end
    local window = journal.windows[#journal.windows]
    if window then
        local streams = {}
        for name, stream in pairs(window.streams) do
            local rows = Recent(stream.rows, name == "unitCombat" and 2 or 1, Linked)
            streams[name] = { rows = rows, dropped = (stream.dropped or 0) + #stream.rows - #rows,
                duplicates = stream.duplicates, rateLimited = stream.rateLimited }
        end
        local meter = window.meter
        local miniMeter
        if meter then
            miniMeter = { selection = meter.selection, sessionID = meter.sessionID, readOffset = meter.readOffset,
                retained = 0, dropped = meter.dropped or 0, categories = {} }
            for _, name in ipairs({ "DamageDone", "DamageTaken", "EnemyDamageTaken", "HealingDone", "Absorbs", "Deaths" }) do
                local group = meter.categories[name]
                if group then
                    local rows = Recent(group.rows, 1, Linked)
                    local removed = #group.rows - #rows
                    miniMeter.categories[name] = { rows = rows, dropped = (group.dropped or 0) + removed }
                    miniMeter.retained, miniMeter.dropped = miniMeter.retained + #rows, miniMeter.dropped + removed
                end
            end
        end
        local followups = window.meterFollowups or {}
        journal.windowsDropped = (journal.windowsDropped or 0) + #journal.windows - 1
        journal.windows = { { time = window.time, index = window.index, build = window.build, ending = window.ending,
            endOffset = window.endOffset, availability = window.availability, streams = streams, meter = miniMeter,
            meterStatus = window.meterStatus, meterWindow = window.meterWindow, meterInterruption = window.meterInterruption,
            meterFollowups = Recent(followups, 1, function(row) return not row.actorID or Linked(row) end) } }
        journal.windows[1].meterFollowupsDropped = (window.meterFollowupsDropped or 0)
            + #followups - #journal.windows[1].meterFollowups
    end
    local recaps = Recent(journal.recaps, 1, Linked)
    journal.recapsDropped = (journal.recapsDropped or 0) + #journal.recaps - #recaps
    journal.recaps, journal.retention = recaps, "compact"
end

local function Trim(journal)
    while SavedBytes(journal, 4) > maxJournalBytes do
        if #journal.windows > 0 then
            table.remove(journal.windows, 1)
            journal.windowsDropped = (journal.windowsDropped or 0) + 1
        else
            table.remove(journal.recaps, 1)
            journal.recapsDropped = (journal.recapsDropped or 0) + 1
            if #journal.recaps == 0 then return end
        end
    end
end

local function HasJournal(input)
    return type(input) == "table" and input.version == 1 and type(input.windows) == "table"
        and type(input.recaps) == "table" and input.retention ~= "compact"
end

function addon.RestoreCombatDiagnostics(db)
    local fights = {}
    for id, battle in pairs(type(db.skirmishes) == "table" and db.skirmishes or {}) do
        if type(battle) == "table" and type(battle.allies) == "table" and type(battle.enemies) == "table"
            and HasJournal(battle.combatDiagnostics) then
            fights[#fights + 1] = { id = tostring(id), battle = battle }
        end
    end
    table.sort(fights, function(a, b)
        local first, second = a.battle, b.battle
        local aSequence, bSequence = tonumber(first.sequence) or 0, tonumber(second.sequence) or 0
        if aSequence ~= bSequence then return aSequence < bSequence end
        local aTime, bTime = tonumber(first.time) or 0, tonumber(second.time) or 0
        if aTime ~= bTime then return aTime < bTime end
        return a.id < b.id
    end)
    local journals = {}
    for index, fight in ipairs(fights) do
        local journal = fight.battle.combatDiagnostics
        if index <= #fights - maxJournals then
            Compact(fight.battle)
        else
            Trim(journal)
            journals[#journals + 1] = fight.battle
        end
    end
    retained[db] = journals
end

function addon.ForgetCombatDiagnostics(db, battle)
    if not battle or not battle.combatDiagnostics then return end
    for index, retainedBattle in ipairs(retained[db] or {}) do
        if retainedBattle == battle then
            table.remove(retained[db], index)
            return
        end
    end
end

local function Journal(battle)
    if not battle.combatDiagnostics then
        local journal = { version = 1, windows = {}, recaps = {} }
        battle.combatDiagnostics = journal
        if addon.db then
            local journals = retained[addon.db] or {}
            retained[addon.db] = journals
            if #journals >= maxJournals then Compact(table.remove(journals, 1)) end
            journals[#journals + 1] = battle
        end
    end
    local journal = battle.combatDiagnostics
    if HasJournal(journal) then return journal end
end

function addon.NewCombatDiagnostics(start, time, build, registration)
    if type(start) ~= "number" then return end
    local availability = {}
    for event, status in pairs(registration or {}) do
        if casts[event] or event == "UNIT_AURA" or event == "UNIT_COMBAT" or event == "UNIT_FLAGS" or event == "PARTY_KILL" then
            availability[event] = status
        end
    end
    return { start = start, budgets = {}, keys = {},
        window = { time = time, build = build, availability = availability, streams = {} } }
end

function addon.AttachCombatDiagnostics(battle, capture)
    if capture.attached then return end
    local journal = Journal(battle)
    if not journal then return end
    local windows = journal.windows
    if #windows >= maxWindows then
        table.remove(windows, 1)
        journal.windowsDropped = (journal.windowsDropped or 0) + 1
    end
    capture.window.index = (journal.windowsDropped or 0) + #windows + 1
    windows[#windows + 1] = capture.window
    capture.journal = journal
    capture.attached = true
    Trim(journal)
end

function addon.EndCombatDiagnostics(capture, ending)
    capture.window.ending = ending
    capture.window.endOffset = RoundedOffset(capture, GetTime())
    if HasJournal(capture.journal) then Trim(capture.journal) end
end

local function Stream(capture, name)
    local stream = capture.window.streams[name]
    if not stream then
        stream = { rows = {}, dropped = 0, duplicates = 0, rateLimited = 0 }
        capture.window.streams[name] = stream
        capture.keys[name] = {}
    end
    return stream
end

local function Begin(capture, name)
    local stream = Stream(capture, name)
    local now = GetTime()
    local second = math.floor(now - capture.start)
    local budget = capture.budgets[name]
    if not budget or budget.second ~= second then
        budget = { second = second, count = 0 }
        capture.budgets[name] = budget
    end
    if budget.count >= streams[name][2] then
        stream.rateLimited = stream.rateLimited + 1
        return
    end
    budget.count = budget.count + 1
    return { offset = RoundedOffset(capture, now) }
end

local function Push(capture, name, row, key)
    local stream, keys = Stream(capture, name), capture.keys[name]
    if key then
        for _, previous in ipairs(keys) do
            if previous == key then
                stream.duplicates = stream.duplicates + 1
                return
            end
        end
    end
    if #stream.rows >= streams[name][1] then
        table.remove(stream.rows, 1)
        table.remove(keys, 1)
        stream.dropped = stream.dropped + 1
    end
    local index = #stream.rows + 1
    stream.rows[index], keys[index] = row, key or false
end

function addon.ObserveCombatFeedback(capture, unit, effect, flag, amount, school)
    local row = Begin(capture, "unitCombat")
    if not row then return end
    local kind, status = Value(effect, "string")
    row.effect = kind and effects[kind] and kind or nil
    row.effectStatus = kind and (row.effect and "readable" or "unknown-token") or status
    local token, flagStatus = Value(flag, "string")
    row.flag = token and feedbackFlags[token] and token or nil
    row.flagStatus = token and (row.flag and "readable" or token == "" and "absent" or "unknown-token") or flagStatus
    row.targetID, row.targetStatus = UnitPlayer(unit)
    SetField(row, "amount", amount, "number")
    SetField(row, "school", school, "number")
    Push(capture, "unitCombat", row)
end

function addon.ObserveCombatCast(capture, event, unit, castGUID, spellID, interruptedBy)
    local row = Begin(capture, "spellCast")
    if not row then return end
    row.phase = casts[event]
    row.actorID, row.actorStatus = UnitPlayer(unit)
    local cast, status = Value(castGUID, "string")
    row.castStatus = status
    SetField(row, "spellID", spellID, "number")
    if event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        row.interrupterID, row.interrupterStatus = Player(interruptedBy)
    end
    -- The GUID is only a transient deduplication key within the bounded stream.
    local key = cast and #cast > 0 and #cast <= 96 and (event .. ":" .. cast) or nil
    Push(capture, "spellCast", row, key)
end

function addon.ObserveCombatAuras(capture, unit, update)
    local sample = Begin(capture, "aura")
    if not sample then return end
    local payload, status = Value(update, "table")
    local full, fullStatus
    if payload then full, fullStatus = Value(payload.isFullUpdate, "boolean") end
    local entries
    if full then
        status = "full-update"
    elseif fullStatus == "secret" then
        status = "secret"
    elseif payload then
        entries, status = Value(payload.addedAuras, "table")
        if entries and #entries == 0 then status = "no-additions" end
    end
    local id, idStatus = UnitPlayer(unit)
    if not entries or #entries == 0 then
        sample.targetID, sample.targetStatus = id, idStatus
        sample.payloadStatus = status
        Push(capture, "aura", sample)
        return
    end
    local length = math.min(#entries, 8)
    local stream = Stream(capture, "aura")
    stream.dropped = stream.dropped + #entries - length
    for i = 1, length do
        local row = i == 1 and sample or Begin(capture, "aura")
        if row then
            local aura, auraStatus = Value(entries[i], "table")
            row.targetID, row.targetStatus, row.payloadStatus = id, idStatus, auraStatus
            local key
            if aura then
                local source, sourceStatus = Value(aura.sourceUnit, "string")
                row.actorID, row.actorStatus = UnitPlayer(source)
                if not source then row.actorStatus = sourceStatus end
                SetField(row, "spellID", aura.spellId, "number")
                SetField(row, "helpful", aura.isHelpful, "boolean")
                SetField(row, "harmful", aura.isHarmful, "boolean")
                local instance = Value(aura.auraInstanceID, "number")
                if id and instance then key = id .. ":" .. instance end
            end
            Push(capture, "aura", row, key)
        end
    end
end

function addon.ObserveCombatState(capture, state)
    local row = Begin(capture, "unitState")
    if not row then return end
    row.targetID, row.targetStatus = Player(state.guid)
    row.signal = state.reason
    row.dead, row.deadStatus = state.dead, state.status.dead
    row.inCombat, row.inCombatStatus = state.inCombat, state.status.inCombat
    row.feign, row.feignStatus = state.feign, state.status.feign
    Push(capture, "unitState", row)
end

function addon.ObserveCombatPartyKill(capture, attacker, victim)
    local row = Begin(capture, "partyKill")
    if not row then return end
    row.actorID, row.actorStatus = Player(attacker)
    row.targetID, row.targetStatus = Player(victim)
    Push(capture, "partyKill", row)
end

function addon.RecordCombatDeathRecap(battle, actor, target, hit, recapIndex, recapTime)
    local journal = Journal(battle)
    if not journal then return end
    local recaps = journal.recaps
    local time = Value(hit.timestamp, "number")
    local row = {}
    row.actorID, row.actorStatus = Player(actor)
    row.targetID, row.targetStatus = Player(target)
    row.recapIndex, row.recapTime = recapIndex or 1, recapTime or time
    for _, previous in ipairs(recaps) do
        if row.recapTime and (previous.recapTime or previous.eventTime) == row.recapTime
            and (previous.recapIndex or 1) == row.recapIndex and previous.targetID == row.targetID then return end
    end
    if #recaps >= maxRecaps then
        table.remove(recaps, 1)
        journal.recapsDropped = (journal.recapsDropped or 0) + 1
    end
    local event, status = Value(hit.event, "string")
    row.effect = addon.Ledger.IsDeathRecapDamage(event) and event or nil
    row.effectStatus = event and (row.effect and "readable" or "unknown-token") or status
    SetField(row, "eventTime", hit.timestamp, "number")
    SetField(row, "spellID", hit.spellId, "number")
    SetField(row, "amount", hit.amount, "number")
    SetField(row, "overkill", hit.overkill, "number")
    SetField(row, "absorbed", hit.absorbed, "number")
    recaps[#recaps + 1] = row
    Trim(journal)
end

function addon.NewCombatMeterProbe()
    return { categories = {}, retained = 0, dropped = 0 }
end

function addon.SampleCombatMeter(probe, category, actor, source, spell, detail, reason, other)
    local group = probe.categories[category]
    if not group then
        group = { rows = {}, dropped = 0 }
        probe.categories[category] = group
    end
    if #group.rows >= 6 or probe.retained >= 32 then
        group.dropped, probe.dropped = group.dropped + 1, probe.dropped + 1
        return
    end

    local row = {
        meterUnitID = Player(actor.guid), otherID = other and Player(other.guid),
        resolution = reason, petOwner = source.sourceGUID ~= actor.guid,
        detailStatus = detail and detail.status.row,
    }
    SetField(row, "spellID", spell.spellID, "number")
    SetField(row, "spellTotal", spell.totalAmount, "number")
    SetField(row, "overkill", spell.overkillAmount, "number")
    SetField(row, "sourceTotal", source.totalAmount, "number")
    if source.status.totalAmount ~= "readable" then row.sourceTotalStatus = source.status.totalAmount end
    if detail then
        SetField(row, "amount", detail.amount, "number")
        if detail.status.amount ~= "readable" then row.amountStatus = detail.status.amount end
        row.nameStatus, row.classStatus = detail.status.unitName, detail.status.unitClassFilename
        row.isPet, row.isMob = detail.isPet, detail.isMob
    end
    group.rows[#group.rows + 1] = row
    probe.retained = probe.retained + 1
end

function addon.CommitCombatMeterProbe(capture, probe, sessionID, selection)
    if probe.retained == 0 then return end
    probe.sessionID, probe.selection = sessionID, selection
    probe.readOffset = RoundedOffset(capture, GetTime())
    capture.window.meter = probe
    if HasJournal(capture.journal) then Trim(capture.journal) end
end

function addon.RecordCombatMeterFollowup(capture, read, signal, category, increase)
    local window = capture.window
    local rows = window.meterFollowups or {}
    window.meterFollowups = rows
    if #rows >= 8 then
        table.remove(rows, 1)
        window.meterFollowupsDropped = (window.meterFollowupsDropped or 0) + 1
    end
    local row = { status = read.status.meter, category = category, readOffset = RoundedOffset(capture, read.uptime) }
    row.sessionID = Value(read.meterSessionID, "number")
    row.localDead, row.localDeadStatus = read.playerDead, read.status.playerDead
    row.localGhost, row.localGhostStatus = read.playerGhost, read.status.playerGhost
    if signal then
        row.actorID, row.targetID = Player(signal.actorID), Player(signal.targetID)
        row.pairTotal, row.amountIncrease = Value(signal.amount, "number"), Value(increase, "number")
    end
    rows[#rows + 1] = row
end

function addon.CombatCastDiagnosticsEvents()
    return pairs(casts)
end
