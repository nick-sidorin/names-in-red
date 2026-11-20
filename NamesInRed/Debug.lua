local addonName, addon = ...
local frame = CreateFrame("Frame")
local db
local deathSequence = 0
local combatSequence = 0
local combat
local limit = 1000

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
    Call(row, "damageMeterAvailable", C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable)
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
    end
end

local function SessionIDs(result, api)
    local sessions = ReadResult(result, "availableSessions", api.GetAvailableCombatSessions)
    if not sessions then return end
    local known = {}
    for _, session in ipairs(sessions) do
        if AccessibleTable(session) then
            local id = Value(session.sessionID)
            if type(id) == "number" then known[id] = true end
        end
    end
    return known
end

local sourceFields = {
    "sourceGUID", "sourceCreatureID", "name", "classFilename", "classification",
    "factionGroup", "isLocalPlayer", "totalAmount", "deathRecapID",
}
local spellFields = { "spellID", "totalAmount", "overkillAmount" }
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
        if (source.isLocalPlayer and (guid or creature)) or (type(guid) == "string" and guid:match("^Player%-")) then
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
    for _, name in ipairs({ "DamageDone", "DamageTaken", "EnemyDamageTaken", "HealingDone" }) do
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
                MeterSources(result, session, function(source, guid, creature)
                    return ReadResult(source, "detail", sourceGetter, selector, meterType, guid, creature)
                end)
            end
        end
    end
end

local handlers = {}

function handlers.PLAYER_REGEN_DISABLED()
    combatSequence = combatSequence + 1
    local row = Add("COMBAT_START")
    Sample(row)
    CopyGroup(row)
    local baseline = C_DamageMeter and SessionIDs(row, C_DamageMeter)
    combat = { sequence = combatSequence, baseline = baseline }
end

function handlers.PLAYER_REGEN_ENABLED()
    if not combat then return end
    local finished = combat
    combat = nil
    local row = Add("COMBAT_END")
    Sample(row)
    CopyGroup(row)
    local function ReadMeter()
        local inCombat = Value(InCombatLockdown and InCombatLockdown())
        if finished.sequence ~= combatSequence or inCombat ~= false then
            row.status.meter = "interrupted"
            return
        end
        CaptureMeter(row, finished.baseline)
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.5, ReadMeter) else ReadMeter() end
end

function handlers.PLAYER_DEAD()
    deathSequence = deathSequence + 1
    local sequence = deathSequence
    local row = Add("PLAYER_DEAD")
    row.deathSequence = sequence
    Sample(row)
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
    local row = Add("PARTY_KILL")
    Capture(row, "attacker", attacker)
    Capture(row, "victim", victim)
    Sample(row)
    row.pet = Unit("pet")
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
    db = NamesInRedDebugDB
    if type(db) ~= "table" or db.version ~= 1 or type(db.rows) ~= "table"
        or type(db.session) ~= "number" or type(db.dropped) ~= "number" then
        return
    end
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
        if message == "seed" or message == "clear-seed" then
            if not addon or not addon.db then return end
            local seed = message == "seed"
            local update = addon[seed and "AddDebugSeeds" or "ClearDebugSeeds"]
            if type(update) ~= "function" then return end
            local count = update(seed and GetServerTime() or nil)
            if addon.RefreshBook then addon.RefreshBook(message == "seed") end
            print("NamesInRed", message, count)
            return
        end
        if message == "sample" then
            Sample(Add("MANUAL_SAMPLE"))
        end
        print("NamesInRedDebugDB", #db.rows, "rows", db.dropped, "dropped", db.session, "session")
    end
end)
