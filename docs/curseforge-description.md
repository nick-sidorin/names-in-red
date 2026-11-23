# Names in Red

**Remember who got you. Plan your revenge.**

## ✨ Features at a Glance

Your personal journal for open-world PvP and battleground skirmishes for **World of Warcraft: Forever**:

- 📖 **Remember your rivals** — Build a searchable record of identifiable enemies you've fought, saved separately for each character.
- ⚔️ **Track the score** — See wins, losses, Honorable Kills, and attributed Honor Points against each rival.
- 📜 **Revisit every skirmish** — Explore one rival's history or browse your latest 100 recorded fights, newest first.
- 🛡️ **See who fought** — Open detailed cards with observed allies, enemies, results, casualties, finishing blows and rewards.
- 🚩 **Record battleground clashes** — Review local fights in the same journal. Turn recording off in settings while keeping your existing history.
- 💬 **Recognize familiar enemies** — See your win/loss record on their nameplates and in their standard unit tooltips.
- 📍 **Remember where it happened** — Place a map waypoint when a saved skirmish has a usable location.
- 🐞 **Report a problem from the journal** — Copy a diagnostic report for a skirmish or a general issue.
- ✍️ **Fill in the gaps** — Manually add a skirmish when automatic tracking cannot capture what happened.

The journal is saved per character. Nameplate indicators and tooltip details can be switched off independently.

## 📖 Your Personal Rival Book

Click the **crossed-swords button by the minimap** to open Names in Red.

The **Rivals** view contains a searchable list of familiar opponents. Select a name to see their portrait, your score against them, Honorable Kills, Honor Points, and the latest recorded encounter. Switch from **Information** to **Skirmishes** to browse your entire recorded history with that player.

The separate **Skirmish History** view collects the latest 100 recorded fights across all opponents. Open a fight to inspect it, or follow a known opponent back to their rival profile.

## ⚔️ More Than a Kill Counter

A skirmish can involve more than two players. The detailed view shows the participants the addon was able to observe on each side, with available class and level information, casualties, a win/loss result when known, and a **Finishing blows** list in recorded order.

Fight cards also show the date, time, zone, and any Honorable Kills or Honor Points that could be linked reliably to the encounter. Alliance and Horde get their own faction artwork and Honor Points icons.

Use **Show on map** to place a waypoint for a saved location when the game can resolve it. Older records can still show their available location details.

## 👀 Recognize an Old Enemy

You don't need to open the journal every time a familiar name appears.

- **Nameplates** show compact crossed-swords and skull counters above a recognized rival's visible nameplate.
- **Unit tooltips** add your recorded win/loss score beneath the game's normal player information.

Both are enabled by default and have separate switches under the addon settings.

## 📝 What Gets Recorded

Names in Red observes **open-world PvP and battleground skirmishes** using information the Forever client makes available to addons. It records readable kills and deaths, groups related observations into skirmishes, and adds other participants when there is sufficient evidence. Battleground cards identify the local fight and its outcome. Matches can contain several independent skirmishes.

Not every encounter exposes a complete team or a certain result. Those records remain in the journal with an incomplete roster or unknown outcome instead of guessing. Honor and Honorable Kill rewards are attached only when the available signals identify the relevant encounter reliably. An unidentified player may appear as **Unknown rival** until their full name is available.

Battleground recording and automatic outcome assessment are still being refined. Forever can restrict access to combat data, so some support players, revivals, repeat kills or rewards may be missing.

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
- **Diagnostics:** The latest 1,000 diagnostic records are saved locally per character. These may contain character names, identifiers, and honor messages. Review them before voluntarily sharing a SavedVariables file in a bug report.

**Update 1.1.0:** Local battleground skirmishes, fights without killing blows, resurrection history and in-game issue reports.

**[Report a Bug or Suggest a Feature](https://github.com/nick-sidorin/names-in-red/issues)**

For a bug, click the bug icon on the affected skirmish or use **Report an issue** in the journal header. Review the report, then copy it into a new issue and describe what you expected to happen. For an idea, click **New issue** on GitHub.

**[Source Code](https://github.com/nick-sidorin/names-in-red)**

---

*Remember who got you. Plan your revenge.*
