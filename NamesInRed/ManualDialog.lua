local _, addon = ...
local L = addon.L

function addon.ApplyAtlas(texture, atlas)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        texture:SetAtlas(atlas)
        return true
    end
end

function addon.CreateRoundIcon(parent)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(52, 52)
    local mask = parent:CreateMaskTexture()
    mask:SetAllPoints(icon)
    if not addon.ApplyAtlas(mask, "CircleMask") then
        mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    icon:AddMaskTexture(mask)
    local ring = parent:CreateTexture(nil, "OVERLAY")
    ring:SetSize(64, 64)
    icon:SetPoint("CENTER", ring)
    if not addon.ApplyAtlas(ring, "Mode-Selection-Ring") then
        ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        ring:SetTexCoord(0, 0.68, 0, 0.68)
    end
    return icon, ring
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
    dialog:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Book_11")
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
        add:SetEnabled(selected ~= nil and addon.ManualName(edit:GetText()) ~= nil)
    end
    local function Choose(direction)
        selected = direction
        Update()
    end
    win = Choice(dialog, 24, L.win, "Interface\\AddOns\\NamesInRed\\Art\\Victory.tga", "killsAgainstThem", Choose)
    loss = Choice(dialog, 186, L.loss, "Interface\\AddOns\\NamesInRed\\Art\\Gravestone.tga", "deathsToThem", Choose)
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
