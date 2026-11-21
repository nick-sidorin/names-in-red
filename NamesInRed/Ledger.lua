local _, addon = ...
local Ledger = {}
addon.Ledger = Ledger

function Ledger.Open(saved)
    if saved == nil then
        return { version = 1, rivals = {} }
    end
    if type(saved) == "table" and saved.version == 1 and type(saved.rivals) == "table" then
        return saved
    end
end

-- The caller resolves a stable identifier before writing to the ledger.
function Ledger.Find(db, id)
    return db.rivals[id]
end

function Ledger.Add(db, id, displayName)
    if type(id) ~= "string" or id == "" then return end
    if displayName == nil and id:match("^Player%-.+") then
        displayName = ""
    elseif type(displayName) ~= "string" or displayName == "" then
        return nil
    end
    if not db.rivals[id] then
        db.rivals[id] = { displayName = displayName, deathsToThem = 0, killsAgainstThem = 0 }
    end
    return db.rivals[id]
end

function Ledger.Remove(db, id)
    if type(id) == "string" then
        db.rivals[id] = nil
    end
end

-- One battle record owns its roster and events. IDs in events are local to
-- that battle, and rival IDs are optional links to the personal ledger.
function Ledger.SaveSkirmish(db, id, skirmish)
    if type(id) ~= "string" or id == "" or type(skirmish) ~= "table"
        or type(skirmish.allies) ~= "table" or type(skirmish.enemies) ~= "table"
        or type(skirmish.events) ~= "table" then
        return
    end
    db.skirmishes = db.skirmishes or {}
    db.skirmishes[id] = skirmish
    return skirmish
end
