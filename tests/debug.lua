local registered, timers = {}, {}
local onEvent
local secret = {}
local restricted = {}
local rejectedEvent = "PVP_MATCH_COMPLETE"

function issecretvalue(value) return value == secret end
function canaccesstable(value) return value ~= restricted end
function GetBuildInfo() return "1.60.1", "70959", "", 16001 end
function GetServerTime() return 100 end
function GetTime() return 15 end
function IsInInstance() return true, "pvp" end
function UnitGUID(unit) return unit == "player" and "Player-test" or secret end
function GetPVPSessionStats() return 2 end

C_PvP = { GetScoreInfoByPlayerGuid = function() return { killingBlows = secret } end }
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { delay, callback } end }
local recap = restricted
C_DeathRecap = {
    HasRecapEvents = function() return true end,
    GetRecapEvents = function() return recap end,
}
SlashCmdList = {}

local frame = {
    RegisterEvent = function(_, event)
        assert(event ~= rejectedEvent)
        registered[event] = true
    end,
    UnregisterEvent = function(_, event) registered[event] = nil end,
    SetScript = function(_, _, callback) onEvent = callback end,
}
function CreateFrame() return frame end

local function Event(name, ...)
    assert(registered[name])
    onEvent(frame, name, ...)
end

local function Login()
    assert(loadfile("NamesInRed/Debug.lua"))("NamesInRed")
    Event("ADDON_LOADED", "OtherAddon")
    Event("ADDON_LOADED", "NamesInRed")
    return NamesInRedDebugDB
end

local db = Login()
assert(db.rows[1].registration[rejectedEvent] == "unavailable")
assert(db.rows[1].score.status.killingBlows == "secret")
assert(db.rows[1].score.killingBlows == nil)

Event("PLAYER_DEAD")
assert(db.rows[3].status.events == "restricted-table")
Event("PLAYER_DEAD")
timers[1][2]()
assert(#db.rows == 5)
recap = {
    { sourceGUID = "Player-a", amount = 10, event = "SWING_DAMAGE" },
    { sourceGUID = secret, amount = secret },
}
for i = 4, 6 do timers[i][2]() end
assert(db.rows[6].delay == 0.3 and db.rows[8].delay == 2)
assert(db.rows[8].events[1].sourceGUID == "Player-a")
assert(db.rows[8].events[2].status.sourceGUID == "secret")
assert(db.rows[8].events[2].sourceGUID == nil)

Event("PARTY_KILL", "Player-test", secret)
assert(db.rows[9].attacker == "Player-test")
assert(db.rows[9].victim == nil and db.rows[9].status.victim == "secret")
Event("CHAT_MSG_COMBAT_HONOR_GAIN", "Test message")
assert(db.rows[10].message == "Test message")
Event("PARTY_KILL", "Player-test", "Creature-test")
assert(#db.rows == 10)
for _ = 1, 1000 do Event("PLAYER_PVP_KILLS_CHANGED", "player") end
assert(#db.rows == 1000 and db.dropped == 10)
assert(Login() == db and db.session == 2 and db.rows[1000].kind == "SESSION")
assert(NamesInRedDB == nil)
print("Debug capture checks passed")
