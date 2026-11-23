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

local function HostilePlayer(row, playerGUID)
    local guid = Readable(row.sourceGUID)
    local flags = Readable(row.sourceFlags)
    if type(guid) == "string" and guid:match("^Player%-.+") and guid ~= playerGUID
        and type(flags) == "number" and bit and bit.band(flags, 0x440) == 0x440 then
        return guid
    end
end

local function Record(death)
    if death.sequence ~= sequence or not C_DeathRecap or not C_DeathRecap.GetRecapEvents then
        return
    end
    local ok, rows = pcall(C_DeathRecap.GetRecapEvents)
    rows = ok and ReadTable(rows)
    local first = rows and ReadTable(rows[1])
    if not first then
        return
    end

    local stamp = Readable(first.timestamp)
    local overkill = Readable(first.overkill)
    local previous = addon.db.lastDeathTimestamp
    if type(stamp) ~= "number" or math.abs(stamp - death.context.time) > 3
        or (type(previous) == "number" and stamp <= previous)
        or type(overkill) ~= "number" or overkill < 0 then
        return
    end

    local playerGUID = Readable(UnitGUID("player"))
    local guid = HostilePlayer(first, playerGUID)
    local name = Readable(first.sourceName)
    if not guid then
        if addon.NotePvPDiagnostic then addon.NotePvPDiagnostic("recap-finisher-unverified") end
        return
    end

    local observed = death.units[guid]
    local cached = death.cached[guid]
    if cached and (not observed or not observed.level) then
        observed = observed or {}
        observed.level = cached
    end
    local attackers = { { guid = guid, name = observed and observed.fullName or addon.ManualName(name),
        appearance = observed } }
    local seen = { [guid] = true }
    for index = 2, #rows do
        local row = ReadTable(rows[index])
        local attackerGUID = row and HostilePlayer(row, playerGUID)
        local amount = row and Readable(row.amount)
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
    local id, battle, status = addon.RecordWorldEncounter(guid, observed and observed.fullName or name, "deathsToThem", death.context)
    if addon.WorldDeathWindow and not id and status ~= "duplicate" then return end
    if id and battle and addon.RecordCombatDeathRecap then
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
    local death = { sequence = sequence, context = context, units = {},
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
    local recorded
    for _, delay in ipairs({ 0.3, 1, 2 }) do
        C_Timer.After(delay, function()
            if not recorded then
                recorded = Record(death)
            end
        end)
    end
end)
