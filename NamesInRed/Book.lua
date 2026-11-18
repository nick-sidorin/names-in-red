local addonName, addon = ...
local L, Readable = addon.L, addon.Readable
local iconPath = "Interface\\Icons\\INV_Misc_Book_11"
local window, names, details, heading, totals, selected, empty
local buttons, lines = {}, {}

local function Counts(rival)
    return ("%s: %d    %s: %d"):format(L.kills, rival.killsAgainstThem, L.deaths, rival.deathsToThem)
end

local function Scroll(parent, x, y, width, height)
    local frame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    frame:SetPoint("TOPLEFT", x, y)
    frame:SetSize(width, height)
    local child = CreateFrame("Frame", nil, frame)
    child:SetSize(width, 1)
    frame:SetScrollChild(child)
    frame.ScrollBar:Hide()
    frame:HookScript("OnScrollRangeChanged", function(self, _, verticalRange)
        self.ScrollBar:SetShown(verticalRange > 0)
    end)
    return child, frame
end

local function ShowDetails()
    local rival = selected and addon.db.rivals[selected]
    heading:SetText(rival and rival.displayName or "")
    empty:SetShown(rival == nil)
    details:GetParent():SetShown(rival ~= nil and rival.encounters ~= nil and #rival.encounters > 0)
    totals:SetText(rival and Counts(rival) or "")
    local encounters = rival and rival.encounters or {}
    local offset = 0
    for index, encounter in ipairs(encounters) do
        local line = lines[index]
        if not line then
            line = details:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            line:SetWidth(326)
            line:SetJustifyH("LEFT")
            lines[index] = line
        end
        local winning = encounter.direction == "killsAgainstThem"
        local outcome = winning and L.kills or L.deaths
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
        line:SetText(outcome .. (when and ("  ·  " .. when) or "") .. place .. levels)
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
    names:GetParent():SetShown(#ids > 0)
    for index, guid in ipairs(ids) do
        local button = buttons[index]
        if not button then
            button = CreateFrame("Button", nil, names, "UIPanelButtonTemplate")
            button:SetSize(166, 25)
            button:SetPoint("TOPLEFT", 0, -(index - 1) * 27)
            button:SetScript("OnClick", function(self)
                selected = self.rivalID
                details:GetParent():SetVerticalScroll(0)
                addon.RefreshBook()
            end)
            buttons[index] = button
        end
        button.rivalID = guid
        local name = addon.db.rivals[guid].displayName
        button:SetText(name .. (guid:match("^manual:") and " *" or ""))
        if guid == selected then button:LockHighlight() else button:UnlockHighlight() end
        button:Show()
    end
    for index = #ids + 1, #buttons do buttons[index]:Hide() end
    names:SetHeight(math.max(1, #ids * 27))
    ShowDetails()
end

local function Pane(parent, x, width, atlas)
    local frame = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    frame:SetPoint("TOPLEFT", x, -58)
    frame:SetSize(width, 346)
    local art = frame:CreateTexture(nil, "BACKGROUND", nil, -4)
    art:SetPoint("TOPLEFT", 3, -3)
    art:SetPoint("BOTTOMRIGHT", -3, 3)
    if not addon.ApplyAtlas(art, atlas) then
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
        window:SetSize(588, 420)
        window:SetPoint("CENTER")
        window:SetFrameStrata("DIALOG")
        window:EnableMouse(true)
        window:SetClampedToScreen(true)
        window:SetTitle(L.book)
        if window.SetPortraitToAsset then window:SetPortraitToAsset(iconPath) end
        window.onCloseCallback = function() window:Hide(); return false end
        MakeDraggable(window)
        tinsert(UISpecialFrames, window:GetName())
        Pane(window, 13, 193, "UI-Character-Info-General-BG")
        local right = Pane(window, 208, 367, "UI-Character-Info-Stat-BG")
        local divider = window:CreateTexture(nil, "OVERLAY")
        divider:SetPoint("TOPLEFT", 203, -58)
        divider:SetSize(8, 346)
        if not addon.ApplyAtlas(divider, "common-framedivider") then
            divider:SetColorTexture(0.42, 0.29, 0.14, 1)
        end

        names = Scroll(window, 22, -67, 166, 286)
        details = Scroll(window, 226, -128, 328, 262)
        heading = window:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        heading:SetPoint("TOPLEFT", 226, -74)
        heading:SetWidth(326)
        heading:SetJustifyH("LEFT")
        totals = window:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        totals:SetPoint("TOPLEFT", 226, -101)
        local rule = right:CreateTexture(nil, "ARTWORK")
        rule:SetPoint("TOPLEFT", 16, -62)
        rule:SetSize(333, 4)
        if not addon.ApplyAtlas(rule, "UI-Character-Info-Honor-LevelBG") then
            rule:SetColorTexture(0.55, 0.39, 0.2, 0.65)
        end
        empty = window:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        empty:SetPoint("CENTER", right, "CENTER", 0, 5)
        empty:SetWidth(305)
        empty:SetText(L.empty)

        local openDialog
        local add = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        add:SetPoint("BOTTOMLEFT", 23, 26)
        add:SetSize(172, 25)
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
        GameTooltip:SetText(L.book)
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
            tooltip:AddLine(L.book, 1, 0.82, 0)
            tooltip:AddLine(Counts(rival), 1, 1, 1)
        end
    end)
end
