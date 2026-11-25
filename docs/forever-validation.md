# Forever feasibility and validation

Source baseline: Forever 1.60.1 build 70959, interface 16001. The findings below
come from the matched UI source, published addon packages and owner captures.
Each section identifies which paths have been observed in the client.

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
| Solo and party kills, group member kill, pet kill, unrelated nearby death, Feign Death | Check `PARTY_KILL` delivery and accessibility for the local player and readable group members |
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

For the nameplate preview, Camelot places the raid marker left of the health
bar and the level on its right. BigDebuffs can attach side indicators outside
the visible bar or name. The first Names in Red preview used a side anchor.
The current preview centers the label directly above the name to keep the
counters close to the character name and leave room for higher overlays.
The counter font string sits one physical pixel higher, using the display
factor from Blizzard's `PixelUtil.lua` and the badge's effective scale.
The nameplate's inline artwork drops its former one-unit height offset.
Check spacing with native raid markers, auras and other addons in Forever.
See the [Camelot level template](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_NamePlates/Camelot/Blizzard_NamePlateLevelFrame.xml)
and [BigDebuffs attachment code](https://github.com/jordonwow/bigdebuffs/blob/38690ed9d782c01c137779b7998dbe905c740fda/BigDebuffs.lua#L1596-L1630).

### Open-world killing blows

A 1.60.1.70959 open-world sample on ruRU exposed both PARTY_KILL GUIDs in
combat. The attacker matched the local player and the victim matched an
attackable player on the target token. The HK total increased from 0 to 1
after 285 ms despite two change notifications. The honor message one second
after the blow awarded seven honor without naming a victim. The saved log
retained three sessions. This observation supports the direct world kill path
only. The preview adds an explicit opposing-faction requirement, which was
not captured by the earlier build. Validate this requirement in the next
live sample. Assists, recap coverage, and battleground attribution are pending.

Another ruRU sample confirmed a personal killing blow against an opposing
player. An unnamed nine-honor message followed 1.012 seconds after `PARTY_KILL`.
The same session also recorded an unnamed one-honor message before the fight.
`CHAT_MSG_COMBAT_HONOR_GAIN` exposes general chat metadata and no documented
victim identifier. The preview keeps the raw messages in diagnostics and does
not assign a reward to an encounter based on timing alone.

## Live death evidence and first UI

One open-world death on 1.60.1.70959 produced two PLAYER_DEAD notifications
108 ms apart. Both immediately exposed the same ten damage rows from one
hostile player, including readable GUID, display name, flags and a lethal hit
with 87 overkill. Later reads repeated the same lethal timestamp. The test
fixture reproduces this duplicate with synthetic identity and timestamps.

A later open-world group session exposed two different player finishing blows
with readable GUIDs, hostile player flags and positive overkill. Each death
produced two notifications with the same lethal timestamp. One recap also
contained another player and two creatures, and the other contained two
additional players. Replaying the four notifications through the updated
handler yielded two records with two and three hostile players respectively.
The finishing blow is checked separately from the other recent damage rows.
The attacker list is limited to readable hostile players in that recap.
The new card tooltip uses the native `GameTooltip`.

On the Forever 70959 source branch, `Blizzard_DeathRecap.lua` loads the event
array through `C_DeathRecap.GetRecapEvents` and uses `overkill` in its damage
display. Generated `UnitDocumentation.lua` documents that standalone
`PARTY_KILL` carries attacker and target GUIDs. Neither observation establishes
the entire participant roster. Falls, pet credit, participation on the outgoing
kill path and battleground coverage still need validation. The new card
tooltip has not been checked in the live client.

### Participant diagnostic preview

The 0.1.3-preview.1 build records a local combat sequence, group snapshots,
and readable target metadata at combat boundaries. After combat, it samples
Damage Done, Damage Taken, Enemy Damage Taken and Healing Done. A single
newly archived meter session takes precedence. A Current-session sample is
explicitly labeled as a fallback when a unique new archive is unavailable.
The capture is scoped to its combat sequence and is marked interrupted when
combat resumes before the read. Source and spell lists have bounded samples.
Secret, restricted and unavailable fields retain their read status.

The probe follows the supported APIs used by
`DamageMeterSessionWindowMixin:GetCombatSession`,
`DamageMeterSourceWindowMixin:GetCombatSessionSource` and the target fields
used by `DamageMeterEntry.lua` in Forever 70959. A target name in an
aggregate is evidence to inspect rather than automatic encounter attribution.
Compare both players' saves after a fight in a party and a fight outside it.
Have one attack while the other lands the finishing blow. This probe needs
live-client validation.

### Duskwood participant evidence

The owner's 22 November 2026 log from Forever 70959 contains a 40-second
combat window with two confirmed player kills and five attributed honor.
`DamageTaken` resolves the local hunter and a priest as victims by GUID. The
spell details identify the same opposing paladin as an attacker by
full name and class, with positive amounts for both victims. The recorded
contact supplies the paladin's GUID and hostile faction. The priest also
appears in `HealingDone`, but its available spell details omit the recipients.
Another friendly player was present without a recorded link to this fight.

The participant preview uses this pattern to extend the roster of an
already recorded open-world fight. It requires a meter update for the selected
session and category during local combat, a duration within two seconds of the
local window, and identities matched in the same zone and recorded fight.
Disjoint player pairs, mobs, secret amounts and ambiguous names are excluded.
The anonymized event replay reproduces the observed 2 × 3 roster, two confirmed
deaths and five honor. The original log remains private. The last known state
of the paladin was alive when its nameplate left view. That alone supplies
no evidence of a resolved fight or the paladin's reason for leaving.

### Damage Meter participant research (Forever 70959)

The source revision is
[Gethe/wow-ui-source at 3d8abb1](https://github.com/Gethe/wow-ui-source/tree/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns).
See `Blizzard_APIDocumentationGenerated/DamageMeterDocumentation.lua`,
`DamageMeterConstantsDocumentation.lua` and
`Blizzard_DamageMeter/{DamageMeterSessionWindow,DamageMeterSourceWindow,DamageMeterEntry}.lua`.

#### Confirmed from the API and Blizzard UI

| Surface | What it supplies |
| --- | --- |
| `IsDamageMeterAvailable()` | Availability and a failure reason. The stock UI separately checks the `damageMeterEnabled` CVar. This addon does not change it. |
| `GetAvailableCombatSessions()` | Listed session IDs, display names and optional durations. The UI offers these alongside an independent Current or Overall selection. |
| `GetCombatSessionFromID` / `GetCombatSessionFromType` | Category totals, optional duration and source rows. Sources may expose a GUID or creature ID, name, class, faction, display type, amount and local-player flag. Death rows have a recap ID and relative death time. |
| `GetCombatSessionSourceFromID` / `GetCombatSessionSourceFromType` | Source totals and aggregates per spell, including spell ID, amount, overkill, avoidance and deadly flags, and optional usable details for a second unit. A detail exposes a display name, class, mob/pet flags and amount. It carries no second GUID, owner GUID or timestamp. |
| `GetSessionDurationSeconds(sessionType)` | Timer for a session type. It has no absolute start/end time. |
| `ResetAllCombatSessions()` | Clears all meter sessions. The preview only observes resets. |
| `DAMAGE_METER_COMBAT_SESSION_UPDATED(type, sessionID)` | Category refresh signal. `DamageMeterSessionWindowMixin:OnEvent` refreshes the matching category and ID and has a special path for ID `0` with a type-based selection. ID `0` accompanied Current data in the Duskwood capture. This event has no action, timestamp or boundary payload. |
| `DAMAGE_METER_CURRENT_SESSION_UPDATED` / `DAMAGE_METER_RESET` | Both have no payload. The UI refreshes Current with scroll discarded on the first and refreshes on reset. The first does not carry a unique numeric ID or say whether a particular encounter ended. |

All four session/detail getters are marked `SecretWhenInCombat` and have
`SecretArguments = AllowedWhenUntainted`. The session list and duration
metadata lack the combat-wide marker. The preview still validates their values
individually, reads category and source data after local combat and keeps the
read status when data is restricted, inaccessible, absent or fails. Even out
of combat, some source fields are conditionally secret and the specialization
icon is marked secret. The four Blizzard getters are called by the
session/source window mixins as data providers. No protected UI is hooked or
used to access values.

The public session types are `Overall (0)`, `Current (1)` and `Expired (2)`.
Here `Current (1)` is an enum argument, while `0` in a category-update event
is a separate ID field. The timer code treats Expired as a fixed-duration
display state. A numeric archived ID selects a listed session. No contract
makes an ID global, persistent across reset/reload, or equal to a skirmish ID.
The constants also describe native combination modes for Challenge Mode,
Arena and multi-round Arena and overrides that can redirect sources to owners
or aura casters. Those enums do not expose the native combination/override
rules or promise that every pet is grouped under its owner.

The category enum lists Damage Done, DPS, Healing Done, HPS, Absorbs,
Interrupts, Dispels, Damage Taken, Avoidable Damage Taken, Deaths and Enemy
Damage Taken. `DAMAGE_METER_CATEGORIES` lists all except Absorbs in the stock
window menu. There is no dedicated buffs, crowd control or threat category.
`DamageMeterSpellEntryMixin:GetNameText` formats the creature name for a pet
spell and a readable second-unit name for entries such as incoming damage.
The fact that rows can display a second name does not guarantee one for
every category. Source totals and per-spell totals without a specific
second unit cannot establish an interaction between two players.

The native engine defines when a session is created, ended, combined and moved
into the list. The stock Lua chooses a type or an ID, fetches aggregates and
renders them. It does not segment an open-world PvP fight. No public function
or event supplies an individual world PvP encounter ID or ordered action log.
`ENCOUNTER_START` and `ENCOUNTER_END` describe boss encounters and carry
encounter, difficulty and group-size fields, with boss status at the end.
They do not furnish a world PvP ID. `world:n` is a Names in Red journal key.
Relative death time and the addon's own receipt time for refresh events can
help compare windows, but cannot recover the order of heals or attacks.

#### Observed in the owner's capture

Duskwood used Current with positive, named `DamageTaken` details. The priest
had 217 healing in aggregate with empty second-unit names and zero detail
amounts. Outgoing damage also had rows with no usable second unit.
`EnemyDamageTaken` included a nearby NPC in addition to opposing players.
Some named second-unit rows had zero detail amounts despite positive spell
totals. A meter session can therefore contain data unrelated to the skirmish.
Whether it folds two independent PvP fights into the same local Current or
archive and how long after the last attack it does so still needs an
explicit two-fight observation. The session alone is insufficient to
distinguish those fights.

#### Preview behavior and limits

- Read at 0.5 seconds after local combat ends. Retry once at 1.5 seconds if
  combat restrictions persist, an update is pending or a qualifying input
  is temporarily unreadable. Use the documented
  `C_RestrictedActions.GetAddOnRestrictionState(Combat)` when available, and
  test field readability independently. Defer source-detail requests while
  category data is pending. A retry builds a fresh graph from the final
  selection and writes at most once.
- Use one newly listed archive or the explicitly labeled Current slot.
  Each category needs a readable source table, an exact session/category
  update during the local window or its settling period, and a duration
  within two seconds of local combat. A newly listed archive can supersede
  Current during the retry; an earlier pinned archive cannot switch IDs or
  fall back to Current. An untyped Current update between Current reads
  invalidates that fallback. Multiple new archives, an incomplete session
  list, a reset, a new combat or an area/world transition prevent unsafe
  enrichment. If another fight starts while a read is pending, discard
  the old read and skip meter enrichment for that next local window because
  a late event cannot safely be assigned. These checks constrain freshness
  without implying exact PvP boundaries.
- Source/target details may be read as one structure or a list of structures.
  The generated 70959 docs and stock spell-entry code declare the former;
  the latter shape is defensive compatibility, exercised by mocks.
  Walk every source and qualifying spell/detail row with reused scratch
  tables, requesting full detail beyond the sample only for a source that
  matches an observed player or pet owner. Deduplicate links per player
  pair and traverse the reachable graph once. Retain one current identity
  per observed contact and positive owner claims for the local window.
  Detailed log samples remain bounded at 12 sources, 16 spells per
  sampled source, 4 detail rows per sampled spell, 32 contact histories,
  32 pets and 10 group members per event. All readable party/raid
  tokens participate in observation. The aura sample is diagnostic only.
- Each eligible category records aggregate resolution counts across the
  full pass, including absent or secret source GUID, missing or secret
  contact identity, unreadable detail, missing recipient name or class,
  zero/secret amount, missing or ambiguous recipient contact, unknown or
  conflicting pet owner and a valid source link outside the rooted graph.
  `combatSpellDetails` does not expose a recipient GUID in this build's API
  schema. Aura samples retain separate source and target GUID read states.
- Connect identified players through positive second-unit details for damage
  or interrupts across factions, healing and absorbs within a faction, and
  dispels within or across factions. An opponent must be observed attackable.
  Source GUIDs match contacts and detail names match a unique full name and
  class. The connected component must touch an existing roster member. Party
  membership, nameplates, targeting, NPC damage, overall totals and disjoint
  player pairs do not qualify on their own. An action to a known player in a
  coincident PvE phase can remain ambiguous; the meter does not timestamp it.
- Credit a separately reported pet source to a single confirmed controller
  using a matching Pet GUID from local/party/raid pet tokens or a readable
  `UnitIsOwnerOrControllerOfUnit` result with both units visible. A meter row
  already using the owner's player GUID follows the player path. A creature
  ID, pet name, ambiguous ownership or a second-unit pet name cannot identify
  an owner. Observed claims survive changes of target, token reuse and
  temporary visibility loss throughout one local window. An independent
  conflicting claim invalidates attribution. A qualifying pet action adds
  evidence about its verified player owner.
- The restricted combat log is not a supported alternative. The
  `UNIT_SPELLCAST_SUCCEEDED` payload identifies the casting unit and spell,
  but gives no recipient or applied effect. `UNIT_SPELLCAST_SENT` can include
  a conditional-secret target string on cast submission, without confirmation
  of successful delivery or all remote casts. `UnitTarget` is only a selected
  unit and does not cover mouseover casts, AoE or procs.
- `UNIT_AURA` incremental additions are a possible separate route for
  applied HoTs, shields, buffs and control. `C_UnitAuras.GetAuraDataByAuraInstanceID`
  requires aura access and can be secret; Blizzard's target aura mixin uses
  `AuraData.sourceUnit`, which is not guaranteed usable by addons. The
  preview logs up to 20 incremental additions on tracked units with
  aura instance, spell, target GUID, source unit/GUID, helpful/harmful flags
  and read status.
  It skips full updates, retains restriction counts, and does not use aura
  data for participation yet. Instant heals produce no lasting aura.

### Comparison with other Forever meters

These are implementation examples, separate from Blizzard's API contract.
They were inspected at the revisions linked below. No source was copied.
ForeverMeter is GPLv3, Damage Meter Forever has a root MIT license,
NetherMeters has a custom all-rights-reserved license, and no add-on-wide
license was found in Kodo-DPS at the inspected revision. All four include
a Forever 16001 TOC; that alone does not establish exact-build behavior.

| Project and reviewed code | Approach and application to Names in Red |
| --- | --- |
| **ForeverMeter** [`SpellTargets`](https://github.com/dldvlpr-addons-wow/threatMeter/blob/2a7ea9efd6d1dd92c281a00e311b75776d2b46a1/CombatBreakdown.lua#L25-L43), [`OpenSegment` and event handler](https://github.com/dldvlpr-addons-wow/threatMeter/blob/2a7ea9efd6d1dd92c281a00e311b75776d2b46a1/CombatBreakdown.lua#L187-L373), [`ForeverMeter.lua` session getters](https://github.com/dldvlpr-addons-wow/threatMeter/blob/2a7ea9efd6d1dd92c281a00e311b75776d2b46a1/ForeverMeter.lua#L763-L780) | Records local casts with relative times, optionally includes a cast shortly before combat, keeps a boss encounter open past a local combat transition, and associates positive session IDs to a segment for up to five seconds after it closes. Rejects already bound or numerically older IDs when a new segment is open. The source accepts a single detail object and an array. We adopt both shapes and a bounded settling window; our journal requires exact category/ID updates and cancels on re-entry, without relying on IDs being monotonic or casting implying a hit. |
| **ForeverMeter** [`SavableSegments` / `RestorableSegments`](https://github.com/dldvlpr-addons-wow/threatMeter/blob/2a7ea9efd6d1dd92c281a00e311b75776d2b46a1/CombatBreakdown.lua#L144-L176), [`CombatSync.lua` payload and sender](https://github.com/dldvlpr-addons-wow/threatMeter/blob/2a7ea9efd6d1dd92c281a00e311b75776d2b46a1/CombatSync.lua#L25-L70) | Reattaches closed timelines after reload by native ID, name and uptime. Shares successful cast spell IDs and timestamps between opted-in addon users, with no per-action recipient. Our journal persists its own records and leaves in-flight attribution transient. Timestamps from local observations may help a future boundary tracker; neither saved native IDs nor peer casts establish PvP recipients. |
| **Damage Meter Forever** [`containerIsOpen` / `startWaitSecretDropTimer`](https://github.com/gitBellucci/DamageMeterForever/blob/5a3fa4e337ae6c2df93fc3c3854f0bb47f2194aa/DamageMeterForever/core/parser_nocleu1.lua#L638-L756), [segment-update handler](https://github.com/gitBellucci/DamageMeterForever/blob/5a3fa4e337ae6c2df93fc3c3854f0bb47f2194aa/DamageMeterForever/core/parser_nocleu1.lua#L1924-L1977) | Queues named archives and polls each second while combat or fields remain restricted. Its segment parser uses increasing IDs and checks a predecessor ID. We check the Forever 70959 restriction API and retry once; a moving segment reference or local re-entry can otherwise misattribute roster links. This parser's actor totals do not resolve healing recipients, control, or the pet's owner in our data. |
| **NetherMeters** [`Meter:Session` / `Meter:Source`](https://github.com/g4nk3d/NetherMeters/blob/b6bd90cc7327ee6fa11e7ccb62ba69bc4bc71b0d/Data/Meter.lua#L124-L159), [combat handlers](https://github.com/g4nk3d/NetherMeters/blob/b6bd90cc7327ee6fa11e7ccb62ba69bc4bc71b0d/Data/Meter.lua#L238-L259) | Distinguishes explicit archive and type-based selection, passes GUID and creature ID to source getters, and marks the display dirty immediately and 0.6 seconds after combat. Its local clock is independent of the selected meter session. We keep explicit selectors and a bounded post-combat read. A creature ID remains a lookup argument without proving the player's ownership. |
| **Kodo-DPS / Moteve** [`GetSession` / `GetSessionSource`](https://github.com/zolesz05/Kodo-DPS/blob/90c8b1827ab3de28741babd889c75c1bdafca038/Moteve%20Damage%20Meter/Moteve.lua#L176-L201), [frame event handler](https://github.com/zolesz05/Kodo-DPS/blob/90c8b1827ab3de28741babd889c75c1bdafca038/Moteve%20Damage%20Meter/Moteve.lua#L1336-L1364) | Keeps the selected ID on the display frame, resets it on re-entry/reset, guards restricted display data, and can fall back to Current when a selected archive expires. We also treat archive selection as transient and invalidate a pending write instead of silently falling back. A display showing approximate continuity is a different tradeoff from attributing a lasting journal record. |

None of the reviewed paths establishes a reliable recipient for an instant
heal with blank detail, a second-unit pet's owner using only its name, or an
outdoor PvP boundary after local death while allies keep fighting. The
sources show local bookkeeping, named PvE encounters and aggregate meter
views. They do not show reliable splitting of independent outdoor fights
within one native session. Our disjoint-graph and overlapping-window tests
cover separations the available evidence can establish. If two fights
share a player within one aggregate, the same links could describe either
one continuous clash or two separate ones. A readable snapshot alone
cannot distinguish those cases. The next PR should first establish a
local hostile anchor without a killing blow and use timestamped
observations to constrain membership across gaps, continued fighting
after death, movement, and resumptions. No inference of the winner is
required to record the confrontation.

### Kill-free world skirmishes and observation boundaries

This section records the earlier recorder design and client evidence. See
[Character POV PR A](#character-pov-pr-a) for the current continuation rules.

The recorder keeps local combat windows separate from the saved confrontation.
A window becomes a journal record only after positive evidence. Its identifier
is allocated once and reused for later kills, deaths, rewards and enrichment.
The version-1 SavedVariables format accepts the extra `origin` and
`observation` fields without migrating earlier cards.

**Start signals.**

- A readable incremental `UNIT_AURA` application with `isHarmful` and
  `sourceUnit` can establish a timestamped hostile player-to-player link.
  Both units must have identified GUIDs on opposite sides; a new enemy must
  be attackable. An exactly identified local pet can represent the player.
  Full aura updates, missing or secret sources, friendly effects and NPCs
  cannot establish this link. This uses the event shape from
  `UnitAuraDocumentation.lua` and the source token used by
  `TargetFrameAuraContainerPrivateMixin:ShouldShowAuraWithLargeSize` in
  the pinned Forever source. The source contract does not guarantee that
  third-party addons can read the fields in live PvP.
- After local combat the existing meter reader can establish a connection
  from the local player to an observed enemy. A connected ally with a
  readable heal or shield can be the path to the hostile exchange. An
  unrelated component, unnamed totals, a selected target or party membership
  does not establish PvP. Existing confirmed kills and death recaps remain
  positive evidence. The recorder retains the prior checks, bounded retry
  and cancellation of ambiguous overlapping meter reads.
- Same-faction actions do not establish a fight. An explicit `DUEL_FINISHED`
  signal vetoes the provisional window; explicitly unflagged enemies cannot
  seed kill-free activity. Those signals do not supply an exhaustive
  cross-faction formal-duel identity, and this preview adds no duel history.

**Continuity and observation.** A local combat exit closes the observed
segment; it does not determine how the sides resolved it. An intervening
readable hostile action between already known allies and enemies can bridge
two nearby windows if the second contains that enemy and stays in the same
area. The five-second freshness limit applies to the bridging observation;
time, shared identities and inherited meter IDs alone are insufficient.
An isolated lost nameplate or stealth does not close an open local window.
Separate local windows without corroboration are stored separately. A
single untimed native aggregate that joins both fights through a shared
participant still cannot reliably split the confrontations. Unreadable
evidence can leave a legitimate fight unrecorded.

The initial record time is approximate. `observation.segments` stores
local opening/closing reasons, relative duration, why the episode was
confirmed, first/last positive aura observations per directed pair,
and available first/last contact sightings and final state samples.
The meter contributes undated opposing links with its selector metadata.
These remain distinct from confirmed killing blows in `events`. The owning
record also stores death, release and resurrection observations, including a
visibility gap. Death and release record the local character's state. The current
outcome observer can continue taking readable evidence in either state.
A gap recorded on a genuine scope change persists even if later
corroborating observations establish continuity. A long unobserved absence is
not filled in. Area and world changes stop attribution from pending meter
reads; a validated delayed death recap may still update the original
captured window in the same addon session. A logout saves confirmed live
activity; it does not reconstruct an unfinished candidate after reload.

**Targeted live verification.**

1. In open-world PvP, exchange ordinary hits with a flagged opposing player
   and disengage with both alive. Check that the journal shows a 1 × 1
   Unknown with zero deaths and zero rewards. Repeat with a named debuff to
   distinguish the meter and live aura paths. Targeting a player or fighting
   an NPC nearby should produce no card.
2. Help an ally against two opposing players, then disengage with no kills.
   Check the connected roster. Repeat two quick fights with different
   opponents, and then with one shared opponent. Record whether the native
   selector rolls over. Test a brief stealth pause and an actual allied
   action during the local combat lull.
3. Die while the others continue, release and return. Record whether the
   connected fight was actually visible during the gap, then compare the
   saved life states, segments and separate new engagements. A lost
   observation supplies no claim about what the allies did in its absence.
4. Repeat Duskwood and confirm two observed allies, three opponents, two
   finishing blows and five honor. Run a heal-only and a pet-only control
   with a known player link if checking recipient/controller availability.

Use a normal logout or `/reload` to save and share the diagnostic file
privately. The original Duskwood capture is real-client evidence. The
kill-free recorder, aura-only path, continuity bridges, ghost gap handling
and cancellation behavior have Lua 5.1 event-replay coverage. Native
delivery of the new live signals and actual meter rollover in these
scenarios still require a fresh Forever 70959 capture.

### World outcomes and observations after death

These are the legacy side-outcome rules and their client evidence. The journal
continues consuming that projection in PR A. See
[Character POV PR A](#character-pov-pr-a) for the independent personal result.

**Three independent axes.** The journal stores the character's life phase
(`observation.playerState` and timed `life`), whether the fight's ending
was observed (`resolution.ending`), and the coverage of different sources
(`resolution.coverage`, unit/position/state counts, and meter status).
A local combat exit opens the first opportunity to seek terminal evidence.
Death, release, resurrection and a lost plate alone do not mark the battle
finished or invalidate available observations. A genuine world/area change
stops sampling the old locus. An unfinished battle then stays Unknown.

**What the client documents.** Forever 70959
[`UnitDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
defines `UnitPosition`, `UnitIsVisible`, `UnitAffectingCombat`,
`UnitIsDeadOrGhost` and `UnitIsFeignDeath`.
Blizzard's tutorial uses `UnitPosition("target")`
([source](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_NewPlayerExperience/Blizzard_TutorialTutorials.lua#L971-L995)).
This establishes the API shape, not availability of hostile position
data to an addon in outdoor PvP, especially while ghosted.
`C_Map.GetPlayerMapPosition` has a player/party-only contract and cannot
fill in the hostile position. The observer requires readable values,
current unit identity and matched world map coordinates. A failed
position read never becomes a departure. Feign death is excluded from
terminal life evidence.

**Terminal rules.** Take two short, guarded snapshots 0.75 and 2.75 seconds
after the observation window closes or relevant new fighting is reported.
Readable changes to known participants' flags can trigger another pair
while tied to a recent hostile observation. A confirmed new hostile action
invalidates older terminal samples. The snapshots record visible roster
members, life, combat state and readable positions.

- Establish the site only from a witnessed hostile pair with nearby readable
  positions. A side can win when it has a visible, living member out of
  combat holding the site in both samples and every observed opponent is
  confirmed dead, visibly dead in both samples, or demonstrably withdrawing
  under pressure. A confirmed death within the fight has no expiry. A
  confirmed revival or a later readable alive sample supersedes its death
  state; the kill remains in history. Known active combat blocks the decision.
- A living departure can be observed through two consistent samples outside
  the 55-yard positional boundary, or an independently checked range exit
  before the unit becomes unreadable. Both paths require the latest witnessed
  action against the departing participant to come from a holder of the
  site and no later known attack by the departing player. The 12-second
  guard applies to pressure, and has no effect on confirmed deaths. There
  is no weighted kill score.
- Where coordinates are unavailable in an observed 1 × 1, a confirmed
  death plus two direct observations of the survivor alive and out of
  combat can resolve it. A personal death during a group fight is one
  event in that fight.
- Both sides seen leaving can yield an observed ending with Unknown
  winner. Missing positions or players, conflicting signals, stealth,
  intervening contest and unresolved pauses remain Unknown. A later
  verified continuation can replace an earlier provisional assessment.
  Legacy cards without the new assessment keep the original interpretation.
  Manual outcomes and personal rewards are independent of the resolver.

**Range exit without hostile coordinates.** Forever 70959 defines
[`UnitDistanceSquared`](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua#L1108-L1121)
with a separate `checkedDistance` result. Blizzard's
[compact unit frame](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_UnitFrame/Shared/CompactUnitFrame.lua#L1068-L1078)
uses that guard. Hostile checked-distance availability is unverified.
[`C_Spell.IsSpellInRange`](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua#L948-L962)
distinguishes out of range from an invalid query, and the
[hostile target action bar](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_GamepadActionBars/TargetActionBars/HostileTargetingActionBar.lua#L150-L155)
uses it for the current hostile target.

The preview records the local character's position and an initial readable
near/in-range result when the character applies a harmful effect to an
identified opponent. With checked distance, the near/exit measurements
are at most 30 and at least 40 yards respectively. The spell alternative
uses the same harmful spell with a zero minimum and 40–45 yard maximum, so
an out-of-range result cannot mean the target moved too close. Invalid,
unchecked, missing or secret readings supply no exit. The first terminal
sample must still identify the opponent alive and out of combat with a
positive exit check. The local holder must be alive, out of combat and
within five yards of the action position through both terminal samples.
The opponent may be unreadable in the second sample. If the second sample
reads it, contradictory position, range or combat evidence blocks this
path. The holding and scoped-hostility guards still apply. A plate loss
before a positive exit proves neither departure nor an ending.

For a fight like Duskwood this means two earlier kills, a readable exit
while the living opponent is still visible, and a sustained hold can
produce Victory even with no hostile coordinates. A fight cut off after
the same two kills stays Unknown. Mock tests model disappearing units,
unchecked and secret ranges, and minimum-range ambiguity. They do not
establish the set of Forever abilities or unit tokens that will expose the
required values. The new rule can still confuse a voluntary departure, or
an outward reposition followed by a later return, with being driven off.

**Meter while dead or ghosted.** The patch can reuse an eligible damage
sample as a baseline. On a matching subsequent category event it compares
only readable increases for previously identified hostile pairs under the
same selection. It checks the archive is still present, rejects changed
Current/reset, refuses decreases or incomparable pairs, and rate-limits
the event-driven reads. Scope changes, a new local combat or an invalidated
record stop use of that baseline. The receipt time describes when new
aggregate evidence was seen; the event is not an action timestamp, death,
retreat or ending. `POST_COMBAT_METER_UPDATE` records life/ghost flags and
why a delta could or could not be used. No events or unreadable data leave
observation unknown and supply no verdict. No polling is needed in a quiet
session. The patch does not assume these events or fields remain available
in the live client after death or release.

**Duskwood review.** The original owner log shows two kills roughly 13
and 22 seconds after local entry, the third enemy leaving nameplate
visibility around second 18 while alive and still in combat, and the local
hunter and priest out of combat at second 40. It contains no subsequent
position or combat state for the third enemy and no terminal position
observations establishing who held the site. The roster regression remains
2 × 3 with two kills and five honor. The available log yields Unknown.
A distinct positive replay of the same type of victory includes a visible
withdrawal under pressure and allied hold without inventing those fields in
the historical capture.

**Risks and live checks.** A voluntary departure can coincide with a last
hostile action and look like forced withdrawal. Two actions within one
untimed native aggregate can share a participant while belonging to
different fights. The positive positional checks and stable selection
reduce these risks, but cannot disambiguate every case. Few or capped unit
visibility/position reads increase Unknown. These rules are verified in
Lua event mocks and saved-data replays. Fresh live checks remain necessary:

1. Record one group fight and remain in the corpse while allies continue.
   Note whether `UNIT_AURA`, `UNIT_FLAGS`, visible roster states and meter
   details are still available. Compare against a fight where only the
   player leaves observation and the allies subsequently lose.
2. Repeat after releasing spirit. If the same scoped meter stays live,
   compare a sample before release, the post-combat delta status and the
   final visible states. Returning and attacking again does not itself
   establish the result of the earlier phase.
3. Run a retreat under pressure and a no-kill disengagement. Keep the
   withdrawing opponent targeted until the range check follows the combat
   exit, then let the target go out of sight while holding the site. Repeat
   with a brief stealth and re-entry as a negative control. Compare the saved snapshots
   and `resolution` reasons, then repeat Duskwood or its equivalent.
   Verify after a normal logout or `/reload`; share SavedVariables privately.

### Participant life history and personal scores

**Forever 70959 signals.** The generated
[`UnitDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua#L3724-L3733)
defines `PARTY_KILL` with attacker and target GUIDs. It has no unique
event ID or timestamp. `UNIT_FLAGS` supplies a unit token; the addon reads
that token's current GUID, visibility and `UnitIsDeadOrGhost` with the
existing feign-death guard. A later readable alive state of the same
participant is accepted within the tracked battle on flags, sightings or
a terminal sample. For the local character,
[`PLAYER_ALIVE` and `PLAYER_UNGHOST`](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_APIDocumentationGenerated/DeathInfoDocumentation.lua#L123-L150)
are additionally paired with a readable living state.

The client also exposes a resurrection offer or incoming status.
[`CompactUnitFrame`](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_UnitFrame/Shared/CompactUnitFrame.lua#L1470-L1478)
uses `UnitHasIncomingResurrection` to render that status. An offer does
not establish a completed resurrection. The supported path records a
state transition without naming the spell or caster. A known participant's
readable death without an attacker is recorded as `death`, with no kill
credit. If a validated finishing blow subsequently identifies that death,
its attributed event takes the place of the uncredited observation.
A druid's combat resurrection is indistinguishable here from any other
verified return to life. The patch uses the unit and player signals above.

**History and deduplication.** The timeline records a confirmed finishing
blow once for the observed life. A strictly later living observation adds
one `revive` for its matching GUID. A monotonic offset preserves the
order of live events within a server second. Older events retain their
server time or stored order. The death-recap adapter captures the event
uptime before retrying. A later state read cannot clear a newer death,
and the 12-second pressure threshold continues to apply only to the
outcome's pressure evidence. Missing or secret readings do not modify
life state. The optional first alive reading of an unobserved corpse
waits for a short flag-settling interval.

A repeated `PARTY_KILL` for a recorded death is ignored. Another
outgoing finishing blow in the skirmish requires an observed revival
and evidence of a new readable corpse. A validated local lethal recap
with its own strictly newer timestamp establishes another local death
even if the intervening revival was outside observation. The addon can retry that check
once after 0.25 seconds; competing actor notifications cancel an
ambiguous retry. Accepted notifications feed reward attribution once.
A late standalone notification for the last known corpse in the same
location cannot create another card. Without a readable revival or
corpse, the client payload cannot reliably separate an actual repeat
from a duplicate, so a real repeat can go uncounted. Legacy histories
remain as recorded; a previously duplicated old row cannot be resolved
retrospectively without evidence.

**Display and accounting.** Personal blows count directed `kill` events
from/to the local character and the specific rival. Legacy directional
combat rows also count. Manual wins and losses remain side results.
A separate line appears in the unit tooltip when there are personal
kills or deaths. Nameplate and profile win/loss counts retain their
skirmish meaning, and Honorable Kills and Honor Points still depend on
Blizzard reward signals. The portrait skull means the participant died
during the fight. A reliably revived participant keeps the skull and
returns to a colored portrait; the finishing-blow list keeps every
confirmed kill.

**Targeted Forever check.** In an ongoing group fight, kill an opponent,
have the opponent accept a combat resurrection, and kill them again
with the same side still contesting the fight. Observe whether the
returned player is reachable through target/nameplate flags before the
second kill. Also keep one resurrection offer unaccepted and have a
second fight with reciprocal personal kills and a clear side outcome.
Compare `events`, the historical skull and the personal tooltip. A
local revival inside the same fighting window and the separate outcome
can be verified from the saved monotonic offsets. Repeat with the local
character returning after release. These paths are exercised by Lua
event mocks; delivery of readable enemy state and actual combat
resurrection timing need a new live capture.

### Seeded full-battle cards

The 0.1.3-preview.2 cards use the existing book frames, text and world map
action. For class icons they use the native class sheet and UVs, following
`Blizzard_PVPMatch/PVPMatchTable.lua`. Class colors use the client's
`RAID_CLASS_COLORS` as in `Blizzard_FriendsFrame/Mainline/FriendsFrame.lua`.
The two-column roster and the time-ordered blow list are owned by Names in Red.
The test suite exercises card reuse across different roster sizes and verifies
that fixture removal preserves other saved records. Card rendering still
needs a Forever client check.

The current sample roster uses fictional encounters with consistent portraits
and levels. Open the Winterspring 2 × 2 rematch to test a recorded win after
the local player dies. The Eastern Plaguelands 5 × 6 loss awards honor for
two opponents. The Western Plaguelands crossing exercises an incomplete
roster and unknown outcome. See [the sample roster](debug-preview.md#sample-roster-for-screenshots)
for the screenshot sequence.

The live observer uses `PARTY_KILL` and local death recap rows to assemble
a partial open-world record. Killing-blow identity can come from the player
or a readable party member. A short tail after leaving combat lets a nearby
teammate's finishing blow join the same record. A long gap after combat, a
world change or resurrection starts a fresh observation. Check missing targets, ghost state
and the timing of kills your group makes after you die.

In the 0.1.3-preview.22 solo replay, two lethal recaps had no matching target
or mouseover. At both deaths the diagnostic log could still read the same
attacker's class and level from a nameplate. The death handler now takes a
GUID-keyed snapshot from ordinary nameplates as well as target and mouseover
before waiting for the recap. `C_NamePlate.GetNamePlates` follows the same
visible-plate path as the kill handler. Only recap-confirmed attackers enter
the roster. Verify a hostile finishing blow while targeting nothing, including
a delayed recap after the nameplate disappears. Old cards use known class and
portrait details. A missing attacker level can be recovered from an outdoor
combat-end observation in the same second and zone, with matching participant
GUIDs and a recorded local death. The cards otherwise leave the level unknown.

An open-world skirmish with one recorded rival, the local player alone on
their side and direct finishing blows between them is treated as an observed
duel. Use the recorded deaths to decide the result. Two eliminated sides
still leave the result unknown. The roster is recalculated on load and after
each update, so additional participants can reopen a provisional result.
The live solo replay should show one win, two losses and one honorable kill
for ten honor in the rival profile. Verify the markers in both card layouts.

The user's 70959 group log showed a session HK increase from four to five
317 ms after a readable player death credited to another attacker, followed
roughly one second after the kill by a localized honor message. The preview
correlates a single plausible player death with one session HK increment, using
`GetPVPSessionStats` and `PLAYER_PVP_KILLS_CHANGED`. Repeated notifications
are coalesced by the cumulative counter. For honor, it uses a single
`CHAT_MSG_COMBAT_HONOR_GAIN` delivery and the observed ruRU amount or a
numeric `CURRENCY_DISPLAY_UPDATE` for an honor currency. These events still
lack a shared victim identifier. Verify an isolated kill, simultaneous kills,
reward-only messages and secret data in the live client.

Both card sizes display the sum of the recorded rewards for the whole battle.
The footer follows the count-then-icon order of `BackpackTokenTemplate` in
`Blizzard_TokenUI/Camelot/Blizzard_TokenUI.xml`. The card uses 14-unit icons
with an 8% crop on each side to remove baked-in borders. The icon hover
identifies the reward earned in the skirmish. The full card places rewards
at the right of the Finishing blows heading and opens the list below it.
Check alignment with larger counts, and compare a team skirmish in both
card sizes and a fight without recorded finishing blows.

From preview.6 onward, a rival's linked cards open a full-width battle in
the same book. This follows the in-window detail transition in
`ProfessionsCraftingPageMixin:SelectRecipe` in `Blizzard_ProfessionsCrafting.lua`.
The Back control uses the native `UIPanelButtonTemplate` and `BACK` text as
in `Blizzard_ProfessionsCrafterOrderView.xml`. The chosen rival's highlight
uses the same `Professions_Recipe_Active` atlas as the book roster.
In Forever, check **Open skirmish** from Information and a scrolled rival
history, then **Back**. Include an old saved battle outside the latest 100
and a partial record. Check the selected highlight and localized button widths.

### Expanded evidence in 0.1.3-preview.3

The old preview captured kills, honor changes and death recaps. The next
preview added combat boundaries, party snapshots and post-combat meter data.
This preview adds visible player observations from target, mouseover and
ordinary nameplate events, plus readable target, pet, combat and death state.
The probe uses the unit tokens documented in Forever's
`NamePlateManagerDocumentation.lua` and `UnitDocumentation.lua`. It does not
read forbidden nameplates. Observations are candidates for investigation.
Visibility, a target change or a group entry alone does not prove participation.

Group and pet context is sampled around combat and readable kill events.
Group changes and damage-meter update IDs are recorded within the combat
window. The post-combat read probes deaths, interrupts and dispels alongside
the existing damage and healing categories when supported.
This preview saved up to 32 readable contact histories and eight previous
states per contact. Repeated flags were throttled. It stored the first
eight fully obscured kill events individually and retained the total at
combat end. The shipped participant search walks all eligible observations.
The earlier diagnostic sample size is not its roster limit. See
[Damage Meter participant research](#damage-meter-participant-research-forever-70959)
for current coverage and sample limits.

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
from `Blizzard_Professions.lua`. The book owns all row data and frames. It
blends 25% `DIM_RED_FONT_COLOR` into `PROFESSION_RECIPE_COLOR` for rival names.
Hovered names still use `HIGHLIGHT_FONT_COLOR`.
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

The book crops the top band of Camelot's `Profession-Background-Template2`
atlas from `Blizzard_ProfessionsFrame.xml`. The crop stays fixed at the
original band depth, including its lower edge, as the displayed width grows.
The details panel uses a plain recipe backdrop,
a proportional Engineering illustration with feathered edges in the lower right,
and the separate `common-insideframe` trim from Camelot's schematic XML. The portrait uses the
add dialog's circle mask and rim. UV insets remove the inventory bevel from
the fallback icon. Verify these surfaces in Forever.

The roster toolbar uses the professions search box and the native Friends
add icon. Check UTF-8 name filtering and clearing, selecting the first result,
and adding a manual rival while filtered. The native delete confirmation names
the selected rival and captures its ID when opened. Verify that cancel leaves
the record intact and accepting removes only that record, including when two
rivals share a display name.

The statistics section instantiates `ProfessionsReagentSlotBaseTemplate` in
`Blizzard_ProfessionsRecipeReagentSlotBase.xml`. Its `Button` inherits
`ProfessionsButtonTemplate` and the intrinsic `ItemButton` mask and layers.
It uses the ordinary reagent state from `SetModifyingRequired(false)`, the
native `SetItemButtonTexture` path, and `SetSlotQuality(Common)` for the
profession frame. The book supplies the icon asset and localized tooltip
without binding the button to an item or crafting transaction.
The reference places whole reagent rows and insets the visible artwork
inside them. Check the heading-to-art gap and the step between rows
separately. The schematic's optional-reagent section supplies the reference
for the last-encounter heading and gap. The owner compared these areas
side by side with tradeskill recipes.
[Reagent layout](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_ProfessionsTemplates/Blizzard_Professions.lua#L1394-L1415) ·
[Schematic section](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_ProfessionsTemplates/Blizzard_ProfessionsRecipeSchematicForm.xml#L66-L92)

## Skirmish cards and the world map

The book uses `PanelTopTabButtonTemplate` from Forever
`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml`. The tab textures are
bottom-anchored by `PanelTopTabButtonMixin:OnLoad`. The book places the tabs
above a sibling pane whose `common-insideframe` trim covers their lower edge.
The `transmog-tab-hl` strip follows the `SelectedHighlight` layer in
`TransmogWardrobeCollectionTabTemplate` and the selected-state handling in
`TransmogWardrobeCollectionTabMixin:SetTabSelected`. It draws above the pane
from a child frame anchored to the tab's bottom corners, so the span follows
the localized label width. The book uses a two-unit strip with its upper
edge meeting the tab's bottom baseline.
Initial sizing uses the same text-based `PanelTemplates_TabResize` as
`PanelTabButtonMixin:OnShow`. Check that the first open after a reload and
subsequent opens use the same compact widths.
The settings reference is `GameTab` and `AddOnsTab` in
`Blizzard_SettingsPanel.xml`. Their `MinimalTabTemplate` swaps to
`Options_Tab_Active_*` via `MinimalTabMixin:UpdateAtlas`. The book keeps its
three active `uiframe-activetab` slices and lowers their brightness.
Camelot's `SchematicFormCraftingTemplate` in
`Blizzard_ProfessionsRecipeSchematicForm.xml` uses that same rim on the BORDER
layer. The full right column uses the same `Professions-background-summarylist`
atlas as the roster and `Blizzard_ProfessionsRecipeList.xml`. The right
column underlay lives on the page's BACKGROUND layer. The inset reaches the
bottom of the book, with a red Delete control inside its upper-right corner.
The control follows `GearSetButtonTemplate`'s `DeleteButton` from Camelot
`PaperDollFrame.xml`, including the `UI-GroupLoot-Pass-Up` texture and hover
opacity. Check it on Information and confirm it is hidden on Skirmishes.
Delete confirmation uses the client's shared
`StaticPopupButtonTemplate` from `Blizzard_StaticPopup_Game/GameDialog.xml`.
The book fades the left side of its illustration into the recipe
background using the texture gradient API. Check that the upper rim is
continuous in both tab states and that the illustration has no visible seam
at its left edge, including at non-default UI scales.

Encounter history uses `ScrollFrameTemplate` and reuses cards as the viewport
scrolls. The global and linked full-skirmish views share the card-list layout,
scrollbar gutter, and battlefield background. Their summary-list backdrop
uses the same tint (0.76) and the illustration uses the same alpha (0.24) as
the Information pane. Compare the empty views and check both tabs on 1.60.1 with
empty, legacy, manual and seeded histories. Scroll through a long history,
then switch rivals while scrolled.

The rival sidebar uses the native `WowScrollBoxList`, `MinimalScrollBar`, and
`ProfessionsRecipeListRecipeTemplate` in
`Blizzard_ProfessionsTemplates/Blizzard_ProfessionsRecipeList.xml`. The recipe
button's overlays keep the atlas dimensions, including the 0.5-alpha hover.
`ProfessionsRecipeListRecipeMixin:GetLabelColor` and `OnEnter` supply the
recipe and highlight colors. The journal binds its own names and click and
hover handlers because the native handlers read crafting recipe IDs. If the
load-on-demand recipe template is unavailable, the row uses its font and
atlas geometry on a plain button. The linear view uses the recipe tree's
20-unit entries, 1-unit spacing, and one level of recipe indentation.
The 304-unit sidebar width comes from `ProfessionsCraftingPageMixin:OverrideArt`
in Camelot's `Blizzard_ProfessionsCrafting.lua`. The search box uses the
recipe list's anchors and height, with the add button centered over the scrollbar.
Check the first open before opening any profession, hover and selection during
scrolling, search while scrolled, and the adjacent add and scrollbar alignment.

Both skirmish card layouts use `CommonSquareIconButtonTemplate` from
`Blizzard_SharedXML/Shared/Button/IconButtonTemplate.xml`, including native
tooltips and click handling supplied by `UIButtonMixin`. Its icons come from
`WaypointLocationPinTemplate` and `UIPanelInfoButton`. The button frames are
32 units square with 16-unit icons. Center the icon at rest and restore that
center after `SquareIconButtonMixin:OnMouseUp`. The
header uses the square template's scaled four-unit inset to match the date-to-map
and map-to-information gaps. Both map buttons share the same center anchor and
pixel rounding. The compact information icon uses a half-unit upward
adjustment. Verify the diamond at different UI scales, before and after clicking.
All dividers use the factor from Blizzard's `PixelUtil.lua` divided by the
texture's effective scale. The two-pixel height and lighter opacity keep the
line subtle and give it coverage as scrolling lands between physical pixels.
The layout rounds to the pixel grid and the texture skips separate texel
snapping. The full header, roster headings and timeline use the same dividers.
Check their visibility while slowly scrolling at different UI scales.
The profile and both card layouts use the same 64-unit portrait and 24-unit
level badge. Card names wrap to two lines. Level and class badges share the
same frame and anchor to opposite lower corners. Class icons use the game's `CLASS_ICON_TCOORDS`
sheet as in `PVPCellClassMixin:Populate`, with a circular mask and a localized
tooltip. The badge rounds its radius to a physical pixel using
`PixelUtil.GetNearestPixelSize`. Its circle and label fill the same
pixel-rounded bounds. The label uses horizontal center and vertical middle
alignment with `GameFontHighlight` throughout the journal. The texture disables separate texel snapping, as in
`NineSliceUtil.DisableSharpening`.
Check levels 54, 55 and 57 on both sides at different UI scales. The rim uses
`Mode-Selection-Ring`
from `Blizzard_GlueXML/Mainline/SuperDistrict.xml`. The highlight draws the
same rim at 0.45 alpha in additive mode, following the profession output
button's inherited `CircularGiantItemButtonTemplate` in
`Blizzard_ItemButton/Mainline/ItemButtonTemplate.xml`. In a linked fight, the
selected rival keeps its rim glow via `LockHighlight`. Check that neither hover
nor selection changes the image inside and that scrolling releases the glow
when the tile is rebound.
Both layouts share a 56-unit result badge and localized caption. Victory and defeat use captions
alone. The unknown result and skulls retain their tooltips. The circle art
comes from `UI-HUD-UnitFrame-SmallCircle` in Camelot's
`TargetFrameTemplates.xml`. The casualty marker uses a 20-unit circle in both layouts. Verify badge text, mirrored sides, and
tooltips at several UI scales.
A local portrait with no saved race portrait uses `SetPortraitTexture`, as in Camelot's
`CharacterFrameMixin:UpdateCharacterModeTabPortrait`. Race portraits use the
`resetTexCoords` argument to `SetAtlas`. The compact rival portrait flips its
full atlas region horizontally with `SetTexCoord(1, 0, 0, 1)`, following
`Blizzard_OrderHallUI/Blizzard_OrderHallTalents.lua` where the same talent atlas
is drawn facing either way. Check the full crop in the profile and the compact
card, and click the same rival repeatedly to verify the direction.
The book is 810 by 640 UI units, with the 304-unit Camelot recipe list width
on the left. The right panel uses `ProfessionsReagentSlotBaseTemplate.Name`
with its `GameFontHighlight_NoShadow` font and 46-unit horizontal offset. The
heading uses the 20-unit `GameFontNormalSmall` label from
`ProfessionsReagentContainerTemplate`. In `Blizzard_Professions.lua`,
`LayoutReagentSlots` and `LayoutAndShowReagentSlotContainer` both start slots
20 units below their heading's top. `ProfessionsReagentSlotBaseTemplate`
centers its 39-unit button within a 50-unit row, leaving 5.5 units from the
label box to the button. The score grid uses that inset and the native
45-unit row step. The last encounter card uses the same 5.5-unit inset below
its label. `OptionalReagents` in `Blizzard_ProfessionsRecipeSchematicForm.xml`
supplies the 20-unit gap between sections. Portrait captions in both card
layouts use `RAID_CLASS_COLORS`. Compare the Information panel with Enchanting
and check a 5 × 6 lineup and the scroll area on a 1920 × 1080 client.
The Honorable Kills slot uses a 128 × 128 gold chevron texture with 21 texels
of background on each side. `ProfessionsButtonMixin:OnLoad` positions the
frame separately from the icon. The preview.38 and preview.39 screenshots
showed opposite imbalances. The square crop samples 0.75 texel farther right,
half the preview.39 adjustment. Check the chevron's centering and legibility
in Forever at normal and reduced UI scales. The
Honor Points stat follows
`TokenEntryMixin:Initialize` in `Blizzard_TokenUI/Camelot/Blizzard_TokenUI.lua`
and displays the `iconFileID` from the native currency list. A hidden currency
can still supply its icon via `C_CurrencyInfo.GetCurrencyInfo` for Classic
Honor. The generated `PVP_CURRENCY_HONOR_*_INV_ICON` constants provide faction
fallbacks. Compare the artwork with the Currency tab on Alliance and Horde,
including a collapsed PvP category. Check that the stat labels keep their
left edge as the counts change.
`PVPMatchStyle.GetLocalPlayerFactionTheme` uses the first return from
`UnitFactionGroup("player")`. The skirmish cards use the same faction tag to
order the existing blue and red palette. `Blizzard_UnitFrame/Camelot/TargetFrame.lua`
directs `TargetFrameMixin:GetPvPIndicatorElements` to `PvpBackgroundIcon`. The
full card uses its `UI-HUD-UnitFrame-SmallCircle-Alliance` and
`UI-HUD-UnitFrame-SmallCircle-Horde` atlases from Camelot's
`UnitFramePvPIndicatorStyle.lua`. Each emblem fits an 18-unit box at its
authored aspect ratio before the heading. Translucent roster panels and card
backdrops reveal one centered battlefield texture attached to the stationary
pane. The cards are attached to the scroll child. Scroll a long history and
verify that the artwork stays centered. Check the colors and emblem order
for both factions. Include the Eastern Plaguelands loss with honor and the
incomplete Western Plaguelands fixture. Verify that a card rebind clears stale
tooltips and that the map action remains available on mapped legacy cards.

Treat badge alignment, icon crop and state reset as separate regression
cases. For example, after a mirrored profile/card switch, a cached texture
can keep its previous UVs unless the atlas application resets them before
mirroring. Rebind the same tile from a dead or highlighted opponent to an
alive participant and then to a class fallback. Check that the current
portrait, rim, tooltip owner and level are restored together. The shared
profile and card use the same geometry. [Shared portrait](../NamesInRed/Portraits.lua) ·
[Earlier mirrored portrait fix](https://github.com/nick-sidorin/names-in-red/commit/9dc353b5534e2b70859e4037ffd7683ab06ef767) ·
[Book tests](../tests/book.lua)

Roster rows center independently on each side. One or two portraits use one
row. Three or four use two rows. Larger groups use the fewest rows that fit
three per row, with any extra portraits assigned to the upper rows. Verify
3, 4, 5, 6 and 7 portraits, including a sparse side opposite a full group.
The timeline header uses the native `common-icon-forwardarrow` art on a
button owned by the card list. The button sizes to the arrow, caption and
count. Its `GameFontHighlightSmall` font state brightens the caption on hover.
`ExpandBarMixin:OnEnter` also uses a local control highlight. The journal's
button remeasures the scrolling list when the rows change. Each finishing
blow arrow anchors to the target label's vertical center. Test expansion,
collapse and card reuse while scrolling. History starts collapsed and the
linked detail view starts expanded.

For the map diamond, see `WaypointLocationDataProviderMixin:HandleClick` and
the MAPPIN slash command in
`Blizzard_SharedMapDataProviders/WaypointLocationDataProvider.lua`. The book
uses the command's waypoint flow, including `OpenMapToUserWaypoint` from
`Blizzard_WorldMap/Blizzard_WorldMap.lua`. Test with a seeded card from a
different zone. Check that the world map opens on that zone, places its
standard user pin at the saved coordinates and replaces any previous user
pin. The full card uses the same map pin button as the compact card, anchored
beside the timestamp. Check the common header centerline and the spacing in
the finishing-blow list. Check that the Skirmish History scrollbar is centered
in the gutter between the cards and the decorative frame. The roster count
always shows the participants in the card. A passive `UIPanelInfoButton` from
`SharedUIPanelTemplates.xml` shows
the coverage tooltip when `rosterComplete` is false or absent. Seed fixtures
set this flag explicitly. Converted one-death entries lack a complete roster
confirmation, so their displayed counts show the known participants.
For legacy cards the addon uses `C_Map.GetMapChildrenInfo` from
`Blizzard_APIDocumentationGenerated/MapDocumentation.lua` to index Azeroth's
zone maps by localized name. Check older Hillsbrad and Stranglethorn cards
like the owner's screenshots, plus an unresolved zone. Verify the saved
location through the map action and that a rejected waypoint leaves the book open.

Preview.4 uses one tinted `Professions-background-summarylist` texture from
`ProfessionsRecipeListTemplate` across the entire right side of the rival
book. The inset frame and translucent battlefield illustration are separate
layers. The roster hover uses the native quest list texture from
`QuestLogFrame.xml` with reduced intensity. The finishing blow marker reuses
`common-icon-forwardarrow` from `GamepadNextPageButtonTemplate`.

### Window ordering, sounds and minimap hint

Forever 70959 loads the Camelot `ProfessionsFrame` from
`Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.xml`. The shared
`ProfessionsFrameBase` uses `PortraitFrameTemplate` with `toplevel=true`.
`ProfessionsMixin:OnShow` and `OnHide` play the two
`UI_PROFESSIONS_WINDOW_*` sound kits. The book uses the same portrait
template and sound kits in its own visibility handlers.

The book remains a movable, independent top-level frame and uses the
ordinary MEDIUM strata. The old DIALOG strata always drew above a MEDIUM
frame regardless of its level. DeModal's `HookMovable` sets the supported
profession window to top-level and raises it on show, while BlizzMove
supplies drag behavior for registered Blizzard frames. The book uses native
top-level ordering and raises its own frame when shown.

The minimap tooltip follows Azeroth Fitness's `Shortcut:Init` implementation
in `Minimap.lua`, using a left anchor, title and a three-line localized hint.
Check first open, reopen, Escape and the close button for one sound per
visibility change. With DeModal and BlizzMove, overlap the book and
Engineering, then click the visible part or header of each alternately.
Check that both remain open and the clicked panel comes to the front.

The journal's `MakeDraggable` attaches a left-button drag region to the
title only. It excludes the portrait and close control, and a shared stop
handler runs on drag stop and on window hide. `UIPanelCloseButton_OnClick`
calls `onCloseCallback` before `HideUIPanel`. The journal hides its own
frame in that callback and returns false. Its hide hook also clears search
focus and the Delete confirmation. The profession sound pair is in the
visibility hooks, so changing a view or refreshing a list leaves it silent.
[Journal source](../NamesInRed/Book.lua) ·
[Native close callback](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua#L152-L164) ·
[Profession sounds](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_Professions/Blizzard_ProfessionsFrame.lua#L520-L542)

The manual-entry dialog owns a separate mouse and wheel shield. Cancel,
the native close button, hiding the parent or hiding the dialog release
that shield and clear EditBox focus. The addon gives the
`AutoCompleteEditBoxTemplate` handlers the first chance to consume Enter
or Escape, and uses a plain input box when autocomplete is unavailable.
This distinguishes choosing a suggestion from saving a fight and
dismissing a suggestion from closing the modal. Verify these paths as well
as hiding the parent mid-entry. [Manual dialog](../NamesInRed/ManualDialog.lua) ·
[Native Enter handler](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_AutoComplete/AutoComplete.lua#L358-L384) ·
[Native Escape handler](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_AutoComplete/AutoComplete.lua#L425-L436)

The minimap shortcut converts cursor coordinates to minimap UI units with
`GetEffectiveScale` before computing the persisted angle. It restores
that angle against the current width and height after a minimap resize.
`OnUpdate` is installed only during a drag. Drag stop and hide remove
it, and the subsequent left-button release cannot open the journal.
The frame keeps the tooltip local to its owner. Click, drag and resize
are separate checks. [Minimap shortcut](../NamesInRed/Book.lua)

## AddOn settings and data reset

Use `Settings.RegisterVerticalLayoutCategory`, `RegisterProxySetting` and
`CreateCheckbox` from `Blizzard_Settings_Shared/Blizzard_Settings.lua`.
Use `CreateSettingsButtonInitializer` from `Blizzard_SettingControls.lua` for
both actions. `Settings.OpenToCategory` opens the registered category from
the minimap right-click. Confirm that left-click still opens the journal
and dragging only moves the shortcut. With a known rival present, toggle
each display setting independently, confirm the change on the visible UI and
reload to check persistence. Unit tooltip refresh uses
`GameTooltipDataMixin:RefreshDataNextUpdate` from `Blizzard_GameTooltip`.

The custom confirmation and copyable URL use `StaticPopup_Show` and
`GameDialogMixin:GetEditBox`. `LaunchURL` is restricted in the client's
`URLDocumentation.lua`. Test Cancel, Escape and then Reset data on a character
with seeded records and diagnostic rows. Check the empty journal and confirm
that the two display flags and minimap position persist. Check that diagnostic
recording resumes with new events. The support dialog should select the
project's Issues URL for copying.

## Cross-rival skirmish history

The outer navigation follows `UI:Build` and `UI:Show` in Azeroth Fitness
`UI.lua`, and the `ProfessionsOverviewTab` anchor in
`Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.xml`. It uses
`LargeSideTabButtonTemplate` and the native
`SidePanelTabButtonMixin:SetCustomOnMouseUpHandler` and `SetChecked` handling.
The two pages share the main book window. Clicking a known opponent in the
journal opens their profile even with a previous search active. The journal
uses the same two-sided battle card for all records. Older one-death entries
show their recorded participants, finishing blow and map data with a partial
roster tooltip. Their original saved data remains in the ledger.

The journal displays at most 100 cards across the ledger. It preserves older
saved entries and uses a bounded sorted list and a viewport-sized frame pool.
New manually added entries use their recording time for ordering. Historic
manual entries without a timestamp follow dated ones.

In Forever, check both side tabs and their hover and selected states, drag to
the right screen edge, open the history with and without entries, scroll to
the bottom, switch back to an opponent from the history with a prior roster
search active, and verify map buttons in both views.

The Rivals tab uses the icon from `RosterTab` in
`Blizzard_Communities/CommunitiesFrame.xml`. Both side tabs retain the native
`common-sidetab-mask` and the icon treatment in
`SidePanelTabButtonMixin:UpdateIconInterior`.

The addon list, window portraits, minimap, statistics, cards, manual dialog,
tooltip and nameplate use the same transparent `CrossedSwords.tga`. Framed
icons keep their native anchors and masks; square and inline icons use
centered texture coordinates for their display size. Inline texture
coordinates follow the format used by `GuildRewards.lua`.
The minimap uses the `MiniMap-TrackingBorder` and backing from
`Shortcut:Init` in Azeroth Fitness `Minimap.lua`. The icon is centered in
the visible opening of the border, which is near (20, 19.5) in its 64 × 64
source texture. That opening was measured in the public texture extraction
`Gethe/wow-ui-textures@d23deaf8f44a7d280dc974a5c9d5321c013db59b`.
Like the First Aid window, the book sets its portrait through `SetPortraitToAsset`. This is the
path used by `ProfessionsMixin:Refresh` in `Blizzard_ProfessionsFrame.lua`.
The stock `PortraitFrameTemplate` controls the portrait and mask placement.
The branded portrait samples a 120 × 120 window of the 128 × 128 artwork.
The portrait crop samples two texels farther right and the statistics crops
sample one, after the owner reported a slight left skew in the statistics.
The minimap samples the same artwork in a 23.5-unit square centered on its
existing circle mask. The
stock mask, reagent frame and texture anchors remain native. Reference mode
uses the full native icon and restores the branded crops when it exits.
The defeat statistics slot uses the painted square banner with a background.
The wide transparent banner marks defeats on cards and in the manual dialog.
The small pink skull marks losses in the nameplate and unit tooltip counters
and recorded deaths on portraits. The transparent banner comes from the
statistics artwork.
Its lower fragment is shorter and points inward to leave clearance at the
left edge of the result circle. Cards draw it at 95% of the circle's diameter.
Compare the header to First Aid and both statistics slots to reagent icons
in the live client at normal and reduced UI scales.

In the 0.0.54–0.0.59 previews, with an opponent's Information tab visible,
`/nirdebug icons` swaps the window
and statistics art for First Aid, Linen Cloth and Wool Cloth in the same
frames. The addon portrait backing is hidden in reference mode. Run it again
to restore addon art. The chat diagnostics report the
center differences between texture and mask or border regions in UI units.
The region bounds include atlas padding and do not measure the center of the
visible paint. Compare before and after in the same client session.
The owner's 0.0.54 comparison shows the First Aid drop in both title portraits
and Linen Cloth in both reagent slots at approximately the same relative
positions. The inline captures support a visual comparison, with an estimated
one-to-two-pixel uncertainty in locating the edges.

The transparent defeat banner needed an asset encoding correction. Its
TGA descriptor changed from `0x28` to `0x08`, with the scanline order
reversed. Both decode to the same image. Check origin and scanline order
together for future replacement art. The manifest checks uncompressed
encoding, dimensions and alpha depth. Orientation and clearance are
visual checks. [Banner change](https://github.com/nick-sidorin/names-in-red/commit/022ebfd2ebffcb5a6214345cc29cddcc33ff4763) ·
[Manifest checker](../scripts/check_manifest.py)

### Public issue reports

The journal header and each card use Blizzard's bug artwork from
[`PTR_IssueReporter.Assets.BugReportIcon`](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_PTRFeedback/Blizzard_PTRFeedback.lua#L37-L50).
The header report button uses the same native `SharedButtonSmallTemplate`
as the former Delete button, including its three-slice `128-RedButton`
art and pressed state. `SetTextToFit` sizes the button around the
localized label and inline icon. The adjacent prompt keeps the active
client font and adds one point to its inherited size.
[Template](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_SharedXML/Shared/Button/ThreeSliceButtonTemplate.xml#L60-L91) ·
[Sizing mixin](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_SharedXML/SecureUIPanelTemplates.lua#L81-L92)
The addon owns the report window and uses the shared
[`InputScrollFrameTemplate`](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml#L72)
and its normal EditBox selection and scrolling. The report reuses the manual
entry window's rock background from Blizzard's
[`PortraitFrameTemplate`](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml#L624-L662).
The form link precedes the report so each can be copied in sequence. The native feedback
submission flow is outside this feature.

The owner's screenshots showed the older button art and a split filename
in the 550-unit dialog. The footer now uses the 28-unit native height of
`SharedButtonSmallTemplate` and refits the text on page changes. The
660 × 410 window shows the path on a separate line with mid-word wrapping
disabled. `InputScrollFrame_OnLoad` sizes the EditBox from the scroll
frame width during initialization. The addon sets the EditBox width after
placing the scroll frame. The shorter viewport holds the whole current
part. Select-all highlights it and switching parts returns to the top.
The tests exercise selection and paging. The final path fit and system
clipboard behavior remain client checks.
[InputScrollFrame source](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.lua#L82-L109) ·
[PR #31](https://github.com/nick-sidorin/names-in-red/pull/31) ·
[Report tests](../tests/issue-report.lua)

The copy field contains a fenced JSON Lines report. Each line is an object
with a `section`, beginning with format version 1 and ending with a list of
truncated sections. Player aliases are scoped to the report; names, GUIDs,
account metadata and raw chat are omitted. Review the remaining public
context before posting. A saved segment retains a compact meter status and
reason counts with its exact combat-end reference. Only an unambiguous
session, combat sequence, server time and uptime match can add a retained
debug row. Evicted rows and unlinked legacy records are explicitly labeled.
Automated tests exercise the projection and EditBox actions. Native sizing,
scrolling and clipboard selection still need a client smoke check.

### Battleground combat windows

Forever build 70959 exposes the instance type and map ID through
[`GetInstanceInfo`](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_APIDocumentationGenerated/InstanceDocumentation.lua#L103-L121).
The recorder accepts an open-world context or an enabled instance whose
`IsInInstance` type is `pvp`. It does not extend recording to arenas,
dungeons or raids. The stored map ID identifies the battleground map, not
the match, and Damage Meter session IDs identify data sources. Neither
identifier joins local fights. A raid member's kill can extend a local
battleground fight only when both participants are already linked.

The native
[`HandleAreaSpiritHealerInRange`](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_Game/Shared/EventImplementation.lua#L107-L114)
queues the player at a spirit healer. The addon uses that range signal
together with observed spirit and living states to stop carrying the
previous local window into a fresh fight. A release alone leaves the
observer running. A return from spirit state without recent linked
hostility also starts fresh observation. When readable, a return within
ongoing linked combat can still be represented in that fight. The
[`PVP_MATCH_COMPLETE` payload](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_APIDocumentationGenerated/PvpInfoDocumentation.lua#L1420-L1431)
does not determine local outcomes. Match completion stops collecting;
independently observed results remain, and unfinished assessments can
remain Unknown.

Lua event tests cover the gates, two local fights on the same map, spirit
respawn, continuing combat, repeat kills, linked healing, and a local
victory during a match loss. New live captures are still needed to determine
which identities, target details and post-combat states remain readable in
active Forever battlegrounds. Missing data may leave support players,
rewards, repeat kills or results unconfirmed.

### Gnomeregan regression evidence

The owner captures are private. The following observations are reproduced by
anonymized Lua fixtures; saved character names, GUIDs and raw messages are
excluded from version control.

| Case (local time) | Evidence and fix | Remaining limit |
| --- | --- | --- |
| 22:22 isolated death | A hostile player lands the lethal recap hit with 140 overkill after NPC damage. A single standalone death window has no connected continuation, so it can retain Defeat after a spirit transition or area change. Already classified terminal samples can likewise survive a later observation interruption. | The detected 1 × 1 is evidence about the recorded episode. It does not certify everyone nearby. A grouped or extended fight still needs team evidence. An NPC finisher cannot establish a PvP Defeat. |
| 22:22 missing level | The attacker appears in the lethal recap without a readable unit level. Earlier in-window levels and brief subsequent sightings can fill an empty field by the same GUID. An explicit skull-level is a separate value. | This capture supplies no verified level or skull value for the attacker. A secret or absent level remains unknown. |
| 20:09 off-target teammate kill | Notifications at +15 s and +18 s are both readable; the teammate's victim was seen earlier. A deferred exact-GUID kill is admitted when a proven participant connection links it to the original window. Both blows keep their original timestamps. | A nearby kill with no connection, an inaccessible identity, or conflicting unattributable events is omitted. |
| 20:20 missing teammate | The roughly 8.56 s local window and 11 s Damage Meter duration disagree. Both scoped damage-category activity and a readable pair linking the teammate to the already confirmed enemy support the recovered edge. | A longer aggregate with no direct anchored pair or a Current slot overlapping a previous window is rejected. No duration tolerance was increased. |
| 20:08 second corpse and group result | The contact loses its nameplate after a readable dead state. A death event requires the same known participant and a negative Feign Death reading. Two quiet terminal snapshots that keep survivors together and stable can establish an observed group elimination without a site anchor. | With a missing corpse, an active opponent, dispersed survivors or unobserved resolution, the group result can remain Unknown. |
| 20:21 omitted window | The previous first read obtained meter metadata, but deferred details until the next fight had displaced the Current slot. A readable anchored hostile link on the first pass now commits a kill-free record before that handoff. | The historical first window did not retain pair detail. The next aggregate spans both windows and cannot retroactively attach isolated rewards or establish the old roster. |
| Honor | The attached diagnostic window contains 39 honor across ten lines, of which old cards account for 25. From the updated build, readable earned totals are retained at rival, skirmish or journal scope. An identified line is counted once in the bounded line-ID deduplication window; known HKs remain independent. | Old unassigned totals are not reconstructed from a rolling debug buffer. Readability, attribution and locale fallback still limit what can be recorded. |

The Camelot
[`CompactUnitFrame_UpdatePlayerLevelDiff`](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_UnitFrame/Shared/CompactUnitFrame.lua#L1521-L1545)
reads `UnitEffectiveLevel`. The
[Camelot level indicator](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_NamePlates/Camelot/Blizzard_NamePlateLevelFrame.xml#L18-L28)
defines the skull atlas reused by the portrait badge. It takes an explicit
`-1` from a readable level API to show the skull. A readable positive
effective level is displayed numerically, regardless of a difficulty
color or the player's level gap. The badge stays hidden when neither
level API supplies a usable value.

Per-skirmish reports include the outcome and its independent interruption
reason, staged kill decisions, meter qualification and reward scope.
The general report includes recent, bounded decision summaries and journal
reward totals even when no fight card exists. These paths do not export
chat text, character names or original identifiers.

### Primary combat diagnostics in Forever 71037

Source baseline for this section is the [1.60.1 build 71037 UI dump](https://github.com/Gethe/wow-ui-source/tree/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns).
The generated API describes payloads and restrictions. The display UI
confirms how Blizzard consumes them. Actual addon-event delivery, data
readability and field completeness during a live PvP session still vary.

| Input | What the API describes | What Names in Red retains |
| --- | --- | --- |
| [`UNIT_COMBAT`](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua#L4168-L4182) | A unit token, effect, flag, school and an amount marked `SecretValue`. Neither attacker nor spell ID is supplied. The native [combat feedback](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_FrameXML/Mainline/CombatFeedback.lua#L26-L88) uses tokens such as WOUND, HEAL and CRITICAL. | Samples for tracked units with the recipient when readable, known effect and flag tokens, and a numeric school or amount only when the actual value can be read. A missing attacker or spell is left unknown. Identical deliveries can represent separate hits. |
| [`UNIT_AURA`](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua#L644-L656) and [update structure](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitConstantsDocumentation.lua#L55-L66) | Unit and aura update, marked `SecretWhenAurasRestricted`. Updates can be full or incremental. | Bounded sample of additions, spell ID, helpful/harmful flags, source and recipient where readable. Full refreshes, missing fields and restricted tables are labeled. No additional aura queries or inferred applications. |
| [`UNIT_SPELLCAST_*`](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua#L4611-L4657) and [start/succeeded events](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua#L4803-L4860) | Caster token, cast GUID and spell ID with `SecretWhenUnitSpellCastRestricted`; selected phases expose an interrupter. `SENT` has a conditionally secret target name. | Start, succeeded, interrupted and channel start/stop. Caster and interrupter are captured independently when readable. Success does not prove a hit, target or amount. `SENT` and its target string are excluded. |
| [`COMBAT_LOG_MESSAGE`](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/CombatLogSecureDocumentation.lua#L126-L141) | Preformatted `|K`-wrapped text, color and order for the native display. [`COMBAT_LOG_EVENT_UNFILTERED`](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/CombatLogDocumentation.lua#L123-L138) is marked restricted. | The addon does not subscribe to either. Protected display text cannot supply a structured source, target, spell or amount. |
| [`C_DamageMeter`](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/DamageMeterDocumentation.lua#L170-L243) | Category totals, source totals, spell totals and optional usable second-unit details. Session and source getters are `SecretWhenInCombat`. Names and GUIDs can be restricted independently. | Sample from the same accepted read used by the existing meter scanner, with category, spell ID, readable amounts, resolution of the second unit, selection and session ID when archived. The meter unit is the affected unit in Damage Taken categories. Total fields are separate and may overlap. The receipt offset timestamps the read rather than individual damage or healing. |
| `PARTY_KILL`, [`C_DeathRecap.GetRecapEvents`](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/DeathRecapDocumentation.lua#L12-L23) and unit status | Kill notification, native recap data, and sampled dead/combat/Feign Death flags. | Kill notifications, sampled status changes and the validated lethal recap entry. Earlier hostile-player entries from the same recap are sampled only when their readable timestamps fall inside the matched battle. Prior rows use their native timestamps and recap indices. |

#### Automatic capture and retention

The collector guards values in two stages. `Debug.lua` checks
`issecretvalue` first and separately checks `canaccesstable` for returned
tables. An accessible result still goes through per-field checks. This
keeps false flags distinct from omitted or secret flags. The report and
combat-diagnostics tests model secret values separately from a restricted
table whose indexing raises an error. That catches incorrect access order.
These mocks exercise rejection and redaction. They do not grant access to
the underlying combat data. [Collector](../NamesInRed/Debug.lua) ·
[Combat diagnostics tests](../tests/combat-diagnostics.lua) ·
[Report tests](../tests/issue-report.lua)

- Collection runs during normal play. A provisional local combat window keeps
  bounded streams before the card is confirmed. Only a confirmed card keeps
  its matched window. A separate pre-combat buffer would have no reliable
  window identity for nearby independent fights. Before local combat starts,
  the existing confirmed aura path already retains qualified pair summaries.
- A detailed journal keeps up to four windows and eight recap rows. Each
  window retains the newest 16 unit feedback, cast and aura samples, 12
  states and eight kill notifications. Per-second limits bound work in
  bursts. At most eight aura additions are inspected per notification.
  Cast and aura IDs deduplicate known repeat deliveries in memory. Direct
  feedback has no event ID and identical hits can be genuine.
- Each accepted meter read retains up to 32 spell details (six per category).
  Up to eight follow-up reads record the comparable meter status, receipt
  offset, readable corpse or spirit state and a representative linked pair
  change. A readable pair increase is a difference between aggregate totals.
  Sample rows do not give individual damage or healing timestamps. The
  existing session, context and area gates qualify these reads. The journal
  makes no additional meter requests. Source registration, missing and
  secret field statuses, and observed Feign Death availability are retained
  when known.
- At most 24 fights per character retain detailed samples. Each is limited
  to a conservative 64 KiB estimate for the serialized Lua journal. Whole
  old windows are dropped first when a journal reaches that limit. The
  per-character detail budget is therefore at most 1.5 MiB by this estimate,
  plus bounded active observations and a small fixed-size compact context
  per older card. Older cards retain the latest window's representative
  roster samples, selected meter categories, last eligible follow-up,
  one recap and the existing timeline, roster and reward data. Reopening
  or reloading retains this context and labels it `retention: compact`.
  Pruning scans saved cards at load and logout. A bounded queue handles
  new detailed journals during play.
- Measurements use actual captured Lua tables from the deterministic
  regression fixtures and a Lua table serialization model with the
  SavedVariables layout. A mixed fight was 8,127 bytes, a dense fight
  47,237 bytes and its compact form 3,685 bytes. The 24 newer dense
  journals occupied 1,118,784 serialized bytes. The 26 additional
  stress cards used about 1,656 KiB of retained Lua heap in Lua 5.1.
  That test took about 0.17 seconds locally, including capture,
  export and reload. The figures exclude the existing general debug
  buffer and game UI and do not measure client frame time.

#### Permanent battle history

Age, count and byte limits apply to optional diagnostics only. The recent
cross-rival view draws up to 100 records and each rival's history queries
all their recorded encounters. The permanent record owns the roster, result,
rewards and timeline.

The accepted meter read can also save sampled damage, healing and absorb
amounts under the matched combat segment. Both endpoints must belong to the
confirmed roster and have an accepted link. The sample stores the category,
direction, readable spell ID and per-pair amount. It preserves pet attribution
when known. Categories can overlap and sample coverage can be partial.
These amounts have no individual hit timestamps. The saved aggregate does
not depend on retaining the underlying technical read. On load, existing
diagnostic samples can populate this history before compaction when their
local start and meter selection match one saved segment unambiguously.
Previously discarded samples cannot be recovered.

Automated regression covers opening a record from 2020 with 140 encounters
for its rival after diagnostic compaction, diagnostic removal and reload.
The original outcome, roster, location, timeline, rewards and linked amounts
are still available. The general event-buffer clear is exercised separately.

`ClearDiagnostics` replaces the rolling rows and invalidates pending recap
and meter state. `ResetData` is the separate confirmed character reset
that also clears the ledger. A callback armed for old rows must fail its
identity or generation check after reset or replacement. Test a queued
read followed by clear and a fresh fight, and verify the fresh fight
still records. Reload and diagnostic compaction also preserve already
linked history when the raw report attachment disappears.
[Reset path](../NamesInRed/Core.lua) · [Debug reset tests](../tests/debug.lua) ·
[History retention tests](../tests/combat-diagnostics.lua)

#### Public JSONL and optional SavedVariables

The JSONL schema remains version 1. `primaryEvidence` contains
`evidence: observation`, `meterSampleBatch`, `meterSpellSample` and
`meterFollowup` contain `evidence: aggregate`, and `resolution`,
`event`, `action` and `meterLink` are labeled `evidence: derived`.
`combatAggregate` exports the permanent per-segment amounts with
`evidence: aggregate` and the report's player aliases.
Honor and HK rows are credited totals. They do not supply an individual
damage, healing or kill event. Direct timestamps may be local window
offsets or native recap times. An aggregate read offset timestamps
receipt of the snapshot.

The sampler uses a matched local window, which can include PvE or
neighboring activity. Public sample rows require at least one roster
identity and omit rows with a resolved player outside that roster.
Rows with one known endpoint carry `participant-only` attribution.
They can describe damage received or a cast observed without linking it
to a particular opponent. The coverage rows count omitted observations.
A record created before capture remains `not-recorded`. The summary and
each optional detail part stay within 24 KiB. When the summary omits
sample rows, **Next part** exposes separately fenced JSONL parts with the
same aliases and record ID. Runtime drops, compaction and export truncation
are distinct fields.

For optional additional detail, attach the existing `NamesInRed.lua`
containing `NamesInRedDB` and `NamesInRedDebugDB`. A typical Windows
installation keeps it under
`_forever_\WTF\Account\<account>\<realm>\<character>\SavedVariables\NamesInRed.lua`.
The file can be attached as is and can contain names and GUIDs. GitHub
attachments are public on a public issue. The addon's window uses the
existing report frame and native input templates. Its localized footer
and pagination controls still need a smoke test in the Forever client.

#### Gnomeregan report replay on current main

The two anonymized JSONL reports from `1.1.0-preview.10` and the earlier
SavedVariables agree with the current evaluator.

| Record | Replayed result | Evidence and limitation |
| --- | --- | --- |
| `world:4`, 20:08 MSK | Unknown, `site-anchor-missing` | The second enemy's nameplate-removal contact at +28.043 s says dead, with no Feign Death value in the linked historical observation. A contact snapshot alone does not establish a durable confirmed death. Both allied terminal samples have readable positions and both allies are alive and out of combat. Without a combat anchor those observations do not qualify as holding the site. The existing site-free group elimination path can award Victory when both enemy deaths are corroborated and terminal survivors remain together. The current roster snapshot path already captures a matched corpse observation with a readable non-feign flag as an observed death without a killer. The historical second death is not reconstructed here. |
| `world:7`, 20:11 MSK | Unknown, `area-changed` / `no-terminal-samples` | The local character died at +6.262 s. An enemy harmful aura was observed at +13.524 s and the ally died at +17.528 s. The comparable meter read advanced at +18.651 s while the local player was a ghost. Observation therefore continued after death and spirit release. The read offset does not establish the exact time of a hit, a final elimination, or whether either ally returned before the end. The area change interrupted coverage without terminal samples. Defeat is plausible and remains unconfirmed. |

### Character POV PR A

**Lifecycle and scope.** A confirmed skirmish stores participation independently
of client combat segments. It is active during linked activity, awaits
continuation after local combat ends or the local character dies, and finalizes
at a bounded quiet deadline or explicit boundary. A genuine linked return
after revival returns it to active; a revival alone changes life state.
Open-world zone names and UI map IDs still locate the original card. The
recorder and current meter/contact scope use world versus battleground, a
readable battleground map when present, match events and actual world loading.
A proven independent PvP window or a later window with a linked hostile NPC
aura can close participation in the old fight. The NPC path needs a five-second
gap between combat windows or at least 55 readable world yards of separation,
then the existing 2.5-second grace for evidence of mixed combat. An NPC aura
inside an already confirmed PvP window leaves that encounter intact.

**Intervals and rationale.** The baseline used 2.5 seconds for late contacts
and kills, five seconds for a fresh continuity bridge, 0.75/2.75 seconds for
terminal samples, 12 seconds for recent visible life/pressure signals, and
0.5 seconds to settle kill/corpse observations. PR A keeps those purposes
separate. The continuation deadline is 12 seconds from the local exit or a
new witnessed linked action, starting at the death if combat remains open.
The old 12-second life horizon is long enough to admit the recorded +13.524
second Gnomeregan allied action after the local +6.262 second death. It also
allows at least one pair of the existing short reads and a final pair around
+10/+12 seconds if visibility continues. Missing late reads preserve a supported
early ending. Later real activity or contradictory life/combat evidence can
invalidate it. The five-second limit corroborates linkage between a new
segment and a witnessed intervening exchange (or a readable opponent still in
combat at the prior live exit). A solo stealth replay rejoins within the
bridge with that observation. A replay with the same GUID and an idle foe,
or with a gap past five seconds, starts a separate fight even while the
previous one is awaiting continuation. The 12-second window still allows
the corpse or spirit to observe allies.
A scoped meter can corroborate participants or enrich its owning window.
Receipt of a meter delta or delayed recap does not extend the deadline.
A separately observed pursuit can hold the original quiet callback while
one successor window awaits qualification. See the [control-gap replay](#control-gap-replay-world2324).
A deadline is private session time; only server times and offsets from the
saved skirmish persist. Logout/loading finalizes with available observations,
and reload closes any saved unfinished state if normal cleanup was missed.
These intervals are engineering choices verified with mocked events, pending
play tuning on Forever.

**Projection and evidence.** PR A introduced `personalOutcome` version 1 to record lifecycle,
the final result and reason, observation boundary, coverage, distinct
friendly/enemy casualties and latest verified life. `observation.participation`
holds the durable state and terminal observations underneath that projection.
A compatible pair of terminal reads can establish disengagement without
coordinates. Known unresolved hostile activity or a still-fighting opponent
lost from view can leave the ending unobserved. Decisive elimination requires
latest confirmed opposing deaths and a corroborated surviving side, or
corroboration of mutual elimination. This takes priority over terminal personal
death without a reliable ending, then over the casualty balance for an
observed non-elimination ending. Repeating a corpse or a kill signal within
one life counts only once. A verified return to life opens a new life episode.
A distinct validated server death recap can also distinguish separate local
lives. PR A linked a corpse without a finisher through a recent timed opposing
action on the same victim. PR B extends this through the shared confirmation
rules below. Each live action-pair row keeps its
existing `first`, `last` and `count` plus distinct
`intermediateOffsets` when available. All offsets are relative to the
segment, and represent witnessed action observations. The life timeline
lets replay match those times to a given life, including the earlier of
two deaths in one segment. Old rows offer only their witnessed endpoints.
Untimed Damage Meter aggregates supply no missing action times. A valid
terminal read reconciles an identified non-local participant's confirmed
death or return to life immediately, including the first read of a sample
pair. A readable dead state with Feign Death explicitly false creates a
durable death with an unknown finisher when no separate notification arrives.
Repeated reads confirm the same death, and a return to life makes a later
death distinct. A corpse contributes a PvP casualty only with evidence from
that life. The scheduled-sample replay covers a linked death with one casualty
and Victory, a second death after a sampled revival, Feign Death, an unlinked
NPC death and a preexisting bystander corpse. Live capture and replay share the
0.5-second guard for an apparent return immediately after `PARTY_KILL` without
a corroborating corpse. Missing fields, reused tokens and invalidated windows
do not supply a revival. Two readable, identity-checked dead observations of
a known non-Hunter separated by at least 0.5 seconds can corroborate a corpse
when Feign Death is unavailable. A single weak read cannot establish a death.
Raw history, legacy results, rewards, manual entries and user-facing
projections retain their existing contracts.

**Anonymized replay results.** Only repository fixtures and documented retained
observations were available for this PR. No original private SavedVariables
were replayed and no fresh live-client check was performed.

| Encounter | Personal projection | Evidence retained |
| --- | --- | --- |
| Gnomeregan `world:4` | Victory by casualty balance, 0:1 | Two stable allied terminal reads and the confirmed teammate kill establish the personal result without a site anchor. The single Paladin corpse snapshot has no second confirmation. Legacy stays Unknown / site-anchor-missing. |
| Gnomeregan `world:7` | Defeat by terminal personal death | The later allied death and hostile aura remain. The original meter delta is untimed and the area cutoff has no terminal pair. The second enemy corpse is still a raw fact in the fixture, with no retained timed attack on that victim. Legacy stays Unknown. |
| Gnomeregan `world:12` | Defeat, one confirmed local casualty | The validated lethal hostile player recap remains sufficient in the mixed PvE/PvP death. Legacy stays Defeat, and readable level recovery is tested separately. |
| Gnomeregan `world:14` | Defeat by terminal personal death | One verified local death, no supported return or terminal pair. Legacy stays Unknown. |
| Duskwood | Unknown, two confirmed enemy casualties | The 2 × 3 roster and five honor survive. The remaining foe was last seen alive in combat, with no readable end or safe third death. The supported favorable disengagement is covered separately. |

**Remaining client limits.** Readable GUID, death, combat, harmful aura and
corpse observations can be unavailable in PvP or while ghosted. Overlapping
untimed meter totals, an off-target kill delivered with no identity or safe
window, and a PvE episode that cannot be separated within one native window
remain ambiguous. A disappearance or unavailable flag cannot establish a
death. Later unobserved allied activity cannot decide a prior result and a
battleground scoreboard cannot decide a local fight. The existing replay also
cannot recover Gnomeregan's missing 20:21 card or assign the 14 historical
unlinked honor. Verify ordinary border pursuit, a real ghost-run return, and
true loading/respawn boundaries in Forever before activation/release. The
native UI and rival scoring changes are documented under PR C.

### Character POV PR B

**Projection and durable inputs.** `EvaluateRivalContributions` shares PR A's
death episode reconstruction. It returns one versioned row per rival,
direction and confirmed death, with the death's timeline index and a proof
that points to a kill, witnessed action, native recap hit or meter segment.
A support proof also points to the supported participant and their opposing
action. `Ledger.RivalContributionScore` sums these credits on demand.
Saved raw events, side outcomes, killing blows, honor and HK remain separate.
The derivation uses neither the skirmish verdict nor its roster as a substitute
for participation.

Both projections use the same confirmed PvP death episodes. An attributed
opposing kill, explicit PvP confirmation or eligible hostile evidence linked
to a durable corpse can confirm an episode. The directed meter path shares
the same unique-window and single-life checks with rival attribution. The
personal outcome counts one casualty even if an allied action earns the
local player no credit, or several opponents earn one credit each for a
single local death. An aggregate alone supplies no death, and a verified
NPC death, ambiguous window or multi-life aggregate supplies no confirmation.
For local deaths, a validated lethal recap remains necessary when the
finisher is unknown. `personalOutcome` version 2 recomputes the cached
projection from retained facts on reload. Original battle and reward data
retain their existing format.

The existing meter read now keeps full accepted directional pair/category
links from the connected component in `segment.contributionLinks`. The
permanent entry needs the pair, category, qualification and known pet
endpoint. Existing sampled amounts remain in `combatAggregates`. This avoids
losing the only readable heal when the technical sample hits its six-row
category limit. Duration-mismatch corroboration remains roster evidence and
does not authorize credit. When a historical segment lacks these links, a
positive saved aggregate can qualify with a matching accepted read summary
and a usable relative segment interval. Old records with only group scores,
untimed loose links or missing scope remain without a new credit.

**Life and time boundaries.** An attributed kill is positive proof. A timed
harmful effect must involve the victim in the applicable life within the
existing 12-second horizon. Compare segment-relative observations on the
skirmish clock. Older whole-second segment starts carry one second of
uncertainty. A selected meter window must contain the death within its local
segment or match a finish within the existing 2.5-second grace. A known life
transition across that window makes the untimed pair unsafe to assign.
Direct damage or hostile control requires the actual directed pair. For
healing, absorbs and defensive dispels, the recipient also needs its own
independent hostile link to the victim and only one observed opposing
counterpart in that window. The support must come from the matched segment
ending at most 2.5 seconds after the death. Earlier or later disconnected
windows, multiple possible opponents, and multi-life segments leave the
untimed support unassigned. Single-life window attribution still cannot order
individual heals and hits inside the native aggregate.

**Native death recaps.** The existing readable hostile-player lethal recap
can attach positive earlier damage rows to its own death event. Store the
latest recognized hit time per attacker in native server seconds. Exclude
hits before the skirmish, after the fatal hit, more than 12 seconds earlier,
or in or before the previous life boundary's server second. This keeps
a later recap from assigning prior-life damage and counts each attacker once.
When the lethal GUID is unavailable but the lethal row confirms a hostile
player, an already linked battle can store a PvP death without an actor.
The bounded retry can refine damage evidence or assign a readable finisher
to that same episode. It matches the native timestamp in the bound record
and preserves the original timeline position. The native timestamp watermark
advances for a confirmed unnamed death, so stale recaps cannot replace it.
Two distinct validated timestamps remain two episodes even if no revival
notification was retained. An NPC finisher or unreadable hostile/type flags
do not establish that fallback. Older diagnostics only contribute when a
recap row matches a unique saved lethal event by native timestamp and target
before diagnostic compaction.

**Forever limits and verification.** Controlled pet sources already resolve
through a verified owner in the meter, or the matching local pet token for a
witnessed aura. An aura applied to the pet does not stand in for an action on
its owner. The recorder preserves that distinction for new timed rows. Old
incoming aura rows without target provenance, restricted endpoints,
unidentified pet sources, cast-only observations and generic buffs do not
supply positive attribution. Meter categories can be unreadable, unnamed or
behind a stale selector. A curse, interrupt or dispel needs a readable
recipient in the existing aura or meter path. The native report does not give
a reliable structured sequence for generic beneficial buffs or positive
untimed actions in multiple lives. No extra collector, polling or native
meter setting is required.

Lua tests cover ally finishing blows, healer-only and shield-only support,
friendly and hostile dispels/interrupts, pet identity, three verified
attackers in one local death, both directions for one rival and repeat
deaths. Runtime replays cover the full meter scanner past the diagnostic
cap, restricted recipients, meter-linked corpse reconciliation after reload,
and distinct native lethal recaps with hidden or newly readable finishers.
Existing Duskwood, Gnomeregan and battleground fixtures still exercise the
legacy and personal outcome paths. Verification used Forever-shaped mocks
and the retained public API evidence above. Runtime event delivery on a fresh
Forever client remains unverified for PR B.

### Character POV PR C

**Journal and compatibility.** The full card binds `Ledger.JournalOutcome`.
PR A's active and awaiting states both produce In progress. Finalized
Victory, Defeat, Draw and exceptional Unknown have distinct display states.
A compact card reads the matching rival's wins and losses. Repeated credit
uses a count and simultaneous directions use the shared inline counter art.
A linked rival without credit stays visible. Historical side results remain
labelled on cards and in profile/hover context. A timestamped old directional
row can supply one direct credit when its rival resolves to a player ID.
Manual entries, undated directional rows and group verdicts supply no new
participation evidence. Existing manual labels, raw timeline, direct totals
and reward fields remain available. The profile keeps HK and honor separate.
The nameplate shows a labelled historical fallback when the rival lacks a
verified score; the unit tooltip shows separate manual/legacy totals and
literal finishing blows.

**Index and invalidation.** The ledger lazily builds one in-memory projection
per loaded database. Warm nameplate and tooltip queries look up the rival's
totals without replaying the timeline. Save subtracts the previous numeric
snapshot for that battle ID and applies its new projection even if the
recorder edited the original table in place. Late meter/recap updates reach
that same write path. Battle deletion subtracts the snapshot. Rival deletion
removes the roster link and refreshes each affected projection while keeping
the shared battle and timeline. Reset clears the maps. Reload invalidates
them after the existing additive restore. The older flat list has a per-rival
summary invalidated by its encounter writer. The recent-view cap is 100;
a rival's permanent history and its index have no count or age cap. Tests
exercise a cold build of 1,050 battles, 300 iterations of warm queries,
one-battle recomputation after late evidence, deletion, reset and two reloads.

**Native references.** [Forever 1.60.1 build 71037](https://github.com/Gethe/wow-ui-source/tree/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns)
was inspected for this integration. The profile uses the existing
`ProfessionsReagentSlotBaseTemplate` with the 50-pixel slot, 39-pixel button
and authored name inset from `Blizzard_ProfessionsTemplates/Blizzard_ProfessionsRecipeReagentSlotBase.xml`.
The journal retains the profession open/close sounds from
`Blizzard_Professions/Blizzard_ProfessionsFrame.lua`. `EncounterCards.lua`
shares the existing framed result component on full and compact cards
with the same circle atlas, portraits and action buttons. Blizzard has no
result widget for a personal contribution tally, so both directions use
the same inline icon format as the profile's hover and nameplate displays.
`Blizzard_NamePlates/Blizzard_NamePlateUnitFrame.lua` provides the name and
health-bar anchors. The tooltip post-call uses the existing
`GameTooltipDataMixin:RefreshDataNextUpdate` path in
`Blizzard_GameTooltip/Mainline/GameTooltip.lua` after writes and deletion.
Mocked layout, options and locale checks verify the wiring. In-client
legibility, spacing across locales, audio, restrictions and event delivery
remain to be checked.

**Issue reports and replay.** The bounded JSONL adds personal lifecycle,
coverage, reason, confirmed casualty counts and rival credit proof.
The proof identifies the aliases for rival, actor, victim and any supported
teammate, the death-event index and evidence type/category. Meter links carry
their segment index and have no invented action time. Historical side
resolution has its own scope. The existing alias rules, byte limits, paging
and optional SavedVariables path still apply. Anonymous Duskwood, Gnomeregan
and battleground replays remain green. Gnomeregan `world:4` displays Victory
from the supported personal projection; `world:7`, `world:12` and
`world:14` display Defeat. Duskwood remains Unknown with two confirmed
enemy casualties and five honor. The replays and synthetic older archive
exercise migration. An original private SavedVariables file and a fresh
Forever client were unavailable for this PR.

**Preview.** PR checks test the GitHub integration commit. The installable
`NamesInRed/` artifact is staged from the exact feature head, stamped with
`X-Preview-Revision` in the packaged TOC, and validated against its manifest.
The public TOC version stays unchanged. The Actions summary identifies the
source commit.
In Forever, use a copy of an older save for compatibility checks and inspect
full/compact cards and the profile, tooltip and nameplate before and after
a qualifying repeat death. The PR B API restrictions above apply unchanged.

#### Live preview follow-up: world:16

The owner tested the first PR #45 preview on Forever 1.60.1 build 71037.
A solo fight ended with the character's death. The warlock died later
outside the character's observed fight. The saved report showed Unknown
and no rival credit. It retained a local death at +25.002 s, positive
`DamageTaken` rows directed from the warlock to the character, and a
terminal read at +26.274 s showing the local corpse and the living
warlock in combat. The next read had lost the warlock. Two `UNIT_COMBAT`
wounds exposed the recipient alone. The recap could establish no lethal
attacker. These are facts from the sanitized report, whose TOC version
alone could not identify the running preview.
[Review and retained evidence](https://github.com/nick-sidorin/names-in-red/pull/45#pullrequestreview-6045725460)

The local `PLAYER_DEAD` signal now writes a durable corpse without a
finisher, including when the meter qualifies the window after death.
The shared episode analysis accepts a local death from the combination
of that signal, a positive directed damage link in the matched single-life
combat window and a terminal read of the same corpse with a linked
opponent still alive and fighting. Both the signal and the read must be
within the existing 2.5-second tolerances, measured from combat end and
the death respectively. A prior aggregate, a pet recipient, control alone,
an ineligible or ambiguous meter read, and multiple lives in a window
cannot establish the fallback. A verified pet source can qualify through
its previously verified player owner. The segment retains the earliest
joint read per witnessed opponent so a linked return and new samples do
not erase evidence for the prior life. The aggregate retains its segment
scope. The result preserves the distinction between one PvP casualty,
one opponent loss and zero attributed finishing blows in this fixture.

A fresh lethal NPC/environment recap vetoes the fallback, even if it
arrives on a bounded retry after the meter read. The recorder binds this
status to the original local death. Stale and duplicate native times carry
no veto into another death. Readable incoming NPC damage or hostile NPC
aura pressure in the same window blocks aggregate-only confirmation.
A legacy incoming category containing unresolved non-player targets also
leaves the fallback ambiguous. A missing or restricted recap alone has
no veto. When the client conceals all evidence of unrelated PvE, even a
scoped aggregate cannot identify the lethal hit.

The first preview could produce `finalizedBy=historical` when the saved
record had no participation object, or when a finalized object had no
boundary and the Lua fallback selected `historical`. The fresh capture
replay creates participation on first confirmation and finalizes it with
`area-changed`. The retained fixture without participation still reports
`historical`. A finalized object without a boundary now reports
`boundary-unavailable`. The report alone cannot distinguish which branch
produced the owner's old result. The new JSONL includes the running preview
revision, a capture revision on newly created skirmishes, participation
state and sampled boundaries, scoped contribution links, and per-death
qualification and recap status. All IDs use existing aliases and the
existing report limits apply.

Version 3 recomputes the personal outcome on load from retained evidence.
The shared rival index invalidates on load and rebuilds from the same
episodes. The anonymous live-shaped and retained fixtures produce Defeat
and one loss for the warlock, including a repeat reload and checks through
the full card, profile, compact card, tooltip and nameplate. They retain
the raw events and separately recorded rewards. Negative cases cover an
NPC or environmental finisher, positive mixed PvE evidence, stale recap,
out-of-scope and multi-life aggregates, missing terminal corroboration,
and a pet without a verified owner. A linked return preserves the prior
credit while the later ending can change the personal result. The fix
has been replayed with client-shaped mocks. Retesting in Forever remains
necessary for the new preview.

#### Original world:16 findings and second follow-up

The owner's investigation of the original SavedVariables identified two
failures in preview `d6f7bcc`. The saved segment has no `offset`. Its
`startedAt` matches the battle's start, `duration` is 25.00200000000041,
and the six directed incoming Damage Meter aggregates were eligible.
The evaluator found a segment start of zero, then gated the finish
calculation on the absent raw offset. The previous test fixture explicitly
supplied an offset. Outcome v4 uses the resolved start for both bounds and
shares that resolver with timed hostility. A missing server anchor,
unbounded timing or overlapping unbound windows still prevent a match.
[Review of the original SavedVariables](https://github.com/nick-sidorin/names-in-red/pull/45#pullrequestreview-6046251024)

The original debug store contains seven reads of the same pet lethal
across two `PLAYER_DEAD` notifications. Three of those reads are retained
in the anonymized fixture.
The reviewed values are a `Pet-` GUID, flags `0x1148`, `SWING_DAMAGE`,
56 damage, 12 HP and 44 overkill. A readable hostile player dealt periodic
damage immediately beforehand. The player-only recap reader discarded
both. The recorder now checks the hostile reaction, player control and
pet type flags, and preserves the lethal pet GUID, native timestamp and hit
fields alongside the earlier player damage. The owner's GUID is a separate
optional field and requires a verified ownership mapping for that window.
A verified hostile pet death can settle a personal Defeat without a known
owner. The full timeline shows the verified owner or an unknown player.
The literal source remains available as technical evidence, and direct
player finishing-blow counters remain independent.

Load-time recovery can attach retained pet-recapping evidence beside an
original local death. It requires the segment's diagnostic session and
combat sequence, an unambiguous local `PLAYER_DEAD` with the same victim,
scope, server second and compatible uptime, and readable recap rows with
the same death sequence. The exact saved event uses the legacy uppercase
`PLAYER_DEAD` source. The first diagnostic notification matches its server
second and combat uptime. The next notification has a later clock and
recaps with the same native lethal timestamp. Exact repeated reads of the
pet and native stamp combine for the matched death. Conflicting verified lethals, multiple candidate windows or
competing claims on the same native stamp are rejected. A historical owner
can be recovered only from the uniquely matched combat-end row's verified
ownership and hostile-player contact. The original event is unchanged.
Once attached, the proof survives diagnostic eviction. Outcome v4 and the
rival index re-evaluate from the resulting evidence on load.

A local Lua replay used the privately supplied original SavedVariables
with the full journal and all retained debug rows. Preview `d6f7bcc`
produced Unknown, 0:0 against the warlock and no finisher. The revised
code produced Defeat, 0:1 and one literal pet finisher without an owner.
It recovered the `SWING_DAMAGE` row and the independent prior hostile
periodic-damage timestamp `1795547079.056`. Direct player kills and deaths
stayed 0:0, and the original event table and rewards were preserved.
Repeated loads produced the same score and proof.

`tests/fixtures/world16-anonymized.lua` contains the original battle,
rival and relevant diagnostic rows with anonymized identities. It omits
unrelated diagnostic probes and preserves the absent offset and rewards.
The exact fixture exercises stale v3 migration, a warm index before recap
recovery, and the full card, compact card, profile, tooltip and nameplate.
Separate controlled tests exercise contradictory rows, owner ambiguity,
NPC and environmental deaths, resurrection and diagnostic eviction.
For the new preview, live Forever verification remains pending.

#### Pet ownership in Forever 71037

The generated unit API at the exact Forever 1.60.1 build declares
`UnitTokenFromGUID(guid)` with a possibly absent token, `UnitOwnerGUID(unit)`
with an owner GUID, and `UnitIsOwnerOrControllerOfUnit(owner, controlled)`
with a Boolean verdict. All three and `UnitGUID` are marked
`SecretWhenUnitIdentityRestricted`. `UnitGUID` and `UnitOwnerGUID` take
`UnitTokenPvPRestrictedForAddOns`. The token lookup has
`SecretArguments = AllowedWhenTainted`; the other three declare
`AllowedWhenUntainted`. These are API capabilities and restrictions
from generated source. They do not establish which hostile tokens an
addon can read in a live world fight or after death.
[Forever UnitDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)

The existing recorder checks the local `pet`, `partypetN` and `raidpetN`
tokens and compares simultaneous readable player/pet tokens. Visible
nameplates and current target or mouseover can provide other tokens
while their GUIDs remain readable. The aura handler can inspect
`addedAuras[].sourceUnit` only when its table and field are readable.
A source token points to the caster, with ownership established separately.
`UNIT_AURA` is marked `SecretWhenAurasRestricted`. The existing bounded
world-aura sample now observes a source only when its readable GUID is
a pet. The sample may omit later or restricted transitions. Identity
absence may also reflect an unseen unit or a recycled token.
[Forever UnitAuraDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua)
· [Forever NamePlateDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/NamePlateDocumentation.lua)

The original `world:16` combat-end row recorded zero paired owner
checks and just the local pet mapping. The lethal hostile pet GUID
appears only in raw recap sources. This is an observation gap.
`UnitTokenFromGUID` and `UnitOwnerGUID` were uncollected in that preview,
so the old record cannot tell whether either would have returned
a readable value. No ownership for this pet was recovered on reload.

The private save shows native owner aggregation for the player's own
pet. The local player's DamageDone entry contains pet-labelled
`creatureName` rows for spells 6603 and 17256, with totals 1,374 and
151. The incoming meter links 324 damage for spell 1293697 to the
warlock. The same hostile pet that later landed the lethal swing dealt
54 and 52 with spell 1293697 in the native recap. This corroborates
involvement, but the spell aggregate has neither the physical pet GUID
nor the timestamp of an individual hit. Amounts, spell IDs, names, class
and the number of observed enemies cannot establish ownership.
`DamageMeterCombatSource` carries a conditionally secret source GUID.
The per-spell aggregate exposes `creatureName`, while the second-unit
details expose name, class, type flags and amount. Technical diagnostic
samples can omit rows, and the permanent aggregate intentionally keeps
only qualified linked evidence. The Deaths row identified the local
victim and native `deathRecapID=56`. Blizzard passes that ID to
`OpenDeathRecapUI`, which reads `GetRecapEvents(recapID)`. It identifies
the death selected in the meter. Neither that relationship nor the
documented recap API supplies a pet-owner join. The generated
`DeathRecapEventInfo` structure declares no fields; the saved recap
demonstrates readable source and hit fields, with no recorded owner.
[Forever DamageMeter schema](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/DamageMeterDocumentation.lua)
· [Native meter recap action](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_DamageMeter/DamageMeterSessionWindow.lua#L968)
· [Forever DeathRecap schema](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/DeathRecapDocumentation.lua)
· [Native recap reader](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_DeathRecap/Mainline/Blizzard_DeathRecap.lua#L315)

The recorder now looks up the owner directly for an observed pet and
tries the recap GUID-to-token path at the initial read and existing
0.3, 1 and 2 second retries. It verifies the pet token against the
same GUID before and after reading the owner, verifies the owning
opponent from the scoped contact or another identity-checked token,
and rejects conflicting ownership. The lookup obeys the owning active
combat window or its existing 2.5-second post-combat tail, before any
scope change or newer combat. An unavailable API or lost token can
leave the attribution unknown. A prior verified scoped observation
can survive lost visibility. Existing retry and death deduplication
also apply when ownership is first discovered after combat. The
literal name, when readable, stays in private technical evidence.
The displayed actor is the verified player or an unknown player.

Per-death diagnostics retain at most four attempts. They report phase,
delay, token lookup, identity checks, owner result and verification
decision as statuses. They contain no raw token, GUID, name or native
error text. In a future ordinary PvP death involving a hostile pet,
inspect whether the initial combat read or a post-combat retry gets
a stable pet token and confirmed owner. Check an off-nameplate pet
and compare secret, absent and error outcomes. There is no need
to recreate `world:16`. The live API and native rendering still need
verification. Lua tests cover success, delayed readability, aura
observation, absent and secret results, token reuse, native errors,
conflicting owners, non-opponents, and window invalidation. The
original save still replays as Defeat, one warlock loss, and an
unknown player actor with the pet lethal retained privately.

The PR #45 follow-up reproduced a stale rival on `278e9f8`: the first
owner result added the player to the roster, and a conflicting retry
revoked attribution while leaving that roster entry behind. A recap-only
claim now stays provisional until the existing skirmish finalization
boundary. A conflicting retry discards the claim. Independently linked
participation still enters the roster immediately, and earlier rival
history and manual entries remain intact. Older persisted rosters have
no provenance for this admission, so historical entries are preserved.

Duplicate reads of the same native death and pet source append probe
statuses to the saved episode even when the outcome and score stay the
same. Lua replay checks the four-attempt cap, ordinary logout, and
reopening a copy of SavedVariables with the debug log cleared. The issue
report labels the direct-player counter scope and distinguishes a verified
player owner from an unknown player actor on a pet finishing blow. The
literal pet death leaves the direct-player counters unchanged.
[PR #45 review](https://github.com/nick-sidorin/names-in-red/pull/45#pullrequestreview-6047563563)

#### Joined ally combat and late generic activity in world:19–21

Live testing reported no UI errors and confirmed that historical world:16
displayed Defeat. The supplied on-disk world:19–21 rows carry capture revision
`d6f7bcc` and saved outcome version 3. They are evidence of the capture listed
in SavedVariables. Replay against PR head `979fa14` yielded 2×1 Unknown and
0:0 for world:19, and 1×1 Victory with 1:0 for each of world:20 and world:21.
The owner confirmed an ally participated in all three fights and started the
last two. The original file stayed private. The regression extract retains
the original clocks, timeline rows, zero amounts, empty classes and read
statuses for the three fights. [Live review](https://github.com/nick-sidorin/names-in-red/pull/45#pullrequestreview-6058796963)

The Forever Source window creates one display entry for each native
`combatSpells` row. `DamageMeterSpellEntryMixin:Init` reads the named second
unit from `combatSpellDetails` and delegates the bar value to
`DamageMeterEntryMixin:Init`, which uses `source.totalAmount`. The generated
API declares the spell total and detail amount as separate fields. The
three captures show a scoped `EnemyDamageTaken` shape with spell ID 0, a
readable named player, readable false mob and pet flags, an empty detail
class, and zero detail amount despite a positive spell total. The native
Lua does not define the producer's grouping contract for every category.
The addon accepts this particular shape only when a complete source
matrix reconciles to the per-GUID `DamageDone` amounts from the same
selection and refresh overlap. It requires unique full identities and an
independently confirmed enemy death with a local player share in that
segment. Names and amounts establish no hit timestamp or pet ownership.
[Native source provider](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_DamageMeter/DamageMeterSourceWindow.lua#L176) ·
[Native entry](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_DamageMeter/DamageMeterEntry.lua#L481) ·
[Generated schema](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/DamageMeterDocumentation.lua#L215)

In world:20, the native session lasted 11 s and the local window 5.318 s.
Both damage-category signals started at local combat start and their last
updates arrived about 1.085 s after local combat ended, inside the existing
1.5 s read retry. The ally was already in combat at local start and the
confirmed enemy targeted the ally. A readable reciprocal `DamageTaken` row
showed 161 incoming damage for that same pair. With the two qualified
category signals and an isolated selection, this corroborates the join.
The incoming category had no own matching update, so its data supplies
corroboration only. The enemy who was finished received 171 from the local
player and 132 from the ally. The ally's other 171 belonged to a different
enemy. Those 171 reconcile the session's totals, but create no participant,
casualty or credit in this fight. An earlier-window overlap, no prior
Current boundary for this extended path, an incomplete matrix or competing
names leave the join unqualified. The ordinary duration rule is unchanged.

In world:19, the confirmed enemy died at +8.454 s and both allies were
alive and out of combat at +14.108 and +16.093 s. A generic ally combat
flag appeared at +23.347 s and was clear again at +25.353 s. Outcome v5
keeps the independently observed elimination when the opponent has no
evidence of a return and later allied activity has no confirmed link to
the confrontation. A linked action, a qualifying linked increase in that
case, a returned enemy or an active additional opponent can still block
reuse of those older samples.

The exact original replay now yields 2×1 Victory and a personal score of
1:0 in all three fights. World:19 retains the ally's finishing blow, so
the local literal direct-player killing blow count is zero there and one
in each of world:20 and world:21. Recovery requires a unique combination
of combat sequence, debug session, owning segment, local identity,
scope, timestamps and meter selection. It appends durable directed
aggregate proof and uses the existing index on subsequent loads. It
keeps raw life events and rewards intact. With no suitable retained
diagnostic rows, older records can still receive the outcome correction
from their existing terminal samples. They cannot gain an unevidenced
participant. The Lua tests exercise the stored replays, the live capture
callbacks with recorded rows, the journal and per-rival views, and
reload with the log removed. Fresh capture and presentation on the new
preview still need a client check.

### Control-gap replay, world:23–24

The private Forever 1.60.1 build 71091 capture was recorded on preview
`22fada7`. The original SavedVariables replayed on main `805c242` as
world:22 Victory, world:23 Unknown and world:24 Defeat. In the second
encounter, the owner used Freezing Trap, moved away and resumed. The
retained aura payload is secret. The cast and timing alone establish no
target or continuation. [Issue #47](https://github.com/nick-sidorin/names-in-red/issues/47)

| Evidence | First window | Successor window |
| --- | --- | --- |
| Native scope | Debug session 66, sequence 27 | Same session, sequence 28 |
| Local uptime | 7029.684–7038.017 | 7041.196–7052.471 |
| Independently qualified incoming damage | 330 | 1,135 |
| Observed opponent | Alive, in combat and targeting the local player at exit | Same readable GUID, alive and targeting the local player at entry |

The gap was 3.179 s. The first record had only one persisted assessment
sample and no settled ending. Its 12 s quiet callback ran during the
second window, before the native death and kill arrived. The old
`Confirm` exit-contact path applied only to a readable harmful aura.
The meter-created predecessor also missed the close-contact capture
when its record was created after the combat-end event.

The recorder now keeps the qualified predecessor's captured exit and
checks the same living opponent targeting the local character at the
start of the next local window, within the existing 5 s bridge. A pending
record with that evidence can wait at its original quiet deadline for
one successor to qualify. The successor needs a scoped directed damage
pair or another verified local hostile action, such as the native lethal
recap. The action must belong to the first 12 s of that successor. Existing
late reads get no more than 2.5 s of grace, measured from the earlier of
its close or that cap. An unrelated or superseding window and explicit
scope changes drop the hold. The predecessor's terminal samples cannot
be supplemented from a different window. Genuine paired disengagement
or a prior unresolved death of either endpoint prevents an exit-contact merge.

Historical reconciliation is narrower. It looks for adjacent, uniquely
owned native windows in the same session with exact timestamps, matching
solo sides and scope, direct links in both windows, readable exit and
entry contacts, a quiet-timeout inside the successor and a later verified
native lethal recap. It keeps the earlier journal ID and preserves its
ending samples as recovery evidence. Battle-relative times use the native
start-to-start difference of 11.512 s. Segment-relative aggregates and
combat diagnostics, original death timestamps and awards remain intact.
The original replay now has world:22 Victory and world:23 Defeat with
both segments. The rival ledger records 1:1, one direct kill and one direct
death, one HK and six honor. A missing, conflicting or ambiguous witness
leaves the stored records separate. The exact anonymized fixture covers
reopening without the debug log, view and index consistency, and the
live recorder tests exercise the captured intervals and native recap.
Fresh in-client capture on the fix preview remains to be checked.

### Preview and release provenance

The original #29 preview included the new combat diagnostics with the old
report layout. Its branch started from a main that had not received the
link-first dialog from #27. Bringing over that UI commit alone reconciled
the two previews without moving the rest of the release branch. Check
the artifact's exact head and relevant runtime files before diagnosing a
visible rollback as a load-time problem.
[Layout port](https://github.com/nick-sidorin/names-in-red/commit/4ea246e2b4e4a8bf03d67d473ba0ae3964fe708e)

In the one-time 1.1.0 publisher, the missing-tag lookup could leave an
API error response where the script expected an empty SHA. PR #33 used
`git ls-remote --tags origin "refs/tags/$tag"` on the exact ref and verified
the remote again after creation. A successful lookup with no matching ref
means absent. An unsuccessful lookup is an error. Check the commit
resolution when annotated tags are involved. The temporary workflow was
removed after publication, so inspect current automation before using
this as a procedure for a future release.
[Tag check fix](https://github.com/nick-sidorin/names-in-red/pull/33) ·
[Workflow cleanup](https://github.com/nick-sidorin/names-in-red/pull/34)

For 1.1.0 the tag resolves to
`e8bcee6a98c5fb95ebb5d62d4a6c1a82039fa588`. The GitHub release ZIP and
CurseForge file `9782367` have different archive bytes. Their 29 runtime
members each match the tagged paths and bytes, including TOC version
1.1.0 and interface 16001. The public CurseForge entry is **Release** for
**Forever 1.60.1** with one matching file ID. Check file type and game
version on the published file, independently of the GitHub release and
project listing copy. [GitHub publisher run](https://github.com/nick-sidorin/names-in-red/actions/runs/45284416748) ·
[GitHub release](https://github.com/nick-sidorin/names-in-red/releases/tag/v1.1.0) ·
[CurseForge file](https://www.curseforge.com/wow/addons/names-in-red/files/9782367)
