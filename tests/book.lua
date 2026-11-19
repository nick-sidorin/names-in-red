local addon, callback, locale = { db = { rivals = {} } }, nil, "enUS"
function GetLocale() return locale end
function CreateFrame()
    return { RegisterEvent = function() end, SetScript = function() end }
end

local totalLines = 0
GameTooltip = {
    AddLine = function(_, text)
        assert(type(text) == "string" and text ~= "")
        totalLines = totalLines + 1
    end,
}
Enum = { TooltipDataType = { Unit = 2 } }
TooltipDataProcessor = {
    AddTooltipPostCall = function(kind, handler)
        assert(kind == Enum.TooltipDataType.Unit)
        callback = handler
    end,
}

for _, supported in ipairs({
    "enUS", "enGB", "ruRU", "deDE", "frFR", "esES", "esMX", "itIT", "ptBR", "koKR", "zhCN", "zhTW",
}) do
    locale = supported
    assert(loadfile("NamesInRed/Locale.lua"))("NamesInRed", addon)
    assert(addon.title == "Names in Red")
    assert(addon.L.deleteConfirm:format("Rival"):find("Rival", 1, true))
    for _, key in ipairs({ "kills", "deaths", "empty", "level", "add", "addTitle", "fullName", "win", "loss", "manual", "noMatches", "deleteConfirm", "statistics", "winTooltip", "lossTooltip" }) do
        assert(type(addon.L[key]) == "string" and addon.L[key] ~= "")
    end
end

local secret = {}
function issecretvalue(value) return value == secret end
assert(loadfile("NamesInRed/Encounter.lua"))("NamesInRed", addon)
assert(loadfile("NamesInRed/Book.lua"))("NamesInRed", addon)
addon.db.rivals["Player-test"] = { killsAgainstThem = 2, deathsToThem = 1 }
addon.db.rivals["Player-empty"] = { killsAgainstThem = 0, deathsToThem = 0 }
callback(GameTooltip, { guid = secret })
callback(GameTooltip, { guid = "Player-unknown" })
callback(GameTooltip, { guid = "Player-empty" })
callback({}, { guid = "Player-test" })
assert(totalLines == 0)
callback(GameTooltip, { guid = "Player-test" })
assert(totalLines == 2)
print("Rival tooltip and locale checks passed")

assert(loadfile("NamesInRed/Ledger.lua"))("NamesInRed", addon)
function UnitIsPlayer(unit) return unit == "target" end
function UnitName() return "Test Rival" end
local targetGUID = "Player-target"
function UnitGUID(unit) return unit == "target" and targetGUID or "Player-self" end

local target = assert(addon.ManualTarget())
targetGUID = "Player-other"
local id = addon.AddManualEncounter(target.name, "killsAgainstThem", target)
assert(id == "Player-target")
assert(addon.db.rivals[id].addedManually and addon.db.rivals[id].killsAgainstThem == 1)
assert(addon.AddManualEncounter("Different Rival", "deathsToThem", target) == "manual:different rival")
callback(GameTooltip, { guid = "Player-target" })
assert(totalLines == 4)
callback(GameTooltip, { guid = "Player-other" })
assert(totalLines == 4)
targetGUID = secret
assert(addon.ManualTarget() == nil)
targetGUID = "Player-self"
assert(addon.ManualTarget() == nil)
print("Target-linked manual tooltip checks passed")

function UnitIsPlayer(unit) return unit == "target" or unit == "mouseover" end
local surname = "Топичмолоток"
function UnitName() return "Айро", surname end
targetGUID = "Player-ayro"
assert(addon.ManualTarget().name == "Айро Топичмолоток")

local manualID = assert(addon.AddManualEncounter("Айро\194\160Топичмолоток", "deathsToThem"))
local manualRival = addon.db.rivals[manualID]
function GameTooltip:GetUnit() return "Айро", "mouseover", "Player-ayro" end
callback(GameTooltip, { guid = "Player-ayro" })
assert(totalLines == 6)
assert(addon.db.rivals[manualID] == manualRival and manualRival.deathsToThem == 1)
assert(addon.db.rivals["Player-ayro"] == nil)
surname = nil
callback(GameTooltip, { guid = "Player-ayro" })
assert(totalLines == 6)
surname = "Топичмолоток"
addon.db.rivals["Player-namesake"] = { displayName = "Айро Топичмолоток", killsAgainstThem = 2, deathsToThem = 0 }
callback(GameTooltip, { guid = "Player-ayro" })
assert(totalLines == 6)
assert(addon.AddManualEncounter(addon.ManualTarget().name, "killsAgainstThem", addon.ManualTarget()) == "Player-ayro")
callback(GameTooltip, { guid = secret })
assert(totalLines == 8)
print("Full-name manual tooltip checks passed")
