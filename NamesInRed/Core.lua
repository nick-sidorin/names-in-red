local addonName, addon = ...
local artPath = "Interface\\AddOns\\NamesInRed\\Art\\"
addon.swordsIconPath = artPath .. "CrossedSwords.tga"
addon.smallSkullIconPath = artPath .. "TooltipSkull.tga"
addon.defeatBannerPath = artPath .. "DefeatBanner.tga"
addon.defeatStatIconPath = artPath .. "DefeatStatIcon.tga"
addon.battlefieldArtPath = artPath .. "Battlefield.tga"
addon.levelBadgePath = artPath .. "LevelBadge.tga"
addon.smallSwordsInset = 22

function addon.IsHonorCurrency(id)
    local currencies = Constants and Constants.CurrencyConsts
    return currencies and type(id) == "number" and (id == currencies.CLASSIC_HONOR_CURRENCY_ID
        or id == currencies.HONOR_CURRENCY_ID or id == currencies.ACCOUNT_WIDE_HONOR_CURRENCY_ID)
end

local function CurrencyIcon(info, fromList)
    info = addon.Readable(info)
    if type(info) ~= "table" or (canaccesstable and not canaccesstable(info)) then return end
    if fromList and not addon.IsHonorCurrency(addon.Readable(info.currencyID)) then return end
    local icon = addon.Readable(info.iconFileID)
    if type(icon) == "number" and icon > 0 then return icon end
end

function addon.HonorIconTexture(faction)
    local currency = C_CurrencyInfo
    if currency then
        -- The Currency tab uses the iconFileID supplied by the currency list.
        local size = currency.GetCurrencyListSize and addon.Readable(currency.GetCurrencyListSize())
        if type(size) == "number" and currency.GetCurrencyListInfo then
            for index = 1, size do
                local icon = CurrencyIcon(currency.GetCurrencyListInfo(index), true)
                if icon then return icon end
            end
        end
        -- The category can be collapsed or the currency hidden from the list.
        local currencies = Constants and Constants.CurrencyConsts
        local honorID = currencies and currencies.CLASSIC_HONOR_CURRENCY_ID
        local icon = honorID and currency.GetCurrencyInfo and CurrencyIcon(currency.GetCurrencyInfo(honorID))
        if icon then return icon end
    end
    local currencies = Constants and Constants.CurrencyConsts
    if faction == "Horde" then return currencies and currencies.PVP_CURRENCY_HONOR_HORDE_INV_ICON or 463451 end
    return currencies and currencies.PVP_CURRENCY_HONOR_ALLIANCE_INV_ICON or 463450
end

function addon.HonorableKillIconPath(faction)
    local rank = faction == "Horde" and "H" or "A"
    return "Interface\\Icons\\Achievement_PVP_" .. rank .. "_12"
end

function addon.AreNameplateIconsEnabled()
    return not addon.db or addon.db.showNameplateIcons ~= false
end

function addon.IsUnitTooltipEnabled()
    return not addon.db or addon.db.showUnitTooltip ~= false
end

function addon.ResetData()
    if not addon.db then return end
    if addon.CancelPendingDeath then addon.CancelPendingDeath() end
    if addon.ResetWorldTracking then addon.ResetWorldTracking() end
    if addon.ResetHonorTracking then addon.ResetHonorTracking() end
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
        if addon.RestoreDeathLevels then addon.RestoreDeathLevels(db, NamesInRedDebugDB) end
        NamesInRedDB = db
        addon.db = db
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
        self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
end)
