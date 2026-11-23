local addon = {}
function GetLocale() return "ruRU" end
function GetBuildInfo() return "1.60.1", "70959", "Nov 23", 16001 end
function IsInInstance() return false, "none" end
function GetRealZoneText() return "Duskwood" end
C_AddOns = { GetAddOnMetadata = function() return "1.1.0-preview.8" end }
C_DamageMeter = {}
local secret, restricted = {}, setmetatable({}, { __index = function() error("restricted table read") end })
function issecretvalue(value) return rawequal(value, secret) end
function canaccesstable(value) return not rawequal(value, restricted) end
for _, file in ipairs({ "Locale", "Encounter", "Ledger", "IssueReport" }) do
    assert(loadfile("NamesInRed/" .. file .. ".lua"))("NamesInRed", addon)
end

local aliases = { "Player-5566-000abcd", "Player-5566-000abce", "Player-5566-000abcf" }
local db = addon.Ledger.Open()
addon.Ledger.Add(db, aliases[2], "Private Rival")
local row = {
    kind = "COMBAT_END", session = 2, combatSequence = 3, time = 1800000010, uptime = 547.12,
    meterSessionID = 12, contactCount = 6, contacts = { { fullName = "Private Rival" } },
    status = { meter = "sampled", meterWindow = "eligible" },
    meter = {
        HealingDone = { resolution = { ["details-secret"] = 2, ["no-target"] = 3 } },
    },
    message = "Never export arbitrary chat",
}
local battle = {
    time = row.time, startedAt = row.time - 10, origin = "world", zone = "Duskwood", mapID = 47,
    allies = { { id = aliases[1], isSelf = true, name = "Private Self", level = 55, class = "MAGE" } },
    enemies = { { id = aliases[2], rivalID = aliases[2], name = "Private Rival", role = secret, level = secret },
        { id = aliases[3], name = "Private Helper", class = secret } },
    events = {
        { kind = "kill", actorID = aliases[1], targetID = aliases[2], offset = 1.2 },
        { kind = "revive", targetID = aliases[2], offset = 5 },
        { kind = "kill", actorID = aliases[2], targetID = aliases[1], offset = 6.1 },
    },
    rewards = { [aliases[2]] = { honorableKills = 1, honor = 5 } },
    observation = {
        playerState = "dead",
        segments = { { reportMeter = addon.ReportMeterSnapshot(row), actions = {
            { kind = "healing", actorID = aliases[3], targetID = aliases[2], count = 2 },
        }, contacts = restricted } },
        assessment = { first = { units = { [aliases[3]] = restricted } }, lastAction = secret, meterStatus = "sampled" },
    },
    resolution = { outcome = "win", reason = "opponents-eliminated", ending = "observed" },
}
addon.Ledger.SaveSkirmish(db, "world:17", battle)
local function Includes(text, part) assert(text:find(part, 1, true), part) end
local function Excludes(text, part) assert(not text:find(part, 1, true), part) end
local function Report(diagnostics) return addon.BuildIssueReport(db, diagnostics, "world:17") end
local general = addon.BuildIssueReport(db)
Includes(general, '"scope": "general"')
Includes(general, '"build": "70959"')
Includes(general, '"locale": "ruRU"')
Excludes(general, "world:17")
local report = Report({ rows = { row, { kind = "COMBAT_END", session = row.session,
    combatSequence = 4, time = row.time, uptime = row.uptime, status = { meter = "wrong-window" } }, secret } })
for _, part in ipairs({ '"id": "world:17"', '"origin": "Open World"', '"outcome": "win"', "opponents-eliminated",
    '"actor": "Player-3"', '"target": "Player-2"', '"killingBlows": 1', '"deaths": 1', '"honor": 5',
    '"section": "linkedDebug"', "details-secret", "exact-combat-window", '"zone": "Duskwood"' }) do
    Includes(report, part)
end
for _, part in ipairs({ "Private", "Never export", "wrong-window", unpack(aliases) }) do Excludes(report, part) end
Includes(Report({ rows = { row, row } }), '"availability": "ambiguous"')
local previous = db
db = addon.Ledger.Open(previous)
local expired = Report()
Includes(expired, "retained-row-unavailable")
Includes(expired, "details-secret")
Excludes(expired, "linkedDebug")
assert(previous == db and db.skirmishes["world:17"] == battle and #battle.events == 3)
assert(addon.Ledger.PersonalCombatScore(db, aliases[2]) == 1)
local missing = addon.BuildIssueReport(db, nil, "world:400")
Includes(missing, '"availability": "missing"')

local encounter = { manual = true, direction = "killsAgainstThem", sequence = 32, recordedAt = 1800000010 }
db.rivals[aliases[2]].encounters = { encounter }
addon.db = db
local legacy = addon.LegacyReportRef(aliases[2], encounter)
local old = addon.BuildIssueReport(db, nil, nil, legacy)
Includes(old, '"id": "legacy:32"')
Includes(old, "manual-outcome")
Includes(old, "no-linked-segments")
Excludes(old, "Private Rival")
Excludes(old, "killingBlows")
local recent, refs = addon.RecentSkirmishes(db, 10)
assert(refs[recent[1]] == "world:17" or refs[recent[2]] == "world:17")
local fullManual = type(refs[recent[1]]) == "table" and refs[recent[1]] or refs[recent[2]]
assert(addon.BuildIssueReport(db, nil, nil, fullManual) == old)

local large = { origin = "battleground", observation = { segments = {} }, allies = {}, enemies = {}, events = {} }
for i = 1, 215 do
    large.enemies[i] = { id = "Player-5566-secret" .. i }
    large.events[i] = { actorID = aliases[1], targetID = large.enemies[i].id, kind = "kill", offset = i }
    large.observation.segments[i] = { actions = large.events }
end
db.skirmishes["bg:20"] = large
local bounded = addon.BuildIssueReport(db, nil, "bg:20")
Includes(bounded, '"origin": "Battleground"')
Includes(bounded, '"truncatedSections": "')
Includes(bounded, "event,")
assert(#bounded <= 24576 and bounded:sub(-4) == "\n```")

local widgets = {}
local function Widget(parent)
    local widget = { parent = parent, scripts = {}, hooks = {} }
    function widget:GetParent() return self.parent end
    function widget:GetName() return self.name end
    function widget:CreateFontString() return Widget(self) end
    function widget:SetScript(key, callback) self.scripts[key] = callback end
    function widget:HookScript(key, callback) self.hooks[key] = callback end
    function widget:SetText(value) self.text = value end
    function widget:SetFocus() self.focus = true end
    function widget:ClearFocus() self.focus = false end
    function widget:HighlightText() self.selected = true end
    return setmetatable(widget, { __index = function(_, key) if key:match("^%u") then return function() end end end })
end
function CreateFrame(kind, name, parent, template)
    local widget = Widget(parent)
    widget.name = name
    widgets[#widgets + 1] = widget
    if template == "InputScrollFrameTemplate" then widget.EditBox, widget.CharCount = Widget(widget), Widget(widget) end
    return widget
end
function ButtonFrameTemplate_HidePortrait() end
UISpecialFrames, tinsert = {}, table.insert
addon.OpenIssueReport("bg:20")
local window, input, select, link = unpack(widgets)
assert(input.EditBox.text == bounded and select.text == addon.L.issueSelectReport)
select.scripts.OnClick()
assert(input.EditBox.focus and input.EditBox.selected)
link.hooks.OnEditFocusGained(link)
assert(link.selected and link.text:find("/issues/new?template=bug_report.md", 1, true))
input.EditBox.hooks.OnTextChanged(input.EditBox, true)
assert(input.EditBox.text == bounded)
addon.OpenIssueReport()
assert(#widgets == 4 and input.EditBox.text == addon.BuildIssueReport(db))
assert(UISpecialFrames[1] == window.name)
print("Issue report selection, stable record identity, reload, diagnostics, privacy and size checks passed")
