local addonName, addon = ...
local L = addon.L
local issuesURL = "https://github.com/nick-sidorin/names-in-red/issues/new?template=bug_report.md"
-- Keep room in GitHub's 65,536-character issue body for its template
-- and the player's description. A byte budget is conservative for UTF-8.
local reportBudget = 60 * 1024
local footerBudget = 1024
addon.issueBugIcon = "Interface\\HelpFrame\\HelpIcon-Bug.blp"

local function Table(value)
    value = addon.Readable(value)
    if type(value) == "table" and (not canaccesstable or canaccesstable(value)) then return value end
    return {}
end

local function Number(value)
    value = addon.Readable(value)
    if type(value) == "number" and value == value and math.abs(value) < math.huge then return value end
end

local function Token(value)
    value = addon.Readable(value)
    if type(value) == "string" and #value <= 64 and value:match("^[%w._%-]+$")
        and not value:match("^%a+%-%d+%-") then return value end
end

local function Flag(value)
    value = addon.Readable(value)
    if type(value) == "boolean" then return value end
end

local function Read(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, first, second, _, fourth = pcall(fn, ...)
    if ok then return addon.Readable(first), addon.Readable(second), addon.Readable(fourth) end
end

local function Zone(value)
    value = addon.Readable(value)
    if type(value) == "string" and #value <= 160 and not value:find("[%c|`]")
        and not value:find("%a+%-%d+%-[%w%-]+") then return value end
end

local function Quote(value)
    return '"' .. value:gsub('[%z\1-\31"\\|`]', function(char)
        return ("\\u%04x"):format(char:byte())
    end) .. '"'
end

local function Object(fields)
    local result = {}
    for key, value in pairs(fields) do
        local kind = type(value)
        local text = kind == "string" and Quote(value)
            or kind == "number" and ("%.14g"):format(value):gsub(",", ".")
            or kind == "boolean" and tostring(value)
        if text then result[#result + 1] = Quote(key) .. ": " .. text end
    end
    table.sort(result)
    return "{" .. table.concat(result, ", ") .. "}"
end

local function Fields(source, tokens, numbers, flags)
    local result = {}
    for key in (tokens or ""):gmatch("%S+") do result[key] = Token(source[key]) end
    for key in (numbers or ""):gmatch("%S+") do result[key] = Number(source[key]) end
    for key in (flags or ""):gmatch("%S+") do result[key] = Flag(source[key]) end
    return result
end

local priorities = {
    report = 1, currentContext = 1, record = 1, side = 1, personalOutcome = 1,
    rivalContribution = 1, resolution = 1, rewardTotal = 1, rewardUnassignedOpponent = 1,
    journalRewards = 1, combatCapture = 1,
    observation = 1, assessment = 1, participation = 1,
    combatAggregate = 3, meterReasons = 3, meterSpellSample = 3, primaryEvidence = 3,
    action = 4,
}

local function MakeWriter(budget)
    local queues = { {}, {}, {}, {} }
    local sizes, truncated = { 0, 0, 0, 0 }, {}
    local limit = (budget or reportBudget) - footerBudget
    local omitted = 0
    local function Omit(section)
        truncated[section], omitted = true, omitted + 1
    end
    local function Write(section, fields)
        local priority = section == "primaryEvidence" and fields.api == "C_DeathRecap" and 2 or priorities[section] or 2
        if sizes[priority] >= limit then Omit(section); return end
        fields.section = section
        local line = Object(fields)
        local queue = queues[priority]
        queue[#queue + 1] = { section = section, line = line }
        sizes[priority] = sizes[priority] + #line + 1
    end
    local function Each(collection, visit)
        for index, item in ipairs(Table(collection)) do visit(Table(item), index) end
    end
    local function Finish()
        local lines, size = { "```jsonl" }, 9
        for _, queue in ipairs(queues) do
            for _, entry in ipairs(queue) do
                local needed = #entry.line + 1
                if size + needed <= limit then
                    lines[#lines + 1], size = entry.line, size + needed
                else
                    Omit(entry.section)
                end
            end
        end
        local names = {}
        for section in pairs(truncated) do names[#names + 1] = section end
        table.sort(names)
        lines[#lines + 1] = Object({ section = "limits", truncatedSections = table.concat(names, ","),
            omittedRows = omitted, transport = budget and "editbox-capacity" or (omitted > 0 and "github-issue-budget" or nil) })
        lines[#lines + 1] = "```"
        return table.concat(lines, "\n")
    end
    return Write, Each, Finish
end

local function Reasons(input)
    local result, count = {}, 0
    for key, value in pairs(Table(input)) do
        key, value = Token(key), Number(value)
        if key and value then
            count = count + 1
            if count <= 48 then result[key] = value end
        end
    end
    return result, count > 48 or nil
end

local meterCategories = { "DamageDone", "DamageTaken", "EnemyDamageTaken", "HealingDone", "Absorbs", "Interrupts", "Dispels", "Deaths" }

-- Store a small allowlisted summary alongside the exact combat-end row identity.
-- The linked row can be retained or evicted independently of the saved battle.
function addon.ReportMeterSnapshot(row)
    local status = Table(row.status)
    local snapshot = Fields(row, "meterSelection", "session combatSequence time uptime meterSessionID meterAttempts meterRestrictionWaits meterUpdateCount contactCount contactOverflow restrictedPartyKills",
        "meterReset areaChanged")
    snapshot.status, snapshot.window = Token(status.meter), Token(status.meterWindow)
    snapshot.decisions = Reasons(row.pvpReasons)
    snapshot.categories = {}
    for _, category in ipairs(meterCategories) do
        local meter = Table(Table(row.meter)[category])
        local details = Fields(Table(meter.status), "session sources")
        details.evidence = Token(Table(row.meterEvidence)[category])
        details.counts, details.truncated = Reasons(meter.resolution)
        if next(details.counts) or details.evidence or details.session or details.sources then
            snapshot.categories[category] = details
        end
    end
    return snapshot
end

local function FindLegacy(db, ref)
    if not ref then return end
    local rival = Table(Table(db.rivals)[ref.rivalID])
    local encounters = Table(rival.encounters)
    if ref.sequence then
        for index, encounter in ipairs(encounters) do
            if addon.Readable(Table(encounter).sequence) == ref.sequence then return encounter, rival, index end
        end
    else
        local encounter = Table(encounters[ref.index])
        if next(encounter) and not encounter.sequence and encounter.time == ref.time
            and encounter.recordedAt == ref.recordedAt and encounter.direction == ref.direction
            and encounter.manual == ref.manual then return encounter, rival, ref.index end
    end
end

function addon.LegacyReportRef(rivalID, encounter, index)
    if not encounter or not rivalID then return end
    if not encounter.sequence and not index then
        local rival = addon.db and addon.db.rivals[rivalID]
        for i, row in ipairs(rival and rival.encounters or {}) do
            if row == encounter then index = i; break end
        end
    end
    return { rivalID = rivalID, sequence = encounter.sequence, index = index,
        time = encounter.time, recordedAt = encounter.recordedAt, direction = encounter.direction, manual = encounter.manual }
end

local function LegacyBattle(db, ref)
    local encounter, rival, index = FindLegacy(db, ref)
    if not encounter then return end
    encounter = Table(encounter)
    local opponent = Fields(rival, "class race", "sex")
    opponent.id, opponent.level = ref.rivalID, Number(encounter.rivalLevel)
    if Read(addon.Ledger.LegacyContribution, encounter, ref.rivalID) then opponent.rivalID = ref.rivalID end
    local manual, direction = Flag(encounter.manual), Token(encounter.direction)
    local outgoing = direction == "killsAgainstThem"
    local outcome = Token(encounter.outcome)
    if manual and (outgoing or direction == "deathsToThem") then outcome = outcome or (outgoing and "win" or "loss") end
    local events, enemies = {}, { opponent }
    if not manual and (outgoing or direction == "deathsToThem") and not encounter.outcome then
        events[1] = { kind = "kill", time = Number(encounter.time), source = "legacy-direction",
            actorID = outgoing and "legacy:local" or ref.rivalID, targetID = outgoing and ref.rivalID or "legacy:local" }
    end
    for i, actor in ipairs(Table(encounter.attackers)) do
        if i > 64 then break end
        local id = addon.Readable(Table(actor).guid)
        if id ~= ref.rivalID then enemies[#enemies + 1] = { id = id or "legacy:attacker:" .. i } end
    end
    return {
        manual = manual, time = Number(encounter.time), recordedAt = Number(encounter.recordedAt),
        zone = Zone(encounter.zone), mapID = Number(encounter.mapID), x = Number(encounter.x), y = Number(encounter.y),
        outcome = outcome, events = events, enemies = enemies, rosterComplete = false,
        allies = { { id = "legacy:local", isSelf = true, level = Number(encounter.playerLevel) } },
        rewards = { [ref.rivalID] = Fields(encounter, nil, "honorableKills honor") },
    }, "legacy:" .. tostring(Number(ref.sequence) or index)
end

local combatStreams = {
    { "unitCombat", "UNIT_COMBAT" },
    { "spellCast", "UNIT_SPELLCAST" },
    { "aura", "UNIT_AURA" },
    { "unitState", "unit-state-sample" },
    { "partyKill", "PARTY_KILL" },
}
local combatRegistration = "UNIT_COMBAT UNIT_AURA UNIT_FLAGS PARTY_KILL UNIT_SPELLCAST_START UNIT_SPELLCAST_SUCCEEDED "
    .. "UNIT_SPELLCAST_INTERRUPTED UNIT_SPELLCAST_CHANNEL_START UNIT_SPELLCAST_CHANNEL_STOP"
local primaryTokens = "effect effectStatus flag flagStatus phase castStatus signal actorStatus targetStatus interrupterStatus payloadStatus "
    .. "spellIDStatus amountStatus schoolStatus helpfulStatus harmfulStatus deadStatus inCombatStatus feignStatus "
    .. "eventTimeStatus overkillStatus absorbedStatus"
local primaryNumbers = "offset eventTime recapIndex recapTime spellID amount school overkill absorbed"
local primaryFlags = "helpful harmful dead inCombat feign"

local function CombatCoverage(journal, write)
    local coverage = Fields(journal, "retention", "version windowsDropped recapsDropped")
    if Number(journal.version) ~= 1 then
        coverage.availability = "not-recorded"
    else
        coverage.availability = "recorded"
    end
    write("combatCapture", coverage)
    return coverage.availability == "recorded"
end

local function ReportCombatDiagnostics(journal, write, each, alias)
    local function Attribution(first, second, third)
        local known = 0
        for _, value in pairs({ first, second, third }) do
            local id = addon.Readable(value)
            if type(id) == "string" then
                if not alias(id) then return end
                known = known + 1
            end
        end
        if known > 0 then return known > 1 and "roster-endpoints" or "participant-only" end
    end
    local function Primary(row, api, index)
        if row.actorStatus == "non-player" or row.targetStatus == "non-player" then return false end
        local attribution = Attribution(row.actorID, row.targetID, row.interrupterID)
        if not attribution then return false end
        local fields = Fields(row, primaryTokens, primaryNumbers, primaryFlags)
        fields.api, fields.window = api, index
        fields.evidence, fields.attribution = "observation", attribution
        fields.actor, fields.target = alias(row.actorID), alias(row.targetID)
        fields.interrupter = alias(row.interrupterID)
        write("primaryEvidence", fields)
        return true
    end
    each(journal.recaps, function(row)
        Primary(row, "C_DeathRecap")
    end)
    each(journal.windows, function(window)
        local fields = Fields(window, "ending meterStatus meterWindow meterInterruption", "time endOffset")
        fields.build = Token(window.build) or Number(window.build)
        fields.window = Number(window.index)
        write("combatWindow", fields)
        local availability = Fields(Table(window.availability), combatRegistration)
        availability.window = fields.window
        write("combatAvailability", availability)
        each(window.meterFollowups, function(row)
            local attribution = Attribution(row.actorID, row.targetID)
            local update = Fields(row, "status category localDeadStatus localGhostStatus",
                "sessionID readOffset", "localDead localGhost")
            if attribution then
                update.actor, update.target = alias(row.actorID), alias(row.targetID)
                update.amountIncrease, update.pairTotal = Number(row.amountIncrease), Number(row.pairTotal)
            end
            update.window, update.evidence, update.attribution = fields.window, "aggregate", attribution
            write("meterFollowup", update)
        end)
        if window.meterFollowupsDropped then
            write("meterFollowupCoverage", { window = fields.window, dropped = Number(window.meterFollowupsDropped) })
        end
        local meter = Table(window.meter)
        if next(meter) then
            local scope = Fields(meter, "selection", "sessionID readOffset retained dropped")
            scope.window, scope.evidence = fields.window, "aggregate"
            write("meterSampleBatch", scope)
            for _, name in ipairs(meterCategories) do
                local category = Table(Table(meter.categories)[name])
                if next(category) then
                    local omitted = 0
                    each(category.rows, function(row)
                        local attribution = Attribution(row.meterUnitID, row.otherID)
                        if not attribution or (Flag(row.isMob) and not alias(row.otherID)) then
                            omitted = omitted + 1
                            return
                        end
                        local spell = Fields(row, "resolution detailStatus spellIDStatus spellTotalStatus overkillStatus "
                            .. "sourceTotalStatus amountStatus nameStatus classStatus",
                            "spellID spellTotal amount sourceTotal overkill", "petOwner isPet isMob")
                        spell.window, spell.category = fields.window, name
                        spell.evidence, spell.attribution = "aggregate", attribution
                        spell.meterUnit, spell.other = alias(row.meterUnitID), alias(row.otherID)
                        write("meterSpellSample", spell)
                    end)
                    write("meterSampleCoverage", { window = fields.window, category = name,
                        dropped = Number(category.dropped), outsideRosterOrUnresolved = omitted })
                end
            end
        end
        for _, stream in ipairs(combatStreams) do
            local samples = Table(Table(window.streams)[stream[1]])
            if next(samples) then
                local summary = Fields(samples, nil, "dropped rateLimited duplicates")
                summary.api, summary.window = stream[2], fields.window
                summary.outsideRosterOrUnresolved = 0
                each(samples.rows, function(row)
                    if not Primary(row, stream[2], fields.window) then
                        summary.outsideRosterOrUnresolved = summary.outsideRosterOrUnresolved + 1
                    end
                end)
                write("combatStream", summary)
            end
        end
    end)
end

local function BuildIssueReport(db, debugDB, battleID, legacy, budget)
    local write, each, finish = MakeWriter(budget)
    local version, build, interface = Read(GetBuildInfo)
    local metadata = C_AddOns and C_AddOns.GetAddOnMetadata
    local journal = Table(db)
    local rows = Table(Table(debugDB).rows)
    local battle = battleID and Table(journal.skirmishes)[battleID]
    if legacy and not battleID then battle, battleID = LegacyBattle(journal, legacy) end
    local requested = battleID ~= nil or legacy ~= nil
    write("report", { schema = "names-in-red-issue", version = 1, scope = requested and "skirmish" or "general",
        addonVersion = Token(Read(metadata, addonName, "Version")), clientVersion = Token(version),
        previewRevision = addon.PreviewRevision(),
        build = Token(build) or Number(build), interface = Number(interface), locale = Token(Read(GetLocale)),
        damageMeterAPI = type(C_DamageMeter) == "table" })
    local _, instance = Read(IsInInstance)
    write("currentContext", { instanceType = Token(instance), zone = Zone(Read(GetRealZoneText)) })
    battle = Table(battle)
    if not next(battle) then
        if requested then write("record", { availability = "missing" }) end
        if not requested then
            local ok, totals = pcall(addon.Ledger.JournalRewards, journal)
            if ok then write("journalRewards", Fields(totals, nil, "honorableKills honor unassignedHK unassignedHonor")) end
            for i = #rows, 1, -1 do
                local row = Table(rows[i])
                local kind = Token(row.kind)
                if kind == "PVP_DECISION" or kind == "COMBAT_END" then
                    local fields = Reasons(row.pvpReasons)
                    local status = Table(row.status)
                    fields.reason, fields.meter, fields.meterWindow = Token(row.reason), Token(status.meter), Token(status.meterWindow)
                    fields.time, fields.context = Number(row.time), Token(row.instanceType)
                    write("recentDecision", fields)
                end
            end
            write("recentDiagnostics", { availability = #rows > 0 and "bounded-session-summary" or "unavailable" })
        end
        return finish()
    end

    local aliases, roster, selfID, aliasCount = {}, {}, nil, 0
    local rosterAliases, rivalAliases = {}, {}
    local function Alias(value)
        value = addon.Readable(value)
        if type(value) ~= "string" or value == "" then return end
        if not aliases[value] then
            aliasCount = aliasCount + 1
            aliases[value] = "Player-" .. aliasCount
        end
        return aliases[value]
    end
    local function Actor(section, fields, source)
        fields.actor = Alias(source.actorID)
        fields.target = Alias(source.targetID)
        write(section, fields)
    end
    local function ForKnown(source, visit)
        local collection = Table(source)
        for _, id in ipairs(roster) do
            local entry = Table(collection[id])
            if next(entry) then visit(entry, aliases[id]) end
        end
    end

    local resolution = Table(battle.resolution)
    local personal = Table(battle.personalOutcome)
    local outcome, qualifier = Read(addon.Ledger.JournalOutcome, battle)
    local oldOutcome = Read(addon.Ledger.EncounterOutcome, battle) or Read(addon.Ledger.SkirmishOutcome, battle)
    local scope = qualifier or (next(personal) and not Flag(battle.manual) and "personal") or "unavailable"
    local record = Fields(battle, nil, "sequence time startedAt recordedAt mapID x y instanceMapID", "rosterComplete manual")
    record.captureRevision = Token(battle.captureRevision)
    local recovery = Table(battle.recoveredContinuation)
    record.recoveredContinuationFrom = type(recovery.id) == "string" and recovery.id:match("^world:%d+$") or nil
    record.recoveredCombatGap = Number(recovery.gap)
    record.id = type(battleID) == "string" and battleID:match("^[%a]+:%d+$") and battleID or nil
    record.origin = addon.Readable(battle.origin) == "battleground" and "Battleground" or "Open World"
    record.zone, record.outcome, record.outcomeScope = Zone(battle.zone), Token(outcome) or "unknown", scope
    record.personalCombatScope = "direct-player"
    record.dateUTC = record.time and record.time >= 0 and record.time <= 4102444800
        and Read(date, "!%Y-%m-%dT%H:%M:%SZ", record.time) or nil
    record.reason = scope == "personal" and Token(personal.reason)
        or (scope == "manual" and "manual-outcome") or (scope == "legacy" and
            (Token(resolution.reason) or "legacy-recorded-or-elimination")) or (outcome == "ongoing" and "pending") or "unavailable"
    if scope ~= "manual" then
        record.legacyOutcome = Token(oldOutcome) or ((battle.outcome or next(resolution)) and "unknown") or nil
    end
    write("record", record)

    for _, side in ipairs({ "allies", "enemies" }) do
        each(battle[side], function(player)
            local id = addon.Readable(player.id)
            local fields = Fields(player, "class race faction", "level sex", "isSelf")
            fields.player, fields.side = Alias(id), side
            if fields.player then
                roster[#roster + 1] = id
                rosterAliases[id] = fields.player
                local rivalID = addon.Readable(player.rivalID)
                if side == "enemies" and type(rivalID) == "string" then rivalAliases[rivalID] = fields.player end
            end
            if fields.isSelf then selfID = id end
            write("participant", fields)
        end)
        local counts = Fields(Table(resolution[side]), nil, "dead holding away unresolved active rangeWithdrawn")
        counts.side, counts.observed = side, #Table(battle[side])
        write("side", counts)
    end
    local pov = Fields(personal, "lifecycle outcome reason coverage boundary finalizedBy", "version")
    pov.availability = scope
    local casualties = Table(personal.casualties)
    pov.friendlyDeaths, pov.enemyDeaths = Number(casualties.friendly), Number(casualties.enemy)
    write("personalOutcome", pov)

    local analysis = Table(Read(addon.AnalyzeSkirmishLives, battle))
    each(analysis.episodes, function(episode)
        local target = rosterAliases[addon.Readable(episode.targetID)]
        if not target or not episode.index then return end
        write("deathEpisode", { target = target, deathIndex = Number(episode.index), confirmed = episode.pvpDeath ~= nil,
            qualification = Token(episode.qualification), meterRejection = Token(episode.meterRejection),
            segment = Number(Table(episode.meterPhase).index) or Number(episode.rejectedSegment),
            nonPvPLethal = Token(episode.nonPvPLethal) })
    end)

    local contribution = Table(Read(addon.Ledger.SkirmishContributionEvidence, journal, battleID, battle))
    local credits = Table(contribution.credits)
    local count = #credits
    write("rivalContribution", { version = Number(contribution.version), credits = count,
        availability = scope == "manual" and "manual" or count > 0 and "confirmed-links-only"
            or (scope == "personal" and "no-confirmed-credit" or "legacy-or-unavailable") })
    each(credits, function(credit)
        local rival = rivalAliases[addon.Readable(credit.rivalID)]
        local actor = rosterAliases[addon.Readable(credit.actorID)]
        local victim = rosterAliases[addon.Readable(credit.victimID)]
        if not rival or not actor or not victim then return end
        local proof = Table(credit.evidence)
        local via = Table(proof.viaEvidence)
        local fields = Fields(proof, "kind category petEndpoint", "segmentIndex offset eventTime eventIndex")
        fields.rival, fields.actor, fields.target = rival, actor, victim
        fields.direction, fields.deathIndex = Token(credit.direction), Number(credit.deathIndex)
        fields.supported = rosterAliases[addon.Readable(proof.viaID)]
        fields.supportedEvidence = Token(via.kind)
        fields.supportedEventIndex, fields.supportedEventTime = Number(via.eventIndex), Number(via.eventTime)
        fields.supportedOffset, fields.supportedCategory = Number(via.offset), Token(via.category)
        write("rivalCredit", fields)
    end)

    local result = Fields(resolution, "ending reason interrupted coverage meter localLife favorsVictory favorsDefeat",
        "unitsRead positionsUnavailable statesUnavailable")
    result.evidence, result.scope = "derived", "legacy-side"
    write("resolution", result)
    local capture = Table(battle.combatDiagnostics)
    local captured = CombatCoverage(capture, write)
    local kills, deaths = {}, {}
    each(battle.events, function(event, index)
        local fields = Fields(event, "kind source recapStatus nonPvPLethal", "time offset spellID segmentIndex", "observedDead pvpLinked")
        fields.index = index
        local evidence = addon.SkirmishDeathEvidence
        local recap = Table(evidence and Read(evidence.EventRecap, battle, event, index))
        local pet = Table(recap.petFinisher)
        if next(pet) then
            fields.finisher, fields.finisherOwner, fields.finisherEffect = "pet", rosterAliases[addon.Readable(pet.ownerID)], Token(pet.effect)
            fields.finisherAttribution = fields.finisherOwner and "verified-player-owner" or "unknown-player"
            fields.finisherTime, fields.finisherAmount = Number(pet.timestamp), Number(pet.amount)
            fields.finisherRecovered = recap ~= event
            fields.finisherOwnerEvidence = Token(pet.ownerEvidence)
            fields.finisherOwnerAmbiguous = Flag(pet.ownerAmbiguous)
        end
        fields.evidence = "derived"
        Actor("event", fields, event)
        each(pet.ownerAttempts, function(attempt)
            local detail = Fields(attempt, "phase petToken tokenSource petBefore petAfter ownerGUID ownerToken decision", "delay")
            detail.deathIndex = index
            write("petOwnerProbe", detail)
        end)
        if fields.kind ~= "kill" or not selfID then return end
        local actor, target = Alias(event.actorID), Alias(event.targetID)
        if actor == aliases[selfID] and target then kills[target] = (kills[target] or 0) + 1 end
        if target == aliases[selfID] and actor then deaths[actor] = (deaths[actor] or 0) + 1 end
    end)
    local honorableKills, honor = 0, 0
    for _, id in ipairs(roster) do
        local player = aliases[id]
        if kills[player] or deaths[player] then
            write("personal", { player = player, killingBlows = kills[player] or 0, deaths = deaths[player] or 0,
                partial = false })
        end
        local reward = Fields(Table(Table(battle.rewards)[id]), nil, "honorableKills honor")
        if next(reward) then
            honorableKills, honor = honorableKills + (reward.honorableKills or 0), honor + (reward.honor or 0)
            reward.player = player
            write("reward", reward)
        end
    end
    local unassigned = Fields(Table(battle.unassignedRewards), nil, "honorableKills honor")
    if next(unassigned) then write("rewardUnassignedOpponent", unassigned) end
    write("rewardTotal", { honorableKills = honorableKills + (unassigned.honorableKills or 0),
        honor = honor + (unassigned.honor or 0), available = next(Table(battle.rewards)) ~= nil or next(unassigned) ~= nil,
        partial = false })

    local observation = Table(battle.observation)
    local assessment = Table(observation.assessment)
    local participation = Table(observation.participation)
    local observationFields = Fields(observation, "coverage playerState", nil, "visibilityGap")
    observationFields.available = next(observation) ~= nil
    write("observation", observationFields)
    write("assessment", Fields(assessment, "checkStatus interrupted meterStatus", "lastMeterActivity"))
    local participationFields = Fields(participation, "state boundary", "closedAt returnedAt lifeChangedAt")
    participationFields.available = next(participation) ~= nil
    write("participation", participationFields)
    Actor("lastHostileAction", Fields(Table(assessment.lastAction), "kind", "offset"), Table(assessment.lastAction))
    Actor("lastMeterPair", {}, Table(assessment.meterPair))
    each(observation.life, function(life)
        write("localLife", Fields(life, "state source", "at offset"))
    end)
    ForKnown(assessment.pressure, function(pressure, player)
        local range = Table(pressure.range)
        write("pressure", { target = player, actor = Alias(pressure.actorID), offset = Number(pressure.offset),
            spellID = Number(range.spell), upperBound = Number(range.upper), distanceBased = Flag(range.distance) })
    end)
    local function TerminalSample(source, key, sample)
        sample = Table(sample)
        if not next(sample) then return end
        local timing = Fields(sample, nil, "at offset")
        timing.source, timing.sample = source, key
        write("terminalSample", timing)
        ForKnown(sample.units, function(unit, player)
            local fields = Fields(unit, nil, nil, "dead combat")
            fields.source, fields.sample, fields.player = source, key, player
            fields.positionAvailable = next(Table(unit.position)) ~= nil
            fields.rangeExit = Flag(unit.rangeExit)
            write("terminalUnit", fields)
        end)
    end
    for _, key in ipairs({ "first", "last", "lateFirst", "lateLast" }) do
        TerminalSample("participation", key, participation[key])
        if key == "first" or key == "last" then
            TerminalSample("assessment", key, assessment[key])
        end
    end

    local function Meter(section, snapshot, index)
        local fields = Fields(snapshot, "status window meterSelection",
            "meterSessionID meterAttempts meterRestrictionWaits meterUpdateCount contactCount contactOverflow restrictedPartyKills",
            "meterReset areaChanged")
        fields.segment = index
        write(section, fields)
        local decisions = Reasons(snapshot.decisions)
        if next(decisions) then
            decisions.segment = index
            write("combatDecisions", decisions)
        end
        for _, name in ipairs(meterCategories) do
            local category = Table(Table(snapshot.categories)[name])
            if next(category) then
                local item = Fields(category, "session sources evidence", nil, "truncated")
                item.segment, item.category = index, name
                write("meterCategory", item)
                local counts = Reasons(category.counts)
                counts.segment, counts.category = index, name
                write("meterReasons", counts)
            end
        end
    end
    each(observation.segments, function(segment, index)
        local fields = Fields(segment, "startReason endReason continuation confirmedBy observationStopped",
            "startedAt endedAt duration offset", "localNpcDamage localNpcPressure outgoingLocalSurvivor rosterCaptureInterrupted")
        fields.segment = index
        write("segment", fields)
        local engaged = Table(segment.engagedAlly)
        if next(engaged) then
            local witness = Fields(engaged, nil, "targetOffset corpseOffset allyOffset")
            witness.ally, witness.opponent, witness.segment = Alias(engaged.allyID), Alias(engaged.opponentID), index
            witness.evidence = "corroborated-targeting"
            write("engagedAlly", witness)
        end
        local decisions = Reasons(segment.rejectedKills)
        if next(decisions) then
            decisions.segment = index
            write("killDecisions", decisions)
        end
        ForKnown(segment.contacts, function(contact, player)
            local item = Fields(contact, "signal deadStatus feignStatus", "first last", "dead inCombat feign")
            item.player, item.segment = player, index
            write("contact", item)
        end)
        each(segment.actions, function(action)
            local item = Fields(action, "kind", "spellID first last count")
            item.segment, item.evidence = index, "derived"
            Actor("action", item, action)
        end)
        each(segment.combatAggregates, function(aggregate)
            local item = Fields(aggregate, "category petEndpoint amountBasis", "spellID amount")
            item.segment, item.evidence, item.api = index, "aggregate", "C_DamageMeter"
            Actor("combatAggregate", item, aggregate)
        end)
        each(segment.contributionLinks, function(link)
            local item = Fields(link, "category petEndpoint amountBasis", nil, "corroborated")
            item.segment, item.evidence = index, "aggregate"
            Actor("contributionLink", item, link)
        end)
        local witnesses = Table(segment.localDeathWitnesses)
        for _, id in ipairs(roster) do
            local offset = Number(witnesses[id])
            if offset then
                write("localDeathWitness", { segment = index, player = rosterAliases[id], offset = offset })
            end
        end
        local meter = Table(segment.meter)
        if next(meter) then
            local item = Fields(meter, "scope selection", "sessionID")
            item.segment = index
            write("meterEvidence", item)
            each(meter.hostileLinks, function(link)
                write("meterLink", { segment = index, ally = Alias(link.allyID), opponent = Alias(link.opponentID),
                    evidence = "derived" })
            end)
        end
        local snapshot = Table(segment.reportMeter)
        local found
        if Number(snapshot.session) and Number(snapshot.combatSequence) and Number(snapshot.uptime) then
            for i = #rows, math.max(1, #rows - 999), -1 do
                local row = Table(rows[i])
                if Token(row.kind) == "COMBAT_END" and Number(row.session) == snapshot.session
                    and Number(row.combatSequence) == snapshot.combatSequence and Number(row.uptime) == snapshot.uptime
                    and Number(row.time) == Number(snapshot.time) then
                    if found then found = false; break end
                    found = row
                end
            end
            Meter("meterSnapshot", found and addon.ReportMeterSnapshot(found) or snapshot, index)
        end
        write("diagnostics", { segment = index, availability = found and "exact-combat-window"
            or (found == false and "ambiguous") or (next(snapshot) and "retained-row-unavailable")
            or (#rows > 0 and "unlinked-time-only-ambiguous") or "unavailable" })
    end)
    if #Table(observation.segments) == 0 then write("diagnostics", { availability = "no-linked-segments" }) end
    local function RosterAlias(id)
        id = addon.Readable(id)
        if type(id) == "string" then return rosterAliases[id] end
    end
    if captured then ReportCombatDiagnostics(capture, write, each, RosterAlias) end
    return finish()
end

function addon.BuildIssueReport(db, debugDB, battleID, legacy)
    return BuildIssueReport(db, debugDB, battleID, legacy)
end

local window, report, link
local function CopyField(box, value)
    if box.reportText == nil then
        box:HookScript("OnTextChanged", function(self, userInput)
            if userInput then self:SetText(self.reportText); self:HighlightText() end
        end)
    end
    box.reportText = value
    box:SetText(value)
    box:ClearFocus()
end

local function Select(box)
    box:SetFocus()
    box:HighlightText()
end

local function BuildWindow()
    local width = 660
    window = CreateFrame("Frame", "NamesInRedIssueReport", UIParent, "PortraitFrameTemplate")
    window:SetSize(width, 320)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetTitle(L.reportIssue)
    window.onCloseCallback = function() window:Hide(); return false end
    ButtonFrameTemplate_HidePortrait(window)
    window:Hide()
    tinsert(UISpecialFrames, window:GetName())

    local linkHint = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    linkHint:SetPoint("TOPLEFT", 20, -38)
    linkHint:SetPoint("TOPRIGHT", -20, -38)
    linkHint:SetJustifyH("LEFT")
    linkHint:SetWordWrap(true)
    linkHint:SetText(L.issueLinkHint)

    link = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
    link:SetAutoFocus(false)
    link:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    link:SetPoint("TOPLEFT", linkHint, "BOTTOMLEFT", 4, -8)
    link:SetPoint("TOPRIGHT", linkHint, "BOTTOMRIGHT", -5, -8)
    link:SetHeight(20)
    link:HookScript("OnEditFocusGained", function(self) self:HighlightText() end)
    CopyField(link, issuesURL)

    local reportHint = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    reportHint:SetPoint("TOPLEFT", link, "BOTTOMLEFT", -4, -16)
    reportHint:SetPoint("TOPRIGHT", link, "BOTTOMRIGHT", 5, -16)
    reportHint:SetJustifyH("LEFT")
    reportHint:SetWordWrap(true)
    reportHint:SetText(L.issueReportHint)

    local savedVariablesHint = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    savedVariablesHint:SetPoint("BOTTOMLEFT", 20, 17)
    savedVariablesHint:SetPoint("BOTTOMRIGHT", -20, 17)
    savedVariablesHint:SetJustifyH("LEFT")
    savedVariablesHint:SetWordWrap(true)
    savedVariablesHint:SetNonSpaceWrap(false)
    local savedVariablesPath = [[_forever_\WTF\Account\<account>\<realm>\<character>\SavedVariables\NamesInRed.lua]]
    savedVariablesHint:SetText(L.issueSavedVariablesHint:format(savedVariablesPath))

    local copy = CreateFrame("Button", nil, window, "SharedButtonSmallTemplate")
    copy:SetPoint("BOTTOMLEFT", savedVariablesHint, "TOPLEFT", 0, 10)
    copy:SetWidth(230)
    copy:SetTextToFit(L.issueSelectReport)
    copy:SetScript("OnClick", function() Select(report) end)

    local scroll = CreateFrame("ScrollFrame", nil, window, "InputScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", reportHint, "BOTTOMLEFT", 3, -12)
    scroll:SetPoint("TOPRIGHT", reportHint, "BOTTOMRIGHT", -2, -12)
    scroll:SetPoint("BOTTOMLEFT", copy, "TOPLEFT", 3, 16)
    scroll.CharCount:Hide()
    report = scroll.EditBox
    report:SetMaxLetters(0)
    report:SetMaxBytes(0)
    report:SetWidth(width - 66)
    report:HookScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)

    window:HookScript("OnHide", function() report:ClearFocus(); link:ClearFocus() end)
end

function addon.OpenIssueReport(battleID, legacy)
    if not window then BuildWindow() end
    local text = BuildIssueReport(addon.db, NamesInRedDebugDB, battleID, legacy)
    CopyField(report, text)
    local stored = report:GetText()
    if stored ~= text then
        -- Native storage can be measured without accessing the OS clipboard.
        -- Rebuild at a complete-row boundary if the widget clips the payload.
        if type(stored) == "string" and #stored > footerBudget and #stored < #text then
            text = BuildIssueReport(addon.db, NamesInRedDebugDB, battleID, legacy, #stored)
            CopyField(report, text)
        end
        if report:GetText() ~= text then
            CopyField(report, '```jsonl\n{"section": "limits", "truncatedSections": "all", "transport": "editbox-capacity"}\n```')
        end
    end
    report:SetCursorPosition(0)
    report:GetParent():SetVerticalScroll(0)
    window:Show()
    window:Raise()
end
