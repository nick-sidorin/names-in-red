# Names in Red — Idea and Product Context

> Status: concept / pre-implementation. This document is the handoff from the initial product discussion to Codex. It is intentionally written in English, as all repository documentation, commits, PRs and code comments should be. Conversations with the owner can be in Russian.
>
> Created: 2026-11-18. No code, UI prototype, accepted technical implementation, release, or in-game test is implied by this document.

## 1. The idea

**Remember who killed you. Remember who you killed. Recognize a familiar rival when you meet again.**

Names in Red is a small, immersive PvP history addon for **World of Warcraft: Forever**. It should quietly maintain a personal record of opposing player characters encountered in PvP, including both directions of combat:

- **Deaths to them:** how many times this enemy player has killed the local character.
- **Kills against them:** how many times the local character has killed that enemy player.

The initial inspiration is a player on an Alliance PvP character who wants to recognize a Horde player responsible for a previous death and perhaps seek revenge when they cross paths again. The underlying product should not be hard-coded to Alliance; enemy faction means the opposing side relative to the local player.

This is a **personal rival ledger**, not a global PvP scoreboard, damage meter, combat assistant, quest tracker, or automated revenge system. Encountering a known rival in the open world should be a small, memorable roleplay moment: “Oh, I remember you. Next time…”

## 2. Naming and identity

- **Chosen name:** **Names in Red**.
- **Repository:** https://github.com/nick-sidorin/names-in-red
- **Potential descriptive subtitle (not a finalized product tagline):** *Personal PvP Kill & Death Tracker for WoW Forever*.
- **Optional phrase:** *Remember every encounter. Settle the score.*
- **“Next Time”** was another name the owner liked. It is not the selected project name; it could inspire copy or flavor text later.
- Other brainstormed names included *You Owe Me*, *Blood Debt* and *Still Owed*. *Vendetta* and *Revenge* were considered attractive search terms but are generic and used by similar addons. Do not rename the project or claim SEO advantages without a later product decision.

The name should feel evocative and characterful, while the descriptive subtitle/keywords explain what the addon does.

## 3. Agreed core experience

### Automatic encounter history

1. Whenever another player kills the local character, the addon attempts to identify the player credited with that death and adds or updates their entry.
2. Whenever the local character kills another player, the addon attempts to identify the defeated player and adds or updates their entry.
3. **Both battlegrounds and open-world PvP are desired.** Neither is deliberately excluded from the product vision.
4. Repeat encounters increment the appropriate count, rather than creating duplicate players.
5. History survives logout/reload and later play sessions.
6. A character may appear in both categories. The same rival can have, for example, **3 deaths to them and 2 kills against them**.

The requested behavior is **automatic when attribution is reliable**, but Forever's addon API may not expose enough information for all situations. Do not silently invent or overstate certainty.

### One record, two views

The owner first described two editable lists (“who killed me” and “who I killed”). A better underlying model discussed afterward is **one player record with two independent counters**, presented through two filtered views or tabs. This avoids duplication and permits accurate rival history.

The user should be able to:

- Browse recorded enemy player names.
- See both kill/death counters.
- Add a player **manually by name**, including a player the addon could not detect automatically.
- Remove a record manually.
- Edit/manage the list. The precise meaning of “edit” beyond add/remove and potentially correcting a record remains to be decided; do not invent complex management features.

The first version can use a simple list window. No elaborate statistics dashboard is required.

## 4. Contextual recognition in the game world

The ledger should be useful **without opening its window**. When the player sees or targets someone whose history is already recorded, show lightweight visual context.

### 4.1 GameTooltip (on mouseover)

When hovering over a recorded enemy player character, append a concise section to their **existing** Blizzard tooltip, e.g.:

```text
Names in Red
☠ 3  Deaths to this player
⚔ 2  Kills against this player
```

The precise wording/layout is design work, not a requirement to copy this mockup literally. Keep Blizzard's normal player information intact.

### 4.2 Target frame

When the user explicitly targets a known enemy player, show a **small, polished badge/strip near the existing target frame** with relevant counts.

- The badge should fit the original Warcraft/Blizzard interface language.
- Do not replace the target frame or obstruct its default controls.
- Hide it when changing to an unrelated/unknown target.
- Avoid persistent explanatory text or unnecessary decoration.

### 4.3 Nameplates

When a recorded enemy naturally appears nearby with a **visible nameplate**, show compact cosmetic indicators attached to or near the nameplate.

- **Red skull + number:** times that player killed the local character.
- **Light-blue crossed swords + number:** times the local character killed that player.
- Show only nonzero counters. If both are nonzero, both indicators may appear.
- **If both counts are zero, show nothing.**
- Do not create extra labels or UI on unknown players, NPCs, or unrelated units.

The visual example originally discussed was a red skull marked “3” beside a blue swords icon marked “2”. That example is illustrative, not a default dataset or hardcoded value.

## 5. Visual direction

- **Feels like Blizzard made it.** Favor native UI textures, fonts, interaction conventions and restrained spacing.
- The initial draft icons are a **red skull** for deaths to a rival and **light-blue crossed swords** for kills against them. They are a direction, not approved final assets.
- Counts should be legible in compact badges, including at nameplate size.
- Avoid gaudy custom art, a permanent HUD, noisy status bars and feature bloat.
- Keep styling consistent across the tooltip, target frame, nameplate and editable list.
- Carefully consider contrast, icon scaling and UI scale without obstructing combat information.
- Prefer passive/cosmetic overlays; do not make combat decisions, modify protected click targeting or replace Blizzard's unit frames.

The owner appreciates native Blizzard appearance and a small feature set, based on experience with the separate **No Quest Hints Forever** addon. The projects remain **separate** and should not share code or hidden dependencies merely because they have the same author.

## 6. Critical WoW Forever API constraints — research, not promises

WoW Forever uses the modern Blizzard addon API and restrictions, **not the older Classic Era API model**. Public examples suggest that the ordinary unrestricted combat-log feed is not available to addons. This materially affects the reliability of both automatic counters.

### Identifying who killed the player

Existing Forever addons describe reading **Blizzard's Death Recap**, including `C_DeathRecap.GetRecapEvents`, as a possible source of the last damaging player. This should be researched and tested on the **actual Forever client** rather than assumed to always identify a single player.

Potential edge cases:
- Death recap not yet populated immediately on death; delayed data.
- Damage by pets/minions with player owners.
- Multiple attackers, environment or NPC finishing blows.
- Missing/ambiguous attacker name or realm.
- Deaths in battlegrounds versus the open world.
- A single death being observed through multiple events/reloads: avoid double counting.

### Identifying whom the player killed

Attribution is potentially **harder** than death detection. Other addons mention honor messages, killing-blow information where exposed, a targeted player dying, and battleground data. These can reflect *participation*, an *honorable kill*, or an inferred association, not necessarily a **personal killing blow**.

**Important semantic decision still open:** What exactly qualifies as “I killed this player”?
- **Strict personal killing blow** (semantically clean, perhaps not always observable).
- An honorable/assisted kill (broader, but must not be mislabeled).
- Best-effort inferred defeat (requires explicit confidence reporting).
  
Do **not** conflate these in stored data or UI. The initial wording is “players I killed”; Codex should first investigate what can genuinely be verified.

### Tooltip, target and nameplate identity

- Verify which player identity fields remain readable in Forever, especially during combat and on nameplate tokens.
- Unit GUIDs, names, realm data and some unit APIs may be restricted or secret in the modern UI. Do not read, compare or branch on secret values in unsafe ways.
- Use the strongest stable identity actually available. Avoid merging two different players with the same name; consider realm and, where allowed, a stable identifier. Decide on normalization and collisions after API research.
- Nameplate/UI modifications must not interfere with protected frames, secure clicks, combat lockdown or targeting. A static cosmetic indication is the goal; there must be no scanning for invisible/undisclosed enemies.
- Tooltips and target/nameplate overlays should degrade gracefully when attribution/identity cannot be trusted.

### Research references (leads, not verified specifications)

- [Revenge Forever — CurseForge](https://www.curseforge.com/wow/addons/revenge-forever): author describes Death Recap-based killer tracking.
- [HeadHunter ForeverDeaths.lua — GitHub](https://github.com/GudaAddons/HeadHunter/blob/main/Detection/ForeverDeaths.lua): example of a Forever-specific death-detection implementation.
- [Killbook — CurseForge](https://www.curseforge.com/wow/addons/killbook): discusses alternative kill-detection signals and battlegrounds.
- [GnomeKiller — CurseForge](https://www.curseforge.com/wow/addons/gnomedrapare): warns about uncertain kill attribution and distinguishes battleground support.
- [Warcraft Wiki — Patch 12.0.5 API changes](https://warcraft.wiki.gg/wiki/Patch_12.0.5/API_changes/notes): modern secret-value/unit restrictions.

Read and test against the actual game version and current Blizzard APIs. Treat third-party addon descriptions as hints, not proof that a particular implementation or technique is correct or permitted.

## 7. Proposed data model (design sketch, not a committed schema)

Prefer a shared logical player entry containing two independent counters, with enough bookkeeping to prevent accidental duplicates.

```text
PlayerRecord
  identity:       normalized character name + realm, or a stronger safe ID
  displayName:    original display name
  deathsToThem:   integer >= 0
  killsOfThem:    integer >= 0
  provenance:     auto-confirmed / inferred / manual, as relevant
  lastEncounter:  optional timestamp / context (only if accessible)
```

This is conceptual only. It does not require these exact names or fields.

Decisions to research before implementation:
- **SavedVariables scope:** per local character, per account, or optionally shared? The owner has not chosen. “My PvP history” suggests per-character by default, but confirm before locking a schema.
- **Realm identity:** how to prevent name collisions without breaking manually typed names.
- **Manual records:** whether manually added entries start at 0/0, and whether the owner can manually adjust counters.
- **Event quality:** store only confirmed events, or separately distinguish tentative guesses. Avoid increasing confirmed totals from incomplete evidence.
- **Data migration:** once real users exist, never silently discard their stored history.
- **Privacy and performance:** local-only SavedVariables; no network backend, public enemy database or synchronization planned.

## 8. Scope and priorities

### MVP direction

1. Confirm the technical limits of **both** kill directions in the actual Forever environment.
2. Implement trustworthy local persistence, record identity/deduplication and a **simple editable list window**.
3. Add automatic death/killer recording if reliable.
4. Add automatic kills-against-them recording only to the extent actually supportable without falsifying attribution.
5. Add tooltip history for a known player.
6. Add a compact target-frame badge.
7. Add nameplate indicators where safe/available.

These are sensible sequencing suggestions, **not** permission to silently drop requested BG support or any of the three surfaces. A staged PR is welcome; the complete vision remains in this document.

### Out of scope for now

- Global leaderboards, online account services, bounties and guild sharing.
- Automated target selection, attack assistance or PvP decision support.
- Tracking NPC kills.
- A permanent scrolling combat log, damage meter or large on-screen K/D dashboard.
- Enemy detection beyond units naturally shown by Blizzard.
- Notifications, sounds, map tracking, detailed per-zone analytics, lifetime achievements or complex filters unless explicitly requested later.
- Publishing a release before in-game verification.

## 9. Engineering and project preferences

This is a new repo, so no architecture or build tooling is yet approved. Preserve the lightweight, professional engineering approach used on the author's other WoW Forever addon:

- **English only** in repository documentation, code comments, commit/PR descriptions and release notes. Direct conversation with the owner is **Russian**.
- Prefer small modules with clear responsibilities, Lua 5.1 compatibility where applicable, and native game UI.
- Implement in **feature branches and PRs**, using **Squash and merge** for a clean history. No direct feature commits to `main` after project setup without an explicit decision.
- Add a practical automated syntax/regression/packaging CI gate and make it mandatory before merging once implementation starts. Mock tests do not replace real game tests.
- Use real in-game API evidence for Forever. Explain limitations rather than assuming Retail/Classic compatibility.
- Keep explanations and UI text minimal and functional; avoid intrusive guidance and large settings menus.
- Don't introduce external services, analytics or monetization as assumptions.
- Keep releases explicit and separate from normal feature PRs.

This repository should eventually get a concise `AGENTS.md` and `README.md` when development begins. Do not blindly copy unrelated instructions from other projects.

## 10. Open product questions

The following **have not been decided** in our discussion. Codex should make reasonable, explicit recommendations rather than treating them as specifications:

1. Counts for personal **killing blows** only, or honor/assists too?
2. How should unverifiable or ambiguous encounters be surfaced?
3. Should PvP history be per character or shared across characters?
4. How should manually added rivals and counters be edited?
5. What is the correct player identity key in the Forever client?
6. What does the game expose about battleground kills and deaths, and how reliable is it?
7. What is the exact frame attachment and update mechanism that remains safe in combat?
8. Which icons/native Blizzard art look best, and how should both counters appear on small plates?
9. Should the list have two tabs/views or one sortable table? Data storage should still represent each player once.

## 11. First Codex handoff

Start by reading this entire document and inspecting the current repository. Perform a **technical feasibility investigation before claiming automatic kill/death tracking can work everywhere**. Separate verified game behavior from third-party suggestions, summarize constraints, propose a minimal architecture and test plan, then implement in small PRs when directed.

The guiding rule is simple: **a trustworthy record of personal PvP history, quietly visible when a known rival reappears.**
