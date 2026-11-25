local addonName, addon = ...

function addon.Readable(value)
    if not issecretvalue or not issecretvalue(value) then
        return value
    end
end

local function SafeRead(fn, ...)
    if type(fn) == "function" then
        local ok, first, second = pcall(fn, ...)
        if ok then
            return addon.Readable(first), addon.Readable(second)
        end
    end
end

function addon.PreviewRevision()
    local revision = SafeRead(C_AddOns and C_AddOns.GetAddOnMetadata, addonName, "X-Preview-Revision")
    if type(revision) == "string" and #revision == 40 and revision:match("^[0-9a-f]+$") then return revision end
end

function addon.IsBattlegroundTrackingEnabled()
    return not addon.db or addon.db.trackBattlegroundSkirmishes ~= false
end

function addon.SetBattlegroundTrackingEnabled(enabled)
    if not addon.db or addon.IsBattlegroundTrackingEnabled() == enabled then return end
    local _, instanceType = SafeRead(IsInInstance)
    if instanceType == "pvp" and addon.OnBattlegroundTrackingChanged then
        addon.OnBattlegroundTrackingChanged()
    end
    addon.db.trackBattlegroundSkirmishes = enabled
end

local battlegroundEnded
function addon.SetBattlegroundEnded(ended)
    battlegroundEnded = ended
end

function addon.RecordingPvPOrigin()
    local inside, instanceType = SafeRead(IsInInstance)
    if instanceType == "none" and inside == false then return "world" end
    if instanceType ~= "pvp" or inside ~= true or battlegroundEnded or not addon.IsBattlegroundTrackingEnabled() then return end

    local states = Enum and Enum.PvPMatchState
    local state = SafeRead(C_PvP and C_PvP.GetActiveMatchState)
    if states and states.Complete ~= nil and state == states.Complete then return end
    return "battleground"
end

function addon.BattlegroundMapID()
    if type(GetInstanceInfo) ~= "function" then return end
    local ok, _, instanceType, _, _, _, _, _, mapID = pcall(GetInstanceInfo)
    mapID = addon.Readable(mapID)
    if ok and addon.Readable(instanceType) == "pvp" and type(mapID) == "number" and mapID > 0 then return mapID end
end

function addon.PlayerFaction()
    return SafeRead(UnitFactionGroup, "player")
end

function addon.ReadUnitLevel(unit)
    local effective = SafeRead(UnitEffectiveLevel, unit)
    if type(effective) == "number" and (effective > 0 or effective == -1) then return effective end
    local level = SafeRead(UnitLevel, unit)
    if type(level) == "number" and (level > 0 or level == -1) then return level end
end

function addon.UnitAppearance(unit)
    local raceLabel, race = SafeRead(UnitRace, unit)
    local classLabel, class = SafeRead(UnitClass, unit)
    local sex = SafeRead(UnitSex, unit)
    return {
        level = addon.ReadUnitLevel(unit),
        race = type(race) == "string" and race ~= "" and race:lower() or nil,
        raceLabel = raceLabel,
        sex = (sex == 2 or sex == 3) and sex or nil,
        class = type(class) == "string" and class ~= "" and class or nil,
        classLabel = classLabel,
    }
end

function addon.VisitVisibleNameplateUnits(visit)
    local plates = C_NamePlate and SafeRead(C_NamePlate.GetNamePlates)
    if type(plates) ~= "table" or (canaccesstable and not canaccesstable(plates)) then return end
    for _, plate in ipairs(plates) do
        plate = addon.Readable(plate)
        if plate and not plate:IsForbidden() then
            local token = addon.Readable(plate.unitToken)
            if type(token) == "string" and visit(token) then return end
        end
    end
end

function addon.ValidMapPosition(mapID, x, y)
    return type(mapID) == "number" and mapID > 0 and mapID < math.huge and mapID % 1 == 0
        and type(x) == "number" and type(y) == "number" and x >= 0 and x <= 1
        and y >= 0 and y <= 1 and (x ~= 0 or y ~= 0)
end

function addon.EncounterContext(unit)
    local result = {
        time = SafeRead(GetServerTime),
        playerLevel = addon.ReadUnitLevel("player"),
        rivalLevel = unit and addon.ReadUnitLevel(unit),
        zone = SafeRead(GetRealZoneText),
    }
    result.origin = addon.RecordingPvPOrigin()
    if result.origin == "battleground" then result.instanceMapID = addon.BattlegroundMapID() end
    if C_Map then
        local mapID = SafeRead(C_Map.GetBestMapForUnit, "player")
        if type(mapID) == "number" then
            local x, y = SafeRead(function()
                local position = addon.Readable(C_Map.GetPlayerMapPosition(mapID, "player"))
                if position then
                    return position:GetXY()
                end
            end)
            if addon.ValidMapPosition(mapID, x, y) then
                result.mapID, result.x, result.y = mapID, x, y
            end
        end
    end
    return result
end

function addon.RivalAppearance(guid)
    if not guid or not guid:match("^Player%-") or not GetPlayerInfoByGUID then
        return
    end
    local ok, classLabel, class, raceLabel, race, sex = pcall(GetPlayerInfoByGUID, guid)
    if not ok then return end
    class, race, sex = addon.Readable(class), addon.Readable(race), addon.Readable(sex)
    if type(race) == "string" and race ~= "" and (sex == 2 or sex == 3) then
        race = race:lower()
    else
        race, sex = nil, nil
    end
    if type(class) ~= "string" or class == "" then class = nil end
    return race, sex, class, addon.Readable(raceLabel), addon.Readable(classLabel)
end

local function NameKey(name)
    -- Keep the provisional key stable even without the client's UTF-8 comparator.
    return name:lower():gsub("Ё", "ё"):gsub("\208[\144-\175]", function(letter)
        local index = letter:byte(2) - 144
        if index < 16 then return string.char(208, 176 + index) end
        return string.char(209, 128 + index - 16)
    end)
end

local function SameFullName(a, b)
    return addon.HasFullName(a) and addon.HasFullName(b)
        and (NameKey(a) == NameKey(b) or (strcmputf8i and strcmputf8i(a, b) == 0))
end

local function GUIDRealm(guid)
    return type(guid) == "string" and guid:match("^Player%-(%d+)%-[%x]+$")
end

local function NameScope()
    if SafeRead(RegionalUniqueNamesEnabled) == true then return true end
    -- A typed name without a realm can only identify a home-realm player
    -- when the client does not confirm regional name uniqueness.
    return GUIDRealm(SafeRead(UnitGUID, "player"))
end

local function InNameScope(guid, scope)
    return guid:match("^Player%-.+") and (scope == true or (scope and GUIDRealm(guid) == scope))
end

local function MatchingRivals(db, name, scope)
    local guid, manuals = nil, {}
    for id, rival in pairs(db.rivals) do
        local provisional = id:match("^manual:")
        local confirmed = InNameScope(id, scope)
        if (provisional or confirmed) and SameFullName(name, addon.ManualName(rival.displayName)) then
            if provisional then
                manuals[#manuals + 1] = id
            elseif guid == nil then
                guid = id
            else
                guid = false
            end
        end
    end
    return guid, manuals
end

local ScanManualUnits

local function LinkManualRivals(db, guid, name, checkVisible)
    local scope = NameScope()
    if not InNameScope(guid, scope) then return end
    local confirmed, manuals = MatchingRivals(db, name, scope)
    if #manuals == 0 then return end
    local ambiguous = confirmed ~= nil and confirmed ~= guid
    if checkVisible and not ambiguous then
        local observed, multiple = ScanManualUnits(name, scope)
        ambiguous = multiple or (observed and observed.guid ~= guid)
    end
    if ambiguous then
        for _, id in ipairs(manuals) do db.rivals[id].manualIdentityAmbiguous = true end
        return
    end
    local rival
    for _, id in ipairs(manuals) do
        rival = addon.Ledger.MergeManualRival(db, id, guid) or rival
    end
    return rival
end

function addon.ReconcileManualRivals(db)
    local scope = NameScope()
    if not scope then return end
    local manuals = {}
    for id, rival in pairs(db.rivals) do
        if id:match("^manual:") then manuals[id] = rival end
    end
    for id, rival in pairs(manuals) do
        local name = addon.ManualName(rival.displayName)
        if addon.HasFullName(name) then
            local guid = MatchingRivals(db, name, scope)
            if guid then addon.Ledger.MergeManualRival(db, id, guid) end
            if guid == false then rival.manualIdentityAmbiguous = true end
        end
    end
end

local manualAppearanceFields = { "race", "raceLabel", "sex", "class", "classLabel", "faction", "factionLabel" }

local function EnrichManualRival(rival, appearance)
    if not appearance then return false end
    local changed = false
    for _, field in ipairs(manualAppearanceFields) do
        if rival[field] == nil and appearance[field] ~= nil then
            rival[field], changed = appearance[field], true
        end
    end
    if appearance.level and rival.observedLevel ~= appearance.level
        and (appearance.level ~= -1 or not rival.observedLevel) then
        rival.observedLevel, changed = appearance.level, true
    end
    return changed
end

local function UpdateRival(guid, name, appearance, manual)
    name = addon.ManualName(name)
    local fullName = addon.HasFullName(name) and name or nil
    local rival = addon.Ledger.Find(addon.db, guid)
    local linked
    if not manual and fullName and (not rival or rival.displayName ~= fullName) then
        if rival then rival.displayName = fullName end
        linked = LinkManualRivals(addon.db, guid, fullName, true)
        rival = linked or rival
    end
    if not rival then
        rival = addon.Ledger.Add(addon.db, guid, fullName)
        if not rival then return end
        if manual then rival.addedManually = true end
    end
    -- Later sightings can complete a name even when an earlier event only exposed its first part.
    if fullName then
        rival.displayName = fullName
    end
    local race, sex, class, raceLabel, classLabel = addon.RivalAppearance(guid)
    if appearance then
        if appearance.race and appearance.sex then
            race, sex = appearance.race, appearance.sex
        end
        raceLabel = appearance.raceLabel or raceLabel
        class, classLabel = appearance.class or class, appearance.classLabel or classLabel
        rival.factionLabel = appearance.factionLabel or rival.factionLabel
    end
    if race then rival.race, rival.sex = race, sex end
    if class then rival.class = class end
    if type(raceLabel) == "string" and raceLabel ~= "" then rival.raceLabel = raceLabel end
    if type(classLabel) == "string" and classLabel ~= "" then rival.classLabel = classLabel end
    if manual or linked then EnrichManualRival(rival, appearance) end
    return rival
end

local function RefreshRivals()
    if addon.RefreshBook then addon.RefreshBook() end
    if addon.RefreshNameplates then addon.RefreshNameplates() end
    if addon.RefreshUnitTooltip then addon.RefreshUnitTooltip() end
end

function addon.RecordEncounter(guid, name, direction, context, appearance)
    local rival = UpdateRival(guid, name, appearance, context.manual)
    if not rival then return end
    if context.manualIdentityAmbiguous then rival.manualIdentityAmbiguous = true end
    rival[direction] = (rival[direction] or 0) + 1
    rival.encounters = rival.encounters or {}
    context.direction = direction
    addon.db.encounterSequence = (addon.db.encounterSequence or 0) + 1
    context.sequence = addon.db.encounterSequence
    if not context.time then context.recordedAt = SafeRead(GetServerTime) end
    table.insert(rival.encounters, 1, context)
    addon.Ledger.InvalidateRivalHistory(addon.db, guid)
    RefreshRivals()
end

function addon.RecordSkirmish(id, battle)
    if not addon.Ledger.SaveSkirmish(addon.db, id, battle) then return end
    for _, opponent in ipairs(battle.enemies) do
        if type(opponent.rivalID) == "string" then
            UpdateRival(opponent.rivalID, opponent.name, opponent)
        end
    end
    RefreshRivals()
    return battle
end

function addon.ManualName(input)
    input = addon.Readable(input)
    if type(input) ~= "string" or input:find("[%c|]") then
        return nil
    end
    local name = input:gsub("\194\160", " "):match("^%s*(.-)%s*$"):gsub(" +", " ")
    if name == "" or #name > 96 then
        return nil
    end
    return name
end

function addon.HasFullName(name)
    return type(name) == "string" and name:find("%S %S") ~= nil
end

function addon.IsRosterRival(id, rival)
    return not id:match("^Player%-") or addon.HasFullName(rival.displayName)
end

local function MoreRecent(a, b)
    if a.time ~= b.time then return a.time > b.time end
    if a.sequence ~= b.sequence then return a.sequence > b.sequence end
    if a.id ~= b.id then return a.id < b.id end
    return a.index < b.index
end

function addon.RivalEncounters(db, id)
    local rival = db.rivals[id]
    if not rival then return {} end
    local entries = {}
    for _, encounters in ipairs({ rival.encounters or {}, addon.Ledger.RivalSkirmishes(db, id) }) do
        for _, encounter in ipairs(encounters) do
            entries[#entries + 1] = {
                encounter = encounter, id = encounter.skirmishID or id, index = #entries + 1,
                time = encounter.time or encounter.recordedAt or 0, sequence = encounter.sequence or 0,
            }
        end
    end
    table.sort(entries, MoreRecent)
    for index, entry in ipairs(entries) do entries[index] = entry.encounter end
    return entries
end

function addon.RecentEncounters(db, limit, accept)
    local entries = {}
    local function Insert(entry)
        if #entries >= limit and not MoreRecent(entry, entries[limit]) then return end
        if accept and not accept(entry) then return end
        local low, high = 1, #entries
        while low <= high do
            local middle = math.floor((low + high) / 2)
            if MoreRecent(entry, entries[middle]) then
                high = middle - 1
            else
                low = middle + 1
            end
        end
        table.insert(entries, low, entry)
        entries[limit + 1] = nil
    end
    for id, rival in pairs(db.rivals) do
        for index, encounter in ipairs(rival.encounters or {}) do
            Insert({
                id = id, rival = rival, encounter = encounter, index = index,
                time = encounter.time or encounter.recordedAt or 0, sequence = encounter.sequence or 0,
            })
        end
    end
    for id, battle in pairs(db.skirmishes or {}) do
        Insert({
            id = id, skirmish = battle, index = 0,
            time = battle.time or battle.startedAt or 0, sequence = battle.sequence or 0,
        })
    end
    return entries
end

function addon.LatestRival(db)
    local function Eligible(id)
        local rival = id and db.rivals[id]
        return rival and addon.IsRosterRival(id, rival)
    end
    local latest = addon.RecentEncounters(db, 1, function(entry)
        if entry.encounter then return Eligible(entry.id) end
        for _, opponent in ipairs(entry.skirmish.enemies or {}) do
            if Eligible(opponent.rivalID) then return true end
        end
    end)[1]
    if not latest then return end
    if latest.encounter then return latest.id end

    local battle = latest.skirmish
    local evidence = addon.Ledger.SkirmishContributionEvidence(db, latest.id, battle)
    local credited = {}
    for _, credit in ipairs(evidence and evidence.credits or {}) do
        credited[credit.rivalID] = true
    end
    local first, personal
    for _, opponent in ipairs(battle.enemies) do
        local id = opponent.rivalID
        if Eligible(id) then
            if not first or id < first then first = id end
            if credited[id] and (not personal or id < personal) then personal = id end
        end
    end
    return personal or first
end

local function LegacyOpponent(db, id, recordedName, level)
    local rival = db.rivals[id]
    local name = rival and addon.IsRosterRival(id, rival) and addon.ManualName(rival.displayName)
    return {
        id = id, rivalID = rival and id, name = name or addon.ManualName(recordedName), level = level,
        class = rival and rival.class, classLabel = rival and rival.classLabel, sex = rival and rival.sex,
    }
end

local function LegacySkirmish(db, entry, playerAppearance)
    local encounter = entry.encounter
    local player = {
        id = "legacy:player", isSelf = true, name = playerAppearance.name, level = encounter.playerLevel,
        class = playerAppearance.class, classLabel = playerAppearance.classLabel, sex = playerAppearance.sex,
    }
    local attackers = encounter.attackers or {}
    local first = attackers[1]
    local profile = db.rivals[entry.id]
    local level = encounter.rivalLevel or (encounter.manual and profile and profile.observedLevel)
    local rival = LegacyOpponent(db, entry.id, first and first.guid == entry.id and first.name, level)
    local opponents, seen = { rival }, { [rival.id] = true }
    for index, attacker in ipairs(attackers) do
        local id = attacker.guid or ("legacy:attacker:" .. index)
        if not seen[id] then
            seen[id] = true
            opponents[#opponents + 1] = LegacyOpponent(db, id, attacker.name)
        end
    end
    local events = {}
    if not encounter.manual and not encounter.outcome and encounter.direction == "killsAgainstThem" then
        events[1] = { kind = "kill", actorID = player.id, targetID = rival.id, time = encounter.time }
    elseif not encounter.manual and not encounter.outcome and encounter.direction == "deathsToThem" then
        events[1] = { kind = "kill", actorID = rival.id, targetID = player.id, time = encounter.time }
    end
    local rewards
    if encounter.honorableKills or encounter.honor then
        rewards = { [rival.id] = { honorableKills = encounter.honorableKills, honor = encounter.honor } }
    end
    -- A legacy entry records one death and the observed participants, without a complete roster.
    return {
        time = encounter.time, manual = encounter.manual, zone = encounter.zone,
        outcome = addon.Ledger.EncounterOutcome(encounter),
        mapID = encounter.mapID, x = encounter.x, y = encounter.y,
        rosterComplete = false, allies = { player }, enemies = opponents, events = events, rewards = rewards,
    }
end

function addon.RecentSkirmishes(db, limit)
    local battles = addon.RecentEncounters(db, limit)
    local playerAppearance
    local reportRefs = {}
    for index, entry in ipairs(battles) do
        if not entry.skirmish and not playerAppearance then
            local classLabel, class = SafeRead(UnitClass, "player")
            playerAppearance = {
                name = addon.UnitPlayerName("player"), class = class, classLabel = classLabel,
                sex = SafeRead(UnitSex, "player"),
            }
        end
        battles[index] = entry.skirmish or LegacySkirmish(db, entry, playerAppearance)
        if addon.LegacyReportRef then
            reportRefs[battles[index]] = entry.skirmish and entry.id
                or addon.LegacyReportRef(entry.id, entry.encounter, entry.index)
        end
    end
    return battles, reportRefs
end

function addon.FindVisibleRival(guid, unit)
    local rivals = addon.db.rivals
    local rival = type(guid) == "string" and rivals[guid]
    if rival and addon.HasFullName(rival.displayName) then return rival, guid end
    if type(unit) ~= "string" or type(guid) ~= "string" then return end
    local scope = NameScope()
    if not InNameScope(guid, scope) then return end

    local name = addon.UnitPlayerName(unit)
    if not addon.HasFullName(name) then return end
    local confirmed, manuals = MatchingRivals(addon.db, name, scope)
    if confirmed == nil and #manuals == 1 and not rivals[manuals[1]].manualIdentityAmbiguous then
        return rivals[manuals[1]], manuals[1]
    end
end

local function CombineName(given, surname)
    local name = addon.ManualName(given)
    if not name then return end
    if not addon.HasFullName(name) then
        local family = addon.ManualName(surname)
        if family then name = addon.ManualName(name .. " " .. family) end
    end
    return name
end

function addon.UnitPlayerName(unit)
    if SafeRead(UnitIsPlayer, unit) ~= true then return end
    local name = CombineName(SafeRead(UnitName, unit))
    if addon.HasFullName(name) then return name end
    local unmodified = CombineName(SafeRead(UnitNameUnmodified, unit))
    if addon.HasFullName(unmodified) then return unmodified end
    return name or unmodified
end

local function ManualUnit(unit, expectedName)
    local guid = SafeRead(UnitGUID, unit)
    if type(guid) ~= "string" or not guid:match("^Player%-.+") then return end
    local source = unit == "target" and guid == SafeRead(UnitGUID, "player") and "player" or unit
    local name = addon.UnitPlayerName(source)
    if not addon.HasFullName(name) or (expectedName and not SameFullName(name, expectedName)) then return end
    local snapshot = addon.UnitAppearance(source)
    local faction, factionLabel = SafeRead(UnitFactionGroup, source)
    if SafeRead(UnitGUID, unit) ~= guid then return end
    if faction == "Alliance" or faction == "Horde" then
        snapshot.faction = faction
        snapshot.factionLabel = _G["FACTION_" .. faction:upper()]
    end
    if type(factionLabel) == "string" and factionLabel ~= "" then snapshot.factionLabel = factionLabel end
    snapshot.guid, snapshot.name = guid, name
    return snapshot
end

function addon.ManualTarget()
    return ManualUnit("target")
end

ScanManualUnits = function(name, scope, selected)
    local observed, ambiguous = selected, false
    local self = SafeRead(UnitGUID, "player")
    local function Observe(unit)
        local snapshot = ManualUnit(unit, name)
        if not snapshot or (snapshot.guid == self and not (selected and selected.guid == self))
            or not (InNameScope(snapshot.guid, scope) or (selected and snapshot.guid == selected.guid)) then return end
        if not observed then
            observed = snapshot
        elseif observed.guid ~= snapshot.guid then
            ambiguous = true
            return true
        else
            for _, field in ipairs(manualAppearanceFields) do
                if observed[field] == nil then observed[field] = snapshot[field] end
            end
            if not observed.level or (observed.level == -1 and snapshot.level and snapshot.level > 0) then
                observed.level = snapshot.level
            end
        end
    end
    if not selected then Observe("target") end
    if not ambiguous and not Observe("mouseover") then addon.VisitVisibleNameplateUnits(Observe) end
    return observed, ambiguous
end

function addon.ResolveRivalName(unit)
    local guid = SafeRead(UnitGUID, unit)
    if type(guid) ~= "string" or not guid:match("^Player%-.+") or guid == SafeRead(UnitGUID, "player") then return end
    local rival = addon.Ledger.Find(addon.db, guid)
    if rival and addon.HasFullName(rival.displayName) then
        local wins, losses = addon.Ledger.RivalHistoryContext(addon.db, guid)
        if wins + losses > 0 then
            local observed = ManualUnit(unit, rival.displayName)
            if observed and observed.guid == guid and EnrichManualRival(rival, observed) then RefreshRivals() end
        end
        return
    end
    local name = addon.UnitPlayerName(unit)
    if not addon.HasFullName(name) or SafeRead(UnitGUID, unit) ~= guid then return end
    if rival then rival.displayName = name end
    local linked = LinkManualRivals(addon.db, guid, name, true)
    if linked then
        linked.displayName = name
        local observed = ManualUnit(unit, name)
        if observed and observed.guid == guid then EnrichManualRival(linked, observed) end
    end
    if rival or linked then RefreshRivals() end
end

function addon.AddManualEncounter(input, direction, openingTarget)
    local name = addon.ManualName(input)
    if not addon.HasFullName(name) or (direction ~= "killsAgainstThem" and direction ~= "deathsToThem") then
        return nil
    end
    local target = ManualUnit("target", name)
    local scope = NameScope()
    local known, manuals = MatchingRivals(addon.db, name, scope)
    local observed, ambiguous = ScanManualUnits(name, scope, target)
    -- The dialog's opening snapshot guards against silently switching between
    -- namesakes. Only the current target can provide the explicit match.
    local candidate = observed and observed.guid or known
    local targetChanged = openingTarget and SameFullName(name, openingTarget.name)
        and candidate and candidate ~= openingTarget.guid
    ambiguous = ambiguous or known == false or (known and observed and known ~= observed.guid)
    if ambiguous or targetChanged then
        for _, id in ipairs(manuals) do addon.db.rivals[id].manualIdentityAmbiguous = true end
    end
    local snapshot = not targetChanged and (target or (not ambiguous and observed))
    local id = snapshot and snapshot.guid or (not targetChanged and not ambiguous and known)
    if id then
        local profile = addon.db.rivals[id]
        if not ambiguous then profile = LinkManualRivals(addon.db, id, name) or profile end
        -- Reuse a previously observed level from this GUID for display only.
        if profile and not profile.observedLevel and not (snapshot and snapshot.level) then
            for _, encounter in ipairs(addon.RivalEncounters(addon.db, id)) do
                if encounter.rivalLevel then
                    profile.observedLevel = encounter.rivalLevel
                    break
                end
            end
        end
    else
        id = #manuals == 1 and manuals[1] or ("manual:" .. NameKey(name))
    end
    local rival = addon.db.rivals[id]
    local displayName = snapshot and snapshot.name or (rival and rival.displayName) or name
    addon.RecordEncounter(id, displayName, direction, {
        manual = true, outcome = direction == "killsAgainstThem" and "win" or "loss",
        manualIdentityAmbiguous = id:match("^manual:") and (ambiguous or targetChanged) and true or nil,
        rivalLevel = snapshot and snapshot.level or nil,
    }, snapshot)
    return id
end
