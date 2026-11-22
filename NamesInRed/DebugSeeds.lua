local _, addon = ...

-- Each side can be played as the local faction. The first Alliance and Horde
-- characters are the recurring rivals in the first three battles.
local alliance = {
    { "Alden Dawnshield", 1, "human", "Human", 2, "WARRIOR", "Warrior", 55 },
    { "Mira Goldwhisper", 1, "human", "Human", 3, "PRIEST", "Priest", 54 },
    { "Daren Wildwood", 4, "nightelf", "Night Elf", 2, "HUNTER", "Hunter", 55 },
    { "Thoren Ironbrook", 3, "dwarf", "Dwarf", 2, "PALADIN", "Paladin", 56 },
    { "Lysa Starwind", 7, "gnome", "Gnome", 3, "MAGE", "Mage", 52 },
    { "Halea Mistwood", 4, "nightelf", "Night Elf", 3, "DRUID", "Druid", 57 },
    { "Kaela Thornwake", 4, "nightelf", "Night Elf", 3, "ROGUE", "Rogue", 53 },
    { "Perrin Emberwick", 7, "gnome", "Gnome", 2, "WARLOCK", "Warlock", 58 },
    { "Borin Flintforge", 3, "dwarf", "Dwarf", 2, "WARRIOR", "Warrior", 55 },
    { "Nara Brightstone", 3, "dwarf", "Dwarf", 3, "HUNTER", "Hunter", 54 },
    { "Elara Goldleaf", 1, "human", "Human", 3, "MAGE", "Mage", 56 },
    { "Arden Swiftbrook", 1, "human", "Human", 2, "ROGUE", "Rogue", 54 },
}
local horde = {
    { "Dargun Ironjaw", 2, "orc", "Orc", 2, "SHAMAN", "Shaman", 56 },
    { "Morga Duskwhisper", 5, "scourge", "Undead", 3, "PRIEST", "Priest", 54 },
    { "Ragor Ashspear", 8, "troll", "Troll", 2, "HUNTER", "Hunter", 55 },
    { "Brakka Bonewind", 6, "tauren", "Tauren", 2, "WARRIOR", "Warrior", 57 },
    { "Fenrik Coldwater", 8, "troll", "Troll", 2, "MAGE", "Mage", 55 },
    { "Vesha Reedthorn", 6, "tauren", "Tauren", 3, "DRUID", "Druid", 53 },
    { "Cressa Ashveil", 5, "scourge", "Undead", 3, "ROGUE", "Rogue", 54 },
    { "Ghash Emberfang", 2, "orc", "Orc", 2, "WARLOCK", "Warlock", 58 },
    { "Ograth Stormtusk", 2, "orc", "Orc", 2, "WARRIOR", "Warrior", 55 },
    { "Zekka Suncleft", 8, "troll", "Troll", 3, "HUNTER", "Hunter", 54 },
    { "Uldren Grimwatch", 5, "scourge", "Undead", 2, "MAGE", "Mage", 56 },
    { "Tavra Ironleaf", 2, "orc", "Orc", 3, "ROGUE", "Rogue", 54 },
}
local zones = {
    winter = { 1452, "Winterspring" },
    crater = { 1449, "Un'Goro Crater" },
    plaguelands = { 1423, "Eastern Plaguelands" },
    silithus = { 1451, "Silithus" },
    felwood = { 1448, "Felwood" },
    western = { 1422, "Western Plaguelands" },
}

-- Roster numbers select characters above. Blows use positions in the current
-- rosters, with "me" for the local player. Honor is the local player's award.
local fights = {
    { "winter-rematch", 9, "winter", 0.604, 0.377,
      allies = { 1, 2 }, enemies = { 1, 2 }, blows = {
          { 21, "me", "enemy2", 7 }, { 37, "enemy1", "me" }, { 73, "ally2", "enemy1", 9 },
      } },
    { "winter-road", 23, "winter", 0.575, 0.360,
      allies = { 1 }, enemies = { 1 }, blows = { { 44, "enemy1", "me" } } },
    { "crater-camp", 1127, "crater", 0.437, 0.089,
      allies = { 1, 2, 3 }, enemies = { 1, 4, 5 }, blows = {
          { 18, "me", "enemy3", 6 }, { 53, "enemy2", "ally3" },
          { 79, "ally2", "enemy2", 8 }, { 104, "me", "enemy1", 10 },
      } },
    { "chapel-road", 1241, "plaguelands", 0.742, 0.528,
      allies = { 1, 3, 4, 5, 6 }, enemies = { 3, 4, 6, 8, 9, 10 }, blows = {
          { 29, "ally2", "enemy4", 8 }, { 52, "enemy2", "ally5" }, { 60, "enemy6", "ally2" },
          { 86, "me", "enemy6", 7 }, { 104, "enemy5", "ally4" },
          { 129, "enemy1", "me" }, { 156, "enemy3", "ally3" },
      } },
    { "plaguelands-crossing", 1280, "western", 0.462, 0.714,
      allies = { 1, 3 }, enemies = { 8 }, incomplete = true, blows = { { 19, "enemy1", "me" } } },
    { "silithus-ridge", 2923, "silithus", 0.524, 0.367,
      allies = { 1, 2, 4, 5 }, enemies = { 2, 5, 9, 11 }, blows = {
          { 24, "ally3", "enemy2", 7 }, { 35, "enemy3", "ally4" }, { 62, "me", "enemy1", 6 },
          { 79, "enemy4", "ally3" }, { 91, "me", "enemy4", 8 }, { 138, "me", "enemy3", 9 },
      } },
    { "silithus-camp", 2987, "silithus", 0.497, 0.377,
      allies = { 1 }, enemies = { 11 }, blows = { { 31, "enemy1", "me" } } },
    { "felwood-fork", 4371, "felwood", 0.514, 0.830,
      allies = { 1, 2 }, enemies = { 7, 12 }, blows = {
          { 16, "enemy1", "ally2" }, { 32, "me", "enemy2", 8 }, { 58, "enemy1", "me" },
      } },
    { "felwood-path", 4380, "felwood", 0.513, 0.856,
      allies = { 1 }, enemies = { 7 }, blows = { { 17, "me", "enemy1", 10 } } },
    { "crater-trail", 5612, "crater", 0.691, 0.789,
      allies = { 1 }, enemies = { 3 }, blows = { { 26, "me", "enemy1", 7 } } },
    { "winter-bridge", 7198, "winter", 0.374, 0.374,
      allies = { 1, 2 }, enemies = { 6 }, blows = { { 54, "me", "enemy1", 5 } } },
    { "plaguelands-farm", 8654, "western", 0.408, 0.528,
      allies = { 1 }, enemies = { 12 }, blows = { { 38, "enemy1", "me" } } },
}

local function Appearance(profile, id)
    local name, raceID, race, englishRace, sex, class, englishClass, level = unpack(profile)
    local raceInfo = C_CreatureInfo and C_CreatureInfo.GetRaceInfo and C_CreatureInfo.GetRaceInfo(raceID)
    local classes = sex == 3 and LOCALIZED_CLASS_NAMES_FEMALE or LOCALIZED_CLASS_NAMES_MALE
    return { id = id, name = name, race = race, raceLabel = raceInfo and raceInfo.raceName or englishRace,
        sex = sex, class = class, classLabel = classes and classes[class] or englishClass, level = level }
end

local function SeedBattle(fight, now, friendly, opposing, faction)
    local key, minutesAgo, zone, x, y = unpack(fight)
    local mapID, englishZone = unpack(zones[zone])
    local map = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    local time = now - minutesAgo * 60
    local startedAt = time - fight.blows[#fight.blows][1]
    local battle = { time = time, startedAt = startedAt, zone = map and map.name or englishZone, mapID = mapID,
        x = x, y = y, demoFaction = faction, rosterComplete = not fight.incomplete, allies = {}, enemies = {}, events = {}, rewards = {} }
    local participants = {}
    for i, profile in ipairs(fight.allies) do
        local id = i == 1 and "me" or "ally" .. i
        local player = Appearance(friendly[profile], id)
        player.isSelf = i == 1 or nil
        battle.allies[i], participants[id] = player, player
    end
    for i, profile in ipairs(fight.enemies) do
        local id = "seed:rival:" .. profile
        local enemy = Appearance(opposing[profile], id)
        enemy.rivalID = id
        battle.enemies[i], participants["enemy" .. i] = enemy, enemy

        local rival = addon.Ledger.Add(addon.db, id, enemy.name)
        rival.demoFaction = faction
        rival.race, rival.sex, rival.class = enemy.race, enemy.sex, enemy.class
        rival.raceLabel, rival.classLabel = enemy.raceLabel, enemy.classLabel
    end
    for _, blow in ipairs(fight.blows) do
        local second, killer, victim, honor = unpack(blow)
        local actorID, targetID = participants[killer].id, participants[victim].id
        battle.events[#battle.events + 1] = { kind = "kill", actorID = actorID, targetID = targetID, time = startedAt + second }
        if honor then battle.rewards[targetID] = { honorableKills = 1, honor = honor } end
    end
    addon.Ledger.SaveSkirmish(addon.db, "seed:battle:" .. key, battle)
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

function addon.AddDebugSeeds(now, faction)
    addon.ClearDebugSeeds()
    faction = faction or addon.PlayerFaction()
    faction = faction == "Horde" and "Horde" or "Alliance"
    local friendly, opposing = alliance, horde
    if faction == "Horde" then friendly, opposing = horde, alliance end
    for _, fight in ipairs(fights) do SeedBattle(fight, now, friendly, opposing, faction) end
    return #opposing
end
