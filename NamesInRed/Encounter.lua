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

function addon.RecordEncounter(guid, name, direction, context)
    local rival = addon.Ledger.Add(addon.db, guid, name)
    rival.displayName = name
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
