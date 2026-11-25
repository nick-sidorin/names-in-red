local addon = {}
local me, rival, unknown = "Player-1-local", "Player-2-rival", "Player-3-other"
local secret, restricted = {}, setmetatable({}, { __index = function() error("restricted data was read") end })
function issecretvalue(value) return rawequal(value, secret) end
function canaccesstable(value) return not rawequal(value, restricted) end
local now = 100
function GetTime() return now end
function UnitGUID(unit)
    if unit == "player" then return me end
    if unit == "target" then return rival end
    if unit == "party1" then return secret end
    if unit == "nameplate1" then return unknown end
end
function GetBuildInfo() return "1.60.1", "71037", "", 16001 end
function GetLocale() return "enUS" end
function IsInInstance() return false, "none" end
for _, file in ipairs({ "Locale", "Ledger", "Encounter", "CombatDiagnostics", "IssueReport" }) do
    assert(loadfile("NamesInRed/" .. file .. ".lua"))("NamesInRed", addon)
end

local db = addon.Ledger.Open()
addon.db = db
local battle = {
    allies = { { id = me, isSelf = true, name = "Private Local" } },
    enemies = { { id = rival, name = "Private Rival" } },
    events = {
        { kind = "kill", actorID = me, targetID = rival, offset = 2 },
        { kind = "revive", targetID = rival, offset = 4 },
    }, observation = {},
}
addon.Ledger.SaveSkirmish(db, "world:14", battle)
local function Includes(text, part) assert(text:find(part, 1, true), part) end
local function Excludes(text, part) assert(not text:find(part, 1, true), part) end
local oldReport = addon.BuildIssueReport(db, nil, "world:14")
Includes(oldReport, '"availability": "not-recorded"')
Excludes(oldReport, '"section": "primaryEvidence"')

local registration = { UNIT_COMBAT = "registered", UNIT_SPELLCAST_CHANNEL_STOP = "unavailable" }
local capture = addon.NewCombatDiagnostics(100, 1800000000, "71037", registration)
assert(not battle.combatDiagnostics)
addon.ObserveCombatFeedback(capture, "target", "WOUND", "CRITICAL", secret, 4)
-- UNIT_COMBAT has no event ID. Identical deliveries remain separate.
addon.ObserveCombatFeedback(capture, "target", "HEAL", "", 24, nil)
addon.ObserveCombatFeedback(capture, "target", "HEAL", "", 24, nil)
addon.ObserveCombatCast(capture, "UNIT_SPELLCAST_START", "player", "Cast-private-guid", 123)
addon.ObserveCombatCast(capture, "UNIT_SPELLCAST_START", "player", "Cast-private-guid", 123)
addon.ObserveCombatCast(capture, "UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-private-guid", 123)
addon.ObserveCombatCast(capture, "UNIT_SPELLCAST_INTERRUPTED", "party1", secret, secret, rival)
addon.ObserveCombatAuras(capture, "target", restricted)
addon.ObserveCombatAuras(capture, "target", { isFullUpdate = secret, addedAuras = restricted })
addon.ObserveCombatAuras(capture, "target", { isFullUpdate = true })
local aura = { sourceUnit = "player", spellId = 234, isHarmful = true, auraInstanceID = 12345, name = "Private Aura" }
addon.ObserveCombatAuras(capture, "target", { addedAuras = { aura, aura } })
addon.ObserveCombatAuras(capture, "nameplate1", { addedAuras = {
    { sourceUnit = "player", spellId = 999001, auraInstanceID = 12345, isHarmful = true },
} })
addon.ObserveCombatState(capture, { guid = rival, reason = "flags", dead = true, inCombat = false,
    status = { dead = "readable", inCombat = "readable", feign = "secret" } })
addon.ObserveCombatPartyKill(capture, me, rival)
addon.AttachCombatDiagnostics(battle, capture)
addon.AttachCombatDiagnostics(battle, capture)
assert(#battle.combatDiagnostics.windows == 1)
local streams = capture.window.streams
assert(#streams.unitCombat.rows == 3 and streams.unitCombat.rows[1].amountStatus == "secret")
assert(not streams.unitCombat.rows[2].actorID and streams.unitCombat.rows[2].schoolStatus == "absent")
assert(#streams.spellCast.rows == 3 and streams.spellCast.duplicates == 1)
assert(streams.spellCast.rows[3].actorStatus == "secret" and streams.spellCast.rows[3].spellIDStatus == "secret")
assert(streams.spellCast.rows[3].interrupterID == rival)
assert(#streams.aura.rows == 5 and streams.aura.duplicates == 1)
assert(streams.aura.rows[1].payloadStatus == "restricted-table")
assert(streams.aura.rows[2].payloadStatus == "secret" and streams.aura.rows[3].payloadStatus == "full-update")
assert(streams.aura.rows[4].actorID == me and streams.aura.rows[4].targetID == rival)
assert(streams.aura.rows[5].targetID == unknown)

local meter = addon.NewCombatMeterProbe()
local actor = { guid = rival }
local source = { sourceGUID = rival, totalAmount = 935, status = { totalAmount = "readable" }, name = "Private Source" }
local spell = { spellID = 31, totalAmount = 510, overkillAmount = secret, creatureName = "Private Creature" }
local detail = { amount = 441, isMob = false, isPet = false, unitName = "Private Local",
    status = { row = "readable", amount = "readable", unitName = "readable", unitClassFilename = "readable" } }
addon.SampleCombatMeter(meter, "EnemyDamageTaken", actor, source, spell, detail, "link", { guid = me })
addon.SampleCombatMeter(meter, "HealingDone", actor, source, spell,
    { status = { row = "readable", amount = "secret", unitName = "secret" } }, "target-name-secret")
addon.CommitCombatMeterProbe(capture, meter, 55, "new-archived")
now = 108
addon.EndCombatDiagnostics(capture, "area-changed")
local hit = { event = "SPELL_DAMAGE", timestamp = 1800000006, spellId = 31, amount = 294 }
addon.RecordCombatDeathRecap(battle, rival, me, hit)
addon.RecordCombatDeathRecap(battle, rival, me, hit)
assert(#battle.combatDiagnostics.recaps == 1)
addon.RecordCombatMeterFollowup(capture, { uptime = now, meterSessionID = 55, playerDead = true, playerGhost = true,
    status = { meter = "linked-increase", playerDead = "readable", playerGhost = "readable" },
}, {
    actorID = rival, targetID = me, amount = 61,
}, "DamageTaken", 17)

local function CopySaved(value, allowCharacterNames)
    local kind = type(value)
    assert(not issecretvalue(value) and canaccesstable(value), "unreadable value was persisted")
    if kind == "table" then
        local copy = {}
        for key, item in pairs(value) do copy[key] = CopySaved(item, allowCharacterNames) end
        return copy
    end
    assert(kind == "string" or kind == "number" or kind == "boolean")
    if kind == "string" then
        assert(not value:find("Cast-private", 1, true))
        assert(allowCharacterNames or not value:find("Private ", 1, true))
    end
    return value
end
local savedBattle = {
    allies = battle.allies, enemies = battle.enemies, events = battle.events, observation = {},
    combatDiagnostics = CopySaved(battle.combatDiagnostics),
}
local saved = addon.Ledger.Open({ version = 1, rivals = {}, skirmishes = { ["world:14"] = savedBattle } })
local report = addon.BuildIssueReport(saved, nil, "world:14")
Includes(report, '"api": "C_DeathRecap"')
Includes(report, '"api": "UNIT_COMBAT"')
Includes(report, '"amountStatus": "secret"')
Includes(report, '"target": "Player-2"')
Includes(report, '"actor": "Player-1"')
Includes(report, '"interrupter": "Player-2"')
Includes(report, '"other": "Player-1"')
Includes(report, '"meterUnit": "Player-2"')
Includes(report, '"sessionID": 55')
Includes(report, '"amount": 441')
Includes(report, '"spellTotal": 510')
Includes(report, '"overkillStatus": "secret"')
Includes(report, '"section": "meterSpellSample"')
Includes(report, '"section": "meterFollowup"')
Includes(report, '"amountIncrease": 17')
Includes(report, '"localGhost": true')
Includes(report, '"kind": "revive"')
Includes(report, '"evidence": "observation"')
Includes(report, '"evidence": "aggregate"')
Includes(report, '"evidence": "derived"')
Includes(report, '"outsideRosterOrUnresolved": 1')
Includes(report, '"UNIT_SPELLCAST_CHANNEL_STOP": "unavailable"')
Includes(report, '"ending": "area-changed"')
for _, private in ipairs({ "Private ", me, rival, unknown, "Cast-private-guid", "12345", "999001" }) do Excludes(report, private) end
for line in report:gmatch("[^\n]+") do
    if line:find('"section": "meterSpellSample"', 1, true) or line:find('"section": "meterFollowup"', 1, true) then
        Excludes(line, '"eventTime"')
        Excludes(line, '"offset"')
    end
end
assert(report == addon.BuildIssueReport(saved, nil, "world:14"))

local bulk = addon.NewCombatMeterProbe()
for _, category in ipairs({ "DamageDone", "DamageTaken", "HealingDone", "Absorbs",
    "Interrupts", "Dispels", "EnemyDamageTaken" }) do
    for _ = 1, 12 do
        addon.SampleCombatMeter(bulk, category, actor, source, spell, detail, "link", { guid = me })
    end
end
assert(bulk.retained == 32 and bulk.dropped == 52)
assert(#bulk.categories.DamageDone.rows == 6 and bulk.categories.DamageDone.dropped == 6)
assert(#bulk.categories.EnemyDamageTaken.rows == 0 and bulk.categories.EnemyDamageTaken.dropped == 12)

-- Simulate a long fight and bursts of combat. Each family has its own budget.
for index = 1, 5 do
    local window = addon.NewCombatDiagnostics(now, 1800000100 + index, "71037", registration)
    for second = 1, 60 do
        now = now + 1
        for _ = 1, 30 do
            addon.ObserveCombatFeedback(window, "target", "WOUND", "", 13, 2)
            addon.ObserveCombatCast(window, "UNIT_SPELLCAST_SUCCEEDED", "target", secret, 200)
            addon.ObserveCombatAuras(window, "target", { addedAuras = {
                { sourceUnit = "player", spellId = 14, isHarmful = true, auraInstanceID = now },
            } })
        end
        addon.ObserveCombatState(window, { guid = rival, reason = "flags", dead = false,
            status = { dead = "readable", inCombat = "secret", feign = "secret" } })
    end
    addon.EndCombatDiagnostics(window, "combat-end")
    addon.AttachCombatDiagnostics(battle, window)
    assert(#window.window.streams.unitCombat.rows == 16)
    assert(window.window.streams.unitCombat.rateLimited == 60 * 18)
    assert(window.window.streams.unitCombat.dropped == 60 * 12 - 16)
    assert(window.window.streams.unitCombat.rows[16].offset == 60)
end
local longCapture = battle.combatDiagnostics
assert(#longCapture.windows == 2 and longCapture.windowsDropped == 4)
local longReport, extra = addon.BuildIssueReport(db, nil, "world:14")
Includes(longReport, '"windowsDropped": 4')
Includes(longReport, '"rateLimited": 1080')
local _, occurrences = longReport:gsub('"effect": "WOUND"', "")
assert(occurrences == #longCapture.windows * 16)
assert(extra == nil and #longReport <= 60 * 1024 and longReport:sub(-4) == "\n```")
Includes(longReport, '"id": "world:14"')
Excludes(longReport, rival)
Includes(longReport, '"target": "Player-2"')
Excludes(longReport, '"section": "meterFollowup"') -- Its older window was dropped.

local function SavedVariablesSize(value, depth)
    if type(value) == "string" then return #("%q"):format(value) end
    if type(value) ~= "table" then return #tostring(value) end
    local bytes = 3 + depth
    for key, item in pairs(value) do
        bytes = bytes + depth + 8 + SavedVariablesSize(key, depth) + SavedVariablesSize(item, depth + 1)
    end
    return bytes
end

local smallBytes = SavedVariablesSize(savedBattle.combatDiagnostics, 4)
local longBytes = SavedVariablesSize(longCapture, 4)
local samples = CopySaved(longCapture.windows)
collectgarbage("collect")
local memoryBefore = collectgarbage("count")
for i = 15, 40 do
    local nextBattle = { sequence = i, allies = battle.allies, enemies = battle.enemies,
        events = {}, observation = {} }
    for _, sample in ipairs(samples) do
        local window = addon.NewCombatDiagnostics(now, 1800010000 + i, "71037", registration)
        window.window = CopySaved(sample)
        addon.AttachCombatDiagnostics(nextBattle, window)
    end
    addon.Ledger.SaveSkirmish(db, "world:" .. i, nextBattle)
end
collectgarbage("collect")
local stressMemory = collectgarbage("count") - memoryBefore
assert(battle.combatDiagnostics.retention == "compact")
assert(#battle.events == 2 and #battle.combatDiagnostics.windows == 1)
assert(#battle.combatDiagnostics.windows[1].streams.unitCombat.rows == 2)
local compactBytes = SavedVariablesSize(battle.combatDiagnostics, 4)
local detailedBytes, detailed = 0, 0
for _, item in pairs(db.skirmishes) do
    if item.combatDiagnostics.retention ~= "compact" then
        detailed = detailed + 1
        detailedBytes = detailedBytes + SavedVariablesSize(item.combatDiagnostics, 4)
    end
end
assert(detailed == 24 and detailedBytes <= 24 * 65536)
assert(compactBytes < 4096 and longBytes <= 65536)
local reloaded = addon.Ledger.Open(CopySaved(db, true))
local compactReport = addon.BuildIssueReport(reloaded, nil, "world:14")
Includes(compactReport, '"retention": "compact"')
Includes(compactReport, '"effect": "WOUND"')
Includes(compactReport, '"kind": "revive"')
Includes(addon.BuildIssueReport(reloaded, nil, "world:40"), '"effect": "WOUND"')
Excludes(compactReport, rival)
assert(reloaded.skirmishes["world:14"] and reloaded.skirmishes["world:40"])
print(("Saved diagnostics fixture sizes: normal %d B, dense %d B, compact %d B, detailed history %d B; "
    .. "26 extra cards used %.1f KiB of retained Lua heap"):format(smallBytes, longBytes, compactBytes, detailedBytes, stressMemory))
print("Bounded primary observations, secret fields, report aliases, saved reload and truncation passed")

-- Saved battle data outlives the optional diagnostics, even for the oldest
-- rival card beyond the limit in the cross-rival view.
local ledger = addon.Ledger
local oldTime, oldID = 1577836800, "world:1"
local historyDB = ledger.Open()
addon.db = historyDB
ledger.Add(historyDB, rival, "Private Rival")
local friend = "Player-4-friendly"
local oldBattle = {
    time = oldTime, sequence = 1, zone = "Old Zone", mapID = 47, x = 0.4, y = 0.5, outcome = "win",
    allies = { { id = me, isSelf = true }, { id = friend } },
    enemies = { { id = rival, rivalID = rival } },
    events = {
        { kind = "kill", actorID = me, targetID = rival, offset = 2 },
        { kind = "revive", targetID = rival, offset = 5 },
        { kind = "death", targetID = rival, offset = 9 },
    },
    observation = { segments = { {
        startedAt = oldTime - 1, localCombatAt = oldTime,
        meter = { selection = "new-archived", sessionID = 51 },
        actions = { { kind = "harmful-aura", actorID = me, targetID = rival, spellID = 127, first = 0, last = 1, count = 2 } },
    } } },
    rewards = { [rival] = { honor = 5, honorableKills = 1 } },
}
local oldSegment = oldBattle.observation.segments[1]
local legacyProbe = {
    selection = "new-archived", sessionID = 51,
    categories = {
        EnemyDamageTaken = { rows = {
            { resolution = "link", meterUnitID = rival, otherID = me, amount = 25, spellID = 127, spellTotal = 85,
                petOwner = true },
            { resolution = "link", meterUnitID = rival, otherID = unknown, amount = 60 },
        } },
        HealingDone = { rows = {
            { resolution = "link", meterUnitID = friend, otherID = me, amount = 16, spellID = 807 },
            { resolution = "target-contact-ambiguous", meterUnitID = friend, otherID = me, amount = 100 },
        } },
    },
}
oldBattle.combatDiagnostics = { version = 1, windows = {
    { time = oldTime, index = 1, meter = legacyProbe, streams = {} },
}, recaps = {} }
ledger.SaveSkirmish(historyDB, oldID, oldBattle)
assert(not oldSegment.combatAggregates)

local ambiguous = CopySaved(historyDB, true)
local ambiguousBattle = ambiguous.skirmishes[oldID]
ambiguousBattle.combatDiagnostics.windows[2] = CopySaved(ambiguousBattle.combatDiagnostics.windows[1])
ledger.Open(ambiguous)
assert(not ambiguousBattle.observation.segments[1].combatAggregates)

ledger.Open(historyDB)
local aggregates = assert(oldSegment.combatAggregates)
assert(#aggregates == 2)
assert(aggregates[1].actorID == me and aggregates[1].targetID == rival and aggregates[1].amount == 25)
assert(aggregates[1].spellID == 127 and aggregates[1].petEndpoint == "target" and not aggregates[1].spellTotal)
assert(aggregates[2].actorID == friend and aggregates[2].targetID == me and aggregates[2].amount == 16)
assert(ledger.Open(historyDB) == historyDB and #oldSegment.combatAggregates == 2)

for index = 2, 140 do
    local time = 1800010000 + index
    local nextBattle = {
        time = time, sequence = index, allies = oldBattle.allies, enemies = oldBattle.enemies, events = {},
        outcome = index == 2 and "loss" or nil,
    }
    local capture = addon.NewCombatDiagnostics(now, time, "71037", registration)
    addon.AttachCombatDiagnostics(nextBattle, capture)
    ledger.SaveSkirmish(historyDB, "world:" .. index, nextBattle)
end
assert(oldBattle.combatDiagnostics.retention == "compact" and oldSegment.combatAggregates == aggregates)
oldBattle.combatDiagnostics = nil
local reopenedHistory = ledger.Open(CopySaved(historyDB, true))
local recent = addon.RecentSkirmishes(reopenedHistory, 100)
assert(#recent == 100 and recent[100].sequence == 41)
local rivalHistory = addon.RivalEncounters(reopenedHistory, rival)
assert(#rivalHistory == 140 and rivalHistory[140].skirmishID == oldID)
assert(rivalHistory[139].outcome == "loss" and rivalHistory[138].outcome == nil)
assert(rivalHistory[140].outcome == "win" and rivalHistory[140].honor == 5)
local reopened = reopenedHistory.skirmishes[oldID]
assert(reopened.time == oldTime and reopened.zone == "Old Zone" and reopened.mapID == 47 and reopened.x == 0.4)
assert(#reopened.allies == 2 and #reopened.enemies == 1 and ledger.Find(reopenedHistory, rival).displayName == "Private Rival")
assert(#reopened.events == 3 and reopened.events[2].kind == "revive" and reopened.events[3].kind == "death")
assert(reopened.observation.segments[1].actions[1].count == 2)
assert(#reopened.observation.segments[1].combatAggregates == 2)
local historyReport = addon.BuildIssueReport(reopenedHistory, nil, oldID)
Includes(historyReport, '"section": "combatAggregate"')
Includes(historyReport, '"category": "HealingDone"')
Includes(historyReport, '"availability": "not-recorded"')
Excludes(historyReport, rival)
print("Permanent rival and battle history outlives both diagnostic buffers and the recent view limit")
