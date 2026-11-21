local _, addon = ...
local L = addon.L
local category
local resetPopup = "NAMES_IN_RED_RESET_DATA"
local reportPopup = "NAMES_IN_RED_REPORT_ISSUE"
local issuesURL = "https://github.com/nick-sidorin/names-in-red/issues"

local function RequestReset()
    if not StaticPopupDialogs or not StaticPopup_Show then return end
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

local function ShowIssuesLink()
    if not StaticPopupDialogs or not StaticPopup_Show then
        print(L.reportIssueLink .. " " .. issuesURL)
        return
    end
    StaticPopupDialogs[reportPopup] = {
        text = L.reportIssueLink,
        button1 = CLOSE,
        hasEditBox = true,
        editBoxWidth = 410,
        maxLetters = 0,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnShow = function(dialog)
            local box = dialog:GetEditBox()
            box:SetText(issuesURL)
            box:SetFocus()
            box:HighlightText()
        end,
    }
    StaticPopup_Show(reportPopup)
end

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
    layout:AddInitializer(CreateSettingsButtonInitializer("", L.resetData, RequestReset, nil, true))
    layout:AddInitializer(CreateSettingsButtonInitializer("", L.reportIssue, ShowIssuesLink, nil, true))
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
