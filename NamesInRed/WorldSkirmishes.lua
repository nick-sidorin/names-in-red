local _, addon = ...
local Readable = addon.Readable
local open, tail, lastRecord
local generation, area = 0, 0
local lateEvent = 2.5
local bridgeAge = 5
local terminalSignalAge = 12

local function IsWorld()
    local _, instance = IsInInstance()
    return Readable(instance) == "none"
end

local function SamePlace(a, b)
    return type(a.zone) == "string" and a.zone == b.zone
        and (not a.mapID or not b.mapID or a.mapID == b.mapID)
end

local function PlayerGUID()
    local guid = Readable(UnitGUID("player"))
    if type(guid) == "string" and guid:match("^Player%-.+") then return guid end
end

local function Valid(window)
    return window and window.generation == generation and window.db == addon.db and not window.duel
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
    generation = generation + 1
    open, tail, lastRecord = nil, nil, nil
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

local function NewWindow(place, reason)
    local self = PlayerGUID()
    if not addon.db or not self or type(place.time) ~= "number" or type(place.zone) ~= "string" then return end
    local now = GetTime()
    return {
        db = addon.db, generation = generation, area = area, self = self, place = place, began = now,
        previous = tail and tail.record and SamePlace(tail.place, place) and tail.record or nil,
        segment = { startedAt = place.time, startReason = reason }, pairs = {},
    }
end

local function Save(record)
    if record.id and (not addon.db.skirmishes or addon.db.skirmishes[record.id] ~= record.battle) then return end
    if not record.id then
        addon.db.encounterSequence = (addon.db.encounterSequence or 0) + 1
        record.battle.sequence = addon.db.encounterSequence
        record.id = "world:" .. record.battle.sequence
    end
    addon.RecordSkirmish(record.id, record.battle)
    return record.id
end

local function Assessment(record)
    return record.battle.observation.assessment
end

local function WatchEnding(window)
    local record = window.record
    if not record or not window.ended or not (C_Timer and C_Timer.After) then return end
    local state = Assessment(record)
    local ticket = {}
    record.endingTicket = ticket
    local function Sample()
        if record.endingTicket ~= ticket or not Valid(window) or window.area ~= area
            or lastRecord ~= record or record.lastWindow ~= window or open then return end
        local place = addon.EncounterContext()
        if not SamePlace(window.place, place) then return end
        local ids = {}
        for _, side in ipairs({ record.battle.allies, record.battle.enemies }) do
            for _, player in ipairs(side) do ids[player.id] = true end
        end
        return { offset = GetTime() - record.began, at = place.time, units = addon.ReadWorldOutcomeUnits(ids) }
    end
    local first
    C_Timer.After(0.75, function() first = Sample() end)
    C_Timer.After(2.75, function()
        local last = Sample()
        if record.endingTicket ~= ticket or not Valid(window) or window.area ~= area then return end
        state.first, state.last = first, first and last
        state.checkStatus = first and last and "sampled" or "sampling-unavailable"
        Save(record)
    end)
end

local function InvalidateEnding(record)
    record.endingTicket = nil
    local state = Assessment(record)
    state.first, state.last, state.interrupted = nil, nil, nil
    state.checkStatus = "watching"
end

local function NewActivity(window, actor, target, kind)
    local record = window.record
    local state = Assessment(record)
    local known = record.battle.resolution and record.battle.resolution.ending == "observed"
    InvalidateEnding(record)
    if kind == "meter" then
        state.lastMeterActivity = GetTime() - record.began
        state.meterStatus = "linked-increase"
        state.meterPair = { actorID = actor, targetID = target }
    else
        addon.NoteWorldOutcomeAction(state, actor, target, GetTime() - record.began, kind)
    end
    if known then Save(record) end
    WatchEnding(window)
end

local function Confirm(window, opponents, basis)
    if window.record then return window.record end
    local previous = window.previous
    local bridge = previous and previous.bridge
    local record
    if bridge and window.area == area and Valid(previous.lastWindow) and opponents[bridge.opponent]
        and GetTime() - bridge.seen <= bridgeAge and SamePlace(window.place, previous.battle)
        and (not previous.id or (addon.db.skirmishes and addon.db.skirmishes[previous.id] == previous.battle)) then
        record = previous
        InvalidateEnding(record)
        record.bridge = nil
        window.segment.continuation = "observed-hostility"
    else
        local place = window.place
        record = { began = window.began, lastWindow = window, battle = {
            startedAt = place.time, time = place.time, zone = place.zone, mapID = place.mapID, x = place.x, y = place.y,
            origin = "world", rosterComplete = false, allies = {}, enemies = {}, events = {},
            observation = { segments = {}, life = {}, coverage = "local", assessment = { checkStatus = "watching" } },
        } }
        Participant(record.battle.allies, window.self, addon.UnitPlayerName("player"), place.playerLevel, nil, true,
            addon.UnitAppearance("player"))
    end
    window.previous = nil
    window.segment.confirmedBy = basis
    local observation = record.battle.observation
    observation.segments[#observation.segments + 1] = window.segment
    for _, event in ipairs(window.life or {}) do
        observation.life[#observation.life + 1] = event
        observation.playerState = event.state
    end
    if not observation.playerState and UnitIsDeadOrGhost and Readable(UnitIsDeadOrGhost("player")) == false then
        observation.playerState = "alive"
    end
    record.lastWindow = window
    window.record = record
    -- A late meter or recap can confirm an earlier window without replacing a later record.
    if window.area == area and (not lastRecord or lastRecord.began <= record.began) then lastRecord = record end
    return record
end

local function Close(window, place, reason)
    if not window or window.ended then return end
    window.ended = GetTime()
    window.segment.endedAt = place.time
    window.segment.duration = window.ended - window.began
    window.segment.endReason = reason
    WatchEnding(window)
    if window.record and (window.dirty or not window.record.id) then
        local function Flush()
            if Valid(window) and window.record and (window.dirty or not window.record.id) then
                Save(window.record)
                window.dirty = nil
            end
        end
        if C_Timer and C_Timer.After then C_Timer.After(0.5, Flush) else Flush() end
    end
end

function addon.WorldCombatWindow(started)
    if type(started) ~= "number" then return end
    -- The meter observer and journal receive the same event on separate frames.
    local function Matches(window)
        return Valid(window) and window.localStart and math.abs(window.localStart - started) <= 0.05
    end
    local first, second = Matches(open), Matches(tail)
    if first and not second then return open end
    if second and not first then return tail end
end

function addon.SnapshotWorldContacts(window, contacts)
    if not Valid(window) or not window.record then return end
    local snapshots = {}
    local battle = window.record.battle
    for _, side in ipairs({ battle.allies, battle.enemies }) do
        for _, player in ipairs(side) do
            local contact = contacts[player.id]
            local latest = contact and contact.latest
            if latest and contact.firstSeen and contact.lastSeen then
                snapshots[player.id] = {
                    first = contact.firstSeen - window.began, last = contact.lastSeen - window.began,
                    signal = latest.reason, inCombat = latest.inCombat, dead = latest.dead,
                }
            end
        end
    end
    window.segment.contacts = snapshots
end

local function Present(side, guid)
    for _, participant in ipairs(side) do
        if participant.id == guid then return true end
    end
end

local function LateWindow(place)
    if Valid(tail) and tail.ended and GetTime() - tail.ended <= lateEvent and SamePlace(tail.place, place) then
        return tail
    end
end

function addon.WorldDeathWindow(place)
    if not IsWorld() then return end
    if Valid(open) and SamePlace(open.place, place) then return open end
    local window = LateWindow(place)
    if window then return window end
    window = NewWindow(place, "death")
    if not window then return end
    if Readable(InCombatLockdown()) == true then
        open = window
    else
        tail = window
        Close(window, place, "standalone-event")
    end
    return window
end

function addon.WorldCanObserveMeter(window)
    return Valid(window) and window.area == area and not open and window.ended and window.record
        and lastRecord == window.record and lastRecord.lastWindow == window
        and SamePlace(window.place, addon.EncounterContext())
end

function addon.WorldMeterObservation(window, status, actor, target)
    if not addon.WorldCanObserveMeter(window) then return end
    local record = window.record
    Assessment(record).meterStatus = status
    if not actor or not target then
        if record.battle.resolution then record.battle.resolution.meter = status end
        return
    end
    local battle = record.battle
    local enemy = Present(battle.enemies, actor) and actor or (Present(battle.enemies, target) and target)
    local ally = Present(battle.allies, actor) and actor or (Present(battle.allies, target) and target)
    if not enemy or not ally then return end
    record.bridge = { opponent = enemy, seen = GetTime() }
    NewActivity(window, actor, target, "meter")
end

local function LinkedWindow(guid, actor, context)
    local record = lastRecord
    local window = record and record.lastWindow
    local bridge = record and record.bridge
    if Valid(window) and window.area == area and bridge and GetTime() - bridge.seen <= bridgeAge
        and SamePlace(window.place, context) and Present(record.battle.allies, actor)
        and Present(record.battle.enemies, guid) then return window end
end

function addon.ObservedWorldOpponent(guid, context, actor)
    local window = open or LinkedWindow(guid, actor, context) or LateWindow(context)
    local battle = Valid(window) and SamePlace(window.place, context) and window.record and window.record.battle
    for _, opponent in ipairs(battle and battle.enemies or {}) do
        if opponent.id == guid then return opponent end
    end
end

function addon.WorldMeterContext(window, row)
    if not Valid(window) or window.area ~= area or not window.ended or not SamePlace(window.place, row)
        or row.instanceType ~= "none" or not row.player or row.player.guid ~= window.self then return end
    local faction = row.player.faction
    if faction ~= "Alliance" and faction ~= "Horde" then return end
    local anchors = { [window.self] = true }
    local battle = window.record and window.record.battle
    if battle then
        for _, player in ipairs(battle.allies) do anchors[player.id] = true end
        for _, player in ipairs(battle.enemies) do anchors[player.id] = true end
    end
    return window, anchors, faction
end

function addon.ApplyWorldMeterEvidence(window, additions, faction, row, links)
    if not Valid(window) or window.area ~= area then return end
    local enemies = {}
    for _, entry in ipairs(additions) do
        if entry.player.faction ~= faction and entry.player.pvp ~= false then enemies[entry.guid] = true end
    end
    if not window.record and not next(enemies) then return end
    local record = Confirm(window, enemies, "meter")
    local battle = record.battle
    local segment = window.segment
    segment.meter = { scope = "aggregate", selection = row.meterSelection, hostileLinks = links }
    if row.meterSessionID then segment.meter.sessionID = row.meterSessionID end
    battle.time = math.max(battle.time, row.time or battle.time)
    for _, entry in ipairs(additions) do
        local player = entry.player
        local friendly = player.faction == faction
        Participant(friendly and battle.allies or battle.enemies, entry.guid, entry.name, player.level,
            not friendly and entry.guid or nil, nil, {
                race = player.race and player.race:lower(), raceLabel = player.raceName,
                sex = player.sex, class = player.class, classLabel = player.className,
            })
    end
    local state = Assessment(record)
    if not state.first and not state.last then WatchEnding(window) end
    Save(record)
    window.dirty = nil
end

local function TimelinePair(window, actor, target, kind, spell)
    local key = actor .. ":" .. target .. ":" .. kind
    local pairs = window.pairs
    local item = pairs[key]
    local offset = GetTime() - window.began
    if item then
        item.last, item.count = offset, item.count + 1
    else
        item = { actorID = actor, targetID = target, kind = kind, spellID = spell, first = offset, last = offset, count = 1 }
        pairs[key] = item
        local actions = window.segment.actions or {}
        window.segment.actions = actions
        actions[#actions + 1] = item
    end
end

function addon.RecordWorldEncounter(guid, name, direction, context)
    if not context.worldWindow and not IsWorld() then return end
    local window = context.worldWindow or open or LinkedWindow(guid, context.actorID, context)
    if not window then
        local candidate = LateWindow(context)
        if candidate and (not candidate.record or Present(candidate.record.battle.enemies, guid)) then window = candidate end
    end
    if not Valid(window) or not SamePlace(window.place, context) then
        if context.worldWindow then return end
        window = NewWindow(context, "confirmed-kill")
        if not window then return end
        if Readable(InCombatLockdown()) == true then
            open = window
        else
            tail = window
            Close(window, context, "standalone-event")
        end
    end
    local record = Confirm(window, { [guid] = true }, "kill")
    local battle = record.battle
    if not battle.mapID and context.mapID then battle.mapID, battle.x, battle.y = context.mapID, context.x, context.y end
    battle.time = math.max(battle.time, context.time or 0)
    Participant(battle.allies, window.self, addon.UnitPlayerName("player"), context.playerLevel, nil, true,
        addon.UnitAppearance("player"))
    Participant(battle.enemies, guid, name, context.rivalLevel, guid, nil, context.rivalAppearance)
    local actorID, targetID
    if direction == "killsAgainstThem" then
        actorID, targetID = context.actorID or window.self, guid
        if actorID ~= window.self then
            Participant(battle.allies, actorID, context.actorName, context.actorLevel, nil, nil, context.actorAppearance)
        end
    else
        actorID, targetID = guid, window.self
        for _, attacker in ipairs(context.attackers or {}) do
            local appearance = attacker.appearance
            Participant(battle.enemies, attacker.guid, attacker.name, appearance and appearance.level,
                attacker.guid, nil, appearance)
        end
    end
    local event = { kind = "kill", actorID = actorID, targetID = targetID, time = context.time }
    local index = #battle.events + 1
    while index > 1 and event.time and battle.events[index - 1].time
        and event.time < battle.events[index - 1].time do index = index - 1 end
    table.insert(battle.events, index, event)
    window.segment.lastConfirmedAt = context.time
    window.dirty = nil
    NewActivity(window, actorID, targetID, "kill")
    return Save(record), battle
end

local function AuraPlayer(unit, playerGUID)
    if type(unit) ~= "string" then return end
    local guid = Readable(UnitGUID(unit))
    if type(guid) ~= "string" then return end
    if Readable(UnitIsPlayer(unit)) == true and guid:match("^Player%-.+") then return guid, unit end
    if guid:match("^Pet%-.+") and Readable(UnitGUID("pet")) == guid then return playerGUID, "player" end
end

local function OpenTable(value)
    value = Readable(value)
    if type(value) == "table" and (not canaccesstable or canaccesstable(value)) then return value end
end

local function ObserveHarmfulAura(targetUnit, aura)
    if Readable(aura.isHarmful) ~= true then return end
    local self = PlayerGUID()
    if not self then return end
    local actor, source = AuraPlayer(Readable(aura.sourceUnit), self)
    local target, affected = AuraPlayer(targetUnit, self)
    if not actor or not target or actor == target then return end
    local faction = addon.PlayerFaction()
    local from, to = Readable(UnitFactionGroup(source)), Readable(UnitFactionGroup(affected))
    if (faction ~= "Alliance" and faction ~= "Horde") or (from ~= "Alliance" and from ~= "Horde")
        or (to ~= "Alliance" and to ~= "Horde") or from == to then return end
    local friendly, hostile, ally, enemy = target, actor, affected, source
    if from == faction then friendly, hostile, ally, enemy = actor, target, source, affected end
    local window = open
    local record = Valid(window) and window.record
    local previous = lastRecord
    local latest = previous and previous.lastWindow
    -- A witnessed action between known opponents can bridge a pause even
    -- while the dead player cannot use UnitCanAttack on either participant.
    if friendly ~= self and not record then
        if not Valid(latest) or not latest.ended
            or not Present(previous.battle.allies, friendly) or not Present(previous.battle.enemies, hostile) then return end
        local place = addon.EncounterContext()
        if not SamePlace(latest.place, place) then return end
        local now = GetTime()
        local coveredThrough = previous.bridge and previous.bridge.seen or latest.ended
        if now - coveredThrough > bridgeAge then return end
        previous.bridge = { opponent = hostile, seen = now }
        TimelinePair(latest, actor, target, "harmful-aura", Readable(aura.spellId))
        latest.segment.lastConfirmedAt = place.time
        NewActivity(latest, actor, target, "harmful-aura")
        return
    end
    if (not record or not Present(record.battle.enemies, hostile))
        and (Readable(UnitCanAttack("player", enemy)) ~= true
            or (UnitIsPVP and Readable(UnitIsPVP(enemy)) == false)) then return end
    local place = addon.EncounterContext()
    if not Valid(window) or not SamePlace(window.place, place) then
        if friendly ~= self then return end
        window = NewWindow(place, "harmful-aura")
        if not window then return end
        open = window
        -- An aura may arrive before PLAYER_REGEN_DISABLED.
        local function CloseUnpaired()
            if open == window and not window.localStart then
                if Readable(InCombatLockdown()) == true then return end
                open, tail = nil, window
                Close(window, addon.EncounterContext(), "local-observation-ended")
            end
        end
        if C_Timer and C_Timer.After then C_Timer.After(0.5, CloseUnpaired) end
    end
    if friendly ~= self and not Present(record.battle.enemies, hostile) then return end
    record = Confirm(window, { [hostile] = true }, "harmful-aura")
    local battle = record.battle
    Participant(battle.allies, friendly, addon.UnitPlayerName(ally), nil, nil, friendly == self, addon.UnitAppearance(ally))
    Participant(battle.enemies, hostile, addon.UnitPlayerName(enemy), nil, hostile, nil, addon.UnitAppearance(enemy))
    TimelinePair(window, actor, target, "harmful-aura", Readable(aura.spellId))
    window.segment.lastConfirmedAt = place.time
    window.dirty = true
    battle.time = math.max(battle.time, place.time or 0)
    NewActivity(window, actor, target, "harmful-aura")
end

local handlers = {}

function handlers.UNIT_AURA(unit, update)
    unit, update = Readable(unit), OpenTable(update)
    if type(unit) ~= "string" or not addon.db or not update or not IsWorld() then return end
    local full = update.isFullUpdate
    if (issecretvalue and issecretvalue(full)) or full == true then return end
    local additions = OpenTable(update.addedAuras)
    if not additions then return end
    for index = 1, #additions do
        local aura = OpenTable(additions[index])
        if aura then ObserveHarmfulAura(unit, aura) end
    end
end

function handlers.UNIT_FLAGS(unit)
    unit = Readable(unit)
    local record = lastRecord
    local window = record and record.lastWindow
    if type(unit) ~= "string" or not window or open
        or (record.battle.resolution and record.battle.resolution.ending == "observed") then return end
    local state = Assessment(record)
    local recent = math.max(state.lastAction and state.lastAction.offset or 0, state.lastMeterActivity or 0)
    if (not state.lastAction and not state.lastMeterActivity)
        or GetTime() - record.began - recent > terminalSignalAge then return end
    local guid = Readable(UnitGUID(unit))
    if type(guid) ~= "string" or (not Present(record.battle.allies, guid) and not Present(record.battle.enemies, guid))
        or not addon.WorldCanObserveMeter(window) then return end

    local current = addon.ReadWorldOutcomeState(unit)
    if not current or current.dead == nil or current.combat == nil then return end
    record.flags = record.flags or {}
    local previous = record.flags[guid] or (state.last and state.last.units[guid])
    if previous and previous.dead == current.dead and previous.combat == current.combat then return end
    record.flags[guid] = current
    WatchEnding(window)
end

function handlers.PLAYER_REGEN_DISABLED()
    if not IsWorld() then return end
    local place = addon.EncounterContext()
    if Valid(open) and not open.localStart and open.segment.startReason == "harmful-aura" and SamePlace(open.place, place) then
        open.segment.localCombatAt = place.time
        open.localStart = GetTime()
        return
    end
    if open then
        tail = open
        Close(open, place, "next-local-combat")
    end
    open = NewWindow(place, "local-combat")
    if open then open.localStart = open.began end
end

function handlers.PLAYER_REGEN_ENABLED()
    if not open then return end
    tail, open = open, nil
    Close(tail, addon.EncounterContext(), "local-combat-ended")
end

local function Life(kind)
    if not IsWorld() then return end
    local place = addon.EncounterContext()
    local window = kind == "dead" and addon.WorldDeathWindow(place) or (open or tail)
    if not Valid(window) then return end
    if not SamePlace(window.place, place) then return end
    local record = window.record
    local life = record and record.battle.observation.life or window.life or {}
    if life[#life] and life[#life].state == kind then return end
    life[#life + 1] = { state = kind, at = place.time, offset = GetTime() - (record and record.began or window.began) }
    if record then
        record.battle.observation.playerState = kind
        if record.battle.resolution then record.battle.resolution.localLife = kind end
    else
        window.life = life
    end
end

function handlers.PLAYER_DEAD() Life("dead") end
function handlers.PLAYER_ALIVE()
    if UnitIsGhost and Readable(UnitIsGhost("player")) == true then Life("ghost") end
end
function handlers.PLAYER_UNGHOST()
    Life("alive")
end

local function Leave(reason)
    local window = open or tail
    if Valid(window) then
        Close(window, addon.EncounterContext(), reason)
        if window.record then
            local record = window.record
            local state = Assessment(record)
            if not (record.battle.resolution and record.battle.resolution.ending == "observed") then
                state.interrupted = reason
                record.battle.observation.visibilityGap = true
            end
            window.segment.observationStopped = reason
            Save(record)
        end
    end
    area = area + 1
    open, tail, lastRecord = nil, nil, nil
end

function handlers.ZONE_CHANGED_NEW_AREA()
    local window = open or tail
    if Valid(window) and not SamePlace(window.place, addon.EncounterContext()) then Leave("area-changed") end
end
function handlers.PLAYER_LEAVING_WORLD() Leave("left-world") end
function handlers.PLAYER_LOGOUT() Leave("logout") end

function handlers.DUEL_FINISHED()
    local window = open or LateWindow(addon.EncounterContext())
    if window and (not window.record or not window.record.id) then window.duel = true end
end

local frame = CreateFrame("Frame")
for event in pairs(handlers) do pcall(frame.RegisterEvent, frame, event) end
frame:SetScript("OnEvent", function(_, event, ...) handlers[event](...) end)
