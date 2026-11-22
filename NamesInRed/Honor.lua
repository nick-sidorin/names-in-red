local _, addon = ...
local Readable = addon.Readable
local windowSeconds = 2
local pending, lastHK

local function SessionHK()
    local count = GetPVPSessionStats and Readable(GetPVPSessionStats())
    return type(count) == "number" and count or nil
end

function addon.ResetHonorTracking()
    pending, lastHK = nil, SessionHK()
end

local function Save(batch)
    if pending ~= batch then return end
    pending = nil
    local battle = batch.battle
    if batch.kills ~= 1 or batch.hk ~= 1 or not battle or not addon.db.skirmishes
        or addon.db.skirmishes[batch.id] ~= battle then return end
    local honor
    if batch.messages == 1 then
        local currencyHonor = batch.currencyUpdates == 1 and batch.currencyHonor or nil
        if not batch.chatHonor or not currencyHonor or batch.chatHonor == currencyHonor then
            honor = batch.chatHonor or currencyHonor
        end
    end
    battle.rewards = battle.rewards or {}
    local reward = battle.rewards[batch.targetID] or { honorableKills = 0, honor = 0 }
    reward.honorableKills = reward.honorableKills + 1
    reward.honor = reward.honor + (honor or 0)
    battle.rewards[batch.targetID] = reward
    addon.RecordSkirmish(batch.id, battle)
end

local function FinishWhenQuiet(batch)
    if pending ~= batch then return end
    local remaining = batch.deadline - GetTime()
    if remaining > 0 then
        C_Timer.After(remaining, function() FinishWhenQuiet(batch) end)
    else
        Save(batch)
    end
end

local function CurrentBatch()
    local now = GetTime()
    if pending and now >= pending.deadline then Save(pending) end
    if pending then
        pending.deadline = now + windowSeconds
        return pending
    end
    local batch = { kills = 0, hk = 0, messages = 0, currencyUpdates = 0, lines = {}, deadline = now + windowSeconds }
    pending = batch
    C_Timer.After(windowSeconds, function() FinishWhenQuiet(batch) end)
    return batch
end

function addon.ObserveHonorKill(id, battle, targetID)
    local batch = CurrentBatch()
    batch.kills = batch.kills + 1
    if batch.kills == 1 then batch.id, batch.battle, batch.targetID = id, battle, targetID end
end

local function HonorFromChat(message)
    if type(message) ~= "string" then return end
    -- The actual ruRU Forever message contains a Blizzard plural marker.
    return tonumber((message:match("^Вы получили (%d+) |4очко чести:очка чести:очков чести;%.$")
        or message:match("^You have been awarded (%d+) honor points?%.$")))
end

local handlers = { PLAYER_ENTERING_WORLD = addon.ResetHonorTracking }

function handlers.PLAYER_LEAVING_WORLD()
    pending, lastHK = nil, nil
end

function handlers.PLAYER_PVP_KILLS_CHANGED(unit)
    unit = Readable(unit)
    if unit and unit ~= "player" then return end
    local count = SessionHK()
    if count and lastHK and count > lastHK then
        local batch = CurrentBatch()
        batch.hk = batch.hk + count - lastHK
    elseif (not count or (lastHK and count < lastHK)) and pending then
        pending.hk = math.huge
    end
    lastHK = count
end

function handlers.CHAT_MSG_COMBAT_HONOR_GAIN(message, _, _, _, _, _, _, _, _, _, lineID)
    local batch = CurrentBatch()
    lineID = Readable(lineID)
    if type(lineID) == "number" and lineID > 0 then
        if batch.lines[lineID] then return end
        batch.lines[lineID] = true
    end
    batch.messages = batch.messages + 1
    batch.chatHonor = HonorFromChat(Readable(message))
end

function handlers.CURRENCY_DISPLAY_UPDATE(currencyID, _, change)
    currencyID, change = Readable(currencyID), Readable(change)
    if not addon.IsHonorCurrency(currencyID) or type(change) ~= "number" or change <= 0 then return end
    local batch = CurrentBatch()
    batch.currencyUpdates = batch.currencyUpdates + 1
    batch.currencyHonor = change
end

local frame = CreateFrame("Frame")
for event in pairs(handlers) do pcall(frame.RegisterEvent, frame, event) end
frame:SetScript("OnEvent", function(_, event, ...)
    if not addon.db then return end
    if event ~= "PLAYER_ENTERING_WORLD" and event ~= "PLAYER_LEAVING_WORLD" then
        local _, instanceType = IsInInstance()
        if Readable(instanceType) ~= "none" then return end
    end
    handlers[event](...)
end)
