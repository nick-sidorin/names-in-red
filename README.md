# Names in Red

A personal PvP journal for World of Warcraft: Forever. Remember who you fought,
what happened, and where you last met.

Names in Red targets Forever 1.60.1 (interface 16001). Click the crossed swords
on the minimap to browse rivals. Information shows your personal score and the
latest skirmish. The Skirmishes tab lists that rival's recorded history, newest
first. Use **Open skirmish** on a linked card to see both sides, levels, classes,
and the finishing-blow timeline in the same window. **Back** returns to the rival
and the same place in their history. The side tab shows the latest 100 skirmishes
across all opponents. Older saved battles can still open from a rival's history.
**Show on map** places a waypoint when the saved location supports one. Known
rivals show the same score in the standard unit tooltip.

Download the latest ZIP from [Releases](https://github.com/nick-sidorin/names-in-red/releases)
and extract `NamesInRed/` into `_forever_/Interface/AddOns/`.

## How the personal score works

- **Win.** You contributed to this opponent's confirmed PvP death and were
  alive when they died. An ally can land the finishing blow.
- **Loss.** This opponent contributed damage to your confirmed PvP death and
  was alive when you died. Several opponents can receive credit for the same
  death. Each adds a loss in your personal score with them.
- A later death leaves earlier results intact. If your brother finishes an orc
  you wounded and a shaman kills you afterwards, the orc's profile gains a win
  and the shaman's profile gains a loss. The battle shows both finishing blows
  with their actual authors.
- Participation alone puts a battle in a known rival's history. When there is
  insufficient evidence about a specific death or who was alive at that moment,
  the corresponding tally stays unchanged.

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
deaths. Each death has one `kind = "kill"` event with a local `targetID`, an
optional finishing-blow `actorID`, and an optional `contributors` map keyed by
local participant ID. `true` identifies a confirmed contributor who was alive
at that death. `false` identifies a confirmed contributor who was already dead.
Omit an entry when either part of the evidence is missing. Mark the local player
`isSelf` in the allies roster. An opponent's `rivalID` links the battle to their
profile. Re-saving the same battle ID replaces its results. Record each death
once, either in a battle or through the existing single-rival recording path.

The preview seeds exercise these rules. Automatic recording still uses the
existing confirmed kill and death paths. The diagnostics collect evidence for
connecting live team fights to the new model.

The pinned [WoW Addon Standards](docs/standards/AGENTS.md) are used for development
and are outside the installable addon folder.
