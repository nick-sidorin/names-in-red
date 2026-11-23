local _, addon = ...
local L, Readable, HideTooltip = addon.L, addon.Readable, addon.HideOwnedTooltip
local swordsStart, swordsEnd = addon.smallSwordsInset, 128 - addon.smallSwordsInset
local window, names, details, heading, profilePortrait, summary, wins, losses, status, selected, empty
local search, tabBar, latestCard, latestEmpty, historyEmpty
local honorableKills, honor
local honorIcon
local deletePopup = "NAMES_IN_RED_DELETE_RIVAL"
local lower = strlower or string.lower
local sideTabs = {}
local rivalsPage, recentPage, recentList, recentEmpty
local battlePage, battleList, selectedSkirmishID
local rivalsView, recentView, battleView = 1, 2, 3
local activeView = rivalsView
local recentLimit = 100
local infoTab, historyTab = 1, 2
local cardGap = 8
local profileInset = 25
local sectionHeaderHeight = 20
local reagentButtonSize = 39
local reagentSlotHeight, reagentRowSpacing = 50, -5
local sectionGap = 20
local statSwordInset = 0.11

local function SetStatIconCrop(icon, texture)
    local inset, shift = 0, 0
    if texture == addon.swordsIconPath then
        shift = 1 / 128
        inset = statSwordInset
    elseif texture == addon.honorableKillIconPath then
        -- Center the chevron within the visible reagent frame.
        inset = 0.75 / 128
        shift = inset
    end
    icon:SetTexCoord(inset + shift, 1 - inset + shift, inset, 1 - inset)
end

function addon.RivalCounters(id, hideZero, iconOffsetY)
    local winCount, lossCount = addon.Ledger.PersonalScore(addon.db, id)
    if winCount == 0 and lossCount == 0 then return end
    iconOffsetY = iconOffsetY or 1
    local wins, losses
    if not hideZero or winCount > 0 then
        wins = ("|T%s:14:14:0:%d:128:128:%d:%d:%d:%d|t %d"):format(
            addon.swordsIconPath, iconOffsetY, swordsStart, swordsEnd, swordsStart, swordsEnd, winCount)
    end
    if not hideZero or lossCount > 0 then
        losses = ("|T%s:14:14:0:%d|t %d"):format(addon.smallSkullIconPath, iconOffsetY, lossCount)
    end
    if wins and losses then return wins .. "   " .. losses end
    return wins or losses
end

local function Scroll(parent, x, y, width, height)
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
    bar:SetHideIfUnscrollable(true)
    bar:SetHideTrackIfThumbExceedsTrack(true)
    return child, frame
end

local function SectionHeading(parent, y, width, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", profileInset, y)
    label:SetSize(width, sectionHeaderHeight)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

local function Stat(parent, section, x, y, width, texture, tooltipText)
    local holder, slot, icon, label
    if ProfessionsReagentSlotButtonMixin then
        local ok, reagent = pcall(CreateFrame, "Frame", nil, parent, "ProfessionsReagentSlotBaseTemplate")
        if ok then
            holder, slot = reagent, reagent.Button
            label = holder.Name
            slot.CropFrame:Hide()
            slot.InputOverlay:Hide()
            slot:SetModifyingRequired(false)
            slot:SetItemButtonTexture(texture)
            icon = slot:GetItemButtonIconTexture()
            slot:SetSlotQuality(Enum.ItemQuality.Common)
        end
    end
    if not slot then
        holder = CreateFrame("Frame", nil, parent)
        holder:SetSize(width, reagentSlotHeight)
        slot = CreateFrame("Button", nil, holder)
        slot:SetSize(reagentButtonSize, reagentButtonSize)
        slot:SetPoint("LEFT")
        local background = slot:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        addon.ApplyAtlas(background, "Professions-Slot-bg")
        icon = slot:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("CENTER")
        icon:SetSize(31, 31)
        icon:SetTexture(texture)
        local border = slot:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints()
        addon.ApplyAtlas(border, "Professions-Slot-Frame")
        slot:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight_NoShadow")
        label:SetPoint("LEFT", holder, "LEFT", 46, 0)
        label:SetHeight(36)
    end
    SetStatIconCrop(icon, texture)
    holder:SetPoint("TOPLEFT", section, "BOTTOMLEFT", x, y)

    slot:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltipText)
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", HideTooltip)
    slot:SetScript("OnHide", HideTooltip)

    label:SetWidth(width - 46)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(true)
    label:SetMaxLines(2)
    return label, icon
end

local function CloseForMap()
    window:Hide()
end

local function CardList(parent, x, y, width, height, createCard, bindCard, measure, initiallyExpanded)
    local content, scroll = Scroll(parent, x, y, width, height)
    local entries, cards, offsets = {}, {}, {}
    local expansion = setmetatable({}, { __mode = "k" })
    local function IsExpanded(entry)
        if expansion[entry] ~= nil then return expansion[entry] end
        return initiallyExpanded
    end
    local function ToggleTimeline(entry)
        expansion[entry] = not IsExpanded(entry)
        scroll:SetEntries(entries)
    end
    local function Render()
        if not scroll:IsVisible() then return end
        local top = scroll:GetVerticalScroll()
        local bottom = top + scroll:GetHeight()
        local index = 0
        for itemIndex, offset in ipairs(offsets) do
            if offset >= bottom then break end
            if (offsets[itemIndex + 1] or content:GetHeight()) > top then
                index = index + 1
                local card = cards[index]
                if not card then
                    card = createCard(content, width, CloseForMap, ToggleTimeline)
                    cards[index] = card
                end
                card:SetPoint("TOPLEFT", 0, -offset)
                local entry = entries[itemIndex]
                bindCard(card, entry, IsExpanded(entry))
            end
        end
        for unused = index + 1, #cards do bindCard(cards[unused], nil) end
    end
    function scroll:SetEntries(newEntries)
        entries, offsets = newEntries, {}
        local offset = 0
        for index, entry in ipairs(entries) do
            offsets[index] = offset
            offset = offset + measure(entry, IsExpanded(entry)) + cardGap
        end
        content:SetHeight(math.max(1, offset - cardGap))
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
    local history = rival and addon.RivalEncounters(addon.db, selected) or {}
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
        local winCount, lossCount, honorableKillCount, honorTotal = addon.Ledger.PersonalScore(addon.db, selected)
        wins:SetText(L.statValue:format(L.wins, winCount))
        losses:SetText(L.statValue:format(L.losses, lossCount))
        honorableKills:SetText(L.statValue:format(L.honorableKills, honorableKillCount))
        honor:SetText(L.statValue:format(L.honor, honorTotal))
        local faction = rival.demoFaction or addon.PlayerFaction()
        honorIcon:SetTexture(addon.HonorIconTexture(faction))
        local level
        for _, encounter in ipairs(history) do
            if type(encounter.rivalLevel) == "number" and encounter.rivalLevel > 0 then
                level = encounter.rivalLevel
                break
            end
        end
        profilePortrait:SetParticipant(rival, selected, level)
        latestCard:SetEncounter(history[1], rival, selected)
        latestEmpty:SetShown(history[1] == nil)
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

local function SetBookView(view)
    activeView = view
    rivalsPage:SetShown(view == rivalsView)
    recentPage:SetShown(view == recentView)
    battlePage:SetShown(view == battleView)
    if view ~= battleView then selectedSkirmishID = nil end
    local sideView = view == battleView and rivalsView or view
    for index, tab in ipairs(sideTabs) do tab:SetChecked(index == sideView) end
end

function addon.RefreshBook(resetSearch)
    if resetSearch and search and search:GetText() ~= "" then
        search:SetText("")
        return
    end
    if not window or not window:IsShown() then
        return
    end
    if activeView == battleView then
        local battle = addon.db.skirmishes and addon.db.skirmishes[selectedSkirmishID]
        if battle then
            battleList:SetEntries({ battle })
            return
        end
        battleList:SetEntries({})
        SetBookView(recentView)
    end
    if activeView == recentView then
        local entries = addon.RecentSkirmishes(addon.db, recentLimit)
        recentEmpty:SetShown(#entries == 0)
        recentList:SetShown(#entries > 0)
        recentList:SetEntries(entries)
        return
    end
    local query = lower(search:GetText():match("^%s*(.-)%s*$"))
    local entries, selectionVisible = {}, false
    for guid, rival in pairs(addon.db.rivals) do
        if addon.IsRosterRival(guid, rival) and NameMatches(rival.displayName, query) then
            entries[#entries + 1] = { id = guid, name = rival.displayName }
            if guid == selected then selectionVisible = true end
        end
    end
    table.sort(entries, function(a, b)
        if a.name == b.name then return a.id < b.id end
        return a.name < b.name
    end)
    if not selectionVisible then
        selected = entries[1] and entries[1].id
        details:SetVerticalScroll(0)
    end
    empty:SetText(query ~= "" and L.noMatches or L.empty)
    names:SetRivals(entries, selected)
    ShowDetails()
end

function addon.CreateBookHeader(parent)
    local atlas = "Profession-Background-Template2"
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    if not info or info.width <= 0 or info.height <= 0 then return end

    -- Keep the crop that included the lower edge at the original 694-unit draw width.
    local sourceBand = math.min(1, (98 / 694) * info.width / info.height)
    local art = parent:CreateTexture(nil, "BACKGROUND", nil, -3)
    art:SetPoint("TOPLEFT", 3, -21)
    art:SetSize(parent:GetWidth() - 6, 44)
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

local detailBackgroundTint = 0.76

local function ListBackground(parent, tint, x, y, width, height)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    if x then
        texture:SetPoint("TOPLEFT", x, y)
        texture:SetSize(width, height)
    else
        texture:SetAllPoints()
    end
    addon.ApplyAtlas(texture, "Professions-background-summarylist")
    if tint then texture:SetVertexColor(tint, tint, tint) end
end

local function BattlefieldBackground(parent, fullWidth)
    if fullWidth then ListBackground(parent, detailBackgroundTint) end
    local size = math.min(parent:GetWidth() * (fullWidth and 0.52 or 0.58),
        parent:GetHeight() * (fullWidth and 0.78 or 0.56))
    local illustration = parent:CreateTexture(nil, "BACKGROUND", nil, fullWidth and 1 or 0)
    illustration:SetTexture(addon.battlefieldArtPath)
    illustration:SetSize(size, size)
    illustration:SetAlpha(0.24)
    if fullWidth then illustration:SetPoint("CENTER")
    else illustration:SetPoint("BOTTOMRIGHT", -9, 13) end

    local trim = parent:CreateTexture(nil, "BORDER")
    trim:SetAllPoints()
    addon.ApplyAtlas(trim, "common-insideframe")
end

local function MakeDraggable(frame)
    frame:SetMovable(true)
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

local function OpenSkirmish(id)
    if not (addon.db.skirmishes and addon.db.skirmishes[id]) then return end
    selectedSkirmishID = id
    battleList:SetVerticalScroll(0)
    SetBookView(battleView)
    addon.RefreshBook()
end

local function SelectRivalTab(id)
    PanelTemplates_SetTab(tabBar, id)
    for index, tab in ipairs(tabBar.Tabs) do
        tab.SelectedHighlight:SetShown(index == id)
    end
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

local function FullSkirmishList(pane, bind, initiallyExpanded)
    local leftInset, rightGutter = 20, 42
    local width = pane:GetWidth() - leftInset - rightGutter
    local function CreateBattleCard(parent, cardWidth, onMapShown, toggleTimeline)
        return addon.CreateSkirmishCard(parent, cardWidth, onMapShown, OpenRival, toggleTimeline)
    end
    local list = CardList(pane, leftInset, -42, width, pane:GetHeight() - 56,
        CreateBattleCard, bind, addon.SkirmishCardHeight, initiallyExpanded)
    local bar = list.ScrollBar
    bar:ClearAllPoints()
    bar:SetPoint("TOP", list, "TOPRIGHT", rightGutter / 2, 0)
    bar:SetPoint("BOTTOM", list, "BOTTOMRIGHT", rightGutter / 2, 0)
    return list
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
        window:Hide()
        window:SetSize(810, 640)
        window:SetPoint("CENTER")
        -- Share the ordinary window strata so another top-level panel can rise above us.
        window:SetFrameStrata("MEDIUM")
        window:SetToplevel(true)
        window:EnableMouse(true)
        window:SetClampedToScreen(true)
        window:SetTitle(addon.title)
        addon.SetBookPortrait(window)
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

        addon.CreateBookHeader(window)
        rivalsPage = CreateFrame("Frame", nil, window)
        rivalsPage:SetAllPoints()
        recentPage = CreateFrame("Frame", nil, window)
        recentPage:SetAllPoints()
        local contentTop = 65
        local paneRightInset = 7
        local fullPaneWidth = window:GetWidth() - 5 - paneRightInset
        local bodyHeight = window:GetHeight() - contentTop - 5
        local leftX = 5
        local rightX = leftX + addon.rivalListWidth + 2
        local rightWidth = window:GetWidth() - rightX - paneRightInset
        local cardWidth = rightWidth - 2 * profileInset
        local left = Pane(rivalsPage, leftX, -contentTop, addon.rivalListWidth, bodyHeight)
        ListBackground(left)
        -- One continuous surface behind the tabs and transparent detail pane.
        ListBackground(rivalsPage, detailBackgroundTint, rightX, -contentTop, rightWidth, bodyHeight)

        local rightTop = contentTop + 30
        local rightHeight = window:GetHeight() - rightTop - 5
        local right = Pane(rivalsPage, rightX, -rightTop, rightWidth, rightHeight)
        BattlefieldBackground(right)
        local nameBar
        names, nameBar = addon.CreateRivalList(left, function(id)
            selected = id
            details:SetVerticalScroll(0)
            addon.RefreshBook()
        end)
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
            -- The transmog strip follows the tab's authored width and sits below its edge.
            local highlight = CreateFrame("Frame", nil, tab)
            highlight:SetFrameLevel(math.max(tab:GetFrameLevel(), right:GetFrameLevel()) + 1)
            highlight:SetHeight(2)
            highlight:SetPoint("BOTTOMLEFT", 2, -2)
            highlight:SetPoint("BOTTOMRIGHT", -3, -2)
            local glow = highlight:CreateTexture(nil, "ARTWORK")
            glow:SetAllPoints()
            addon.ApplyAtlas(glow, "transmog-tab-hl")
            tab.SelectedHighlight = highlight
            tab:SetScript("OnClick", function(self)
                SelectRivalTab(self:GetID())
                ShowDetails()
            end)
        end
        PanelTemplates_SetNumTabs(tabBar, 2)
        SelectRivalTab(infoTab)
        -- Match the template's OnShow sizing once labels and selection are set.
        for _, tab in ipairs(tabBar.Tabs) do
            PanelTemplates_TabResize(tab)
        end

        local historyTop = 16
        local function CreateRivalCard(parent, width, onMapShown)
            return addon.CreateCompactEncounterCard(parent, width, onMapShown, OpenSkirmish)
        end
        details = CardList(right, profileInset, -historyTop, cardWidth, rightHeight - historyTop - 12,
            CreateRivalCard, function(card, encounter)
                card:SetEncounter(encounter, addon.db.rivals[selected], selected)
            end, function() return addon.compactEncounterCardHeight end)
        historyEmpty = right:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        historyEmpty:SetPoint("CENTER", 0, 5)
        historyEmpty:SetText(L.noSkirmishes)

        summary = CreateFrame("Frame", nil, right)
        summary:SetPoint("TOPLEFT", 0, -3)
        summary:SetPoint("BOTTOMRIGHT")
        profilePortrait = addon.CreateParticipantPortrait(summary)
        local rim = profilePortrait.rim
        -- The race ring artwork has a small transparent border.
        rim:SetPoint("TOPLEFT", profileInset - 2, -17.5)
        heading = summary:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        heading:SetPoint("TOPLEFT", rim, "TOPRIGHT", 8.5, -8.5)
        heading:SetPoint("TOPRIGHT", summary, "TOPRIGHT", -50, -26)
        heading:SetJustifyH("LEFT")
        heading:SetWordWrap(false)
        status = summary:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        status:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
        status:SetWidth(275)
        status:SetJustifyH("LEFT")
        status:SetTextColor(0.72, 0.67, 0.59)
        local statsTop = -92
        local statsHeading = SectionHeading(summary, statsTop, cardWidth, L.personalScore)
        local secondRow = -reagentSlotHeight - reagentRowSpacing
        local columnGap = 12
        local columnWidth = (cardWidth - columnGap) / 2
        local rewardColumn = columnWidth + columnGap
        wins = Stat(summary, statsHeading, 0, 0, columnWidth, addon.swordsIconPath, L.winsDescription)
        losses = Stat(summary, statsHeading, 0, secondRow, columnWidth, addon.defeatStatIconPath, L.lossesDescription)
        local faction = addon.PlayerFaction()
        honorableKills = Stat(summary, statsHeading, rewardColumn, 0, columnWidth,
            addon.honorableKillIconPath, L.honorableKills)
        honor, honorIcon = Stat(summary, statsHeading, rewardColumn, secondRow, columnWidth,
            addon.HonorIconTexture(faction), L.honor)
        local latestHeadingTop = statsTop - sectionHeaderHeight + secondRow - reagentSlotHeight - sectionGap
        local latestHeading = SectionHeading(summary, latestHeadingTop, cardWidth, L.latestEncounter)
        local latestInset = (reagentSlotHeight - reagentButtonSize) / 2
        latestEmpty = summary:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        latestEmpty:SetPoint("TOPLEFT", latestHeading, "BOTTOMLEFT", 0, -latestInset)
        latestEmpty:SetText(L.noSkirmishes)
        latestCard = CreateRivalCard(summary, cardWidth, CloseForMap)
        latestCard:SetPoint("TOPLEFT", latestHeading, "BOTTOMLEFT", 0, -latestInset)
        empty = right:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        empty:SetPoint("CENTER", 0, 5)
        empty:SetWidth(305)
        empty:SetText(L.empty)

        local add = CreateFrame("Button", nil, left, "SharedButtonSmallTemplate")
        add:SetPoint("CENTER", nameBar, "TOP", 0, 17)
        add:SetSize(23, 23)
        search = CreateFrame("EditBox", nil, left, "SearchBoxTemplate")
        search:SetHeight(20)
        search:SetPoint("TOPLEFT", 13, -8)
        search:SetPoint("RIGHT", add, "LEFT", -4, 0)
        search:SetMaxLetters(96)
        search:HookScript("OnTextChanged", function()
            addon.RefreshBook()
            names:ScrollToBegin(ScrollBoxConstants.NoScrollInterpolation)
        end)

        local openDialog
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
        add:SetScript("OnLeave", HideTooltip)
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
        local remove = CreateFrame("Button", nil, summary)
        remove:SetPoint("TOPRIGHT", right, "TOPRIGHT", -14, -12)
        remove:SetSize(22, 22)
        local removeIcon = remove:CreateTexture(nil, "ARTWORK")
        removeIcon:SetSize(22, 22)
        removeIcon:SetPoint("TOPLEFT", 0, 0)
        removeIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        removeIcon:SetAlpha(0.5)
        remove:SetScript("OnEnter", function(self)
            removeIcon:SetAlpha(1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(DELETE)
            GameTooltip:Show()
        end)
        local function ResetRemove(self)
            removeIcon:SetAlpha(0.5)
            removeIcon:SetPoint("TOPLEFT", 0, 0)
            HideTooltip(self)
        end
        remove:SetScript("OnLeave", ResetRemove)
        remove:SetScript("OnHide", ResetRemove)
        remove:SetScript("OnMouseDown", function() removeIcon:SetPoint("TOPLEFT", 1, -1) end)
        remove:SetScript("OnMouseUp", function() removeIcon:SetPoint("TOPLEFT", 0, 0) end)
        remove:SetScript("OnClick", function(self)
            local rival = selected and addon.Ledger.Find(addon.db, selected)
            if rival then
                ResetRemove(self)
                StaticPopup_Show(deletePopup, rival.displayName, nil, selected)
            end
        end)
        local journal = Pane(recentPage, 5, -contentTop, fullPaneWidth, bodyHeight)
        BattlefieldBackground(journal, true)
        local journalTitle = journal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        journalTitle:SetPoint("TOPLEFT", 20, -15)
        journalTitle:SetText(L.recentView)
        recentEmpty = journal:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        recentEmpty:SetPoint("CENTER")
        recentEmpty:SetText(L.noSkirmishes)
        recentList = FullSkirmishList(journal, function(card, battle, expanded)
            card:SetSkirmish(battle, nil, expanded)
        end)

        battlePage = Pane(window, 5, -contentTop, fullPaneWidth, bodyHeight)
        BattlefieldBackground(battlePage, true)
        local back = CreateFrame("Button", nil, battlePage, "UIPanelButtonTemplate")
        back:SetPoint("TOPLEFT", 20, -11)
        back:SetSize(92, 23)
        back:SetText(BACK)
        back:SetScript("OnClick", function()
            SetBookView(rivalsView)
            addon.RefreshBook()
        end)
        battleList = FullSkirmishList(battlePage, function(card, battle, expanded)
            card:SetSkirmish(battle, selected, expanded)
        end, true)

        CreateSideTabs()
        SetBookView(activeView)
        window:HookScript("OnShow", function(self)
            self:Raise()
            PlaySound(SOUNDKIT.UI_PROFESSIONS_WINDOW_OPEN)
        end)
        window:HookScript("OnHide", function()
            PlaySound(SOUNDKIT.UI_PROFESSIONS_WINDOW_CLOSE)
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
    icon:SetSize(23.5, 23.5)
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
        button.dragging = nil
        button:SetScript("OnUpdate", nil)
        HideTooltip(button)
    end
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton == "LeftButton" then self.dragged = false end
    end)
    button:SetScript("OnDragStart", function(self)
        self.dragging, self.dragged = true, true
        HideTooltip(self)
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
    button:SetScript("OnClick", function(self, mouseButton)
        if self.dragging then return end
        if mouseButton == "RightButton" then
            HideTooltip(self)
            addon.OpenSettings()
        elseif not self.dragged then
            ToggleBook()
        end
    end)
    button:SetScript("OnEnter", function(self)
        if self.dragging then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(addon.title)
        GameTooltip:AddLine(L.minimapHint, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", HideTooltip)
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

local unitTooltipType = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit

function addon.RefreshUnitTooltip()
    local tooltip = GameTooltip
    if unitTooltipType and tooltip and tooltip.RefreshDataNextUpdate and tooltip.IsTooltipType
        and tooltip:IsShown() and tooltip:IsTooltipType(unitTooltipType) then
        tooltip:RefreshDataNextUpdate()
    end
end

if TooltipDataProcessor and unitTooltipType then
    TooltipDataProcessor.AddTooltipPostCall(unitTooltipType, function(tooltip, data)
        if tooltip ~= GameTooltip or not addon.db or not addon.IsUnitTooltipEnabled() then return end
        local rival, id = TooltipRival(tooltip, data)
        if not rival then return end
        local counters = addon.RivalCounters(id)
        local kills, deaths = addon.Ledger.PersonalCombatScore(addon.db, id)
        if counters or kills > 0 or deaths > 0 then
            tooltip:AddLine(" ")
            tooltip:AddLine(addon.title, 1, 0.82, 0)
            if counters then tooltip:AddLine(counters, 1, 1, 1) end
            if kills > 0 or deaths > 0 then tooltip:AddLine(L.personalFinishingBlows:format(kills, deaths), 1, 1, 1) end
        end
    end)
end
