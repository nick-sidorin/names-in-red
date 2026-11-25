local _, addon = ...

-- Camelot's crafting page overrides the shared recipe list width.
addon.rivalListWidth = 304

local recipeTemplate = "ProfessionsRecipeListRecipeTemplate"
local rowHeight = 20
local recipeIndent = 10
local labelInset = 26 - 9 + 4

local function FallbackRowArt(row, layer, subLevel, atlas)
    local texture = row:CreateTexture(nil, layer, nil, subLevel)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        texture:SetAtlas(atlas, true)
    end
    texture:SetPoint("CENTER", 0, -1)
    return texture
end

local function CreateFallbackRowVisuals(row)
    row.Label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight_NoShadow", 1)
    row.Label:SetPoint("LEFT", labelInset, 0)
    row.Label:SetHeight(12)
    row.Label:SetJustifyH("LEFT")
    row.SelectedOverlay = FallbackRowArt(row, "OVERLAY", 2, "Professions_Recipe_Active")
    row.HighlightOverlay = FallbackRowArt(row, "HIGHLIGHT", 0, "Professions_Recipe_Hover")
    row.HighlightOverlay:SetAlpha(0.5)
    function row:SetSelected(selected)
        self.SelectedOverlay:SetShown(selected)
        self.HighlightOverlay:SetShown(not selected)
    end
end

function addon.CreateRivalList(parent, onSelect)
    if not ProfessionsRecipeListRecipeMixin and C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_ProfessionsTemplates")
    end
    local useRecipeTemplate = ProfessionsRecipeListRecipeMixin ~= nil
    local scroll = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
    scroll:SetPoint("TOPLEFT", 8, -35)
    scroll:SetPoint("BOTTOMRIGHT", -20, 5)
    local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT")
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT")

    -- Match the recipe tree's spacing and one level of recipe indentation.
    local view = CreateScrollBoxListLinearView(5, 5, recipeIndent, 5, 1)
    local recipeColor = PROFESSION_RECIPE_COLOR or CreateColor(0.83, 0.82, 0.80)
    local red = DIM_RED_FONT_COLOR or RED_FONT_COLOR
    local normalR, normalG, normalB = recipeColor:GetRGB()
    if red then
        local redR, redG, redB = red:GetRGB()
        normalR = normalR * 0.75 + redR * 0.25
        normalG = normalG * 0.75 + redG * 0.25
        normalB = normalB * 0.75 + redB * 0.25
    end
    local hoverColor = HIGHLIGHT_FONT_COLOR
    local selectedID, previousEntries
    local function OnEnter(row)
        row.Label:SetVertexColor(hoverColor:GetRGB())
        if row.Label:IsTruncated() then
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:SetText(row.Label:GetText())
            GameTooltip:Show()
        end
    end
    local function OnLeave(row)
        row.Label:SetVertexColor(normalR, normalG, normalB)
        addon.HideOwnedTooltip(row)
    end
    local function BindRow(row, entry)
        if not row.rivalRowInitialized then
            if useRecipeTemplate then
                row.SkillUps:Hide()
                row.LockedIcon:Hide()
                row.Count:Hide()
            else
                CreateFallbackRowVisuals(row)
            end
            row.Label:SetPoint("RIGHT", row, "RIGHT", -10, 0)
            row.Label:SetWordWrap(false)
            -- The native recipe hover and click handlers expect recipe IDs.
            row:RegisterForClicks("LeftButtonUp")
            row:SetScript("OnEnter", OnEnter)
            row:SetScript("OnLeave", OnLeave)
            row:SetScript("OnHide", OnLeave)
            row:SetScript("OnClick", function(self)
                onSelect(self:GetElementData().id)
            end)
            row.rivalRowInitialized = true
        end
        if row.Label:GetText() ~= entry.name then
            addon.HideOwnedTooltip(row)
            row.Label:SetText(entry.name)
        end
        row:SetSelected(entry.id == selectedID)
        if row:IsMouseMotionFocus() then
            row.Label:SetVertexColor(hoverColor:GetRGB())
        else
            row.Label:SetVertexColor(normalR, normalG, normalB)
        end
    end
    view:SetElementExtent(rowHeight)
    view:SetElementInitializer(useRecipeTemplate and recipeTemplate or "Button", BindRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scroll, bar, view)

    function scroll:SetRivals(entries, selected)
        selectedID = selected
        local dataChanged = not previousEntries or #entries ~= #previousEntries
        if not dataChanged then
            for index, entry in ipairs(entries) do
                local previous = previousEntries[index]
                if entry.id ~= previous.id or entry.name ~= previous.name then
                    dataChanged = true
                    break
                end
            end
        end
        if dataChanged then
            previousEntries = entries
            self:SetDataProvider(CreateDataProvider(entries), ScrollBoxConstants.RetainScrollPosition)
        else
            self:ForEachFrame(BindRow)
        end
    end
    function scroll:ScrollToRival(id)
        self:ScrollToElementDataByPredicate(function(entry) return entry.id == id end,
            ScrollBoxConstants.AlignNearest, 0, ScrollBoxConstants.NoScrollInterpolation)
    end
    return scroll, bar
end
