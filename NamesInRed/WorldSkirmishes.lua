local _, addon = ...
local Readable = addon.Readable
local Ledger = addon.Ledger
local open, tail, lastRecord
local spiritHealerInRange
local generation, area = 0, 0
local lateEvent = 2.5
local bridgeAge = 5
local continuationWait = 12
local terminalSignalAge = continuationWait
local lifeSettle = 0.5

local Origin = addon.RecordingPvPOrigin

local function SameScope(a, b)
    local origin = a.origin or "world"
    return origin == (b.origin or "world")
        and (origin == "world" or not a.instanceMapID or not b.instanceMapID or a.instanceMapID == b.instanceMapID)
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
    if addon.CancelPendingWorldKills then addon.CancelPendingWorldKills() end
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
        previous = lastRecord and SameScope(lastRecord.battle, place) and lastRecord or nil,
        segment = { startedAt = place.time, startReason = reason }, pairs = {},
    }
end

local function Save(record)
    if record.id and (not addon.db.skirmishes or addon.db.skirmishes[record.id] ~= record.battle) then return end
    if not record.id then
        addon.db.encounterSequence = (addon.db.encounterSequence or 0) + 1
        record.battle.sequence = addon.db.encounterSequence
        local prefix = record.battle.origin == "battleground" and "bg:" or "world:"
        record.id = prefix .. record.battle.sequence
    end
    addon.RecordSkirmish(record.id, record.battle)
    return record.id
end

local function InsertEvent(battle, event)
    local index = #battle.events + 1
    while index > 1 and Ledger.LaterBattleEvent(battle.events[index - 1], event) do index = index - 1 end
    table.insert(battle.events, index, event)
end

local function SpiritReturnBoundary(window, record)
    if not window or window.place.origin ~= "battleground" then return end
    local states = record and record.battle.observation.life or window.life
    local last = states and states[#states]
    if not last or last.state ~= "ghost" then return end
    if spiritHealerInRange then return "battleground-spirit-respawn" end
    local bridge = record and record.bridge
    if not bridge or bridge.seen < record.began + last.offset or GetTime() - bridge.seen > bridgeAge then
        return "battleground-unlinked-return"
    end
end

local function RecordAlive(record, id, stamp, source)
    local player = record.battle.allies[1]
    if player.isSelf and player.id == id and SpiritReturnBoundary(record.lastWindow, record) then return end
    local death = Ledger.LatestParticipantLife(record.battle, id)
    if not Ledger.IndicatesDeath(death) or not Ledger.LaterBattleEvent(stamp, death) then return end
    if death.source == "party-kill" and not death.observedDead
        and type(death.offset) == "number" and stamp.offset - death.offset < lifeSettle then return end
    InsertEvent(record.battle, { kind = "revive", targetID = id, time = stamp.time, offset = stamp.offset, source = source })
    if player.isSelf and player.id == id then record.battle.observation.playerState = "alive" end
    return true
end

local function Participation(record)
    return record.battle.observation.participation
end

local function Pending(record)
    return record and Participation(record).state ~= "finalized"
end

local function SetParticipationState(record, state)
    local participation = Participation(record)
    if participation.state == state then return end
    participation.state = state
    addon.RefreshPersonalSkirmish(record.battle)
end

local function Assessment(record)
    return record.battle.observation.assessment
end

local function RecentHostility(record)
    local state = Assessment(record)
    local action = state.lastAction and state.lastAction.offset
    local meter = state.lastMeterActivity
    return (action or meter) and GetTime() - record.began - math.max(action or 0, meter or 0) <= terminalSignalAge
end

local function ObserveDeath(record, id, stamp, source)
    local life = Ledger.LatestParticipantLife(record.battle, id, stamp)
    if Ledger.IndicatesDeath(life) then
        life.observedDead = true
        return
    end
    -- A sampled corpse can precede delivery of its attributed kill.
    local latest = Ledger.LatestParticipantLife(record.battle, id)
    if latest and latest.kind == "kill" and latest.offset and latest.offset >= stamp.offset
        and latest.offset - stamp.offset <= lifeSettle then
        latest.observedDead = true
        return
    end
    InsertEvent(record.battle, { kind = "death", targetID = id, time = stamp.time, offset = stamp.offset, source = source })
    return true
end

local function CorroborateCorpse(record, id, unit, stamp)
    record.possibleCorpses = record.possibleCorpses or {}
    local prior = record.possibleCorpses[id]
    if not unit.possibleCorpse then
        record.possibleCorpses[id] = nil
    elseif not prior or stamp.offset - prior.offset > terminalSignalAge then
        record.possibleCorpses[id] = stamp
    elseif stamp.offset - prior.offset >= lifeSettle then
        return ObserveDeath(record, id, prior, "corroborated-corpse")
    end
end

local function SampleEnding(record, pressure, lifeOnly)
    local ids = {}
    for _, side in ipairs({ record.battle.allies, record.battle.enemies }) do
        for _, player in ipairs(side) do ids[player.id] = true end
    end
    return { offset = GetTime() - record.began, at = addon.EncounterContext().time,
        units = addon.ReadWorldOutcomeUnits(ids, pressure, lifeOnly) }
end

local function Finalize(record, reason, discardUnsaved)
    if not Pending(record) or not Valid(record.lastWindow) then return end
    local participation = Participation(record)
    participation.state, participation.boundary = "finalized", reason
    participation.closedAt = addon.EncounterContext().time
    record.settlement = nil
    if record.id or not discardUnsaved then Save(record) end
end

local function WatchParticipation(window)
    local record = window.record
    if not Pending(record) or not Valid(window) or not (C_Timer and C_Timer.After) then return end
    local participation = Participation(record)
    if participation.state ~= "awaiting" then return end
    local remaining = math.max(0, record.quietUntil - GetTime())
    local ticket = {}
    record.settlement = ticket
    local function Current()
        return record.settlement == ticket and Pending(record) and Valid(window) and window.area == area
            and lastRecord == record and record.lastWindow == window
    end
    local function Sample()
        if not Current() or (open and open ~= window) or not Origin()
            or not SameScope(window.place, addon.EncounterContext()) then return end
        return SampleEnding(record, nil, true)
    end
    local function SavePair(first, last)
        if not first or not last then return end
        for _, sample in ipairs({ first, last }) do
            local stamp = { time = sample.at, offset = sample.offset }
            for id, state in pairs(sample.units) do
                if id ~= window.self then CorroborateCorpse(record, id, state, stamp) end
            end
        end
        participation.first, participation.last = first, last
    end
    local early, late
    C_Timer.After(0.75, function() early = Sample() end)
    C_Timer.After(2.75, function() SavePair(early, Sample()) end)
    if remaining >= 2 then C_Timer.After(remaining - 2, function() late = Sample() end) end
    C_Timer.After(remaining, function()
        if not Current() then return end
        SavePair(late, Sample())
        Finalize(record, "quiet-timeout")
    end)
end

local function Await(window, evidenceAt)
    local record = window.record
    if not Pending(record) or not Valid(record.lastWindow) then return end
    SetParticipationState(record, "awaiting")
    if evidenceAt then
        record.quietUntil = math.max(record.quietUntil or 0, evidenceAt + continuationWait)
    end
    WatchParticipation(window)
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
        if not SameScope(window.place, place) then return end
        local sample = SampleEnding(record, state.pressure)
        if Pending(record) then
            for id, unit in pairs(sample.units) do
                if unit.dead == false and id ~= window.self then
                    RecordAlive(record, id, { time = sample.at, offset = sample.offset }, "terminal-sample")
                end
            end
        end
        return sample
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

local function NewActivity(window, actor, target, kind, spell, targetUnit, uptime)
    local record = window.record
    local state = Assessment(record)
    local known = record.battle.resolution and record.battle.resolution.ending == "observed"
    InvalidateEnding(record)
    if kind == "meter" then
        state.lastMeterActivity = GetTime() - record.began
        state.meterStatus = "linked-increase"
        state.meterPair = { actorID = actor, targetID = target }
    else
        local offset = (uptime or GetTime()) - record.began
        addon.NoteWorldOutcomeAction(state, actor, target, offset, kind, spell, targetUnit)
        if Pending(record) then
            local participation = Participation(record)
            participation.first, participation.last = nil, nil
            local localAction = actor == window.self or target == window.self
            local life = record.battle.observation.playerState
            if localAction and life == "alive" and not (kind == "kill" and target == window.self) then
                participation.returnedAt = offset
            end
            if window.ended or life == "dead" or life == "ghost" then
                Await(window, record.began + offset)
            else
                SetParticipationState(record, "active")
                record.settlement, record.quietUntil = nil, nil
            end
        end
    end
    if known then Save(record) end
    WatchEnding(window)
end

local function Confirm(window, opponents, basis)
    if window.record then return window.record end
    local previous = window.previous
    local bridge = previous and previous.bridge
    local record
    local continuing = Pending(previous) and window.area == area and not window.segment.observationStopped
        and Valid(previous.lastWindow) and previous.lastWindow.began <= window.began
        and SameScope(window.place, previous.battle)
    local linked = continuing and bridge and opponents[bridge.opponent]
        and math.abs(window.began - bridge.seen) <= bridgeAge
        and (basis ~= "meter" or bridge.seen <= (window.ended or GetTime()))
    if continuing and not linked and basis == "harmful-aura" and previous.endingContact
        and GetTime() - previous.lastWindow.ended <= bridgeAge
        and previous.battle.observation.playerState == "alive" then
        for id in pairs(opponents) do
            local contact = previous.endingContact[id]
            if contact and contact.combat == true and contact.dead == false then linked = true end
        end
    end
    if linked
        and (not previous.id or (addon.db.skirmishes and addon.db.skirmishes[previous.id] == previous.battle)) then
        record = previous
        InvalidateEnding(record)
        record.bridge, record.endingContact, record.settlement, record.quietUntil = nil, nil, nil, nil
        local participation = Participation(record)
        participation.first, participation.last = nil, nil
        SetParticipationState(record, "active")
        window.segment.continuation = "observed-hostility"
    else
        if continuing then Finalize(previous, "independent-engagement") end
        local place = window.place
        record = { began = window.began, lastWindow = window, battle = {
            startedAt = place.time, time = place.time, zone = place.zone, mapID = place.mapID, x = place.x, y = place.y,
            origin = place.origin or "world", instanceMapID = place.instanceMapID, rosterComplete = false, allies = {}, enemies = {}, events = {},
            observation = { segments = {}, life = {}, coverage = "local", assessment = { checkStatus = "watching" },
                participation = { state = "active" } },
        } }
        Participant(record.battle.allies, window.self, addon.UnitPlayerName("player"), place.playerLevel, nil, true,
            addon.UnitAppearance("player"))
    end
    window.previous = nil
    window.segment.confirmedBy = basis
    local observation = record.battle.observation
    if window.segment.observationStopped then
        observation.assessment.interrupted = window.segment.observationStopped
        observation.visibilityGap = true
    end
    window.segment.offset = window.began - record.began
    observation.segments[#observation.segments + 1] = window.segment
    for _, event in ipairs(window.life or {}) do
        local offset = event.offset + window.began - record.began
        observation.life[#observation.life + 1] = { at = event.at, offset = offset, state = event.state, source = event.source }
        observation.playerState = event.state
        if event.state == "alive" then
            RecordAlive(record, window.self, { time = event.at, offset = offset }, event.source)
        end
    end
    if not observation.playerState and UnitIsDeadOrGhost and Readable(UnitIsDeadOrGhost("player")) == false then
        observation.playerState = "alive"
    end
    record.lastWindow = window
    window.record = record
    if window.combatDiagnostic then addon.AttachCombatDiagnostics(record.battle, window.combatDiagnostic) end
    -- A late meter or recap can confirm an earlier window without replacing a later record.
    if window.area == area and (not lastRecord or lastRecord.began <= record.began) then
        lastRecord = record
        if window.ended then Await(window, window.ended) end
    else
        Participation(record).state = "finalized"
        Participation(record).boundary = window.segment.observationStopped or "superseded-window"
    end
    return record
end

local function Close(window, place, reason)
    if not window or window.ended then return end
    window.ended = GetTime()
    window.segment.endedAt = place.time
    window.segment.duration = window.ended - window.began
    window.segment.endReason = reason
    if Pending(window.record) then
        local record = window.record
        if reason == "local-combat-ended" then
            record.endingContact = SampleEnding(record).units
        end
        local life = record.battle.observation.playerState
        local preserveDeadline = record.quietUntil and (life == "dead" or life == "ghost")
        Await(window, not preserveDeadline and window.ended)
    end
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

function addon.BindCombatDiagnostics(window, capture)
    if not capture or not Valid(window) or window.area ~= area then return end
    window.combatDiagnostic = capture
    if window.record then addon.AttachCombatDiagnostics(window.record.battle, capture) end
end

function addon.SnapshotWorldContacts(window, contacts)
    if not Valid(window) or not window.record then return end
    local snapshots = {}
    local record = window.record
    local battle, changed = record.battle, false
    for _, side in ipairs({ battle.allies, battle.enemies }) do
        for _, player in ipairs(side) do
            local contact = contacts[player.id]
            local latest = contact and contact.latest
            if latest and latest.guid == player.id and contact.firstSeen and contact.lastSeen then
                if not player.level and contact.level then player.level, changed = contact.level, true end
                for _, sample in ipairs(contact.life or {}) do
                    if sample.uptime >= window.began and sample.uptime <= (window.ended or GetTime()) then
                        local stamp = { offset = sample.uptime - record.began, time = sample.time }
                        local exists = Ledger.LatestParticipantLife(battle, player.id, stamp)
                        if not exists or Ledger.LaterBattleEvent(stamp, exists) then
                            if sample.dead then
                                changed = ObserveDeath(record, player.id, stamp, sample.source) or changed
                            else
                                changed = RecordAlive(record, player.id, stamp, sample.source) or changed
                            end
                        end
                    end
                end
                snapshots[player.id] = {
                    first = contact.firstSeen - window.began, last = contact.lastSeen - window.began,
                    signal = latest.reason, inCombat = latest.inCombat, dead = latest.dead, feign = latest.feign,
                    deadStatus = latest.status and latest.status.dead, feignStatus = latest.status and latest.status.feign,
                }
            end
        end
    end
    window.segment.contacts = snapshots
    if changed then
        if record.id then Save(record) else window.dirty = true end
    end
end

local function Present(side, guid)
    for _, participant in ipairs(side) do
        if participant.id == guid then return true end
    end
end

local function LateWindow(place)
    if Valid(tail) and tail.ended and GetTime() - tail.ended <= lateEvent and SameScope(tail.place, place) then
        return tail
    end
end

function addon.HonorWorldWindow()
    local place = addon.EncounterContext()
    if Valid(open) and SameScope(open.place, place) then return open end
    return LateWindow(place)
end

function addon.WorldDeathWindow(place)
    if not Origin() then return end
    if Valid(open) and (not open.record or Pending(open.record)) and SameScope(open.place, place) then return open end
    local window = LateWindow(place)
    if window and (not window.record or Pending(window.record)) then return window end
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
    return Origin() and Valid(window) and window.area == area and not open and window.ended and Pending(window.record)
        and lastRecord == window.record and lastRecord.lastWindow == window
        and SameScope(window.place, addon.EncounterContext())
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
    NewActivity(window, actor, target, "meter")
end

local function LinkedWindow(guid, actor, context)
    local record = lastRecord
    local window = record and record.lastWindow
    if not Pending(record) or not Valid(window) or window.area ~= area or not SameScope(window.place, context)
        or not Present(record.battle.allies, actor) or not Present(record.battle.enemies, guid) then return end
    local bridge = record.bridge
    if bridge and GetTime() - bridge.seen <= bridgeAge then return window end
    -- An attributed allied finish between already linked participants can
    -- be the first readable action after a local death.
    if window.ended and actor ~= window.self and not open then return window end
end

function addon.ObservedWorldOpponent(guid, context, actor)
    local function Find(window)
        local battle = Valid(window) and SameScope(window.place, context) and window.record and window.record.battle
        for _, opponent in ipairs(battle and battle.enemies or {}) do
            if opponent.id == guid then return opponent end
        end
    end
    return Find(open) or Find(LinkedWindow(guid, actor, context) or LateWindow(context))
end

function addon.WorldMeterContext(window, row)
    local origin = Origin()
    if not Valid(window) or window.area ~= area or not window.ended or not origin
        or (window.place.origin or "world") ~= origin or not SameScope(window.place, row)
        or row.instanceType ~= (origin == "battleground" and "pvp" or "none")
        or not row.player or row.player.guid ~= window.self then return end
    local faction = row.player.faction
    if faction ~= "Alliance" and faction ~= "Horde" then return end
    local anchors, enemies = { [window.self] = true }, {}
    local battle = window.record and window.record.battle
    if battle then
        for _, player in ipairs(battle.allies) do anchors[player.id] = true end
        for _, player in ipairs(battle.enemies) do anchors[player.id], enemies[player.id] = true, true end
    end
    return window, anchors, faction, enemies
end

function addon.ApplyWorldMeterEvidence(window, additions, faction, row, links, contacts, probe)
    if not Valid(window) or window.area ~= area then return end
    local enemies = {}
    for _, entry in ipairs(additions) do
        if entry.player.faction ~= faction and entry.player.pvp ~= false then enemies[entry.guid] = true end
    end
    if not window.record and not next(enemies) then return end
    local record = Confirm(window, enemies, "meter")
    local battle = record.battle
    local segment = window.segment
    if segment.confirmedBy == "meter" and segment.continuation and battle.observation.playerState == "alive" then
        -- This fresh segment was qualified from the local anchor and a
        -- separate witnessed bridge. Store its lower bound, not a hit time.
        local participation = Participation(record)
        participation.returnedAt = math.max(participation.returnedAt or 0, segment.offset)
    end
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
    Ledger.RecordMeterAggregates(battle, segment, probe)
    addon.ResolveStagedWorldKills(window, contacts)
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
    local origin = Origin()
    local bound = context.worldWindow
    local recap = direction == "deathsToThem" and context.deathTimestamp
    if bound and not Valid(bound) then return end
    if bound and recap then origin = bound.place.origin or "world" end
    if not origin then return end
    context.origin = context.origin or origin
    if context.origin ~= origin then return end
    local candidate = open
    if candidate and candidate.record and not Pending(candidate.record) then candidate = nil end
    local linked = not bound and LinkedWindow(guid, context.actorID, context)
    local teammateKill = direction == "killsAgainstThem" and context.actorID and context.actorID ~= PlayerGUID()
    local window = bound or (teammateKill and linked) or candidate or linked
    if not window then
        local candidate = LateWindow(context)
        if candidate and (not candidate.record or Present(candidate.record.battle.enemies, guid)) then window = candidate end
    end
    if origin == "battleground" and direction == "killsAgainstThem" and context.actorID
        and context.actorID ~= PlayerGUID() then
        -- A battleground raid kill can be delivered while we are fighting
        -- elsewhere. Only actors and victims already linked to our window
        -- can extend it through a teammate's finishing blow.
        local battle = Valid(window) and window.record and window.record.battle
        if not battle or not Present(battle.allies, context.actorID) or not Present(battle.enemies, guid)
            or not SameScope(window.place, context) then return nil, nil, "unlinked" end
    end
    if not Valid(window) or not SameScope(window.place, context) then
        if context.worldWindow then return end
        local latest = lastRecord and lastRecord.lastWindow
        -- A late standalone notification for the same observed corpse
        -- supplies no evidence of a new battle or another death.
        if direction == "killsAgainstThem" and Valid(latest) and latest.area == area
            and SameScope(latest.place, context) and Readable(InCombatLockdown()) == false then
            local prior = Ledger.LatestParticipantLife(lastRecord.battle, guid)
            if prior and prior.kind == "kill" then return nil, nil, "duplicate" end
        end
        window = NewWindow(context, "confirmed-kill")
        if not window then return end
        if Readable(InCombatLockdown()) == true then
            open = window
        else
            tail = window
            Close(window, context, "standalone-event")
        end
    end
    if context.retrying and (window.area ~= area or (open and open ~= window and open.record ~= window.record)) then return end
    local record = Confirm(window, { [guid] = true }, "kill")
    local battle = record.battle
    local outgoing = direction == "killsAgainstThem"
    local actorID = outgoing and (context.actorID or window.self) or guid
    local targetID = outgoing and guid or window.self
    local event = { kind = "kill", actorID = actorID, targetID = targetID, time = context.time,
        offset = (context.killUptime or GetTime()) - record.began,
        source = outgoing and "party-kill" or "death-recap", recapTimestamp = context.deathTimestamp }
    local prior = Ledger.LatestParticipantLife(battle, targetID, event)
    if prior and prior.kind == "kill" then
        local distinctRecap = not outgoing and type(event.recapTimestamp) == "number" and type(prior.recapTimestamp) == "number"
            and event.recapTimestamp > prior.recapTimestamp
        if not distinctRecap then return nil, nil, "duplicate" end
    end
    if outgoing and (prior or context.victimUnit) then
        local state = addon.ReadWorldOutcomeUnits({ [guid] = true })[guid]
        event.observedDead = state and state.dead == true or nil
        if prior and prior.kind == "revive" and not event.observedDead then return nil, nil, "awaiting-death", window end
    end
    if not battle.mapID and context.mapID then battle.mapID, battle.x, battle.y = context.mapID, context.x, context.y end
    battle.time = math.max(battle.time, context.time or 0)
    Participant(battle.allies, window.self, addon.UnitPlayerName("player"), context.playerLevel, nil, true,
        addon.UnitAppearance("player"))
    Participant(battle.enemies, guid, name, context.rivalLevel, guid, nil, context.rivalAppearance)
    if outgoing then
        if actorID ~= window.self then
            Participant(battle.allies, actorID, context.actorName, context.actorLevel, nil, nil, context.actorAppearance)
        end
    else
        for _, attacker in ipairs(context.attackers or {}) do
            local appearance = attacker.appearance
            Participant(battle.enemies, attacker.guid, attacker.name, appearance and appearance.level,
                attacker.guid, nil, appearance)
        end
    end
    -- A directly seen corpse can acquire an attributed finishing blow
    -- when PARTY_KILL or the validated local recap follows the state change.
    for index, recorded in ipairs(battle.events) do
        if recorded == prior and recorded.kind == "death" then
            table.remove(battle.events, index)
            break
        elseif recorded.targetID == targetID and Ledger.LaterBattleEvent(recorded, event) then
            if recorded.kind == "death" then table.remove(battle.events, index) end
            break
        end
    end
    InsertEvent(battle, event)
    if not outgoing then
        -- A bounded recap retry can report the old death after the local
        -- resurrection event has already been observed.
        for _, life in ipairs(battle.observation.life) do
            if life.state == "alive" then
                RecordAlive(record, targetID, { time = life.at, offset = life.offset }, life.source)
            end
        end
    end
    window.segment.lastConfirmedAt = math.max(window.segment.lastConfirmedAt or 0, event.time or 0)
    window.dirty = nil
    local last = Assessment(record).lastAction
    if Pending(record) and record.lastWindow == window and not window.segment.observationStopped
        and (not last or last.offset <= event.offset) and not context.delayedAssociation and not context.retrying then
        NewActivity(window, actorID, targetID, "kill", context.spellID, nil, context.killUptime)
    end
    if not outgoing and not context.rivalLevel then
        local reasons = window.segment.rejectedKills or {}
        window.segment.rejectedKills = reasons
        reasons["recap-level-unavailable"] = 1
    end
    return Save(record), battle
end

function addon.StageWorldKill(guid, context, started)
    local window = addon.WorldCombatWindow(started)
    if not Valid(window) or window.area ~= area or not SameScope(window.place, context) then return end
    window.stagedKills = window.stagedKills or {}
    local existing = window.stagedKills[guid]
    if existing then
        if existing.actorID == context.actorID then return "duplicate" end
        existing.ambiguous = true
        return "ambiguous"
    end
    window.stagedKills[guid] = context
    return true
end

function addon.ResolveStagedWorldKills(window, contacts)
    if not Valid(window) or not window.record then return end
    for guid, context in pairs(window.stagedKills or {}) do
        local battle = window.record.battle
        if not context.ambiguous and (Present(battle.allies, context.actorID) or Present(battle.enemies, guid)) then
            local contact = contacts and contacts[guid]
            local latest = contact and contact.latest
            local cached = context.cachedRival or (latest and latest.guid == guid and latest.isPlayer == true
                and latest.opponent == true and latest.faction ~= addon.PlayerFaction() and latest)
            if cached then
                window.stagedKills[guid] = nil
                context.worldWindow, context.delayedAssociation = window, true
                context.rivalLevel = cached.level
                context.rivalAppearance = {
                    level = cached.level, class = cached.class, classLabel = cached.className,
                    race = cached.race and cached.race:lower(), raceLabel = cached.raceName, sex = cached.sex,
                }
                local id, _, status = addon.RecordWorldEncounter(guid, addon.CombatContactName(cached), "killsAgainstThem", context)
                local counters = window.segment.rejectedKills or {}
                window.segment.rejectedKills = counters
                local reason = id and "recovered-linked-kill" or status or "unlinked-team-kill"
                counters[reason] = (counters[reason] or 0) + 1
            end
        end
    end
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

local function NoteUnrelatedPvE(self, actor, target, sourceUnit, targetUnit)
    local window = open
    local previous = window and window.previous
    if not Pending(previous) or window.record or window.pveBoundary or not previous.lastWindow.ended then return end
    local npc
    if actor == self then npc = targetUnit elseif target == self then npc = sourceUnit end
    if not npc then return end
    local guid = Readable(UnitGUID(npc))
    if type(guid) ~= "string" or not guid:match("^Creature%-") or Readable(UnitIsPlayer(npc)) ~= false
        or Readable(UnitCanAttack("player", npc)) ~= true or Readable(UnitGUID(npc)) ~= guid then return end
    local atClose = previous.endingContact and previous.endingContact[self]
    if window.began - previous.lastWindow.ended < bridgeAge then
        local current = addon.ReadWorldOutcomeUnits({ [self] = true })[self]
        local a, b = atClose and atClose.position, current and current.position
        if not a or not b or a.map ~= b.map or (a.x - b.x)^2 + (a.y - b.y)^2 < 55^2 then return end
    end
    window.pveBoundary = true
    if C_Timer and C_Timer.After then
        C_Timer.After(lateEvent, function()
            if Valid(window) and window.area == area and not window.record and lastRecord == previous then
                local bridge = previous.bridge
                if not bridge or bridge.seen < window.began then Finalize(previous, "unrelated-pve") end
            end
        end)
    end
end

local function ObserveHarmfulAura(targetUnit, aura)
    if Readable(aura.isHarmful) ~= true then return end
    local self = PlayerGUID()
    if not self then return end
    local sourceUnit = Readable(aura.sourceUnit)
    local spell = Readable(aura.spellId)
    local actor, source = AuraPlayer(sourceUnit, self)
    local target, affected = AuraPlayer(targetUnit, self)
    if not actor or not target then
        NoteUnrelatedPvE(self, actor, target, sourceUnit, targetUnit)
        return
    end
    if actor == target then return end
    local faction = addon.PlayerFaction()
    local from, to = Readable(UnitFactionGroup(source)), Readable(UnitFactionGroup(affected))
    if (faction ~= "Alliance" and faction ~= "Horde") or (from ~= "Alliance" and from ~= "Horde")
        or (to ~= "Alliance" and to ~= "Horde") or from == to then return end
    local friendly, hostile, ally, enemy = target, actor, affected, source
    if from == faction then friendly, hostile, ally, enemy = actor, target, source, affected end
    local window = open
    if Valid(window) and window.record and not Pending(window.record) then window = nil end
    local record = Valid(window) and window.record
    local previous = lastRecord
    local latest = previous and previous.lastWindow
    -- A witnessed action between known opponents can bridge a pause even
    -- while the dead player cannot use UnitCanAttack on either participant.
    if friendly ~= self and not record then
        if not Pending(previous) or not Valid(latest) or not latest.ended
            or not Present(previous.battle.allies, friendly) or not Present(previous.battle.enemies, hostile) then return end
        local place = addon.EncounterContext()
        if not SameScope(latest.place, place) then return end
        local now = GetTime()
        local coveredThrough = previous.bridge and previous.bridge.seen or latest.ended
        if now - coveredThrough > continuationWait then return end
        previous.bridge = { opponent = hostile, seen = now }
        if not open and latest.combatDiagnostic then
            addon.ObserveCombatAuras(latest.combatDiagnostic, targetUnit, { addedAuras = { aura } })
        end
        TimelinePair(latest, actor, target, "harmful-aura", spell)
        latest.segment.lastConfirmedAt = place.time
        NewActivity(latest, actor, target, "harmful-aura")
        return
    end
    if (not record or not Present(record.battle.enemies, hostile))
        and (Readable(UnitCanAttack("player", enemy)) ~= true
            or (UnitIsPVP and Readable(UnitIsPVP(enemy)) == false)) then return end
    local place = addon.EncounterContext()
    if not Valid(window) or not SameScope(window.place, place) then
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
    TimelinePair(window, actor, target, "harmful-aura", spell)
    window.segment.lastConfirmedAt = place.time
    window.dirty = true
    battle.time = math.max(battle.time, place.time or 0)
    local directTarget = sourceUnit == "player" and targetUnit or nil
    NewActivity(window, actor, target, "harmful-aura", spell, directTarget)
end

local handlers = {}

function handlers.UNIT_AURA(unit, update)
    unit, update = Readable(unit), OpenTable(update)
    if type(unit) ~= "string" or not addon.db or not update or not Origin() then return end
    local full = update.isFullUpdate
    if (issecretvalue and issecretvalue(full)) or full == true then return end
    local additions = OpenTable(update.addedAuras)
    if not additions then return end
    for index = 1, #additions do
        local aura = OpenTable(additions[index])
        if aura then ObserveHarmfulAura(unit, aura) end
    end
end

local function ObserveParticipantLife(unit, source)
    if not Origin() then return end
    unit = Readable(unit)
    if type(unit) ~= "string" then return end
    local record = open and open.record or lastRecord
    local window = record and record.lastWindow
    if not Valid(window) or window.area ~= area or (open and open ~= window) then return end

    local id = Readable(UnitGUID(unit))
    if type(id) ~= "string" then return end
    if not Present(record.battle.allies, id) and not Present(record.battle.enemies, id) then return end
    local now = GetTime()
    local place = addon.EncounterContext()
    if not SameScope(window.place, place) then return end
    if open or (window.ended and now - window.ended <= terminalSignalAge) then
        local level = addon.ReadUnitLevel(unit)
        if level and Readable(UnitGUID(unit)) == id then
            for _, opponent in ipairs(record.battle.enemies) do
                if opponent.id == id and not opponent.level then
                    opponent.level = level
                    local reasons = window.segment.rejectedKills
                    if reasons and reasons["recap-level-unavailable"] then reasons["recap-level-recovered"] = 1 end
                    if record.id then Save(record) else window.dirty = true end
                    break
                end
            end
        end
    end
    if not Pending(record) or (not open and not RecentHostility(record)) then return end
    local observed = addon.ReadWorldOutcomeState(unit)
    if not observed or Readable(UnitGUID(unit)) ~= id then return end
    local stamp = { time = place.time, offset = now - record.began }
    local changed
    if id ~= window.self then changed = CorroborateCorpse(record, id, observed, stamp) end
    if observed.dead then
        local life = Ledger.LatestParticipantLife(record.battle, id)
        if life and not Ledger.LaterBattleEvent(stamp, life) then return end
        changed = ObserveDeath(record, id, stamp, source)
    elseif observed.dead == false then
        changed = RecordAlive(record, id, stamp, source)
    end
    if not changed then return end
    local participation = Participation(record)
    if id ~= window.self then
        participation.lifeChangedAt = stamp.offset
        participation.first, participation.last = nil, nil
        WatchParticipation(window)
    end
    InvalidateEnding(record)
    Save(record)
    WatchEnding(window)
end

function handlers.NAME_PLATE_UNIT_ADDED(unit) ObserveParticipantLife(unit, "nameplate-sighting") end
function handlers.NAME_PLATE_UNIT_REMOVED(unit) ObserveParticipantLife(unit, "nameplate-removed") end
function handlers.PLAYER_TARGET_CHANGED() ObserveParticipantLife("target", "target-sighting") end
function handlers.UPDATE_MOUSEOVER_UNIT() ObserveParticipantLife("mouseover", "mouseover-sighting") end

function handlers.UNIT_FLAGS(unit)
    ObserveParticipantLife(unit, "unit-flags")
    unit = Readable(unit)
    local record = lastRecord
    local window = record and record.lastWindow
    if type(unit) ~= "string" or not window or open
        or (record.battle.resolution and record.battle.resolution.ending == "observed") then return end
    if not RecentHostility(record) then return end
    local state = Assessment(record)
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
    if not Origin() then return end
    local place = addon.EncounterContext()
    if Valid(open) and not open.localStart and open.segment.startReason == "harmful-aura" and SameScope(open.place, place) then
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

local function Life(kind, source)
    if not Origin() then return end
    local place = addon.EncounterContext()
    local window = kind == "dead" and addon.WorldDeathWindow(place) or open or tail
    if not Valid(window) or (window.record and not Pending(window.record)) then return end
    if not SameScope(window.place, place) then return end
    local record = window.record
    local life = record and record.battle.observation.life or window.life or {}
    if life[#life] and life[#life].state == kind then return end
    local offset = GetTime() - (record and record.began or window.began)
    life[#life + 1] = { state = kind, at = place.time, offset = offset, source = source }
    if record then
        record.battle.observation.playerState = kind
        if record.battle.resolution then record.battle.resolution.localLife = kind end
        if kind == "dead" then
            Await(window, GetTime())
        end
        if kind == "alive" and Pending(record) and RecordAlive(record, window.self, { time = place.time, offset = offset }, source) then
            local resolved = record.battle.resolution and record.battle.resolution.ending == "observed"
            if not resolved then InvalidateEnding(record) end
            Save(record)
            if not resolved then WatchEnding(window) end
        end
    else
        window.life = life
    end
end

function handlers.PLAYER_DEAD() Life("dead", "player-dead") end
local Leave

local function LocalAlive(source)
    if not UnitIsDeadOrGhost or Readable(UnitIsDeadOrGhost("player")) ~= false then return end
    if Origin() == "battleground" then
        local window = open or tail
        local record = Valid(window) and window.record
        local boundary = SpiritReturnBoundary(window, record)
        if boundary then
            -- The next local fight starts with fresh evidence after a respawn.
            Leave(boundary)
            spiritHealerInRange = nil
            return
        end
        spiritHealerInRange = nil
    end
    Life("alive", source)
end
function handlers.PLAYER_ALIVE()
    if UnitIsGhost and Readable(UnitIsGhost("player")) == true then Life("ghost", "released-spirit")
    else LocalAlive("player-alive") end
end
function handlers.PLAYER_UNGHOST()
    LocalAlive("player-unghost")
end

Leave = function(reason, discardUnsaved)
    local window = open or tail
    if Valid(window) then
        Close(window, addon.EncounterContext(), reason)
        window.segment.observationStopped = reason
        if window.record and (window.record.id or not discardUnsaved) then
            local record = window.record
            local state = Assessment(record)
            if not (record.battle.resolution and record.battle.resolution.ending == "observed") then
                state.interrupted = reason
                record.battle.observation.visibilityGap = true
            end
            if Pending(record) then Finalize(record, reason, discardUnsaved)
            elseif record.id then Save(record) end
        end
    end
    if lastRecord then Finalize(lastRecord, reason, discardUnsaved) end
    if addon.CancelPendingWorldKills then addon.CancelPendingWorldKills() end
    area = area + 1
    open, tail, lastRecord = nil, nil, nil
end

function handlers.ZONE_CHANGED_NEW_AREA()
    local window = open or tail
    if Valid(window) and (not Origin() or not SameScope(window.place, addon.EncounterContext())) then
        Leave("area-changed")
    end
end
function handlers.PLAYER_LEAVING_WORLD()
    Leave("left-world")
    addon.SetBattlegroundEnded(false)
    spiritHealerInRange = nil
end

function handlers.PVP_MATCH_ACTIVE()
    addon.SetBattlegroundEnded(false)
    spiritHealerInRange = nil
    if addon.ResetHonorTracking then addon.ResetHonorTracking() end
end

function handlers.PVP_MATCH_COMPLETE()
    local window = open or tail
    if not (window and window.place.origin == "battleground") and Origin() ~= "battleground" then return end
    Leave("battleground-match-ended")
    addon.SetBattlegroundEnded(true)
    spiritHealerInRange = nil
    if addon.CloseHonorTracking then addon.CloseHonorTracking() end
end

function handlers.AREA_SPIRIT_HEALER_IN_RANGE()
    if Origin() == "battleground" then spiritHealerInRange = true end
end
function handlers.AREA_SPIRIT_HEALER_OUT_OF_RANGE() spiritHealerInRange = nil end

function addon.OnBattlegroundTrackingChanged()
    Leave("battleground-setting-changed", true)
    addon.ResetWorldTracking()
    if addon.CancelPendingDeath then addon.CancelPendingDeath() end
    if addon.CloseHonorTracking then addon.CloseHonorTracking() end
    if addon.ResetHonorTracking then addon.ResetHonorTracking() end
    if addon.CancelDiagnosticCombat then addon.CancelDiagnosticCombat() end
end
function handlers.PLAYER_LOGOUT()
    Leave("logout")
    if addon.db and addon.RestoreCombatDiagnostics then addon.RestoreCombatDiagnostics(addon.db) end
end

function handlers.DUEL_FINISHED()
    local window = open or LateWindow(addon.EncounterContext())
    if window and (not window.record or not window.record.id) then window.duel = true end
end

local frame = CreateFrame("Frame")
for event in pairs(handlers) do pcall(frame.RegisterEvent, frame, event) end
frame:SetScript("OnEvent", function(_, event, ...) handlers[event](...) end)
