local _, addon = ...
local Readable = addon.Readable
local sequence = 0

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
        return
    end

    local observed = death.units[guid]
    local attackers = { { guid = guid, name = observed and observed.fullName or addon.ManualName(name) } }
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
            }
            seen[attackerGUID] = true
        end
    end

    death.context.time = math.floor(stamp)
    death.context.rivalLevel = observed and observed.level
    death.context.attackers = attackers
    addon.db.lastDeathTimestamp = stamp
    addon.RecordEncounter(guid, observed and observed.fullName or name, "deathsToThem", death.context)
    return true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_DEAD")
frame:SetScript("OnEvent", function()
    sequence = sequence + 1
    if not addon.db then
        return
    end
    local _, instanceType = IsInInstance()
    if Readable(instanceType) ~= "none" then
        return
    end
    local context = addon.EncounterContext()
    if type(context.time) ~= "number" then
        return
    end
    local death = { sequence = sequence, context = context, units = {} }
    for _, unit in ipairs({ "target", "mouseover" }) do
        local guid = Readable(UnitGUID(unit))
        local level = Readable(UnitLevel(unit))
        if type(guid) == "string" and guid:match("^Player%-.+") then
            local observed = death.units[guid] or {}
            local name = addon.UnitPlayerName(unit)
            if addon.HasFullName(name) then observed.fullName = name end
            if type(level) == "number" and level > 0 then observed.level = level end
            death.units[guid] = observed
        end
    end
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
