local _, addon = ...

local function ContactName(unit)
    local name = unit.name
    if not name then return end
    if unit.surname and unit.surname ~= "" then name = name .. " " .. unit.surname end
    name = addon.ManualName(name)
    if addon.HasFullName(name) then return name end
end

local function Index(index, key, entry)
    if index[key] == nil then
        index[key] = entry
    elseif index[key] ~= entry then
        index[key] = false
    end
end

local function IndexPet(pets, state, entry)
    local guid = state.petGUID
    if guid and guid:match("^Pet%-.+") then Index(pets, guid, entry) end
end

local function CanJoin(player, faction)
    return player.faction == faction or player.opponent == true
end

-- Session rows summarize interactions, so keep only positive relations between
-- identified players. An owner can stand in for a pet only with a matching GUID.
local function ParticipantLinks(contacts, petOwners, categories, faction)
    local byGUID, byName, byPet = {}, {}, {}
    for guid, contact in pairs(contacts) do
        local player = contact.latest
        if player and player.guid == guid and player.isPlayer == true and guid:match("^Player%-.+")
            and (player.faction == "Alliance" or player.faction == "Horde") then
            local name = ContactName(player)
            if name and player.class then
                local entry = { guid = guid, name = name, player = player }
                byGUID[guid] = entry
                Index(byName, name .. "\0" .. player.class, entry)
                IndexPet(byPet, player, entry)
                for _, state in ipairs(contact.changes or {}) do IndexPet(byPet, state, entry) end
            end
        end
    end

    for pet, owners in pairs(petOwners) do
        for owner in pairs(owners) do
            Index(byPet, pet, byGUID[owner] or false)
        end
    end

    local edges = {}
    local function AddLinks(category, sameFaction, sourceFaction)
        local data = categories[category]
        for _, source in ipairs(data and data.sources or {}) do
            local actor = byGUID[source.sourceGUID] or byPet[source.sourceGUID]
            if actor and CanJoin(actor.player, faction)
                and (not sourceFaction or actor.player.faction == sourceFaction) then
                for _, spell in ipairs(source.spells or {}) do
                    local detail = spell.target
                    if detail and detail.isMob == false and detail.isPet == false
                        and type(detail.amount) == "number" and detail.amount > 0
                        and type(detail.unitName) == "string" and detail.unitName ~= ""
                        and type(detail.unitClassFilename) == "string" then
                        local other = byName[detail.unitName .. "\0" .. detail.unitClassFilename]
                        if other and other ~= actor and CanJoin(other.player, faction)
                            and (sameFaction == nil or (actor.player.faction == other.player.faction) == sameFaction) then
                            edges[#edges + 1] = { actor, other }
                        end
                    end
                end
            end
        end
    end

    -- The source is the victim in the taken categories and the actor otherwise.
    AddLinks("DamageTaken", false, faction)
    AddLinks("EnemyDamageTaken", false, faction == "Alliance" and "Horde" or "Alliance")
    AddLinks("DamageDone", false)
    AddLinks("Interrupts", false)
    AddLinks("HealingDone", true)
    AddLinks("Absorbs", true)
    AddLinks("Dispels")
    return edges
end

-- Anchors are GUIDs supplied by the caller. Links themselves have no dependency
-- on journal entries or killing blows.
function addon.ConnectedMeterParticipants(anchors, contacts, petOwners, categories, faction)
    local edges = ParticipantLinks(contacts, petOwners, categories, faction)
    local reached, additions = {}, {}
    for guid in pairs(anchors) do reached[guid] = true end
    local previousCount
    repeat
        previousCount = #additions
        for _, edge in ipairs(edges) do
            local left, right = edge[1], edge[2]
            if reached[left.guid] ~= reached[right.guid] then
                local nextPlayer = reached[left.guid] and right or left
                reached[nextPlayer.guid] = true
                additions[#additions + 1] = nextPlayer
            end
        end
    until #additions == previousCount
    return additions
end
