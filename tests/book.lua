local addon, callback, locale = { db = { rivals = {} } }, nil, "enUS"
function GetLocale() return locale end
function CreateFrame()
    return { RegisterEvent = function() end, SetScript = function() end }
end

local totalLines = 0
GameTooltip = {
    AddLine = function(_, text)
        assert(type(text) == "string" and text ~= "")
        totalLines = totalLines + 1
    end,
}
Enum = { TooltipDataType = { Unit = 2 } }
TooltipDataProcessor = {
    AddTooltipPostCall = function(kind, handler)
        assert(kind == Enum.TooltipDataType.Unit)
        callback = handler
    end,
}

for _, supported in ipairs({
    "enUS", "enGB", "ruRU", "deDE", "frFR", "esES", "esMX", "itIT", "ptBR", "koKR", "zhCN", "zhTW",
}) do
    locale = supported
    assert(loadfile("NamesInRed/Locale.lua"))("NamesInRed", addon)
    for _, key in ipairs({ "book", "kills", "deaths", "empty", "level" }) do
        assert(type(addon.L[key]) == "string" and addon.L[key] ~= "")
    end
end

local secret = {}
function issecretvalue(value) return value == secret end
assert(loadfile("NamesInRed/Encounter.lua"))("NamesInRed", addon)
assert(loadfile("NamesInRed/Book.lua"))("NamesInRed", addon)
addon.db.rivals["Player-test"] = { killsAgainstThem = 2, deathsToThem = 1 }
addon.db.rivals["Player-empty"] = { killsAgainstThem = 0, deathsToThem = 0 }
callback(GameTooltip, { guid = secret })
callback(GameTooltip, { guid = "Player-unknown" })
callback(GameTooltip, { guid = "Player-empty" })
callback({}, { guid = "Player-test" })
assert(totalLines == 0)
callback(GameTooltip, { guid = "Player-test" })
assert(totalLines == 2)
print("Rival tooltip and locale checks passed")
