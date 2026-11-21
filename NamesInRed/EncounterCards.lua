local _, addon = ...
local L = addon.L
local azerothMapID = 947
local mapsByName

addon.compactEncounterCardHeight = 138

local allianceColor = { 0.65, 0.83, 1 }
local hordeColor = { 1, 0.61, 0.52 }
local neutralColor = { 0.77, 0.71, 0.61 }
local allianceEmblem = "UI-HUD-UnitFrame-SmallCircle-Alliance"
local hordeEmblem = "UI-HUD-UnitFrame-SmallCircle-Horde"

local function SideColors()
    local faction = UnitFactionGroup and addon.Readable(UnitFactionGroup("player"))
    if faction == "Horde" then return hordeColor, allianceColor, true end
    return allianceColor, hordeColor, false
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

local function Label(parent, font, point, x, y, width, relativePoint)
    local label = parent:CreateFontString(nil, "OVERLAY", font)
    if relativePoint then label:SetPoint(point, parent, relativePoint, x, y) else label:SetPoint(point, x, y) end
    label:SetWidth(width)
    label:SetJustifyH((point == "TOPRIGHT" or point == "RIGHT") and "RIGHT" or "LEFT")
    label:SetWordWrap(false)
    return label
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

local cardInset = 14
local sectionPadding = 8
local fullHeaderCenter = -18
-- Keep equal space between the map button and the inside edges of the header.
local fullHeaderDivider = 2 * fullHeaderCenter + 2
local rosterTop, rosterHeaderHeight, rosterRowHeight = fullHeaderDivider - sectionPadding, 27, 81
local portraitSize, rosterGutter = 50, 100
local finishingBlowFirstRow, finishingBlowStep = 26, 19

local function RosterRows(count)
    if count <= 2 then return 1 end
    return math.max(2, math.ceil(count / 3))
end

local function RosterHeight(battle)
    local rows = RosterRows(math.max(#battle.allies, #battle.enemies))
    return rosterHeaderHeight + sectionPadding * 2 + rows * rosterRowHeight
end

local function TimelineHeight(count, expanded)
    if count == 0 then return 0 end
    return finishingBlowFirstRow + (expanded and finishingBlowStep * count or 0)
end

local function RosterBottom(height)
    return rosterTop - height - sectionPadding
end

function addon.SkirmishCardHeight(battle, expanded)
    local count = 0
    for _, event in ipairs(battle.events) do
        if event.kind == "kill" then count = count + 1 end
    end
    return -RosterBottom(RosterHeight(battle)) + TimelineHeight(count, expanded)
end

local dividers = setmetatable({}, { __mode = "k" })

local function SizeDivider(line)
    local factor = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()
    line:SetHeight(factor and factor / line:GetEffectiveScale() or 1)
end

if PixelUtil and PixelUtil.GetPixelToUIUnitFactor then
    local layoutEvents = CreateFrame("Frame")
    layoutEvents:RegisterEvent("UI_SCALE_CHANGED")
    layoutEvents:RegisterEvent("DISPLAY_SIZE_CHANGED")
    layoutEvents:SetScript("OnEvent", function()
        for line in pairs(dividers) do SizeDivider(line) end
    end)
end

local function Divider(card, top, inset)
    inset = inset or cardInset
    local line = card:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", inset, top)
    line:SetPoint("TOPRIGHT", -inset, top)
    line:SetRoundLayoutToNearestPixel(true)
    SizeDivider(line)
    dividers[line] = true
    line:SetColorTexture(0.56, 0.42, 0.27, 0.45)
    return line
end

local compactActionSize = 32
local compactActionInset = 4
local compactHeaderGap = 6
local compactActionStep = compactActionSize - 2 * compactActionInset + compactHeaderGap
local compactActionRight = 11
local compactIconY = 0.5

local function CardActionButton(card, iconY)
    local button = CreateFrame("Button", nil, card, "CommonSquareIconButtonTemplate")
    button:SetSize(compactActionSize, compactActionSize)
    button:SetHitRectInsets(compactActionInset, compactActionInset, compactActionInset, compactActionInset)
    button:RegisterForClicks("LeftButtonUp")
    button.Icon:SetSize(16, 16)
    local function CenterIcon(self)
        self.Icon:SetPoint("CENTER", self, "CENTER", 0, iconY or 0)
    end
    CenterIcon(button)
    button:HookScript("OnMouseUp", CenterIcon)
    button:SetTooltipAnchor("ANCHOR_TOP")
    button:HookScript("OnHide", HideTooltip)
    return button
end

local function MapAction(card, onClick)
    local map = CardActionButton(card)
    map:SetAtlas("Waypoint-MapPin-Untracked")
    map:SetRoundLayoutToNearestPixel(true)
    map.Icon:SetRoundLayoutToNearestPixel(true)
    map:SetTooltipInfo(L.showOnMap)
    map:SetOnClickHandler(onClick)
    return map
end

local function StampRight(actionRight)
    return actionRight and actionRight + compactActionSize - compactActionInset + compactHeaderGap or cardInset
end

local function OutcomeMarker(parent, size, texture, tooltipText, framed)
    local marker = CreateFrame("Frame", nil, parent)
    marker:SetSize(size, size)
    if framed then
        local rim = marker:CreateTexture(nil, "BACKGROUND")
        rim:SetAllPoints()
        if not addon.ApplyAtlas(rim, "UI-HUD-UnitFrame-SmallCircle") then rim:SetTexture(addon.levelBadgePath) end
        if texture == addon.smallSkullIconPath then rim:SetVertexColor(1, 0.68, 0.64) end
    end
    if not texture then
        local mark = marker:CreateFontString(nil, "OVERLAY", size >= 24 and "GameFontNormalLarge" or "GameFontNormal")
        mark:SetPoint("CENTER")
        mark:SetText("?")
    else
        local icon = marker:CreateTexture(nil, "OVERLAY", nil, 1)
        local iconSize = framed and size * 0.7 or size
        icon:SetSize(iconSize, iconSize)
        icon:SetPoint("CENTER")
        icon:SetTexture(texture)
        if texture == addon.swordsIconPath then
            local inset = addon.smallSwordsInset / 128
            icon:SetTexCoord(inset, 1 - inset, inset, 1 - inset)
        end
    end
    marker:SetMouseMotionEnabled(true)
    marker:SetScript("OnEnter", function(self)
        local tooltip = GetAppropriateTooltip and GetAppropriateTooltip() or GameTooltip
        tooltip:SetOwner(self, "ANCHOR_TOP")
        tooltip:SetText(tooltipText)
        tooltip:Show()
    end)
    marker:SetScript("OnLeave", HideTooltip)
    marker:SetScript("OnHide", HideTooltip)
    return marker
end

local function CreateOutcomeMarkers(card, y, swordSize, bannerSize, framed)
    local markers = {
        win = OutcomeMarker(card, swordSize, addon.swordsIconPath, L.winTooltip, framed),
        loss = OutcomeMarker(card, bannerSize, addon.defeatBannerPath, L.lossTooltip, framed),
        unknown = OutcomeMarker(card, swordSize, nil, L.unknownOutcome, framed),
    }
    for _, marker in pairs(markers) do
        marker:SetPoint("CENTER", card, "TOP", 0, y)
        marker:Hide()
    end
    return function(outcome, changed)
        for result, marker in pairs(markers) do
            if changed then HideTooltip(marker) end
            marker:SetShown(outcome == result)
        end
    end
end

local function CompactParticipant(card, x, size, nameWidth, isOpponent)
    local portrait, rim = addon.CreateRoundIcon(card, size)
    rim:SetPoint("TOPLEFT", x - size / 2, -47)
    local level = addon.CreateLevelBadge(card, rim, isOpponent)
    local name = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetPoint("TOP", rim, "BOTTOM", 0, -4)
    name:SetWidth(nameWidth)
    name:SetJustifyH("CENTER")
    name:SetWordWrap(false)
    local death = OutcomeMarker(card, 20, addon.smallSkullIconPath, L.portraitDeath, true)
    death:SetPoint("CENTER", rim, isOpponent and "TOPLEFT" or "TOPRIGHT", isOpponent and 10 or -10, -10)
    return { portrait = portrait, level = level, name = name, death = death }
end

local compactHeaderCenter, compactOutcomeY = -21, -79

function addon.CreateCompactEncounterCard(parent, width, onMapShown, openSkirmish)
    local card = CreateCard(parent, width, addon.compactEncounterCardHeight)
    local zone = Label(card, "GameFontHighlight", "LEFT", cardInset, compactHeaderCenter, width - 167, "TOPLEFT")
    zone:SetWordWrap(true)
    zone:SetMaxLines(2)
    local day = Label(card, "GameFontHighlightSmall", "TOPRIGHT", -cardInset, -9, 96)
    local time = Label(card, "GameFontHighlightSmall", "TOPRIGHT", -cardInset, -23, 96)
    time:SetTextColor(unpack(neutralColor))
    Divider(card, -41)

    local portraitSize = 64
    local mine = CompactParticipant(card, width / 4, portraitSize, width / 2 - 18, false)
    local theirs = CompactParticipant(card, 3 * width / 4, portraitSize, width / 2 - 18, true)
    local setOutcome = CreateOutcomeMarkers(card, compactOutcomeY, 24, 31)

    local map = MapAction(card, function()
        if card.encounter then ActivateWaypoint(card.encounter, onMapShown) end
    end)
    local info = CardActionButton(card, compactIconY)
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
        local changed = self.encounter ~= encounter
        if changed then
            HideTooltip(map)
            HideTooltip(info)
            HideTooltip(mine.death)
            HideTooltip(theirs.death)
        end
        self.encounter = encounter
        self:SetShown(encounter ~= nil)
        setOutcome(encounter and (addon.Ledger.EncounterOutcome(encounter) or "unknown"), changed)
        if not encounter then return end

        local player, opponent = encounter.player, encounter.opponent
        local playerName = player and addon.ManualName(player.name) or addon.UnitPlayerName("player")
        local opponentName = opponent and addon.ManualName(opponent.name) or rival and addon.ManualName(rival.displayName)
        mine.name:SetText(playerName or YOU or L.unknownPlayer)
        theirs.name:SetText(opponentName or L.unknownRival)
        local allyColor, enemyColor = SideColors()
        mine.name:SetTextColor(unpack(allyColor))
        theirs.name:SetTextColor(unpack(enemyColor))
        local playerAppearance = addon.UnitAppearance("player")
        local race = player and player.race or playerAppearance.race
        local sex = player and player.sex or playerAppearance.sex
        if race and sex then
            addon.SetRivalPortrait(mine.portrait, { race = race, sex = sex,
                class = player and player.class or playerAppearance.class }, nil, portraitSize)
        elseif SetPortraitTexture then
            mine.portrait:SetSize(portraitSize * 13 / 16, portraitSize * 13 / 16)
            SetPortraitTexture(mine.portrait, "player", true)
            mine.portrait:SetTexCoord(0, 1, 0, 1)
        else
            addon.SetRivalPortrait(mine.portrait, player or {}, nil, portraitSize)
        end
        local appearance = opponent or rival or {}
        if not appearance.race and rival and rival.race then appearance = rival end
        addon.SetRivalPortrait(theirs.portrait, appearance, rivalID, portraitSize, true)
        mine.level:SetLevel(encounter.playerLevel)
        theirs.level:SetLevel(encounter.rivalLevel)

        mine.death:SetShown(encounter.playerDeathIndex ~= nil
            or (not encounter.manual and encounter.direction == "deathsToThem"))
        theirs.death:SetShown(encounter.opponentDeathIndex ~= nil
            or (not encounter.manual and encounter.direction == "killsAgainstThem"))

        local hasWaypoint = WaypointMap(encounter) ~= nil
        local hasInfo = encounter.skirmishID ~= nil or type(encounter.attackers) == "table" and #encounter.attackers > 0
        local mapRight = compactActionRight + (hasInfo and compactActionStep or 0)
        local firstActionRight = hasWaypoint and mapRight or hasInfo and compactActionRight
        local stampRight = StampRight(firstActionRight)
        local stampWidth = encounter.manual and not encounter.time and 136 or 96
        day:SetPoint("TOPRIGHT", -stampRight, -9)
        day:SetWidth(stampWidth)
        time:SetPoint("TOPRIGHT", -stampRight, -23)
        local encounterDay, encounterTime = EncounterDate(encounter)
        day:SetText(encounterDay)
        time:SetText(encounterTime)
        zone:SetWidth(width - 20 - stampRight - stampWidth)
        zone:SetText(encounter.zone and encounter.zone ~= "" and encounter.zone or L.unknownLocation)
        map:SetPoint("RIGHT", card, "TOPRIGHT", -mapRight, compactHeaderCenter)
        map:SetShown(hasWaypoint)
        info:SetShown(hasInfo)
        info:SetTooltipInfo(encounter.skirmishID and L.openSkirmish or L.attackers)
    end
    return card
end

local function CreateRosterTile(side, isOpponent, openRival)
    local tile = CreateFrame("Button", nil, side)
    local hover = tile:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 0.8, 0.5, 0.08)
    tile:SetHighlightTexture(hover)
    tile.selection = tile:CreateTexture(nil, "BACKGROUND", nil, 1)
    tile.selection:SetAllPoints()
    tile.selection:SetColorTexture(1, 0.71, 0.29, 0.14)
    tile:SetScript("OnClick", function(self)
        if self.rivalID then openRival(self.rivalID) end
    end)
    tile:SetScript("OnEnter", function(self)
        if not self.name:IsTruncated() then return end
        local tooltip = GetAppropriateTooltip and GetAppropriateTooltip() or GameTooltip
        tooltip:SetOwner(self, "ANCHOR_TOP")
        tooltip:SetText(self.name:GetText())
        tooltip:Show()
    end)
    tile:SetScript("OnLeave", HideTooltip)
    tile:SetScript("OnHide", HideTooltip)
    tile:SetMouseMotionEnabled(true)

    local portrait, rim = addon.CreateRoundIcon(tile, portraitSize)
    tile.portrait = portrait
    rim:SetPoint("TOP")
    tile.level = addon.CreateLevelBadge(tile, rim, isOpponent, 20)
    tile.death = OutcomeMarker(tile, 17, addon.smallSkullIconPath, L.portraitDeath, true)
    local innerCorner = isOpponent and "TOPLEFT" or "TOPRIGHT"
    tile.death:SetPoint("CENTER", rim, innerCorner, isOpponent and 7 or -7, -7)
    tile.name = Label(tile, "GameFontHighlightSmall", "TOP", 0, -52, 1)
    tile.name:SetJustifyH("CENTER")
    tile.class = Label(tile, "GameFontHighlightSmall", "TOP", 0, -66, 1)
    tile.class:SetJustifyH("CENTER")
    return tile
end

local function BindRosterTile(tile, player, isOpponent, selectedRivalID, died, slotWidth)
    HideTooltip(tile)
    HideTooltip(tile.death)
    local rival = player.rivalID and addon.db.rivals[player.rivalID]
    local known = rival or (player.isSelf and addon.UnitAppearance("player")) or {}
    local class, sex = player.class or known.class, player.sex or known.sex
    addon.SetRivalPortrait(tile.portrait, { race = player.race or known.race, sex = sex, class = class },
        player.id, portraitSize, isOpponent)
    tile.portrait:SetDesaturated(died)
    local shade = died and 0.78 or 1
    tile.portrait:SetVertexColor(shade, shade, shade)
    tile.level:SetLevel(player.level)
    tile.death:SetShown(died)
    tile.name:SetText(player.name or (player.isSelf and YOU) or L.unknownPlayer)
    tile.name:SetWidth(slotWidth - 4)
    local classes = sex == 3 and LOCALIZED_CLASS_NAMES_FEMALE or LOCALIZED_CLASS_NAMES_MALE
    local className = classes and classes[class] or player.classLabel or known.classLabel or ""
    if player.isSelf and YOU then className = className ~= "" and (className .. " • " .. YOU) or YOU end
    tile.class:SetText(className)
    tile.class:SetWidth(slotWidth - 4)
    local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    tile.class:SetTextColor(classColor and classColor.r or 0.77, classColor and classColor.g or 0.71,
        classColor and classColor.b or 0.61)
    tile.rivalID = rival and addon.IsRosterRival(player.rivalID, rival) and player.rivalID or nil
    tile:SetMouseClickEnabled(tile.rivalID ~= nil)
    tile.selection:SetShown(selectedRivalID ~= nil and player.rivalID == selectedRivalID)
    tile:Show()
end

local function CreateSkirmishSide(card, x, width, caption, isOpponent, openRival)
    local side = CreateCard(card, width, 1)
    side:SetPoint("TOPLEFT", x, rosterTop)
    side:SetBackdropColor(0, 0, 0, 0.22)
    side:SetBackdropBorderColor(0.47, 0.36, 0.25, 0.68)
    local header = side:CreateTexture(nil, "BACKGROUND", nil, 1)
    header:SetPoint("TOPLEFT", 2, -2)
    header:SetPoint("TOPRIGHT", -2, -2)
    header:SetHeight(rosterHeaderHeight - 2)
    header:SetColorTexture(0, 0, 0, 0.14)
    Divider(side, -rosterHeaderHeight, 2)

    local title = side:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetText(caption)
    local emblem = side:CreateTexture(nil, "ARTWORK")
    emblem:SetPoint("RIGHT", title, "LEFT", -4, 0)
    local tiles = {}
    return function(players, height, horde, color, selectedRivalID, casualties)
        side:SetHeight(height)
        title:ClearAllPoints()
        title:SetTextColor(unpack(color))
        local atlas = horde and hordeEmblem or allianceEmblem
        local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
        local emblemWidth = 0
        if info then
            local scale = 18 / math.max(info.width, info.height)
            emblemWidth = info.width * scale
            emblem:SetAtlas(atlas)
            emblem:SetSize(emblemWidth, info.height * scale)
        end
        emblem:SetShown(info ~= nil)
        title:SetPoint("CENTER", side, "TOP", info and (emblemWidth + 4) / 2 or 0, -rosterHeaderHeight / 2)

        local rows = RosterRows(#players)
        local base, extra = math.floor(#players / rows), #players % rows
        local columns = math.max(1, math.ceil(#players / rows))
        local slotWidth = math.min(122, math.floor((width - sectionPadding * 2) / columns))
        local unusedHeight = height - rosterHeaderHeight - 2 * sectionPadding - rows * rosterRowHeight
        local firstTop = -rosterHeaderHeight - sectionPadding - unusedHeight / 2
        local index = 0
        for row = 1, rows do
            local count = base + (row <= extra and 1 or 0)
            local top = firstTop - (row - 1) * rosterRowHeight
            for column = 1, count do
                index = index + 1
                local tile = tiles[index]
                if not tile then
                    tile = CreateRosterTile(side, isOpponent, openRival)
                    tiles[index] = tile
                end
                tile:SetSize(slotWidth, rosterRowHeight)
                tile:ClearAllPoints()
                tile:SetPoint("TOP", side, "TOP", (column - (count + 1) / 2) * slotWidth, top)
                local player = players[index]
                BindRosterTile(tile, player, isOpponent, selectedRivalID, casualties[player.id] == true, slotWidth)
            end
        end
        for i = index + 1, #tiles do
            HideTooltip(tiles[i])
            HideTooltip(tiles[i].death)
            tiles[i]:Hide()
        end
    end
end

local function CreateSkirmishResult(card)
    local center = CreateFrame("Frame", nil, card)
    center:SetSize(rosterGutter - 8, 80)
    local setMarker = CreateOutcomeMarkers(center, -28, 56, 56, true)
    local resultText = Label(center, "GameFontNormalSmall", "TOP", 0, -60, rosterGutter - 8)
    resultText:SetJustifyH("CENTER")
    resultText:SetWordWrap(true)
    resultText:SetMaxLines(2)
    return function(outcome, changed, top)
        setMarker(outcome, changed)
        center:SetShown(outcome ~= nil)
        if not outcome then return end
        center:ClearAllPoints()
        center:SetPoint("CENTER", card, "TOP", 0, top)
        resultText:SetText(outcome == "win" and L.winTooltip
            or outcome == "loss" and L.lossTooltip or L.shortUnknownOutcome)
        if outcome == "loss" then
            resultText:SetTextColor(1, 0.72, 0.62)
        elseif outcome == "unknown" then
            resultText:SetTextColor(unpack(neutralColor))
        else
            resultText:SetTextColor(1, 0.82, 0.50)
        end
    end
end

local function CreateTimeline(card, width, toggleTimeline)
    local events = CreateFrame("Frame", nil, card)
    events:SetSize(width, 1)
    Divider(events, 0)
    local header = CreateFrame("Button", nil, events)
    header:SetSize(width - 2 * cardInset, finishingBlowFirstRow)
    header:SetPoint("TOPLEFT", cardInset, 0)
    local hover = header:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 0.8, 0.5, 0.08)
    header:SetHighlightTexture(hover)
    local chevron = header:CreateTexture(nil, "ARTWORK")
    chevron:SetPoint("LEFT", 2, 0)
    chevron:SetSize(9, 9)
    local hasChevron = addon.ApplyAtlas(chevron, "common-icon-forwardarrow")
    if not hasChevron then
        chevron:Hide()
        chevron = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        chevron:SetPoint("LEFT", 2, 0)
    end
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("LEFT", 18, 0)
    title:SetText(L.finishingBlows)
    local count = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    count:SetPoint("LEFT", title, "RIGHT", 6, 0)
    count:SetTextColor(unpack(neutralColor))
    header:SetScript("OnClick", function()
        if card.skirmish and toggleTimeline then toggleTimeline(card.skirmish) end
    end)
    local rows = {}
    return function(battle, blows, expanded, top, players, colors)
        events:SetShown(#blows > 0)
        if #blows == 0 then return end
        events:ClearAllPoints()
        events:SetPoint("TOPLEFT", 0, top)
        events:SetHeight(TimelineHeight(#blows, expanded))
        count:SetText(#blows)
        if hasChevron then chevron:SetRotation(expanded and -math.pi / 2 or 0)
        else chevron:SetText(expanded and "⌄" or "›") end
        local visible = expanded and #blows or 0
        local columnWidth = math.floor(width / 2) - cardInset
        for i = 1, math.max(visible, #rows) do
            local event = i <= visible and blows[i]
            local row = rows[i]
            if not row then
                local y = -finishingBlowFirstRow - (i - 1) * finishingBlowStep
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
                    Label(events, "GameFontHighlightSmall", "TOPLEFT", cardInset + 3, y, 45),
                    Label(events, "GameFontHighlightSmall", "TOPLEFT", 64, y, columnWidth - 62),
                    arrow,
                    Label(events, "GameFontHighlightSmall", "TOPLEFT", width / 2 + cardInset, y, columnWidth - cardInset),
                }
                rows[i] = row
            end
            for _, region in ipairs(row) do region:SetShown(event and true or false) end
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
    end
end

function addon.CreateSkirmishCard(parent, width, onMapShown, openRival, toggleTimeline)
    local card = CreateCard(parent, width, 1)
    card:SetBackdropColor(0.085, 0.06, 0.04, 0.50)
    local sideWidth = math.floor((width - 2 * cardInset - rosterGutter) / 2)
    local zone = Label(card, "GameFontHighlight", "LEFT", cardInset, fullHeaderCenter, sideWidth, "TOPLEFT")
    local score = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    score:SetPoint("CENTER", card, "TOP", 0, fullHeaderCenter - 2)
    local coverage = CreateFrame("Button", nil, card, "UIPanelInfoButton")
    coverage:SetPoint("LEFT", score, "RIGHT", 6, 0)
    coverage:SetAlpha(0.75)
    coverage:SetMouseMotionEnabled(true)
    coverage:SetMouseClickEnabled(false)
    coverage:SetScript("OnEnter", function(self)
        local tooltip = GetAppropriateTooltip and GetAppropriateTooltip() or GameTooltip
        tooltip:SetOwner(self, "ANCHOR_TOP")
        tooltip:SetText(L.partialRoster)
        tooltip:AddLine(L.partialRosterHint, 1, 1, 1, true)
        tooltip:Show()
    end)
    coverage:SetScript("OnLeave", HideTooltip)
    coverage:SetScript("OnHide", HideTooltip)
    local stamp = Label(card, "GameFontHighlightSmall", "RIGHT", -cardInset, fullHeaderCenter, sideWidth - 22, "TOPRIGHT")
    stamp:SetTextColor(unpack(neutralColor))
    Divider(card, fullHeaderDivider)

    local setAllies = CreateSkirmishSide(card, cardInset, sideWidth, L.alliedSide, false, openRival)
    local setEnemies = CreateSkirmishSide(card, width - cardInset - sideWidth, sideWidth, L.enemySide, true, openRival)
    local setResult = CreateSkirmishResult(card)
    local setTimeline = CreateTimeline(card, width, toggleTimeline)
    local map = MapAction(card, function()
        ActivateWaypoint(card.skirmish, onMapShown)
    end)
    map:SetPoint("RIGHT", card, "TOPRIGHT", -compactActionRight, fullHeaderCenter)
    function card:SetSkirmish(battle, selectedRivalID, expanded)
        local changed = self.skirmish ~= battle
        if changed then
            HideTooltip(coverage)
            HideTooltip(map)
        end
        self.skirmish = battle
        self:SetShown(battle ~= nil)
        if not battle then
            setResult(nil, changed)
            return
        end
        local height = RosterHeight(battle)
        local bottom = RosterBottom(height)
        local middle = rosterTop - height / 2
        setResult(addon.Ledger.SkirmishOutcome(battle) or "unknown", changed, middle)
        zone:SetText(battle.zone and battle.zone ~= "" and battle.zone or L.unknownLocation)
        score:SetText(("%d × %d"):format(#battle.allies, #battle.enemies))
        coverage:SetShown(battle.rosterComplete ~= true)
        local day, time = EncounterDate(battle)
        local hasWaypoint = WaypointMap(battle) ~= nil
        local stampRight = StampRight(hasWaypoint and compactActionRight)
        stamp:SetPoint("RIGHT", card, "TOPRIGHT", -stampRight, fullHeaderCenter)
        stamp:SetText(time ~= "" and day .. "  " .. time or day)
        map:SetShown(hasWaypoint)

        local players, colors, casualties, blows = {}, {}, {}, {}
        local allyColor, enemyColor, alliesHorde = SideColors()
        for _, player in ipairs(battle.allies) do players[player.id], colors[player.id] = player, allyColor end
        for _, player in ipairs(battle.enemies) do players[player.id], colors[player.id] = player, enemyColor end
        for _, event in ipairs(battle.events) do
            if event.kind == "kill" then
                blows[#blows + 1] = event
                if event.targetID then casualties[event.targetID] = true end
            end
        end
        setAllies(battle.allies, height, alliesHorde, allyColor, nil, casualties)
        setEnemies(battle.enemies, height, not alliesHorde, enemyColor, selectedRivalID, casualties)
        setTimeline(battle, blows, expanded, bottom, players, colors)
        card:SetHeight(-bottom + TimelineHeight(#blows, expanded))
    end
    return card
end
