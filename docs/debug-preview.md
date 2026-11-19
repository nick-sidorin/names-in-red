# PvP diagnostics preview

Install the ZIP by extracting its `NamesInRed/` folder into
`_forever_/Interface/AddOns/`. The AddOns list shows **Names in Red (Debug)**.
This is a temporary build for Forever 1.60.1. Collection starts at addon load
and works during ordinary play.

- `/nirdebug` prints the retained record count and session number.
- `/nirdebug sample` adds a snapshot of the current target and mouseover,
  HK totals and, in an instanced PvP match, the local scoreboard row.
  Unit snapshots include the faction tag when readable.
- Log out normally or use `/reload` to flush SavedVariables. Open
  `_forever_/WTF/Account/<account>/<realm>/<character>/SavedVariables/NamesInRed.lua`
  and inspect `NamesInRedDebugDB`. The file contains the complete retained
  diagnostic data. The filename is shared with the regular ledger.
- Send the file to the project owner privately for analysis. The data can
  include character names, GUIDs and raw honor messages.

The last 1,000 diagnostic rows (individual events or snapshots) are retained independently per character. Each row has a
session and timestamp. The initial row records the client build, locale and
event registration results. The preview captures the honor channel, HK
changes, standalone PARTY_KILL, match completion, and the local death recap
immediately and after 0.3, 1 and 2 seconds. Local PvE deaths remain as controls. Party kills with a readable creature,
pet or vehicle victim GUID are filtered out. Prior rows remain available. Consecutive death
probes are scoped to their own sequence. Field status distinguishes
`readable`, `absent`, `secret`, restricted tables, and API failures.
Recap rows are bounded to 32 per sample and include the original event count.

Record these scenarios when they happen:

1. Get hit by two enemies before dying. If a third enemy heals them, note that
   separately and sample the target while visible when practical.
2. Make an opposing player die with and without landing the finishing blow.
   Repeat on a battleground and note when two enemies die close together.
3. Try one PvE death as a control. Compare repeated recap reads to identify
   stale or delayed rows.

This preview also records personal killing blows in open-world PvP. It
requires readable PARTY_KILL GUIDs, a local player attacker, and a matching
attackable target or mouseover player of the opposing faction. The first
counter is stored under `NamesInRedDB.rivals[guid].killsAgainstThem` in the
same SavedVariables file. Assists, pet kills, and battleground kills remain diagnostic. Earlier debug rows are retained for analysis and are not
replayed into the ledger.

## Rival Book preview

The minimap book icon opens the Rival Book and can be dragged around the
minimap. Select a name to see counts and the latest 20 encounters. Existing
totals load without needing saved encounter details. The standard GameTooltip
gets a history section for recognized rivals with nonzero counts.

The preview records single-attacker world deaths when the first recap row is
a fresh lethal hit from an identifiable hostile player and all other recap rows
identify the same player. A saved lethal-hit timestamp prevents double counts
from duplicate PLAYER_DEAD signals or the same recap after reload. Earlier
debug captures are preserved as evidence and left out of the live totals.

Encounter metadata uses the local character's map position at capture time.
The rival's level is included only when a readable target or mouseover GUID
matches. Party encounters and battlegrounds remain diagnostic.

## Book layout and manual entries

Drag the window by its title. The empty book keeps the roster pane and Add
button visible. Scrollbars appear when content overflows. The panes use
Blizzard profession list and recipe backgrounds. Selected and hovered names
use the same atlases as profession recipe rows.

Add opens a name field and two outcome choices. The native mail autocomplete
suggests names known to the client. Free-form names remain valid. Manual
entries are identified in the encounter details. Repeating a manual entry for the same name adds to
its totals. Name-only records are separate from GUID-backed rivals and do
not create tooltip matches. Manual entries store the selected outcome
without a battle date, levels, zone or coordinates.

## Sample roster

Run `/nirdebug seed` to load 30 fictional rivals into the current character's
book. Twenty-four have race and class information and several dated encounters
with levels, zones and coordinates. Six are sample manual records. Running the
command again refreshes those sample entries. Run `/nirdebug clear-seed` to
remove only the sample roster. Your real and manually added records are kept.

## Testing the player tooltip

Target another player, open Add an encounter, keep the prefilled name, and
confirm an outcome. The form includes the surname when available, and the entry
uses the selected player's GUID. Hover over the player to see the counts beside
crossed swords and a gravestone below a blank line in the standard unit tooltip.
An existing name-only entry can also appear when
the player's full name is readable and matches exactly one ledger record.
You can delete the test record afterward in the book.
