local addonName, addon = ...
local L = addon.L
local issuesURL = "https://github.com/nick-sidorin/names-in-red/issues/new?template=bug_report.md"
local maxBytes, maxRows = 24576, 520
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

local function MakeWriter()
    local lines, size, truncated = { "```jsonl" }, 9, {}
    local function Write(section, fields)
        fields.section = section
        local line = Object(fields)
        -- Reserve the footer even if every section reaches its cap.
        if size + #line + 1 > maxBytes - 1024 or #lines >= maxRows then
            truncated[section] = true
            return
        end
        lines[#lines + 1], size = line, size + #line + 1
    end
    local function Each(section, collection, limit, visit)
        for index, item in ipairs(Table(collection)) do
            if index > limit then
                truncated[section] = true
                break
            end
            visit(Table(item), index)
        end
    end
    local function Finish()
        local names = {}
        for section in pairs(truncated) do names[#names + 1] = section end
        table.sort(names)
        lines[#lines + 1] = Object({ section = "limits", truncatedSections = table.concat(names, ",") })
        lines[#lines + 1] = "```"
        return table.concat(lines, "\n")
    end
    return Write, Each, Finish, truncated
end

local meterCategories = { "DamageDone", "DamageTaken", "EnemyDamageTaken", "HealingDone", "Absorbs", "Interrupts", "Dispels", "Deaths" }

-- Store a small allowlisted summary alongside the exact combat-end row identity.
-- The linked row can be retained or evicted independently of the saved battle.
function addon.ReportMeterSnapshot(row)
    local status = Table(row.status)
    local snapshot = Fields(row, "meterSelection", "session combatSequence time uptime meterSessionID meterAttempts meterRestrictionWaits meterUpdateCount contactCount contactOverflow restrictedPartyKills",
        "meterReset areaChanged")
    snapshot.status, snapshot.window = Token(status.meter), Token(status.meterWindow)
    snapshot.categories = {}
    for _, category in ipairs(meterCategories) do
        local meter = Table(Table(row.meter)[category])
        local details = Fields(Table(meter.status), "session sources")
        details.evidence = Token(Table(row.meterEvidence)[category])
        details.counts = {}
        local count = 0
        for key, value in pairs(Table(meter.resolution)) do
            key, value = Token(key), Number(value)
            if key and value then
                count = count + 1
                if count <= 48 then details.counts[key] = value end
            end
        end
        details.truncated = count > 48 or nil
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

function addon.BuildIssueReport(db, debugDB, battleID, legacy)
    local write, each, finish, truncated = MakeWriter()
    local version, build, interface = Read(GetBuildInfo)
    local metadata = C_AddOns and C_AddOns.GetAddOnMetadata
    local journal = Table(db)
    local battle = battleID and Table(journal.skirmishes)[battleID]
    if legacy and not battleID then battle, battleID = LegacyBattle(journal, legacy) end
    local requested = battleID ~= nil or legacy ~= nil
    write("report", { schema = "names-in-red-issue", version = 1, scope = requested and "skirmish" or "general",
        addonVersion = Token(Read(metadata, addonName, "Version")), clientVersion = Token(version),
        build = Token(build) or Number(build), interface = Number(interface), locale = Token(Read(GetLocale)),
        damageMeterAPI = type(C_DamageMeter) == "table" })
    local _, instance = Read(IsInInstance)
    write("currentContext", { instanceType = Token(instance), zone = Zone(Read(GetRealZoneText)) })
    battle = Table(battle)
    if not next(battle) then
        if requested then write("record", { availability = "missing" }) end
        return finish()
    end

    local aliases, roster, selfID, aliasCount = {}, {}, nil, 0
    local function Alias(value)
        value = addon.Readable(value)
        if type(value) ~= "string" or value == "" then return end
        if not aliases[value] then
            if aliasCount >= 256 then truncated.participant = true; return end
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
    local outcome = Token(battle.outcome) or Token(resolution.outcome)
    local reason = Token(resolution.reason)
    if not outcome and Flag(battle.rosterComplete) == true and not next(Table(battle.observation))
        and not next(resolution) then
        -- Ledger can infer a result on older, complete rosters. Invalid historical
        -- data must not prevent the rest of the sanitized report from opening.
        local ok, inferred = pcall(addon.Ledger.SkirmishOutcome, battle)
        if ok then outcome = Token(inferred) end
    end
    if outcome ~= "win" and outcome ~= "loss" then outcome = "unknown" end
    local record = Fields(battle, nil, "sequence time startedAt recordedAt mapID x y instanceMapID", "rosterComplete manual")
    record.id = type(battleID) == "string" and battleID:match("^[%a]+:%d+$") and battleID or nil
    record.origin = addon.Readable(battle.origin) == "battleground" and "Battleground" or "Open World"
    record.zone, record.outcome = Zone(battle.zone), outcome
    record.dateUTC = record.time and record.time >= 0 and record.time <= 4102444800
        and Read(date, "!%Y-%m-%dT%H:%M:%SZ", record.time) or nil
    record.reason = reason or (record.manual and "manual-outcome")
        or (outcome ~= "unknown" and "legacy-recorded-or-elimination") or "unavailable"
    write("record", record)

    for _, side in ipairs({ "allies", "enemies" }) do
        each("participant", battle[side], 64, function(player)
            local id = addon.Readable(player.id)
            local fields = Fields(player, "class race faction", "level sex", "isSelf")
            fields.player, fields.side = Alias(id), side
            if fields.player then roster[#roster + 1] = id end
            if fields.isSelf then selfID = id end
            write("participant", fields)
        end)
        local counts = Fields(Table(resolution[side]), nil, "dead holding away unresolved active rangeWithdrawn")
        counts.side, counts.observed = side, #Table(battle[side])
        write("side", counts)
    end
    write("resolution", Fields(resolution, "ending reason coverage meter localLife favorsVictory favorsDefeat",
        "unitsRead positionsUnavailable statesUnavailable"))
    local kills, deaths = {}, {}
    each("event", battle.events, 128, function(event)
        local fields = Fields(event, "kind source", "time offset spellID", "observedDead")
        Actor("event", fields, event)
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
                partial = truncated.event == true })
        end
        local reward = Fields(Table(Table(battle.rewards)[id]), nil, "honorableKills honor")
        if next(reward) then
            honorableKills, honor = honorableKills + (reward.honorableKills or 0), honor + (reward.honor or 0)
            reward.player = player
            write("reward", reward)
        end
    end
    write("rewardTotal", { honorableKills = honorableKills, honor = honor, available = next(Table(battle.rewards)) ~= nil,
        partial = truncated.participant == true })

    local observation = Table(battle.observation)
    local assessment = Table(observation.assessment)
    local observationFields = Fields(observation, "coverage playerState", nil, "visibilityGap")
    observationFields.available = next(observation) ~= nil
    write("observation", observationFields)
    write("assessment", Fields(assessment, "checkStatus interrupted meterStatus", "lastMeterActivity"))
    Actor("lastHostileAction", Fields(Table(assessment.lastAction), "kind", "offset"), Table(assessment.lastAction))
    Actor("lastMeterPair", {}, Table(assessment.meterPair))
    each("localLife", observation.life, 32, function(life)
        write("localLife", Fields(life, "state source", "at offset"))
    end)
    ForKnown(assessment.pressure, function(pressure, player)
        local range = Table(pressure.range)
        write("pressure", { target = player, actor = Alias(pressure.actorID), offset = Number(pressure.offset),
            spellID = Number(range.spell), upperBound = Number(range.upper), distanceBased = Flag(range.distance) })
    end)
    for _, key in ipairs({ "first", "last" }) do
        local sample = Table(assessment[key])
        if next(sample) then
            local timing = Fields(sample, nil, "at offset")
            timing.sample = key
            write("terminalSample", timing)
            ForKnown(sample.units, function(unit, player)
                local fields = Fields(unit, nil, nil, "dead combat")
                fields.sample, fields.player = key, player
                fields.positionAvailable = next(Table(unit.position)) ~= nil
                fields.rangeExit = Flag(unit.rangeExit)
                write("terminalUnit", fields)
            end)
        end
    end

    local rows = Table(Table(debugDB).rows)
    local function Meter(section, snapshot, index)
        local fields = Fields(snapshot, "status window meterSelection",
            "meterSessionID meterAttempts meterRestrictionWaits meterUpdateCount contactCount contactOverflow restrictedPartyKills",
            "meterReset areaChanged")
        fields.segment = index
        write(section, fields)
        for _, name in ipairs(meterCategories) do
            local category = Table(Table(snapshot.categories)[name])
            if next(category) then
                local item = Fields(category, "session sources evidence", nil, "truncated")
                item.segment, item.category = index, name
                write("meterCategory", item)
                local counts = {}
                for key, value in pairs(Table(category.counts)) do
                    key, value = Token(key), Number(value)
                    if key and value then counts[key] = value end
                end
                counts.segment, counts.category = index, name
                write("meterReasons", counts)
            end
        end
    end
    each("segment", observation.segments, 24, function(segment, index)
        local fields = Fields(segment, "startReason endReason continuation confirmedBy observationStopped", "startedAt endedAt duration")
        fields.segment = index
        write("segment", fields)
        ForKnown(segment.contacts, function(contact, player)
            local item = Fields(contact, "signal", "first last", "dead inCombat")
            item.player, item.segment = player, index
            write("contact", item)
        end)
        each("action", segment.actions, 60, function(action)
            local item = Fields(action, "kind", "spellID first last count")
            item.segment = index
            Actor("action", item, action)
        end)
        local meter = Table(segment.meter)
        if next(meter) then
            local item = Fields(meter, "scope selection", "sessionID")
            item.segment = index
            write("meterEvidence", item)
            each("meterLink", meter.hostileLinks, 60, function(link)
                write("meterLink", { segment = index, ally = Alias(link.allyID), opponent = Alias(link.opponentID) })
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
            Meter("meterSnapshot", snapshot, index)
            if found then
                Meter("linkedDebug", addon.ReportMeterSnapshot(found), index)
            end
        end
        write("diagnostics", { segment = index, availability = found and "exact-combat-window"
            or (found == false and "ambiguous") or (next(snapshot) and "retained-row-unavailable")
            or (#rows > 0 and "unlinked-time-only-ambiguous") or "unavailable" })
    end)
    if #Table(observation.segments) == 0 then write("diagnostics", { availability = "no-linked-segments" }) end
    return finish()
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
    window = CreateFrame("Frame", "NamesInRedIssueReport", UIParent, "ButtonFrameTemplate")
    window:SetSize(550, 420)
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

    local instructions = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    instructions:SetPoint("TOPLEFT", 20, -38)
    instructions:SetPoint("TOPRIGHT", -20, -38)
    instructions:SetJustifyH("LEFT")
    instructions:SetWordWrap(true)
    instructions:SetText(L.issueInstructions)

    local scroll = CreateFrame("ScrollFrame", nil, window, "InputScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", instructions, "BOTTOMLEFT", 3, -13)
    scroll:SetPoint("BOTTOMRIGHT", -22, 95)
    scroll.CharCount:Hide()
    report = scroll.EditBox
    report:SetMaxLetters(0)
    report:SetMaxBytes(0)
    report:SetWidth(484)
    report:HookScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)

    local copy = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    copy:SetPoint("BOTTOMLEFT", 20, 56)
    copy:SetSize(230, 23)
    copy:SetText(L.issueSelectReport)
    copy:SetScript("OnClick", function() Select(report) end)

    local caption = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    caption:SetPoint("BOTTOMLEFT", 20, 38)
    caption:SetText(L.issueLinkLabel)
    link = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
    link:SetAutoFocus(false)
    link:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    link:SetPoint("BOTTOMLEFT", 24, 13)
    link:SetSize(501, 20)
    link:HookScript("OnEditFocusGained", function(self) self:HighlightText() end)
    CopyField(link, issuesURL)
    window:HookScript("OnHide", function() report:ClearFocus(); link:ClearFocus() end)
end

function addon.OpenIssueReport(battleID, legacy)
    if not window then BuildWindow() end
    CopyField(report, addon.BuildIssueReport(addon.db, NamesInRedDebugDB, battleID, legacy))
    report:SetCursorPosition(0)
    report:GetParent():SetVerticalScroll(0)
    window:Show()
    window:Raise()
end
