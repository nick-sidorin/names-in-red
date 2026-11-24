# Names in Red — PvP Skirmishes: Product Specification

**Status:** Owner-approved Character POV direction, 24 November 2026. This is the target behavior for development after 1.1.0, not a description of its shipped behavior. It supersedes the previous side-outcome and rival-score semantics. The evidence and implementation details belong in [Forever validation](forever-validation.md).

## 1. Product goal: Character POV

Names in Red is a **personal combat journal of an individual character**, for connected PvP skirmishes in the open world and on enabled battlegrounds. It is not a neutral referee, a global combat log, a scoreboard for all participants, or a reconstruction of the whole battlefield. It should feel like the character's own recollection of adventures in Azeroth.

A solo player must find the journal useful without any other player installing the addon. A character may enter an ongoing battle, die, be revived, leave, or lose observation. The record includes the locally available evidence, including reliable information about others from the client's APIs. It does not assume knowledge of off-screen events before arrival or after observation is lost. Voice chat and a friend's account of later events are not automatically known to the character's addon.

The journal answers three independent questions:

1. **How did my character fare?** The primary skirmish result is the character's own Victory, Defeat or Unknown.
2. **What happened between me and this rival?** A separate personal score credits meaningful participation in defeating that opponent and records relevant losses to them, not simply who dealt the finishing blow.
3. **What happened around me?** Preserve the observed sides, participants, timeline and any reliably inferable group result as context. A later allied victory does not turn the character's terminal death into a personal victory.

A skirmish is more than a collection of killing blows. Healers, supporters, pets, multiple targets and battles with zero kills, HKs or honor belong in the journal. Preserve meaningful facts and reasonable local inferences; never invent a death, participant, action, reward or certainty. Missing one ideal API field is not sufficient reason to discard otherwise compelling evidence.

## 2. Scope: open-world PvP and optional battleground PvP

- Record PvP confrontations between opposing player characters in the **open world**.
- **Battlegrounds are supported and enabled by default.** The player can opt out of **recording** battleground encounters using one settings checkbox: **Track Battleground Skirmishes** (default **ON**). **This option controls recording only, not recognition or display of existing rival history.**
- When the checkbox is ON, battleground skirmishes follow the same fundamental idea as open-world skirmishes: track the **local, connected confrontation**, not automatically the entire battleground match, its full team rosters, or its final scoreboard.
- When the checkbox is OFF, **do not record new battleground skirmishes, kills, deaths, rewards, or battleground-driven changes to rival history and scores**. Existing records remain saved and browseable; open-world tracking is unaffected.
- **Always recognize previously recorded rivals in battlegrounds and the open world, regardless of this checkbox.** Existing history and scores appear in unit tooltips and on nameplates wherever the recognized opponent is encountered, subject only to the existing independent **unit tooltip** and **nameplate icons** display settings. Disabling battleground recording must never hide those indicators.
- The same opposing player can be recognized later in the world or on another battleground, **even when battleground recording is disabled**. Keep **one rival identity and shared history**, with each individual encounter labelled by its origin; do not create duplicate rival profiles for each context.
- Other instanced PvP modes are outside this specification. Do not silently expand scope to them.
- Do not turn ordinary PvE encounters, friendly activity, nearby spectators, or independent fights into this skirmish.
- This is a locally observed personal account, not a global reconstruction of an entire battlefield.

## 3. What is one skirmish?

A skirmish is a **continuous, connected hostile confrontation** between the two sides. It begins when meaningful PvP engagement occurs or the local character joins an already ongoing confrontation. The shared record can cover the observable connected confrontation, while the character's own participation and outcome have a separate ending.

### Starting, observing, and joining

- Engaging an enemy can begin before the first damage is dealt: an offensive ability, crowd control, or commanding a pet to attack may be the first action.
- An attempted attack that never connects or contributes to any real PvP confrontation should not create a completed fight by itself.
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
- Fighting via a pet or other controlled unit; credit that involvement to the owning player, rather than counting the pet as another player on the roster.
- Joining later, retreating, dying, reviving, or leaving early, after having participated.

The support case matters: **a priest who only heals a fighting ally is still a participant**, even with no recorded damage or killing blow.

A player does **not** become a participant solely by being in the party, appearing on a nameplate, being selected as a target, standing nearby, or fighting an unrelated NPC. Actions must connect them to this confrontation. Conversely, a character need not be in our party/raid to be an ally.

### The limits of observation

- Retain all identifiable actual participants supported by what the character could observe.
- Show names, faction, class, race, and level when known. A known participant can remain in the report even when some details are missing.
- Do not assume that an unseen player was absent from the fight.
- Display team sizes as **observed participants**, not guaranteed complete numbers. An incomplete roster is a coverage limitation, **not** a reason by itself to label the personal outcome Unknown. Distinguish a participant from a rival whom the local character actually helped defeat.
- If a player was fighting before we arrived and there is evidence linking them to this clash, include them even if they stopped before our first attack.

## 5. How the character's participation ends

Track the connected fight and the character's participation separately. The record may continue to collect observable allied activity after the local player dies, drops combat or releases spirit. This does not require waiting indefinitely to decide the character's own result.

- A death is an event, not necessarily the end of a continuing fight. If the character genuinely returns to the same linked confrontation, preserve the death and revival, then evaluate the final participation. A brief pause, stealth, resurrection or change of target is not necessarily a new skirmish.
- A terminal death attributable to the PvP encounter, without a return to that confrontation, is a personal Defeat. Do not demand proof of what happened to all surviving allies and enemies after that death.
- Spirit release, leaving the area, respawning elsewhere or starting an unrelated fight can close the local participation. They are coverage/boundary signals, not outcomes by themselves. Preserve decisions supported before observation stopped.
- Retreat under credible hostile pressure can end the character's participation with Defeat without a death. Losing a nameplate, leaving combat or losing access to an API alone is not evidence of retreat, death or victory.
- When the character remains alive and the local threat is overcome or driven away, a clear resolution can be Victory without a coordinate anchor or a certified complete roster.
- A death unrelated to the PvP episode (for example an unrelated NPC death) does not automatically create a PvP loss or assign a rival credit. Mixed PvE/PvP deaths require evidence connecting the death to the confrontation; a confirmed hostile player finisher is sufficient even if NPC damage preceded it.

## 6. Outcome: personal Victory, Defeat or genuinely Unknown

The primary outcome is **how the local character's own participation in this skirmish ended**. It is not their kill count, and it is not necessarily the final result of their faction or group. Preserve the observed group ending as optional, separately labeled context when available. Never copy the battleground match result to a local fight.

### Victory

The character survives the concluding part of the confrontation and reasonably overcomes the local opposing threat, alone or with participating allies. A healer who helps allies win can earn the same personal Victory as a damage dealer.

Evidence can include defeated opponents, allies and the character remaining safely together, disengagement after pressure, or a combination of meaningful actions and settled states. A confirmed enemy retreat can count without any kill. The local player's survival alone is not enough. A single disappearance or dropping combat alone is not enough. Do not require every opponent's fate, exact team sizes, two perfect coordinate snapshots or a known site anchor when other evidence establishes the local resolution.

### Defeat

The character's own participation ends in a confirmed PvP-related death or a reasonably established forced withdrawal. A terminal death remains Defeat even if surviving allies later win; that allied result is separate. If the character revives and returns to the same continuing confrontation, the personal outcome may be revised according to the actual later ending; retain all earlier death/kill events and rival credit. A character who survives but is driven off can lose. A simultaneous death of both players can still be a personal Defeat if our own participation ends in death; it need not establish a group victor.

### Unknown

Unknown is valid when the character's participation has ended or observation is lost without reasonable evidence of a personal win or loss, including mutual disengagement, ambiguous stealth/disappearance, or an unresolved living departure. It is not an error code for a missing field, incomplete roster, unavailable coordinate or unavailable group result. While participation is ongoing, do not prematurely lock an ending. Preserve an Unknown fight even with zero rewards or casualties; it does not count as either outcome.

### Best-evidence inference, not a courtroom standard

Use the combined story of the observed encounter, while distinguishing confirmed facts from inferred results. Prefer independent evidence paths for lethal outcomes, observed elimination, withdrawal, and unresolved endings. Feign Death and subsequent revival matter: assess same-identity, class, readable death state, chronological observations and corroboration. Do not simply promote an unavailable Feign Death flag to false, or infer death from disappearance. Conversely, a missing flag should not veto a strongly corroborated corpse or otherwise clear local victory. A known non-Hunter class is relevant evidence, not a universal proof that no feign-like effect is possible.

Record a reason and coverage for each inferred result separately from interruption or API availability. A later interruption must not erase an already supported personal result. If evidence conflicts or is genuinely insufficient, keep Unknown. Preserve earlier evidence and recompute versioned derived results when justified; do not fabricate missing observations to make a fixture pass.

### Observed group result

When reliable evidence supports a result for the whole observed local group, it may be recorded independently (including group Victory after personal Defeat). It may be Unknown or absent without affecting the personal result. Do not require a group result for a normal card or duplicate a second prominent badge everywhere. Its eventual UI is secondary to the character's own story.

## 7. What the journal shows and counts

### Skirmish views

- **Primary outcome:** the character's Victory, Defeat or Unknown.
- **Observed sides and roster:** identify actual Alliance and Horde participants, including meaningful support; keep known class, race, name and level. Use Blizzard's skull only for an explicitly observed skull-level value; hide an unavailable level.
- **Casualties and timeline:** confirmed deaths, finishing blows and revivals, plus meaningful actions and available permanent aggregates. Do not mark disappearance as death or fabricate a killer or individual hit from an aggregate.
- **Rewards:** distinguish game-awarded Honorable Kills and Honor Points from both personal and rival outcomes. Preserve earned rewards at the most specific confirmed scope (rival, skirmish, or journal); no invented attribution.
- **When/where, origin and coverage:** date, zone, map waypoint if available, observed rather than guaranteed full roster. Both compact and full battleground cards retain the localized Battleground label beside the location.
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

For a rival loss, apply the analogous attribution principle to the local character's confirmed PvP death: a direct hostile finisher qualifies, and other rivals with reliably linked material participation in that death (damage or relevant support/control) may qualify. Do not give a loss against every enemy merely because our character or side lost. Do not presume a healer on the other side was supporting the killer without evidence. An NPC-only death cannot create rival losses.

**Keep the score and literal combat statistics distinct.** Rival wins/losses represent credited participation in defeats/deaths, while personal killing blows and deaths directly caused by that rival are separately observable facts. HKs and honor remain the game's awards. A shared kill is not a personal finishing blow; neither statistic should be silently relabeled as the other.

Examples:
- I damage a mage, my brother finishes the mage: victory against the mage; zero personal finishing blows.
- I heal my brother while he fights and defeats the mage: victory against the mage even with zero damage.
- I kill the mage, then a rogue kills me: overall personal Defeat; victory against the mage and loss against the rogue (and any independently proven contribution to my death). The mage does not automatically get a loss credit simply because they were there.
- I fight a mage, both of us leave alive: preserve the meeting and its context; do not invent a kill-based rival victory. Non-lethal opponent-specific wins (for example a clear 1v1 retreat) are a possible later refinement requiring their own rule. They are not necessary for this iteration's participation score.

A natural implementation unit is a uniquely identified death episode plus credited rival, deduplicated across repeated signals and replay. A genuine revival followed by another defeat is a separate episode. The exact counter behavior for repeat deaths, non-lethal rival outcomes and legacy/manual rows must be settled explicitly in implementation design before changing persisted or public counters; do not silently combine different counting units. Preserve manual assertions as such.

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

The original capture was 1 vs 2, later reconstructed as 2 vs 3 with two enemy deaths and five honor. The local hunter joined an ongoing fight with a priest ally; the third enemy's death is not confirmed. A nearby friendly bystander is not a participant unless linked by meaningful action. The observed local result should be Victory if the character survived and the opposing force was driven away; an incomplete roster or last-seen-alive enemy alone must not force Unknown. Preserve the actual two deaths and credit supported rival contributions, not blanket wins against all three opponents. The retained replay currently remains Unknown; missing evidence cannot be invented.

### Gnomeregan, 23 November 2026

- **20:08, world:4 (2 vs 2):** one enemy killed by the ally, the other (known Paladin) observed dead in a contact, without a recorded Feign Death value. Both allies alive and out of combat in two later samples. Existing result Unknown / site-anchor-missing. Strong candidate for personal Victory using corroborated local evidence without requiring an exact anchor. Investigate whether the available raw observations establish the second defeat; preserve uncertainty about an unconfirmed death and finisher. Rival credit requires actual local contribution, not only the observed group win.
- **20:11, world:7 (2 vs 3):** local character killed by a hostile player, later allied death and continued hostile activity observed; area change before final samples. Existing group result Unknown / area-changed. Expected personal Defeat if no return to the same confrontation is established. Retain the observed allied continuation and do not claim a final group winner. Credit the actual killer and only other demonstrably involved rivals for the personal death.
- **22:22, world:12 (1 vs 1):** high-level opponent lands confirmed lethal PvP damage while the character is low on health from PvE. Expected personal Defeat (already repaired in 1.1.0). Unknown level remains unknown, not a fabricated skull.
- **22:37, world:14 (1 vs 3 observed):** hostile Paladin kills the local player, two additional opponents linked to the fight, spirit release and area change, no terminal samples. Expected personal Defeat on terminal death without return; group result unknown. Do not credit all three automatically as personal losses.
- **20:09 and 20:20:** preserve prior improvements to teammate kills and Damage Meter-linked participation. **20:21:** do not invent the lost historical card; retain the fix preventing a subsequent combat window from replacing the first readable links. Preserve reward attribution improvements (39 historical honor, 25 linked, 14 unassigned; no automatic invented backfill).

## 9. Acceptance scenarios

1. Ordinary 1 vs 1: clear terminal win/loss yields the corresponding personal outcome, with attributed death credit where supported.
2. Group fight: include meaningful damage dealers, victims, healers, shields, crowd control and other linked support regardless of last hit or party membership.
3. Local damage, ally finishing blow: credit the local character's victory over that rival once for the relevant defeat, without claiming a personal killing blow.
4. Pure healer: heal or shield an ally fighting and killing a mage; credit the healer's victory even with zero direct damage. An unrelated heal or passive party membership earns no credit.
5. Support chain: an identifiable ally receives meaningful support connected to the same opponent and death episode. No indiscriminate credit for other enemies or unrelated earlier/later windows. Test missing and restricted endpoints.
6. Enemy receives support and kills me: attribute my loss to the killer and other rivals only where their material involvement is independently established. No automatic blanket losses.
7. Kill mage, die to rogue: personal Defeat, mage-specific victory credit, rogue-specific loss credit, actual finishing blow/death counters independent. If both directions are credited against one rival, show both.
8. Local character dies while allies win: personal Defeat if no return; group Victory may be shown separately if reliably observed. Loss of later observation does not erase personal Defeat.
9. Death then resurrection and genuine return to same battle: keep death/credit, revise provisional personal result according to subsequent ending; distinguish new battle after respawn.
10. Local character survives but is forced to retreat: personal Defeat even without a death; distinguish from neutral withdrawal.
11. Enemy retreats alive under pressure: personal Victory when local resolution is established; no fabricated kill or automatic kill-based rival credit.
12. Mutual disengagement, ambiguous disappearance, ongoing combat or missing decisive evidence: no forced outcome; keep real fight, even without rewards.
13. Feign Death, true corpse with missing flag, token reuse and revival: distinguish corroborated death from uncertain observation; do not require a single perfect field in all cases.
14. Duskwood and Gnomeregan: replay existing anonymized fixtures and original evidence; preserve prior roster, kill, reward, late-window fixes. Check world:4, world:7, world:12 and world:14 against section 8 without hard-coding outcomes.
15. Late arrival, visible pet from range, no initial nameplate, bystanders, unrelated PvE or independent nearby fights: keep only linked observations; no invented pre-arrival history; do not count pets as additional players.
16. Battleground recording defaults ON; label both card sizes, distinguish separate local clashes and respawns, ignore global match result as an outcome source.
17. Battleground recording OFF: no new BG records or score/reward changes; previously recorded rivals remain recognizable; open-world tracking unaffected.
18. One rival across both contexts; independent nameplate/tooltip options do not affect recording.
19. Permanent history survives reload, pruning and years of new records; oldest card retains roster, outcomes, confirmed timeline, contribution facts, aggregates and rewards. The latest-100 view is display-only.
20. Legacy group outcomes remain labeled as legacy; do not silently reinterpret as character outcomes or credit them to every rival. Re-evaluate only from sufficient retained evidence, preserve explicitly manual results, and test migration and repeat reload idempotency.
21. Duplicate notifications, overlapping meter categories, repeated read/replay, and revival followed by a new death: don't double count the same episode or erase legitimate distinct ones.
22. Report an Issue remains automatic, bounded and copyable; report identifies outcome reason, credit evidence and missing fields separately. No requirement for prior logging, other addon installations, or public sharing.

## 10. Boundaries and follow-up work

- This is a post-1.1.0 product redesign, not a hotfix to the released build. No runtime changes or release are implied by approval of this document.
- Preserve all existing real history, reward totals, user settings, identity handling, and the current native UI style. Separate versioned personal outcome and rival contribution from legacy side outcome; derived results must be traceable and re-evaluable without overwriting facts.
- No manual correction UI as a substitute for automatic inference. Existing manual-entry behavior remains separately identified.
- The Report an Issue feature already ships in 1.1.0. Preserve pseudonymized JSONL, extra report pages, and optional existing SavedVariables attachment without prior logging or mandatory editing. Persist evidence necessary for future product views, not only in an expiring debug buffer.
- A full battle timeline viewer is later work. Preserve accessible facts and accepted aggregates now; never reconstruct exact casts, hits or times from untimed totals.
- Optional addon-to-addon synchronization between consenting friends/group members is a future idea, not a dependency. Research permitted Forever addon messages and provenance, trust, deduplication, privacy and conflicting observations before implementing. Solo operation must remain complete and useful; no expectation that opponents install Names in Red.
- Feasibility design and in-client validation remain necessary, especially for support linkage, terminal deaths/return, non-lethal outcomes and migration. Prefer small PRs: outcome boundary/evaluator, rival attribution and migration, then consistent UI/stat semantics and regression checks. Reconcile README and CurseForge descriptions when the behavior actually ships.
- Technical investigation uses [Forever validation](forever-validation.md), current source and anonymized fixtures, not speculative global combat events. See [PROJECT_CONTEXT.md](../PROJECT_CONTEXT.md) for the development handoff.

---

**Guiding principle:** Tell my character's story. Remember who I fought and helped defeat, what happened to me, and what I could know about the fight. Give healers and teammates fair credit without inventing last hits. Preserve history indefinitely. Reserve Unknown for genuinely uncertain personal endings, not for unavailable global knowledge.
