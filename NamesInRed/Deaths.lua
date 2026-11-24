local _, addon = ...
local Readable = addon.Readable
local sequence = 0

function addon.CancelPendingDeath()
    sequence = sequence + 1
end

local function ReadTable(value)
    value = Readable(value)
    if type(value) == "table" and (not canaccesstable or canaccesstable(value)) then
        return value
    end
end

local function IsHostilePlayer(row)
    local flags = Readable(row.sourceFlags)
    return type(flags) == "number" and bit and bit.band(flags, 0x440) == 0x440
end

local function HostilePlayer(row, playerGUID)
    local guid = Readable(row.sourceGUID)
    if type(guid) == "string" and guid:match("^Player%-.+") and guid ~= playerGUID and IsHostilePlayer(row) then
        return guid
    end
end

local function CollectRecapDamage(hit, rival, stamp, hits)
    local amount, time = Readable(hit.amount), Readable(hit.timestamp)
    if type(time) == "number" and time > 0 and time <= stamp and type(amount) == "number"
        and amount > 0 and amount < math.huge and addon.Ledger.IsDeathRecapDamage(Readable(hit.event)) then
        hits[rival] = math.max(hits[rival] or time, time)
    end
end

local function ScopeKey(row)
    local number = addon.SkirmishDeathEvidence.IsNumber
    if number(row.session) and number(row.combatSequence) then
        return row.session .. ":" .. row.combatSequence
    end
end

local function IndexLegacyRecaps(diagnostics)
    local windows = {}
    for _, row in ipairs(diagnostics.rows) do
        local key = type(row) == "table"
            and (row.kind == "PLAYER_DEAD" or row.kind == "RECAP" or row.kind == "COMBAT_END") and ScopeKey(row)
        if key then
            local window = windows[key] or { deaths = {}, ends = {} }
            windows[key] = window
            if row.kind == "COMBAT_END" then
                window.ends[#window.ends + 1] = row
            elseif addon.SkirmishDeathEvidence.IsNumber(row.deathSequence) then
                local group = window.deaths[row.deathSequence] or { reads = {} }
                window.deaths[row.deathSequence] = group
                if row.kind == "PLAYER_DEAD" then
                    group.signal = group.signal == nil and row or false
                else
                    group.reads[#group.reads + 1] = row
                end
            end
        end
    end
    return windows
end

local function MatchesScope(battle, row)
    local battleground = battle.origin == "battleground"
    return row.instanceType == (battleground and "pvp" or "none")
        and (not battleground or (battle.instanceMapID and row.instanceMapID == battle.instanceMapID))
        and type(battle.zone) == "string" and row.zone == battle.zone
end

local function MatchLegacyDeath(battle, event, deaths, expectedUptime)
    local number = addon.SkirmishDeathEvidence.IsNumber
    local selected
    for _, group in pairs(deaths) do
        local row = group.signal
        local player = row and row.player
        if player and player.guid == event.targetID and player.dead ~= false and row.time == event.time
            and number(row.uptime) and math.abs(row.uptime - expectedUptime) <= 1 and MatchesScope(battle, row) then
            if selected then return end
            selected = group
        end
    end
    return selected
end

local function RestorePetOwner(battle, window, snapshot, source)
    local matched
    for _, row in ipairs(window.ends) do
        if row.time == snapshot.time and row.uptime == snapshot.uptime and MatchesScope(battle, row) then
            if matched then return end
            matched = row
        end
    end
    if not matched or not matched.petOwners or not addon.UniqueCombatPetOwner then return end
    local owner = addon.UniqueCombatPetOwner(matched.petOwners[source])
    local contact = owner and matched.contacts and matched.contacts[owner]
    local known = contact and contact.latest
    if known and known.guid == owner and known.isPlayer == true and known.opponent == true then return owner end
end

local function RestorePetRecap(battle, event, group)
    local evidence = addon.SkirmishDeathEvidence
    local signal = group.signal
    local pet, damage
    for _, row in ipairs(group.reads) do
        local first = row.status and row.status.events == "readable" and row.events and row.events[1]
        if first and first.status and first.status.row == "readable" and evidence.IsNumber(row.uptime)
            and row.uptime >= signal.uptime and row.uptime - signal.uptime <= 3 and MatchesScope(battle, row)
            and evidence.IsNumber(first.timestamp) and math.abs(first.timestamp - event.time) <= 3
            and evidence.IsNumber(first.overkill) and first.overkill >= 0 then
            local confirmed = evidence.PetFinisher(first)
            if not confirmed then
                if HostilePlayer(first, event.targetID) or evidence.IsCreatureSource(first.sourceGUID)
                    or first.event == "ENVIRONMENTAL_DAMAGE" then return end
            elseif not pet or (confirmed.timestamp == pet.timestamp and confirmed.sourceID == pet.sourceID) then
                pet, damage = pet or confirmed, damage or {}
                for i = 2, #row.events do
                    local hit = row.events[i]
                    local rival = hit.status and hit.status.row == "readable" and HostilePlayer(hit, event.targetID)
                    if rival then CollectRecapDamage(hit, rival, pet.timestamp, damage) end
                end
            else
                return
            end
        end
    end
    if pet then
        return { targetID = event.targetID, time = event.time, offset = event.offset, petFinisher = pet,
            recapTimestamp = pet.timestamp, recapDamage = damage }
    end
end

-- Restore only retained pet recaps with a unique combat and local-death
-- match. Keep the evidence beside the raw event and never create a death.
function addon.RestoreLegacyPetRecaps(skirmishes, diagnostics)
    if type(diagnostics) ~= "table" or diagnostics.version ~= 1 or type(diagnostics.rows) ~= "table" then return end
    local evidence, windows = addon.SkirmishDeathEvidence, IndexLegacyRecaps(diagnostics)
    if not next(windows) then return end
    local matches, claims, changed = {}, {}, {}
    for _, battle in pairs(skirmishes) do
        if type(battle) == "table" and type(battle.events) == "table" and type(battle.allies) == "table" and not battle.manual then
            local me
            for _, ally in ipairs(battle.allies) do if ally.isSelf then me = ally.id; break end end
            local segments
            for index, event in ipairs(battle.events) do
                if me and event.targetID == me and event.kind == "death" and evidence.IsLocalDeathSignal(event.source)
                    and not event.recapTimestamp and not event.nonPvPLethal and event.pvpLinked ~= false then
                    segments = segments or evidence.Segments(battle)
                    local phase = evidence.LegacyDeathWindow(segments, event)
                    local snapshot = phase and phase.evidence.reportMeter
                    local key = snapshot and ScopeKey(snapshot)
                    local window = key and windows[key]
                    local group = window and evidence.IsNumber(snapshot.uptime)
                        and MatchLegacyDeath(battle, event, window.deaths, snapshot.uptime + event.offset - phase.finish)
                    if group then
                        local proof = RestorePetRecap(battle, event, group)
                        if proof then
                            proof.petFinisher.ownerID = RestorePetOwner(battle, window, snapshot, proof.petFinisher.sourceID)
                            local stamp = proof.recapTimestamp
                            claims[stamp] = claims[stamp] == nil and true or false
                            matches[#matches + 1] = { battle = battle, index = index, event = event, proof = proof }
                        end
                    end
                end
            end
        end
    end
    for _, match in ipairs(matches) do
        local battle = match.battle
        if claims[match.proof.recapTimestamp] and not evidence.EventRecap(battle, match.event, match.index) then
            battle.recoveredDeathRecaps = battle.recoveredDeathRecaps or {}
            battle.recoveredDeathRecaps[match.index] = match.proof
            changed[battle] = true
        end
    end
    return changed
end

local function NoteRecap(death, status, cause)
    local context = death.context
    if addon.NoteWorldDeathRecap and context.worldWindow then
        addon.NoteWorldDeathRecap(context.worldWindow, context.killUptime, status, cause)
    end
end

local function Record(death)
    if death.sequence ~= sequence then return end
    if not C_DeathRecap or not C_DeathRecap.GetRecapEvents then
        return NoteRecap(death, "unavailable")
    end
    local ok, rows = pcall(C_DeathRecap.GetRecapEvents)
    rows = ok and ReadTable(rows)
    local first = rows and ReadTable(rows[1])
    if not first then
        return NoteRecap(death, "unreadable")
    end

    local stamp = Readable(first.timestamp)
    local overkill = Readable(first.overkill)
    local previous = addon.db.lastDeathTimestamp
    local repeatRecap = type(previous) == "number" and stamp == previous
    if type(stamp) ~= "number" or not (stamp > 0 and stamp < math.huge) or math.abs(stamp - death.observedAt) > 3
        or (type(previous) == "number" and stamp < previous)
        or (repeatRecap and not death.context.worldWindow)
        or type(overkill) ~= "number" or not (overkill >= 0 and overkill < math.huge) then
        return NoteRecap(death, "stale-or-unverified-lethal")
    end

    local playerGUID = Readable(UnitGUID("player"))
    local source = Readable(first.sourceGUID)
    local guid = HostilePlayer(first, playerGUID)
    local name = Readable(first.sourceName)
    local window = death.context.worldWindow
    local pet = window and addon.SkirmishDeathEvidence.PetFinisher(first)
    local unknownFinisher = pet ~= nil or (not guid and source == nil and IsHostilePlayer(first) and window ~= nil)
    local effect = Readable(first.event)
    local cause = effect == "ENVIRONMENTAL_DAMAGE" and "environment"
        or (addon.SkirmishDeathEvidence and addon.SkirmishDeathEvidence.IsCreatureSource(source) and "npc")
    if not guid and cause then
        if repeatRecap then return NoteRecap(death, "duplicate-non-pvp") end
        NoteRecap(death, "non-pvp-lethal", cause)
        addon.db.lastDeathTimestamp = stamp
        return true
    end
    if not guid and not unknownFinisher then
        if addon.NotePvPDiagnostic then addon.NotePvPDiagnostic("recap-finisher-unverified") end
        return NoteRecap(death, "finisher-unverified")
    end

    local observed = guid and death.units[guid]
    local cached = guid and death.cached[guid]
    if cached and (not observed or not observed.level) then
        observed = observed or {}
        observed.level = cached
    end
    local attackers, seen, recapDamage = {}, {}, {}
    if pet and addon.CombatRecapPetOwner then
        local owner, appearance = addon.CombatRecapPetOwner(window, pet.sourceID)
        if owner and owner ~= playerGUID then
            pet.ownerID = owner
            attackers[1] = { guid = owner, name = addon.CombatContactName(appearance), appearance = appearance }
            seen[owner] = true
        end
    end
    if guid then
        attackers[1] = { guid = guid, name = observed and observed.fullName or addon.ManualName(name), appearance = observed }
        seen[guid] = true
    end
    for index = 2, #rows do
        local row = ReadTable(rows[index])
        local attackerGUID = row and HostilePlayer(row, playerGUID)
        local amount = row and Readable(row.amount)
        if attackerGUID then CollectRecapDamage(row, attackerGUID, stamp, recapDamage) end
        if attackerGUID and not seen[attackerGUID] and type(amount) == "number" and amount > 0 then
            local unit = death.units[attackerGUID]
            attackers[#attackers + 1] = {
                guid = attackerGUID,
                name = unit and unit.fullName or addon.ManualName(Readable(row.sourceName)),
                appearance = unit,
            }
            seen[attackerGUID] = true
        end
    end

    death.context.time = math.floor(stamp)
    death.context.deathTimestamp = stamp
    death.context.rivalLevel = observed and observed.level
    death.context.rivalAppearance = observed
    death.context.attackers = attackers
    death.context.recapDamage = recapDamage
    death.context.petFinisher = pet
    death.context.unknownFinisher = unknownFinisher
    death.context.repeatRecap = repeatRecap
    local id, battle, status = addon.RecordWorldEncounter(guid, observed and observed.fullName or name, "deathsToThem", death.context)
    if addon.WorldDeathWindow and not id and status ~= "duplicate" then return end
    if unknownFinisher then
        -- Advance the native watermark even without a player actor. An exact
        -- repeat in the bound record can still refine this death on retry.
        if id then addon.db.lastDeathTimestamp = stamp end
        return
    end
    if id and battle and addon.RecordCombatDeathRecap then
        -- Reuse the same recap read. Earlier entries need a readable clock
        -- inside the matched skirmish, and the lethal entry is retained last.
        for index = math.min(#rows, 8), 2, -1 do
            local row = ReadTable(rows[index])
            local time = row and Readable(row.timestamp)
            if type(time) == "number" and type(battle.startedAt) == "number"
                and time >= battle.startedAt and time <= stamp then
                local actor = HostilePlayer(row, playerGUID)
                if actor then addon.RecordCombatDeathRecap(battle, actor, playerGUID, row, index, stamp) end
            end
        end
        addon.RecordCombatDeathRecap(battle, guid, playerGUID, first)
    end
    addon.db.lastDeathTimestamp = stamp
    if addon.NotePvPDiagnostic and not death.context.rivalLevel then addon.NotePvPDiagnostic("recap-level-unavailable") end
    return true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_DEAD")
frame:SetScript("OnEvent", function()
    sequence = sequence + 1
    if not addon.db then
        return
    end
    if not addon.RecordingPvPOrigin() then
        return
    end
    local context = addon.EncounterContext()
    if type(context.time) ~= "number" then
        return
    end
    if addon.WorldDeathWindow then
        context.killUptime = GetTime()
        context.worldWindow = addon.WorldDeathWindow(context)
        if not context.worldWindow then return end
    end
    local death = { sequence = sequence, context = context, observedAt = context.time, units = {},
        cached = addon.ActiveCombatContacts and addon.ActiveCombatContacts() or {} }
    local function Snapshot(unit)
        local guid = Readable(UnitGUID(unit))
        if type(guid) == "string" and guid:match("^Player%-.+") then
            local observed = death.units[guid] or {}
            local name = addon.UnitPlayerName(unit)
            if addon.HasFullName(name) then observed.fullName = name end
            local appearance = addon.UnitAppearance(unit)
            if Readable(UnitGUID(unit)) ~= guid then return end
            for key, value in pairs(appearance) do
                if observed[key] == nil then observed[key] = value end
            end
            death.units[guid] = observed
        end
    end
    Snapshot("target")
    Snapshot("mouseover")
    addon.VisitVisibleNameplateUnits(Snapshot)
    if Record(death) then
        return
    end
    context.delayedAssociation = true
    local recorded
    for _, delay in ipairs({ 0.3, 1, 2 }) do
        C_Timer.After(delay, function()
            if not recorded then
                recorded = Record(death)
            end
        end)
    end
end)
