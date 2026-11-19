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
    local rival = addon.Ledger.Add(addon.db, guid, name)
    rival.displayName = name
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
    local name = input:match("^%s*(.-)%s*$"):gsub(" +", " ")
    if name == "" or #name > 96 then
        return nil
    end
    return name
end

function addon.AddManualEncounter(input, direction)
    local name = addon.ManualName(input)
    if not name or (direction ~= "killsAgainstThem" and direction ~= "deathsToThem") then
        return nil
    end
    -- A typed name alone cannot identify a GUID or its realm.
    local id = "manual:" .. (strlower or string.lower)(name)
    addon.RecordEncounter(id, name, direction, { manual = true })
    return id
end
