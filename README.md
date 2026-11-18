# Names in Red

A personal rival ledger for World of Warcraft: Forever. The goal is to remember
who killed your character and whom your character killed, then recognize those
rivals in the game world.

The foundation targets Forever 1.60.1 (interface 16001). It initializes a local
ledger with separate death and kill totals. The ledger is per character in
this preview. Gameplay detection and player-facing UI are planned. Live client
compatibility is pending.

See [PvP diagnostics preview](docs/debug-preview.md) for capture and installation.

## Development

Run `bash scripts/check.sh` with Python 3, Bash, `lua5.1` and `luac5.1` installed.
GitHub Actions runs the same suite. For a developer smoke test, copy the
`NamesInRed/` folder into `_forever_/Interface/AddOns/`. See
[Forever validation](docs/forever-validation.md) for gameplay research and the
client test matrix. See [idea.md](idea.md) for the full scope.

The pinned [WoW Addon Standards](docs/standards/AGENTS.md) are used for development
and are outside the installable addon folder.
