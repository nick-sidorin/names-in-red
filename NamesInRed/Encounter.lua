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

local function UpdateRival(guid, name, appearance, manual)
    name = addon.ManualName(name)
    local fullName = addon.HasFullName(name) and name or nil
    local rival = addon.Ledger.Find(addon.db, guid)
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
    rival[direction] = rival[direction] + 1
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

function addon.RecentEncounters(db, limit)
    local entries = {}
    local function Insert(entry)
        if #entries >= limit and not MoreRecent(entry, entries[limit]) then return end
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
    local rival = LegacyOpponent(db, entry.id, first and first.guid == entry.id and first.name, encounter.rivalLevel)
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
    if rival then
        if addon.HasFullName(rival.displayName) then return rival, guid end
        return
    end
    if type(unit) ~= "string" then return end

    local name = addon.UnitPlayerName(unit)
    if not addon.HasFullName(name) then return end

    -- Only an unambiguous full name can match an entry without a GUID.
    local lower = strlower or string.lower
    local key = lower(name)
    local matched, matchedID
    for id, entry in pairs(rivals) do
        local stored = not id:match("^seed:") and addon.ManualName(entry.displayName)
        if stored and (lower(stored) == key or (strcmputf8i and strcmputf8i(stored, name) == 0)) then
            if matched or not id:match("^manual:") then return end
            matched, matchedID = entry, id
        end
    end
    return matched, matchedID
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

function addon.ResolveRivalName(unit)
    local guid = SafeRead(UnitGUID, unit)
    if type(guid) ~= "string" or not guid:match("^Player%-.+") then return end
    local rival = addon.Ledger.Find(addon.db, guid)
    if not rival or addon.HasFullName(rival.displayName) then return end
    local name = addon.UnitPlayerName(unit)
    if addon.HasFullName(name) then
        rival.displayName = name
        RefreshRivals()
    end
end

function addon.ManualTarget()
    local name = addon.UnitPlayerName("target")
    if not addon.HasFullName(name) then return end
    local guid = SafeRead(UnitGUID, "target")
    local playerGUID = SafeRead(UnitGUID, "player")
    if type(guid) ~= "string" or not guid:match("^Player%-.+")
        or type(playerGUID) ~= "string" or guid == playerGUID then
        return
    end
    local snapshot = addon.UnitAppearance("target")
    local _, factionLabel = SafeRead(UnitFactionGroup, "target")
    snapshot.guid, snapshot.name = guid, name
    snapshot.factionLabel = type(factionLabel) == "string" and factionLabel ~= "" and factionLabel or nil
    return snapshot
end

function addon.AddManualEncounter(input, direction, target)
    local name = addon.ManualName(input)
    if not addon.HasFullName(name) or (direction ~= "killsAgainstThem" and direction ~= "deathsToThem") then
        return nil
    end
    -- Bind only the name supplied by the target snapshot.
    local snapshot = target and target.name == name and target
    local id = snapshot and snapshot.guid
        or ("manual:" .. (strlower or string.lower)(name))
    addon.RecordEncounter(id, name, direction, {
        manual = true, outcome = direction == "killsAgainstThem" and "win" or "loss",
        rivalLevel = snapshot and snapshot.level or nil,
    }, snapshot)
    return id
end
