# Names in Red

**Remember who got you. Plan your revenge.**

## ✨ Features at a Glance

Your personal journal for open-world PvP and battleground skirmishes for **World of Warcraft: Forever**:

- 📖 **Remember your rivals** — Build a searchable record of identifiable enemies you've fought, saved separately for each character.
- ⚔️ **Track the score** — See the Character POV score against each rival alongside Honorable Kills and attributed Honor Points.
- 📜 **Revisit past skirmishes** — Browse a rival's full history or open the latest 100 fights across all rivals.
- 🛡️ **See who fought** — Open detailed cards with observed allies, enemies, results, casualties, finishing blows and rewards.
- 🚩 **Record battleground clashes** — Review local fights in the same journal. Turn recording off in settings while keeping your existing history.
- 💬 **Recognize familiar enemies** — See your win/loss record on their nameplates and in their standard unit tooltips.
- 📍 **Remember where it happened** — Place a map waypoint when a saved skirmish has a usable location.
- 🐞 **Report a problem from the journal** — Select and copy a single privacy-filtered report for a skirmish or a general issue.
- ✍️ **Fill in the gaps** — Manually add a skirmish when automatic tracking cannot capture what happened.

The journal is saved per character and keeps your recorded rival and skirmish history indefinitely. Nameplate indicators and tooltip details can be switched off independently.

## 📖 Your Personal Rival Book

Click the **crossed-swords button by the minimap** to open Names in Red.

The **Rivals** view contains a searchable list of familiar opponents. Select a name to see their portrait, your score against them, Honorable Kills, Honor Points, and the latest recorded encounter. Switch from **Information** to **Skirmishes** to browse your entire recorded history with that player.

The separate **Skirmish History** view collects the latest 100 recorded fights across all opponents. Open a fight to inspect it, or follow a known opponent back to their rival profile.

## ⚔️ New in 2.0.0 · Character POV

A skirmish can involve more than two players. The detailed view shows the participants the addon was able to observe on each side, with available class and level information, casualties, recorded levels or skull-level indicators, and a **Finishing blows** list in recorded order.

A full card shows **Victory**, **Defeat**, **Draw**, **In progress**, or
**Unknown** from your character's perspective. Your rival score follows
what you contributed to each confirmed defeat. Help bring down a rival
with damage, healing, protection or control to earn a win against them.
Each rival who contributed to your death adds a loss to your score against them.
Activity from a pet with a verified owner can count. A later death after
revival can earn another credit in the same fight.

Rival scores appear in profiles, compact cards, nameplates and tooltips.
Direct kills and deaths, Honorable Kills, and Honor Points stay separate.

Fight cards also show the date, time, zone, and any Honorable Kills or Honor Points that could be linked reliably to the encounter. Alliance and Horde get their own faction artwork and Honor Points icons.

Use **Show on map** to place a waypoint for a saved location when the game can resolve it. Older records can still show their available location details.

## 👀 Recognize an Old Enemy

You don't need to open the journal every time a familiar name appears.

- **Nameplates** show compact crossed-swords and skull counters above a recognized rival's visible nameplate.
- **Unit tooltips** add your recorded win/loss score beneath the game's normal player information.

Both are enabled by default and have separate switches under the addon settings.

## 📝 What Gets Recorded

Names in Red observes **open-world PvP and battleground skirmishes** using information the Forever client makes available to addons. It groups related activity into skirmishes, including fights without a killing blow. The saved record can include confirmed deaths and revivals, earned rewards, and linked Damage Meter samples for damage, healing and absorbs. Battleground cards identify the local fight and its outcome. Matches can contain several independent skirmishes.

When you join someone else's fight, your confirmed damage can establish the skirmish and count toward a victory when the enemy's death is observed. Some encounters have an incomplete roster or an unknown outcome. Rewards appear on the fight or rival record when their attribution is confirmed. An unidentified player may appear as **Unknown rival** until their full name is available.

A brief retreat or return after resurrection can continue the same fight. An independent rematch gets its own record. Forever can restrict identities, pet ownership and event timing, so some participants, revivals, repeat kills or rewards may be unavailable. The upgrade preserves recorded fights, manual entries and rewards.

You can also add a skirmish manually by entering an opponent's full name and choosing the outcome. The addon is a personal history, not a complete combat log or a battleground scoreboard.

## ⚙️ Getting Started and Settings

1. Install Names in Red for **WoW: Forever** through CurseForge, or place the `NamesInRed/` folder in `_forever_/Interface/AddOns/`.
2. Click the crossed-swords minimap button to browse your recorded rivals.
3. Select a rival for their **Information** and **Skirmishes** tabs, or open **Skirmish History** for all recent fights.

Right-click the minimap icon, or open **Options → AddOns → Names in Red**, to configure nameplate icons, tooltip information, and battleground tracking. Battleground tracking is enabled by default. Turning it off keeps your existing history and rival recognition. **Reset data** asks for confirmation before deleting this character's rivals, skirmishes, manual entries, demo data, and diagnostic log. Your display preferences and minimap button position are kept.

| Command | Action |
| --- | --- |
| `/nirreset` | Open the confirmed **Reset data** action. |
| `/nirdebug` | Show the retained diagnostic record count and session information. |
| `/nirdebug seed` | Add or refresh fictional rivals and skirmishes for a preview. |
| `/nirdebug clear-seed` | Remove demo entries without deleting your real or manually added records. |

More diagnostic and demo commands are documented in the [project guide](https://github.com/nick-sidorin/names-in-red/blob/main/docs/debug-preview.md).

## ℹ️ Good to Know

- **Client:** Built specifically for **World of Warcraft: Forever 1.60.1**.
- **Languages:** Follows the WoW client language: English, Russian, German, French, Spanish, Italian, Brazilian Portuguese, Korean, Simplified Chinese, and Traditional Chinese.
- **History:** Stored separately for each character; unavailable identity, team size, rewards, or outcomes are not fabricated.
- **Diagnostics:** A rolling local log and bounded per-fight samples help investigate bugs. You can copy an issue report after reload. Older detailed diagnostics can be compacted while the fight and its confirmed timeline stay in your history.

**[Report a Bug or Suggest a Feature](https://github.com/nick-sidorin/names-in-red/issues)**

Click **New issue** to report a problem or share an idea. For a bug, click the bug icon on the affected skirmish or use **Report an issue** in the journal header. Click **Select Report**, copy once, and paste into the GitHub form. Review the report and include the steps that led to the problem. The report window also shows where to find the optional `NamesInRed.lua` SavedVariables file. That file can contain character names and GUIDs, and attachments to a public issue are public.

**[Source Code](https://github.com/nick-sidorin/names-in-red)**

---

*Remember who got you. Plan your revenge.*
