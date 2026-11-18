local _, addon = ...
local L = addon.L

function addon.ApplyAtlas(texture, atlas)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        texture:SetAtlas(atlas)
        return true
    end
end

local function Choice(parent, x, title, texture, direction, choose)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(152, 116)
    button:SetPoint("TOPLEFT", x, -104)
    button:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    local glow = button:CreateTexture(nil, "BORDER")
    glow:SetAllPoints()
    local hasGlow = addon.ApplyAtlas(glow, "Mode-Selection-Card-Regular-yellow-glow")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(54, 54)
    icon:SetPoint("TOP", 0, -14)
    icon:SetTexture(texture)
    local mask = button:CreateMaskTexture()
    mask:SetAllPoints(icon)
    if not addon.ApplyAtlas(mask, "CircleMask") then
        mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    icon:AddMaskTexture(mask)
    local ring = button:CreateTexture(nil, "OVERLAY")
    ring:SetSize(67, 67)
    ring:SetPoint("CENTER", icon)
    if not addon.ApplyAtlas(ring, "Mode-Selection-Ring") then
        ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        ring:SetTexCoord(0, 0.68, 0, 0.68)
    end
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOP", icon, "BOTTOM", 0, -10)
    label:SetWidth(136)
    label:SetText(title)
    button:SetScript("OnClick", function() choose(direction) end)
    function button:SetSelected(selected)
        glow:SetShown(selected and hasGlow == true)
        if selected then
            self:SetBackdropBorderColor(1, 0.84, 0.25)
        else
            self:SetBackdropBorderColor(0.53, 0.42, 0.27)
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
    dialog:SetSize(364, 274)
    dialog:SetPoint("CENTER", parent)
    dialog:SetClampedToScreen(true)
    dialog:SetTitle(L.addTitle)
    dialog:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Book_11")
    dialog.onCloseCallback = function() shield:Hide(); return false end

    local label = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", 26, -52)
    label:SetText(L.fullName)
    local edit = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    edit:SetPoint("TOPLEFT", 27, -73)
    edit:SetSize(310, 23)
    edit:SetMaxLetters(96)
    edit:SetAutoFocus(false)

    local add = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    add:SetPoint("BOTTOMRIGHT", -22, 15)
    add:SetSize(132, 25)
    add:SetText(L.add)
    local cancel = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    cancel:SetPoint("RIGHT", add, "LEFT", -8, 0)
    cancel:SetSize(132, 25)
    cancel:SetText(CANCEL)

    local selected, win, loss
    local function Update()
        win:SetSelected(selected == "killsAgainstThem")
        loss:SetSelected(selected == "deathsToThem")
        add:SetEnabled(selected ~= nil and addon.ManualName(edit:GetText()) ~= nil)
    end
    local function Choose(direction)
        selected = direction
        Update()
    end
    win = Choice(dialog, 22, L.win, "Interface\\AddOns\\NamesInRed\\Art\\Victory.tga", "killsAgainstThem", Choose)
    loss = Choice(dialog, 190, L.loss, "Interface\\AddOns\\NamesInRed\\Art\\Gravestone.tga", "deathsToThem", Choose)
    local function Save()
        local id = addon.AddManualEncounter(edit:GetText(), selected)
        if id then
            shield:Hide()
            onAdded(id)
        end
    end
    add:SetScript("OnClick", Save)
    cancel:SetScript("OnClick", function() shield:Hide() end)
    edit:SetScript("OnTextChanged", Update)
    edit:SetScript("OnEscapePressed", function() shield:Hide() end)
    edit:SetScript("OnEnterPressed", function()
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
        edit:SetText("")
        Update()
        shield:Show()
        dialog:Show()
        edit:SetFocus()
    end
end
