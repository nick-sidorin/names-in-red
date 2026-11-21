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

local squad = {
    { id = "me", name = "Alden Dawnshield", race = "human", sex = 2, class = "WARRIOR", classLabel = "Warrior", level = 51, isSelf = true },
    { id = "ally:1", name = "Mira Goldwhisper", class = "PRIEST", classLabel = "Priest", level = 50, sex = 3 },
    { id = "ally:2", name = "Thoren Ironbrook", class = "PALADIN", classLabel = "Paladin", level = 52 },
    { id = "ally:3", name = "Lysa Starwind", class = "MAGE", classLabel = "Mage", level = 48, sex = 3 },
    { id = "ally:4", name = "Daren Wildwood", class = "HUNTER", classLabel = "Hunter", level = 53 },
}
local opposing = { 4, 7, 2, 8, 3, 6 }

local function Ally(index)
    local ally = {}
    for key, value in pairs(squad[index]) do ally[key] = value end
    return ally
end

local function Opponent(id, index, rival)
    return {
        id = id, rivalID = id, name = rival.displayName, race = rival.race, sex = rival.sex,
        class = rival.class, classLabel = rival.classLabel, level = 30 + (index * 7) % 31,
    }
end

local function SeedBattle(index, now, zoneNames, allyCount, enemyCount, complete, blows, rewards)
    local zone = (index - 1) % #zones + 1
    local time = now - index * 290
    local battle = {
        time = time, startedAt = time - math.max(95, #blows * 17),
        zone = zoneNames[zone], mapID = zones[zone][1], x = 0.42 + index * 0.03, y = 0.51,
        rosterComplete = complete, allies = {}, enemies = {}, events = {}, rewards = rewards,
    }
    for i = 1, allyCount do
        battle.allies[i] = Ally(i)
    end
    for i = 1, enemyCount do
        local rivalIndex = opposing[i]
        local id = "seed:" .. rivalIndex
        battle.enemies[i] = Opponent(id, rivalIndex, addon.db.rivals[id])
    end
    for i, blow in ipairs(blows) do
        battle.events[i] = { kind = "kill", actorID = blow[1], targetID = blow[2],
            time = battle.startedAt + i * 17, contributors = blow[3] }
    end
    addon.Ledger.SaveSkirmish(addon.db, "seed:battle:" .. index, battle)
end

local function SeedSolo(index, attempt, now, zoneNames, opponent)
    local player = Ally(1)
    player.level = 48 + (index + attempt) % 13
    local time = now - index * 173 - attempt * 3617
    local zone = (index + attempt - 2) % #zones + 1
    local won = (index + attempt) % 3 ~= 0
    local winner, loser = player, opponent
    if not won then winner, loser = opponent, player end
    local rewards
    if won and opponent.level >= player.level - 8 then
        rewards = { [opponent.id] = { honorableKills = 1, honor = 4 + (index + attempt) % 9 } }
    end
    addon.Ledger.SaveSkirmish(addon.db, ("seed:solo:%d:%d"):format(index, attempt), {
        time = time, startedAt = time - 17, zone = zoneNames[zone], mapID = zones[zone][1],
        x = (20 + (index * 13 + attempt * 7) % 61) / 100,
        y = (20 + (index * 5 + attempt * 11) % 61) / 100,
        rosterComplete = true, allies = { player }, enemies = { opponent },
        events = { { kind = "kill", actorID = winner.id, targetID = loser.id, time = time } }, rewards = rewards,
    })
end

function addon.ClearDebugSeeds()
    local removed = 0
    for id in pairs(addon.db.skirmishes or {}) do
        if id:match("^seed:") then addon.Ledger.RemoveSkirmish(addon.db, id) end
    end
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
        if manual then
            rival.encounters = { { manual = true, outcome = (index + 1) % 3 == 0 and "loss" or "win" } }
        else
            local profile = profiles[(index - 1) % #profiles + 1]
            local raceInfo = C_CreatureInfo and C_CreatureInfo.GetRaceInfo and C_CreatureInfo.GetRaceInfo(profile[1])
            rival.race, rival.sex, rival.class = profile[2], profile[4], profile[5]
            rival.raceLabel = raceInfo and raceInfo.raceName or profile[3]
            rival.classLabel = ClassName(profile[5], profile[4], profile[6])
            for attempt = 1, 3 + index % 5 do
                SeedSolo(index, attempt, now, zoneNames, Opponent(id, index, rival))
            end
        end
    end
    SeedBattle(1, now, zoneNames, 2, 2, true, {
        { "ally:1", "seed:7", { me = true, ["ally:1"] = true } },
        { "seed:4", "me", { ["seed:4"] = true, ["seed:7"] = false } },
        { "ally:1", "seed:4" },
    }, {
        ["seed:7"] = { honorableKills = 1, honor = 7 },
        ["seed:4"] = { honorableKills = 1, honor = 6 },
    })
    SeedBattle(2, now, zoneNames, 1, 1, true, {
        { "me", "seed:4", { me = true } },
        { "seed:4", "me", { ["seed:4"] = false } },
    })
    SeedBattle(3, now, zoneNames, 5, 6, true, {
        { "seed:4", "ally:2" }, { "ally:4", "seed:2" },
        { "seed:7", "me", { ["seed:4"] = true, ["seed:7"] = true } },
        { "seed:8", "ally:1" }, { "seed:3", "ally:3" }, { "seed:6", "ally:4" },
    }, {
        ["seed:2"] = { honorableKills = 1, honor = 8 },
    })
    SeedBattle(4, now, zoneNames, 2, 1, false, { { "seed:4", "me" } })
    SeedBattle(5, now, zoneNames, 2, 1, true, {
        { "seed:4", "me" },
        { "ally:1", "seed:4", { me = false } },
    })
    SeedBattle(6, now, zoneNames, 2, 1, true, {
        { "seed:4", "me" }, { "seed:4", "ally:1" },
    })
    return #names
end
