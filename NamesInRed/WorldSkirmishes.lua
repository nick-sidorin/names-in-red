local _, addon = ...
local Readable = addon.Readable
local active
local aftermath = 8

local function CurrentBattle(context, now)
    if not active then return end
    local battle = active.battle
    if battle.mapID and context.mapID and battle.mapID ~= context.mapID then return end
    if battle.zone and context.zone and battle.zone ~= context.zone then return end
    if (active.combatEnded or Readable(InCombatLockdown()) ~= true)
        and now - (active.combatEnded or active.lastEvent) > aftermath then return end
    return battle
end

function addon.ObservedWorldOpponent(guid, context)
    local battle = CurrentBattle(context, GetTime())
    for _, opponent in ipairs(battle and battle.enemies or {}) do
        if opponent.id == guid then return opponent end
    end
end

function addon.WorldAllyUnit(guid)
    if type(guid) ~= "string" or not guid:match("^Player%-.+") then return end
    if Readable(UnitGUID("player")) == guid then return "player" end
    local raid = IsInRaid and Readable(IsInRaid()) == true
    local count = raid and GetNumGroupMembers or GetNumSubgroupMembers
    count = count and Readable(count()) or 0
    local prefix = raid and "raid" or "party"
    for index = 1, count do
        local unit = prefix .. index
        if Readable(UnitGUID(unit)) == guid then return unit end
    end
end

function addon.ResetWorldTracking()
    active = nil
end

local appearanceFields = { "race", "raceLabel", "sex", "class", "classLabel" }

local function Participant(side, guid, name, level, rivalID, isSelf, appearance)
    local participant
    for _, player in ipairs(side) do
        if player.id == guid then
            participant = player
            break
        end
    end
    if not participant then
        participant = { id = guid, rivalID = rivalID, isSelf = isSelf }
        side[#side + 1] = participant
    end
    participant.name = addon.HasFullName(name) and name or participant.name or name
    participant.level = level or participant.level
    if appearance then
        for _, key in ipairs(appearanceFields) do
            participant[key] = appearance[key] or participant[key]
        end
    end
end

function addon.EnrichWorldSkirmish(row, startTime, startUptime, damageTaken)
    if not active or not addon.db or not addon.db.skirmishes or addon.db.skirmishes[active.id] ~= active.battle
        or row.instanceType ~= "none" or type(row.zone) ~= "string" or not active.battle.startedAt
        or active.battle.startedAt < startTime or active.lastEvent < startUptime or active.lastEvent > row.uptime
        or active.battle.zone ~= row.zone then return end
    local battle = active.battle
    local localPlayer = row.player
    local faction = localPlayer and localPlayer.faction
    if not battle.allies[1].isSelf or not localPlayer or battle.allies[1].id ~= localPlayer.guid
        or (faction ~= "Alliance" and faction ~= "Horde") then return end
    local additions = addon.ConnectedDamageParticipants(battle, row.contacts, damageTaken, faction)
    if #additions == 0 then return end
    for _, entry in ipairs(additions) do
        local player = entry.player
        local friendly = player.faction == faction
        local side = friendly and battle.allies or battle.enemies
        local rivalID = not friendly and entry.guid or nil
        Participant(side, entry.guid, entry.name, player.level, rivalID, nil, {
            race = player.race and player.race:lower(), raceLabel = player.raceName,
            sex = player.sex, class = player.class, classLabel = player.className,
        })
    end
    addon.RecordSkirmish(active.id, battle)
end

function addon.RecordWorldEncounter(guid, name, direction, context)
    local playerGUID = Readable(UnitGUID("player"))
    if type(playerGUID) ~= "string" then return end
    local now = GetTime()
    if not CurrentBattle(context, now) then
        local db = addon.db
        db.encounterSequence = (db.encounterSequence or 0) + 1
        local id = "world:" .. db.encounterSequence
        active = { id = id, battle = {
            startedAt = context.time, sequence = db.encounterSequence,
            zone = context.zone, mapID = context.mapID, x = context.x, y = context.y,
            rosterComplete = false, allies = {}, enemies = {}, events = {},
        } }
    end
    active.lastEvent = now
    local battle = active.battle
    if not battle.mapID and context.mapID then
        battle.mapID, battle.x, battle.y = context.mapID, context.x, context.y
    end
    battle.time = math.max(battle.time or 0, context.time or 0)
    Participant(battle.allies, playerGUID, addon.UnitPlayerName("player"), context.playerLevel, nil, true,
        addon.UnitAppearance("player"))
    Participant(battle.enemies, guid, name, context.rivalLevel, guid, nil, context.rivalAppearance)
    local actorID, targetID
    if direction == "killsAgainstThem" then
        actorID, targetID = context.actorID or playerGUID, guid
        if actorID ~= playerGUID then
            Participant(battle.allies, actorID, context.actorName, context.actorLevel, nil, nil,
                context.actorAppearance)
        end
    else
        actorID, targetID = guid, playerGUID
        for _, attacker in ipairs(context.attackers or {}) do
            local appearance = attacker.appearance
            Participant(battle.enemies, attacker.guid, attacker.name, appearance and appearance.level,
                attacker.guid, nil, appearance)
        end
    end
    local event = { kind = "kill", actorID = actorID, targetID = targetID, time = context.time }
    -- A delayed local death recap can arrive after a subsequently observed kill.
    local index = #battle.events + 1
    while index > 1 and event.time and battle.events[index - 1].time
        and event.time < battle.events[index - 1].time do
        index = index - 1
    end
    table.insert(battle.events, index, event)
    addon.RecordSkirmish(active.id, battle)
    return active.id, battle
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_UNGHOST")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" and active then
        active.combatEnded = GetTime()
    elseif event == "PLAYER_REGEN_DISABLED" and active then
        if GetTime() - (active.combatEnded or active.lastEvent) <= aftermath then
            active.combatEnded = nil
        else
            addon.ResetWorldTracking()
        end
    elseif event == "PLAYER_UNGHOST" or event == "PLAYER_LEAVING_WORLD" then
        addon.ResetWorldTracking()
    end
end)
