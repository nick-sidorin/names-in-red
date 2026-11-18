local addon = {}
assert(loadfile("NamesInRed/Ledger.lua"))("NamesInRed", addon)
local onEvent
local secret = {}
local context = "none"
local units = {
    player = { guid = "Player-self", faction = "Alliance" },
    target = { guid = "Player-rival", faction = "Horde", name = "Rival", attackable = true },
    mouseover = {},
}
function issecretvalue(value) return value == secret end
function UnitGUID(unit) return units[unit].guid end
function UnitFactionGroup(unit) return units[unit].faction end
function UnitName(unit) return units[unit].name end
function UnitIsPlayer(unit) return units[unit].guid ~= nil end
function UnitCanAttack(_, unit) return units[unit].attackable end
function IsInInstance() return context ~= "none", context end

function CreateFrame()
    return {
        RegisterEvent = function(_, event) assert(event == "PARTY_KILL") end,
        SetScript = function(_, script, handler)
            assert(script == "OnEvent")
            onEvent = handler
        end,
    }
end

local function Kill(attacker, victim)
    onEvent(nil, "PARTY_KILL", attacker, victim)
end

assert(loadfile("NamesInRed/Kills.lua"))("NamesInRed", addon)
Kill("Player-self", "Player-rival")
addon.db = assert(addon.Ledger.Open(nil))

Kill("Player-ally", "Player-rival")
Kill("Pet-self", "Player-rival")
Kill("Player-self", secret)
Kill(secret, "Player-rival")
Kill("Player-self", "Creature-mob")
Kill("Player-self", "Player-other")
local target = units.target
target.faction = "Alliance"
Kill("Player-self", "Player-rival")
target.faction = secret
Kill("Player-self", "Player-rival")
target.faction = "Horde"
target.name = secret
Kill("Player-self", "Player-rival")
target.name = "Rival"
context = "pvp"
Kill("Player-self", "Player-rival")
assert(next(addon.db.rivals) == nil)

context = "none"
Kill("Player-self", "Player-rival")
local rival = assert(addon.Ledger.Find(addon.db, "Player-rival"))
assert(rival.displayName == "Rival" and rival.killsAgainstThem == 1 and rival.deathsToThem == 0)
addon.db = assert(addon.Ledger.Open(addon.db))
units.target = {}
units.mouseover = target
Kill("Player-self", "Player-rival")
assert(addon.Ledger.Find(addon.db, "Player-rival").killsAgainstThem == 2)
print("Confirmed world kill checks passed")
