local _, addon = ...
local Readable = addon.Readable
local active = {}
local badges = {}

local function Hide(unit)
    local badge = active[unit]
    if badge and badge.unit == unit then
        badge:Hide()
        badge.unit = nil
    end
end

local function Refresh(unit)
    Hide(unit)
    active[unit] = false
    if not addon.db or not addon.AreNameplateIconsEnabled() then return end

    local guid = Readable(UnitGUID(unit))
    local playerGUID = Readable(UnitGUID("player"))
    if type(guid) ~= "string" or not guid:match("^Player%-.+") or type(playerGUID) ~= "string"
        or guid == playerGUID then return end
    local rival, id = addon.FindVisibleRival(guid, unit)
    local text = rival and addon.RivalCounters(id, true)
    if not text then return end

    local plate = Readable(C_NamePlate.GetNamePlateForUnit(unit))
    if not plate or plate:IsForbidden() or Readable(plate.unitToken) ~= unit then return end
    local parent = Readable(plate.UnitFrame)
    if not parent or parent:IsForbidden() then return end

    local anchor = parent.name
    if not anchor or anchor:IsForbidden() or not anchor:IsShown() then
        anchor = parent.HealthBarsContainer and parent.HealthBarsContainer.healthBar
        if not anchor or anchor:IsForbidden() or not anchor:IsShown() then return end
    end

    local badge = badges[parent]
    if not badge then
        badge = CreateFrame("Frame", nil, parent)
        badge:SetSize(1, 14)
        badge.label = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmallOutline")
        badge.label:SetTextColor(1, 1, 1)
        badge.label:SetPoint("CENTER")
        badges[parent] = badge
    end
    if badge.unit then active[badge.unit] = false end
    badge:ClearAllPoints()
    badge:SetPoint("BOTTOM", anchor, "TOP", 0, 0)
    badge.label:SetText(text)
    badge.unit = unit
    active[unit] = badge
    badge:Show()
end

function addon.RefreshNameplates()
    for unit in pairs(active) do Refresh(unit) end
end

if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
    local events = CreateFrame("Frame")
    events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    events:RegisterEvent("UNIT_NAME_UPDATE")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("PLAYER_LEAVING_WORLD")
    events:SetScript("OnEvent", function(_, event, token)
        if event == "PLAYER_LEAVING_WORLD" then
            for unit in pairs(active) do Hide(unit) end
            active = {}
        elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            addon.RefreshNameplates()
        else
            local unit = Readable(token)
            if type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
            if event == "NAME_PLATE_UNIT_REMOVED" then
                Hide(unit)
                active[unit] = nil
            elseif event == "NAME_PLATE_UNIT_ADDED" or active[unit] ~= nil then
                Refresh(unit)
            end
        end
    end)
end
