local addonName, addon = ...
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, loadedName)
    if loadedName ~= addonName then
        return
    end
    self:UnregisterEvent("ADDON_LOADED")

    local db = addon.Ledger.Open(NamesInRedDB)
    if db then
        NamesInRedDB = db
        addon.db = db
    end
end)
