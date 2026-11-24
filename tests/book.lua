local addon, callback, locale = { db = { rivals = {} } }, nil, "enUS"
local pixelFactor, dividerScale = 0.8, 0.7
local displayHandlers, bookLogin = {}
PixelUtil = {
    GetPixelToUIUnitFactor = function() return pixelFactor end,
    GetNearestPixelSize = function(size, scale, minimum)
        return math.max(minimum, math.floor(size * scale / pixelFactor + 0.5)) * pixelFactor / scale
    end,
}
local function DisplayChanged()
    for _, handler in ipairs(displayHandlers) do handler() end
end
function GetLocale() return locale end
function CreateFrame()
    local layoutFrame, playerLogin
    return {
        RegisterEvent = function(_, event)
            if event == "UI_SCALE_CHANGED" then layoutFrame = true end
            if event == "PLAYER_LOGIN" then playerLogin = true end
        end,
        SetScript = function(_, _, handler)
            if layoutFrame then displayHandlers[#displayHandlers + 1] = handler end
            if playerLogin then bookLogin = handler end
        end,
    }
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

local LoadLocale = assert(loadfile("NamesInRed/Locale.lua"))
local function FormatArguments(text)
    local args, cursor = {}, 1
    while true do
        local start = text:find("%", cursor, true)
        if not start then return table.concat(args) end
        if text:sub(start + 1, start + 1) == "%" then
            cursor = start + 2
        else
            local kind, finish = text:sub(start):match("^%%[-+ #0]*%d*%.?%d*([cdiouxXeEfgGqs])()")
            assert(kind, "Invalid format specifier in " .. text)
            args[#args + 1], cursor = kind, start + finish - 1
        end
    end
end

LoadLocale("NamesInRed", addon)
local english = addon.L
local tocFile = assert(io.open("NamesInRed/NamesInRed.toc"))
local toc = tocFile:read("*a")
tocFile:close()
assert(toc:match("## Notes: [^\r\n]+"))
local spanish
for _, supported in ipairs({
    "enUS", "enGB", "ruRU", "deDE", "frFR", "esES", "esMX", "itIT", "ptBR", "koKR", "zhCN", "zhTW",
}) do
    locale = supported
    LoadLocale("NamesInRed", addon)
    assert(addon.title == "Names in Red")
    for key, default in pairs(english) do
        local translated = rawget(addon.L, key)
        assert(type(translated) == "string" and translated ~= "", supported .. " missing " .. key)
        assert(FormatArguments(translated) == FormatArguments(default), supported .. " format mismatch for " .. key)
    end
    for key in pairs(addon.L) do assert(english[key], "Unknown translation key " .. key) end
    assert(addon.L.deleteConfirm:format("Rival"):find("Rival", 1, true))
    assert(addon.L.finishingBlow:format("Rival"):find("Rival", 1, true))
    local _, lineBreaks = addon.L.minimapHint:gsub("\n", "")
    assert(lineBreaks == 2)
    if supported == "enUS" or supported == "enGB" then
        assert(addon.L.recentView == english.recentView)
    else
        assert(toc:match("## Notes%-" .. supported .. ": [^\r\n]+"), supported .. " missing AddOns description")
        assert(addon.L.recentView ~= english.recentView)
    end
    if supported == "esES" then spanish = addon.L.recentView end
    if supported == "esMX" then assert(addon.L.recentView == spanish) end
    if supported == "ruRU" then assert(addon.L.winTooltip == "Победа" and addon.L.lossTooltip == "Поражение") end
end

locale = "deDE"
LoadLocale("NamesInRed", addon)
addon.L.finishingBlow = nil
assert(addon.L.finishingBlow == english.finishingBlow)
locale = "unknownLocale"
LoadLocale("NamesInRed", addon)
assert(addon.L.recentView == english.recentView and addon.L.debugStatus == english.debugStatus)
locale = "enUS"
LoadLocale("NamesInRed", addon)

local secret = {}
function issecretvalue(value) return value == secret end
for _, file in ipairs({ "Ledger", "SkirmishDeathEvidence", "PersonalSkirmishOutcomes", "RivalContributions" }) do
    assert(loadfile("NamesInRed/" .. file .. ".lua"))("NamesInRed", addon)
end
assert(loadfile("NamesInRed/Encounter.lua"))("NamesInRed", addon)
assert(loadfile("NamesInRed/Portraits.lua"))("NamesInRed", addon)
assert(loadfile("NamesInRed/EncounterCards.lua"))("NamesInRed", addon)
assert(loadfile("NamesInRed/Core.lua"))("NamesInRed", addon)
assert(addon.HonorIconTexture("Alliance") == 463450 and addon.HonorIconTexture("Horde") == 463451)
Constants = { CurrencyConsts = { CLASSIC_HONOR_CURRENCY_ID = 1901 } }
local listedHonorIcon = 900101
C_CurrencyInfo = {
    GetCurrencyListSize = function() return 2 end,
    GetCurrencyListInfo = function(index)
        if index == 1 then return { currencyID = 777, iconFileID = 900100 } end
        return { currencyID = 1901, iconFileID = listedHonorIcon }
    end,
    GetCurrencyInfo = function(id)
        assert(id == 1901)
        return { iconFileID = 900103 }
    end,
}
assert(addon.HonorIconTexture("Alliance") == 900101)
listedHonorIcon = 900102
assert(addon.HonorIconTexture("Horde") == 900102)
UnitFactionGroup = function() return "Alliance" end
assert(addon.HonorIconTexture("Alliance") == 900102 and addon.HonorIconTexture("Horde") == 463451)
UnitFactionGroup = nil
listedHonorIcon = secret
assert(addon.HonorIconTexture("Horde") == 900103)
Constants, C_CurrencyInfo = nil, nil
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
local swordCounter = art .. "CrossedSwords.tga:14:14:0:1:128:128:22:106:22:106|t"
local loss = art .. "TooltipSkull.tga:14:14:0:1|t"
assert(tooltipLines[3] == addon.L.historyPair:format(addon.L.legacyResult, 2, 1))
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
assert(tooltipLines[9] == addon.L.historyPair:format(addon.L.manual, 0, 1))
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

local duelGUID = "Player-reciprocal"
local directBattle = {
    startedAt = 100, time = 100,
    personalOutcome = { lifecycle = "finalized", outcome = "draw", version = 2 },
    allies = { { id = "Player-self", isSelf = true } }, enemies = { { id = duelGUID, rivalID = duelGUID, name = "Reciprocal Rival" } },
    events = { { kind = "kill", actorID = "Player-self", targetID = duelGUID, offset = 1 },
        { kind = "revive", targetID = duelGUID, offset = 4 },
        { kind = "kill", actorID = duelGUID, targetID = "Player-self", offset = 5 } },
}
local duelRef = "tooltip-skirmish"
local refreshes = 0
function GameTooltip:IsShown() return true end
function GameTooltip:IsTooltipType(kind) return kind == Enum.TooltipDataType.Unit end
function GameTooltip:RefreshDataNextUpdate() refreshes = refreshes + 1 end
addon.RecordSkirmish(duelRef, directBattle)
callback(GameTooltip, { guid = duelGUID })
assert(refreshes == 1 and #tooltipLines == 16)
assert(tooltipLines[15] == swordCounter .. " 1   " .. loss .. " 1")
assert(tooltipLines[16] == addon.L.personalFinishingBlows:format(1, 1))
directBattle.allies[2] = { id = "Player-ally" }
directBattle.events[4] = { kind = "revive", targetID = "Player-self", offset = 5.5 }
directBattle.events[5] = { kind = "kill", actorID = "Player-ally", targetID = duelGUID, offset = 8 }
directBattle.observation = { segments = { {
    offset = 6, duration = 3,
    contributionLinks = { { category = "HealingDone", actorID = "Player-self", targetID = "Player-ally" } },
} } }
addon.RecordSkirmish(duelRef, directBattle)
callback(GameTooltip, { guid = duelGUID })
assert(refreshes == 2 and #tooltipLines == 20)
assert(tooltipLines[19] == swordCounter .. " 2   " .. loss .. " 1")
assert(tooltipLines[20] == addon.L.personalFinishingBlows:format(1, 1))

local function MockRegion(parent)
    local region = { parent = parent, children = {}, shown = true, scripts = {} }
    if parent then parent.children[#parent.children + 1] = region end
    function region:CreateFontString(_, _, font)
        local label = MockRegion(self)
        label.font = font
        return label
    end
    function region:CreateTexture() return MockRegion(self) end
    function region:CreateMaskTexture() return MockRegion(self) end
    function region:SetText(text)
        assert(text ~= nil)
        self.text = text
    end
    function region:GetText() return self.text end
    function region:GetFont() return "ClientFont", 10, "OUTLINE" end
    function region:SetFont(path, size, flags) self.textStyle = { path, size, flags } end
    function region:SetSnapToPixelGrid(enabled) self.snapToGrid = enabled end
    function region:SetTexelSnappingBias(bias) self.texelBias = bias end
    function region:GetStringWidth() return #(tostring(self.text or "")) * 6 end
    function region:SetBlendMode(mode) self.blend = mode end
    function region:SetHighlightTexture(texture) self.highlight = texture end
    function region:SetHighlightFontObject(font) self.hoverFont = font end
    function region:SetFontString(label) self.buttonLabel = label end
    function region:LockHighlight() self.highlightLocked = true end
    function region:UnlockHighlight() self.highlightLocked = false end
    function region:SetDesaturated(active) self.desaturated = active end
    function region:SetTextColor(r, g, b) self.color = { r, g, b } end
    function region:SetVertexColor(r, g, b) self.color = { r, g, b } end
    function region:SetAlpha(alpha) self.alpha = alpha end
    function region:IsTruncated() return rawget(self, "truncated") == true end
    function region:IsMouseMotionFocus() return rawget(self, "hovered") == true end
    function region:SetColorTexture(_, _, _, opacity) self.fillOpacity = opacity end
    function region:SetBackdropColor(...) self.backdropColor = { ... } end
    function region:SetRoundLayoutToNearestPixel(enabled) self.roundToPixel = enabled end
    function region:GetEffectiveScale() return dividerScale end
    function region:SetPoint(...) self.anchor = { ... } end
    function region:SetJustifyH(value) self.justifyH = value end
    function region:SetJustifyV(value) self.justifyV = value end
    function region:SetWordWrap(value) self.wordWrap = value end
    function region:SetMaxLines(value) self.maxLines = value end
    function region:AddMaskTexture(mask) self.mask = mask end
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
    function region:Show() self:SetShown(true) end
    function region:Hide() self:SetShown(false) end
    function region:SetHeight(height) self.height = height end
    function region:SetWidth(width) self.width = width end
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
    return setmetatable(region, { __index = function(_, key) if key:match("^%u") then return function() end end end })
end


function CreateFrame(_, _, parent, template)
    local region = MockRegion(parent)
    region.template = template
    if template == "CommonSquareIconButtonTemplate" then
        region.Icon = MockRegion(region)
        function region:SetAtlas(atlas) self.Icon:SetAtlas(atlas) end
        region:SetScript("OnMouseUp", function(self) self.Icon:SetPoint("CENTER", self, "CENTER", -1, 0) end)
    elseif template == "SharedButtonSmallTemplate" then
        function region:SetTextToFit(value) self:SetText(value) end
    end
    return region
end
assert(loadfile("NamesInRed/ManualDialog.lua"))("NamesInRed", addon)
local allianceAtlas = "UI-HUD-UnitFrame-SmallCircle-Alliance"
local hordeAtlas = "UI-HUD-UnitFrame-SmallCircle-Horde"
local missingAtlas
C_Texture = {
    GetAtlasInfo = function(atlas)
        if atlas == missingAtlas then return end
        if atlas == allianceAtlas then return { width = 24, height = 32 } end
        if atlas == hordeAtlas then return { width = 16, height = 32 } end
        if atlas == "Profession-Background-Template2" then
            return { width = 668, height = 588, leftTexCoord = 0.2, rightTexCoord = 0.6,
                topTexCoord = 0.3, bottomTexCoord = 0.8 }
        end
        return { leftTexCoord = 0.2, rightTexCoord = 0.4, topTexCoord = 0.3, bottomTexCoord = 0.5 }
    end,
}
date = os.date
local selectedRival, journalMapOpened, timelineRequested
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
local card = addon.CreateSkirmishCard(MockRegion(), 736, function() journalMapOpened = true end,
    function(id) selectedRival = id end, function(battle) timelineRequested = battle end)
local allies = { { id = "me", name = "My Character", isSelf = true }, { id = "ally", name = "Ally Warrior" } }
local enemies = {
    { id = "enemy", name = "Test Rival", rivalID = "Player-test", class = "MAGE", level = 42 },
    { id = "other", name = "Other Rival" },
}
local large = { time = 100, startedAt = 80, zone = "Hillsbrad Foothills", mapID = 1424, x = 0.45, y = 0.51,
    allies = allies, enemies = enemies, rosterComplete = true,
    rewards = { enemy = { honorableKills = 1, honor = 10 }, other = { honorableKills = 2, honor = 4000 } },
    events = {
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

do
    local reportOpened
    function addon.OpenIssueReport() reportOpened = true end
    addon.issueBugIcon = "Interface\\HelpFrame\\HelpIcon-Bug.blp"
    local function HeaderAtWidth(width)
        local parent = MockRegion()
        function parent:GetWidth() return width end
        addon.CreateBookHeader(parent)
        local report = assert(FindRegion(parent, "template", "SharedButtonSmallTemplate"))
        assert(report.text:find(addon.L.reportIssue, 1, true) and report.text:find(addon.issueBugIcon, 1, true))
        local hint = assert(FindText(parent, addon.L.issuePrompt))
        assert(hint.textStyle[1] == "ClientFont" and hint.textStyle[2] == 11 and hint.textStyle[3] == "OUTLINE")
        reportOpened = nil
        report.scripts.OnClick()
        assert(reportOpened)
        return assert(FindRegion(parent, "atlas", "Profession-Background-Template2"))
    end
    local original, wide = HeaderAtWidth(700), HeaderAtWidth(810)
    assert(original.width == 694 and wide.width == 804 and original.height == wide.height)
    for index = 1, 4 do
        assert(original.texcoords[index] == wide.texcoords[index])
    end
end

assert(loadfile("NamesInRed/RivalList.lua"))("NamesInRed", addon)
do
    local function Color(r, g, b) return { GetRGB = function() return r, g, b end } end
    PROFESSION_RECIPE_COLOR = Color(0.85, 0.84, 0.81)
    DIM_RED_FONT_COLOR = Color(0.9, 0.22, 0.28)
    HIGHLIGHT_FONT_COLOR = Color(1, 1, 1)
    ScrollBoxConstants = { RetainScrollPosition = true }
    CreateDataProvider = function(entries) return entries end
    local view
    function CreateScrollBoxListLinearView(top, bottom, left, right, spacing)
        assert(top == 5 and bottom == 5 and left == 10 and right == 5 and spacing == 1)
        view = {
            SetElementExtent = function(self, height) self.height = height end,
            SetElementInitializer = function(self, template, bind)
                self.template, self.bind = template, bind
            end,
        }
        return view
    end
    ScrollUtil = {
        InitScrollBoxListWithScrollBar = function(scroll, bar)
            assert(scroll.template == "WowScrollBoxList" and bar.template == "MinimalScrollBar")
            function scroll:SetDataProvider(entries, retain)
                assert(retain)
                self.providerUpdates = (rawget(self, "providerUpdates") or 0) + 1
                self.entries = entries
                self.rows = self.rows or {}
                for index, entry in ipairs(entries) do
                    local row = self.rows[index]
                    if not row then
                        row = CreateFrame("Button", nil, self, view.template)
                        if view.template == "ProfessionsRecipeListRecipeTemplate" then
                            for _, key in ipairs({ "Label", "SkillUps", "LockedIcon", "Count" }) do
                                row[key] = MockRegion(row)
                            end
                            row:SetScript("OnEnter", function() error("Recipe handlers require recipe data") end)
                            row.SelectedOverlay, row.HighlightOverlay = MockRegion(row), MockRegion(row)
                            function row:SetSelected(selected)
                                self.SelectedOverlay:SetShown(selected)
                                self.HighlightOverlay:SetShown(not selected)
                            end
                        end
                        self.rows[index] = row
                    end
                    function row:GetElementData() return self.entry end
                    row.entry = entry
                    view.bind(row, entry)
                end
            end
            function scroll:ForEachFrame(callback)
                for index, entry in ipairs(self.entries) do callback(self.rows[index], entry) end
            end
            scroll.rows = {}
        end,
    }
    local firstRival = { id = "first", name = "First Rival" }
    local secondRival = { id = "second", name = "Second Rival" }
    local clicked
    ProfessionsRecipeListRecipeMixin = {}
    local list, bar = addon.CreateRivalList(MockRegion(), function(id) clicked = id end)
    assert(addon.rivalListWidth == 304 and bar.anchor[2] == list and view.height == 20)
    assert(view.template == "ProfessionsRecipeListRecipeTemplate")
    list:SetRivals({ firstRival, secondRival }, "second")
    local first, second = unpack(list.rows)
    local normal = first.Label.color
    assert(first.Label:GetText() == "First Rival" and normal[1] > normal[2] and normal[1] > normal[3])
    assert(normal[2] < 0.84 and normal[3] < 0.81)
    assert(not first.SelectedOverlay.shown and first.HighlightOverlay.shown)
    assert(second.SelectedOverlay.shown and not second.HighlightOverlay.shown and not second.Count.shown)
    first.Label.truncated = true
    first.scripts.OnEnter(first)
    assert(first.Label.color[1] == 1 and GameTooltip.owner == first)
    first.scripts.OnClick(first)
    assert(clicked == "first")
    first.scripts.OnLeave(first)
    assert(first.Label.color[1] == normal[1] and first.Label.color[2] == normal[2]
        and first.Label.color[3] == normal[3] and not GameTooltip.owner)
    list:SetRivals({ firstRival, secondRival }, "first")
    assert(first.SelectedOverlay.shown and not second.SelectedOverlay.shown and list.providerUpdates == 1)
    list:SetRivals({ secondRival }, "second")
    first.scripts.OnClick(first)
    assert(clicked == "second" and first.Label:GetText() == "Second Rival" and list.providerUpdates == 2)

    ProfessionsRecipeListRecipeMixin = nil
    local fallback = addon.CreateRivalList(MockRegion(), function() end)
    fallback:SetRivals({ firstRival }, "first")
    local row = fallback.rows[1]
    assert(view.template == "Button" and row.Label.font == "GameFontHighlight_NoShadow")
    assert(row.HighlightOverlay.atlas == "Professions_Recipe_Hover" and row.HighlightOverlay.alpha == 0.5)
    assert(row.SelectedOverlay.shown and not row.HighlightOverlay.shown)
end
print("Native recipe row style, search data reuse, and rival selection checks passed")

local function CheckLevelLabel(label)
    local size = 24
    local badge = label.parent
    local circle = assert(FindRegion(badge, "texture", addon.levelBadgePath))
    local expectedPixels = 2 * math.floor(size / 2 * dividerScale / pixelFactor + 0.5)
    assert(math.abs(badge.width * dividerScale / pixelFactor - expectedPixels) < 1e-6)
    assert(badge.width == badge.height and badge.roundToPixel and label.roundToPixel and circle.roundToPixel)
    assert(label.bounds == badge and circle.bounds == badge and circle.snapToGrid == false and circle.texelBias == 0)
    assert(label.justifyH == "CENTER" and label.justifyV == "MIDDLE" and not label.anchor)
    assert(label.font == "GameFontHighlight")
    return badge
end
local classSheet = "Interface\\TargetingFrame\\UI-Classes-Circles"
CLASS_ICON_TCOORDS = {
    MAGE = { 0.25, 0.5, 0, 0.25 },
    ROGUE = { 0.5, 0.75, 0, 0.25 },
    WARRIOR = { 0, 0.25, 0, 0.25 },
}
local function CheckClassBadge(tile, class, label, corner)
    local badge = tile.avatar.classBadge
    assert(badge.shown and badge.anchor[1] == corner and badge.anchor[3] == corner)
    assert(badge.anchor[2] == tile.avatar.rim and badge.roundToPixel)
    assert(FindRegion(badge, "texture", addon.levelBadgePath))
    local icon = assert(FindRegion(badge, "texture", classSheet))
    assert(icon.mask and #icon.texcoords == 4)
    for index, coord in ipairs(CLASS_ICON_TCOORDS[class]) do assert(icon.texcoords[index] == coord) end
    assert(tile.name.wordWrap and tile.name.maxLines == 2 and tile.name.justifyV == "TOP")
    badge.scripts.OnEnter(badge)
    assert(GameTooltip.shown and GameTooltip.title == label)
    badge.scripts.OnLeave(badge)
    assert(not GameTooltip.shown)
    return badge
end
local function FindDivider(region)
    for _, child in ipairs(region.children) do
        if rawget(child, "fillOpacity") == 0.30 then return child end
    end
end
local faction = "Alliance"
function UnitFactionGroup(unit)
    assert(unit == "player")
    return faction
end
local function CheckFactionColors(left, right)
    assert(left.color[3] > left.color[1] and right.color[1] > right.color[3])
end
local function CheckRewards(card, kills, honor, currencyTexture)
    local function CheckCounter(texture, value, tooltip)
        local icon = assert(FindRegion(card, "texture", texture))
        local target = icon.parent
        assert(target.width == 14 and target.height == 14 and icon.texcoords[1] > 0 and icon.texcoords[2] < 1)
        local count
        for _, region in ipairs(target.parent.children) do
            if rawget(region, "text") == value and region.anchor[2] == target then count = region end
        end
        assert(count and count.anchor[1] == "RIGHT" and count.anchor[3] == "LEFT" and count.anchor[4] < 0)
        assert(rawget(count, "width") == nil)
        target.scripts.OnEnter(target)
        assert(GameTooltip.shown and GameTooltip.title == tooltip)
        target.scripts.OnLeave(target)
        assert(not GameTooltip.shown)
        return target, count
    end
    local honorIcon, honorCount = CheckCounter(currencyTexture, honor, addon.L.skirmishHonorEarned)
    local killsIcon = CheckCounter(addon.honorableKillIconPath, kills, addon.L.skirmishHonorableKillsEarned)
    assert(killsIcon.anchor[2] == honorCount and killsIcon.anchor[4] < honorCount.anchor[4])
    return honorIcon
end
card:SetSkirmish(large, "Player-test")
local rewardIcon = CheckRewards(card, "3", "4010", 463450)
local collapsedHeight = card.height
assert(collapsedHeight == addon.SkirmishCardHeight(large) and not FindText(card, "0:11"))
local timelineTitle = assert(FindText(card, addon.L.finishingBlows))
local timelineHeader = timelineTitle.parent
assert(rewardIcon.parent == timelineHeader.parent and rewardIcon.anchor[1] == "TOPRIGHT")
assert(rewardIcon.anchor[3] - rewardIcon.height / 2 == -timelineHeader.height / 2)
assert(collapsedHeight == -rewardIcon.parent.anchor[3] + timelineHeader.height)
assert(timelineHeader.buttonLabel == timelineTitle and timelineHeader.hoverFont == "GameFontHighlightSmall")
assert(not timelineHeader.highlight and timelineHeader.width < card.width / 2)
timelineTitle.parent.scripts.OnClick(timelineTitle.parent)
assert(timelineRequested == large)
card:SetSkirmish(large, "Player-test", true)
assert(CheckRewards(card, "3", "4010", 463450) == rewardIcon)
local largeHeight = card.height
assert(largeHeight == addon.SkirmishCardHeight(large, true) and collapsedHeight < largeHeight)
assert(FindText(card, "2 × 2") and FindText(card, "Ally Warrior") and FindText(card, "0:11"))
assert(not FindText(card, "0:15"))
assert(not FindText(card, addon.L.showOnMap) and not FindText(card, "45.0, 51.0"))
local journalMap = assert(FindRegion(card, "title", addon.L.showOnMap))
local zone = assert(FindText(card, large.zone))
local stamp = assert(FindText(card, date("%x", large.time) .. "  " .. date("%H:%M", large.time)))
assert(journalMap.template == "CommonSquareIconButtonTemplate" and stamp.anchor[4] < journalMap.anchor[4])
assert(zone.anchor[5] == stamp.anchor[5] and stamp.anchor[5] == journalMap.anchor[5])
assert(FindText(card, "2 × 2").anchor[5] == stamp.anchor[5] - 2)
local eventTitle, firstTime = timelineTitle, FindText(card, "0:11")
local secondTime = FindText(card, "0:17")
local timeline = firstTime.parent
local arrows = 0
for _, region in ipairs(timeline.children) do
    if region.atlas == "common-icon-forwardarrow" and region.anchor[1] == "CENTER" then
        local target = region.anchor[2]
        assert(target.parent == timeline and target.font == "GameFontHighlightSmall")
        assert(region.anchor[3] == "LEFT" and region.anchor[5] == 0)
        arrows = arrows + 1
    end
end
assert(arrows == 2)
assert(firstTime.anchor[3] > secondTime.anchor[3])
local headerLine, blowsLine = assert(FindDivider(card)), assert(FindDivider(eventTitle.parent.parent))
assert(headerLine.anchor[3] - 2 == 2 * journalMap.anchor[5])
addon.ShowEncounterWaypoint = function(battle) assert(battle == large); return true end
journalMap.scripts.OnClick()
assert(journalMapOpened)
assert(not FindRegion(card, "template", "UIPanelInfoButton"))
local allyHeading, enemyHeading = FindText(card, addon.L.alliedSide), FindText(card, addon.L.enemySide)
local allyEmblem = assert(FindRegion(card, "atlas", allianceAtlas))
local enemyEmblem = assert(FindRegion(card, "atlas", hordeAtlas))
assert(allyEmblem.anchor[2] == allyHeading and enemyEmblem.anchor[2] == enemyHeading)
assert(allyEmblem.height == 18 and allyEmblem.width == 13.5 and enemyEmblem.height == 18 and enemyEmblem.width == 9)
local allyPanel, enemyPanel = allyHeading.parent, enemyHeading.parent
for _, panel in ipairs({ allyPanel, enemyPanel }) do
    local r, g, b, alpha = unpack(panel.backdropColor)
    assert(r == g and g == b and alpha < 0.5)
end
assert(not FindRegion(card, "texture", addon.battlefieldArtPath) and card.backdropColor[4] < 0.72)
CheckFactionColors(allyHeading, enemyHeading)
large.demoFaction = "Horde"
card:SetSkirmish(large, "Player-test")
CheckFactionColors(enemyHeading, allyHeading)
CheckRewards(card, "3", "4010", 463451)
assert(faction == "Alliance" and allyEmblem.atlas == hordeAtlas and enemyEmblem.atlas == allianceAtlas)
large.demoFaction = nil
faction = "Horde"
card:SetSkirmish(large, "Player-test")
CheckFactionColors(enemyHeading, allyHeading)
assert(allyEmblem.atlas == hordeAtlas and allyEmblem.width == 9)
assert(enemyEmblem.atlas == allianceAtlas and enemyEmblem.width == 13.5)
missingAtlas = hordeAtlas
card:SetSkirmish(large, "Player-test")
assert(not allyEmblem.shown and enemyEmblem.shown)
missingAtlas = nil
faction = "Alliance"
local name = assert(FindText(card, "Test Rival"))
assert(name.color[1] == 0.25 and name.color[2] == 0.78 and name.color[3] == 0.92)
local rimHighlight = name.parent.highlight
assert(name.parent.highlightLocked and rimHighlight.bounds == name.parent.avatar.rim)
assert(rimHighlight.atlas == "Mode-Selection-Ring" and rimHighlight.blend == "ADD" and rimHighlight.alpha == 0.45)
assert(name.parent.avatar.death.shown and FindRegion(name.parent.avatar.death, "atlas", "UI-HUD-UnitFrame-SmallCircle"))
CheckLevelLabel(assert(FindText(name.parent, 42)))
name.parent.scripts.OnClick(name.parent)
assert(selectedRival == "Player-test")
local finished = { allies = { allies[1] }, enemies = { enemies[1] }, rosterComplete = true,
    personalOutcome = { lifecycle = "finalized", outcome = "win" },
    events = { { kind = "kill", actorID = "me", targetID = "enemy" } } }
card:SetSkirmish(finished)
CheckRewards(card, "0", "0", 463450)
assert(allyEmblem.shown and allyEmblem.atlas == allianceAtlas and enemyEmblem.atlas == hordeAtlas)
local fullVictory = assert(FindRegion(card, "texture", addon.swordsIconPath)).parent
local fullOutcome = fullVictory.parent
assert(fullOutcome.anchor[4] == 0 and FindText(fullOutcome, addon.L.winTooltip))
assert(fullVictory.width == 56 and fullVictory.height == 56)
assert(FindRegion(fullVictory, "atlas", "UI-HUD-UnitFrame-SmallCircle"))
assert(not fullVictory.scripts.OnEnter)
card:SetSkirmish({ allies = finished.allies, enemies = finished.enemies,
    personalOutcome = { lifecycle = "finalized", outcome = "loss" }, events = {} })
assert(CheckRewards(card, "0", "0", 463450) == rewardIcon)
assert(not FindText(card, addon.L.finishingBlows) and not FindText(card, "0:11"))
assert(not GameTooltip.shown and not fullVictory.shown)
local fullDefeat = assert(FindRegion(card, "texture", addon.defeatBannerPath)).parent
assert(FindText(fullOutcome, addon.L.lossTooltip))
assert(fullDefeat.width == fullVictory.width and fullDefeat.height == fullVictory.height)
local bannerArt = assert(FindRegion(fullDefeat, "texture", addon.defeatBannerPath))
assert(bannerArt.width >= 0.9 * fullDefeat.width and not fullDefeat.scripts.OnEnter)
card:SetSkirmish({ allies = finished.allies, enemies = finished.enemies, outcome = "win", events = {} })
assert(FindText(fullOutcome, addon.L.legacyResult) and not FindText(fullOutcome, addon.L.winTooltip))
fullVictory.scripts.OnEnter(fullVictory)
assert(GameTooltip.shown and GameTooltip.title:find(addon.L.winTooltip, 1, true))
card:SetSkirmish(directBattle)
assert(FindText(fullOutcome, addon.L.drawOutcome) and FindText(fullOutcome, "="))
assert(not GameTooltip.shown)
directBattle.personalOutcome = { lifecycle = "awaiting", outcome = "win" }
card:SetSkirmish(directBattle)
assert(FindText(fullOutcome, addon.L.ongoingOutcome) and FindText(fullOutcome, "…"))
directBattle.personalOutcome = { lifecycle = "active" }
card:SetSkirmish(directBattle)
assert(FindText(fullOutcome, addon.L.ongoingOutcome))
directBattle.personalOutcome = { lifecycle = "finalized", outcome = "unknown" }
card:SetSkirmish(directBattle)
assert(FindText(fullOutcome, addon.L.shortUnknownOutcome) and FindText(fullOutcome, "?"))
card:SetSkirmish({ allies = { allies[1] }, enemies = { enemies[1] }, events = {} })
assert(not GameTooltip.shown and not fullDefeat.shown and FindText(card, "?"))
assert(not name.parent.highlightLocked)
local partialCount = assert(FindText(card, "1 × 1"))
assert(card.height < largeHeight and not FindText(card, addon.L.partialRoster))
assert(not journalMap.shown)
assert(not FindText(card, "Ally Warrior") and not FindText(card, "Other Rival") and not FindText(card, "0:11"))
local rosterHint = assert(FindRegion(card, "template", "UIPanelInfoButton"))
assert(rosterHint.anchor[2] == partialCount and rosterHint.anchor[4] > 0)
rosterHint.scripts.OnEnter(rosterHint)
assert(GameTooltip.shown and GameTooltip.title == addon.L.partialRoster)
assert(tooltipLines[#tooltipLines] == addon.L.partialRosterHint)
card:SetSkirmish({ allies = { allies[1] }, enemies = { enemies[2] }, events = {} })
assert(FindText(card, "Other Rival") == name)
assert(name.color[1] == 1 and name.color[2] == 1 and name.color[3] == 1)
card:SetSkirmish(nil)
assert(not card.shown and not GameTooltip.shown)
print("Skirmish card roster, faction emblems, outcomes and recycling checks passed")

local patterns = { { 1 }, { 2 }, { 2, 1 }, { 2, 2 }, { 3, 2 }, { 3, 3 }, { 3, 2, 2 },
    { 3, 3, 2 }, { 3, 3, 3 }, { 3, 3, 2, 2 } }
local roster = {}
for i = 1, #patterns do roster[i] = { id = "ally:" .. i, name = "Ally " .. i } end
for count = #patterns, 1, -1 do
    local battle = { allies = { unpack(roster, 1, count) }, enemies = enemies, events = {} }
    card:SetSkirmish(battle)
    assert(card.height == addon.SkirmishCardHeight(battle))
    local i, priorY = 0, 0
    for _, slots in ipairs(patterns[count]) do
        local center, y, priorX = 0, nil, -math.huge
        for _ = 1, slots do
            i = i + 1
            local tile = assert(FindText(card, roster[i].name)).parent
            local x, rowY = tile.anchor[4], tile.anchor[5]
            assert(x > priorX and (not y or y == rowY))
            y, priorX, center = rowY, x, center + x
            assert(not tile.avatar.death.shown)
        end
        assert(center == 0 and y < priorY)
        priorY = y
    end
    assert(i == count and not FindText(card, "Ally " .. (count + 1)))
end
print("Skirmish portraits use balanced, centered rows and clear recycled casualties")

local openedSkirmish, openedMap, mapped
local compact = addon.CreateCompactEncounterCard(MockRegion(), 442, function() openedMap = true end,
    function(id) openedSkirmish = id end)
local compactLine = assert(FindDivider(compact))
for _, line in ipairs({ headerLine, blowsLine, compactLine }) do
    assert(line.height == 2 * pixelFactor / dividerScale and line.anchor[2] == -14)
    assert(line.roundToPixel and line.snapToGrid == false and line.texelBias == 0)
end
pixelFactor, dividerScale = 0.5, 0.9
DisplayChanged()
for _, line in ipairs({ headerLine, blowsLine, compactLine }) do
    assert(line.height == 2 * pixelFactor / dividerScale)
end
local first = { skirmishID = "battle-one", contributionWins = 1, opponentDeathIndex = 1, mapID = 1424, x = 0.45, y = 0.51,
    zone = "Hillsbrad Foothills", time = 100, player = allies[1], opponent = enemies[1],
    playerLevel = 51, rivalLevel = 42 }
first.player.race, first.player.sex = "orc", 2
first.opponent.race, first.opponent.sex, first.opponent.classLabel = "human", 3, "Mage"
function GetRaceAtlas(race, gender) return race .. "-" .. gender end
compact:SetEncounter(first)
assert(CheckRewards(compact, "0", "0", 463450).anchor[1] == "BOTTOMRIGHT")
addon.db.skirmishes[first.skirmishID] = large
compact:SetEncounter(first)
CheckRewards(compact, "3", "4010", 463450)
addon.db.skirmishes[first.skirmishID] = nil
assert(FindText(compact, "Hillsbrad Foothills") and FindText(compact, date("%x", first.time)))
assert(FindText(compact, "Hillsbrad Foothills").anchor[1] == "LEFT")
assert(FindText(compact, "My Character") and FindText(compact, "Test Rival"))
local myBadge = CheckLevelLabel(assert(FindText(compact, 51)))
local opponentBadge = CheckLevelLabel(assert(FindText(compact, 42)))
assert(myBadge.anchor[1] == "BOTTOMLEFT" and myBadge.anchor[3] == "BOTTOMLEFT")
assert(opponentBadge.anchor[1] == "BOTTOMRIGHT" and opponentBadge.anchor[3] == "BOTTOMRIGHT")
assert(#myBadge.anchor == 3 and #opponentBadge.anchor == 3 and myBadge.width == opponentBadge.width)
local myName, opponentName = FindText(compact, "My Character"), FindText(compact, "Test Rival")
assert(opponentName.color[1] == 0.25 and opponentName.color[2] == 0.78 and opponentName.color[3] == 0.92)
local myRim, opponentRim = myName.parent.avatar.rim, opponentName.parent.avatar.rim
assert(myRim.width == 64 and opponentRim.width == myRim.width)
assert(myName.font == "GameFontHighlight_NoShadow" and opponentName.font == myName.font)
local opponentClass = CheckClassBadge(opponentName.parent, "MAGE", "Mage", "BOTTOMLEFT")
assert(opponentClass.width == opponentBadge.width and not FindText(opponentName.parent, "Mage"))
assert(myName.parent.highlight.bounds == myRim and opponentName.parent.highlight.bounds == opponentRim)
local playerPortrait = assert(FindRegion(compact, "atlas", "orc-male"))
local rivalPortrait = assert(FindRegion(compact, "atlas", "human-female"))
local function AssertFullPortrait(portrait, mirrored)
    local left, right, top, bottom = unpack(portrait.texcoords)
    assert(left == (mirrored and 1 or 0) and right == (mirrored and 0 or 1))
    assert(top == 0 and bottom == 1)
end
AssertFullPortrait(playerPortrait, false)
AssertFullPortrait(rivalPortrait, true)
local profile = MockRegion()
local profileAvatar = addon.CreateParticipantPortrait(profile)
profileAvatar:SetParticipant(first.opponent, nil, 58)
AssertFullPortrait(assert(FindRegion(profile, "atlas", "human-female")), false)
local profileBadge = CheckLevelLabel(assert(FindText(profile, 58)))
assert(profileBadge.anchor[2] == profileAvatar.rim and profileBadge.anchor[3] == "BOTTOMLEFT")
assert(profileAvatar.rim.width == myRim.width and myBadge.width == profileBadge.width)
assert(name.parent.avatar.rim.width == profileAvatar.rim.width)
assert(not profileAvatar.death and not profileAvatar.classBadge)
profileAvatar:SetParticipant(first.opponent, nil, 9)
assert(CheckLevelLabel(assert(FindText(profile, 9))) == profileBadge)
local previousWidth = profileBadge.width
pixelFactor, dividerScale = 0.8, 0.7
DisplayChanged()
assert(profileBadge.width ~= previousWidth)
CheckLevelLabel(assert(FindText(profile, 9)))
CheckLevelLabel(assert(FindText(compact, 51)))
CheckLevelLabel(assert(FindText(compact, 42)))
local function PortraitMarker(anchor, texture)
    for _, tile in ipairs({ myName.parent, opponentName.parent }) do
        local death = tile.avatar.death
        if death.shown and death.anchor[2] == anchor and FindRegion(death, "texture", texture) then
            return death
        end
    end
end
local function CenterMarker(texture)
    local icon = FindRegion(compact, "texture", texture)
    local marker = icon and icon.parent
    if marker and marker.parent.parent == compact and marker.anchor[1] == "TOP" then return marker end
end
local function CheckPortraitMarker(rim, texture, corner)
    local marker = assert(PortraitMarker(rim, texture))
    local x = corner == "TOPRIGHT" and -10 or 10
    assert(marker.anchor[3] == corner and marker.anchor[4] == x and marker.anchor[5] == -10)
    return marker
end
local swords, skull, banner = addon.swordsIconPath, addon.smallSkullIconPath, addon.defeatBannerPath
local victory = assert(CenterMarker(swords))
assert(victory.width == fullVictory.width and victory.parent.anchor[4] == 0 and not CenterMarker(banner))
assert(FindRegion(victory, "atlas", "UI-HUD-UnitFrame-SmallCircle"))
assert(FindText(victory.parent, addon.L.winTooltip) and not victory.scripts.OnEnter)
assert(rivalPortrait.desaturated and not playerPortrait.desaturated)
local portraitDeath = CheckPortraitMarker(opponentRim, skull, "TOPLEFT")
assert(FindRegion(portraitDeath, "atlas", "UI-HUD-UnitFrame-SmallCircle"))
assert(portraitDeath.width == 20 and FindRegion(portraitDeath, "texture", skull).width == 14)
first.opponentRevived = true
compact:SetEncounter(first)
assert(portraitDeath.shown and not rivalPortrait.desaturated)
first.opponentRevived = nil
compact:SetEncounter(first)
assert(portraitDeath.shown and rivalPortrait.desaturated)
assert(not PortraitMarker(myRim, skull) and not PortraitMarker(opponentRim, swords))
faction = "Horde"
compact:SetEncounter(first)
AssertFullPortrait(rivalPortrait, true)
compact:SetEncounter(first)
AssertFullPortrait(rivalPortrait, true)
faction = "Alliance"
local open = assert(FindRegion(compact, "title", addon.L.openSkirmish))
local map = assert(FindRegion(compact, "title", addon.L.showOnMap))
assert(not FindText(compact, addon.L.openSkirmish) and not FindText(compact, addon.L.showOnMap))
assert(open.width == 32 and map.width == 32 and open.Icon.width == 16 and map.Icon.width == 16)
assert(open.Icon.anchor[4] == 0 and open.Icon.anchor[5] == 0.5)
assert(map.Icon.atlas == "Waypoint-MapPin-Untracked" and map.Icon.atlas == journalMap.Icon.atlas)
assert(map.anchor[1] == journalMap.anchor[1] and map.anchor[3] == journalMap.anchor[3])
for _, button in ipairs({ map, journalMap }) do
    assert(button.roundToPixel and button.Icon.roundToPixel)
    for i = 1, 2 do
        assert(button.Icon.anchor[2] == button and button.Icon.anchor[4] == 0 and button.Icon.anchor[5] == 0)
        button.scripts.OnMouseUp(button)
    end
end
local inset = map.insets[1]
local mapToInfo = open.anchor[4] - open.width + inset - (map.anchor[4] - inset)
local dateToMap = map.anchor[4] - map.width + inset - FindText(compact, date("%x", first.time)).anchor[2]
assert(mapToInfo == dateToMap and mapToInfo == 6)
local reportAction = assert(FindRegion(compact, "title", addon.L.reportIssue))
local reportID
function addon.OpenIssueReport(id) reportID = id end
assert(reportAction.shown and reportAction.anchor[4] - reportAction.width + inset - (open.anchor[4] - inset) == 6)
reportAction.scripts.OnClick()
assert(reportID == first.skirmishID)
card:SetSkirmish(large, "Player-test", true, first.skirmishID)
local fullReport = assert(FindRegion(card, "title", addon.L.reportIssue))
reportID = nil
fullReport.scripts.OnClick()
assert(reportID == first.skirmishID)
card:SetSkirmish(large, "Player-test", true, "rebound")
fullReport.scripts.OnClick()
assert(reportID == "rebound")
card:SetSkirmish(nil)
fullReport.scripts.OnClick()
assert(reportID == "rebound")
open.scripts.OnClick()
assert(openedSkirmish == "battle-one")
addon.ShowEncounterWaypoint = function(encounter) mapped = encounter; return true end
map.scripts.OnClick()
assert(openedMap and mapped == first)

compact:SetEncounter({ skirmishID = "battle-loss", contributionLosses = 1, playerDeathIndex = 1 })
assert(not GameTooltip.shown and not CenterMarker(swords))
local defeat = assert(CenterMarker(banner))
assert(not CenterMarker(skull))
assert(FindText(defeat.parent, addon.L.lossTooltip) and not defeat.scripts.OnEnter)
CheckPortraitMarker(myRim, skull, "TOPRIGHT")
assert(not PortraitMarker(opponentRim, swords) and defeat.parent.anchor[4] == 0)
compact:SetEncounter({ skirmishID = "win-while-dead", contributionWins = 1, playerDeathIndex = 1, opponentDeathIndex = 2 })
assert(not GameTooltip.shown and CenterMarker(swords) and not CenterMarker(banner))
CheckPortraitMarker(myRim, skull, "TOPRIGHT")
CheckPortraitMarker(opponentRim, skull, "TOPLEFT")
portraitDeath.scripts.OnEnter(portraitDeath)
assert(GameTooltip.shown and GameTooltip.title == addon.L.portraitDeath)
compact:SetEncounter({ skirmishID = "player-casualty", playerDeathIndex = 1 })
assert(not GameTooltip.shown and not CenterMarker(swords) and not CenterMarker(banner))
assert(PortraitMarker(myRim, skull) and not PortraitMarker(opponentRim, skull))
local noCreditMark = assert(FindText(compact, "–"))
assert(noCreditMark.parent.shown and FindText(noCreditMark.parent.parent, addon.L.noRivalCredit))
noCreditMark.parent.scripts.OnEnter(noCreditMark.parent)
assert(GameTooltip.shown and GameTooltip.title == addon.L.noRivalCreditHint)
compact:SetEncounter({ skirmishID = "battle-two" })
assert(not GameTooltip.shown and noCreditMark.parent.shown)
assert(not PortraitMarker(myRim, skull) and not PortraitMarker(opponentRim, skull))
assert(not FindText(compact, 51) and not FindText(compact, 42) and not map.shown)
open.scripts.OnClick()
assert(openedSkirmish == "battle-two")
reportAction.scripts.OnClick()
assert(reportID == "battle-two")
compact:SetEncounter({ skirmishID = "bg:22", origin = "battleground", zone = "Warsong Gulch" })
local warsong = "Warsong Gulch  |cffc9b8a2· " .. addon.L.battleground .. "|r"
assert(FindText(compact, warsong))
card:SetSkirmish({ allies = large.allies, enemies = large.enemies, events = {},
    origin = "battleground", zone = "Warsong Gulch" }, "Player-test", false, "bg:22")
assert(FindText(card, warsong))
fullReport.scripts.OnClick()
assert(reportID == "bg:22")
local loadedSelfPortrait
function SetPortraitTexture(_, unit, disableMasking)
    assert(unit == "player" and disableMasking)
    loadedSelfPortrait = true
end
local unitRace = UnitRace
UnitRace = nil
compact:SetEncounter({ direction = "killsAgainstThem", honorableKills = 1 }, { displayName = "Legacy Rival" })
CheckRewards(compact, "1", "0", 463450)
assert(FindText(compact, "Legacy Rival") and loadedSelfPortrait and not open.shown)
UnitRace = unitRace
assert(rivalPortrait.texture == "Interface\\Icons\\INV_Misc_QuestionMark")
assert(rivalPortrait.texcoords[1] < rivalPortrait.texcoords[2])
assert(not CenterMarker(swords) and noCreditMark.parent.shown)
local rivalSummary = assert(addon.Ledger.RivalSkirmishes(addon.db, duelGUID)[1])
compact:SetEncounter(rivalSummary, nil, duelGUID)
assert(FindText(compact, addon.FormatRivalCounters(2, 1, false, 0)))
assert(not CenterMarker(swords) and not CenterMarker(banner))
compact:SetEncounter({ contributionLosses = 2 })
assert(FindText(compact, addon.L.resultCount:format(addon.L.lossTooltip, 2)) and CenterMarker(banner))
compact:SetEncounter({ manual = true, direction = "killsAgainstThem" })
assert(FindText(compact, addon.L.qualifiedOutcome:format(addon.L.manual, addon.L.winTooltip)))
compact:SetEncounter({ outcome = "loss" })
assert(FindText(compact, addon.L.legacyResult) and CenterMarker(banner))
compact:SetEncounter(first)
AssertFullPortrait(rivalPortrait, true)
compact:SetEncounter(nil)
assert(not compact.shown)
print("Compact skirmish factions, team outcomes, casualties and actions checks passed")

local rivalID = "Player-sparse"
local knownRival = addon.Ledger.Add(addon.db, rivalID, "Sparse Rival")
knownRival.class, knownRival.classLabel, knownRival.race, knownRival.sex = "ROGUE", "Rogue", "scourge", 2
local self = { id = "Player-self", name = "Local Player", isSelf = true, level = 31 }
local opponent = { id = rivalID, rivalID = rivalID, name = knownRival.displayName }
local older = { time = 10, allies = { self }, enemies = { opponent }, events = {
    { kind = "kill", actorID = rivalID, targetID = self.id },
} }
local observed = { time = 20, allies = { self }, enemies = {
    { id = rivalID, rivalID = rivalID, name = knownRival.displayName, level = 32, class = "WARRIOR", classLabel = "Warrior" },
}, events = {} }
addon.Ledger.SaveSkirmish(addon.db, "sparse", older)
addon.Ledger.SaveSkirmish(addon.db, "observed", observed)
card:SetSkirmish(older)
local fullRival = assert(FindText(card, "Sparse Rival")).parent
local classBadge = CheckClassBadge(fullRival, "ROGUE", "Rogue", "BOTTOMLEFT")
assert(not FindText(card, "Rogue") and not FindText(card, "Mage"))
assert(FindRegion(fullRival, "atlas", "scourge-male") and not FindText(fullRival, 32) and not fullRival.avatar.death.shown)
local history = addon.RivalEncounters(addon.db, rivalID)
compact:SetEncounter(history[2], knownRival, rivalID)
assert(FindRegion(compact, "atlas", "human-female") and FindRegion(compact, "atlas", "scourge-male"))
assert(not FindText(compact, 32) and not FindText(compact, "~32") and not history[2].rivalLevel and not opponent.level)
compact:SetEncounter(history[1], knownRival, rivalID)
assert(FindText(compact, 32) and not FindText(compact, "~32"))
card:SetSkirmish(observed)
assert(CheckClassBadge(fullRival, "WARRIOR", "Warrior", "BOTTOMLEFT") == classBadge)
assert(not FindText(card, "Warrior") and not FindText(card, "~32"))
local unclassified = { id = "unclassified", name = "Longname Extraordinarilylongsurname", level = 54 }
card:SetSkirmish({ allies = older.allies, enemies = { unclassified }, events = {} })
assert(FindText(fullRival, unclassified.name).maxLines == 2 and not classBadge.shown)
local allyTile = assert(FindText(card, "Local Player")).parent
local allyIcon = CheckClassBadge(allyTile, "MAGE", "Mage", "BOTTOMRIGHT")
assert(allyIcon.anchor[3] == "BOTTOMRIGHT")
print("Sparse histories use known identity and display recorded levels only")

local skullLevelAtlas = "ui-hud-nameplates-levelindicator-skull"
observed.enemies[1].level = -1
card:SetSkirmish(observed)
assert(FindRegion(fullRival, "atlas", skullLevelAtlas) and not FindText(fullRival, -1))
compact:SetEncounter({ rivalLevel = -1 }, knownRival, rivalID)
assert(FindRegion(compact, "atlas", skullLevelAtlas) and not FindText(compact, -1))
compact:SetEncounter({ rivalLevel = 53 }, knownRival, rivalID)
assert(FindText(compact, 53) and not FindRegion(compact, "atlas", skullLevelAtlas))
compact:SetEncounter({}, knownRival, rivalID)
assert(not FindText(compact, 53) and not FindRegion(compact, "atlas", skullLevelAtlas))
print("Numeric, skull-level, and unknown badges survive card recycling")

-- Open the journal through the minimap and verify the actual profile's
-- native stats and latest card after late evidence, removal and data reset.
do
    local createFrame = CreateFrame
    local book, shortcut, openProfile
    UIParent, Minimap = MockRegion(), MockRegion()
    Minimap:SetSize(120, 120)
    function Minimap:GetFrameLevel() return 1 end
    function Minimap:GetWidth() return self.width end
    function Minimap:GetHeight() return self.height end
    UISpecialFrames, StaticPopupDialogs, SOUNDKIT = {}, {}, {}
    tinsert, BACK = table.insert, "Back"
    function PlaySound() end
    function PanelTemplates_SetNumTabs(parent)
        parent.Tabs = {}
        for _, child in ipairs(parent.children) do
            if child.template == "PanelTopTabButtonTemplate" then table.insert(parent.Tabs, child) end
        end
    end
    function PanelTemplates_SetTab(parent, id) parent.selectedTab = id end
    function PanelTemplates_GetSelectedTab(parent) return parent.selectedTab end
    function PanelTemplates_TabResize() end
    function addon.CreateRivalList(parent, selectRival)
        openProfile = selectRival
        return MockRegion(parent), MockRegion(parent)
    end
    function CreateFrame(frameType, frameName, parent, template)
        local frame = createFrame(frameType, frameName, parent, template)
        function frame:GetName() return frameName end
        function frame:GetWidth() return self.width or 0 end
        function frame:GetHeight() return self.height or 0 end
        function frame:GetFrameLevel() return 1 end
        function frame:IsShown() return self.shown end
        function frame:GetVerticalScroll() return self.scroll or 0 end
        function frame:SetVerticalScroll(value) self.scroll = value end
        if template == "SearchBoxTemplate" then frame:SetText("") end
        if template == "ScrollFrameTemplate" then frame.ScrollBar = MockRegion(frame) end
        if template == "PanelTopTabButtonTemplate" then
            frame.LeftActive, frame.MiddleActive, frame.RightActive = MockRegion(), MockRegion(), MockRegion()
        end
        if template == "LargeSideTabButtonTemplate" then frame.Icon = MockRegion(frame) end
        if frameName == "NamesInRedMinimapButton" then shortcut = frame end
        if frameName == "NamesInRedRivalBook" then
            book = frame
            local portrait = MockRegion(frame)
            function frame:GetPortrait() return portrait end
            frame.PortraitContainer = MockRegion(frame)
            frame.Bg, frame.TopTileStreaks = MockRegion(frame), MockRegion(frame)
        end
        return frame
    end

    directBattle.rewards = { [duelGUID] = { honorableKills = 1, honor = 5 } }
    addon.RecordSkirmish(duelRef, directBattle)
    bookLogin({ UnregisterEvent = function() end })
    shortcut.scripts.OnClick(shortcut, "LeftButton")
    openProfile(duelGUID)
    local function ProfileStat(label, value)
        assert(FindText(book, addon.L.statValue:format(label, value)))
    end
    ProfileStat(addon.L.wins, 2)
    ProfileStat(addon.L.losses, 1)
    ProfileStat(addon.L.honorableKills, 1)
    ProfileStat(addon.L.honor, 5)
    assert(FindText(book, addon.FormatRivalCounters(2, 1, false, 0)))

    directBattle.observation.segments[1].contributionLinks = {}
    addon.RecordSkirmish(duelRef, directBattle)
    ProfileStat(addon.L.wins, 1)
    ProfileStat(addon.L.losses, 1)
    ProfileStat(addon.L.honorableKills, 1)
    ProfileStat(addon.L.honor, 5)
    assert(FindText(book, addon.FormatRivalCounters(1, 1, false, 0)))

    local before = refreshes
    StaticPopupDialogs.NAMES_IN_RED_DELETE_RIVAL.OnAccept(nil, duelGUID)
    assert(not addon.db.rivals[duelGUID] and refreshes == before + 1)
    assert(not FindText(book, addon.FormatRivalCounters(1, 1, false, 0)))
    addon.ResetData()
    assert(not next(addon.db.rivals) and refreshes == before + 2)
end
print("Journal profile, compact card, unit tooltip refresh, removal and reset stay synchronized")
