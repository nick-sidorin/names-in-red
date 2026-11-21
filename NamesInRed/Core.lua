local addonName, addon = ...
local artPath = "Interface\\AddOns\\NamesInRed\\Art\\"
addon.swordsIconPath = artPath .. "CrossedSwords.tga"
addon.skullIconPath = artPath .. "Skull.tga"
addon.smallSkullIconPath = artPath .. "TooltipSkull.tga"
addon.smallSwordsInset = 22

function addon.AreNameplateIconsEnabled()
    return not addon.db or addon.db.showNameplateIcons ~= false
end

function addon.IsUnitTooltipEnabled()
    return not addon.db or addon.db.showUnitTooltip ~= false
end

function addon.ResetData()
    if not addon.db then return end
    if addon.CancelPendingDeath then addon.CancelPendingDeath() end
    addon.Ledger.Clear(addon.db)
    if addon.ClearDiagnostics then addon.ClearDiagnostics() end
    if addon.RefreshBook then addon.RefreshBook(true) end
    if addon.RefreshNameplates then addon.RefreshNameplates() end
    if addon.RefreshUnitTooltip then addon.RefreshUnitTooltip() end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedName)
    if event == "PLAYER_TARGET_CHANGED" then
        addon.ResolveRivalName("target")
        return
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        addon.ResolveRivalName("mouseover")
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        addon.ResolveRivalName("target")
        addon.ResolveRivalName("mouseover")
        return
    elseif loadedName ~= addonName then
        return
    end
    self:UnregisterEvent("ADDON_LOADED")

    local db = addon.Ledger.Open(NamesInRedDB)
    if db then
        NamesInRedDB = db
        addon.db = db
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
        self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
end)
