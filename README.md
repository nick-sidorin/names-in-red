# Names in Red

A personal PvP journal for World of Warcraft: Forever. Remember who you fought,
what happened, and where you last met.

Names in Red targets Forever 1.60.1 (interface 16001). Click the crossed swords
on the minimap to browse rivals. Information shows your personal score and the
latest skirmish. The Skirmishes tab lists that rival's recorded history, newest
first. Compact cards show both portraits and levels. Crossed swords and skulls
mark confirmed wins and deaths. Hover over a center icon for the personal result.
Alliance is blue and Horde is red. Use the information icon on a linked card
to see both sides, levels, classes, and the finishing blows
in the same window. **Back** returns to the rival and the same place in their
history. The side tab shows the latest 100 skirmishes across all opponents using
the same two-sided layout for both battle records and earlier individual
encounters. The header shows the number of recorded participants on each side.
An information icon beside those counts explains when the full team sizes are
unconfirmed. Older saved battles can still open from a rival's history.
The map pin places a waypoint when the saved location supports one. Known
rivals show the same score in the standard unit tooltip.

Download the latest ZIP from [Releases](https://github.com/nick-sidorin/names-in-red/releases)
and extract `NamesInRed/` into `_forever_/Interface/AddOns/`.

## Settings

Right-click the minimap icon or open **Options → AddOns → Names in Red**.
Nameplate icons and unit tooltip information are enabled by default and can
be toggled independently. **Reset data** confirms before deleting the current
character's rivals, skirmishes and diagnostic logs. Display preferences and
the minimap icon position are kept. **Report an issue** shows a copyable link
to [GitHub Issues](https://github.com/nick-sidorin/names-in-red/issues).

## How the personal score works

- **Win.** You landed the confirmed finishing blow or contributed to this
  opponent's death in the same skirmish.
- **Loss.** This opponent landed the confirmed finishing blow or contributed
  to your death in the same skirmish. Each confirmed attacker can add a loss
  to their own profile.
- Confirmed contributions count even if the contributor dies before the
  finishing blow. If you wound an opponent, they kill you, and your brother
  finishes them, you gain one win and one loss against that same opponent.
  The timeline credits the finishing blow to your brother.
- Each death counts once per credited rival. The score requires evidence of
  participation in that specific kill. The history can also show battles with
  no confirmed contribution.

The score describes your history with each rival. Honor awards and the outcome
of an entire battle or battleground follow the game's own rules. Existing
confirmed solo records and manually chosen results still count. Use **Add**
to enter a full character name and choose the outcome manually.
Deleting a rival clears their profile and personal history. Shared battles
remain in the journal with their recorded participants and timeline.

## Development

Run `bash scripts/check.sh` with Python 3, Bash, `lua5.1` and `luac5.1` installed.
GitHub Actions runs the same suite. For a developer smoke test, copy the
`NamesInRed/` folder into `_forever_/Interface/AddOns/`. See
[Forever validation](docs/forever-validation.md) for gameplay research and the
client test matrix. See [idea.md](idea.md) for the full scope.

The scoring logic consumes normalized, chronologically ordered confirmed PvP
deaths. Each death has one `kind = "kill"` event with a local `targetID`. Set
`actorID` only for a confirmed finishing blow. The optional `contributors` map
uses local participant IDs as keys. Store `true` for a confirmed contribution
to that death. Older preview records use `false` for confirmed contributors who
were already dead. Both values qualify. Omit entries for unconfirmed
contributions. Mark the local player `isSelf` in the allies roster. An
opponent's `rivalID` links the battle to their
profile. Re-saving the same battle ID replaces its results. Record each death
once, either in a battle or through the existing single-rival recording path.

The preview seeds exercise these rules. Automatic recording still uses the
existing confirmed kill and death paths. The diagnostics collect evidence for
connecting live team fights to the new model.

The pinned [WoW Addon Standards](docs/standards/AGENTS.md) are used for development
and are outside the installable addon folder.
