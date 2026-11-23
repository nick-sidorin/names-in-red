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
  conflicting claim invalidates attribution. Pet evidence adds a
  participant rather than a killing blow.
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
  recently confirmed dead, visibly dead in both samples, or demonstrably
  withdrawing under pressure. A stronger later observation of life
  supersedes an old kill. Known active combat blocks the decision.
- For a living departure, the participant must start near the site in an
  observed hostile action and then be visibly outside it in both terminal
  samples. The latest witnessed action against that participant must come
  from a member of the side still holding the site, with no later known
  attack by the withdrawing player. The 30/55 yard radii and 12-second
  evidence freshness limit are conservative guards for this preview.
  They do not assign a winner on their own. There is no weighted kill score.
- Where coordinates are unavailable in an observed 1 × 1, a recent
  confirmed death plus two direct observations of the surviving opponent
  alive and out of combat can resolve it. A personal death during a group
  fight is only one event in that fight.
- Both sides seen leaving can yield an observed ending with Unknown
  winner. Missing positions or players, conflicting signals, stealth,
  intervening contest and unresolved pauses remain Unknown. A later
  verified continuation can replace an earlier provisional assessment.
  Legacy cards without the new assessment keep the original interpretation.
  Manual outcomes and personal rewards are independent of the resolver.

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
3. Run a retreat under pressure and a no-kill disengagement. Add a brief
   stealth and re-entry as a negative control. Compare the saved snapshots
   and `resolution` reasons, then repeat Duskwood or its equivalent.
   Verify after a normal logout or `/reload`; share SavedVariables privately.

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
Observations are bounded to 32 readable contacts and eight previous states per
contact. Repeated flags are throttled. The first eight fully obscured kill
events in a combat are stored individually, with the total retained at combat
end. Protected fields remain unavailable. The collector is local and the
additional event coverage needs a check in the Forever client.

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
