# Names in Red

A personal rival ledger for World of Warcraft: Forever. The goal is to remember
who killed your character and whom your character killed, then recognize those
rivals in the game world.

Names in Red targets Forever 1.60.1 (interface 16001). It keeps separate
per-character totals for confirmed personal killing blows and single-attacker
deaths in open-world PvP. Click the crossed-swords icon on the minimap to browse rivals.
Information shows totals and the latest skirmish. Skirmishes lists the complete
recorded history, newest first. Cards show the date, zone, coordinates and levels
when available. The side tabs switch between the rival book and the latest
100 skirmishes across all opponents. Each identified opponent's card can open
the Information tab for that rival. Show on Map opens the world map with a waypoint when the
recorded location maps to a zone. Drag the window by its title.
Use Add to enter a full character name and select who won. A manual entry
keeps its chosen outcome and has no inferred battle details. Known rivals also have
history appended to the standard unit tooltip.

Download the latest ZIP from [Releases](https://github.com/nick-sidorin/names-in-red/releases)
and extract `NamesInRed/` into `_forever_/Interface/AddOns/`.

## Development

Run `bash scripts/check.sh` with Python 3, Bash, `lua5.1` and `luac5.1` installed.
GitHub Actions runs the same suite. For a developer smoke test, copy the
`NamesInRed/` folder into `_forever_/Interface/AddOns/`. See
[Forever validation](docs/forever-validation.md) for gameplay research and the
client test matrix. See [idea.md](idea.md) for the full scope.

The pinned [WoW Addon Standards](docs/standards/AGENTS.md) are used for development
and are outside the installable addon folder.
