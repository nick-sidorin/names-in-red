local addon = {}
assert(loadfile("NamesInRed/Ledger.lua"))("NamesInRed", addon)
assert(loadfile("NamesInRed/Encounter.lua"))("NamesInRed", addon)
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
function UnitName(unit) return units[unit].name, units[unit].surname end
function UnitNameUnmodified(unit) return units[unit].originalName, units[unit].originalSurname end
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

-- Keep this suite focused on event filtering and visible player identity.
addon.RecordWorldEncounter = addon.RecordEncounter
function addon.ObserveHonorKill() end
function addon.ObservedWorldOpponent() end
function addon.WorldAllyUnit(guid)
    if guid == units.player.guid then return "player" end
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
context = "pvp"
Kill("Player-self", "Player-rival")
assert(next(addon.db.rivals) == nil)

context = "none"
target.name = secret
Kill("Player-self", "Player-rival")
local rival = assert(addon.Ledger.Find(addon.db, "Player-rival"))
assert(rival.displayName == "" and rival.killsAgainstThem == 1 and rival.deathsToThem == 0)
addon.db = assert(addon.Ledger.Open(addon.db))
target.name = "Rival"
local namesake = { guid = "Player-namesake", faction = "Horde", name = "Rival", surname = "Other", attackable = true }
units.mouseover = namesake
addon.ResolveRivalName("mouseover")
assert(rival.displayName == "")
target.originalName, target.originalSurname = "Rival", "Emberfang"
addon.ResolveRivalName("target")
assert(rival.displayName == "Rival Emberfang" and rival.killsAgainstThem == 1)
Kill("Player-self", "Player-namesake")
assert(addon.db.rivals["Player-namesake"].displayName == "Rival Other")
units.target = {}
units.mouseover = target
target.originalName, target.originalSurname = nil, nil
target.surname = "Emberfang"
Kill("Player-self", "Player-rival")
assert(rival.displayName == "Rival Emberfang" and rival.killsAgainstThem == 2)
target.surname = secret
Kill("Player-self", "Player-rival")
assert(rival.displayName == "Rival Emberfang" and rival.killsAgainstThem == 3)
print("Confirmed world kill checks passed")
