local rival = { displayName = "Cute Rock", killsAgainstThem = 1, deathsToThem = 0 }
local addon = { db = { rivals = { ["Player-rival"] = rival } }, L = {} }
local secret = {}
function issecretvalue(value) return value == secret end
local unit, guid = "nameplate1", "Player-rival"
function UnitGUID(token) return token == "player" and "Player-self" or guid end
function UnitIsPlayer() return true end
function UnitName() return "Cute", "Rock" end

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
C_NamePlate = { GetNamePlateForUnit = function(token) if token == plate.unitToken then return plate end end }

local onEvent, badge
function CreateFrame(_, _, owner)
    if not owner then
        return { RegisterEvent = function() end, SetScript = function(_, _, cb) onEvent = cb end }
    end
    assert(owner == parent and badge == nil)
    badge = {
        SetSize = function() end,
        CreateFontString = function(self)
            return {
                SetTextColor = function() end,
                SetPoint = function() end,
                SetText = function(_, value) self.text = value end,
            }
        end,
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

for _, file in ipairs({ "Encounter", "EncounterCards", "Book", "Nameplates" }) do
    assert(loadfile("NamesInRed/" .. file .. ".lua"))("NamesInRed", addon)
end

onEvent(nil, "NAME_PLATE_UNIT_ADDED", unit)
assert(badge.shown and badge.anchor == name)
assert(badge.text:find("TooltipVictory", 1, true) and not badge.text:find("TooltipSkull", 1, true))
rival.deathsToThem = 2
addon.RefreshNameplates()
assert(badge.shown and badge.text:find("TooltipSkull", 1, true))
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
assert(badge.shown)
rival.killsAgainstThem, rival.deathsToThem = 0, 0
addon.RefreshNameplates()
assert(not badge.shown)
rival.killsAgainstThem = 1
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
