local _, addon = ...

local Readable = addon.Readable

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

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, _, attacker, victim)
    if not addon.db then
        return
    end

    local _, instanceType = IsInInstance()
    if Readable(instanceType) ~= "none" then
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
    local opponent = not unit and addon.ObservedWorldOpponent(victim, context)
    if unit or opponent then
        if opponent then name, context.rivalLevel = opponent.name, opponent.level end
        context.rivalAppearance = unit and addon.UnitAppearance(unit)
        context.actorID = attacker
        context.actorName = addon.UnitPlayerName(actorUnit)
        context.actorAppearance = addon.UnitAppearance(actorUnit)
        context.actorLevel = context.actorAppearance.level
        local id, battle = addon.RecordWorldEncounter(victim, name, "killsAgainstThem", context)
        addon.ObserveHonorKill(id, battle, victim)
    else
        addon.ObserveHonorKill()
    end
end)
pcall(frame.RegisterEvent, frame, "PARTY_KILL")
