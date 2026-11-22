# PvP diagnostics and sample data

Versions 0.0.x were diagnostic previews. Version 0.1.0 shipped only the rival
journal. Starting with 0.1.1, the standard addon also collects diagnostic data
automatically. Starting with 0.1.3, the standard addon also includes commands
to load and remove fictional rivals and sample skirmishes.

Install the ZIP by extracting its `NamesInRed/` folder into
`_forever_/Interface/AddOns/`. Collection starts at addon load and works
during ordinary play.

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

The minimap crossed-swords icon opens the Rival Book and can be dragged around the
minimap. Select a name to see totals and the last skirmish in Information.
Skirmishes shows all saved cards in newest-first order. Existing totals load
without needing saved encounter details. The standard GameTooltip gets a
history section for recognized rivals with nonzero counts.

The preview records single-attacker world deaths when the first recap row is
a fresh lethal hit from an identifiable hostile player and all other recap rows
identify the same player. A saved lethal-hit timestamp prevents double counts
from duplicate PLAYER_DEAD signals or the same recap after reload. Earlier
debug captures are preserved as evidence and left out of the live totals.

Encounter metadata uses the local character's map position and map ID at
capture time. Show on Map opens the world map with the native user waypoint.
Older records can also open the map when their saved zone name matches
exactly one localized Azeroth zone map. Coordinates remain in saved data
for waypoint placement.
The previous twenty-record cap cannot recover data already discarded.
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
its totals. A matching selected target also supplies its readable level, race,
sex, class and faction when the form opens. Manual entries have no battle date,
zone or coordinates. A typed name without a matching target supplies no target
details.

## Sample roster for screenshots

Run `/nirdebug seed` to load 12 fictional rivals
and 12 battles across six zones over the past week. Both rosters match the
current character's faction, and the game supplies localized zone, race and
class names when available.

Use `/nirdebug faction alliance` or `/nirdebug faction horde` to rebuild the
demo roster, faction emblems and reward icons for either faction. Use
`/nirdebug faction auto` to rebuild the roster for your current character.
The selected faction is saved with the demo records and applies to those
records in the journal. Live capture continues to use the player's faction.

Open **Information** for Dargun Ironjaw on Alliance or Alden Dawnshield on
Horde. The profile shows a recurring opponent with wins, a loss, honorable
kills and honor. The latest encounter is a 2 × 2 rematch in Winterspring
that your side wins after you die. Use its information button for the full
card and finishing blows. **Skirmish History** also shows a 1 × 1 loss,
a 3 × 3 win and a 5 × 6 loss with honor credited.

Running the command again replaces the previous fixtures. Run
`/nirdebug clear-seed` to remove them. Real and manual records stay in
the journal and can appear alongside the demo data.

## Testing the player tooltip

Target another player, open Add an encounter, keep the prefilled name, and
confirm an outcome. The form includes the surname when available, and the entry
uses the selected player's GUID. Hover over the player to see the counts beside
crossed swords and a skull below a blank line in the standard unit tooltip.
An existing name-only entry can also appear when
the player's full name is readable and matches exactly one ledger record.
You can delete the test record afterward in the book.

The book portrait shows the latest recorded rival level from an automatic
encounter or a manual entry linked to a selected target.

Automatic encounters are stored by player GUID. If the client exposes only a
first name or no name, the encounter is saved and its rival stays out of the
book and tooltip until the full name is available. Targeting or hovering over
the same player can fill in the name without adding another encounter. This
also completes older half-name records. New manual entries require both names.

Visible player nameplates show the nonzero counters in a centered row directly
above the name. When the name is hidden, the row sits just above the visible
health bar. Plates whose identity is restricted do not show counters.
