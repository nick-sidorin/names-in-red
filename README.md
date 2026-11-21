# Names in Red

A personal PvP journal for World of Warcraft: Forever. Remember who you fought,
what happened, and where you last met.

Names in Red targets Forever 1.60.1 (interface 16001). Click the crossed swords
on the minimap to browse rivals. Information shows your skirmish stats and the
latest skirmish. The Skirmishes tab lists that rival's recorded history, newest
first. Compact cards show both portraits and levels. Both card layouts show
crossed swords for a victory and a torn gray banner for a defeat. The defeat
count uses a square version of the banner on a painted background. A small
skull on a portrait marks a recorded death. The reward icons use the current
character's faction.
Alliance is blue and Horde is red. Use the information icon on a linked card
to see both sides, levels, classes, and the finishing blows
in the same window. **Back** returns to the rival and the same place in their
history. The side tab shows the latest 100 skirmishes across all opponents using
the same two-sided layout for both battle records and earlier individual
encounters. The full card shows the game's PvP faction emblems beside the side
headings. The header shows the number of recorded participants on each side.
If a rival's level was unavailable in one fight, `~` marks the last known level
from their history.
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

## How the score works

- **Skirmishes won** and **Skirmishes lost** count the result of your side.
  A recorded result counts once in the journal and once in each opponent's
  profile. If you die and your surviving teammate finishes the opposing
  side, it counts as one win against every opponent in the battle.
- In open-world history, a direct fight between you and the only recorded
  opponent counts as a duel. If another participant is recorded in the same
  fight, the result is recalculated using the larger roster.
- A skirmish with an unknown outcome stays in the history. The score changes
  once the outcome is known. Older records of individual killing blows and
  deaths stay visible. Manually entered results still count.
- **Honorable kills** and **Honor** show how much the game awarded you for
  identifiable opponents. An award may count even when the team outcome is
  unknown. Shared or closely spaced signals can leave a reward unattributed.

Deleting a rival clears their profile and its statistics. Shared battles
remain in the journal with their recorded participants and timeline.

## Development

Run `bash scripts/check.sh` with Python 3, Bash, `lua5.1` and `luac5.1` installed.
GitHub Actions runs the same suite. For a developer smoke test, copy the
`NamesInRed/` folder into `_forever_/Interface/AddOns/`. See
[Forever validation](docs/forever-validation.md) for gameplay research and the
client test matrix. See [idea.md](idea.md) for the full scope.

Each skirmish owns its roster, timeline and rewards. Store an explicit
`outcome` of `"win"` or `"loss"` when known. Otherwise a complete roster
allows inference if exactly one side ends fully eliminated. A
`kind = "revive"` event restores the participant for outcome calculation.
Mark the local player `isSelf` and identify profile links with `rivalID`.
Store `honorableKills` and `honor` under `rewards[opponent.id]`. Re-saving
the same skirmish ID replaces the indexed result and rewards.

Live open-world capture groups readable player kills and local death recaps
within the observed combat window. A current party member's finishing blow
can add that ally to the roster. At death, visible nameplates can supply
participant details when the target and mouseover are unavailable. For live
records, `rosterComplete` also covers observed duels. It is recalculated at
load and on each save. Honor correlation uses one readable
opponent death and a single increase in the session honorable kill count.
An honor amount also requires one award message and a readable amount from
that message or a matching honor currency update. Ambiguous broadcasts
remain in diagnostics. Rewards are collected for new observations. The
seeded preview exercises completed outcomes and attributed rewards.

The pinned [WoW Addon Standards](docs/standards/AGENTS.md) are used for development
and are outside the installable addon folder.
