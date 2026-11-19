local _, addon = ...

local names = {
    "Aelra Moonbough", "Borin Flintforge", "Cressa Ashveil", "Dargun Ironjaw",
    "Elara Goldleaf", "Fenrik Coldwater", "Ghash Emberfang", "Halea Mistwood",
    "Ilyra Dusksong", "Jorin Blackpine", "Kaela Thornwake", "Loran Windmere",
    "Maelis Frostglen", "Nara Brightstone", "Ograth Stormtusk", "Perrin Emberwick",
    "Quilla Mossbloom", "Ragor Ashspear", "Selya Silvermist", "Tavra Ironleaf",
    "Uldren Grimwatch", "Vesha Reedthorn", "Werrin Copperbolt", "Xalara Dawnshade",
    "Yorin Redmarsh", "Zekka Suncleft", "Arden Swiftbrook", "Brakka Bonewind",
    "Cyra Cloudstep", "Daven Steelbough",
}
local profiles = {
    { 4, "nightelf", "Night Elf", 3, "HUNTER", "Hunter" },
    { 3, "dwarf", "Dwarf", 2, "WARRIOR", "Warrior" },
    { 5, "scourge", "Undead", 3, "ROGUE", "Rogue" },
    { 2, "orc", "Orc", 2, "SHAMAN", "Shaman" },
    { 1, "human", "Human", 3, "PRIEST", "Priest" },
    { 8, "troll", "Troll", 2, "MAGE", "Mage" },
    { 2, "orc", "Orc", 2, "WARLOCK", "Warlock" },
    { 6, "tauren", "Tauren", 3, "DRUID", "Druid" },
}
local zones = {
    { 1424, "Hillsbrad Foothills" },
    { 1434, "Stranglethorn Vale" },
    { 1446, "Tanaris" },
    { 1440, "Ashenvale" },
    { 1444, "Feralas" },
    { 1428, "Burning Steppes" },
}

local function ClassName(class, sex, fallback)
    local dictionary = sex == 3 and LOCALIZED_CLASS_NAMES_FEMALE or LOCALIZED_CLASS_NAMES_MALE
    return dictionary and dictionary[class] or fallback
end

function addon.ClearDebugSeeds()
    local removed = 0
    for id in pairs(addon.db.rivals) do
        if id:match("^seed:") then
            addon.Ledger.Remove(addon.db, id)
            removed = removed + 1
        end
    end
    return removed
end

function addon.AddDebugSeeds(now)
    local zoneNames = {}
    for index, zone in ipairs(zones) do
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(zone[1])
        zoneNames[index] = info and info.name or zone[2]
    end
    addon.ClearDebugSeeds()
    for index, name in ipairs(names) do
        local manual = index % 5 == 0
        local id = (manual and "seed:manual:" or "seed:") .. index
        local rival = addon.Ledger.Add(addon.db, id, name)
        rival.encounters = {}
        local count = manual and 1 or (3 + index % 5)
        local rivalLevel = 30 + (index * 7) % 31
        if not manual then
            local profile = profiles[(index - 1) % #profiles + 1]
            local raceInfo = C_CreatureInfo and C_CreatureInfo.GetRaceInfo and C_CreatureInfo.GetRaceInfo(profile[1])
            rival.race, rival.sex, rival.class = profile[2], profile[4], profile[5]
            rival.raceLabel = raceInfo and raceInfo.raceName or profile[3]
            rival.classLabel = ClassName(profile[5], profile[4], profile[6])
        end
        for encounter = 1, count do
            local field = (index + encounter) % 3 == 0 and "deathsToThem" or "killsAgainstThem"
            rival[field] = rival[field] + 1
            local row = { direction = field }
            if manual then
                row.manual = true
            else
                row.time = now - index * 173 - encounter * 3617
                row.zone = zoneNames[(index + encounter - 2) % #zones + 1]
                row.x = (20 + (index * 13 + encounter * 7) % 61) / 100
                row.y = (18 + (index * 9 + encounter * 11) % 65) / 100
                row.playerLevel = 48 + (index + encounter) % 13
                row.rivalLevel = rivalLevel
            end
            rival.encounters[encounter] = row
        end
    end
    return #names
end
