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

local function SetPortraitRingArt(ring)
    if not addon.ApplyAtlas(ring, "Mode-Selection-Ring") then
        ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        ring:SetTexCoord(0, 0.68, 0, 0.68)
    end
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
    SetPortraitRingArt(ring)
    return icon, ring
end

local function SetRacePortrait(portrait, rival, id, size, mirrored)
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

local function CreateLevelBadge(parent, rim, rightSide, size)
    local badge = CreateFrame("Frame", nil, parent)
    badge:SetSize(size, size)
    badge:SetRoundLayoutToNearestPixel(true)
    badge:SetPoint("CENTER", rim, rightSide and "BOTTOMRIGHT" or "BOTTOMLEFT",
        rightSide and -size / 2 or size / 2, size / 2)
    local circle = badge:CreateTexture(nil, "ARTWORK")
    circle:SetAllPoints()
    circle:SetTexture(addon.levelBadgePath)
    local font = size < 24 and "SystemFont_Tiny" or "GameFontHighlightSmall"
    local label = badge:CreateFontString(nil, "OVERLAY", font)
    label:SetTextColor(1, 1, 1)
    label:SetAllPoints(circle)
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

function addon.HideOwnedTooltip(button)
    local tooltip = GetAppropriateTooltip and GetAppropriateTooltip() or GameTooltip
    if tooltip:IsOwned(button) then tooltip:Hide() end
end

function addon.CreateFramedMarker(parent, size, texture, tooltipText)
    local marker = CreateFrame("Frame", nil, parent)
    marker:SetSize(size, size)
    local rim = marker:CreateTexture(nil, "BACKGROUND")
    rim:SetAllPoints()
    if not addon.ApplyAtlas(rim, "UI-HUD-UnitFrame-SmallCircle") then rim:SetTexture(addon.levelBadgePath) end
    if texture == addon.smallSkullIconPath then rim:SetVertexColor(1, 0.68, 0.64) end
    if not texture then
        local mark = marker:CreateFontString(nil, "OVERLAY", size >= 24 and "GameFontNormalLarge" or "GameFontNormal")
        mark:SetPoint("CENTER")
        mark:SetText("?")
    else
        local icon = marker:CreateTexture(nil, "OVERLAY", nil, 1)
        local iconSize = size * 0.7
        icon:SetSize(iconSize, iconSize)
        icon:SetPoint("CENTER")
        icon:SetTexture(texture)
        if texture == addon.swordsIconPath then
            local inset = addon.smallSwordsInset / 128
            icon:SetTexCoord(inset, 1 - inset, inset, 1 - inset)
        end
    end
    if tooltipText then
        marker:SetMouseMotionEnabled(true)
        marker:SetScript("OnEnter", function(self)
            local tooltip = GetAppropriateTooltip and GetAppropriateTooltip() or GameTooltip
            tooltip:SetOwner(self, "ANCHOR_TOP")
            tooltip:SetText(tooltipText)
            tooltip:Show()
        end)
        marker:SetScript("OnLeave", addon.HideOwnedTooltip)
        marker:SetScript("OnHide", addon.HideOwnedTooltip)
    end
    return marker
end

function addon.CreateParticipantPortrait(parent, options)
    options = options or {}
    local size = options.size or 64
    local opposing = options.opposing
    local portrait, rim = addon.CreateRoundIcon(parent, size)
    if options.highlightRim then
        local highlight = parent:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(rim)
        SetPortraitRingArt(highlight)
        highlight:SetBlendMode("ADD")
        highlight:SetAlpha(0.2)
        parent:SetHighlightTexture(highlight)
    end
    local level = CreateLevelBadge(parent, rim, opposing, options.levelSize or 24)
    local death
    if options.casualtySize then
        local inset = options.casualtyInset
        death = addon.CreateFramedMarker(parent, options.casualtySize, addon.smallSkullIconPath, L.portraitDeath)
        death:SetPoint("CENTER", rim, opposing and "TOPLEFT" or "TOPRIGHT", opposing and inset or -inset, -inset)
        death:Hide()
    end

    local component = { rim = rim, death = death }
    function component:SetParticipant(appearance, id, playerLevel, died)
        if options.livePlayerFallback and (not appearance.race or not appearance.sex) and SetPortraitTexture then
            portrait:SetSize(size * 13 / 16, size * 13 / 16)
            SetPortraitTexture(portrait, "player", true)
            portrait:SetTexCoord(0, 1, 0, 1)
        else
            SetRacePortrait(portrait, appearance, id, size, opposing)
        end
        level:SetLevel(playerLevel)
        if death then death:SetShown(died == true) end
        if options.desaturateCasualty then
            portrait:SetDesaturated(died)
            local shade = died and 0.78 or 1
            portrait:SetVertexColor(shade, shade, shade)
        end
    end
    return component
end
