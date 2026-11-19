local _, addon = ...

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

local function Level(unit)
    local level = SafeRead(UnitLevel, unit)
    if type(level) == "number" and level > 0 then
        return level
    end
end

function addon.EncounterContext(unit)
    local result = {
        time = SafeRead(GetServerTime),
        playerLevel = Level("player"),
        rivalLevel = unit and Level(unit),
        zone = SafeRead(GetRealZoneText),
    }
    if C_Map then
        local mapID = SafeRead(C_Map.GetBestMapForUnit, "player")
        if type(mapID) == "number" then
            local x, y = SafeRead(function()
                local position = addon.Readable(C_Map.GetPlayerMapPosition(mapID, "player"))
                if position then
                    return position:GetXY()
                end
            end)
            if type(x) == "number" and type(y) == "number" and x >= 0 and x <= 1
                and y >= 0 and y <= 1 and (x ~= 0 or y ~= 0) then
                result.x, result.y = x, y
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

function addon.RecordEncounter(guid, name, direction, context)
    name = addon.ManualName(name)
    local fullName = addon.HasFullName(name) and name or nil
    local rival = addon.Ledger.Find(addon.db, guid)
    if not rival then
        rival = addon.Ledger.Add(addon.db, guid, fullName)
        if context.manual then rival.addedManually = true end
    end
    -- Later sightings can complete a name even when an earlier event only exposed its first part.
    if fullName then
        rival.displayName = fullName
    end
    local race, sex, class, raceLabel, classLabel = addon.RivalAppearance(guid)
    if race then rival.race, rival.sex = race, sex end
    if class then rival.class = class end
    if type(raceLabel) == "string" and raceLabel ~= "" then rival.raceLabel = raceLabel end
    if type(classLabel) == "string" and classLabel ~= "" then rival.classLabel = classLabel end
    rival[direction] = rival[direction] + 1
    rival.encounters = rival.encounters or {}
    context.direction = direction
    table.insert(rival.encounters, 1, context)
    if #rival.encounters > 20 then
        table.remove(rival.encounters)
    end
    if addon.RefreshBook then
        addon.RefreshBook()
    end
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
        if addon.RefreshBook then addon.RefreshBook() end
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
    return { guid = guid, name = name }
end

function addon.AddManualEncounter(input, direction, target)
    local name = addon.ManualName(input)
    if not addon.HasFullName(name) or (direction ~= "killsAgainstThem" and direction ~= "deathsToThem") then
        return nil
    end
    -- Bind only the name supplied by the target snapshot.
    local id = target and target.name == name and target.guid
        or ("manual:" .. (strlower or string.lower)(name))
    addon.RecordEncounter(id, name, direction, { manual = true })
    return id
end
