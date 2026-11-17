local addon = {}
assert(loadfile("NamesInRed/Ledger.lua"))("NamesInRed", addon)

local onEvent
local frame = {
    RegisterEvent = function(_, event) assert(event == "ADDON_LOADED") end,
    UnregisterEvent = function(_, event) assert(event == "ADDON_LOADED") end,
    SetScript = function(_, script, handler)
        assert(script == "OnEvent")
        onEvent = handler
    end,
}
function CreateFrame(kind)
    assert(kind == "Frame")
    return frame
end

local function Load(saved)
    NamesInRedDB = saved
    local session = { Ledger = addon.Ledger }
    assert(loadfile("NamesInRed/Core.lua"))("NamesInRed", session)
    onEvent(frame, "ADDON_LOADED", "OtherAddon")
    assert(NamesInRedDB == saved and session.db == nil)
    onEvent(frame, "ADDON_LOADED", "NamesInRed")
    return session.db
end

local ledger = addon.Ledger
local db = assert(Load(nil))
assert(NamesInRedDB == db)
local rival = assert(ledger.Add(db, "id-one", "Rival"))
assert(rival.deathsToThem == 0 and rival.killsAgainstThem == 0)
rival.deathsToThem = 3
rival.killsAgainstThem = 2
assert(ledger.Add(db, "id-one", "Rival") == rival)
local other = assert(ledger.Add(db, "id-two", "Rival"))
assert(other ~= rival and other.deathsToThem == 0 and other.killsAgainstThem == 0)
assert(ledger.Add(db, "id-one", "") == nil)
assert(ledger.Add(db, "", "Rival") == nil)

local loaded = assert(Load(db))
local found = assert(ledger.Find(loaded, "id-one"))
assert(found.deathsToThem == 3 and found.killsAgainstThem == 2)
ledger.Remove(loaded, "id-one")
assert(ledger.Find(loaded, "id-one") == nil)
assert(ledger.Find(loaded, "id-two") == other)

local future = { version = 2, rivals = { existing = true } }
assert(Load(future) == nil)
assert(NamesInRedDB == future and future.rivals.existing)
local malformed = { version = 1 }
assert(Load(malformed) == nil and NamesInRedDB == malformed)
print("Ledger and startup checks passed")
