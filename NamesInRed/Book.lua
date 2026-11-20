local _, addon = ...
local L, Readable = addon.L, addon.Readable
local victoryGlyph = "|T" .. addon.swordsIconPath .. ":14:14:0:1:128:128:22:106:22:106|t"
local deathGlyph = "|TInterface\\AddOns\\NamesInRed\\Art\\TooltipSkull.tga:14:14:0:1|t"
local window, names, details, heading, portrait, summary, wins, losses, status, selected, empty
local search, remove, levelBadge, tabBar, latestCard, latestEmpty, historyEmpty
local deletePopup = "NAMES_IN_RED_DELETE_RIVAL"
local lower = strlower or string.lower
local buttons, sideTabs = {}, {}
local rivalsPage, recentPage, recentList, recentEmpty
local rivalsView, recentView = 1, 2
local activeView = rivalsView
local recentLimit = 100
local infoTab, historyTab = 1, 2
local cardStride = addon.encounterCardHeight + 8
local cardWidth = 332
local sectionFont = "GameFontNormal"
local statIcons = {}
local bookPortraitBacking
local showReferenceIcons = false
local statSwordInset = 0.11

local function SetStatIconCrop(icon, texture)
    local inset, shift = 0, 0
    if texture == addon.swordsIconPath or texture == addon.skullIconPath then
        shift = 2 / 128
        inset = texture == addon.swordsIconPath and statSwordInset or shift
    end
    icon:SetTexCoord(inset + shift, 1 - inset + shift, inset, 1 - inset)
end

function addon.RivalCounters(rival, hideZero)
    local wins, losses
    if not hideZero or rival.killsAgainstThem > 0 then wins = victoryGlyph .. " " .. rival.killsAgainstThem end
    if not hideZero or rival.deathsToThem > 0 then losses = deathGlyph .. " " .. rival.deathsToThem end
    if wins and losses then return wins .. "   " .. losses end
    return wins or losses
end

local function Scroll(parent, x, y, width, height, hideIfUnscrollable)
    local frame = CreateFrame("ScrollFrame", nil, parent, "ScrollFrameTemplate")
    frame:SetPoint("TOPLEFT", x, y)
    frame:SetSize(width, height)
    local child = CreateFrame("Frame", nil, frame)
    child:SetSize(width, 1)
    frame:SetScrollChild(child)
    frame:EnableMouseWheel(true)
    local bar = frame.ScrollBar
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4, 0)
    bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 4, 0)
    bar:SetHideIfUnscrollable(hideIfUnscrollable)
    bar:SetHideTrackIfThumbExceedsTrack(hideIfUnscrollable)
    return child, frame
end

local function UpdatePortrait(portrait, rival, id)
    portrait:SetSize(52, 52)
    local race, sex, class = rival.race, rival.sex, rival.class
    if not race then
        local knownRace, knownSex, knownClass = addon.RivalAppearance(id)
        race, sex, class = knownRace, knownSex, class or knownClass
    end
    if race and (sex == 2 or sex == 3) and GetRaceAtlas then
        local gender = sex == 3 and "female" or "male"
        if addon.ApplyAtlas(portrait, GetRaceAtlas(race, gender, true))
            or addon.ApplyAtlas(portrait, GetRaceAtlas(race, gender)) then
            return
        end
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

local function Stat(parent, y, texture, tooltipText)
    local holder, slot, icon, border
    if ProfessionsReagentSlotButtonMixin then
        local ok, reagent = pcall(CreateFrame, "Frame", nil, parent, "ProfessionsReagentSlotBaseTemplate")
        if ok then
            holder, slot = reagent, reagent.Button
            holder:SetSize(slot:GetSize())
            holder.Name:Hide()
            slot.CropFrame:Hide()
            slot.InputOverlay:Hide()
            slot:SetModifyingRequired(false)
            slot:SetItemButtonTexture(texture)
            icon = slot:GetItemButtonIconTexture()
            slot:SetSlotQuality(Enum.ItemQuality.Common)
            border = slot.IconBorder
        end
    end
    if not slot then
        slot = CreateFrame("Button", nil, parent)
        holder = slot
        slot:SetSize(39, 39)
        local background = slot:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        addon.ApplyAtlas(background, "Professions-Slot-bg")
        icon = slot:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("CENTER")
        icon:SetSize(31, 31)
        icon:SetTexture(texture)
        border = slot:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints()
        addon.ApplyAtlas(border, "Professions-Slot-Frame")
        slot:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    end
    SetStatIconCrop(icon, texture)
    holder:SetPoint("TOPLEFT", 25, y)

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
    return label, { texture = icon, reference = border }
end

local function PrintIconOffset(label, icon, reference)
    local x, y = icon:GetCenter()
    local refX, refY = reference:GetCenter()
    if x and refX then
        print(("NamesInRed %s offset x=%+.2f y=%+.2f"):format(label, x - refX, y - refY))
    end
end

function addon.ToggleIconReference()
    if not summary or not summary:IsVisible() then return "open-information" end
    local windowAsset, winAsset, lossAsset = addon.swordsIconPath, addon.swordsIconPath, addon.skullIconPath
    if not showReferenceIcons then
        if not C_TradeSkillUI or not C_TradeSkillUI.GetTradeSkillTexture or not C_Item or not C_Item.GetItemIconByID then
            return "reference-unavailable"
        end
        windowAsset = Readable(C_TradeSkillUI.GetTradeSkillTexture(129)) -- First Aid
        if (not windowAsset or windowAsset == 0) and C_Spell and C_Spell.GetSpellTexture then
            windowAsset = Readable(C_Spell.GetSpellTexture(3273))
        end
        winAsset = Readable(C_Item.GetItemIconByID(2589)) -- Linen Cloth
        lossAsset = Readable(C_Item.GetItemIconByID(2592)) -- Wool Cloth
        if not windowAsset or windowAsset == 0 or not winAsset or not lossAsset then return "reference-unavailable" end
    end
    showReferenceIcons = not showReferenceIcons
    addon.SetBookPortraitTexture(window, windowAsset)
    bookPortraitBacking:SetShown(not showReferenceIcons)
    statIcons[1].texture:SetTexture(winAsset)
    statIcons[2].texture:SetTexture(lossAsset)
    SetStatIconCrop(statIcons[1].texture, winAsset)
    SetStatIconCrop(statIcons[2].texture, lossAsset)
    PrintIconOffset("portrait/mask", window:GetPortrait(), window.PortraitContainer.CircleMask)
    PrintIconOffset("wins/frame", statIcons[1].texture, statIcons[1].reference)
    PrintIconOffset("losses/frame", statIcons[2].texture, statIcons[2].reference)
    return showReferenceIcons and "blizzard" or "addon"
end

local function CloseForMap()
    window:Hide()
end

local function CardList(parent, x, y, width, height, createCard, bindCard)
    local content, scroll = Scroll(parent, x, y, width, height, true)
    local entries, cards = {}, {}
    local function Render()
        if not scroll:IsVisible() then return end
        local first = math.floor(scroll:GetVerticalScroll() / cardStride) + 1
        local visibleCount = math.ceil(scroll:GetHeight() / cardStride) + 1
        local count = math.max(0, math.min(visibleCount, #entries - first + 1))
        for index = 1, count do
            local card = cards[index]
            if not card then
                card = createCard(content, width, CloseForMap)
                cards[index] = card
            end
            local itemIndex = first + index - 1
            card:SetPoint("TOPLEFT", 0, -(itemIndex - 1) * cardStride)
            bindCard(card, entries[itemIndex])
        end
        for index = count + 1, #cards do bindCard(cards[index], nil) end
    end
    function scroll:SetEntries(newEntries)
        entries = newEntries
        content:SetHeight(math.max(1, #entries * cardStride - 8))
        local maxScroll = math.max(0, content:GetHeight() - self:GetHeight())
        if self:GetVerticalScroll() > maxScroll then self:SetVerticalScroll(maxScroll) end
        Render()
    end
    scroll:HookScript("OnVerticalScroll", Render)
    return scroll
end

local function ShowDetails()
    local rival = selected and addon.db.rivals[selected]
    local activeTab = PanelTemplates_GetSelectedTab(tabBar)
    local showInfo = rival ~= nil and activeTab == infoTab
    local showHistory = rival ~= nil and activeTab == historyTab
    summary:SetShown(showInfo)
    local history = rival and rival.encounters or {}
    if showInfo then
        heading:SetText(rival.displayName)
        local manual = rival.addedManually or selected:match("^manual:") or selected:match("^seed:manual:")
        local description = {}
        if rival.raceLabel then description[#description + 1] = rival.raceLabel end
        if rival.classLabel then description[#description + 1] = rival.classLabel end
        if rival.factionLabel then description[#description + 1] = rival.factionLabel end
        local profile = table.concat(description, " / ")
        if manual then
            profile = profile ~= "" and profile .. "\n" .. L.manual or L.manual
        end
        status:SetText(profile)
        wins:SetText(("%s: %d"):format(L.kills, rival.killsAgainstThem))
        losses:SetText(("%s: %d"):format(L.deaths, rival.deathsToThem))
        UpdatePortrait(portrait, rival, selected)
        latestCard:SetEncounter(history[1])
        latestEmpty:SetShown(history[1] == nil)
        local lastLevel
        for _, encounter in ipairs(history) do
            if type(encounter.rivalLevel) == "number" and encounter.rivalLevel > 0 then
                lastLevel = encounter.rivalLevel
                break
            end
        end
        levelBadge:SetShown(lastLevel ~= nil)
        levelBadge.label:SetText(lastLevel)
    end
    empty:SetShown(rival == nil)

    historyEmpty:SetShown(showHistory and #history == 0)
    details:SetShown(showHistory and #history > 0)
    details:SetEntries(history)
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
    if activeView == recentView then
        local entries = addon.RecentEncounters(addon.db, recentLimit)
        recentEmpty:SetShown(#entries == 0)
        recentList:SetShown(#entries > 0)
        recentList:SetEntries(entries)
        return
    end
    local query = lower(search:GetText():match("^%s*(.-)%s*$"))
    local ids, selectionVisible = {}, false
    for guid, rival in pairs(addon.db.rivals) do
        if addon.IsRosterRival(guid, rival)
            and NameMatches(rival.displayName, query) then
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
        details:SetVerticalScroll(0)
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
                details:SetVerticalScroll(0)
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

local function ListBackground(parent, x, y, width, height)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    if x then
        texture:SetPoint("TOPLEFT", x, y)
        texture:SetSize(width, height)
    else
        texture:SetAllPoints()
    end
    addon.ApplyAtlas(texture, "Professions-background-summarylist")
end

local function DetailBackground(parent)
    local background = parent:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    if not addon.ApplyAtlas(background, "Professions-Recipe-Background") then
        background:SetColorTexture(0.07, 0.048, 0.034, 1)
    end

    local sourceWidth = 512
    local leftEdge, fadeEnd = 171, 265
    local aspect = (sourceWidth - leftEdge) / sourceWidth
    local height = math.min(parent:GetHeight() - 12, (parent:GetWidth() - 12) / aspect)
    local function PaintingSlice(first, last)
        local texture = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
        texture:SetTexture("Interface\\AddOns\\NamesInRed\\Art\\Battlefield.tga")
        texture:SetTexCoord(first / sourceWidth, last / sourceWidth, 0, 1)
        texture:SetSize(height * (last - first) / sourceWidth, height)
        texture:SetAlpha(0.88)
        return texture
    end

    local illustration = PaintingSlice(fadeEnd, sourceWidth)
    illustration:SetPoint("BOTTOMRIGHT", -6, 6)
    -- Feather the painted underlay into the recipe background.
    local leftFade = PaintingSlice(leftEdge, fadeEnd)
    leftFade:SetPoint("BOTTOMRIGHT", illustration, "BOTTOMLEFT")
    leftFade:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 1))

    local trim = parent:CreateTexture(nil, "BORDER")
    trim:SetAllPoints()
    addon.ApplyAtlas(trim, "common-insideframe")
    return trim
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

local function SetBookView(view)
    activeView = view
    rivalsPage:SetShown(view == rivalsView)
    recentPage:SetShown(view == recentView)
    for index, tab in ipairs(sideTabs) do tab:SetChecked(index == view) end
end

local function UpdateRivalTabHighlight()
    local glow = tabBar.SelectedHighlight
    local tab = tabBar.Tabs[PanelTemplates_GetSelectedTab(tabBar)]
    if not tab then glow:Hide(); return end
    local trim = glow.trim
    local tabLeft, trimLeft = tab:GetLeft(), trim:GetLeft()
    if not tabLeft or not trimLeft then return end
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", trim, "TOPLEFT", tabLeft - trimLeft + 2, -2)
    glow:SetSize(tab:GetWidth() - 5, 2)
    glow:Show()
end

local function SelectRivalTab(id)
    PanelTemplates_SetTab(tabBar, id)
    UpdateRivalTabHighlight()
end

local function OpenRival(id)
    local rival = addon.Ledger.Find(addon.db, id)
    if not rival or not addon.IsRosterRival(id, rival) then return end
    selected = id
    SelectRivalTab(infoTab)
    details:SetVerticalScroll(0)
    SetBookView(rivalsView)
    addon.RefreshBook(true)
end

local function CreateRecentCard(parent, width, onMapShown)
    local card = addon.CreateEncounterCard(parent, width, onMapShown, 265)
    local profile = card.profile
    local icon, rim = addon.CreateRoundIcon(profile)
    rim:SetPoint("TOPLEFT", 11, -12)
    local name = profile:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("TOPLEFT", 80, -23)
    name:SetPoint("TOPRIGHT", -8, -23)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    local description = profile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -6)
    description:SetWidth(177)
    description:SetJustifyH("LEFT")
    description:SetTextColor(0.72, 0.67, 0.59)
    description:SetMaxLines(2)

    local open = CreateFrame("Button", nil, profile, "SharedButtonSmallTemplate")
    open:SetPoint("BOTTOMLEFT", 15, 14)
    open:SetSize(132, 25)
    open:SetText(L.infoTab)
    open:SetScript("OnClick", function()
        if card.rivalID then OpenRival(card.rivalID) end
    end)

    function card:SetEntry(entry)
        self.rivalID = entry and entry.id
        self:SetEncounter(entry and entry.encounter)
        if not entry then return end
        local rival = entry.rival
        local known = addon.IsRosterRival(entry.id, rival)
        name:SetText(known and rival.displayName or L.unknownRival)
        open:SetEnabled(known)
        local labels = {}
        if rival.raceLabel then labels[#labels + 1] = rival.raceLabel end
        if rival.classLabel then labels[#labels + 1] = rival.classLabel end
        description:SetText(table.concat(labels, " / "))
        UpdatePortrait(icon, rival, entry.id)
    end
    return card
end

local function CreateSideTabs()
    local icons = { "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend", "Interface\\Icons\\INV_Misc_Book_09" }
    local labels = { L.rivalsView, L.recentView }
    for view, icon in ipairs(icons) do
        local tab = CreateFrame("Frame", nil, window, "LargeSideTabButtonTemplate")
        tab:EnableMouse(true)
        if view > 1 then
            tab:SetPoint("TOPLEFT", sideTabs[view - 1], "BOTTOMLEFT", 0, -2)
        else
            tab:SetPoint("TOPLEFT", window, "TOPRIGHT", 0, -60)
        end
        tab.Icon:SetTexture(icon)
        tab.tooltipText = labels[view]
        tab:SetFillToInterior(true)
        tab:SetCustomOnMouseUpHandler(function(_, mouseButton, upInside)
            if mouseButton == "LeftButton" and upInside and activeView ~= view then
                search:ClearFocus()
                StaticPopup_Hide(deletePopup)
                SetBookView(view)
                addon.RefreshBook()
            end
        end)
        sideTabs[view] = tab
    end
    window:SetClampRectInsets(0, sideTabs[1]:GetWidth(), 0, 0)
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
        bookPortraitBacking = addon.SetBookPortrait(window)
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
        rivalsPage = CreateFrame("Frame", nil, window)
        rivalsPage:SetAllPoints()
        recentPage = CreateFrame("Frame", nil, window)
        recentPage:SetAllPoints()
        local contentTop, footerInset, removeHeight = 65, 10, 28
        local bodyHeight = window:GetHeight() - contentTop - 5
        local rightX, rightWidth = 312, 383
        local left = Pane(rivalsPage, 5, -contentTop, rightX - 5, bodyHeight)
        ListBackground(left)
        -- Paint the underlay below the footer button's three-slice background.
        ListBackground(rivalsPage, rightX, -contentTop, rightWidth, bodyHeight)

        local panelGap = 4
        local rightTop = contentTop + 30
        local rightHeight = window:GetHeight() - rightTop - removeHeight - footerInset - panelGap
        local right = Pane(rivalsPage, rightX, -rightTop, rightWidth, rightHeight)
        local trim = DetailBackground(right)
        names = Scroll(left, 9, -42, 273, 431, false)
        tabBar = CreateFrame("Frame", nil, rivalsPage)
        local onePixel = PixelUtil.GetPixelToUIUnitFactor() / tabBar:GetEffectiveScale()
        local tabOverlap = onePixel - 4
        tabBar:SetPoint("BOTTOMLEFT", right, "TOPLEFT", 24, tabOverlap)
        tabBar:SetPoint("BOTTOMRIGHT", right, "TOPRIGHT", -24, tabOverlap)
        tabBar:SetHeight(32)
        -- The pane draws over the bottom of the tabs where they meet its trim.
        right:SetFrameLevel(tabBar:GetFrameLevel() + 2)
        for id, label in ipairs({ L.infoTab, L.historyTab }) do
            local tab = CreateFrame("Button", nil, tabBar, "PanelTopTabButtonTemplate")
            tab:SetID(id)
            if id == infoTab then tab:SetPoint("TOPLEFT") end
            tab:SetText(label)
            for _, texture in ipairs({ tab.LeftActive, tab.MiddleActive, tab.RightActive }) do
                texture:SetVertexColor(0.68, 0.68, 0.68)
            end
            tab:SetScript("OnClick", function(self)
                SelectRivalTab(self:GetID())
                ShowDetails()
            end)
        end
        local glow = right:CreateTexture(nil, "OVERLAY", nil, 6)
        addon.ApplyAtlas(glow, "transmog-tab-hl")
        glow.trim = trim
        tabBar.SelectedHighlight = glow
        PanelTemplates_SetNumTabs(tabBar, 2)
        SelectRivalTab(infoTab)
        -- Match the template's OnShow sizing once labels and selection are set.
        for _, tab in ipairs(tabBar.Tabs) do
            PanelTemplates_TabResize(tab)
            tab:HookScript("OnSizeChanged", UpdateRivalTabHighlight)
        end
        right:HookScript("OnShow", UpdateRivalTabHighlight)
        UpdateRivalTabHighlight()

        local historyTop = 16
        details = CardList(right, 25, -historyTop, cardWidth, rightHeight - historyTop - 12,
            addon.CreateEncounterCard, function(card, encounter) card:SetEncounter(encounter) end)
        historyEmpty = right:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        historyEmpty:SetPoint("CENTER", 0, 5)
        historyEmpty:SetText(L.noSkirmishes)

        summary = CreateFrame("Frame", nil, right)
        summary:SetPoint("TOPLEFT", 0, -9)
        summary:SetPoint("BOTTOMRIGHT")
        local rim
        portrait, rim = addon.CreateRoundIcon(summary)
        rim:SetPoint("TOPLEFT", 17.5, -17.5)
        local badgeSize = 24
        local badge = CreateFrame("Frame", nil, summary)
        badge:SetSize(badgeSize, badgeSize)
        badge:SetPoint("CENTER", rim, "BOTTOMLEFT", 12, 12)
        local circle = badge:CreateTexture(nil, "ARTWORK")
        circle:SetAllPoints()
        circle:SetTexture("Interface\\AddOns\\NamesInRed\\Art\\LevelBadge.tga")
        badge.label = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        badge.label:SetPoint("CENTER", badge, "CENTER", 0, -0.5)
        badge.label:SetSize(badgeSize, badgeSize)
        badge.label:SetJustifyH("CENTER")
        badge.label:SetJustifyV("MIDDLE")
        badge.label:SetShadowOffset(0, 0)
        badge:Hide()
        levelBadge = badge
        heading = summary:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        heading:SetPoint("TOPLEFT", 90, -26)
        heading:SetWidth(250)
        heading:SetJustifyH("LEFT")
        status = summary:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        status:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
        status:SetWidth(275)
        status:SetJustifyH("LEFT")
        status:SetTextColor(0.72, 0.67, 0.59)
        local statsTitle = summary:CreateFontString(nil, "OVERLAY", sectionFont)
        statsTitle:SetPoint("TOPLEFT", 25, -92)
        statsTitle:SetText(L.statistics)
        if not ProfessionsReagentSlotButtonMixin and C_AddOns and C_AddOns.LoadAddOn then
            pcall(C_AddOns.LoadAddOn, "Blizzard_ProfessionsTemplates")
        end
        wins, statIcons[1] = Stat(summary, -112, addon.swordsIconPath, L.winTooltip)
        losses, statIcons[2] = Stat(summary, -162, addon.skullIconPath, L.lossTooltip)
        local latestHeading = summary:CreateFontString(nil, "OVERLAY", sectionFont)
        latestHeading:SetPoint("TOPLEFT", 25, -215)
        latestHeading:SetText(L.latestEncounter)
        latestEmpty = summary:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        latestEmpty:SetPoint("TOPLEFT", 25, -240)
        latestEmpty:SetText(L.noSkirmishes)
        latestCard = addon.CreateEncounterCard(summary, cardWidth, CloseForMap)
        latestCard:SetPoint("TOPLEFT", 25, -234)
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
                    SelectRivalTab(infoTab)
                    search:SetText("")
                    details:SetVerticalScroll(0)
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
                if addon.RefreshNameplates then addon.RefreshNameplates() end
            end,
        }
        remove = CreateFrame("Button", nil, rivalsPage, "SharedButtonSmallTemplate")
        remove:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -footerInset, footerInset)
        remove:SetSize(128, removeHeight)
        remove:SetText(DELETE)
        remove:SetScript("OnClick", function()
            local rival = selected and addon.Ledger.Find(addon.db, selected)
            if rival then
                StaticPopup_Show(deletePopup, rival.displayName, nil, selected)
            end
        end)
        local journal = Pane(recentPage, 5, -contentTop, window:GetWidth() - 10, bodyHeight)
        ListBackground(journal)
        local journalTrim = journal:CreateTexture(nil, "BORDER")
        journalTrim:SetAllPoints()
        addon.ApplyAtlas(journalTrim, "common-insideframe")
        local journalTitle = journal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        journalTitle:SetPoint("TOPLEFT", 20, -15)
        journalTitle:SetText(L.recentView)
        recentEmpty = journal:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        recentEmpty:SetPoint("CENTER")
        recentEmpty:SetText(L.noSkirmishes)
        recentList = CardList(journal, 20, -42, journal:GetWidth() - 62, bodyHeight - 56,
            CreateRecentCard, function(card, entry) card:SetEntry(entry) end)

        CreateSideTabs()
        SetBookView(activeView)
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
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(24, 24)
    background:SetPoint("TOPLEFT", 3, -3)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    local borderSize = 53
    border:SetSize(borderSize, borderSize)
    border:SetPoint("TOPLEFT")
    -- The aperture center in the 64x64 TrackingBorder texture, including its padding.
    local apertureX, apertureY = 20 / 64, 19.5 / 64
    local mask = button:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetSize(20, 20)
    mask:SetPoint("CENTER", border, "TOPLEFT", borderSize * apertureX, -borderSize * apertureY)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(addon.swordsIconPath)
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER", mask)
    icon:AddMaskTexture(mask)
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

local function TooltipRival(tooltip, data)
    data = Readable(data)
    local guid
    if type(data) == "table" and (not canaccesstable or canaccesstable(data)) then
        guid = Readable(data.guid)
    end
    if type(guid) == "string" and addon.db.rivals[guid] then
        return addon.FindVisibleRival(guid)
    end

    local unit
    if tooltip.GetUnit then
        local ok, _, token, unitGUID = pcall(tooltip.GetUnit, tooltip)
        if ok then
            unit = Readable(token)
            unitGUID = Readable(unitGUID)
            if guid and unitGUID and guid ~= unitGUID then return end
            guid = guid or unitGUID
        end
    end
    return addon.FindVisibleRival(guid, unit)
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
        if tooltip ~= GameTooltip or not addon.db then return end
        local rival = TooltipRival(tooltip, data)
        if rival and (rival.killsAgainstThem > 0 or rival.deathsToThem > 0) then
            tooltip:AddLine(" ")
            tooltip:AddLine(addon.title, 1, 0.82, 0)
            tooltip:AddLine(addon.RivalCounters(rival), 1, 1, 1)
        end
    end)
end
