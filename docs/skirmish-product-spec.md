# Names in Red — PvP Skirmishes: Product Specification

**Status:** Owner-approved Character POV milestone contract, 24 November 2026. The owner approved moving to implementation after discussion of the hybrid observed-resolution/casualty model. Refine genuinely new edge cases during development; do not reopen settled rules merely to delay implementation. This is the target behavior for development after 1.1.0, not a description of its shipped behavior. It supersedes the previous side-outcome and rival-score semantics. The evidence and implementation details belong in [Forever validation](forever-validation.md).

## 1. Product goal: Character POV

Names in Red is a **personal combat journal of an individual character**, for connected PvP skirmishes in the open world and on enabled battlegrounds. It is not a neutral referee, a global combat log, a scoreboard for all participants, or a reconstruction of the whole battlefield. It should feel like the character's own recollection of adventures in Azeroth.

A solo player must find the journal useful without any other player installing the addon. A character may enter an ongoing battle, die, be revived, leave, or lose observation. The record includes the locally available evidence, including reliable information about others from the client's APIs. It does not assume knowledge of off-screen events before arrival or after observation is lost. Voice chat and a friend's account of later events are not automatically known to the character's addon.

The journal answers three independent questions:

1. **How did my character fare?** The primary skirmish result is Victory, Defeat or Draw from the character's observed encounter, with an exceptional Unknown only when the ending cannot be established. In progress is a lifecycle state, not a result.
2. **What happened between me and this rival?** A separate personal score credits meaningful participation in defeating that opponent and records relevant losses to them, not simply who dealt the finishing blow.
3. **What happened around me?** Preserve the observed sides, participants, timeline and any reliably inferable group result as context. An allied victory that the dead character still reliably observes can determine the primary result; an unobserved later victory cannot.

A skirmish is more than a collection of killing blows. Healers, supporters, pets, multiple targets and battles with zero kills, HKs or honor belong in the journal. Preserve meaningful facts and reasonable local inferences; never invent a death, participant, action, reward or certainty. Missing one ideal API field is not sufficient reason to discard otherwise compelling evidence.

## 2. Scope: open-world PvP and optional battleground PvP

- Record PvP confrontations between opposing player characters in the **open world**.
- **Battlegrounds are supported and enabled by default.** The player can opt out of **recording** battleground encounters using one settings checkbox: **Track Battleground Skirmishes** (default **ON**). **This option controls recording only, not recognition or display of existing rival history.**
- When the checkbox is ON, battleground skirmishes follow the same fundamental idea as open-world skirmishes: track the **local, connected confrontation**, not automatically the entire battleground match, its full team rosters, or its final scoreboard.
- When the checkbox is OFF, **do not record new battleground skirmishes, kills, deaths, rewards, or battleground-driven changes to rival history and scores**. Existing records remain saved and browseable; open-world tracking is unaffected.
- **Always recognize previously recorded rivals in battlegrounds and the open world, regardless of this checkbox.** The unit tooltip shows their personal rival score, including explicit manual results. Nameplates use the same score and keep their labelled historical fallback. Both surfaces obey their independent display settings.
- The same opposing player can be recognized later in the world or on another battleground, **even when battleground recording is disabled**. Keep **one rival identity and shared history**, with each individual encounter labelled by its origin; do not create duplicate rival profiles for each context.
- Other instanced PvP modes are outside this specification. Do not silently expand scope to them.
- Do not turn ordinary PvE encounters, friendly activity, nearby spectators, or independent fights into this skirmish.
- This is a locally observed personal account, not a global reconstruction of an entire battlefield.

## 3. What is one skirmish?

A skirmish is a **continuous, connected hostile confrontation** between the two sides. It begins when meaningful PvP engagement occurs or the local character joins an already ongoing confrontation. Track the character's participation, the connected encounter's observable ending, and loss of observation separately.

### Starting, observing, and joining

- Engaging an enemy can begin before the first damage is dealt: an offensive ability, crowd control, or commanding a pet to attack may be the first action.
- An attempted attack that never connects or contributes to any real PvP confrontation should not create a completed fight by itself.
- Confirmed directed damage from the local character to an opposing player can establish a skirmish even when nobody dies and no incoming damage is available. A Damage Meter pair must identify both players and belong to the observed combat window.
- Targeting a hostile player, being in range, seeing a nameplate, or being in a group **does not by itself** establish participation.
- **Visible nameplates are not required.** Ranged attacks, spells, controlled pets, and observations of an ongoing fight can precede nameplate visibility.
- The local character may arrive **mid-fight**. Observed participants and events from the earlier phase of the same connected confrontation should be retained when available, rather than starting the story at the first personal killing blow.
- The character may witness a fight before joining it; that observation is useful context. The journal is about locally experienced or joined PvP, not logging all distant fights the character never engages with.
- People who fought before any usable observation may be unknowable. Do not create invented players or backfill unobserved actions.

### Keeping a confrontation together

- Multiple targets, kills, heals, brief pauses, stealth, resurrections, and reinforcements can belong to **one** skirmish.
- A local character's death can end their own participation without ending the observed confrontation. Keep reliable allied continuation as context, and allow a genuine return to the same fight to reopen the provisional personal ending.
- Separate nearby fights must remain separate when they are not part of the same connected confrontation.
- A genuinely new engagement after the previous local confrontation has ended starts a new skirmish; don't merge independent fights merely because they happen near each other.
- Do not split one continuing fight just because the local player briefly leaves combat, changes target, or loses sight of a unit.
- **Battleground-specific:** the match can contain many independent clashes (for example, at different objectives). Record distinct local fights as distinct skirmishes. A death followed by a respawn and a later new fight is not automatically part of the first fight. Conversely, a continuing fight is not split merely because it takes place on a battleground.

## 4. Participants: the entire involved side, not only finishers

**Core rule:** Include every player demonstrably involved in the same confrontation, whether or not they dealt the finishing blow or shared a party with the local character.

Qualifying involvement can include:

- Attacking, attempting a relevant hostile ability, damaging, or controlling an opponent.
- Being attacked or otherwise directly affected by an opposing participant.
- Healing, shielding, buffing, dispelling, protecting, crowd-controlling, or otherwise materially supporting a participant **in this same fight**.
- Fighting via a pet or other controlled unit. This activity belongs to its verified player owner. Roster slots and rival histories are for players.
- Joining later, retreating, dying, reviving, or leaving early, after having participated.

The support case matters: **a priest who only heals a fighting ally is still a participant**, even with no recorded damage or killing blow.

A player does **not** become a participant solely by being in the party, appearing on a nameplate, being selected as a target, standing nearby, or fighting an unrelated NPC. Actions must connect them to this confrontation. Conversely, a character need not be in our party/raid to be an ally.

For a fight joined in progress, a hostile player's consistent focus on an independently identified friendly player in the same confrontation can corroborate involvement when that friendly player is also observed alive, PvP-flagged, and fighting around the hostile player's confirmed death. Record the roster evidence separately from any damage, support, or finishing-blow attribution.

### The limits of observation

- Retain all identifiable actual participants supported by what the character could observe.
- Show names, faction, class, race, and level when known. A known participant can remain in the report even when some details are missing.
- Do not assume that an unseen player was absent from the fight.
- Display team sizes as **observed participants**, not guaranteed complete numbers. An incomplete roster is a coverage limitation, **not** a reason by itself to label the personal outcome Unknown. Distinguish a participant from a rival whom the local character actually helped defeat. After 2.0.0, show a roster warning only for a concrete observed gap or unresolved participant evidence, not merely because a battle is not a direct 1×1 kill. Absence of a warning is not a claim of omniscient coverage; keep internal outcome evidence separate from the UI indicator.
- If a player was fighting before we arrived and there is evidence linking them to this clash, include them even if they stopped before our first attack.

## 5. How the character's participation ends

Track the connected fight and the character's participation separately. The record may continue to collect observable allied activity after the local player dies, drops combat or releases spirit. This does not require waiting indefinitely to decide the character's own result.

- A death is an event, not necessarily the end of a continuing fight. If the character genuinely returns to the same linked confrontation, preserve the death and revival, then evaluate the final participation. A brief pause, stealth, resurrection or change of target is not necessarily a new skirmish.
- A terminal PvP death followed by loss of observation before a reliable encounter ending is Defeat. If observation continues to a reliable ending, apply section 6, even if the character remains dead. If the character genuinely returns, evaluate the continued encounter.
- Spirit release, leaving the area, respawning elsewhere or starting an unrelated fight can close local participation or observation. They are coverage/boundary signals, not outcomes by themselves. Preserve decisions supported before observation stopped.
- Retreat, stealth, survival and losing a nameplate are not outcomes by themselves. A supported non-elimination ending uses the casualty balance. No inference about intention or territorial control is required.
- A death unrelated to the PvP episode (for example an unrelated NPC death) does not automatically create a PvP loss or assign a rival credit. Mixed PvE/PvP deaths require evidence connecting the death to the confrontation; a confirmed hostile player finisher is sufficient even if NPC damage preceded it.

### Waiting for continuation and closing the encounter

Separate a real local PvP episode from the client's combat flag. A lull, stealth, death, spirit release or crossing an ordinary open-world zone boundary can occur during the same fight. Keep a bounded pending/settling state when continuation is plausible, with a provisional result that can be revised if genuine participation resumes.

- Meaningful renewed hostile/support activity linked to the same continuing confrontation, or a revival followed by actual return, can continue the record. Merely sharing opponents, party, location or map is insufficient. Resurrection alone is not proof of re-engagement.
- A sufficiently long quiet interval since the last qualifying activity, combined with the character's state and other available boundary evidence, can finalize the encounter. Use a bounded timeout so an unobservable fight cannot wait forever. Exact intervals are technical choices to justify against existing fixtures and real play, not a new owner-specified number of seconds. Late diagnostic receipt alone does not reset the hostile activity clock.
- The character beginning an unrelated PvE fight in a different place/time, resuming ordinary travel or engaging an independent fight is positive evidence that the previous PvP participation ended. An NPC attack during the same mixed PvE/PvP episode is not by itself a boundary.
- A change in localized zone name or map within the open world is not a sufficient hard boundary: opponents can chase one another across a border. Distinguish true instance/match changes, loading/disconnect and incompatible context from ordinary zone transitions. Preserve any already supported personal result if observation genuinely ends.
- Once an encounter is genuinely finalized, later revenge against the same opponents is a new skirmish, even near the same location. For example, the party is killed, regroups, searches for the opponents and fights them again roughly five minutes later: two encounters, not one continuing record. The example is not a literal five-minute timeout.
- Keep late evidence reconciliation distinct from reopening participation. A late readable kill or meter sample can update its exact earlier episode without merging a new fight. Reject stale callbacks and ambiguous links.
- A short combat gap caused by control or movement can connect two local windows when the exit, entry and renewed PvP activity independently link the same live confrontation. For example, an opponent keeps targeting the local player through a trap and brief retreat. The resumed fight ends in the local player's death. Record one Defeat with both segments and one rival loss. A previous settled Victory against that opponent remains a separate meeting.

A practical lifecycle is Active → Awaiting continuation → Finalized, with an evidence-linked return from Awaiting continuation to Active. These are conceptual states, not required enum names. Persist enough information to keep boundaries and outcomes coherent after reload; do not persist raw session-relative uptime as a durable clock.

## 6. Outcome: observed resolution, character POV, and casualty balance

The primary result tells how the observed confrontation ended from the local
character's perspective. It is independent of rival-specific credit, personal
finishing blows, reward totals and the final battleground scoreboard. The
owner approved the following ordered hybrid contract to proceed with
implementation. Evaluate at finalization; while the fight is active or
awaiting continuation, keep its lifecycle separate from its result.

1. **Corroborated decisive resolution:** if the observed confrontation
   establishes one side's elimination while the other has surviving
   participants, the surviving side wins, even when accumulated death episodes
   favor the eliminated side. If mutual elimination is actually established,
   the result is Draw. Use latest verified life states, including revivals, for
   elimination, not cumulative casualties. A known roster is not automatically
   a complete roster, and disappearing opponents are not confirmed dead.
   Require sufficient local evidence that the confrontation was resolved.
2. **Terminal personal death with no observed decisive ending:** if the local
   character's PvP-related death ends their participation and observation before
   a reliable ending is known, Defeat. This includes the solo character killed
   by a surviving foe, or a dead character losing contact with a continuing
   group fight. Do not award a Victory merely because the partial casualty
   tally was favorable. Spirit release is a potential observation boundary,
   not an automatic result; actual continuing linked observations matter.
   A return to the same fight invalidates a provisional terminal death.
3. **Observed non-elimination ending:** when the encounter is established as
   ended, compare confirmed PvP-linked death episodes on the two sides:
   fewer friendly deaths → Victory, more → Defeat, equal (including zero)
   → Draw. This includes a living character who defeated one opponent and
   disengaged from another, and a dead character who was able to observe
   the group engagement's actual conclusion. No need to infer fear, intent,
   territory ownership or which survivor chose to retreat.
4. **Insufficient ending evidence:** do not turn a truncated observation or
   an absent API field into a proven Draw. Retain exceptional Unknown for genuinely unresolved cases; preserve legacy
   Unknown separately. UI presentation belongs to PR C. Ordinary missing
   optional fields alone do not establish an indeterminate ending. Ordinary mutual disengagement
   with no recorded casualties and a supported ending is Draw, not Unknown.

Use the Active → Awaiting continuation → Finalized lifecycle.
In progress is a lifecycle state, not an outcome. A death or spirit release
does not immediately finalize if linked observation or real return remains
plausible. Use bounded waiting; a finalized encounter and later revenge
remain distinct. Evaluate based on available verified observations, not
a fictional omniscient replay. A partial roster or missing coordinates
alone must not veto a well-supported resolution.

For the casualty comparison, the unit is distinct confirmed
death episodes, not rival credits, consistent with the approved per-rival
unit. A death to three attackers is one casualty. Genuine revival followed
by another confirmed death counts again. Exclude unrelated NPC deaths,
bystanders, ambiguous/duplicate events and unlinked fights. Preserve
coverage, reason, observation boundary and original historical outcomes
separately from the derived result.

Acceptance examples (friendly deaths : enemy deaths):
- Solo kills two and is killed by a surviving third: 1:2 → Defeat, decisive
  elimination or terminal-death boundary takes precedence.
- Solo kills one of two enemies, escapes alive, fight ends: 0:1 → Victory.
- Solo escapes an attack alive and the confrontation ends with no casualties:
  0:0 → Draw.
- Local player dies; brother remains fighting; player loses observation with
  two enemies already dead: 1:2 → Defeat absent a known decisive resolution.
- Local player stays dead, observes brother defeat the last of three enemies
  and survive: 1:3 → Victory, even though the character died.
- Allies and enemies disperse, with the end observed and losses 1:2 → Victory;
  losses 2:2 → Draw. A living survivor who lost two allies while one enemy
  died and the fight ended → Defeat.
- Local death followed by revival and genuine re-engagement: In progress
  until the encounter actually ends; earlier casualties and rival credits remain.

### Evidence and implementation boundaries

Use verified facts and corroborated observations rather than demanding perfect
coverage. For elimination use latest life state, not a cumulative death count;
for casualty scoring use distinct death episodes, not the number of rival
credits. In a known solo confrontation, confirmed local death to a surviving
opponent is decisive even without later terminal samples. Mutual elimination
requires actual evidence of both sides' terminal deaths, not merely a tied
casualty count or absent nameplates. A confirmed dead character who observed
a supported non-elimination ending also uses the casualty comparison. A quiet
interval combined with compatible observations can establish an ordinary
ending: no universal requirement for coordinates, complete roster, or perfect
terminal snapshots. No inference of victory solely from survival.

Feign Death, later revival and identity reuse matter. Do not treat unavailable
Feign Death as false or disappearance as death. A known non-Hunter class is
relevant corroboration, not universal proof. An unavailable flag must not veto
an otherwise well-supported death. Preserve reasons, coverage, death episode
counts, life states, observation boundary and evaluator version separately
from the result. Do not invent evidence to make historical fixtures pass.
Keep old side results as legacy context; additional observed group context
may be retained when supported, but is not a prerequisite or a competing
primary badge. Rare new ambiguities can be discussed during implementation.
No new requirement for global synchronization or exhaustive observation.

## 7. What the journal shows and counts

### Skirmish views

- **Primary outcome:** Victory, Defeat or Draw from section 6; exceptional Unknown for genuinely unresolved endings. Show In progress separately for ongoing/settling encounters.
- **Observed sides and roster:** identify actual Alliance and Horde participants, including meaningful support; keep known class, race, name and level. Use Blizzard's skull only for an explicitly observed skull-level value; hide an unavailable level.
- **Casualties and timeline:** confirmed deaths, finishing blows and revivals, plus meaningful actions and available permanent aggregates. A pet finishing blow shows its verified player owner as the actor. When ownership is unresolved, show an unknown player and retain the actual source as technical evidence. Do not mark disappearance as death or fabricate a killer or individual hit from an aggregate.
- **Rewards:** distinguish game-awarded Honorable Kills and Honor Points from both personal and rival outcomes. Preserve earned rewards at the most specific confirmed scope. A unique confirmed opponent death with matched native award observations in the same window can attribute the award to that rival without identifying the finishing blow. Move an already-counted award once on stronger evidence, preserving the journal total. Show rival- and skirmish-scoped awards in their respective views. Keep journal-wide unmatched awards in internal accounting and diagnostics.
- **When/where, origin and coverage:** date, zone, map waypoint if available, observed rather than guaranteed full roster. A recovered fight can show a waypoint when its exact combat window retained a validated player map position. Both compact and full battleground cards retain the localized Battleground label beside the location.
- **Group context:** optional and explicitly labeled. It does not replace the character's primary outcome.

### Personal rival score: participation, not last-hit ownership

The rival profile, compact rival encounter card, nameplate and unit tooltip should describe **my character's history with that particular opponent**. Never copy a skirmish's personal or group outcome to every opponent on its roster.

A personal victory over a rival is credited when the rival is defeated in the connected confrontation and the local character demonstrably contributed to that defeat:

- A confirmed killing blow is sufficient. It is not necessary.
- Readable damage dealt to that rival during the relevant engagement qualifies, even when a teammate lands the final hit.
- Meaningful hostile control, dispels, interrupts, or other relevant hostile contribution can qualify with reliable linkage.
- **Indirect support counts equally:** healing, shielding, protecting, buffing or otherwise materially supporting an ally engaged against the rival in the same connected episode qualifies. A pure healer can earn a victory over a mage killed by that supported ally without dealing any damage. No minimum damage requirement or last-hit requirement.
- Credit verified pet/controlled-unit activity to its owner; do not invent ownership.
- A confirmed death with no known finisher can qualify if relevant local contribution and the death are reliably linked. No need to know the final hitter.
- A party membership, nearby appearance, unrelated heal or PvE action, generic totals, honor alone, or mere membership on the opposing roster is not proof of participation in that rival's defeat. Link support to the ally's relevant engagement and the opponent's death, not to every enemy in a large fight.

For a rival loss, apply the analogous attribution principle to the local character's confirmed PvP death: a direct hostile finisher qualifies, and every other rival with reliably linked material participation in that death qualifies (including damage or relevant support/control). If three enemies damaged the character in the same lethal episode, all three receive a rival-specific loss credit, regardless of who finished the character. This is one friendly death episode, not three; the single skirmish result follows section 6. Do not give a loss against every enemy merely because our character or side lost. Do not presume a healer on the other side was supporting the killer without evidence. An NPC-only death cannot create rival losses.

**Keep the score, direct-player counters and Finishing blows distinct.** Rival wins and losses represent credited participation in defeats and deaths. The personal killing blow and death counters use literal direct-player kill events. Finishing blows can display a verified player owner for a pet's lethal hit. The underlying death keeps the pet as its physical source, and the owner attribution can support rival credit without incrementing a direct-player counter. HKs and honor remain the game's awards.

Joining an ally's fight can qualify both characters on evidence tied to the same confirmed opponent. A party roster, a longer shared meter session, or combat against another target does not establish that link. A later generic combat flag from an ally does not reopen a witnessed elimination on its own. A linked renewed PvP action or an observed returning opponent can invalidate the earlier ending.

Examples:
- I damage a mage, my brother finishes the mage: victory against the mage; zero personal finishing blows.
- I heal my brother while he fights and defeats the mage: victory against the mage even with zero damage.
- I kill the mage, then a rogue kills me: overall personal Defeat; victory against the mage and loss against the rogue (and any independently proven contribution to my death). The mage does not automatically get a loss credit simply because they were there.
- I fight a mage, both of us leave alive: preserve the meeting and its context; do not invent a kill-based rival victory. Non-lethal opponent-specific wins/losses are excluded from this milestone's death-linked rival score. An observed non-elimination ending uses the casualty balance for the primary skirmish outcome.

**Approved counting unit:** one credit per rival, per genuine death episode, per direction. Repeated signals, overlapping categories, late reads and replay of the same death do not add another credit. A confirmed revival followed by another relevant death is another episode: helping defeat the same mage twice earns two rival victories. The character's own two deaths may likewise earn two losses against a qualifying rival even if they belong to one skirmish. The skirmish itself has one final personal outcome, independent of those counts. A confirmed death plus reliably linked participation is enough even if the finisher is unknown.

Count every explicit manual win or loss once in the visible personal rival
score. Keep the manual provenance in the ledger and the card label. Manual
results carry no automatic contribution evidence, finishing blows, deaths,
Honorable Kills or Honor Points. Preserve any awards already recorded in
historical data. Re-evaluate an old side result only where retained evidence
supports the new semantics.

### UI semantics

The full skirmish card and cross-rival journal use the character's personal outcome. A compact card inside a rival profile must present the rival-specific result/credit, or clearly distinguish it from the overall personal outcome; never show an unqualified group Defeat as the result of a fight against a mage I helped defeat. If a single fight contains both a credited victory and a loss against one rival, represent both rather than force a misleading binary badge. A rival without enough evidence for credit remains in the history with no invented score. Keep the current native visual language and use concise labels/tooltips; exact layout can be designed later.

Open-world and enabled battleground encounters feed the same rival history and display the same personal-score meaning across the profile, tooltip and nameplate. Disabling recording or a display setting follows section 2. Do not quietly omit healers or turn a personal score into a faction-wide scoreboard.

### History retention

**Permanent Battle History** retains every rival and skirmish indefinitely.
It includes time, place, sides, versioned outcomes, confirmed kills, deaths and
revivals, rival contribution facts/credit, rewards, the core timeline, and the
accepted Damage Meter aggregates saved with the skirmish. Keep evidence needed
for future score re-evaluation and user-facing history independently of debug
retention. Historical facts are not overwritten by a new outcome model. There is no automatic age, count or
byte quota for this history. The cross-rival view displays the latest 100
entries. An individual rival's history includes every linked encounter.

**Debug Evidence** covers API samples, repeated readings, rejection reasons
and meter session diagnostics. It can be compacted or cleared. The core
timeline and saved damage, healing and absorb amounts remain available for
future timeline views. A user's explicit reset or profile deletion follows
the existing confirmation flow.

## 8. Real encounters and regression targets

The following are anonymized product examples, not claims that old captures already contain all required data. Preserve the real evidence and do not hard-code record IDs. See [Forever validation](forever-validation.md) for the original technical findings.

### Duskwood, 22 November 2026

The original capture was 1 vs 2, later reconstructed as 2 vs 3 with two enemy deaths and five honor. The local hunter joined an ongoing fight with a priest ally; the third enemy's death is not confirmed. A nearby friendly bystander is not a participant unless linked by meaningful action. The observed local result should be Victory if the non-elimination ending is established and the confirmed casualty balance favors the character's side; an incomplete roster or last-seen-alive enemy alone must not force Unknown. Preserve the actual two deaths and credit supported rival contributions, not blanket wins against all three opponents. The retained replay currently remains Unknown; missing evidence cannot be invented.

### Gnomeregan, 23 November 2026

- **20:08, world:4 (2 vs 2):** one enemy killed by the ally, the other (known Paladin) observed dead in a contact, without a recorded Feign Death value. Both allies alive and out of combat in two later samples. Existing result Unknown / site-anchor-missing. Strong candidate for personal Victory using corroborated local evidence without requiring an exact anchor. Investigate whether the available raw observations establish the second defeat; preserve uncertainty about an unconfirmed death and finisher. Rival credit requires actual local contribution, not only the observed group win.
- **20:11, world:7 (2 vs 3):** local character killed by a hostile player, later allied death and continued hostile activity observed; area change before final samples. Existing group result Unknown / area-changed. Expected personal Defeat on terminal death and loss of observation before a reliable ending, if no return is established. Retain the observed allied continuation and do not claim a final group winner. Credit the actual killer and only other demonstrably involved rivals for the personal death.
- **22:22, world:12 (1 vs 1):** high-level opponent lands confirmed lethal PvP damage while the character is low on health from PvE. Expected personal Defeat (already repaired in 1.1.0). Unknown level remains unknown, not a fabricated skull.
- **22:37, world:14 (1 vs 3 observed):** hostile Paladin kills the local player, two additional opponents linked to the fight, spirit release and area change, no terminal samples. Expected personal Defeat on terminal death and loss of observation without return; group result unknown. Do not credit all three automatically as personal losses.
- **20:09 and 20:20:** preserve prior improvements to teammate kills and Damage Meter-linked participation. **20:21:** do not invent the lost historical card; retain the fix preventing a subsequent combat window from replacing the first readable links. Preserve reward attribution improvements (39 historical honor, 25 linked, 14 unassigned; no automatic invented backfill).

## 9. Acceptance scenarios

1. Ordinary 1 vs 1: clear terminal win/loss yields the corresponding personal outcome, with attributed death credit where supported.
2. Group fight: include meaningful damage dealers, victims, healers, shields, crowd control and other linked support regardless of last hit or party membership.
3. Local damage, ally finishing blow: credit the local character's victory over that rival once for the relevant defeat, without claiming a personal killing blow.
4. Pure healer: heal or shield an ally fighting and killing a mage; credit the healer's victory even with zero direct damage. An unrelated heal or passive party membership earns no credit.
5. Support chain: an identifiable ally receives meaningful support connected to the same opponent and death episode. No indiscriminate credit for other enemies or unrelated earlier/later windows. Test missing and restricted endpoints.
6. Enemy receives support and kills me: attribute my loss to the killer and other rivals only where their material involvement is independently established. No automatic blanket losses.
7. Kill mage, die to surviving rogue while solo: personal Defeat, mage-specific victory credit, rogue-specific loss credit, actual finishing blow/death counters independent. If both directions are credited against one rival, show both.
8. Local character dies while allies continue: Victory if the character observes the allies eliminate the opposition and survive; Defeat if observation is lost before a reliable ending and there is no return. Apply casualty comparison if an observed non-elimination ending occurs. A later unobserved allied victory cannot change the result.
9. Death then resurrection and genuine return to same battle: keep death/credit, revise provisional personal result according to subsequent ending; distinguish new battle after respawn.
10. Local character survives and disengages: use the casualty balance at an established non-elimination ending; survival alone is not Victory.
11. Enemy retreats alive: if the encounter ends with zero deaths on either side, Draw; no fabricated death or rival credit. A favorable casualty balance can yield Victory without elimination.
12. Established mutual disengagement with equal deaths is Draw; an ongoing/settling encounter is In progress; genuinely unresolved observation may exceptionally be Unknown. Keep all real fights, even without rewards.
13. Feign Death, true corpse with missing flag, token reuse and revival: distinguish corroborated death from uncertain observation; do not require a single perfect field in all cases.
14. Duskwood and Gnomeregan: replay existing anonymized fixtures and original evidence; preserve prior roster, kill, reward, late-window fixes. Check world:4, world:7, world:12 and world:14 against section 8 without hard-coding outcomes.
15. Late arrival, visible pet from range, no initial nameplate, bystanders, unrelated PvE or independent nearby fights: keep only linked observations; no invented pre-arrival history; do not count pets as additional players.
16. Battleground recording defaults ON; label both card sizes, distinguish separate local clashes and respawns, ignore global match result as an outcome source.
17. Battleground recording OFF: no new BG records or score/reward changes; previously recorded rivals remain recognizable; open-world tracking unaffected.
18. One rival across both contexts; independent nameplate/tooltip options do not affect recording.
19. Permanent history survives reload, pruning and years of new records; oldest card retains roster, outcomes, confirmed timeline, contribution facts, aggregates and rewards. The latest-100 view is display-only.
20. Legacy group outcomes remain labeled as legacy; do not silently reinterpret as character outcomes or credit them to every rival. Re-evaluate only from sufficient retained evidence, preserve explicitly manual results, and test migration and repeat reload idempotency.
21. Duplicate notifications, overlapping meter categories, repeated read/replay, and revival followed by a new death: don't double count the same episode or erase legitimate distinct ones.
22. Report an Issue exports one pseudonymized JSONL document for one selection and copy. The report identifies outcome reason, credit evidence, unavailable fields and any sections omitted to fit the submission limit. Prior logging and SavedVariables sharing are optional.
23. Three rivals damage the character in the same lethal episode: each earns one rival loss; one friendly death episode and one skirmish result under section 6. A bystander or unrelated earlier attacker gets none.
24. Two genuine deaths of the same rival separated by revival, with qualifying local contribution in both: two rival victories, one skirmish; duplicate reads of either death do not add credit.
25. Stealth or temporary disengagement then linked re-engagement: continue the same skirmish. Two allies dead, one enemy dead, character escapes and the encounter ends: Defeat by casualty balance, not inferred intention.
26. Death, ghost run, resurrection and actual return to ongoing fight: keep the same record and original death. Later revenge after a finalized fight: start another record, even against the same enemies at the same place.
27. Chase across an ordinary zone border: do not split on zone name alone. An unrelated later PvE fight in a different place/time or bounded quiet interval can close the previous participation. An NPC mixed into the original PvP fight cannot close it by itself.
28. Delayed old meter read or kill notification after a new fight starts: only update the uniquely matched old episode; do not reopen or merge the fights. A delayed read is not proof of new activity.
29. Hybrid outcome cases: solo terminal death despite favorable casualties → Defeat; dead local player observing surviving allies eliminate the enemy → Victory; surviving disengagement with a favorable casualty balance → Victory; completed 0:0 or equal-casualty non-elimination ending → Draw; lost observation after terminal personal death → Defeat. Distinguish decisive elimination from cumulative death totals, genuine revival, incomplete observation, and an active/settling encounter. Three attackers contributing to one local death still yield one casualty.

## Boundaries and follow-up work

- This is a post-1.1.0 product redesign, not a hotfix to the released build. No runtime changes or release are implied by approval of this document.
- Preserve all existing real history, reward totals, user settings, identity handling, and the current native UI style. Separate versioned personal outcome and rival contribution from legacy side outcome; derived results must be traceable and re-evaluable without overwriting facts.
- No manual correction UI as a substitute for automatic inference. Existing manual-entry behavior remains separately identified.
- Report an Issue keeps native scrolling and focus in a compact window with one Select Report action. Preserve pseudonymization, the public attachment warning and optional use of the existing SavedVariables file. Keep evidence needed for future product views in permanent history independently of the diagnostic buffer.
- A full battle timeline viewer is later work. Preserve accessible facts and accepted aggregates now; never reconstruct exact casts, hits or times from untimed totals.
- Optional addon-to-addon synchronization between consenting friends/group members is a future idea, not a dependency. Research permitted Forever addon messages and provenance, trust, deduplication, privacy and conflicting observations before implementing. Solo operation must remain complete and useful; no expectation that opponents install Names in Red.
- Feasibility design and in-client validation remain necessary, especially for support linkage, terminal deaths/return, non-lethal outcomes and migration. Prefer small PRs: outcome boundary/evaluator, rival attribution and migration, then consistent UI/stat semantics and regression checks. Reconcile README and CurseForge descriptions when the behavior actually ships.
- Technical investigation uses [Forever validation](forever-validation.md), current source and anonymized fixtures, not speculative global combat events. See [PROJECT_CONTEXT.md](../PROJECT_CONTEXT.md) for the development handoff.

---

**Guiding principle:** Tell my character's story. Remember who I fought and helped defeat, what happened to me, and what I could know about the fight. Give healers and teammates fair credit without inventing last hits. Preserve history indefinitely. Use Draw for established equal-loss endings, and reserve Unknown for genuinely unresolved observation, not unavailable global knowledge.

## 10. Approved post-2.0.0 polish

The owner accepted release 2.0.0 and deferred these corrections until after publication. The polish preview implements the following behavior. Live Forever acceptance is pending.

- **Coverage UX.** The displayed count is the observed roster. The warning requires a concrete unresolved participant or evidence of observation cut short during an ongoing PvP exchange. Roster size, a missing finisher, or a general API restriction alone do not trigger it. The outcome evaluator retains its own `rosterComplete` evidence. The restored 2×1 World:27 is the acceptance example.
- **Manual rival identity.** A unique normalized full-name match reuses the existing profile in the client's confirmed regional name scope, or in the home realm when regional uniqueness is unavailable. The current matching target can supply a GUID directly, including the player's own character as an explicit manual entry. On save, resolve matching readable details from the target, mouseover, available nameplates and previously identified profiles. Revalidate the dialog's opening target against the typed name and the identities available at save. Later target, mouseover or fight evidence can enrich a provisional profile. Preserve unknown fields and the original context of the manual encounter. Conflicting confirmed GUIDs and ambiguous matches stay separate, including after reload.
- **Shared card action buttons.** The waypoint diamond, details icon and report bug use a common centered native button geometry wherever they appear. The frame, hit area, tooltips and action behavior are preserved.
- **Portrait and result layout.** The shared level digits are one UI unit smaller and centered in the badge. Both card layouts center each portrait with its displayed name. The compact result centers its icon and caption together. Wrapped localized names and multi-row rosters retain their layout.
- **Natural score language.** Explanatory tooltips describe defeating a rival, or being defeated by them, alone or with allies. Confirmed support retains its credit. Let Blizzard size and wrap all four profile statistics tooltips and their history lines.
- **Unit tooltip.** Its Names in Red section shows the heading plus personal rival-score icons and numbers. The profile and nameplate use the same personal total. Historical side results and the provenance of explicit manual entries remain available in the journal. Native tooltip content and the existing display options are preserved.
- **Out of scope:** leave honor/currency number and icon alignment as it is (owner withdrew this request after comparing the native bag presentation). No formal duels, ally profiles, target menu, progression, new timeline features, or other future-idea implementation in this polish phase.

Use focused tests and preview acceptance for the actual fixes; avoid changing the accepted Character POV scoring or old records merely for visual polish.
