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
    '"section": "meterSnapshot"', "details-secret", "exact-combat-window", '"zone": "Duskwood"' }) do
    Includes(report, part)
end
for _, part in ipairs({ "Private", "Never export", "wrong-window", unpack(aliases) }) do Excludes(report, part) end
Includes(Report({ rows = { row, row } }), '"availability": "ambiguous"')
local previous = db
db = addon.Ledger.Open(previous)
local expired = Report()
Includes(expired, "retained-row-unavailable")
Includes(expired, "details-secret")
local _, snapshots = report:gsub('"section": "meterSnapshot"', "")
assert(snapshots == 1)
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

-- Replay a saved assisted win alongside the rival's finishing blow against
-- us. The old side Victory remains visible independently of the POV Defeat.
for _, file in ipairs({ "SkirmishDeathEvidence", "PersonalSkirmishOutcomes", "RivalContributions" }) do
    assert(loadfile("NamesInRed/" .. file .. ".lua"))("NamesInRed", addon)
end
local helper = aliases[3]
local scopeBattle = {
    time = row.time, startedAt = row.time, outcome = "win",
    personalOutcome = { version = 2, lifecycle = "finalized", outcome = "loss", reason = "terminal-personal-death",
        coverage = "partial", casualties = { friendly = 1, enemy = 1 } },
    allies = { { id = aliases[1], isSelf = true }, { id = helper } },
    enemies = { { id = aliases[2], rivalID = aliases[2] } },
    events = { { kind = "kill", actorID = helper, targetID = aliases[2], offset = 4 },
        { kind = "revive", targetID = aliases[2], offset = 5 },
        { kind = "kill", actorID = aliases[2], targetID = aliases[1], offset = 7 } },
    observation = { segments = { { offset = 1, duration = 3, contributionLinks = {
        { category = "HealingDone", actorID = aliases[1], targetID = helper },
    } } } },
}
addon.Ledger.SaveSkirmish(db, "world:18", scopeBattle)
addon.Ledger.RivalContributionScore(db, aliases[2])
local projected = addon.BuildIssueReport(db, nil, "world:18")
for _, part in ipairs({ '"outcome": "loss"', '"outcomeScope": "personal"', '"legacyOutcome": "win"',
    '"section": "personalOutcome"', '"coverage": "partial"', '"friendlyDeaths": 1', '"enemyDeaths": 1',
    '"section": "rivalContribution"', '"credits": 2', '"section": "rivalCredit"', '"deathIndex": 1',
    '"kind": "support"', '"category": "HealingDone"', '"supported": "Player-2"',
    '"supportedEvidence": "finishing-blow"', '"deathIndex": 3', '"direction": "loss"' }) do
    Includes(projected, part)
end
for line in projected:gmatch("[^\n]+") do
    if line:find('"kind": "support"', 1, true) then
        Excludes(line, '"offset":')
        Excludes(line, '"eventTime":')
    end
end
for _, id in ipairs(aliases) do Excludes(projected, id) end
scopeBattle.personalOutcome = { version = 2, lifecycle = "awaiting" }
Includes(addon.BuildIssueReport(db, nil, "world:18"), '"outcome": "ongoing"')
local direct = { direction = "killsAgainstThem", time = 80 }
db.rivals[aliases[2]].encounters[2] = direct
local directional = addon.BuildIssueReport(db, nil, nil, addon.LegacyReportRef(aliases[2], direct))
Includes(directional, '"section": "rivalCredit"')
Includes(directional, '"kind": "finishing-blow"')
Includes(directional, '"outcomeScope": "unavailable"')

local large = { origin = "battleground", observation = { segments = {} }, allies = {}, enemies = {}, events = {} }
for i = 1, 92 do
    large.enemies[i] = { id = "Player-5566-secret" .. i }
    large.events[i] = { actorID = aliases[1], targetID = large.enemies[i].id, kind = "kill", offset = i }
    large.observation.segments[i] = { actions = large.events }
end
db.skirmishes["bg:20"] = large
local bounded = addon.BuildIssueReport(db, nil, "bg:20")
Includes(bounded, '"origin": "Battleground"')
Includes(bounded, '"truncatedSections": "')
Includes(bounded, '"transport": "github-issue-budget"')
Includes(bounded, '"section": "rewardTotal"')
Includes(bounded, '"section": "personalOutcome"')
assert(#bounded > 24576 and #bounded <= 60 * 1024 and bounded:sub(-4) == "\n```")

local widgets = {}
local function Widget(parent)
    local widget = { parent = parent, scripts = {}, hooks = {}, points = {}, labels = {} }
    function widget:GetParent() return self.parent end
    function widget:GetName() return self.name end
    function widget:CreateFontString(_, _, font)
        local label = Widget(self)
        label.font = font
        self.labels[#self.labels + 1] = label
        return label
    end
    function widget:SetPoint(anchor, ...)
        self.points[anchor] = { ... }
    end
    function widget:SetScript(key, callback) self.scripts[key] = callback end
    function widget:HookScript(key, callback) self.hooks[key] = callback end
    function widget:SetText(value) self.text = self.capacity and value:sub(1, self.capacity) or value end
    function widget:GetText() return self.text end
    function widget:SetSize(width, height) self.width, self.height = width, height end
    function widget:SetWidth(width) self.width = width end
    function widget:SetNonSpaceWrap(enabled) self.nonSpaceWrap = enabled end
    function widget:SetShown(value) self.visible = value end
    function widget:SetFocus() self.focus = true end
    function widget:ClearFocus() self.focus = false end
    function widget:SetVerticalScroll(value) self.vertical = value end
    function widget:SetCursorPosition(value) self.cursor = value end
    function widget:HighlightText(first, last)
        self.selected = (not first and not last) and self.text or nil
    end
    return setmetatable(widget, { __index = function(_, key) if key:match("^%u") then return function() end end end })
end
function CreateFrame(kind, name, parent, template)
    local widget = Widget(parent)
    widget.name = name
    widget.template = template
    widgets[#widgets + 1] = widget
    if template == "InputScrollFrameTemplate" then
        widget.EditBox, widget.CharCount = Widget(widget), Widget(widget)
    elseif template == "SharedButtonSmallTemplate" then
        widget.SetTextToFit = widget.SetText
    end
    return widget
end
function ButtonFrameTemplate_HidePortrait() end
UISpecialFrames, tinsert = {}, table.insert
addon.OpenIssueReport("bg:20")
local window, link, select, input = unpack(widgets)
local linkHint, reportHint, savedVariablesHint = unpack(window.labels)
assert(window.template == "PortraitFrameTemplate")
assert(window.width == 660 and window.height == 320 and input.EditBox.width == 594)
assert(select.template == "SharedButtonSmallTemplate")
assert(linkHint.text == "Перейди на форму по ссылке и напиши о проблеме")
assert(reportHint.text == "Отправь мне этот код с информацией о стычке")
assert(linkHint.font == "GameFontHighlight" and reportHint.font == "GameFontHighlight")
assert(savedVariablesHint.font == reportHint.font)
assert(savedVariablesHint.nonSpaceWrap == false)
assert(link.points.TOPLEFT[1] == linkHint and reportHint.points.TOPLEFT[1] == link)
assert(input.points.TOPLEFT[1] == reportHint)
assert(link.template == "InputBoxTemplate" and input.template == "InputScrollFrameTemplate")
assert(input.EditBox.text == bounded and select.text == addon.L.issueSelectReport)
Includes(savedVariablesHint.text, "в папке World of Warcraft")
Includes(savedVariablesHint.text, [[_forever_\WTF\Account\<account>\<realm>\<character>\SavedVariables\NamesInRed.lua]])
Includes(savedVariablesHint.text, "как есть")
Includes(savedVariablesHint.text, "GUID")
Excludes(savedVariablesHint.text, "/combatlog")
select.scripts.OnClick()
assert(input.EditBox.focus and input.EditBox.selected == bounded)
link.hooks.OnEditFocusGained(link)
assert(link.selected and link.text:find("/issues/new?template=bug_report.md", 1, true))
input.EditBox.hooks.OnTextChanged(input.EditBox, true)
assert(input.EditBox.text == bounded)
addon.OpenIssueReport()
assert(#widgets == 4 and input.EditBox.text == addon.BuildIssueReport(db))
-- The detailed sample and outcome share one document, even when low
-- priority action rows exhaust the GitHub budget.
large.combatDiagnostics = { version = 1, recaps = {}, windows = {
    { index = 1, streams = { aura = { rows = { { targetID = large.enemies[1].id, spellID = 327 } } } } },
} }
addon.OpenIssueReport("bg:20")
local single = input.EditBox.text
local _, reports = single:gsub('"section": "report"', "")
local _, samples = single:gsub('"spellID": 327', "")
assert(reports == 1 and samples == 1 and #single > 24576 and #single <= 60 * 1024)
Includes(single, '"scope": "skirmish"')
Includes(single, '"section": "combatWindow"')
Includes(single, '"truncatedSections": "action')
Excludes(single, '"scope": "combat-details"')
input:SetVerticalScroll(200)
select.scripts.OnClick()
assert(input.EditBox.selected == single and input.vertical == 200)
input.EditBox.hooks.OnEditFocusLost(input.EditBox)
assert(not input.EditBox.selected)

-- Re-export complete rows if an EditBox returns less text than it received.
input.EditBox.capacity = 32768
addon.OpenIssueReport("bg:20")
local clipped = input.EditBox.text
assert(#clipped <= input.EditBox.capacity and clipped:sub(-4) == "\n```")
Includes(clipped, '"transport": "editbox-capacity"')
Includes(clipped, '"section": "personalOutcome"')
select.scripts.OnClick()
assert(input.EditBox.selected == clipped and input.vertical == 0 and input.EditBox.cursor == 0)
input.EditBox.capacity = nil
addon.OpenIssueReport()
assert(#widgets == 4 and input.EditBox.text == addon.BuildIssueReport(db))

local rows = {}
for index = 1, 600 do rows[index] = { kind = "PVP_DECISION", time = index } end
local noRowLimit = addon.BuildIssueReport(db, { rows = rows })
local _, decisions = noRowLimit:gsub('"section": "recentDecision"', "")
assert(decisions == 600)
Includes(noRowLimit, '"omittedRows": 0')
assert(UISpecialFrames[1] == window.name)
print("Issue report selection, stable record identity, reload, diagnostics, privacy and size checks passed")
