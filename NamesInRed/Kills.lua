local _, addon = ...

local Readable = addon.Readable

local function RivalName(unit, victim, faction)
    if Readable(UnitGUID(unit)) ~= victim or Readable(UnitIsPlayer(unit)) ~= true
        or Readable(UnitCanAttack("player", unit)) ~= true then
        return nil
    end

    local rivalFaction = Readable(UnitFactionGroup(unit))
    if (rivalFaction == "Alliance" or rivalFaction == "Horde") and rivalFaction ~= faction then
        return Readable(UnitName(unit)), unit
    end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, _, attacker, victim)
    if not addon.db then
        return
    end

    attacker, victim = Readable(attacker), Readable(victim)
    if type(victim) ~= "string" or not victim:match("^Player%-.+")
        or type(attacker) ~= "string" or attacker ~= Readable(UnitGUID("player"))
        or attacker == victim then
        return
    end

    local _, instanceType = IsInInstance()
    if Readable(instanceType) ~= "none" then
        return
    end

    local faction = Readable(UnitFactionGroup("player"))
    if faction ~= "Alliance" and faction ~= "Horde" then
        return
    end

    local name, unit = RivalName("target", victim, faction)
    if not name then
        name, unit = RivalName("mouseover", victim, faction)
    end
    if type(name) == "string" and name ~= "" then
        addon.RecordEncounter(victim, name, "killsAgainstThem", addon.EncounterContext(unit))
    end
end)
pcall(frame.RegisterEvent, frame, "PARTY_KILL")
