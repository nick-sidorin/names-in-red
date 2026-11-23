# Changelog

## 1.1.0

For **World of Warcraft: Forever 1.60.1**.

- Record connected skirmishes in the open world and on battlegrounds, including fights without a killing blow. Battleground recording is on by default and can be turned off while keeping existing history.
- Track the outcome of each local fight. Improve recognition of off-target finishing blows, connected allies, observed casualties and isolated lethal encounters. Fights with insufficient evidence remain **Unknown**.
- Keep rival and skirmish history indefinitely, including confirmed kills, deaths, revivals, rewards and linked Damage Meter samples for damage, healing and absorbs. The shared history view shows the latest 100 fights. Each rival's full history remains available.
- See personal finishing blows and deaths separately from skirmish wins and losses. Verified skull-level opponents display Blizzard's skull badge. Earned Honorable Kills and Honor Points remain visible even when an award cannot be linked to a rival or fight.
- Copy a privacy-filtered JSONL report from the journal, settings or a skirmish. The wider report window shows the SavedVariables path and offers extra pages for long reports.
- Save bounded combat diagnostics for each fight, including readable observations and Damage Meter aggregates. Reports retain available evidence after reload. Older detailed diagnostics can be compacted while the fight remains in the journal.

Participant reconstruction, automatic outcomes and battleground tracking are evolving. Forever can restrict access to combat data. Rosters, rewards and event histories can be incomplete.

## 1.0.0

The first complete Names in Red release for WoW: Forever, with the rival book, skirmish history, recorded fight details, and earned PvP rewards.

- Restore crossed swords for wins and the red skull for losses in rival scores on nameplates and in unit tooltips.
- Raise nameplate numbers by one screen pixel to align them with the score icons.

## 0.1.3

- Browse a searchable rival book, revisit each rival's skirmishes, and open the full record of a fight from either history view.
- See recorded participants, class and level badges, casualties, outcomes, finishing blows, and attributed PvP rewards. Faction emblems and Honor Points artwork follow the character's faction.
- Capture readable open-world fights, including multiple attackers and observed party participation. Incomplete records indicate when the roster or outcome is uncertain.
- Use the journal in the game client's language across all supported locales.
- Keep local PvP diagnostics and use `/nirdebug` to inspect the log or load and remove sample Alliance and Horde fights.

## 0.1.2

- Configure CurseForge source packaging for version tags, with the addon folder and its runtime assets at the ZIP root.

## 0.1.1

- Collect PvP diagnostics automatically in the standard addon. The last 1,000 diagnostic rows are saved locally per character for voluntary sharing when reporting an issue.

## 0.1.0

- First public release for World of Warcraft: Forever 1.60.1.
- Keep a per-character journal of confirmed personal killing blows and single-attacker deaths in open-world PvP.
- Browse individual rivals or the latest 100 skirmishes across all opponents.
- See encounter details and open the world map with a waypoint when the recorded location is available.
- Add a skirmish manually and see rival counters on nameplates and unit tooltips.
