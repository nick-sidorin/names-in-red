local _, addon = ...
local L, Readable = addon.L, addon.Readable
local iconPath = "Interface\\Icons\\INV_Misc_Book_11"
local window, names, details, heading, portrait, summary, wins, losses, status, selected, empty
local search, remove
local deletePopup = "NAMES_IN_RED_DELETE_RIVAL"
local lower = strlower or string.lower
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
    portrait:SetSize(52, 52)
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
        -- The inventory icon includes a light bevel inside the texture.
        portrait:SetTexCoord(0.12, 0.88, 0.12, 0.88)
        portrait:SetSize(44, 44)
    end
end

local function Stat(parent, y, art, tooltipText)
    local slot = CreateFrame("Button", nil, parent)
    slot:SetPoint("TOPLEFT", 25, y)
    slot:SetSize(43, 43)
    local icon = slot:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexture("Interface\\AddOns\\NamesInRed\\Art\\" .. art .. ".tga")
    local border = slot:CreateTexture(nil, "OVERLAY")
    border:SetAllPoints()
    if not addon.ApplyAtlas(border, "Professions-Slot-Frame") then
        border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    end
    local highlight = slot:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", 2, -2)
    highlight:SetPoint("BOTTOMRIGHT", -2, 2)
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    highlight:SetVertexColor(0.52, 0.73, 1)

    slot:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltipText)
        GameTooltip:Show()
    end)
    local function HideTooltip(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    slot:SetScript("OnLeave", HideTooltip)
    slot:SetScript("OnHide", HideTooltip)

    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", slot, "RIGHT", 10, 0)
    return label
end

local function ShowDetails()
    local rival = selected and addon.db.rivals[selected]
    summary:SetShown(rival ~= nil)
    if rival then
        heading:SetText(rival.displayName)
        local manual = selected:match("^manual:") or selected:match("^seed:manual:")
        local description = {}
        if rival.raceLabel then description[#description + 1] = rival.raceLabel end
        if rival.classLabel then description[#description + 1] = rival.classLabel end
        status:SetText(manual and L.manual or table.concat(description, " / "))
        wins:SetText(("%s: %d"):format(L.kills, rival.killsAgainstThem))
        losses:SetText(("%s: %d"):format(L.deaths, rival.deathsToThem))
        UpdatePortrait(rival)
    end
    empty:SetShown(rival == nil)
    local encounters = rival and rival.encounters or {}
    local offset, count = 0, 0
    for _, encounter in ipairs(encounters) do
        if not encounter.manual then
            count = count + 1
            local row = lines[count]
            if not row then
                row = CreateFrame("Frame", nil, details)
                row:SetWidth(315)
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(20, 20)
                row.icon:SetPoint("TOPLEFT")
                row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row.label:SetPoint("TOPLEFT", 28, -2)
                row.label:SetWidth(287)
                row.label:SetJustifyH("LEFT")
                lines[count] = row
            end
            local art = encounter.direction == "killsAgainstThem" and "Victory" or "Gravestone"
            row.icon:SetTexture("Interface\\AddOns\\NamesInRed\\Art\\" .. art .. ".tga")
            local info = {}
            if encounter.time then info[#info + 1] = date("%x %H:%M", encounter.time) end
            local place = encounter.zone or ""
            if encounter.x and encounter.y then
                place = ("%s (%.1f, %.1f)"):format(place, encounter.x * 100, encounter.y * 100)
            end
            if place ~= "" then info[#info + 1] = place end
            if encounter.playerLevel or encounter.rivalLevel then
                info[#info + 1] = ("%s: %s / %s"):format(L.level, encounter.playerLevel or "?", encounter.rivalLevel or "?")
            end
            row.label:SetText(table.concat(info, "\n"))
            local height = math.max(20, row.label:GetStringHeight() + 2)
            row:SetHeight(height)
            row:SetPoint("TOPLEFT", 2, -offset)
            row:Show()
            offset = offset + height + 10
        end
    end
    for index = count + 1, #lines do lines[index]:Hide() end
    details:SetHeight(math.max(1, offset))
    details:GetParent():SetShown(count > 0)
end

local function NameMatches(name, query)
    if query == "" or lower(name):find(query, 1, true) then return true end
    if not strcmputf8i or not (name:find("[\128-\255]") or query:find("[\128-\255]")) then return false end

    -- Compare only complete UTF-8 characters when the case differs.
    local starts = {}
    for position in name:gmatch("()[^\128-\191]") do
        starts[#starts + 1] = position
    end
    starts[#starts + 1] = #name + 1
    local _, characters = query:gsub("[^\128-\191]", "")
    for index = 1, #starts - characters do
        if strcmputf8i(name:sub(starts[index], starts[index + characters] - 1), query) == 0 then
            return true
        end
    end
    return false
end

function addon.RefreshBook(resetSearch)
    if resetSearch and search and search:GetText() ~= "" then
        search:SetText("")
        return
    end
    if not window or not window:IsShown() then
        return
    end
    local query = lower(search:GetText():match("^%s*(.-)%s*$"))
    local ids, selectionVisible = {}, false
    for guid, rival in pairs(addon.db.rivals) do
        if NameMatches(rival.displayName, query) then
            ids[#ids + 1] = guid
            if guid == selected then selectionVisible = true end
        end
    end
    table.sort(ids, function(a, b)
        local first, second = addon.db.rivals[a].displayName, addon.db.rivals[b].displayName
        if first == second then return a < b end
        return first < second
    end)
    if not selectionVisible then
        selected = ids[1]
        details:GetParent():SetVerticalScroll(0)
    end
    remove:SetEnabled(selected ~= nil)
    empty:SetText(query ~= "" and L.noMatches or L.empty)
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

local function ProfessionBackdrop(parent)
    local atlas = "Profession-Background-Template2"
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    if not info or info.width <= 0 or info.height <= 0 then return end

    -- Compress the original top band, including its lower edge, into the book header.
    local width = parent:GetWidth() - 6
    local fullHeight = info.height * width / info.width
    local sourceBand = math.min(1, 98 / fullHeight)
    local art = parent:CreateTexture(nil, "BACKGROUND", nil, -3)
    art:SetPoint("TOPLEFT", 3, -21)
    art:SetSize(width, 44)
    art:SetAtlas(atlas)
    art:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord,
        info.topTexCoord + sourceBand * (info.bottomTexCoord - info.topTexCoord))
end

local function Pane(parent, x, y, width, height)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", x, y)
    frame:SetSize(width, height)
    return frame
end

local function DetailBackground(parent)
    local background = parent:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    if not addon.ApplyAtlas(background, "Professions-Recipe-Background") then
        background:SetColorTexture(0.07, 0.048, 0.034, 1)
    end

    local atlas = "Professions-Recipe-Background-Engineering"
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    if info and info.width > 0 and info.height > 0 then
        local illustration = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
        local scale = math.min(parent:GetWidth() * 0.80 / info.width, parent:GetHeight() * 0.65 / info.height)
        illustration:SetAtlas(atlas)
        illustration:SetSize(info.width * scale, info.height * scale)
        illustration:SetPoint("BOTTOMRIGHT", -6, 6)
        local fade = parent:CreateMaskTexture()
        fade:SetAllPoints(illustration)
        fade:SetTexture("Interface\\AddOns\\NamesInRed\\Art\\BackdropFade.tga",
            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        illustration:AddMaskTexture(fade)
    end

    local trim = parent:CreateTexture(nil, "BORDER")
    trim:SetAllPoints()
    addon.ApplyAtlas(trim, "common-insideframe")
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
        window:SetSize(700, 555)
        window:SetPoint("CENTER")
        window:SetFrameStrata("DIALOG")
        window:EnableMouse(true)
        window:SetClampedToScreen(true)
        window:SetTitle(addon.title)
        if window.SetPortraitToAsset then window:SetPortraitToAsset(iconPath) end
        window.onCloseCallback = function() window:Hide(); return false end
        MakeDraggable(window)
        tinsert(UISpecialFrames, window:GetName())
        -- The overview atlas can be translucent over the game world.
        local backing = window:CreateTexture(nil, "BACKGROUND", nil, -7)
        backing:SetPoint("TOPLEFT", 2, -21)
        backing:SetPoint("BOTTOMRIGHT", -2, 2)
        backing:SetColorTexture(0.065, 0.047, 0.033, 1)

        -- Camelot professions replace the portrait frame background and omit
        -- both inset borders.
        if window.Bg and addon.ApplyAtlas(window.Bg, "Profession-Background-Overview") then
            if window.TopTileStreaks then window.TopTileStreaks:Hide() end
        end

        ProfessionBackdrop(window)
        local left = Pane(window, 5, -65, 307, 485)
        local listArt = left:CreateTexture(nil, "BACKGROUND")
        listArt:SetAllPoints()
        addon.ApplyAtlas(listArt, "Professions-background-summarylist")
        local right = Pane(window, 312, -65, 383, 450)
        DetailBackground(right)
        names = Scroll(left, 9, -42, 273, 431, true)
        details = Scroll(right, 25, -219, 318, 215)
        summary = CreateFrame("Frame", nil, right)
        summary:SetAllPoints()
        local rim
        portrait, rim = addon.CreateRoundIcon(summary)
        rim:SetPoint("TOPLEFT", 17.5, -17.5)
        heading = summary:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        heading:SetPoint("TOPLEFT", 90, -26)
        heading:SetWidth(250)
        heading:SetJustifyH("LEFT")
        status = summary:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        status:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
        status:SetTextColor(0.72, 0.67, 0.59)
        local statsTitle = summary:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statsTitle:SetPoint("TOPLEFT", 25, -92)
        statsTitle:SetText(L.statistics)
        wins = Stat(summary, -112, "Victory", L.winTooltip)
        losses = Stat(summary, -162, "Gravestone", L.lossTooltip)
        empty = right:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        empty:SetPoint("CENTER", 0, 5)
        empty:SetWidth(305)
        empty:SetText(L.empty)

        search = CreateFrame("EditBox", nil, left, "SearchBoxTemplate")
        search:SetSize(245, 22)
        search:SetPoint("TOPLEFT", 13, -12)
        search:SetMaxLetters(96)
        search:HookScript("OnTextChanged", function()
            names:GetParent():SetVerticalScroll(0)
            addon.RefreshBook()
        end)

        local openDialog
        local add = CreateFrame("Button", nil, left, "SharedButtonSmallTemplate")
        add:SetPoint("LEFT", search, "RIGHT", 8, 0)
        add:SetSize(23, 23)
        local addIcon = add:CreateTexture(nil, "OVERLAY")
        addIcon:SetPoint("CENTER")
        addIcon:SetSize(16, 16)
        if not addon.ApplyAtlas(addIcon, "friends-icon-addFriend") then
            add:SetText("+")
        end
        add:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.addTitle)
            GameTooltip:Show()
        end)
        add:SetScript("OnLeave", function(self)
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
        add:SetScript("OnClick", function()
            StaticPopup_Hide(deletePopup)
            if not openDialog then
                openDialog = addon.CreateManualDialog(window, function(id)
                    selected = id
                    search:SetText("")
                    details:GetParent():SetVerticalScroll(0)
                    addon.RefreshBook()
                end)
            end
            openDialog()
        end)

        StaticPopupDialogs[deletePopup] = {
            text = L.deleteConfirm,
            button1 = DELETE,
            button2 = CANCEL,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            OnAccept = function(_, id)
                addon.Ledger.Remove(addon.db, id)
                addon.RefreshBook()
            end,
        }
        remove = CreateFrame("Button", nil, window, "SharedButtonSmallTemplate")
        remove:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -10, 8)
        remove:SetSize(128, 28)
        remove:SetText(DELETE)
        remove:SetScript("OnClick", function()
            local rival = selected and addon.Ledger.Find(addon.db, selected)
            if rival then
                StaticPopup_Show(deletePopup, rival.displayName, nil, selected)
            end
        end)
        window:HookScript("OnHide", function()
            search:ClearFocus()
            StaticPopup_Hide(deletePopup)
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
