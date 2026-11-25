# Names in Red

A personal PvP journal for World of Warcraft: Forever. Remember who you fought,
what happened, and where you last met. Every rival has a story.

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
Version 2.0.0 introduces [Character POV](docs/skirmish-product-spec.md).

- The full skirmish card shows your character's result. A confirmed ending can
  be **Victory**, **Defeat** or **Draw**. Open fights show **In progress**.
  **Unknown** preserves a fight whose ending could not be determined.
- Rival wins and losses count credited participation in confirmed death
  episodes. Damage, relevant healing, shielding and control can count.
  Activity from a pet can count when its owner is verified. Each enemy you
  helped defeat adds a win against that rival, and each rival who helped
  defeat you adds a loss to your score against them. A revival can make a later death count
  separately. The nameplate, tooltip, compact card and profile show that score.
- Direct killing blows and deaths, **Honorable Kills** and **Honor Points**
  keep their own counters. Original historical and manual entries stay in the
  journal. Older side results carry their historical scope.

Deleting a rival clears their profile and its statistics. Shared battles
remain in the journal with their recorded participants and timeline.

## Development

The [PvP skirmish product specification](docs/skirmish-product-spec.md)
describes participation, outcomes and battleground behavior.

Use **Report an issue** in the journal header or addon settings, or click the
bug icon on a skirmish to prepare a report for that fight. Open the form
from the link, click **Select Report**, then copy and paste the report once.
Review the pasted report before posting.
Participant aliases replace character names and GUIDs in the report. Names in
Red saves bounded combat evidence automatically, so it can be reported after
a reload. The report identifies any sections shortened to fit the issue form.
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
color after an observed revival. Rival tooltips show the personal rival win/loss score based on confirmed
contribution, not literal killing blows. Skirmish outcomes, direct-player
kills/deaths and Blizzard rewards are distinct.
Mark the local player `isSelf` and identify profile links with `rivalID`.
Store `honorableKills` and `honor` under `rewards[opponent.id]`. Re-saving
the same skirmish ID replaces the indexed result and rewards.

Live open-world capture can record a skirmish with zero kills or rewards
when a readable harmful effect or a confirmed directed damage pair establishes
that the player was involved. Observed local combat windows can join one record
if a corroborating hostile action links them. The preview checks specific
damage, healing, absorb, interrupt and dispel links when the meter supplies
both identities. It can credit a pet with a confirmed owner. Nearby sightings,
group membership alone and unnamed meter totals do not establish participation.
At death, visible nameplates can supply details when the target and mouseover
are unavailable. For live records, `rosterComplete` still covers observed
one-on-one kills and is recalculated at load and on each save.
Rival-specific honor correlation uses a linked kill or an independently
confirmed opponent death with a single increase in the session honorable kill
count. For an actorless death, a unique readable honor award must match that
death in the same combat window. A late-confirmed combat window can receive
awards originally saved in the journal's internal totals when their window
is unambiguous. Unmatched awards remain in saved accounting and diagnostics. The
seeded preview exercises completed outcomes and attributed rewards.

The pinned [WoW Addon Standards](docs/standards/AGENTS.md) are used for development
and are outside the installable addon folder.

### Release packaging

After final product and technical approval, choose **Publish release → Run workflow**
on the main branch with the version (e.g. 2.0.0) and the approved 40-character
main commit SHA, or merge a separate PR that changes only
`.github/release-request.json` with exactly those two fields:

```json
{"version":"2.0.0","commit":"<approved 40-character SHA>"}
```

The permanent [publisher](.github/workflows/release.yml) accepts only the
repository owner (including a retry), on this repository. It requires
successful main-push CI for the exact target, reruns the suite and verifies
the package before creating a missing tag and publishing. It refuses to move
existing tags and verifies existing assets on retry. A manually pushed stable
tag by the owner is also supported. No per-release workflow or personal token
is necessary for a checked main target with current workflow files. Creating a
historical ref with different workflows can require additional permissions;
if denied, stop and ask the owner to create the tag. Never silently retarget
or move a published tag. Ordinary PR checks and unrelated main changes do not publish.
Repository write/admin access must remain restricted; workflow guards do not
replace branch/tag access control.
The existing CurseForge source packager uses `.pkgmeta`. Verify the
CurseForge file and game version separately after publication.
