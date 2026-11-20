local addon, callback, locale = { db = { rivals = {} } }, nil, "enUS"
function GetLocale() return locale end
function CreateFrame()
    return { RegisterEvent = function() end, SetScript = function() end }
end

local tooltipLines = {}
GameTooltip = {
    AddLine = function(_, text)
        assert(type(text) == "string" and text ~= "")
        table.insert(tooltipLines, text)
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
    for _, key in ipairs({
        "kills", "deaths", "empty", "level", "add", "addTitle", "fullName", "win", "loss", "manual",
        "noMatches", "deleteConfirm", "statistics", "winTooltip", "lossTooltip", "infoTab", "historyTab",
        "latestEncounter", "showOnMap", "unknownLocation", "myLevel", "rivalLevel", "waypointError", "noSkirmishes",
        "rivalsView", "recentView", "unknownRival",
    }) do
        assert(type(addon.L[key]) == "string" and addon.L[key] ~= "")
    end
end

local secret = {}
function issecretvalue(value) return value == secret end
assert(loadfile("NamesInRed/Encounter.lua"))("NamesInRed", addon)
assert(loadfile("NamesInRed/EncounterCards.lua"))("NamesInRed", addon)
assert(loadfile("NamesInRed/Book.lua"))("NamesInRed", addon)
addon.db.rivals["Player-test"] = { displayName = "Test Rival", killsAgainstThem = 2, deathsToThem = 1 }
addon.db.rivals["Player-empty"] = { displayName = "Empty Rival", killsAgainstThem = 0, deathsToThem = 0 }
addon.db.rivals["Player-partial"] = { displayName = "Rival", killsAgainstThem = 1, deathsToThem = 0 }
callback(GameTooltip, { guid = secret })
callback(GameTooltip, { guid = "Player-unknown" })
callback(GameTooltip, { guid = "Player-empty" })
callback(GameTooltip, { guid = "Player-partial" })
callback({}, { guid = "Player-test" })
assert(#tooltipLines == 0)
callback(GameTooltip, { guid = "Player-test" })
assert(#tooltipLines == 3)
assert(tooltipLines[1] == " ")
assert(tooltipLines[2] == addon.title)
local art = "|TInterface\\AddOns\\NamesInRed\\Art\\"
local victory = art .. "TooltipVictory.tga:14:14:0:1|t"
local death = art .. "TooltipSkull.tga:14:14:0:1|t"
assert(tooltipLines[3] == victory .. " 2   " .. death .. " 1")
print("Rival tooltip and locale checks passed")

assert(loadfile("NamesInRed/Ledger.lua"))("NamesInRed", addon)
function UnitIsPlayer(unit) return unit == "target" end
function UnitName() return "Test Rival" end
local targetGUID = "Player-target"
function UnitGUID(unit) return unit == "target" and targetGUID or "Player-self" end
local targetLevel = 42
function UnitLevel() return targetLevel end
function UnitRace() return "Human", "Human" end
function UnitSex() return 3 end
function UnitClass() return "Mage", "MAGE" end
function UnitFactionGroup() return "Alliance", "Alliance" end

local target = assert(addon.ManualTarget())
targetGUID = "Player-other"
targetLevel = 77
local id = addon.AddManualEncounter(target.name, "killsAgainstThem", target)
assert(id == "Player-target")
local linked = addon.db.rivals[id]
assert(linked.addedManually and linked.killsAgainstThem == 1)
assert(linked.race == "human" and linked.raceLabel == "Human" and linked.sex == 3)
assert(linked.class == "MAGE" and linked.classLabel == "Mage" and linked.factionLabel == "Alliance")
assert(linked.encounters[1].rivalLevel == 42 and linked.encounters[1].time == nil)
local differentID = addon.AddManualEncounter("Different Rival", "deathsToThem", target)
assert(differentID == "manual:different rival")
local different = addon.db.rivals[differentID]
assert(not different.race and not different.class and not different.factionLabel and not different.encounters[1].rivalLevel)
callback(GameTooltip, { guid = "Player-target" })
assert(#tooltipLines == 6)
callback(GameTooltip, { guid = "Player-other" })
assert(#tooltipLines == 6)
targetGUID = secret
assert(addon.ManualTarget() == nil)
targetGUID = "Player-self"
assert(addon.ManualTarget() == nil)
targetGUID, targetLevel = "Player-restricted", secret
assert(addon.ManualTarget().level == nil)
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
assert(#tooltipLines == 9)
assert(tooltipLines[9] == victory .. " 0   " .. death .. " 1")
assert(addon.db.rivals[manualID] == manualRival and manualRival.deathsToThem == 1)
assert(addon.db.rivals["Player-ayro"] == nil)
surname = nil
callback(GameTooltip, { guid = "Player-ayro" })
assert(#tooltipLines == 9)
surname = "Топичмолоток"
addon.db.rivals["Player-namesake"] = { displayName = "Айро Топичмолоток", killsAgainstThem = 2, deathsToThem = 0 }
callback(GameTooltip, { guid = "Player-ayro" })
assert(#tooltipLines == 9)
assert(addon.AddManualEncounter(addon.ManualTarget().name, "killsAgainstThem", addon.ManualTarget()) == "Player-ayro")
callback(GameTooltip, { guid = secret })
assert(#tooltipLines == 12)
print("Full-name manual tooltip checks passed")
