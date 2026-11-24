local _, addon = ...

function addon.CombatContactName(unit)
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

local support = { HealingDone = true, Absorbs = true }
local crossFaction = { DamageTaken = true, EnemyDamageTaken = true, DamageDone = true, Interrupts = true }
local timedDamage = { DamageDone = true, DamageTaken = true, EnemyDamageTaken = true }
local targetFields = { "unitName", "unitClassFilename", "isMob", "isPet", "amount" }
local Evidence = {}

function addon.NewMeterParticipantEvidence(contacts, petOwners, faction, localID)
    local evidence = setmetatable({
        player = {}, names = {}, pet = {}, links = {}, damage = {}, contributions = {}, contacts = contacts, faction = faction,
        localID = localID,
    }, { __index = Evidence })
    for guid, contact in pairs(contacts) do
        local player = contact.latest
        if player and player.guid == guid and player.isPlayer == true
            and (player.faction == "Alliance" or player.faction == "Horde") then
            local name = addon.CombatContactName(player)
            if name then
                local entry = { guid = guid, name = name, player = player }
                evidence.player[guid] = entry
                if player.class then Index(evidence.names, name .. "\0" .. player.class, entry) end
            end
        end
    end
    for pet, owners in pairs(petOwners) do
        for owner in pairs(owners) do Index(evidence.pet, pet, owner) end
    end
    return evidence
end

function Evidence:Source(category, source)
    local guid = source.sourceGUID
    if type(guid) ~= "string" then return nil, "source-guid-" .. (source.status.sourceGUID or "absent") end
    if guid == "" then return nil, "source-guid-empty" end
    local actor = self.player[guid]
    if guid:match("^Pet%-.+") then
        local owner = self.pet[guid]
        if owner == false then return nil, "pet-owner-ambiguous" end
        if not owner then return nil, "pet-owner-unresolved" end
        actor = self.player[owner]
        if not actor then return nil, "pet-owner-contact-unusable" end
    elseif not guid:match("^Player%-.+") then
        return nil, "non-player-source"
    elseif not actor then
        local contact = self.contacts[guid]
        if not contact then return nil, "source-contact-missing" end
        local status = contact.latest and contact.latest.status
        if status and (status.isPlayer == "secret" or status.name == "secret" or status.faction == "secret") then
            return nil, "source-contact-secret"
        end
        return nil, "source-contact-incomplete"
    end
    local friendly = actor.player.faction == self.faction
    if (not friendly and actor.player.opponent ~= true)
        or (category == "DamageTaken" and not friendly)
        or (category == "EnemyDamageTaken" and friendly) then return nil, "source-side-unverified" end
    return actor
end

-- The source is the affected unit in the taken categories. Links are
-- undirected, and repeated spells between the same two players cost one edge.
function Evidence:Link(category, actor, detail, accept, petSource)
    if detail.status.row ~= "readable" then return "detail-" .. detail.status.row end
    if category == "DamageTaken" and not accept and not petSource and actor.guid == self.localID then
        local npcDamage = detail.isMob == true and detail.isPet == false and type(detail.amount) == "number"
            and detail.amount > 0 and detail.amount < math.huge
        self.localNpcDamage = self.localNpcDamage == true or npcDamage
    end
    for _, key in ipairs(targetFields) do
        if detail.status[key] == "secret" then return "target-" .. key .. "-secret" end
    end
    if type(detail.unitName) ~= "string" or detail.unitName == "" then return "target-name-missing" end
    if detail.isMob == true or detail.isPet == true then return "target-not-player" end
    if detail.isMob ~= false or detail.isPet ~= false then return "target-kind-unknown" end
    if type(detail.amount) ~= "number" or not (detail.amount > 0 and detail.amount < math.huge) then
        return "target-amount-missing-or-zero"
    end
    if type(detail.unitClassFilename) ~= "string" or detail.unitClassFilename == "" then return "target-class-missing" end
    local other = self.names[detail.unitName .. "\0" .. detail.unitClassFilename]
    if other == false then return "target-contact-ambiguous" end
    if not other then return "target-contact-missing" end
    if other == actor then return "self-action", other end
    if other.player.faction ~= self.faction and other.player.opponent ~= true then return "target-side-unverified", other end
    local sameSide = actor.player.faction == other.player.faction
    if (support[category] and not sameSide) or (crossFaction[category] and sameSide) then return "unexpected-faction", other end
    if accept and not accept(actor, other) then return "duration-link-unconfirmed", other end
    self.links[actor] = self.links[actor] or {}
    self.links[other] = self.links[other] or {}
    self.links[actor][other], self.links[other][actor] = true, true
    local from, to = actor.guid, other.guid
    local taken = category == "DamageTaken" or category == "EnemyDamageTaken"
    if taken then from, to = to, from end
    local pairKey = from .. ":" .. to
    if timedDamage[category] then
        local totals = self.damage[category] or {}
        self.damage[category] = totals
        local pair = totals[pairKey] or { actorID = from, targetID = to, amount = 0 }
        totals[pairKey] = pair
        pair.amount = pair.amount + detail.amount
    end
    local endpoint = petSource and (taken and "target" or "actor") or nil
    local key = category .. ":" .. pairKey .. ":" .. (endpoint or "")
    self.contributions[key] = { category = category, actorID = from, targetID = to,
        petEndpoint = endpoint, corroborated = accept ~= nil or nil }
    return "link", other
end

-- Anchors are GUIDs supplied by the caller. The graph does not depend on kills.
function Evidence:Connected(anchors)
    local reached, queue, additions = {}, {}, {}
    for guid in pairs(anchors) do
        local entry = self.player[guid]
        if entry then
            reached[entry] = true
            queue[#queue + 1] = entry
        end
    end
    local index = 1
    while index <= #queue do
        local entry = queue[index]
        for other in pairs(self.links[entry] or {}) do
            if not reached[other] then
                reached[other] = true
                queue[#queue + 1] = other
                additions[#additions + 1] = other
            end
        end
        index = index + 1
    end
    table.sort(additions, function(a, b) return a.guid < b.guid end)
    return additions, reached
end

-- These are untimed links from the selected meter aggregate, not events.
function Evidence:HostileLinks(reached)
    local result = {}
    for player in pairs(reached) do
        if player.player.faction == self.faction then
            for rival in pairs(self.links[player] or {}) do
                if rival.player.faction ~= self.faction then
                    result[#result + 1] = { allyID = player.guid, opponentID = rival.guid }
                end
            end
        end
    end
    table.sort(result, function(a, b)
        if a.allyID == b.allyID then return a.opponentID < b.opponentID end
        return a.allyID < b.allyID
    end)
    return result
end


-- Take every accepted pair in the connected component before the bounded
-- diagnostic probe can drop rows. The keys make the persisted order stable.
function Evidence:ContributionLinks(reached)
    local keys, result = {}, {}
    for key, link in pairs(self.contributions) do
        if reached[self.player[link.actorID]] and reached[self.player[link.targetID]] then keys[#keys + 1] = key end
    end
    table.sort(keys)
    for _, key in ipairs(keys) do result[#result + 1] = self.contributions[key] end
    return result
end
