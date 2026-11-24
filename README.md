# Names in Red

A personal PvP journal for World of Warcraft: Forever. Remember who you fought,
what happened, and where you last met.

Names in Red targets Forever 1.60.1 (interface 16001). Click the crossed swords
on the minimap to browse rivals. Information shows your skirmish stats and the
latest skirmish. The Skirmishes tab lists that rival's recorded history, newest
first. Both card layouts show portraits with class and recorded level badges.
Full names can wrap to two lines. Both layouts show a circular result badge
with a caption, using crossed swords for a victory and a torn gray banner on a
broken pole for a defeat. The defeat count uses a square version on a painted
background. A small
skull on a portrait marks a recorded death. Honorable Kills uses a gold chevron
for both factions. The Honor Points counter uses the Currency tab's icon.
Alliance is blue and Horde is red. Use the information icon on a linked card
to see both sides, levels, classes, and the finishing blows
in the same window. **Back** returns to the rival and the same place in their
history. The side tab shows the latest 100 skirmishes across all opponents using
the same two-sided layout for both battle records and earlier individual
encounters. The full card groups portraits in centered rows beneath the game's
PvP faction emblems. The outcome has a circular frame and label between the
sides. Expand **Finishing blows** to see the recorded kills in order. The header
shows the number of recorded participants on each side.
Cards show a rival's level when an observation from that fight is available.
An information icon beside those counts explains when the full team sizes are
unconfirmed. Rivals and skirmishes stay saved indefinitely, including the
core timeline and linked Damage Meter aggregates. Older battles remain
available in each rival's history after diagnostic data is compacted.
The map pin places a waypoint when the saved location supports one. Known
rivals show the same score in the standard unit tooltip.

The interface follows the language selected in World of Warcraft. It supports
English, German, Spanish, French, Italian, Korean, Brazilian Portuguese,
Russian, Simplified Chinese, and Traditional Chinese.

Download the latest ZIP from [CurseForge](https://www.curseforge.com/wow/addons/names-in-red/files/all)
and extract `NamesInRed/` into `_forever_/Interface/AddOns/`.

## Settings

Right-click the minimap icon or open **Options → AddOns → Names in Red**.
Nameplate icons and unit tooltip information are enabled by default and can
be toggled independently. **Reset data** confirms before deleting the current
character's rivals, skirmishes and diagnostic logs. Display preferences and
the minimap icon position are kept. **Track Battleground Skirmishes** is on
by default. Turn it off to stop recording new battleground activity while
keeping previous records and recognizing familiar rivals.

## Chat commands

Enter these commands in the in-game chat box.

| Command | What it does |
| --- | --- |
| `/nirreset` | Opens **Reset data**. Confirm to delete the current character's rivals, skirmishes, manual entries, demo data and diagnostic log. Display preferences and the minimap icon position are kept. |
| `/nirdebug` | Prints the number of retained and dropped diagnostic records and the session number. |
| `/nirdebug sample` | Adds a diagnostic snapshot of the current target, mouseover, honorable kill totals and available PvP scoreboard data. |
| `/nirdebug seed` | Adds or refreshes the demo rivals and skirmishes for screenshots. |
| `/nirdebug clear-seed` | Removes the demo rivals and skirmishes. Recorded and manually added entries are kept. |
| `/nirdebug faction alliance` | Replaces the demo data with an Alliance playthrough. |
| `/nirdebug faction horde` | Replaces the demo data with a Horde playthrough. |
| `/nirdebug faction auto` | Rebuilds demo data for the current character's faction, just like `/nirdebug seed`. |

See [diagnostics and sample data](docs/debug-preview.md) for details.

## How the score works

The journal records local fights in the open world and on battlegrounds.
Battleground cards label their origin and use the same rival profiles.
A battleground fight can have a different result from the overall match.
The [PvP skirmish product specification](docs/skirmish-product-spec.md)
describes the approved next Character POV model. The score below describes
**shipped 1.1.0 behavior**, not that future model. See [project context](PROJECT_CONTEXT.md)
for the handoff.

- **Wins** and **Losses** count the result of your side.
  A recorded result counts once in the journal and once in each opponent's
  profile. If you die and your surviving teammate finishes the opposing
  side, it counts as one win against every opponent in the battle.
- In open-world history, a direct fight between you and the only recorded
  opponent counts as a duel. If another participant is recorded in the same
  fight, the result is recalculated using the larger roster.
- A skirmish receives a result when terminal observations support a
  side. A confirmed departure under pressure can count with zero kills.
  Unknown stays in history without contributing a win or loss. Older
  recorded and manually entered results stay available.
- **Honorable Kills** and **Honor Points** show how much the game awarded you for
  identifiable opponents. Both skirmish card sizes show the totals for the
  whole fight. An award may count even when the team outcome is unknown.
  Shared or closely spaced signals can leave a reward unattributed.

Deleting a rival clears their profile and its statistics. Shared battles
remain in the journal with their recorded participants and timeline.

## Development

The [PvP skirmish product specification](docs/skirmish-product-spec.md)
describes the target participation, outcome and battleground behavior for future development.

Use **Report an issue** in the journal header or addon settings, or click the
bug icon on a skirmish to prepare a report for that fight. Copy the report and
the GitHub issue link from the dialog, then review the report before posting.
Participant aliases replace character names and GUIDs in the report. Names in
Red saves bounded combat evidence automatically, so it can be reported after
a reload. Use **Next part** if the report offers additional pages.
You can optionally attach the existing `NamesInRed.lua` SavedVariables file
for more detail. That file may contain character names and GUIDs and is
public when attached to a public issue.

[CurseForge listing Markdown](docs/curseforge-description.md) and
[short description](docs/curseforge-summary.txt) are ready to copy into the
[CurseForge description editor](https://authors.curseforge.com/#/projects/1819566/description).

Run `bash scripts/check.sh` with Python 3, Bash, `lua5.1` and `luac5.1` installed.
GitHub Actions runs the same suite. For a developer smoke test, copy the
`NamesInRed/` folder into `_forever_/Interface/AddOns/`. See
[Forever validation](docs/forever-validation.md) for gameplay research and the
client test matrix. See [Future ideas](docs/future-ideas.md) for
optional, uncommitted features such as PvP ranks and achievements.

Each skirmish owns its roster, timeline and rewards. Explicit and older
results keep their existing interpretation. New world records derive
`resolution` from their observed ending. Life state and observation
coverage are stored separately. A `kind = "revive"` event marks a later
readable living state for the same character and preserves the killing
blow. The skull marks a death during the fight. The portrait returns to
color after an observed revival. Rival tooltips show a separate personal
kill/death score. Skirmish wins/losses and Blizzard rewards have their own
counters.
Mark the local player `isSelf` and identify profile links with `rivalID`.
Store `honorableKills` and `honor` under `rewards[opponent.id]`. Re-saving
the same skirmish ID replaces the indexed result and rewards.

Live open-world capture can record a skirmish with zero kills or rewards
when a readable harmful effect or post-combat link establishes that the
player was involved. Observed local combat windows can join one record
if a corroborating hostile action links them. The preview checks specific
damage, healing, absorb, interrupt and dispel links when the meter supplies
both identities. It can credit a pet with a confirmed owner. Nearby sightings,
group membership alone and unnamed meter totals do not establish participation.
At death, visible nameplates can supply details when the target and mouseover
are unavailable. For live records, `rosterComplete` still covers observed
one-on-one kills and is recalculated at load and on each save.
Honor correlation uses one readable
opponent death and a single increase in the session honorable kill count.
An honor amount also requires one award message and a readable amount from
that message or a matching honor currency update. Ambiguous broadcasts
remain in diagnostics. Rewards are collected for new observations. The
seeded preview exercises completed outcomes and attributed rewards.

The pinned [WoW Addon Standards](docs/standards/AGENTS.md) are used for development
and are outside the installable addon folder.
