local _, addon = ...
local Readable = addon.Readable
local windowSeconds, lineLimit = 2, 256
local pending, lastHK
local lines, lineOrder, lineIndex = {}, {}, 0

local function SessionHK()
    local count = GetPVPSessionStats and Readable(GetPVPSessionStats())
    return type(count) == "number" and count or nil
end

function addon.ResetHonorTracking()
    pending, lastHK = nil, SessionHK()
end

function addon.ReconcileHonorWindow(window, battle)
    local claim = window and window.honorClaim
    if not claim or addon.db ~= claim.db or not window.record or window.record.battle ~= battle then return end
    local target = claim.hkAt and not window.rewardAttributed and addon.OutgoingRewardOpponent
        and addon.OutgoingRewardOpponent(battle, window.segment, window.rewardCorpse,
            claim.hkAt - window.began, claim.honorAt - window.began)
    if addon.Ledger.MoveUnassignedRewards(claim.owner, battle, claim.honorableKills, claim.honor, target) then
        claim.owner = battle
        if target then
            window.rewardAttributed, window.honorClaim = true, nil
            return true
        end
    end
    if claim.owner == battle and not claim.hkAt then window.honorClaim = nil end
end

local function RememberWindowAward(batch, owner, hk, honor)
    local window = batch.window
    if not window or batch.conflict or batch.unlinkedKill or batch.unscopedReward or batch.hkUncertain or batch.kills ~= 0 then return end
    local claim = window.honorClaim
    if not claim then
        claim = { db = batch.db, owner = owner, honorableKills = hk, honor = honor }
        window.honorClaim = claim
        if hk == 1 and honor > 0 and batch.messages == 1 and batch.honorAt
            and (batch.currencyUpdates == 0 or (batch.currencyUpdates == 1 and batch.currencyHonor == honor)) then
            claim.hkAt, claim.honorAt = batch.hkAt, batch.honorAt
        end
    elseif claim.owner == owner then
        claim.honorableKills, claim.honor = claim.honorableKills + hk, claim.honor + honor
        claim.hkAt, claim.honorAt = nil, nil
    else
        claim.hkAt, claim.honorAt = nil, nil
    end
end

local function Save(batch)
    if pending ~= batch then return end
    pending = nil
    if addon.db ~= batch.db then return end
    local hk = batch.hk
    local honor = batch.chatHonor
    if honor == 0 and batch.messages == 1 and batch.currencyUpdates == 1 then honor = batch.currencyHonor end
    if hk == 0 and honor == 0 then return end

    local db, ledger = batch.db, addon.Ledger
    local id, battle = batch.id, batch.battle
    local record = batch.window and batch.window.record
    if not battle and batch.kills == 0 and record then id, battle = record.id, record.battle end
    if batch.conflict or batch.unlinkedKill or batch.unscopedReward or not battle or not db.skirmishes or db.skirmishes[id] ~= battle then
        ledger.AddRewards(db, "unassignedRewards", hk, honor)
        -- Keep a live claim on this exact window while the total is safely
        -- counted in the journal. A later confirmation moves it once.
        if not battle then RememberWindowAward(batch, db, hk, honor) end
        if addon.RefreshBook then addon.RefreshBook() end
        if addon.NotePvPDiagnostic then addon.NotePvPDiagnostic("reward-unassigned-skirmish") end
        return
    end
    if batch.kills == 1 and hk == 1 and batch.targetID and not batch.hkUncertain then
        local targetHonor = 0
        if batch.messages == 1 and (batch.currencyUpdates ~= 1 or batch.currencyHonor == honor) then
            targetHonor = honor
        end
        ledger.AddSkirmishRewards(battle, batch.targetID, hk, targetHonor)
        hk, honor = 0, honor - targetHonor
    end
    if hk > 0 or honor > 0 then
        ledger.AddSkirmishRewards(battle, nil, hk, honor)
        RememberWindowAward(batch, battle, hk, honor)
        if not addon.ReconcileHonorWindow(batch.window, battle) and addon.NotePvPDiagnostic then
            addon.NotePvPDiagnostic("reward-unassigned-opponent")
        end
    end
    addon.RecordSkirmish(id, battle)
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
    local origin = addon.RecordingPvPOrigin()
    local instanceMapID = origin == "battleground" and addon.BattlegroundMapID() or nil
    local window = addon.HonorWorldWindow and addon.HonorWorldWindow()
    if pending and (pending.origin ~= origin or pending.instanceMapID ~= instanceMapID or now >= pending.deadline) then
        Save(pending)
    end
    if pending then
        if window and pending.window and window ~= pending.window then pending.conflict = true end
        pending.window = pending.window or window
        pending.deadline, pending.currentWindow = now + windowSeconds, window
        return pending
    end
    local batch = { kills = 0, hk = 0, messages = 0, currencyUpdates = 0, chatHonor = 0,
        deadline = now + windowSeconds, db = addon.db, origin = origin, instanceMapID = instanceMapID,
        window = window, currentWindow = window }
    pending = batch
    C_Timer.After(windowSeconds, function() FinishWhenQuiet(batch) end)
    return batch
end

function addon.ObserveHonorKill(id, battle, targetID)
    local batch = CurrentBatch()
    batch.kills = batch.kills + 1
    if not battle then
        batch.unlinkedKill = true
    elseif batch.battle and battle ~= batch.battle then
        batch.conflict = true
    elseif not batch.battle then
        batch.id, batch.battle, batch.targetID = id, battle, targetID
    end
end

function addon.HonorFromChat(message)
    if type(message) ~= "string" then return end
    -- The actual ruRU Forever message contains a Blizzard plural marker.
    return tonumber((message:match("^Вы получили (%d+) |4очко чести:очка чести:очков чести;%.$")
        or message:match("^You have been awarded (%d+) honor points?%.$")))
end

local handlers = { PLAYER_ENTERING_WORLD = addon.ResetHonorTracking }

function addon.CloseHonorTracking()
    if pending then Save(pending) end
    lastHK = nil
end

handlers.PLAYER_LEAVING_WORLD = addon.CloseHonorTracking
handlers.PLAYER_LOGOUT = addon.CloseHonorTracking

function handlers.PLAYER_PVP_KILLS_CHANGED(unit)
    unit = Readable(unit)
    if unit and unit ~= "player" then return end
    local count = SessionHK()
    if count and lastHK and count > lastHK then
        local batch = CurrentBatch()
        batch.hk = batch.hk + count - lastHK
        batch.hkAt = GetTime()
        if not batch.currentWindow and not batch.battle then batch.unscopedReward = true end
    elseif (not count or (lastHK and count < lastHK)) and pending then
        pending.hkUncertain = true
    end
    lastHK = count
end

function handlers.CHAT_MSG_COMBAT_HONOR_GAIN(message, _, _, _, _, _, _, _, _, _, lineID)
    lineID = Readable(lineID)
    if type(lineID) == "number" and lineID > 0 then
        if lines[lineID] then return end
        lineIndex = lineIndex % lineLimit + 1
        local previous = lineOrder[lineIndex]
        if previous then lines[previous] = nil end
        lineOrder[lineIndex], lines[lineID] = lineID, true
    end
    local batch = CurrentBatch()
    batch.messages = batch.messages + 1
    if not batch.currentWindow and not batch.battle then batch.unscopedReward = true end
    local amount = addon.HonorFromChat(Readable(message))
    batch.chatHonor = batch.chatHonor + (amount or 0)
    if amount and amount > 0 and type(lineID) == "number" and lineID > 0 then batch.honorAt = GetTime() end
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
    if event ~= "PLAYER_ENTERING_WORLD" and event ~= "PLAYER_LEAVING_WORLD" and event ~= "PLAYER_LOGOUT"
        and not addon.RecordingPvPOrigin() then return end
    handlers[event](...)
end)
