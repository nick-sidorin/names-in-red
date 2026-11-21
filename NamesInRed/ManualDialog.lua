local _, addon = ...
local L = addon.L

function addon.ApplyAtlas(texture, atlas, resetTexCoords)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        texture:SetAtlas(atlas, false, nil, resetTexCoords)
        return true
    end
end

function addon.SetBookPortrait(frame)
    frame:SetPortraitToAsset(addon.swordsIconPath)
    local portrait = frame:GetPortrait()
    local inset, shift = 4 / 128, 2 / 128
    portrait:SetTexCoord(inset + shift, 1 - inset + shift, inset, 1 - inset)
    local container = frame.PortraitContainer
    local backing = container:CreateTexture(nil, "BACKGROUND")
    backing:SetAllPoints(portrait)
    backing:SetColorTexture(0.02, 0.03, 0.055, 1)
    backing:AddMaskTexture(container.CircleMask)
end

function addon.CreateRoundIcon(parent, size)
    size = size or 64
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size * 13 / 16, size * 13 / 16)
    local mask = parent:CreateMaskTexture()
    mask:SetAllPoints(icon)
    if not addon.ApplyAtlas(mask, "CircleMask") then
        mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    icon:AddMaskTexture(mask)
    local ring = parent:CreateTexture(nil, "OVERLAY")
    ring:SetSize(size, size)
    icon:SetPoint("CENTER", ring)
    if not addon.ApplyAtlas(ring, "Mode-Selection-Ring") then
        ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        ring:SetTexCoord(0, 0.68, 0, 0.68)
    end
    return icon, ring
end

function addon.SetRivalPortrait(portrait, rival, id, size, mirrored)
    size = size or 64
    portrait:SetSize(size * 13 / 16, size * 13 / 16)
    local race, sex, class = rival.race, rival.sex, rival.class
    if not race then
        local knownRace, knownSex, knownClass = addon.RivalAppearance(id)
        race, sex, class = knownRace, knownSex, class or knownClass
    end
    if race and (sex == 2 or sex == 3) and GetRaceAtlas then
        local gender = sex == 3 and "female" or "male"
        if addon.ApplyAtlas(portrait, GetRaceAtlas(race, gender, true), true)
            or addon.ApplyAtlas(portrait, GetRaceAtlas(race, gender), true) then
            -- Mirror the atlas region in texture-local coordinates.
            if mirrored then portrait:SetTexCoord(1, 0, 0, 1) end
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
        portrait:SetSize(size * 11 / 16, size * 11 / 16)
    end
end

function addon.CreateLevelBadge(parent, rim, rightSide, size)
    size = size or 24
    local badge = CreateFrame("Frame", nil, parent)
    badge:SetSize(size, size)
    badge:SetPoint("CENTER", rim, rightSide and "BOTTOMRIGHT" or "BOTTOMLEFT",
        rightSide and -size / 2 or size / 2, size / 2)
    local circle = badge:CreateTexture(nil, "ARTWORK")
    circle:SetAllPoints()
    circle:SetTexture(addon.levelBadgePath)
    local font = size < 24 and "SystemFont_Tiny" or "GameFontHighlightSmall"
    local label = badge:CreateFontString(nil, "OVERLAY", font)
    label:SetTextColor(1, 1, 1)
    label:SetPoint("CENTER", 0, -0.5)
    label:SetSize(size, size)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetShadowOffset(0, 0)
    function badge:SetLevel(level)
        local known = type(level) == "number" and level > 0
        self:SetShown(known)
        label:SetText(known and level or "")
    end
    badge:Hide()
    return badge
end

local function Choice(parent, x, title, texture, direction, choose)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(150, 102)
    button:SetPoint("TOPLEFT", x, -111)

    local icon, ring = addon.CreateRoundIcon(button)
    ring:SetPoint("TOP", 0, -3)
    icon:SetTexture(texture)
    local glow = button:CreateTexture(nil, "OVERLAY", nil, 1)
    glow:SetSize(69, 69)
    glow:SetPoint("CENTER", icon)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.32)
    local hasGlow = addon.ApplyAtlas(glow, "ArtifactsFX-YellowRing")
    glow:Hide()

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOP", icon, "BOTTOM", 0, -9)
    label:SetWidth(144)
    label:SetText(title)
    button:SetScript("OnClick", function() choose(direction) end)
    button:SetScript("OnEnter", function() icon:SetVertexColor(1, 1, 1) end)
    button:SetScript("OnLeave", function()
        if not button.selected then icon:SetVertexColor(0.86, 0.86, 0.86) end
    end)
    function button:SetSelected(selected)
        self.selected = selected
        glow:SetShown(selected and hasGlow == true)
        if selected then
            ring:SetVertexColor(1, 0.88, 0.47)
            label:SetTextColor(1, 0.84, 0.38)
            icon:SetVertexColor(1, 1, 1)
        else
            ring:SetVertexColor(0.72, 0.69, 0.63)
            label:SetTextColor(0.9, 0.87, 0.82)
            icon:SetVertexColor(0.86, 0.86, 0.86)
        end
    end
    return button
end

function addon.CreateManualDialog(parent, onAdded)
    local shield = CreateFrame("Frame", nil, UIParent)
    shield:SetAllPoints()
    shield:SetFrameStrata("FULLSCREEN_DIALOG")
    shield:EnableMouse(true)
    shield:EnableMouseWheel(true)
    shield:Hide()
    local shade = shield:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, 0.45)
    local dialog = CreateFrame("Frame", "NamesInRedManualEntry", shield, "PortraitFrameTemplate")
    dialog:SetSize(360, 267)
    dialog:SetPoint("CENTER", parent)
    dialog:SetClampedToScreen(true)
    dialog:SetTitle(L.addTitle)
    addon.SetBookPortrait(dialog)
    dialog.onCloseCallback = function() shield:Hide(); return false end

    local label = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", 24, -60)
    label:SetText(L.fullName)
    -- The native mail widget supplies navigation and a dropdown for known names.
    local mail = AUTOCOMPLETE_LIST and AUTOCOMPLETE_LIST.MAIL
    local autocomplete = mail and C_AutoComplete and C_AutoComplete.GetAutoCompleteResults
        and AutoCompleteEditBox_SetAutoCompleteSource and AutoCompleteBox
    local edit = CreateFrame("EditBox", nil, dialog,
        autocomplete and "InputBoxTemplate, AutoCompleteEditBoxTemplate" or "InputBoxTemplate")
    -- InputBoxVisualTemplate extends the left edge five pixels from its anchor.
    edit:SetPoint("TOPLEFT", 29, -81)
    edit:SetPoint("TOPRIGHT", -24, -81)
    edit:SetHeight(23)
    edit:SetMaxLetters(96)
    edit:SetAutoFocus(false)
    if autocomplete then
        AutoCompleteEditBox_SetAutoCompleteSource(edit, C_AutoComplete.GetAutoCompleteResults,
            mail.include, mail.exclude)
    end

    local add = CreateFrame("Button", nil, dialog, "SharedButtonSmallTemplate")
    add:SetPoint("BOTTOMRIGHT", -24, 19)
    add:SetSize(150, 28)
    add:SetText(L.add)
    local cancel = CreateFrame("Button", nil, dialog, "SharedButtonSmallTemplate")
    cancel:SetPoint("RIGHT", add, "LEFT", -12, 0)
    cancel:SetSize(150, 28)
    cancel:SetText(CANCEL)

    local selected, target, win, loss
    local function Update()
        win:SetSelected(selected == "killsAgainstThem")
        loss:SetSelected(selected == "deathsToThem")
        add:SetEnabled(selected ~= nil and addon.HasFullName(addon.ManualName(edit:GetText())))
    end
    local function Choose(direction)
        selected = direction
        Update()
    end
    win = Choice(dialog, 24, L.win, addon.swordsIconPath, "killsAgainstThem", Choose)
    loss = Choice(dialog, 186, L.loss, addon.defeatBannerPath, "deathsToThem", Choose)
    local function Save()
        local id = addon.AddManualEncounter(edit:GetText(), selected, target)
        if id then
            shield:Hide()
            onAdded(id)
        end
    end
    add:SetScript("OnClick", Save)
    cancel:SetScript("OnClick", function() shield:Hide() end)
    edit:HookScript("OnTextChanged", Update)
    edit:SetScript("OnEscapePressed", function(self)
        if autocomplete and AutoCompleteEditBox_OnEscapePressed(self) then return end
        shield:Hide()
    end)
    edit:SetScript("OnEnterPressed", function(self)
        if autocomplete and AutoCompleteEditBox_OnEnterPressed(self) then return end
        if add:IsEnabled() then Save() end
    end)
    parent:HookScript("OnHide", function() shield:Hide() end)
    shield:SetScript("OnHide", function() edit:ClearFocus(); dialog:Hide() end)
    dialog:HookScript("OnHide", function()
        if shield:IsShown() then shield:Hide() end
    end)
    tinsert(UISpecialFrames, 1, dialog:GetName())

    return function()
        selected = nil
        target = addon.ManualTarget()
        edit:SetText(target and target.name or "")
        Update()
        shield:Show()
        dialog:Show()
        edit:SetFocus()
    end
end
