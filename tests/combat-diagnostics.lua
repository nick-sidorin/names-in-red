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
local battle = {
    allies = { { id = me, isSelf = true, name = "Private Local" } },
    enemies = { { id = rival, name = "Private Rival" } },
    events = {}, observation = {},
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
addon.ObserveCombatAuras(capture, "nameplate1", { addedAuras = { aura } })
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
addon.RecordCombatDeathRecap(battle, rival, me, { event = "SPELL_DAMAGE", timestamp = 1800000006, spellId = 31, amount = 294 })

local function CopySaved(value)
    local kind = type(value)
    assert(not issecretvalue(value) and canaccesstable(value), "unreadable value was persisted")
    if kind == "table" then
        local copy = {}
        for key, item in pairs(value) do copy[key] = CopySaved(item) end
        return copy
    end
    assert(kind == "string" or kind == "number" or kind == "boolean")
    if kind == "string" then
        assert(not value:find("Cast-private", 1, true) and not value:find("Private ", 1, true))
    end
    return value
end
local savedBattle = {
    allies = battle.allies, enemies = battle.enemies, events = {}, observation = {},
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
Includes(report, '"UNIT_SPELLCAST_CHANNEL_STOP": "unavailable"')
Includes(report, '"ending": "area-changed"')
for _, private in ipairs({ "Private ", me, rival, unknown, "Cast-private-guid", "12345" }) do Excludes(report, private) end
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
assert(#battle.combatDiagnostics.windows == 4 and battle.combatDiagnostics.windowsDropped == 2)
local longReport = addon.BuildIssueReport(db, nil, "world:14")
Includes(longReport, '"windowsDropped": 2')
Includes(longReport, '"rateLimited": 1080')
local truncated = assert(longReport:match('"truncatedSections": "([^"]+)"'))
Includes(truncated, "primaryEvidence")
assert(#longReport <= 24576 and longReport:sub(-4) == "\n```")
print("Bounded primary observations, secret fields, report aliases, saved reload and truncation passed")
