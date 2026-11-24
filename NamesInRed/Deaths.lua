local _, addon = ...
local Readable = addon.Readable
local sequence = 0

function addon.CancelPendingDeath()
    sequence = sequence + 1
end

local function ReadTable(value)
    value = Readable(value)
    if type(value) == "table" and (not canaccesstable or canaccesstable(value)) then
        return value
    end
end

local function IsHostilePlayer(row)
    local flags = Readable(row.sourceFlags)
    return type(flags) == "number" and bit and bit.band(flags, 0x440) == 0x440
end

local function HostilePlayer(row, playerGUID)
    local guid = Readable(row.sourceGUID)
    if type(guid) == "string" and guid:match("^Player%-.+") and guid ~= playerGUID and IsHostilePlayer(row) then
        return guid
    end
end

local function NoteRecap(death, status, cause)
    local context = death.context
    if addon.NoteWorldDeathRecap and context.worldWindow then
        addon.NoteWorldDeathRecap(context.worldWindow, context.killUptime, status, cause)
    end
end

local function Record(death)
    if death.sequence ~= sequence then return end
    if not C_DeathRecap or not C_DeathRecap.GetRecapEvents then
        return NoteRecap(death, "unavailable")
    end
    local ok, rows = pcall(C_DeathRecap.GetRecapEvents)
    rows = ok and ReadTable(rows)
    local first = rows and ReadTable(rows[1])
    if not first then
        return NoteRecap(death, "unreadable")
    end

    local stamp = Readable(first.timestamp)
    local overkill = Readable(first.overkill)
    local previous = addon.db.lastDeathTimestamp
    local repeatRecap = type(previous) == "number" and stamp == previous
    if type(stamp) ~= "number" or not (stamp > 0 and stamp < math.huge) or math.abs(stamp - death.observedAt) > 3
        or (type(previous) == "number" and stamp < previous)
        or (repeatRecap and not death.context.worldWindow)
        or type(overkill) ~= "number" or not (overkill >= 0 and overkill < math.huge) then
        return NoteRecap(death, "stale-or-unverified-lethal")
    end

    local playerGUID = Readable(UnitGUID("player"))
    local source = Readable(first.sourceGUID)
    local guid = HostilePlayer(first, playerGUID)
    local name = Readable(first.sourceName)
    local unknownFinisher = not guid and source == nil and IsHostilePlayer(first)
        and death.context.worldWindow ~= nil
    local effect = Readable(first.event)
    local cause = effect == "ENVIRONMENTAL_DAMAGE" and "environment"
        or (addon.SkirmishDeathEvidence and addon.SkirmishDeathEvidence.IsCreatureSource(source) and "npc")
    if not guid and cause then
        if repeatRecap then return NoteRecap(death, "duplicate-non-pvp") end
        NoteRecap(death, "non-pvp-lethal", cause)
        addon.db.lastDeathTimestamp = stamp
        return true
    end
    if not guid and not unknownFinisher then
        if addon.NotePvPDiagnostic then addon.NotePvPDiagnostic("recap-finisher-unverified") end
        return NoteRecap(death, "finisher-unverified")
    end

    local observed = guid and death.units[guid]
    local cached = guid and death.cached[guid]
    if cached and (not observed or not observed.level) then
        observed = observed or {}
        observed.level = cached
    end
    local attackers, seen, recapDamage = {}, {}, {}
    if guid then
        attackers[1] = { guid = guid, name = observed and observed.fullName or addon.ManualName(name), appearance = observed }
        seen[guid] = true
    end
    for index = 2, #rows do
        local row = ReadTable(rows[index])
        local attackerGUID = row and HostilePlayer(row, playerGUID)
        local amount = row and Readable(row.amount)
        local time = row and Readable(row.timestamp)
        if attackerGUID and type(time) == "number" and time > 0 and time <= stamp
            and type(amount) == "number" and amount > 0 and amount < math.huge
            and addon.Ledger.IsDeathRecapDamage(Readable(row.event)) then
            recapDamage[attackerGUID] = math.max(recapDamage[attackerGUID] or time, time)
        end
        if attackerGUID and not seen[attackerGUID] and type(amount) == "number" and amount > 0 then
            local unit = death.units[attackerGUID]
            attackers[#attackers + 1] = {
                guid = attackerGUID,
                name = unit and unit.fullName or addon.ManualName(Readable(row.sourceName)),
                appearance = unit,
            }
            seen[attackerGUID] = true
        end
    end

    death.context.time = math.floor(stamp)
    death.context.deathTimestamp = stamp
    death.context.rivalLevel = observed and observed.level
    death.context.rivalAppearance = observed
    death.context.attackers = attackers
    death.context.recapDamage = recapDamage
    death.context.unknownFinisher = unknownFinisher
    death.context.repeatRecap = repeatRecap
    local id, battle, status = addon.RecordWorldEncounter(guid, observed and observed.fullName or name, "deathsToThem", death.context)
    if addon.WorldDeathWindow and not id and status ~= "duplicate" then return end
    if unknownFinisher then
        -- Advance the native watermark even without a finisher. An exact
        -- repeat in the bound record can still refine this death on retry.
        if id then addon.db.lastDeathTimestamp = stamp end
        return
    end
    if id and battle and addon.RecordCombatDeathRecap then
        -- Reuse the same recap read. Earlier entries need a readable clock
        -- inside the matched skirmish, and the lethal entry is retained last.
        for index = math.min(#rows, 8), 2, -1 do
            local row = ReadTable(rows[index])
            local time = row and Readable(row.timestamp)
            if type(time) == "number" and type(battle.startedAt) == "number"
                and time >= battle.startedAt and time <= stamp then
                local actor = HostilePlayer(row, playerGUID)
                if actor then addon.RecordCombatDeathRecap(battle, actor, playerGUID, row, index, stamp) end
            end
        end
        addon.RecordCombatDeathRecap(battle, guid, playerGUID, first)
    end
    addon.db.lastDeathTimestamp = stamp
    if addon.NotePvPDiagnostic and not death.context.rivalLevel then addon.NotePvPDiagnostic("recap-level-unavailable") end
    return true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_DEAD")
frame:SetScript("OnEvent", function()
    sequence = sequence + 1
    if not addon.db then
        return
    end
    if not addon.RecordingPvPOrigin() then
        return
    end
    local context = addon.EncounterContext()
    if type(context.time) ~= "number" then
        return
    end
    if addon.WorldDeathWindow then
        context.killUptime = GetTime()
        context.worldWindow = addon.WorldDeathWindow(context)
        if not context.worldWindow then return end
    end
    local death = { sequence = sequence, context = context, observedAt = context.time, units = {},
        cached = addon.ActiveCombatContacts and addon.ActiveCombatContacts() or {} }
    local function Snapshot(unit)
        local guid = Readable(UnitGUID(unit))
        if type(guid) == "string" and guid:match("^Player%-.+") then
            local observed = death.units[guid] or {}
            local name = addon.UnitPlayerName(unit)
            if addon.HasFullName(name) then observed.fullName = name end
            local appearance = addon.UnitAppearance(unit)
            if Readable(UnitGUID(unit)) ~= guid then return end
            for key, value in pairs(appearance) do
                if observed[key] == nil then observed[key] = value end
            end
            death.units[guid] = observed
        end
    end
    Snapshot("target")
    Snapshot("mouseover")
    addon.VisitVisibleNameplateUnits(Snapshot)
    if Record(death) then
        return
    end
    context.delayedAssociation = true
    local recorded
    for _, delay in ipairs({ 0.3, 1, 2 }) do
        C_Timer.After(delay, function()
            if not recorded then
                recorded = Record(death)
            end
        end)
    end
end)
