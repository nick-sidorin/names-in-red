-- Synthetic terminal local death for focused evidence and UI tests.
return function(me, rival)
    local death = { kind = "death", offset = 25.002, time = 125, targetID = me, source = "unit-flags" }
    local segment = { startedAt = 100, duration = 25.002, endReason = "local-combat-ended",
        meter = { selection = "current-fallback" }, combatAggregates = {}, actions = {},
        reportMeter = { status = "sampled", meterSelection = "current-fallback",
            categories = { DamageTaken = { evidence = "eligible", counts = { link = 8, ["source-connected"] = 1 } } } } }
    for _, amount in ipairs({ 716, 402, 339, 324, 156, 115 }) do
        table.insert(segment.combatAggregates, { category = "DamageTaken", actorID = rival, targetID = me, amount = amount })
    end
    return {
        startedAt = 100, time = 125, origin = "world", rosterComplete = false,
        allies = { { id = me, isSelf = true } },
        enemies = { { id = rival, rivalID = rival, name = "Mock Warlock", class = "WARLOCK" } },
        events = { death },
        personalOutcome = { version = 3, lifecycle = "finalized", outcome = "unknown", finalizedBy = "historical" },
        rewards = { [rival] = { honor = 5, honorableKills = 1 } },
        observation = {
            segments = { segment },
            assessment = {
                interrupted = "area-changed",
                first = { offset = 26.274, units = { [me] = { dead = true }, [rival] = { dead = false, combat = true } } },
                last = { offset = 28.277, units = { [me] = { dead = true } } },
            },
            life = {
                { state = "dead", source = "player-dead", offset = 25.002 },
                { state = "ghost", offset = 50.371 },
                { state = "alive", offset = 79.623 },
            },
        },
    }, segment, death
end
