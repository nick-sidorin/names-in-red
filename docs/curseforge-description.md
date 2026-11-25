# Names in Red

**Remember who got you. Plan your revenge.**

Your personal PvP journal for **World of Warcraft: Forever**. Every rival has a story. Remember your encounters, keep track of your rivalries, and see how the score changes the next time your paths cross.

## ✨ Features at a Glance

- 📖 **Your personal rival book** — Remember enemy players you've fought and browse your history with each of them.
- ⚔️ **Keep the score** — Track wins and losses against individual rivals, direct kills and deaths, Honorable Kills and Honor Points.
- 🛡️ **More than killing blows** — Meaningful damage, healing, protection and control can earn credit when your contribution is confirmed.
- 📜 **Relive your skirmishes** — See observed allies and enemies, outcomes, casualties, finishing blows and earned rewards in detailed battle cards.
- 👀 **Recognize old enemies** — See your personal score on familiar rivals' nameplates and in their unit tooltips.
- 🚩 **Open-world PvP and battlegrounds** — Record local encounters, from spontaneous one-on-one fights to group clashes.
- 📍 **Remember where it happened** — Revisit encounter locations with map waypoints when available.
- ✍️ **Fill in the gaps** — Add a skirmish manually if the game couldn't provide enough information.

## ⚔️ New in 2.0.0 — Character POV

Names in Red is not a battleground scoreboard. It's the story of your character's PvP adventures, told from your character's perspective.

Every recorded skirmish has its own outcome, while your personal score against each rival reflects your contribution to their defeat — and theirs to yours.

- You help an ally defeat an enemy: you can earn a win against that rival even if your ally lands the final blow.
- You heal an ally who defeats an enemy: your confirmed support can count, even without dealing damage.
- You defeat one enemy and another kills you: your journal can show a defeat for the skirmish, a win against the first rival and a loss against the second.

Rival wins and losses are separate from direct kills and deaths, Honorable Kills and Honor Points. A pet's activity can count toward its player owner when that ownership and contribution are reliably linked. Fights without a killing blow can also be recorded.

## 📖 Your PvP History

Open Names in Red using the crossed-swords button by the minimap.

- **Rivals:** search your opponents, see their portrait and personal score, and browse their full recorded encounter history.
- **Skirmish History:** revisit the latest 100 recorded fights across all rivals. Older fights remain available in individual rival histories.

Each fight card displays the observed participants on both sides, available class and level information, the outcome, recorded deaths and finishing blows, time, location and attributable rewards. Use **Show on map** when the saved location supports a waypoint.

Your recorded history is saved separately for each character and persists across game sessions. Nameplate and tooltip displays can be toggled independently. Battleground recording is enabled by default and can be switched off without losing your existing history or rival recognition.

## 📝 What the Game Can Tell Us

Names in Red uses the information the Forever client makes available to addons. It works without requiring other players to install it.

A brief retreat or a return after resurrection can be part of the same skirmish. A separate rematch gets its own entry. Battleground encounters represent local fights, not the entire match.

Some identities, participants, pet owners, actions or outcomes may be unavailable. When the evidence is incomplete, the journal keeps what it can reliably establish rather than inventing details. The journal distinguishes **Victory**, **Defeat**, **Draw**, **In progress**, and **Unknown** when the ending cannot be established. Rewards are recorded at the most specific scope that can be established. Older detailed diagnostics may be compacted without removing recorded fights and their core history. Upgrading preserves recorded encounters, manual entries and rewards.

## ⚙️ Getting Started

Install through CurseForge, or place the `NamesInRed/` folder in `_forever_/Interface/AddOns/`.

Click the minimap button to open your journal. Right-click it or open **Options → AddOns → Names in Red** to configure nameplates, tooltips and battleground tracking.

**Reset data** (also available via `/nirreset`) asks for confirmation before deleting the current character's history, manual entries, demo entries and diagnostic log. Display preferences and minimap position are retained. For optional diagnostic and demo commands, see the [project guide](https://github.com/nick-sidorin/names-in-red/blob/main/docs/debug-preview.md).

## ℹ️ Compatibility and Languages

- Built for **World of Warcraft: Forever 1.60.1**.
- English, Russian, German, French, Spanish, Italian, Brazilian Portuguese, Korean, Simplified Chinese and Traditional Chinese. The interface follows your client language.

## 🐞 Feedback and Support

**[Report a Bug or Suggest a Feature](https://github.com/nick-sidorin/names-in-red/issues)**

Click **New issue** to report a problem or share an idea.

For bugs, use **Report an issue** in the journal or the bug icon on a skirmish, select the report and copy it once into the issue form. The report uses participant aliases and identifies any shortened sections. Review it before posting and include the game build, addon version and steps to reproduce where available.

You can optionally attach the existing `NamesInRed.lua` SavedVariables file for more detail. It may contain character names and GUIDs; public attachments are visible to everyone.

**[Source Code](https://github.com/nick-sidorin/names-in-red)**

*Remember who got you. Plan your revenge.*
