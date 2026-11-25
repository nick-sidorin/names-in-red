local _, addon = ...
local L, HideTooltip = addon.L, addon.HideOwnedTooltip
local azerothMapID = 947
local mapsByName

local allianceColor = { 0.65, 0.83, 1 }
local hordeColor = { 1, 0.61, 0.52 }
local neutralColor = { 0.77, 0.71, 0.61 }
local allianceEmblem = "UI-HUD-UnitFrame-SmallCircle-Alliance"
local hordeEmblem = "UI-HUD-UnitFrame-SmallCircle-Horde"

local function SideColors(faction)
    faction = faction or addon.PlayerFaction()
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
local rewardIconSize = 14
local compactRewardRowHeight = rewardIconSize + sectionPadding
local fullHeaderCenter = -18
-- Keep equal space between the map button and the inside edges of the header.
local fullHeaderDivider = 2 * fullHeaderCenter + 2
local rosterTop, rosterHeaderHeight = fullHeaderDivider - sectionPadding, 27
local portraitSize, rosterGutter = addon.participantPortraitSize, 100
local rosterRowHeight = portraitSize + 36
local resultWidth = rosterGutter - 8
local compactHeaderCenter, compactHeaderDivider = -21, -41
local compactRosterTop = compactHeaderDivider - sectionPadding
addon.compactEncounterCardHeight = -compactRosterTop + rosterRowHeight + sectionPadding + compactRewardRowHeight
local skirmishSummaryHeight, finishingBlowStep = 26, 19

local function CreateRewardSummary(parent, anchor, y)
    local function Counter(tooltipTitle)
        local target = CreateFrame("Frame", nil, parent)
        target:SetSize(rewardIconSize, rewardIconSize)
        target:SetMouseMotionEnabled(true)
        target:SetScript("OnEnter", function(self)
            local tooltip = GetAppropriateTooltip and GetAppropriateTooltip() or GameTooltip
            tooltip:SetOwner(self, "ANCHOR_TOP")
            tooltip:SetText(tooltipTitle)
            tooltip:Show()
        end)
        target:SetScript("OnLeave", HideTooltip)
        target:SetScript("OnHide", HideTooltip)
        local count = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightRight")
        local icon = target:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        count:SetPoint("RIGHT", target, "LEFT", -4, 0)
        return count, icon, target
    end
    local honor, honorIcon, honorTarget = Counter(L.skirmishHonorEarned)
    local kills, killsIcon, killsTarget = Counter(L.skirmishHonorableKillsEarned)
    honorTarget:SetPoint(anchor, -cardInset, y)
    killsTarget:SetPoint("RIGHT", honor, "LEFT", -16, 0)
    killsIcon:SetTexture(addon.honorableKillIconPath)
    local formatCount = BreakUpLargeNumbers or tostring
    return function(honorableKills, honorPoints, faction)
        kills:SetText(formatCount(honorableKills or 0))
        honor:SetText(formatCount(honorPoints or 0))
        honorIcon:SetTexture(addon.HonorIconTexture(faction or addon.PlayerFaction()))
    end
end

local function RosterRows(count)
    if count <= 2 then return 1 end
    return math.max(2, math.ceil(count / 3))
end

local function RosterHeight(battle)
    local rows = RosterRows(math.max(#battle.allies, #battle.enemies))
    return rosterHeaderHeight + sectionPadding * 2 + rows * rosterRowHeight
end

local function SkirmishDetailsHeight(count, expanded)
    return skirmishSummaryHeight + (expanded and finishingBlowStep * count or 0)
end

local function RosterBottom(height)
    return rosterTop - height - sectionPadding
end

local function FullCardHeight(rosterBottom, blowCount, expanded)
    return -rosterBottom + SkirmishDetailsHeight(blowCount, expanded)
end

local function PetFinisher(battle, event, index)
    local evidence = addon.SkirmishDeathEvidence
    local recap = evidence and evidence.EventRecap(battle, event, index)
    return recap and recap.petFinisher
end

function addon.SkirmishCardHeight(battle, expanded)
    local count = 0
    for index, event in ipairs(battle.events) do
        if event.kind == "kill" or PetFinisher(battle, event, index) then count = count + 1 end
    end
    return FullCardHeight(RosterBottom(RosterHeight(battle)), count, expanded)
end

local dividers = setmetatable({}, { __mode = "k" })

local function SizeDivider(line)
    local factor = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()
    -- A one-pixel line can disappear between pixels as the scroll child moves.
    line:SetHeight(factor and 2 * factor / line:GetEffectiveScale() or 2)
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
    line:SetSnapToPixelGrid(false)
    line:SetTexelSnappingBias(0)
    SizeDivider(line)
    dividers[line] = true
    line:SetColorTexture(0.56, 0.42, 0.27, 0.30)
    return line
end

local compactActionSize = 32
local compactActionInset = 4
local compactHeaderGap = 6
local compactActionStep = compactActionSize - 2 * compactActionInset + compactHeaderGap
local compactActionRight = 11

local function CardActionButton(card)
    local button = CreateFrame("Button", nil, card, "CommonSquareIconButtonTemplate")
    button:SetSize(compactActionSize, compactActionSize)
    button:SetHitRectInsets(compactActionInset, compactActionInset, compactActionInset, compactActionInset)
    button:RegisterForClicks("LeftButtonUp")
    button.Icon:SetSize(16, 16)
    -- The painted bounds are centered in the native artwork. Keep the icon
    -- on the same layout center as the button at fractional UI scales.
    button.Icon:SetSnapToPixelGrid(false)
    button.Icon:SetTexelSnappingBias(0)
    local function CenterIcon(self)
        self.Icon:SetPoint("CENTER", self, "CENTER", 0, 0)
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
    map:SetTooltipInfo(L.showOnMap)
    map:SetOnClickHandler(onClick)
    return map
end

local function ReportAction(card)
    local report = CardActionButton(card)
    report:SetIcon(addon.issueBugIcon)
    report:SetTooltipInfo(L.reportIssue)
    report:SetOnClickHandler(function()
        local ref = card.reportRef
        if type(ref) == "string" then addon.OpenIssueReport(ref)
        elseif ref then addon.OpenIssueReport(nil, ref) end
    end)
    return report
end

local function PositionActions(card, center, report, map, hasWaypoint, info, hasInfo)
    local last
    local function Place(button, shown)
        button:SetShown(shown and true or false)
        if shown then
            last = last and last + compactActionStep or compactActionRight
            button:ClearAllPoints()
            button:SetPoint("RIGHT", card, "TOPRIGHT", -last, center)
        end
    end
    Place(report, card.reportRef ~= nil)
    if info then Place(info, hasInfo) end
    Place(map, hasWaypoint)
    return last
end

local function StampRight(actionRight)
    return actionRight and actionRight + compactActionSize - compactActionInset + compactHeaderGap or cardInset
end

local function CreateSkirmishResult(card, fitCaption)
    local size = 56
    local center = CreateFrame("Frame", nil, card)
    center:SetSize(resultWidth, size + 24)
    local markers = {
        win = addon.CreateFramedMarker(center, size, addon.swordsIconPath),
        loss = addon.CreateFramedMarker(center, size, addon.defeatBannerPath),
        unknown = addon.CreateFramedMarker(center, size, nil, L.unknownOutcome),
        draw = addon.CreateFramedMarker(center, size, nil, nil, "="),
        ongoing = addon.CreateFramedMarker(center, size, nil, nil, "…"),
        noCredit = addon.CreateFramedMarker(center, size, nil, L.noRivalCreditHint, "–"),
    }
    for _, marker in pairs(markers) do
        marker:SetPoint("TOP", center)
        marker:Hide()
    end
    local labels = { win = L.winTooltip, loss = L.lossTooltip, unknown = L.shortUnknownOutcome,
        draw = L.drawOutcome, ongoing = L.ongoingOutcome, noCredit = L.noRivalCredit }
    local caption = Label(center, "GameFontNormalSmall", "TOP", 0, -size - 4, resultWidth)
    caption:SetJustifyH("CENTER")
    caption:SetWordWrap(true)
    caption:SetMaxLines(2)
    local tally = Label(center, "GameFontHighlightSmall", "CENTER", 0, 0, resultWidth)
    tally:SetJustifyH("CENTER")
    tally:SetWordWrap(true)
    local previous
    return function(outcome, changed, top, qualifier, wins, losses)
        if changed or outcome ~= previous then
            for _, marker in pairs(markers) do HideTooltip(marker) end
        end
        previous = outcome
        for result, marker in pairs(markers) do marker:SetShown(outcome == result) end
        tally:SetShown(outcome == "mixed")
        caption:SetShown(outcome ~= "mixed")
        center:SetShown(outcome ~= nil)
        if not outcome then return end
        center:SetPoint("CENTER", card, "TOP", 0, top)
        if outcome == "mixed" then
            tally:SetText(addon.FormatRivalCounters(wins, losses, false, 0))
            return
        end
        local label = labels[outcome]
        local count = outcome == "win" and wins or outcome == "loss" and losses
        if count and count > 1 then label = L.resultCount:format(label, count) end
        local marker = markers[outcome]
        if qualifier == "legacy" then
            addon.SetFramedMarkerTooltip(marker, L.qualifiedOutcome:format(L.legacyResult, label) .. "\n" .. L.legacyResultHint)
            label = L.legacyResult
        elseif qualifier == "manual" then
            addon.SetFramedMarkerTooltip(marker, nil)
            label = L.qualifiedOutcome:format(L.manual, label)
        elseif outcome == "win" or outcome == "loss" or outcome == "unknown" then
            addon.SetFramedMarkerTooltip(marker, outcome == "unknown" and L.unknownOutcome or nil)
        end
        caption:SetText(label)
        if fitCaption then center:SetHeight(size + 4 + caption:GetStringHeight()) end
        if outcome == "loss" then
            caption:SetTextColor(1, 0.72, 0.62)
        elseif outcome ~= "win" then
            caption:SetTextColor(unpack(neutralColor))
        else
            caption:SetTextColor(1, 0.82, 0.50)
        end
    end
end

local function CompactResult(encounter, rivalID)
    if not encounter then return end
    local legacy = addon.Ledger.EncounterOutcome(encounter)
    if encounter.manual and legacy then return legacy, "manual" end
    local wins, losses = encounter.contributionWins or 0, encounter.contributionLosses or 0
    if not encounter.skirmishID then
        local direction = addon.Ledger.LegacyContribution(encounter, rivalID)
        if direction == "win" then wins = 1 elseif direction == "loss" then losses = 1 end
    end
    if wins > 0 and losses > 0 then return "mixed", nil, wins, losses end
    if wins > 0 then return "win", nil, wins end
    if losses > 0 then return "loss", nil, nil, losses end
    if encounter.legacyResult or (not encounter.skirmishID and legacy) then
        return encounter.legacyResult or legacy, "legacy"
    end
    return "noCredit"
end

local function CreateParticipantTile(parent, isOpponent, openRival, compact)
    local tile = CreateFrame("Button", nil, parent)
    tile.canOpenRival = openRival ~= nil
    tile.isOpponent = isOpponent
    tile.isLocalCharacter = compact and not isOpponent
    if openRival then
        tile:SetScript("OnClick", function(self)
            if self.rivalID then openRival(self.rivalID) end
        end)
    end
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

    tile.avatar = addon.CreateParticipantPortrait(tile, {
        opposing = isOpponent, showCasualty = true, showClass = true,
        highlightRim = true, livePlayerFallback = tile.isLocalCharacter,
    })
    local name = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlight_NoShadow")
    name:SetPoint("TOP", tile.avatar.rim, "BOTTOM", 0, -2)
    name:SetHeight(rosterRowHeight - portraitSize - 2)
    name:SetJustifyH("CENTER")
    name:SetJustifyV("TOP")
    name:SetWordWrap(true)
    name:SetNonSpaceWrap(true)
    name:SetMaxLines(2)
    tile.name = name
    return tile
end

local function HideParticipantTooltips(tile)
    HideTooltip(tile)
    HideTooltip(tile.avatar.death)
    HideTooltip(tile.avatar.classBadge)
end

local function BindParticipantTile(tile, player, known, level, died, selectedRivalID, revived)
    HideParticipantTooltips(tile)
    local isSelf = player.isSelf or tile.isLocalCharacter
    local class = tile.avatar:SetParticipant({
        race = player.race or known.race,
        sex = player.sex or known.sex,
        class = player.class or known.class,
        classLabel = player.classLabel or known.classLabel,
    }, player.id or player.rivalID, level, died, revived)
    local name = addon.ManualName(player.name) or addon.ManualName(known.displayName)
    if isSelf then name = name or addon.UnitPlayerName("player") or YOU end
    tile.name:SetWidth(tile:GetWidth() - 4)
    tile.name:SetText(name or (tile.isOpponent and L.unknownRival or L.unknownPlayer))
    local nameHeight = math.min(tile.name:GetStringHeight(), rosterRowHeight - portraitSize - 2)
    local padding = (rosterRowHeight - portraitSize - 2 - nameHeight) / 2
    tile.avatar.rim:SetPoint("TOP", tile, "TOP", 0, -padding)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then tile.name:SetTextColor(color.r, color.g, color.b)
    else tile.name:SetTextColor(1, 1, 1) end
    tile.rivalID = tile.canOpenRival and player.rivalID and known.displayName
        and addon.IsRosterRival(player.rivalID, known) and player.rivalID or nil
    tile:SetMouseClickEnabled(tile.rivalID ~= nil)
    if selectedRivalID and player.rivalID == selectedRivalID then tile:LockHighlight()
    else tile:UnlockHighlight() end
    tile:Show()
end

local function LocationLabel(encounter)
    local zone = encounter.zone and encounter.zone ~= "" and encounter.zone or L.unknownLocation
    if encounter.origin == "battleground" then
        return zone .. "  |cffc9b8a2· " .. L.battleground .. "|r"
    end
    return zone
end

function addon.CreateCompactEncounterCard(parent, width, onMapShown, openSkirmish)
    local card = CreateCard(parent, width, addon.compactEncounterCardHeight)
    local zone = Label(card, "GameFontHighlight", "LEFT", cardInset, compactHeaderCenter, width - 167, "TOPLEFT")
    zone:SetWordWrap(true)
    zone:SetMaxLines(2)
    local day = Label(card, "GameFontHighlightSmall", "TOPRIGHT", -cardInset, -9, 96)
    local time = Label(card, "GameFontHighlightSmall", "TOPRIGHT", -cardInset, -23, 96)
    time:SetTextColor(unpack(neutralColor))
    Divider(card, compactHeaderDivider)

    local sideWidth = (width - 2 * cardInset - resultWidth) / 2
    local mine = CreateParticipantTile(card, false, nil, true)
    local theirs = CreateParticipantTile(card, true, nil, true)
    mine:SetSize(sideWidth, rosterRowHeight)
    theirs:SetSize(sideWidth, rosterRowHeight)
    mine:SetPoint("TOPLEFT", cardInset, compactRosterTop)
    theirs:SetPoint("TOPRIGHT", -cardInset, compactRosterTop)
    local setResult = CreateSkirmishResult(card, true)
    local setRewards = CreateRewardSummary(card, "BOTTOMRIGHT", sectionPadding)

    local map = MapAction(card, function()
        if card.encounter then ActivateWaypoint(card.encounter, onMapShown) end
    end)
    local report = ReportAction(card)
    local info = CardActionButton(card)
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
            HideTooltip(report)
            if not encounter then
                HideParticipantTooltips(mine)
                HideParticipantTooltips(theirs)
            end
        end
        self.encounter = encounter
        self.reportRef = encounter and (encounter.skirmishID
            or (addon.LegacyReportRef and addon.LegacyReportRef(rivalID, encounter)))
        self:SetShown(encounter ~= nil)
        local result, qualifier, wins, losses = CompactResult(encounter, rivalID)
        setResult(result, changed, compactRosterTop - rosterRowHeight / 2, qualifier, wins, losses)
        if not encounter then return end

        local skirmishes = addon.db and addon.db.skirmishes
        local battle = skirmishes and skirmishes[encounter.skirmishID]
        if battle then
            local honorableKills, honor = addon.Ledger.SkirmishRewards(battle)
            setRewards(honorableKills, honor, battle.demoFaction)
        else
            setRewards(encounter.honorableKills, encounter.honor, rival and rival.demoFaction)
        end

        local player, opponent = encounter.player, encounter.opponent
        BindParticipantTile(mine, player or {}, addon.UnitAppearance("player"), encounter.playerLevel,
            encounter.playerDeathIndex ~= nil
            or (not encounter.manual and encounter.direction == "deathsToThem"), nil, encounter.playerRevived)
        local rivalLevel = encounter.rivalLevel or (encounter.manual and rival and rival.observedLevel)
        BindParticipantTile(theirs, opponent or { rivalID = rivalID, name = rival and rival.displayName },
            rival or {}, rivalLevel, encounter.opponentDeathIndex ~= nil
            or (not encounter.manual and encounter.direction == "killsAgainstThem"), nil, encounter.opponentRevived)

        local hasWaypoint = WaypointMap(encounter) ~= nil
        local hasInfo = encounter.skirmishID ~= nil or type(encounter.attackers) == "table" and #encounter.attackers > 0
        local stampRight = StampRight(PositionActions(card, compactHeaderCenter, report, map, hasWaypoint, info, hasInfo))
        local stampWidth = encounter.manual and not encounter.time and 136 or 96
        day:SetPoint("TOPRIGHT", -stampRight, -9)
        day:SetWidth(stampWidth)
        time:SetPoint("TOPRIGHT", -stampRight, -23)
        local encounterDay, encounterTime = EncounterDate(encounter)
        day:SetText(encounterDay)
        time:SetText(encounterTime)
        zone:SetWidth(width - 20 - stampRight - stampWidth)
        zone:SetText(LocationLabel(battle or encounter))
        info:SetTooltipInfo(encounter.skirmishID and L.openSkirmish or L.attackers)
    end
    return card
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
    return function(players, height, horde, color, selectedRivalID, casualties, life)
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
        local slotWidth = math.min(144, math.floor((width - sectionPadding * 2) / columns))
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
                    tile = CreateParticipantTile(side, isOpponent, openRival)
                    tiles[index] = tile
                end
                tile:SetSize(slotWidth, rosterRowHeight)
                tile:ClearAllPoints()
                tile:SetPoint("TOP", side, "TOP", (column - (count + 1) / 2) * slotWidth, top)
                local player = players[index]
                local rival = player.rivalID and addon.db.rivals[player.rivalID]
                local known = rival or (player.isSelf and addon.UnitAppearance("player")) or {}
                local revived = life[player.id] and life[player.id].kind == "revive"
                BindParticipantTile(tile, player, known, player.level, casualties[player.id] ~= nil, selectedRivalID, revived)
            end
        end
        for i = index + 1, #tiles do
            HideParticipantTooltips(tiles[i])
            tiles[i]:Hide()
        end
    end
end

local function CreateSkirmishDetails(card, width, toggleTimeline)
    local events = CreateFrame("Frame", nil, card)
    events:SetSize(width, 1)
    Divider(events, 0)
    local setRewards = CreateRewardSummary(events, "TOPRIGHT", (rewardIconSize - skirmishSummaryHeight) / 2)
    local header = CreateFrame("Button", nil, events)
    header:SetHeight(skirmishSummaryHeight)
    header:SetPoint("TOPLEFT", cardInset, 0)
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
    header:SetFontString(title)
    header:SetNormalFontObject("GameFontNormalSmall")
    header:SetHighlightFontObject("GameFontHighlightSmall")
    title:SetText(L.finishingBlows)
    local count = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    count:SetPoint("LEFT", title, "RIGHT", 6, 0)
    count:SetTextColor(unpack(neutralColor))
    header:SetScript("OnClick", function()
        if card.skirmish and toggleTimeline then toggleTimeline(card.skirmish) end
    end)
    local rows = {}
    return function(battle, blows, expanded, top, players, colors)
        events:ClearAllPoints()
        events:SetPoint("TOPLEFT", 0, top)
        events:SetHeight(SkirmishDetailsHeight(#blows, expanded))
        local honorableKills, honor = addon.Ledger.SkirmishRewards(battle)
        setRewards(honorableKills, honor, battle.demoFaction)
        header:SetShown(#blows > 0)
        count:SetText(#blows)
        header:SetWidth(32 + title:GetStringWidth() + count:GetStringWidth())
        if hasChevron then chevron:SetRotation(expanded and -math.pi / 2 or 0)
        else chevron:SetText(expanded and "⌄" or "›") end
        local visible = expanded and #blows or 0
        local columnWidth = math.floor(width / 2) - cardInset
        for i = 1, math.max(visible, #rows) do
            local blow = i <= visible and blows[i]
            local event = blow and blow.event
            local row = rows[i]
            if not row then
                local y = -skirmishSummaryHeight - (i - 1) * finishingBlowStep
                local target = Label(events, "GameFontHighlightSmall", "TOPLEFT", width / 2 + cardInset, y,
                    columnWidth - cardInset)
                local arrow = events:CreateTexture(nil, "ARTWORK")
                if addon.ApplyAtlas(arrow, "common-icon-forwardarrow") then
                    arrow:SetSize(10, 10)
                    arrow:SetAlpha(0.75)
                else
                    arrow = events:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    arrow:SetWidth(18)
                    arrow:SetJustifyH("CENTER")
                    arrow:SetText(">")
                end
                arrow:SetPoint("CENTER", target, "LEFT", -cardInset, 0)
                row = {
                    Label(events, "GameFontHighlightSmall", "TOPLEFT", cardInset + 3, y, 45),
                    Label(events, "GameFontHighlightSmall", "TOPLEFT", 64, y, columnWidth - 62),
                    arrow,
                    target,
                }
                rows[i] = row
            end
            for _, region in ipairs(row) do region:SetShown(event and true or false) end
            if event then
                local actorID = blow.pet and blow.pet.ownerID or event.actorID
                local actor, target = players[actorID], players[event.targetID]
                local elapsed = event.time and battle.startedAt and math.max(0, event.time - battle.startedAt)
                row[1]:SetText(elapsed and ("%d:%02d"):format(math.floor(elapsed / 60), elapsed % 60) or "")
                row[2]:SetText(actor and actor.name or L.unknownPlayer)
                row[2]:SetTextColor(unpack(colors[actorID] or neutralColor))
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
    zone:SetWordWrap(true)
    zone:SetMaxLines(2)
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
    local setDetails = CreateSkirmishDetails(card, width, toggleTimeline)
    local map = MapAction(card, function()
        ActivateWaypoint(card.skirmish, onMapShown)
    end)
    local report = ReportAction(card)
    function card:SetSkirmish(battle, selectedRivalID, expanded, reportRef)
        local changed = self.skirmish ~= battle
        if changed then
            HideTooltip(coverage)
            HideTooltip(map)
            HideTooltip(report)
        end
        self.skirmish = battle
        self.reportRef = battle and reportRef
        self:SetShown(battle ~= nil)
        if not battle then
            setResult(nil, changed)
            return
        end
        local height = RosterHeight(battle)
        local bottom = RosterBottom(height)
        local middle = rosterTop - height / 2
        local result, qualifier = addon.Ledger.JournalOutcome(battle)
        setResult(result, changed, middle, qualifier)
        zone:SetText(LocationLabel(battle))
        score:SetText(("%d × %d"):format(#battle.allies, #battle.enemies))
        coverage:SetShown(addon.Ledger.HasRosterGap(battle))
        local day, time = EncounterDate(battle)
        local hasWaypoint = WaypointMap(battle) ~= nil
        local stampRight = StampRight(PositionActions(card, fullHeaderCenter, report, map, hasWaypoint))
        stamp:SetPoint("RIGHT", card, "TOPRIGHT", -stampRight, fullHeaderCenter)
        stamp:SetWidth(width / 2 - 64 - stampRight)
        stamp:SetText(time ~= "" and day .. "  " .. time or day)

        local players, colors, blows = {}, {}, {}
        local allyColor, enemyColor, alliesHorde = SideColors(battle.demoFaction)
        for _, player in ipairs(battle.allies) do players[player.id], colors[player.id] = player, allyColor end
        for _, player in ipairs(battle.enemies) do players[player.id], colors[player.id] = player, enemyColor end
        for index, event in ipairs(battle.events) do
            local pet = PetFinisher(battle, event, index)
            if event.kind == "kill" or pet then
                blows[#blows + 1] = { event = event, pet = pet }
            end
        end
        local casualties = addon.Ledger.FirstDeaths(battle)
        local life = addon.Ledger.ParticipantLife(battle)
        setAllies(battle.allies, height, alliesHorde, allyColor, nil, casualties, life)
        setEnemies(battle.enemies, height, not alliesHorde, enemyColor, selectedRivalID, casualties, life)
        setDetails(battle, blows, expanded, bottom, players, colors)
        card:SetHeight(FullCardHeight(bottom, #blows, expanded))
    end
    return card
end
