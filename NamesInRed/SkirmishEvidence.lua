local _, addon = ...

local function ContactName(unit)
    local name = unit.name
    if not name then return end
    if unit.surname and unit.surname ~= "" then name = name .. " " .. unit.surname end
    name = addon.ManualName(name)
    if addon.HasFullName(name) then return name end
end

-- Consume the sanitized post-combat snapshot. Unit sightings establish identity;
-- only a readable, positive combat interaction supplies a link to the fight.
function addon.ConnectedDamageParticipants(battle, contacts, damageTaken, faction)
    local byGUID, byName = {}, {}
    for guid, contact in pairs(contacts) do
        local player = contact.latest
        if player and player.guid == guid and player.isPlayer == true and guid:match("^Player%-.+")
            and (player.faction == "Alliance" or player.faction == "Horde") then
            local name = ContactName(player)
            if name and player.class then
                local entry = { guid = guid, name = name, player = player }
                byGUID[guid] = entry
                local key = name .. "\0" .. player.class
                -- The meter names attackers without GUIDs. Reject collisions.
                byName[key] = byName[key] == nil and entry or false
            end
        end
    end

    local edges = {}
    for _, source in ipairs(damageTaken.sources or {}) do
        local victim = byGUID[source.sourceGUID]
        if victim and victim.player.faction == faction then
            for _, spell in ipairs(source.spells or {}) do
                local target = spell.target
                if target and target.isMob == false and target.isPet == false
                    and type(target.amount) == "number" and target.amount > 0
                    and target.unitName and target.unitClassFilename then
                    -- In DamageTaken, the detail target names the attacker.
                    local attacker = byName[target.unitName .. "\0" .. target.unitClassFilename]
                    if attacker and attacker.player.faction ~= faction and attacker.player.opponent == true then
                        edges[#edges + 1] = { victim, attacker }
                    end
                end
            end
        end
    end

    local reached, additions = {}, {}
    for _, player in ipairs(battle.allies) do reached[player.id] = true end
    for _, player in ipairs(battle.enemies) do reached[player.id] = true end
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
