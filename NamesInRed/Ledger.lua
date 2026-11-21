local _, addon = ...
local Ledger = {}
addon.Ledger = Ledger
local skirmishIndexes = setmetatable({}, { __mode = "k" })

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
        -- Keep the shared battle and its timeline when removing a rival's history.
        for _, battle in pairs(db.skirmishes or {}) do
            for _, opponent in ipairs(battle.enemies) do
                if opponent.rivalID == id then opponent.rivalID = nil end
            end
        end
        skirmishIndexes[db] = nil
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
    skirmishIndexes[db] = nil
    return skirmish
end

function Ledger.RemoveSkirmish(db, id)
    if db.skirmishes then
        db.skirmishes[id] = nil
        skirmishIndexes[db] = nil
    end
end

local function IndexSkirmish(index, id, battle)
    local player
    for _, ally in ipairs(battle.allies) do
        if ally.isSelf and ally.id then
            player = ally
            break
        end
    end
    local opponents = {}
    for _, opponent in ipairs(battle.enemies) do
        if opponent.id and opponent.rivalID then
            local rival = index[opponent.rivalID]
            if not rival then
                rival = { wins = 0, losses = 0, encounters = {} }
                index[opponent.rivalID] = rival
            end
            local summary = {
                skirmishID = id, time = battle.time or battle.startedAt, sequence = battle.sequence,
                zone = battle.zone, mapID = battle.mapID, x = battle.x, y = battle.y,
                playerLevel = player and player.level, rivalLevel = opponent.level,
                player = player, opponent = opponent,
                wins = 0, losses = 0,
            }
            opponents[opponent.id] = { index = rival, summary = summary }
            rival.encounters[#rival.encounters + 1] = summary
        end
    end
    if not player then return end
    for _, event in ipairs(battle.events) do
        -- True identifies a confirmed contributor who was alive at this death.
        if event.kind == "kill" and type(event.contributors) == "table" then
            if event.targetID == player.id then
                for contributorID, alive in pairs(event.contributors) do
                    local opponent = opponents[contributorID]
                    if opponent and alive == true then
                        opponent.index.losses = opponent.index.losses + 1
                        opponent.summary.losses = opponent.summary.losses + 1
                    end
                end
            elseif event.contributors[player.id] == true then
                local opponent = opponents[event.targetID]
                if opponent then
                    opponent.index.wins = opponent.index.wins + 1
                    opponent.summary.wins = opponent.summary.wins + 1
                end
            end
        end
    end
end

local function RivalSkirmishIndex(db, id)
    local index = skirmishIndexes[db]
    if not index then
        index = {}
        for battleID, battle in pairs(db.skirmishes or {}) do
            IndexSkirmish(index, battleID, battle)
        end
        skirmishIndexes[db] = index
    end
    return index[id]
end

function Ledger.PersonalScore(db, id)
    local rival = db.rivals[id]
    local battles = RivalSkirmishIndex(db, id)
    return (rival and rival.killsAgainstThem or 0) + (battles and battles.wins or 0),
        (rival and rival.deathsToThem or 0) + (battles and battles.losses or 0)
end

function Ledger.RivalSkirmishes(db, id)
    local battles = RivalSkirmishIndex(db, id)
    return battles and battles.encounters or {}
end
