local addonName, addon = ...
local frame = CreateFrame("Frame")
local db
local deathSequence = 0
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
    return data
end

local function Add(kind)
    local row = { kind = kind, status = {}, session = db.session }
    Call(row, "time", GetServerTime)
    Call(row, "uptime", GetTime)
    Call(row, "instanceType", function()
        local _, instanceType = IsInInstance()
        return instanceType
    end)
    Call(row, "inCombat", InCombatLockdown)
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

local handlers = {}

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
    Sample(row)
    row.registration = {}
    for name in pairs(handlers) do
        local ok, registered = pcall(self.RegisterEvent, self, name)
        row.registration[name] = ok and registered ~= false and "registered" or "unavailable"
    end

    SLASH_NAMESINREDDEBUG1 = "/nirdebug"
    SlashCmdList.NAMESINREDDEBUG = function(message)
        if message == "icons" and addon and addon.ToggleIconReference then
            print("NamesInRed", "icons", addon.ToggleIconReference())
            return
        end
        if message == "seed" or message == "clear-seed" then
            if not addon or not addon.db then return end
            local count
            if message == "seed" then
                count = addon.AddDebugSeeds(GetServerTime())
            else
                count = addon.ClearDebugSeeds()
            end
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
