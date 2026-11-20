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

function addon.CreateEncounterCard(parent, width, onMapShown, profileWidth)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(width, addon.encounterCardHeight)
    card:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    card:SetBackdropColor(0.085, 0.06, 0.04, 0.72)
    card:SetBackdropBorderColor(0.56, 0.42, 0.27, 0.9)

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

    local function HideCoordinates(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    map:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(card.coordinateText)
        GameTooltip:Show()
    end)
    map:SetScript("OnLeave", HideCoordinates)
    map:HookScript("OnHide", HideCoordinates)
    map:SetScript("OnClick", function()
        if addon.ShowEncounterWaypoint(card.encounter) then
            onMapShown()
        elseif UIErrorsFrame then
            UIErrorsFrame:AddMessage(L.waypointError, 1, 0.25, 0.25)
        end
    end)

    function card:SetEncounter(encounter)
        if self.encounter ~= encounter then HideCoordinates(map) end
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
    end

    return card
end
