local rival = { displayName = "Cute Rock", encounters = { { outcome = "win" } } }
local addon = { db = { rivals = { ["Player-rival"] = rival } }, L = {} }
local secret = {}
function issecretvalue(value) return value == secret end
local unit, guid = "nameplate1", "Player-rival"
function UnitGUID(token) return token == "player" and "Player-self" or guid end
function UnitIsPlayer() return true end
function UnitIsFriend() return true end
function UnitName() return "Cute", "Rock" end
local pixelFactor, badgeScale = 0.8, 0.75
PixelUtil = { GetPixelToUIUnitFactor = function() return pixelFactor end }

local function Anchor()
    return {
        IsForbidden = function() return false end,
        IsShown = function(self) return self.shown end,
        shown = true,
    }
end
local bar, name, parent = Anchor(), Anchor(), Anchor()
parent.HealthBarsContainer = { healthBar = bar }
parent.name = name
local plate = Anchor()
plate.IsForbidden = function(self) return self.forbidden end
plate.UnitFrame = parent
plate.unitToken = unit
local lookups = 0
C_NamePlate = { GetNamePlateForUnit = function(token)
    lookups = lookups + 1
    if token == plate.unitToken then return plate end
end }

local events, onEvent, badge = {}
function CreateFrame(_, _, owner)
    if not owner then
        return {
            RegisterEvent = function(_, event) events[event] = true end,
            SetScript = function(_, _, cb) onEvent = cb end,
        }
    end
    assert(owner == parent and badge == nil)
    badge = {
        SetSize = function() end,
        CreateFontString = function(self)
            return {
                SetTextColor = function() end,
                SetPoint = function(_, point, x, y)
                    assert(point == "CENTER" and x == 0)
                    self.textOffsetY = y
                end,
                SetText = function(_, value) self.text = value end,
            }
        end,
        GetEffectiveScale = function() return badgeScale end,
        ClearAllPoints = function() end,
        SetPoint = function(self, point, anchor, relativePoint, x, y)
            assert(point == "BOTTOM" and relativePoint == "TOP" and x == 0 and y == 0)
            self.anchor = anchor
        end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
    }
    return badge
end

for _, file in ipairs({ "Ledger", "Encounter", "Portraits", "EncounterCards", "Core", "Book", "Nameplates" }) do
    assert(loadfile("NamesInRed/" .. file .. ".lua"))("NamesInRed", addon)
end

onEvent(nil, "NAME_PLATE_UNIT_ADDED", unit)
assert(badge.shown and badge.anchor == name)
assert(badge.text:find("CrossedSwords.tga:14:14:0:0", 1, true) and not badge.text:find("TooltipSkull.tga", 1, true))
assert(badge.textOffsetY == pixelFactor / badgeScale)
addon.db.showNameplateIcons = false
addon.RefreshNameplates()
onEvent(nil, "NAME_PLATE_UNIT_ADDED", unit)
assert(not badge.shown and lookups == 1)
addon.db.showNameplateIcons = true
addon.RefreshNameplates()
assert(badge.shown and lookups == 2)
rival.encounters[2] = { outcome = "loss" }
addon.RefreshNameplates()
assert(badge.shown and badge.text:find("TooltipSkull.tga:14:14:0:0|t 1", 1, true))
assert(not badge.text:find("DefeatBanner.tga", 1, true))
pixelFactor, badgeScale = 0.5, 0.9
assert(events.DISPLAY_SIZE_CHANGED and events.UI_SCALE_CHANGED)
onEvent(nil, "DISPLAY_SIZE_CHANGED")
assert(badge.anchor == name and badge.textOffsetY == pixelFactor / badgeScale)
name.shown = false
addon.RefreshNameplates()
assert(badge.anchor == bar)
name.shown = true

guid = secret
onEvent(nil, "PLAYER_REGEN_DISABLED")
assert(not badge.shown)
guid = "Player-rival"
onEvent(nil, "PLAYER_REGEN_ENABLED")
assert(badge.shown)
plate.forbidden = true
addon.RefreshNameplates()
assert(not badge.shown)
plate.forbidden = false

addon.db.rivals["Player-rival"] = nil
addon.RefreshNameplates()
assert(not badge.shown)
addon.db.rivals["manual:cute rock"] = rival
addon.RefreshNameplates()
assert(badge.shown and badge.text:find("TooltipSkull.tga:14:14:0:0|t 1", 1, true))
rival.encounters = {}
addon.RefreshNameplates()
assert(not badge.shown)
rival.encounters[1] = { outcome = "win" }
addon.RefreshNameplates()
assert(badge.shown)

onEvent(nil, "NAME_PLATE_UNIT_REMOVED", unit)
assert(not badge.shown)
plate.unitToken, guid = "nameplate2", "Creature-unknown"
onEvent(nil, "NAME_PLATE_UNIT_ADDED", plate.unitToken)
assert(not badge.shown)
onEvent(nil, "PLAYER_LEAVING_WORLD")
guid = "Player-rival"
addon.RefreshNameplates()
assert(not badge.shown)
print("Rival nameplate checks passed")
