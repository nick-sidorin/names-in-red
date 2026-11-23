local _, addon = ...

local Readable = addon.Readable
local pending = {}

function addon.CancelPendingWorldKills()
    pending = {}
end

local function RivalName(unit, victim, faction)
    if Readable(UnitGUID(unit)) ~= victim or Readable(UnitIsPlayer(unit)) ~= true
        or Readable(UnitCanAttack("player", unit)) ~= true then
        return nil
    end

    local rivalFaction = Readable(UnitFactionGroup(unit))
    if (rivalFaction == "Alliance" or rivalFaction == "Horde") and rivalFaction ~= faction then
        return addon.UnitPlayerName(unit), unit
    end
end

local function Record(victim, name, context, retry)
    local prior = pending[victim]
    if not retry and prior then
        if prior.actorID ~= context.actorID then prior.ambiguous = true end
        return
    end
    local id, battle, status, window = addon.RecordWorldEncounter(victim, name, "killsAgainstThem", context)
    if status == "awaiting-death" and not retry and C_Timer and C_Timer.After then
        context.worldWindow = window
        context.retrying = true
        pending[victim] = context
        C_Timer.After(0.25, function()
            if pending[victim] ~= context then return end
            pending[victim] = nil
            if not context.ambiguous then Record(victim, name, context, true) end
        end)
    elseif status == "unlinked" then
        addon.ObserveHonorKill()
    elseif status == nil and (id or not addon.WorldDeathWindow) then
        pending[victim] = nil
        addon.ObserveHonorKill(id, battle, victim)
    end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, _, attacker, victim)
    if not addon.db then
        return
    end

    if not addon.RecordingPvPOrigin() then
        return
    end

    attacker, victim = Readable(attacker), Readable(victim)
    if type(victim) ~= "string" then
        addon.ObserveHonorKill()
        return
    end
    if not victim:match("^Player%-.+") or attacker == victim then return end
    local actorUnit = addon.WorldAllyUnit(attacker)
    local faction = Readable(UnitFactionGroup("player"))
    if not actorUnit or (faction ~= "Alliance" and faction ~= "Horde") then
        addon.ObserveHonorKill()
        return
    end

    local name, unit = RivalName("target", victim, faction)
    if not addon.HasFullName(name) then
        local hoveredName, hoveredUnit = RivalName("mouseover", victim, faction)
        if not unit or addon.HasFullName(hoveredName) then
            name, unit = hoveredName, unit or hoveredUnit
        end
    end
    if not unit then
        addon.VisitVisibleNameplateUnits(function(token)
            name, unit = RivalName(token, victim, faction)
            return unit ~= nil
        end)
    end
    local context = addon.EncounterContext(unit)
    local opponent = not unit and addon.ObservedWorldOpponent(victim, context, attacker)
    local cached, started
    if not unit and not opponent and addon.ReadCombatContact then
        cached, started = addon.ReadCombatContact(victim)
    end
    if not unit and not opponent and started and addon.StageWorldKill then
        context.actorID = attacker
        context.actorName = addon.UnitPlayerName(actorUnit)
        context.actorAppearance = addon.UnitAppearance(actorUnit)
        context.actorLevel = context.actorAppearance.level
        context.killUptime = GetTime()
        context.cachedRival = cached and cached.opponent == true and cached.faction ~= faction and cached or nil
        local staged = addon.StageWorldKill(victim, context, started)
        if addon.NotePvPDiagnostic then addon.NotePvPDiagnostic(staged and "kill-staged" or "kill-window-unavailable") end
        if staged ~= "duplicate" then addon.ObserveHonorKill() end
        return
    end
    if unit or opponent then
        if opponent then name, context.rivalLevel = opponent.name, opponent.level end
        context.rivalAppearance = unit and addon.UnitAppearance(unit)
        context.actorID = attacker
        context.actorName = addon.UnitPlayerName(actorUnit)
        context.actorAppearance = addon.UnitAppearance(actorUnit)
        context.actorLevel = context.actorAppearance.level
        context.victimUnit = unit
        context.killUptime = GetTime and GetTime()
        Record(victim, name, context, false)
    else
        if addon.NotePvPDiagnostic then addon.NotePvPDiagnostic("kill-opponent-unresolved") end
        addon.ObserveHonorKill()
    end
end)
pcall(frame.RegisterEvent, frame, "PARTY_KILL")
