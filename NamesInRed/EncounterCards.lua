local _, addon = ...
local L = addon.L
local azerothMapID = 947
local mapsByName

addon.encounterCardHeight = 136

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
    local coords = Label(body, "GameFontHighlightSmall", "TOPLEFT", 13, -73, width - 26)
    time:SetTextColor(0.77, 0.71, 0.61)
    coords:SetTextColor(0.77, 0.71, 0.61)

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

    local function HideTooltip(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    map:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(card.coordinateText)
        GameTooltip:Show()
    end)
    map:SetScript("OnLeave", HideTooltip)
    map:HookScript("OnHide", HideTooltip)
    map:SetScript("OnClick", function()
        if addon.ShowEncounterWaypoint(card.encounter) then
            onMapShown()
        elseif UIErrorsFrame then
            UIErrorsFrame:AddMessage(L.waypointError, 1, 0.25, 0.25)
        end
    end)

    local attackers = CreateFrame("Button", nil, body, "SharedButtonSmallTemplate")
    attackers:SetPoint("BOTTOMRIGHT", -12, 11)
    attackers:SetSize(130, 25)
    attackers:SetText(L.attackers)
    attackers:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.attackers)
        for index, attacker in ipairs(card.encounter.attackers) do
            local name = attacker.name or L.unknownRival
            GameTooltip:AddLine(index == 1 and L.finishingBlow:format(name) or name, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    attackers:SetScript("OnLeave", HideTooltip)
    attackers:HookScript("OnHide", HideTooltip)

    function card:SetEncounter(encounter)
        if self.encounter ~= encounter then
            HideTooltip(map)
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
        self.coordinateText = HasCoordinates(encounter)
            and ("%.1f, %.1f"):format(encounter.x * 100, encounter.y * 100) or ""
        coords:SetText(hasWaypoint and "" or self.coordinateText)
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

local allyColor = { 0.65, 0.83, 1 }
local enemyColor = { 1, 0.61, 0.52 }

function addon.CreateSkirmishCard(parent, width, onMapShown, openRival)
    local card = CreateCard(parent, width, 1)
    local columnWidth = math.floor(width / 2) - 26
    local zone = Label(card, "GameFontHighlight", "TOPLEFT", 14, -16, columnWidth - 76)
    local score = Label(card, "GameFontNormal", "TOP", 0, -15, 194)
    score:SetJustifyH("CENTER")
    local stamp = Label(card, "GameFontHighlightSmall", "TOPRIGHT", -14, -17, columnWidth - 76)
    stamp:SetTextColor(0.77, 0.71, 0.61)
    Divider(card, -36)

    local function CreateSide(x, caption, color)
        local title = Label(card, "GameFontNormalSmall", "TOPLEFT", x, -47, columnWidth)
        title:SetText(caption)
        title:SetTextColor(unpack(color))
        local side = CreateFrame("Frame", nil, card)
        side:SetPoint("TOPLEFT", x, -62)
        side:SetSize(columnWidth, 1)
        local rows = {}
        return function(players)
            side:SetHeight(math.max(1, #players * 29))
            for i = 1, math.max(#players, #rows) do
                local player, row = players[i], rows[i]
                if not row then
                    row = CreateFrame("Button", nil, side)
                    row:SetSize(columnWidth, 27)
                    row:SetPoint("TOPLEFT", 0, -(i - 1) * 29)
                    row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
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

    local setAllies = CreateSide(14, L.alliedSide, allyColor)
    local setEnemies = CreateSide(math.floor(width / 2) + 12, L.enemySide, enemyColor)
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
        if addon.ShowEncounterWaypoint(card.skirmish) then
            onMapShown()
        elseif UIErrorsFrame then
            UIErrorsFrame:AddMessage(L.waypointError, 1, 0.25, 0.25)
        end
    end)
    local coords = Label(card, "GameFontHighlightSmall", "BOTTOMLEFT", 14, 17, 160)
    coords:SetTextColor(0.77, 0.71, 0.61)

    function card:SetSkirmish(battle)
        self.skirmish = battle
        self:SetShown(battle ~= nil)
        if not battle then return end
        self:SetHeight(addon.SkirmishCardHeight(battle))
        zone:SetText(battle.zone or L.unknownLocation)
        score:SetText(battle.rosterComplete and ("%d × %d"):format(#battle.allies, #battle.enemies)
            or L.partialRoster)
        local day, time = EncounterDate(battle)
        stamp:SetText(day .. "  " .. time)
        setAllies(battle.allies)
        setEnemies(battle.enemies)
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
                local arrow = Label(events, "GameFontNormalSmall", "TOP", 0, y, 18)
                arrow:SetJustifyH("CENTER")
                arrow:SetText("→")
                row = {
                    Label(events, "GameFontHighlightSmall", "TOPLEFT", 15, y, 45), from, arrow,
                    Label(events, "GameFontHighlightSmall", "TOPLEFT", math.floor(width / 2) + 14, y, columnWidth),
                }
                eventRows[i] = row
            end
            for _, text in ipairs(row) do text:SetShown(event ~= nil) end
            if event then
                local actor, target = players[event.actorID], players[event.targetID]
                local elapsed = event.time and battle.startedAt and math.max(0, event.time - battle.startedAt)
                row[1]:SetText(elapsed and ("%d:%02d"):format(math.floor(elapsed / 60), elapsed % 60) or "")
                row[2]:SetText(actor and actor.name or L.unknownPlayer)
                row[2]:SetTextColor(unpack(colors[event.actorID] or enemyColor))
                row[4]:SetText(target and target.name or L.unknownPlayer)
                row[4]:SetTextColor(unpack(colors[event.targetID] or enemyColor))
            end
        end
        coords:SetText(HasCoordinates(battle) and ("%.1f, %.1f"):format(battle.x * 100, battle.y * 100) or "")
        map:SetShown(WaypointMap(battle) ~= nil)
    end
    return card
end
