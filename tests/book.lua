local addon, callback, locale = { db = { rivals = {} } }, nil, "enUS"
function GetLocale() return locale end
function CreateFrame()
    return { RegisterEvent = function() end, SetScript = function() end }
end

local tooltipLines = {}
GameTooltip = {
    IsOwned = function(self, owner) return self.owner == owner end,
    SetOwner = function(self, owner) self.owner = owner end,
    SetText = function(self, title) self.title = title end,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown, self.owner = false, nil end,
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
        "openSkirmish", "partialRosterHint", "portraitDeath", "honorableKills", "honor", "unknownOutcome",
        "showNameplateIcons", "showUnitTooltip", "resetData", "resetDataConfirm", "reportIssue", "reportIssueLink",
    }) do
        assert(type(addon.L[key]) == "string" and addon.L[key] ~= "")
    end
    local _, lineBreaks = addon.L.minimapHint:gsub("\n", "")
    assert(lineBreaks == 2)
end

local secret = {}
function issecretvalue(value) return value == secret end
assert(loadfile("NamesInRed/Ledger.lua"))("NamesInRed", addon)
assert(loadfile("NamesInRed/Encounter.lua"))("NamesInRed", addon)
assert(loadfile("NamesInRed/EncounterCards.lua"))("NamesInRed", addon)
assert(loadfile("NamesInRed/Core.lua"))("NamesInRed", addon)
assert(loadfile("NamesInRed/Book.lua"))("NamesInRed", addon)
addon.db.rivals["Player-test"] = { displayName = "Test Rival", encounters = { { outcome = "win" }, { outcome = "win" }, { outcome = "loss" } } }
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
addon.db.showUnitTooltip = false
callback(GameTooltip, { guid = "Player-test" })
assert(#tooltipLines == 3)
addon.db.showUnitTooltip = true
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
    function region:SetTextColor(r, g, b) self.color = { r, g, b } end
    function region:SetPoint(...) self.anchor = { ... } end
    function region:SetAllPoints(target) self.bounds = target end
    function region:SetSize(width, height) self.width, self.height = width, height end
    function region:SetTexture(texture) self.texture, self.atlas = texture, nil end
    function region:SetTexCoord(...) self.texcoords = { ... } end
    function region:SetAtlas(atlas, _, _, resetTexCoords)
        -- Reassigning an atlas already on the texture preserves its custom coordinates.
        if self.atlas ~= atlas or resetTexCoords then self:SetTexCoord(0, 1, 0, 1) end
        self.atlas = atlas
    end
    function region:SetHitRectInsets(...) self.insets = { ... } end
    function region:SetShown(shown) self.shown = shown end
    function region:Hide() self:SetShown(false) end
    function region:SetHeight(height) self.height = height end
    function region:SetScript(event, handler) self.scripts[event] = handler end
    function region:HookScript(event, handler)
        local previous = self.scripts[event]
        self:SetScript(event, function(...)
            if previous then previous(...) end
            handler(...)
        end)
    end
    function region:SetOnClickHandler(handler) self.scripts.OnClick = handler end
    function region:SetTooltipInfo(title) self.title = title end
    return setmetatable(region, { __index = function() return function() end end })
end


function CreateFrame(_, _, parent, template)
    local region = MockRegion(parent)
    region.template = template
    if template == "CommonSquareIconButtonTemplate" then
        region.Icon = MockRegion(region)
        region:SetScript("OnMouseUp", function(self) self.Icon:SetPoint("CENTER", self, "CENTER", -1, 0) end)
    end
    return region
end
assert(loadfile("NamesInRed/ManualDialog.lua"))("NamesInRed", addon)
C_Texture = {
    GetAtlasInfo = function()
        return { leftTexCoord = 0.2, rightTexCoord = 0.4, topTexCoord = 0.3, bottomTexCoord = 0.5 }
    end,
}
date = os.date
local selectedRival, journalMapOpened
local card = addon.CreateSkirmishCard(MockRegion(), 630, function() journalMapOpened = true end,
    function(id) selectedRival = id end)
local allies = { { id = "me", name = "My Character", isSelf = true }, { id = "ally", name = "Ally Warrior" } }
local enemies = {
    { id = "enemy", name = "Test Rival", rivalID = "Player-test", class = "MAGE", level = 42 },
    { id = "other", name = "Other Rival" },
}
local large = { time = 100, startedAt = 80, zone = "Hillsbrad Foothills", mapID = 1424, x = 0.45, y = 0.51,
    allies = allies, enemies = enemies, rosterComplete = true, events = {
    { kind = "kill", actorID = "ally", targetID = "enemy", time = 91 },
    { kind = "revive", targetID = "enemy", time = 95 },
    { kind = "kill", actorID = "other", targetID = "me", time = 97 },
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
local faction = "Alliance"
function UnitFactionGroup(unit)
    assert(unit == "player")
    return faction
end
local function CheckFactionColors(left, right)
    assert(left.color[3] > left.color[1] and right.color[1] > right.color[3])
end
card:SetSkirmish(large, "Player-test")
local largeHeight = card.height
assert(FindText(card, "2 × 2") and FindText(card, "Ally Warrior") and FindText(card, "0:11"))
assert(not FindText(card, "0:15"))
assert(not FindText(card, addon.L.showOnMap) and not FindText(card, "45.0, 51.0"))
local journalMap = assert(FindRegion(card, "title", addon.L.showOnMap))
local zone = assert(FindText(card, large.zone))
local stamp = assert(FindText(card, date("%x", large.time) .. "  " .. date("%H:%M", large.time)))
assert(journalMap.template == "CommonSquareIconButtonTemplate" and stamp.anchor[4] < journalMap.anchor[4])
assert(zone.anchor[5] == stamp.anchor[5] and stamp.anchor[5] == journalMap.anchor[5])
assert(FindText(card, "2 × 2").anchor[5] == stamp.anchor[5] - 2)
local eventTitle, firstTime = FindText(card, addon.L.finishingBlows), FindText(card, "0:11")
local secondTime = FindText(card, "0:17")
assert(eventTitle.anchor[3] - firstTime.anchor[3] == firstTime.anchor[3] - secondTime.anchor[3])
addon.ShowEncounterWaypoint = function(battle) assert(battle == large); return true end
journalMap.scripts.OnClick()
assert(journalMapOpened)
assert(not FindRegion(card, "template", "UIPanelInfoButton"))
local allyHeading, enemyHeading = FindText(card, addon.L.alliedSide), FindText(card, addon.L.enemySide)
CheckFactionColors(allyHeading, enemyHeading)
faction = "Horde"
card:SetSkirmish(large, "Player-test")
CheckFactionColors(enemyHeading, allyHeading)
faction = "Alliance"
local name = assert(FindText(card, "Test Rival"))
assert(name.parent.selection.shown)
name.parent.scripts.OnClick(name.parent)
assert(selectedRival == "Player-test")
card:SetSkirmish({ allies = { allies[1] }, enemies = { enemies[1] }, events = {} })
assert(not name.parent.selection.shown)
local partialCount = assert(FindText(card, "1 × 1"))
assert(card.height < largeHeight and not FindText(card, addon.L.partialRoster))
assert(not journalMap.shown)
assert(not FindText(card, "Ally Warrior") and not FindText(card, "Other Rival") and not FindText(card, "0:11"))
local rosterHint = assert(FindRegion(card, "template", "UIPanelInfoButton"))
assert(rosterHint.anchor[2] == partialCount and rosterHint.anchor[4] > 0)
rosterHint.scripts.OnEnter(rosterHint)
assert(GameTooltip.shown and GameTooltip.title == addon.L.partialRoster)
assert(tooltipLines[#tooltipLines] == addon.L.partialRosterHint)
card:SetSkirmish(nil)
assert(not card.shown and not GameTooltip.shown)
print("Skirmish card roster and recycling checks passed")

local openedSkirmish, openedMap, mapped
local compact = addon.CreateCompactEncounterCard(MockRegion(), 332, function() openedMap = true end,
    function(id) openedSkirmish = id end)
local first = { skirmishID = "battle-one", outcome = "win", opponentDeathIndex = 1, mapID = 1424, x = 0.45, y = 0.51,
    zone = "Hillsbrad Foothills", time = 100, player = allies[1], opponent = enemies[1],
    playerLevel = 51, rivalLevel = 42 }
first.player.race, first.player.sex = "orc", 2
first.opponent.race, first.opponent.sex = "human", 3
function GetRaceAtlas(race, gender) return race .. "-" .. gender end
compact:SetEncounter(first)
assert(FindText(compact, "Hillsbrad Foothills") and FindText(compact, date("%x", first.time)))
assert(FindText(compact, "Hillsbrad Foothills").anchor[1] == "LEFT")
assert(FindText(compact, "My Character") and FindText(compact, "Test Rival"))
assert(FindText(compact, 51).width == 24 and FindText(compact, 42).width == 24)
local myName, opponentName = FindText(compact, "My Character"), FindText(compact, "Test Rival")
local myRim, opponentRim = myName.anchor[2], opponentName.anchor[2]
assert(myRim.width == 64 and opponentRim.width == 64)
local playerPortrait = assert(FindRegion(compact, "atlas", "orc-male"))
local rivalPortrait = assert(FindRegion(compact, "atlas", "human-female"))
local function AssertFullPortrait(portrait, mirrored)
    local left, right, top, bottom = unpack(portrait.texcoords)
    assert(left == (mirrored and 1 or 0) and right == (mirrored and 0 or 1))
    assert(top == 0 and bottom == 1)
end
AssertFullPortrait(playerPortrait, false)
AssertFullPortrait(rivalPortrait, true)
local profilePortrait = MockRegion()
addon.SetRivalPortrait(profilePortrait, first.opponent)
AssertFullPortrait(profilePortrait, false)
local function PortraitMarker(anchor, texture)
    for _, child in ipairs(compact.children) do
        if child.shown and child.scripts.OnEnter and child.children[1] and child.children[1].texture == texture
            and child.anchor[2] == anchor then
            return child
        end
    end
end
local function CenterMarker(texture) return PortraitMarker(compact, texture) end
local function CheckPortraitMarker(rim, texture, corner)
    local marker = assert(PortraitMarker(rim, texture))
    local x = corner == "TOPRIGHT" and -10 or 10
    assert(marker.anchor[3] == corner and marker.anchor[4] == x and marker.anchor[5] == -10)
    return marker
end
local swords, skull = addon.swordsIconPath, addon.smallSkullIconPath
local victory = assert(CenterMarker(swords))
assert(victory.anchor[4] == 0 and not CenterMarker(skull))
local portraitDeath = CheckPortraitMarker(opponentRim, skull, "TOPLEFT")
assert(not PortraitMarker(myRim, skull) and not PortraitMarker(opponentRim, swords))
CheckFactionColors(myName, opponentName)
faction = "Horde"
compact:SetEncounter(first)
CheckFactionColors(opponentName, myName)
AssertFullPortrait(rivalPortrait, true)
compact:SetEncounter(first)
AssertFullPortrait(rivalPortrait, true)
faction = "Alliance"
local open = assert(FindRegion(compact, "title", addon.L.openSkirmish))
local map = assert(FindRegion(compact, "title", addon.L.showOnMap))
assert(not FindText(compact, addon.L.openSkirmish) and not FindText(compact, addon.L.showOnMap))
assert(open.width == 32 and map.width == 32 and open.Icon.width == 16 and map.Icon.width == 16)
assert(open.Icon.anchor[4] == 0 and map.Icon.anchor[4] == 0)
assert(open.Icon.anchor[5] == 0.5 and map.Icon.anchor[5] == 0.5 and journalMap.Icon.anchor[5] == 0)
map.scripts.OnMouseUp(map)
assert(map.Icon.anchor[4] == 0 and map.Icon.anchor[5] == 0.5)
local inset = map.insets[1]
local mapToInfo = open.anchor[2] - open.width + inset - (map.anchor[2] - inset)
local dateToMap = map.anchor[2] - map.width + inset - FindText(compact, date("%x", first.time)).anchor[2]
assert(mapToInfo == dateToMap and mapToInfo == 6)
open.scripts.OnClick()
assert(openedSkirmish == "battle-one")
addon.ShowEncounterWaypoint = function(encounter) mapped = encounter; return true end
map.scripts.OnClick()
assert(openedMap and mapped == first)

victory.scripts.OnEnter(victory)
assert(GameTooltip.shown and GameTooltip.title == addon.L.winTooltip)
compact:SetEncounter({ skirmishID = "battle-loss", outcome = "loss", playerDeathIndex = 1 })
assert(not GameTooltip.shown and not CenterMarker(swords))
local defeat = assert(CenterMarker(skull))
defeat.scripts.OnEnter(defeat)
assert(GameTooltip.shown and GameTooltip.title == addon.L.lossTooltip)
CheckPortraitMarker(myRim, skull, "TOPRIGHT")
assert(not PortraitMarker(opponentRim, swords) and defeat.anchor[4] == 0)
compact:SetEncounter({ skirmishID = "win-while-dead", outcome = "win", playerDeathIndex = 1, opponentDeathIndex = 2 })
assert(not GameTooltip.shown and CenterMarker(swords) and not CenterMarker(skull))
CheckPortraitMarker(myRim, skull, "TOPRIGHT")
CheckPortraitMarker(opponentRim, skull, "TOPLEFT")
portraitDeath.scripts.OnEnter(portraitDeath)
assert(GameTooltip.shown and GameTooltip.title == addon.L.portraitDeath)
compact:SetEncounter({ skirmishID = "player-casualty", playerDeathIndex = 1 })
assert(not GameTooltip.shown and not CenterMarker(swords) and not CenterMarker(skull))
assert(PortraitMarker(myRim, skull) and not PortraitMarker(opponentRim, skull))
local unknownMark = assert(FindText(compact, "?"))
assert(unknownMark.parent.shown)
unknownMark.parent.scripts.OnEnter(unknownMark.parent)
assert(GameTooltip.shown and GameTooltip.title == addon.L.unknownOutcome)
compact:SetEncounter({ skirmishID = "battle-two" })
assert(not GameTooltip.shown and unknownMark.parent.shown)
assert(not PortraitMarker(myRim, skull) and not PortraitMarker(opponentRim, skull))
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
assert(rivalPortrait.texture == "Interface\\Icons\\INV_Misc_QuestionMark")
assert(rivalPortrait.texcoords[1] < rivalPortrait.texcoords[2])
assert(not CenterMarker(swords) and unknownMark.parent.shown)
compact:SetEncounter(first)
AssertFullPortrait(rivalPortrait, true)
compact:SetEncounter(nil)
assert(not compact.shown)
print("Compact skirmish factions, team outcomes, casualties and actions checks passed")
