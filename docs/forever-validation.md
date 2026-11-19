# Forever feasibility and validation

Source baseline: Forever 1.60.1 build 70959, interface 16001. The findings below
come from code review and published addon packages. Live behavior has yet to be
verified for Names in Red.

## Attribution

- **Incoming deaths.** Blizzard documents `PLAYER_DEAD` without a killer payload,
  and `C_DeathRecap.GetRecapEvents(recapID?)` without a documented row schema.
  Blizzard's death dialog calls `HasRecapEvents()` and the recap UI consumes
  `overkill`. HeadHunter reports that a 1.60.1.69913 probe saw source GUID, name,
  flags, and timestamps. Its code retries after death, accepts a recent hostile
  participant when the finisher cannot be identified, and can infer pet ownership.
  Warlords Forever's `Kills.lua` instead takes the first recap row. Neither
  fallback establishes that a hostile player landed the final blow. Probe row
  ordering, zero overkill, completeness, and freshness. Commit only a uniquely
  identified hostile player finisher from a fresh recap. Use bounded retries
  tied to that death, cancel stale callbacks, and ensure at most one write across
  event retries and reloads. Leave pet attribution out until ownership and credit
  can be proven.
- **Outgoing kills.** Blizzard's standalone `PARTY_KILL` provides attacker and
  target GUIDs and is marked `SecretWhenUnitIdentityRestricted`. Warlords Forever
  1.3.0 registers this event, checks readable GUIDs, and checks the attacker
  against the local player or their current pet. Test event delivery in world
  PvP and battlegrounds, both solo and grouped. Require readable evidence that
  the local player was the attacker and the target was an opposing player with
  resolvable identity. A party member's blow does not qualify. Treat pet credit
  as a separate product decision. The similarly named combat-log subevent is a
  separate route. Generated documentation flags `COMBAT_LOG_EVENT_UNFILTERED`
  as restricted; compatible addon authors report it is closed to addons.
- **Honor and scoreboards.** `PLAYER_PVP_KILLS_CHANGED` carries a unit token for
  the changed totals. It does not identify a victim. Honor chat can name a
  victim for shared credit and can also report unrelated honor. Killbook 0.2.0
  uses honor and observed deaths, with a delayed Feign Death check in
  `Detect.lua`. These signals cannot prove who landed a killing blow. The
  `PVPScoreInfo` schema exposes per-player totals, including killing blows and
  deaths. `UPDATE_BATTLEFIELD_SCORE` carries no pairwise record and the
  `GetScoreInfo*` APIs carry `SecretInActivePvPMatch`. Post-match totals can
  cross-check the test session, but cannot attribute any individual event.
- **Identity and display.** `UnitGUID` and `UnitName` can be secret under
  identity restrictions. Check accessibility before comparing, indexing, parsing,
  printing or persisting results, including nested fields of returned tables.
  Protected calls contain runtime errors only. Hide contextual counts when a
  unit cannot be matched safely. HeadHunter's probe describes recap names as
  given name plus realm, while Killbook handles scoreboard names that may
  contain a surname in multiple formats. Treat any delimiter or name-only match
  as ambiguous until tested. Compare readable player GUIDs across recap,
  `PARTY_KILL`, unit tokens, relogs and realm contexts before adopting them as
  persistent IDs. Keep display names separate from record IDs.

Sources:

- [Blizzard Forever UI and generated API, build 70959](https://github.com/Gethe/wow-ui-source/tree/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns)
- [HeadHunter ForeverDeaths.lua](https://github.com/GudaAddons/HeadHunter/blob/4b06580c25e623f725ffd97bcf985c4437bb2164/Detection/ForeverDeaths.lua)
- [Warlords Forever 1.3.0 source package](https://www.curseforge.com/wow/addons/warlords-forever/files/9560128)
- [Killbook 0.2.0 source package](https://www.curseforge.com/wow/addons/killbook/files/9636021)

## Live client checks

Record the full client build, addon commit, context, event delivery and field
accessibility. Use consented participants and redact character identifiers from
published evidence.

| Scenario | Expected criterion |
| --- | --- |
| One opposing player kills the local player in world PvP and in a battleground | Fresh recap associates a unique lethal row with the actual attacker |
| Several attackers, NPC or fall as finisher, pet or guardian, exact-lethal damage | No attribution to a recent attacker or guessed owner |
| Rapid deaths, release, resurrection and reload while dead | Old recap cannot count again or be applied to the next death |
| Solo and party kills, group member kill, pet kill, unrelated nearby death, Feign Death | Check `PARTY_KILL` delivery and accessibility. Only a readable direct personal blow can qualify by default |
| Simultaneous deaths in an active battleground and final scoreboard | Compare totals and verify that a matching delta does not qualify as an individual kill |
| Target, mouseover and nameplate in/out of combat and across plate reuse | Match only the currently exposed unit; restricted or stale identity clears decorations |
| Cold login, reload, switch characters, logout and relog | Verify SavedVariables loading, persistence and isolation |

## Implementation sequence

1. Bootstrap the local ledger and CI. Storage accepts a resolved ID and keeps
   display name and totals separately. Per-character storage is provisional.
2. Probe attribution and identity in both PvP contexts before wiring any event
   into storage. Prefer direct killing blows and skip ambiguous encounters.
3. Add a small editable list. Start with one sortable table and two columns,
   zero totals for manual additions, and add/remove. Decide how a name-only
   manual entry can be linked without merging distinct players. Decide whether
   to offer explicit manual corrections and how to label them before storing any.
4. Add individually verified incoming and outgoing attribution paths. Leave an
   unsupported direction manual for now, subject to the manual-edit decision.
5. Append to the native GameTooltip, add a noninteractive Blizzard-style target
   badge, then test addon-owned decorations on exposed nameplates. Research each
   matching Blizzard component before choosing a template or native artwork.
   Check combat lockdown, frame reuse, Edit Mode and input. Show only nonzero
   icons and hide the display when both counters are zero.

## First live evidence

A 1.60.1.70959 open-world sample on ruRU exposed both PARTY_KILL GUIDs in
combat. The attacker matched the local player and the victim matched an
attackable player on the target token. The HK total increased from 0 to 1
after 285 ms despite two change notifications. The honor message one second
after the blow awarded seven honor without naming a victim. The saved log
retained three sessions. This observation supports the direct world kill path
only. The preview adds an explicit opposing-faction requirement, which was
not captured by the earlier build. Validate this requirement in the next
live sample. Assists, recap coverage, and battleground attribution are pending.


## Live death evidence and first UI

One open-world death on 1.60.1.70959 produced two PLAYER_DEAD notifications
108 ms apart. Both immediately exposed the same ten damage rows from one
hostile player, including readable GUID, display name, flags and a lethal hit
with 87 overkill. Later reads repeated the same lethal timestamp. The test
fixture reproduces this duplicate with synthetic identity and timestamps.
Coverage for groups and battlegrounds still needs live data.

The UI uses the Forever Blizzard PortraitFrameTemplate,
UIPanelScrollFrameTemplate and UIPanelButtonTemplate, and a unit-only
TooltipDataProcessor post-call for GameTooltip. The minimap button follows
Azeroth Fitness's native tracking-border artwork and drag behavior.
Level, zone and local map coordinates are best-effort snapshots. Test layout,
scrolling, minimap dragging and tooltip refresh in the real client, including
hovering an item after a known unit and reopening the book after reload.

The revised book follows the title drag region in Azeroth Fitness
`UI.lua`, the art and divider in Forever's Camelot `CharacterFrame.xml`
and honor heading art in `PVPRankFrame.xml`. The manual outcome cards use
the selection glow and ring atlases used by No Quest Hints Forever
`Onboarding.lua`. Verify window movement with and without BlizzMove,
empty panes, both outcome choices, and closing the dialog via Cancel,
Escape, the close button, and the parent closing.

The profession-inspired revision reuses the background and row-state atlases
from `Blizzard_ProfessionsRecipeList.xml` and the generic recipe background
from `Blizzard_Professions.lua`. The book owns all row data and frames.
The add dialog uses `AutoCompleteEditBoxTemplate` with the mail recipient
filters in `MailFrame.xml` and leaves free-form entry available. Verify a known
character suggestion, Tab and arrow selection, Enter accepting a suggestion
before saving, Escape dismissing suggestions first, and an enemy name the
client does not suggest. Check both layouts with longer localized names.

The First Aid reference uses the specialized `Professions-Recipe-Background-FirstAid`
atlas, the recipe list background, the minimal scrolling track and the item slot
art. The overview uses the circular output icon's ring and mask without its item
scripts. Race portraits follow `GetRaceAtlas` based on readable player info by
GUID, then fall back to a class icon or a question mark. Test selected and
empty rosters, enough rivals to overflow, and records with and without identity
data. The compact add dialog uses the circular portrait ring and a restrained
ArtifactsFX-YellowRing selection glow. Check spacing and selected states in Forever.

Camelot's profession overrides in `Blizzard_ProfessionsFrame.lua` and
`Blizzard_ProfessionsCrafting.lua` replace the window background with
`Profession-Background-Overview`, hide the list NineSlice, and clear the
schematic NineSlice anchors. The book follows that treatment and uses the
recipe atlas for the right panel's ornamental frame.

The book uses the top band of Camelot's `Profession-Background-Template2`
atlas, including its lower edge. The recipe artwork fills the details panel
with a bottom-right crop at the original aspect ratio. The portrait uses the
same circle mask and rim as the add dialog. Verify these surfaces in Forever.
