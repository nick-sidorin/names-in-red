local _, addon = ...
local L, Readable = addon.L, addon.Readable
local iconPath = "Interface\\Icons\\INV_Misc_Book_11"
local window, names, details, heading, portrait, summary, wins, losses, selected, empty
local buttons, lines = {}, {}

local function Counts(rival)
    return ("%s: %d    %s: %d"):format(L.kills, rival.killsAgainstThem, L.deaths, rival.deathsToThem)
end

local function Scroll(parent, x, y, width, height, minimal)
    local template = minimal and "ScrollFrameTemplate" or "UIPanelScrollFrameTemplate"
    local frame = CreateFrame("ScrollFrame", nil, parent, template)
    frame:SetPoint("TOPLEFT", x, y)
    frame:SetSize(width, height)
    local child = CreateFrame("Frame", nil, frame)
    child:SetSize(width, 1)
    frame:SetScrollChild(child)
    if minimal then
        frame:EnableMouseWheel(true)
        local bar = frame.ScrollBar
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4, 0)
        bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 4, 0)
        bar:SetHideIfUnscrollable(false)
        bar:SetHideTrackIfThumbExceedsTrack(false)
    else
        frame.ScrollBar:Hide()
        frame:HookScript("OnScrollRangeChanged", function(self, _, verticalRange)
            self.ScrollBar:SetShown(verticalRange > 0)
        end)
    end
    return child, frame
end

local function UpdatePortrait(rival)
    portrait:SetDesaturated(false)
    portrait:SetVertexColor(1, 1, 1)
    local race, sex, class = rival.race, rival.sex, rival.class
    if not race then
        local knownRace, knownSex, knownClass = addon.RivalAppearance(selected)
        race, sex, class = knownRace, knownSex, class or knownClass
    end
    if race and (sex == 2 or sex == 3) and GetRaceAtlas
        and addon.ApplyAtlas(portrait, GetRaceAtlas(race, sex == 3 and "female" or "male")) then
        return
    end
    local coords = CLASS_ICON_TCOORDS and class and CLASS_ICON_TCOORDS[class]
    if coords then
        portrait:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        portrait:SetTexCoord(unpack(coords))
    else
        portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        portrait:SetTexCoord(0, 1, 0, 1)
        portrait:SetDesaturated(true)
        portrait:SetVertexColor(0.62, 0.54, 0.42)
    end
end

local function Stat(parent, y, art)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 25, y)
    icon:SetSize(33, 33)
    icon:SetTexture("Interface\\AddOns\\NamesInRed\\Art\\" .. art .. ".tga")
    local border = parent:CreateTexture(nil, "OVERLAY")
    border:SetPoint("CENTER", icon)
    border:SetSize(39, 39)
    if not addon.ApplyAtlas(border, "Professions-Slot-Frame") then
        border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    end
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", icon, "RIGHT", 12, 0)
    return label
end

local function ShowDetails()
    local rival = selected and addon.db.rivals[selected]
    summary:SetShown(rival ~= nil)
    if rival then
        heading:SetText(rival.displayName)
        wins:SetText(("%s: %d"):format(L.kills, rival.killsAgainstThem))
        losses:SetText(("%s: %d"):format(L.deaths, rival.deathsToThem))
        UpdatePortrait(rival)
    end
    empty:SetShown(rival == nil)
    details:GetParent():SetShown(rival ~= nil and rival.encounters ~= nil and #rival.encounters > 0)
    local encounters = rival and rival.encounters or {}
    local offset = 0
    for index, encounter in ipairs(encounters) do
        local line = lines[index]
        if not line then
            line = details:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            line:SetWidth(315)
            line:SetJustifyH("LEFT")
            lines[index] = line
        end
        local winning = encounter.direction == "killsAgainstThem"
        local outcome = winning and L.win or L.loss
        local when = encounter.manual and L.manual or (encounter.time and date("%x %H:%M", encounter.time))
        local place = encounter.zone or ""
        if encounter.x and encounter.y then
            place = ("%s (%.1f, %.1f)"):format(place, encounter.x * 100, encounter.y * 100)
        end
        local levels = ""
        if encounter.playerLevel or encounter.rivalLevel then
            levels = ("\n%s: %s / %s"):format(L.level, encounter.playerLevel or "?", encounter.rivalLevel or "?")
        end
        if place ~= "" then
            place = "\n" .. place
        end
        line:SetText(outcome .. (when and ("  -  " .. when) or "") .. place .. levels)
        if winning then
            line:SetTextColor(0.63, 0.82, 1)
        else
            line:SetTextColor(1, 0.52, 0.48)
        end
        line:SetPoint("TOPLEFT", 2, -offset)
        line:Show()
        offset = offset + line:GetStringHeight() + 12
    end
    for index = #encounters + 1, #lines do
        lines[index]:Hide()
    end
    details:SetHeight(math.max(1, offset))
end

function addon.RefreshBook()
    if not window or not window:IsShown() then
        return
    end
    local ids = {}
    for guid in pairs(addon.db.rivals) do
        ids[#ids + 1] = guid
    end
    table.sort(ids, function(a, b)
        local first, second = addon.db.rivals[a].displayName, addon.db.rivals[b].displayName
        if first == second then return a < b end
        return first < second
    end)
    if not selected or not addon.db.rivals[selected] then selected = ids[1] end
    for index, guid in ipairs(ids) do
        local button = buttons[index]
        if not button then
            button = CreateFrame("Button", nil, names)
            button:SetSize(273, 24)
            button:SetPoint("TOPLEFT", 0, -(index - 1) * 24)
            local highlight = button:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            if not addon.ApplyAtlas(highlight, "Professions_Recipe_Hover") then
                highlight:SetColorTexture(1, 0.82, 0.4, 0.12)
            end
            local selection = button:CreateTexture(nil, "ARTWORK")
            selection:SetAllPoints()
            if not addon.ApplyAtlas(selection, "Professions_Recipe_Active") then
                selection:SetColorTexture(1, 0.78, 0.28, 0.24)
            end
            button.selection = selection
            local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            label:SetPoint("LEFT", 18, 0)
            label:SetPoint("RIGHT", -7, 0)
            label:SetJustifyH("LEFT")
            label:SetWordWrap(false)
            button.label = label
            button:SetScript("OnClick", function(self)
                selected = self.rivalID
                details:GetParent():SetVerticalScroll(0)
                addon.RefreshBook()
            end)
            buttons[index] = button
        end
        button.rivalID = guid
        button.label:SetText(addon.db.rivals[guid].displayName)
        button.selection:SetShown(guid == selected)
        button:Show()
    end
    for index = #ids + 1, #buttons do buttons[index]:Hide() end
    names:SetHeight(math.max(1, #ids * 24))
    ShowDetails()
end

local function Pane(parent, x, y, width, height, atlas)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", x, y)
    frame:SetSize(width, height)
    local art = frame:CreateTexture(nil, "BACKGROUND")
    art:SetAllPoints()
    if not addon.ApplyAtlas(art, atlas) and not addon.ApplyAtlas(art, "Professions-Recipe-Background") then
        art:SetColorTexture(0.07, 0.048, 0.034, 1)
    end
    return frame
end

local function MakeDraggable(frame)
    frame:SetMovable(true)
    frame:SetToplevel(true)
    local drag = CreateFrame("Frame", nil, frame)
    drag:SetPoint("TOPLEFT", 60, -1)
    drag:SetPoint("TOPRIGHT", -30, -1)
    drag:SetHeight(22)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    local moving
    local function Stop()
        if moving then
            frame:StopMovingOrSizing()
            moving = nil
        end
    end
    drag:SetScript("OnDragStart", function()
        frame:StartMoving()
        moving = true
    end)
    drag:SetScript("OnDragStop", Stop)
    frame:HookScript("OnHide", Stop)
end

local function ToggleBook()
    if not addon.db then return end
    if not window then
        window = CreateFrame("Frame", "NamesInRedRivalBook", UIParent, "PortraitFrameTemplate")
        window:SetSize(700, 572)
        window:SetPoint("CENTER")
        window:SetFrameStrata("DIALOG")
        window:EnableMouse(true)
        window:SetClampedToScreen(true)
        window:SetTitle(addon.title)
        if window.SetPortraitToAsset then window:SetPortraitToAsset(iconPath) end
        window.onCloseCallback = function() window:Hide(); return false end
        MakeDraggable(window)
        tinsert(UISpecialFrames, window:GetName())
        -- Camelot professions replace the portrait frame background and omit
        -- both inset borders. The decorative corners belong to the recipe atlas.
        if window.Bg and addon.ApplyAtlas(window.Bg, "Profession-Background-Overview") then
            if window.TopTileStreaks then window.TopTileStreaks:Hide() end
        end

        local left = Pane(window, 12, -65, 300, 451, "Professions-background-summarylist")
        local right = Pane(window, 318, -65, 370, 451, "Professions-Recipe-Background-FirstAid")
        names = Scroll(left, 7, -12, 273, 425, true)
        details = Scroll(right, 25, -219, 318, 210)
        summary = CreateFrame("Frame", nil, right)
        summary:SetAllPoints()
        portrait = summary:CreateTexture(nil, "ARTWORK")
        portrait:SetPoint("TOPLEFT", 23, -23)
        portrait:SetSize(53, 53)
        local mask = summary:CreateMaskTexture()
        mask:SetAllPoints(portrait)
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        portrait:AddMaskTexture(mask)
        local rim = summary:CreateTexture(nil, "OVERLAY")
        rim:SetPoint("CENTER", portrait)
        rim:SetSize(68, 68)
        if not addon.ApplyAtlas(rim, "auctionhouse-itemicon-border-white") then
            addon.ApplyAtlas(rim, "Mode-Selection-Ring")
        end
        rim:SetVertexColor(0.81, 0.66, 0.48)
        heading = summary:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        heading:SetPoint("TOPLEFT", 90, -26)
        heading:SetWidth(250)
        heading:SetJustifyH("LEFT")
        wins = Stat(summary, -107, "Victory")
        losses = Stat(summary, -152, "Gravestone")
        empty = right:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        empty:SetPoint("CENTER", 0, 5)
        empty:SetWidth(305)
        empty:SetText(L.empty)

        local openDialog
        local add = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        add:SetPoint("TOP", left, "BOTTOM", 0, -12)
        add:SetSize(162, 25)
        add:SetText(L.add)
        add:SetScript("OnClick", function()
            if not openDialog then
                openDialog = addon.CreateManualDialog(window, function(id)
                    selected = id
                    details:GetParent():SetVerticalScroll(0)
                    addon.RefreshBook()
                end)
            end
            openDialog()
        end)
    elseif window:IsShown() then
        window:Hide()
        return
    end
    window:Show()
    addon.RefreshBook()
end

local function CreateShortcut()
    if not Minimap then return end
    local button = CreateFrame("Button", "NamesInRedMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(24, 24)
    background:SetPoint("TOPLEFT", 3, -3)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(iconPath)
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -5)
    local mask = button:CreateMaskTexture()
    mask:SetAllPoints(icon)
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    icon:AddMaskTexture(mask)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    local function Position()
        local angle = math.rad(addon.db.minimapAngle or 205)
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER",
            math.cos(angle) * (Minimap:GetWidth() / 2 + 8),
            math.sin(angle) * (Minimap:GetHeight() / 2 + 8))
    end
    local function StopDrag()
        button:SetScript("OnUpdate", nil)
    end
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnMouseDown", function(self) self.dragged = false end)
    button:SetScript("OnDragStart", function(self)
        self.dragged = true
        self:SetScript("OnUpdate", function()
            local cx, cy = Minimap:GetCenter()
            if not cx or not cy then return end
            local x, y = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            addon.db.minimapAngle = math.deg(math.atan2(y / scale - cy, x / scale - cx))
            Position()
        end)
    end)
    button:SetScript("OnDragStop", StopDrag)
    button:SetScript("OnHide", StopDrag)
    button:SetScript("OnClick", function(self)
        if not self.dragged then ToggleBook() end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(addon.title)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    Minimap:HookScript("OnSizeChanged", Position)
    Position()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if addon.db then CreateShortcut() end
end)

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
        if tooltip ~= GameTooltip or not addon.db then return end
        data = Readable(data)
        if type(data) ~= "table" or (canaccesstable and not canaccesstable(data)) then return end
        local guid = Readable(data.guid)
        local rival = type(guid) == "string" and addon.db.rivals[guid]
        if rival and (rival.killsAgainstThem > 0 or rival.deathsToThem > 0) then
            tooltip:AddLine(addon.title, 1, 0.82, 0)
            tooltip:AddLine(Counts(rival), 1, 1, 1)
        end
    end)
end
