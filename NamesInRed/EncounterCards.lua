local _, addon = ...
local L = addon.L
local azerothMapID = 947
local mapsByName

addon.encounterCardHeight = 136
addon.compactEncounterCardHeight = 138

local allianceColor = { 0.65, 0.83, 1 }
local hordeColor = { 1, 0.61, 0.52 }
local neutralColor = { 0.77, 0.71, 0.61 }

local function SideColors()
    local faction = UnitFactionGroup and addon.Readable(UnitFactionGroup("player"))
    if faction == "Horde" then return hordeColor, allianceColor end
    return allianceColor, hordeColor
end

local function HasCoordinates(encounter)
    local x, y = encounter.x, encounter.y
    return type(x) == "number" and type(y) == "number"
        and x >= 0 and x <= 1 and y >= 0 and y <= 1
        and (x ~= 0 or y ~= 0)
end

local function IsMapID(mapID)
    return type(mapID) == "number" and mapID > 0 and mapID < math.huge
        and mapID == math.floor(mapID)
end

local function IndexZoneMaps()
    local mapTypes = Enum and Enum.UIMapType
    if not mapTypes or not C_Map or not C_Map.GetMapChildrenInfo then return end
    local zones = C_Map.GetMapChildrenInfo(azerothMapID, mapTypes.Zone, true)
    if not zones or #zones == 0 then return end
    local index = {}
    for _, zone in ipairs(zones) do
        if index[zone.name] == nil then
            index[zone.name] = zone.mapID
        elseif index[zone.name] ~= zone.mapID then
            index[zone.name] = false
        end
    end
    return index
end

local function WaypointMap(encounter)
    if not encounter or not HasCoordinates(encounter) then return end
    if IsMapID(encounter.mapID) then return encounter.mapID end
    if encounter.mapID ~= nil or type(encounter.zone) ~= "string" or encounter.zone == "" then return end
    -- Legacy world encounters saved the localized zone name and coordinates.
    if not mapsByName then
        local ok, index = pcall(IndexZoneMaps)
        if ok then mapsByName = index end
    end
    local mapID = mapsByName and mapsByName[encounter.zone]
    if IsMapID(mapID) then return mapID end
end

local function PlaceWaypoint(encounter)
    local mapID = WaypointMap(encounter)
    if not mapID or not C_Map or not UiMapPoint or not OpenMapToUserWaypoint then return end
    local rules = Enum and Enum.GameRule
    if rules and C_GameRules and C_GameRules.IsGameRuleActive then
        if (rules.WorldMapDisabled and C_GameRules.IsGameRuleActive(rules.WorldMapDisabled))
            or (rules.WorldMapTrackingPinDisabled and C_GameRules.IsGameRuleActive(rules.WorldMapTrackingPinDisabled)) then
            return
        end
    end
    if not addon.Readable(C_Map.CanSetUserWaypointOnMap(mapID)) then return end
    local point = UiMapPoint.CreateFromCoordinates(mapID, encounter.x, encounter.y)
    if not addon.Readable(C_Map.SetUserWaypoint(point)) then return end
    OpenMapToUserWaypoint()
    return true
end

function addon.ShowEncounterWaypoint(encounter)
    local ok, opened = pcall(PlaceWaypoint, encounter)
    return ok and opened == true
end

local function ActivateWaypoint(encounter, onMapShown)
    if addon.ShowEncounterWaypoint(encounter) then
        onMapShown()
    elseif UIErrorsFrame then
        UIErrorsFrame:AddMessage(L.waypointError, 1, 0.25, 0.25)
    end
end

local function HideTooltip(button)
    local tooltip = GetAppropriateTooltip and GetAppropriateTooltip() or GameTooltip
    if tooltip:IsOwned(button) then tooltip:Hide() end
end

local function ShowAttackers(button, attackers)
    local tooltip = GetAppropriateTooltip and GetAppropriateTooltip() or GameTooltip
    tooltip:SetOwner(button, "ANCHOR_RIGHT")
    tooltip:SetText(L.attackers)
    for index, attacker in ipairs(attackers) do
        local name = attacker.name or L.unknownRival
        tooltip:AddLine(index == 1 and L.finishingBlow:format(name) or name, 1, 1, 1, true)
    end
    tooltip:Show()
end

local function Label(parent, font, point, x, y, width)
    local label = parent:CreateFontString(nil, "OVERLAY", font)
    label:SetPoint(point, x, y)
    label:SetWidth(width)
    label:SetJustifyH(point == "TOPRIGHT" and "RIGHT" or "LEFT")
    label:SetWordWrap(false)
    return label
end

local function LevelText(level)
    return type(level) == "number" and level > 0 and level or "—"
end

local function EncounterDate(encounter)
    if not encounter.time then return encounter.manual and L.manual or "—", "" end
    local calendar = date("*t", encounter.time)
    local day = FormatShortDate and FormatShortDate(calendar.day, calendar.month, calendar.year)
        or date("%x", encounter.time)
    local time = GameTime_GetFormattedTime and GameTime_GetFormattedTime(calendar.hour, calendar.min, true)
        or date("%H:%M", encounter.time)
    return day, time
end

local function CreateCard(parent, width, height)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(width, height)
    card:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    card:SetBackdropColor(0.085, 0.06, 0.04, 0.72)
    card:SetBackdropBorderColor(0.56, 0.42, 0.27, 0.9)
    return card
end

function addon.CreateEncounterCard(parent, width, onMapShown, profileWidth)
    local card = CreateCard(parent, width, addon.encounterCardHeight)

    local body = card
    if profileWidth then
        card.profile = CreateFrame("Frame", nil, card)
        card.profile:SetPoint("TOPLEFT")
        card.profile:SetSize(profileWidth, addon.encounterCardHeight)
        local seam = card:CreateTexture(nil, "ARTWORK")
        seam:SetPoint("TOPLEFT", profileWidth, -12)
        seam:SetPoint("BOTTOMLEFT", profileWidth, 12)
        seam:SetWidth(1)
        seam:SetColorTexture(0.56, 0.42, 0.27, 0.45)

        body = CreateFrame("Frame", nil, card)
        body:SetPoint("TOPLEFT", profileWidth, 0)
        body:SetPoint("BOTTOMRIGHT")
        width = width - profileWidth
    end

    local icon = body:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 12, -11)
    icon:SetSize(28, 28)
    local outcome = Label(body, "GameFontNormal", "TOPLEFT", 48, -18, width - 181)
    local day = Label(body, "GameFontHighlightSmall", "TOPRIGHT", -13, -12, 120)
    local time = Label(body, "GameFontHighlightSmall", "TOPRIGHT", -13, -26, 120)
    local divider = body:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 12, -45)
    divider:SetPoint("TOPRIGHT", -12, -45)
    divider:SetHeight(1)
    divider:SetColorTexture(0.56, 0.42, 0.27, 0.45)

    local zone = Label(body, "GameFontHighlight", "TOPLEFT", 13, -54, width - 26)
    time:SetTextColor(0.77, 0.71, 0.61)

    local myCaption = Label(body, "GameFontNormalSmall", "TOPLEFT", 13, -96, 79)
    myCaption:SetText(L.myLevel)
    local rivalCaption = Label(body, "GameFontNormalSmall", "TOPLEFT", 98, -96, 107)
    rivalCaption:SetText(L.rivalLevel)
    local myLevel = Label(body, "GameFontHighlight", "TOPLEFT", 13, -110, 79)
    local rivalLevel = Label(body, "GameFontHighlight", "TOPLEFT", 98, -110, 107)
    local map = CreateFrame("Button", nil, body, "SharedButtonSmallTemplate")
    local mapButtonWidth = 130
    map:SetPoint("TOPRIGHT", -12, -53)
    map:SetSize(mapButtonWidth, 25)
    map:SetText(L.showOnMap)

    map:SetScript("OnClick", function()
        ActivateWaypoint(card.encounter, onMapShown)
    end)

    local attackers = CreateFrame("Button", nil, body, "SharedButtonSmallTemplate")
    attackers:SetPoint("BOTTOMRIGHT", -12, 11)
    attackers:SetSize(130, 25)
    attackers:SetText(L.attackers)
    attackers:SetScript("OnEnter", function(self)
        ShowAttackers(self, card.encounter.attackers)
    end)
    attackers:SetScript("OnLeave", HideTooltip)
    attackers:HookScript("OnHide", HideTooltip)

    function card:SetEncounter(encounter)
        if self.encounter ~= encounter then
            HideTooltip(attackers)
        end
        self.encounter = encounter
        self:SetShown(encounter ~= nil)
        if not encounter then return end

        local victory = encounter.direction == "killsAgainstThem"
        icon:SetTexture(victory and addon.swordsIconPath or addon.skullIconPath)
        local inset = victory and 0.16 or 0.08
        icon:SetTexCoord(inset, 1 - inset, inset, 1 - inset)
        outcome:SetText(victory and L.win or L.loss)
        if victory then outcome:SetTextColor(0.65, 0.83, 1) else outcome:SetTextColor(1, 0.61, 0.52) end
        local encounterDay, encounterTime = EncounterDate(encounter)
        day:SetText(encounterDay)
        time:SetText(encounterTime)
        local hasWaypoint = WaypointMap(encounter) ~= nil
        zone:SetWidth(hasWaypoint and width - 33 - mapButtonWidth or width - 26)
        zone:SetText(encounter.zone and encounter.zone ~= "" and encounter.zone or L.unknownLocation)
        myLevel:SetText(LevelText(encounter.playerLevel))
        rivalLevel:SetText(LevelText(encounter.rivalLevel))
        map:SetShown(hasWaypoint)
        attackers:SetShown(type(encounter.attackers) == "table" and #encounter.attackers > 0)
    end

    return card
end

function addon.SkirmishCardHeight(battle)
    local rosterHeight = 29 * math.max(#battle.allies, #battle.enemies, 1)
    local eventHeight = #battle.events > 0 and 22 + 19 * #battle.events or 0
    return 102 + rosterHeight + eventHeight
end

local function Divider(card, top)
    local line = card:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", 14, top)
    line:SetPoint("TOPRIGHT", -14, top)
    line:SetHeight(1)
    line:SetColorTexture(0.56, 0.42, 0.27, 0.45)
    return line
end

local compactActionSize = 32
local compactActionInset = 4
local compactHeaderGap = 6
local compactActionStep = compactActionSize - 2 * compactActionInset + compactHeaderGap
local compactActionRight = 11

local function CompactAction(card)
    local button = CreateFrame("Button", nil, card, "CommonSquareIconButtonTemplate")
    button:SetSize(compactActionSize, compactActionSize)
    button:SetHitRectInsets(compactActionInset, compactActionInset, compactActionInset, compactActionInset)
    button:RegisterForClicks("LeftButtonUp")
    button.Icon:SetSize(16, 16)
    -- Apply the template's resting icon position before the first click.
    button:OnMouseUp()
    button:SetTooltipAnchor("ANCHOR_TOP")
    button:HookScript("OnHide", HideTooltip)
    return button
end

local function OutcomeTexture(parent, size, victory)
    local icon = parent:CreateTexture(nil, "OVERLAY", nil, 1)
    icon:SetSize(size, size)
    icon:SetTexture(victory and addon.swordsIconPath or addon.smallSkullIconPath)
    if victory then
        local inset = addon.smallSwordsInset / 128
        icon:SetTexCoord(inset, 1 - inset, inset, 1 - inset)
    end
    return icon
end

local function CompactParticipant(card, x, size, nameWidth)
    local portrait, rim = addon.CreateRoundIcon(card, size)
    rim:SetPoint("TOPLEFT", x - size / 2, -47)
    local level = addon.CreateLevelBadge(card, rim)
    local name = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetPoint("TOP", rim, "BOTTOM", 0, -4)
    name:SetWidth(nameWidth)
    name:SetJustifyH("CENTER")
    name:SetWordWrap(false)
    local victory = OutcomeTexture(card, 14, true)
    victory:SetPoint("CENTER", rim, "TOPRIGHT", -10, -10)
    local death = OutcomeTexture(card, 14, false)
    death:SetPoint("CENTER", rim, "TOPLEFT", 10, -10)
    return { portrait = portrait, level = level, name = name, victory = victory, death = death }
end

local function CompactOutcome(card, victory)
    local marker = CreateFrame("Frame", nil, card)
    marker:SetSize(24, 24)
    OutcomeTexture(marker, 24, victory):SetPoint("CENTER")
    marker:SetMouseMotionEnabled(true)
    marker:SetScript("OnEnter", function(self)
        local tooltip = GetAppropriateTooltip and GetAppropriateTooltip() or GameTooltip
        tooltip:SetOwner(self, "ANCHOR_TOP")
        tooltip:SetText(victory and L.winTooltip or L.lossTooltip)
        tooltip:Show()
    end)
    marker:SetScript("OnLeave", HideTooltip)
    marker:SetScript("OnHide", HideTooltip)
    return marker
end

function addon.CreateCompactEncounterCard(parent, width, onMapShown, openSkirmish)
    local card = CreateCard(parent, width, addon.compactEncounterCardHeight)
    local zone = Label(card, "GameFontHighlight", "TOPLEFT", 13, -14, width - 167)
    zone:SetWordWrap(true)
    zone:SetMaxLines(2)
    local day = Label(card, "GameFontHighlightSmall", "TOPRIGHT", -13, -9, 96)
    local time = Label(card, "GameFontHighlightSmall", "TOPRIGHT", -13, -23, 96)
    time:SetTextColor(unpack(neutralColor))
    Divider(card, -41)

    local portraitSize = 64
    local mine = CompactParticipant(card, width / 4, portraitSize, width / 2 - 18)
    local theirs = CompactParticipant(card, 3 * width / 4, portraitSize, width / 2 - 18)
    local victory = CompactOutcome(card, true)
    local defeat = CompactOutcome(card, false)

    local map = CompactAction(card)
    map:SetAtlas("Waypoint-MapPin-Untracked")
    map:SetTooltipInfo(L.showOnMap)
    map:SetOnClickHandler(function()
        if card.encounter then ActivateWaypoint(card.encounter, onMapShown) end
    end)
    local info = CompactAction(card)
    info:SetPoint("TOPRIGHT", -compactActionRight, -5)
    info:SetIcon("Interface\\FriendsFrame\\InformationIcon")
    info:SetOnEnterHandler(function(self)
        local encounter = card.encounter
        if encounter and not encounter.skirmishID and encounter.attackers and #encounter.attackers > 0 then
            ShowAttackers(self, encounter.attackers)
            return true
        end
    end)
    info:SetOnClickHandler(function(self)
        local encounter = card.encounter
        if not encounter then return end
        if encounter.skirmishID then
            openSkirmish(encounter.skirmishID)
        elseif encounter.attackers and #encounter.attackers > 0 then
            ShowAttackers(self, encounter.attackers)
        end
    end)

    function card:SetEncounter(encounter, rival, rivalID)
        if self.encounter ~= encounter then
            HideTooltip(map)
            HideTooltip(info)
            HideTooltip(victory)
            HideTooltip(defeat)
        end
        self.encounter = encounter
        self:SetShown(encounter ~= nil)
        if not encounter then return end

        local player, opponent = encounter.player, encounter.opponent
        local playerName = player and addon.ManualName(player.name) or addon.UnitPlayerName("player")
        local opponentName = opponent and addon.ManualName(opponent.name) or rival and addon.ManualName(rival.displayName)
        mine.name:SetText(playerName or YOU or L.unknownPlayer)
        theirs.name:SetText(opponentName or L.unknownRival)
        local allyColor, enemyColor = SideColors()
        mine.name:SetTextColor(unpack(allyColor))
        theirs.name:SetTextColor(unpack(enemyColor))
        if player and player.race and player.sex then
            addon.SetRivalPortrait(mine.portrait, player, nil, portraitSize)
        elseif SetPortraitTexture then
            mine.portrait:SetSize(portraitSize * 13 / 16, portraitSize * 13 / 16)
            SetPortraitTexture(mine.portrait, "player", true)
            mine.portrait:SetTexCoord(0, 1, 0, 1)
        else
            addon.SetRivalPortrait(mine.portrait, player or {}, nil, portraitSize)
        end
        local appearance = opponent or rival or {}
        if not appearance.race and rival and rival.race then appearance = rival end
        addon.SetRivalPortrait(theirs.portrait, appearance, rivalID, portraitSize)
        mine.level:SetLevel(encounter.playerLevel)
        theirs.level:SetLevel(encounter.rivalLevel)

        local won = encounter.direction == "killsAgainstThem" or (encounter.wins or 0) > 0
        local lost = encounter.direction == "deathsToThem" or (encounter.losses or 0) > 0
        victory:SetPoint("CENTER", card, "TOP", lost and -15 or 0, -79)
        defeat:SetPoint("CENTER", card, "TOP", won and 15 or 0, -79)
        victory:SetShown(won)
        defeat:SetShown(lost)
        mine.victory:SetShown(won)
        theirs.victory:SetShown(lost)
        mine.death:SetShown(lost or encounter.playerDeathIndex ~= nil)
        theirs.death:SetShown(won or encounter.opponentDeathIndex ~= nil)

        local hasWaypoint = WaypointMap(encounter) ~= nil
        local hasInfo = encounter.skirmishID ~= nil or type(encounter.attackers) == "table" and #encounter.attackers > 0
        local mapRight = compactActionRight + (hasInfo and compactActionStep or 0)
        local firstActionRight = hasWaypoint and mapRight or hasInfo and compactActionRight
        local stampRight = firstActionRight
            and firstActionRight + compactActionSize - compactActionInset + compactHeaderGap or 13
        local stampWidth = encounter.manual and not encounter.time and 136 or 96
        day:SetPoint("TOPRIGHT", -stampRight, -9)
        day:SetWidth(stampWidth)
        time:SetPoint("TOPRIGHT", -stampRight, -23)
        local encounterDay, encounterTime = EncounterDate(encounter)
        day:SetText(encounterDay)
        time:SetText(encounterTime)
        zone:SetWidth(width - 20 - stampRight - stampWidth)
        zone:SetText(encounter.zone and encounter.zone ~= "" and encounter.zone or L.unknownLocation)
        map:SetPoint("TOPRIGHT", -mapRight, -5)
        map:SetShown(hasWaypoint)
        info:SetShown(hasInfo)
        info:SetTooltipInfo(encounter.skirmishID and L.openSkirmish or L.attackers)
    end
    return card
end

function addon.CreateSkirmishCard(parent, width, onMapShown, openRival)
    local card = CreateCard(parent, width, 1)
    local columnWidth = math.floor(width / 2) - 26
    local zone = Label(card, "GameFontHighlight", "TOPLEFT", 14, -16, columnWidth - 76)
    local score = Label(card, "GameFontNormal", "TOP", 0, -15, 194)
    score:SetJustifyH("CENTER")
    local stamp = Label(card, "GameFontHighlightSmall", "TOPRIGHT", -14, -17, columnWidth - 76)
    stamp:SetTextColor(0.77, 0.71, 0.61)
    Divider(card, -36)

    local function CreateSide(x, caption)
        local title = Label(card, "GameFontNormalSmall", "TOPLEFT", x, -47, columnWidth)
        title:SetText(caption)
        local side = CreateFrame("Frame", nil, card)
        side:SetPoint("TOPLEFT", x, -62)
        side:SetSize(columnWidth, 1)
        local rows = {}
        return function(players, color, selectedRivalID)
            title:SetTextColor(unpack(color))
            side:SetHeight(math.max(1, #players * 29))
            for i = 1, math.max(#players, #rows) do
                local player, row = players[i], rows[i]
                if not row then
                    row = CreateFrame("Button", nil, side)
                    row:SetSize(columnWidth, 27)
                    row:SetPoint("TOPLEFT", 0, -(i - 1) * 29)
                    local hover = row:CreateTexture(nil, "HIGHLIGHT")
                    hover:SetAllPoints(row)
                    hover:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
                    hover:SetVertexColor(0.70, 0.54, 0.36)
                    hover:SetAlpha(0.24)
                    row:SetHighlightTexture(hover, "ADD")
                    row.selection = row:CreateTexture(nil, "ARTWORK")
                    row.selection:SetAllPoints()
                    addon.ApplyAtlas(row.selection, "Professions_Recipe_Active")
                    row.selection:SetAlpha(0.45)
                    row:SetScript("OnClick", function(self)
                        if self.rivalID then openRival(self.rivalID) end
                    end)
                    row.icon = row:CreateTexture(nil, "ARTWORK")
                    row.icon:SetSize(22, 22)
                    row.icon:SetPoint("LEFT", 2, 0)
                    row.name = Label(row, "GameFontHighlightSmall", "TOPLEFT", 31, -2, columnWidth - 67)
                    row.class = Label(row, "GameFontHighlightSmall", "TOPLEFT", 31, -14, columnWidth - 67)
                    row.class:SetTextColor(0.76, 0.70, 0.62)
                    row.level = Label(row, "GameFontNormal", "TOPRIGHT", -5, -7, 34)
                    rows[i] = row
                end
                row:SetShown(player ~= nil)
                if player then
                    row.selection:SetShown(selectedRivalID ~= nil and player.rivalID == selectedRivalID)
                    local name = player.name or L.unknownPlayer
                    row.name:SetText(player.isSelf and YOU and (name .. " • " .. YOU) or name)
                    local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[player.class]
                    row.name:SetTextColor(classColor and classColor.r or 1, classColor and classColor.g or 1,
                        classColor and classColor.b or 1)
                    local classes = player.sex == 3 and LOCALIZED_CLASS_NAMES_FEMALE or LOCALIZED_CLASS_NAMES_MALE
                    row.class:SetText(classes and classes[player.class] or player.classLabel or "")
                    row.level:SetText(LevelText(player.level))
                    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[player.class]
                    row.icon:SetTexture(coords and "Interface\\TargetingFrame\\UI-Classes-Circles"
                        or "Interface\\Icons\\INV_Misc_QuestionMark")
                    if coords then row.icon:SetTexCoord(unpack(coords)) else row.icon:SetTexCoord(0, 1, 0, 1) end
                    local rival = player.rivalID and addon.db.rivals[player.rivalID]
                    row.rivalID = rival and addon.IsRosterRival(player.rivalID, rival) and player.rivalID or nil
                    row:EnableMouse(row.rivalID ~= nil)
                end
            end
        end
    end

    local setAllies = CreateSide(14, L.alliedSide)
    local setEnemies = CreateSide(math.floor(width / 2) + 12, L.enemySide)
    local events = CreateFrame("Frame", nil, card)
    events:SetSize(width, 1)
    Divider(events, 0)
    local eventTitle = Label(events, "GameFontNormalSmall", "TOPLEFT", 14, -7, width - 28)
    eventTitle:SetText(L.finishingBlows)
    local eventRows = {}
    local map = CreateFrame("Button", nil, card, "SharedButtonSmallTemplate")
    map:SetPoint("BOTTOMRIGHT", -14, 10)
    map:SetSize(130, 25)
    map:SetText(L.showOnMap)
    map:SetScript("OnClick", function()
        ActivateWaypoint(card.skirmish, onMapShown)
    end)
    function card:SetSkirmish(battle, selectedRivalID)
        self.skirmish = battle
        self:SetShown(battle ~= nil)
        if not battle then return end
        self:SetHeight(addon.SkirmishCardHeight(battle))
        zone:SetText(battle.zone or L.unknownLocation)
        score:SetText(battle.rosterComplete and ("%d × %d"):format(#battle.allies, #battle.enemies)
            or L.partialRoster)
        local day, time = EncounterDate(battle)
        stamp:SetText(day .. "  " .. time)
        local allyColor, enemyColor = SideColors()
        setAllies(battle.allies, allyColor)
        setEnemies(battle.enemies, enemyColor, selectedRivalID)
        local players, colors = {}, {}
        for _, player in ipairs(battle.allies) do players[player.id], colors[player.id] = player, allyColor end
        for _, player in ipairs(battle.enemies) do players[player.id], colors[player.id] = player, enemyColor end

        events:ClearAllPoints()
        events:SetPoint("TOPLEFT", 0, -66 - 29 * math.max(#battle.allies, #battle.enemies, 1))
        events:SetHeight(math.max(1, 22 + 19 * #battle.events))
        events:SetShown(#battle.events > 0)
        for i = 1, math.max(#battle.events, #eventRows) do
            local event, row = battle.events[i], eventRows[i]
            if not row then
                local y = -22 - (i - 1) * 19
                local from = Label(events, "GameFontHighlightSmall", "TOPLEFT", 64, y, columnWidth - 52)
                local arrow = events:CreateTexture(nil, "ARTWORK")
                if addon.ApplyAtlas(arrow, "common-icon-forwardarrow") then
                    arrow:SetPoint("TOP", 0, y - 2)
                    arrow:SetSize(10, 10)
                    arrow:SetAlpha(0.75)
                else
                    arrow = Label(events, "GameFontNormalSmall", "TOP", 0, y, 18)
                    arrow:SetJustifyH("CENTER")
                    arrow:SetText(">")
                end
                row = {
                    Label(events, "GameFontHighlightSmall", "TOPLEFT", 15, y, 45), from, arrow,
                    Label(events, "GameFontHighlightSmall", "TOPLEFT", math.floor(width / 2) + 14, y, columnWidth),
                }
                eventRows[i] = row
            end
            for _, region in ipairs(row) do region:SetShown(event ~= nil) end
            if event then
                local actor, target = players[event.actorID], players[event.targetID]
                local elapsed = event.time and battle.startedAt and math.max(0, event.time - battle.startedAt)
                row[1]:SetText(elapsed and ("%d:%02d"):format(math.floor(elapsed / 60), elapsed % 60) or "")
                row[2]:SetText(actor and actor.name or L.unknownPlayer)
                row[2]:SetTextColor(unpack(colors[event.actorID] or neutralColor))
                row[4]:SetText(target and target.name or L.unknownPlayer)
                row[4]:SetTextColor(unpack(colors[event.targetID] or neutralColor))
            end
        end
        map:SetShown(WaypointMap(battle) ~= nil)
    end
    return card
end
