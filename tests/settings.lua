local addon, frames = {}, {}
local shortcut
local function Noop() end

function GetLocale() return "ruRU" end

local function Region()
    local region = { events = {}, scripts = {} }
    function region:RegisterEvent(event) self.events[event] = true end
    function region:UnregisterEvent(event) self.events[event] = nil end
    function region:SetScript(event, handler) self.scripts[event] = handler end
    function region:RegisterForClicks(...) self.clicks = { ... } end
    function region:RegisterForDrag(...) self.drags = { ... } end
    function region:CreateTexture() return Region() end
    function region:CreateMaskTexture() return Region() end
    return setmetatable(region, { __index = function(_, key) if key:match("^%u") then return Noop end end })
end

function CreateFrame(_, name)
    local frame = Region()
    if name then
        assert(name == "NamesInRedMinimapButton")
        shortcut = frame
    end
    frames[#frames + 1] = frame
    return frame
end

local function Event(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] then frame.scripts.OnEvent(frame, event, ...) end
    end
end

Minimap = Region()
function Minimap:GetWidth() return 160 end
function Minimap:GetHeight() return 160 end
function Minimap:GetFrameLevel() return 4 end
GameTooltip = {
    IsOwned = function(self, owner) return self.owner == owner end,
    SetOwner = function(self, owner) self.owner = owner end,
    SetText = function() end,
    AddLine = function(self, line) self.line = line end,
    Show = function() end,
    Hide = function(self) self.owner = nil end,
}

NamesInRedDB = { version = 1, rivals = {}, minimapAngle = 139 }
SlashCmdList = {}
for _, file in ipairs({ "Locale", "Ledger", "Encounter", "Core", "Portraits", "Book", "Settings" }) do
    assert(loadfile("NamesInRed/" .. file .. ".lua"))("NamesInRed", addon)
end
Event("ADDON_LOADED", "NamesInRed")

local category = { GetID = function() return 901 end }
local registered, opened = 0, 0
local rows = {}
Settings = {
    VarType = { Boolean = "boolean" },
    RegisterVerticalLayoutCategory = function(title)
        assert(title == "Names in Red")
        return category, { AddInitializer = function(_, row) rows[#rows + 1] = row end }
    end,
    RegisterProxySetting = function(owner, id, valueType, label, default, get, set)
        assert(owner == category and valueType == "boolean" and default == true)
        return { id = id, label = label, get = get, set = set }
    end,
    CreateCheckbox = function(owner, setting)
        assert(owner == category)
        rows[#rows + 1] = setting
    end,
    RegisterAddOnCategory = function(owner)
        assert(owner == category)
        registered = registered + 1
    end,
    OpenToCategory = function(id)
        assert(id == category:GetID())
        opened = opened + 1
    end,
}
function CreateSettingsButtonInitializer(_, label, click) return { label = label, click = click } end

local badgeRefreshes, tooltipRefreshes, journalRefreshes = 0, 0, 0
function addon.RefreshNameplates() badgeRefreshes = badgeRefreshes + 1 end
function addon.RefreshUnitTooltip() tooltipRefreshes = tooltipRefreshes + 1 end
function addon.RefreshBook(resetSearch)
    assert(resetSearch)
    journalRefreshes = journalRefreshes + 1
end

Event("PLAYER_LOGIN")
assert(registered == 1 and #rows == 4 and opened == 0)
assert(rows[1].label == addon.L.showNameplateIcons and rows[2].label == addon.L.showUnitTooltip)
assert(rows[1].get() and rows[2].get())
rows[1].set(false)
assert(not rows[1].get() and rows[2].get() and badgeRefreshes == 1)
rows[2].set(false)
assert(not rows[2].get() and not rows[1].get() and tooltipRefreshes == 1)

assert(shortcut.clicks[2] == "RightButtonUp" and #shortcut.drags == 1 and shortcut.drags[1] == "LeftButton")
shortcut.scripts.OnEnter(shortcut)
assert(GameTooltip.line:find("ПКМ — открыть настройки", 1, true))
shortcut.scripts.OnClick(shortcut, "RightButton")
assert(opened == 1 and GameTooltip.owner == nil and registered == 1)
shortcut.scripts.OnDragStart(shortcut)
shortcut.scripts.OnClick(shortcut, "RightButton")
shortcut.scripts.OnDragStop(shortcut)
shortcut.scripts.OnClick(shortcut, "LeftButton")
assert(opened == 1)

local db = addon.db
local rivalID = "Player-rival"
addon.Ledger.Add(db, rivalID, "Test Rival")
addon.Ledger.SaveSkirmish(db, "one", {
    rosterComplete = true,
    allies = { { id = "me", isSelf = true } },
    enemies = { { id = "them", rivalID = rivalID } },
    events = { { kind = "kill", actorID = "me", targetID = "them" } },
})
assert(addon.Ledger.PersonalScore(db, rivalID) == 1)
db.lastDeathTimestamp, db.encounterSequence = 20, 7

StaticPopupDialogs = {}
CANCEL, CLOSE = "Cancel", "Close"
local shown
function StaticPopup_Show(key) shown = assert(StaticPopupDialogs[key]) end

assert(rows[3].label == addon.L.resetData and rows[4].label == "Сообщить о проблеме")
local resetCommand = SlashCmdList.NAMESINREDRESET
assert(SLASH_NAMESINREDRESET1 == "/nirreset" and resetCommand == rows[3].click)
local showPopup = StaticPopup_Show
StaticPopup_Show = nil
resetCommand("")
assert(addon.Ledger.PersonalScore(db, rivalID) == 1 and journalRefreshes == 0)
StaticPopup_Show = showPopup
rows[3].click()
assert(shown.button2 == CANCEL and shown.hideOnEscape and addon.Ledger.PersonalScore(db, rivalID) == 1)
if shown.OnCancel then shown.OnCancel() end
assert(addon.Ledger.PersonalScore(db, rivalID) == 1 and journalRefreshes == 0)
resetCommand("")
shown.OnAccept()
assert(next(db.rivals) == nil and db.skirmishes == nil)
assert(db.lastDeathTimestamp == nil and db.encounterSequence == nil)
assert(addon.Ledger.PersonalScore(db, rivalID) == 0)
assert(db == NamesInRedDB and db.minimapAngle == 139 and not rows[1].get() and not rows[2].get())
assert(journalRefreshes == 1 and badgeRefreshes == 2 and tooltipRefreshes == 2)

local reportOpens = 0
function addon.OpenIssueReport() reportOpens = reportOpens + 1 end
rows[4].click()
assert(reportOpens == 1)
print("Native settings, minimap shortcut, confirmed reset and Issues link checks passed")
