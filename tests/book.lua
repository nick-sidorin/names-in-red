local addon, callback, locale = { db = { rivals = {} } }, nil, "enUS"
function GetLocale() return locale end
function CreateFrame()
    return { RegisterEvent = function() end, SetScript = function() end }
end

local tooltipLines = {}
GameTooltip = {
    IsOwned = function() return false end,
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
        "wins", "losses", "empty", "level", "add", "addTitle", "fullName", "win", "loss", "manual",
        "noMatches", "deleteConfirm", "personalScore", "winTooltip", "lossTooltip", "infoTab", "historyTab",
        "latestEncounter", "showOnMap", "unknownLocation", "myLevel", "rivalLevel", "waypointError", "noSkirmishes",
        "rivalsView", "recentView", "unknownRival",
        "alliedSide", "enemySide", "partialRoster", "finishingBlows", "unknownPlayer", "minimapHint",
        "openSkirmish",
    }) do
        assert(type(addon.L[key]) == "string" and addon.L[key] ~= "")
    end
end

local secret = {}
function issecretvalue(value) return value == secret end
assert(loadfile("NamesInRed/Ledger.lua"))("NamesInRed", addon)
assert(loadfile("NamesInRed/Encounter.lua"))("NamesInRed", addon)
assert(loadfile("NamesInRed/EncounterCards.lua"))("NamesInRed", addon)
assert(loadfile("NamesInRed/Core.lua"))("NamesInRed", addon)
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
local victory = art .. "CrossedSwords.tga:14:14:0:1:128:128:22:106:22:106|t"
local death = art .. "TooltipSkull.tga:14:14:0:1|t"
assert(tooltipLines[3] == victory .. " 2   " .. death .. " 1")
print("Rival tooltip and locale checks passed")

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

local function MockRegion(parent)
    local region = { parent = parent, children = {}, shown = true, scripts = {} }
    if parent then parent.children[#parent.children + 1] = region end
    function region:CreateFontString() return MockRegion(self) end
    function region:CreateTexture() return MockRegion(self) end
    function region:CreateMaskTexture() return MockRegion(self) end
    function region:SetText(text)
        assert(text ~= nil)
        self.text = text
    end
    function region:SetShown(shown) self.shown = shown end
    function region:Hide() self:SetShown(false) end
    function region:SetHeight(height) self.height = height end
    function region:SetScript(event, handler) self.scripts[event] = handler end
    function region:SetOnClickHandler(handler) self.scripts.OnClick = handler end
    function region:SetTooltipInfo(title) self.title = title end
    return setmetatable(region, { __index = function() return function() end end })
end

function CreateFrame(_, _, parent, template)
    local region = MockRegion(parent)
    if template == "CommonSquareIconButtonTemplate" then region.Icon = MockRegion(region) end
    return region
end
assert(loadfile("NamesInRed/ManualDialog.lua"))("NamesInRed", addon)
function addon.ApplyAtlas(region, atlas)
    region.atlas = atlas
    return true
end
date = os.date
local selectedRival
local card = addon.CreateSkirmishCard(MockRegion(), 630, function() end, function(id) selectedRival = id end)
local allies = { { id = "me", name = "My Character", isSelf = true }, { id = "ally", name = "Ally Warrior" } }
local enemies = {
    { id = "enemy", name = "Test Rival", rivalID = "Player-test", class = "MAGE", level = 42 },
    { id = "other", name = "Other Rival" },
}
local large = { time = 100, startedAt = 80, mapID = 1424, x = 0.45, y = 0.51,
    allies = allies, enemies = enemies, rosterComplete = true, events = {
    { actorID = "ally", targetID = "enemy", time = 91 }, { actorID = "other", targetID = "me", time = 97 },
} }
local function FindRegion(region, key, expected)
    if not region.shown then return end
    if rawget(region, key) == expected then return region end
    for _, child in ipairs(region.children) do
        local match = FindRegion(child, key, expected)
        if match then return match end
    end
end
local function FindText(region, expected)
    return FindRegion(region, "text", expected)
end
card:SetSkirmish(large, "Player-test")
local largeHeight = card.height
assert(FindText(card, "2 × 2") and FindText(card, "Ally Warrior") and FindText(card, "0:11"))
assert(FindText(card, addon.L.showOnMap) and not FindText(card, "45.0, 51.0"))
local name = assert(FindText(card, "Test Rival"))
assert(name.parent.selection.shown)
name.parent.scripts.OnClick(name.parent)
assert(selectedRival == "Player-test")
card:SetSkirmish({ allies = { allies[1] }, enemies = { enemies[1] }, events = {} })
assert(not name.parent.selection.shown)
assert(card.height < largeHeight and FindText(card, addon.L.partialRoster))
assert(not FindText(card, "Ally Warrior") and not FindText(card, "Other Rival") and not FindText(card, "0:11"))
card:SetSkirmish(nil)
assert(not card.shown)
print("Skirmish card roster and recycling checks passed")

local openedSkirmish, openedMap, mapped
local compact = addon.CreateCompactEncounterCard(MockRegion(), 332, function() openedMap = true end,
    function(id) openedSkirmish = id end)
local first = { skirmishID = "battle-one", wins = 1, losses = 0, mapID = 1424, x = 0.45, y = 0.51,
    zone = "Hillsbrad Foothills", time = 100, player = allies[1], opponent = enemies[1],
    playerLevel = 51, rivalLevel = 42 }
compact:SetEncounter(first)
assert(FindText(compact, "Hillsbrad Foothills") and FindText(compact, date("%x", first.time)))
assert(FindText(compact, "My Character") and FindText(compact, "Test Rival"))
assert(FindText(compact, 51) and FindText(compact, 42))
assert(FindRegion(compact, "atlas", "common-icon-forwardarrow"))
assert(not FindRegion(compact, "atlas", "common-icon-backarrow"))
local open = assert(FindRegion(compact, "title", addon.L.openSkirmish))
local map = assert(FindRegion(compact, "title", addon.L.showOnMap))
assert(not FindText(compact, addon.L.openSkirmish) and not FindText(compact, addon.L.showOnMap))
open.scripts.OnClick()
assert(openedSkirmish == "battle-one")
addon.ShowEncounterWaypoint = function(encounter) mapped = encounter; return true end
map.scripts.OnClick()
assert(openedMap and mapped == first)

compact:SetEncounter({ skirmishID = "battle-loss", wins = 0, losses = 1 })
assert(FindRegion(compact, "atlas", "common-icon-backarrow"))
assert(not FindRegion(compact, "atlas", "common-icon-forwardarrow"))
compact:SetEncounter({ skirmishID = "battle-both", wins = 1, losses = 1 })
assert(FindRegion(compact, "atlas", "common-icon-backarrow") and FindRegion(compact, "atlas", "common-icon-forwardarrow"))
compact:SetEncounter({ skirmishID = "battle-two", wins = 0, losses = 0 })
assert(not FindRegion(compact, "atlas", "common-icon-backarrow") and not FindRegion(compact, "atlas", "common-icon-forwardarrow"))
assert(not FindText(compact, 51) and not FindText(compact, 42) and not map.shown)
open.scripts.OnClick()
assert(openedSkirmish == "battle-two")
local loadedSelfPortrait
function SetPortraitTexture(_, unit, disableMasking)
    assert(unit == "player" and disableMasking)
    loadedSelfPortrait = true
end
compact:SetEncounter({ direction = "killsAgainstThem" }, { displayName = "Legacy Rival" })
assert(FindText(compact, "Legacy Rival") and loadedSelfPortrait and not open.shown)
assert(FindRegion(compact, "atlas", "common-icon-forwardarrow"))
compact:SetEncounter(nil)
assert(not compact.shown)
print("Compact skirmish portraits, direction, actions and reuse checks passed")
