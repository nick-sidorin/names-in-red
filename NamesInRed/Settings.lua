local _, addon = ...
local L = addon.L
local category
local resetPopup = "NAMES_IN_RED_RESET_DATA"

local function RequestReset()
    if not addon.db or not StaticPopupDialogs or not StaticPopup_Show then return end
    StaticPopupDialogs[resetPopup] = {
        text = L.resetDataConfirm,
        button1 = L.resetData,
        button2 = CANCEL,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = addon.ResetData,
    }
    StaticPopup_Show(resetPopup)
end

SLASH_NAMESINREDRESET1 = "/nirreset"
SlashCmdList.NAMESINREDRESET = RequestReset

local function RegisterSettings()
    if category then return true end
    if not addon.db or not Settings or not Settings.RegisterVerticalLayoutCategory or not Settings.RegisterProxySetting
        or not Settings.CreateCheckbox or not Settings.RegisterAddOnCategory or not Settings.OpenToCategory
        or not Settings.VarType or not Settings.VarType.Boolean or not CreateSettingsButtonInitializer then return end

    local options, layout = Settings.RegisterVerticalLayoutCategory(addon.title)
    local nameplates = Settings.RegisterProxySetting(
        options, "NAMES_IN_RED_NAMEPLATE_ICONS", Settings.VarType.Boolean, L.showNameplateIcons, true,
        addon.AreNameplateIconsEnabled, function(enabled)
            addon.db.showNameplateIcons = enabled
            addon.RefreshNameplates()
        end)
    Settings.CreateCheckbox(options, nameplates)
    local tooltip = Settings.RegisterProxySetting(
        options, "NAMES_IN_RED_UNIT_TOOLTIP", Settings.VarType.Boolean, L.showUnitTooltip, true,
        addon.IsUnitTooltipEnabled, function(enabled)
            addon.db.showUnitTooltip = enabled
            addon.RefreshUnitTooltip()
        end)
    Settings.CreateCheckbox(options, tooltip)

    local battlegrounds = Settings.RegisterProxySetting(
        options, "NAMES_IN_RED_TRACK_BATTLEGROUNDS", Settings.VarType.Boolean, L.trackBattlegrounds, true,
        addon.IsBattlegroundTrackingEnabled, addon.SetBattlegroundTrackingEnabled)
    Settings.CreateCheckbox(options, battlegrounds)
    layout:AddInitializer(CreateSettingsButtonInitializer("", L.resetData, RequestReset, nil, true))
    layout:AddInitializer(CreateSettingsButtonInitializer("", L.reportIssue, function() addon.OpenIssueReport() end, nil, true))
    Settings.RegisterAddOnCategory(options)
    category = options
    return true
end

function addon.OpenSettings()
    if RegisterSettings() then Settings.OpenToCategory(category:GetID()) end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    if RegisterSettings() then
        self:UnregisterEvent("ADDON_LOADED")
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
