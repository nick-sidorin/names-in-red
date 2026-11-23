# Names in Red — PvP Skirmishes: Product Specification

**Status:** Product behavior proposal, 23 November 2026. This describes what Names in Red should do, not a claim about what the current addon already implements. It is intentionally independent of code, events, and APIs.

## 1. Product goal

Names in Red is a personal journal of **PvP skirmishes in the open world and, optionally, on battlegrounds**. A skirmish is a connected, local confrontation between opposing sides, **not** a collection of killing blows. A duel is only the simplest case. A fight may involve many people, unrelated parties, loosely allied players, controlled pets, support characters, and participants joining or leaving at different times.

When revisiting a fight, the player should understand:

1. **Who fought?** Show as many identifiable actual participants from both factions as were observable.
2. **What happened?** Show confirmed deaths/finishing blows, available player details, place, time, and attributable PvP rewards.
3. **Who won the local confrontation?** Show Victory, Defeat, or Unknown from the local character's side, based on the fight's resolution rather than a requirement to kill every opponent.

The journal records real fights, **including fights with no deaths, Honorable Kills, or Honor Points**. Never fabricate missing participants, deaths, rewards, or certainty.

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

A skirmish is a **continuous, connected hostile confrontation** between the two sides. It begins when meaningful PvP engagement occurs or the local character joins an already ongoing confrontation. It ends when that local confrontation is resolved or genuinely ceases.

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
- A local character's death does not necessarily conclude the confrontation if known allies continue fighting.
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
- Display team sizes as **observed participants**, not guaranteed complete numbers. An incomplete roster is a coverage limitation, **not** a reason by itself to label the outcome Unknown.
- If a player was fighting before we arrived and there is evidence linking them to this clash, include them even if they stopped before our first attack.

## 5. How a skirmish ends

A confrontation ends when the connected local fight is actually resolved or stops, **not** necessarily when someone is killed.

Possible endings include:

- The opposing side is killed or otherwise defeated.
- The opposing side disengages, flees, stealths away, or is pushed out, while our side remains in control.
- Our side is pushed out or forced to retreat.
- Both sides stop fighting and separate without a discernible victor.
- The player dies, while allies remain involved and eventually resolve the fight.

A disappearance from a nameplate alone is **not proof** of death, retreat, or victory: visibility can be lost for other reasons. Similarly, a momentary combat-state change or short lull is not necessarily the end of a continuing skirmish.

**Product expectation:** resolve the encounter from the overall course and ending of the connected confrontation, allowing its participants to leave, hide, or die without requiring everyone to be eliminated.

## 6. Outcome: Victory, Defeat, or genuinely Unknown

The result belongs to **the local character's side in this local confrontation**, not to the local player's personal kill count, damage, or survival. On battlegrounds, **winning or losing the entire match does not automatically determine the result of any individual skirmish**: a side can win a clash yet lose the match, or vice versa.

### Victory

**Victory** means our side won the local confrontation: it eliminated, drove away, or otherwise overcame the opposing side and retained the encounter.

Examples:
- We kill some opponents; the others flee or disengage; our side remains and the confrontation ends: **Victory**.
- We kill no one but successfully force the opponents away and hold the location: **Victory**.
- Our character dies, but the continuing allied side wins the same confrontation: **Victory**.

### Defeat

**Defeat** means our side lost the local confrontation, including when we withdraw or are driven away while the opposing side holds the field. Surviving personally does not turn a team loss into a win.

### Unknown

**Unknown** is a **valid recorded outcome**, but a narrow exception: the skirmish definitely happened and ended (or observation stopped), yet available evidence does not reasonably establish which side prevailed.

Examples:
- Two players exchange attacks, then both disengage and leave without a discernible winner.
- A rogue stealths away; if this plausibly ends a losing retreat, the other side may have won, but if the observation cannot distinguish withdrawal from a temporary repositioning or mutual disengagement, the report may remain **Unknown**.
- The player loses visibility of an unresolved fight before its ending and has no reliable evidence of the result.

**Never discard a real skirmish solely because its outcome is Unknown.** It belongs in history even with zero kills, zero HKs, and zero honor. Unknown is not a win or a loss and must not silently increment either counter.

### Avoid false Unknowns

**Unknown must not be the default fallback simply because the roster is incomplete or not every enemy died.** A sufficiently clear local victory/defeat remains a victory/defeat, even when some players left alive and exact team sizes are unknown.

A particularly important case: **our side stays alive and holds the location; the participating enemies are killed or dispersed; no one continues contesting the local fight; the confrontation ends. That is a Victory**. The player need not prove the fate of every previously seen enemy.

Do not treat *one* lost nameplate or the local player dropping combat as sufficient on its own. Consider the connected confrontation as a whole. We want a strong best-evidence result, not made-up certainty.

There is no general product requirement to always force a binary result. The aim is to make **clear outcomes correctly determined**, while reserving Unknown for genuinely indecisive or unobservable endings.

## 7. What the journal shows and counts

A skirmish report should tell the understandable story of the event:

- **Outcome:** Victory, Defeat, or Unknown.
- **Sides and roster:** observed Alliance and Horde participants, independently of party membership, with available appearance information.
- **Casualties:** only confirmed deaths; retreat, disappearance, or stealth is not a death marker.
- **Key events:** confirmed finishing blows, relevant deaths/revivals and other meaningful actions when available; not a noisy transcript of every spell.
- **Rewards:** earned Honorable Kills and Honor Points when reliably attributable to the fight. **A fight can exist without either reward**, including a legitimate PvP clash with an Unknown outcome.
- **When/where:** approximate time, zone, and location/waypoint if known.
- **Origin:** explicitly distinguish **Open World** from **Battleground** on saved skirmishes. For battleground skirmishes, show a compact localized **Battleground** label or badge immediately beside the battleground/zone name on **both compact and expanded cards**. The location name alone is not the indicator; the provenance remains visible even if the location text is unfamiliar or localized.
- **Coverage:** distinguish observed participants from a certified complete roster.

For rivalry statistics, one recorded skirmish can count once as a side Victory or Defeat against each **confirmed opposing participant** associated with it; Unknown contributes to fight history but not either win/loss counter. Open-world and enabled battleground encounters feed the **same rival history**; their origin is recorded on each encounter. Rewards are a separate concept, not proof of victory or who delivered a finishing blow.

Do not quietly omit a demonstrated healer simply because the local character landed all finishing blows.

### History retention

**Permanent Battle History** retains every rival and skirmish indefinitely.
It includes time, place, sides, outcome, confirmed kills, deaths and
revivals, rewards, the core timeline, and the accepted Damage Meter
aggregates saved with the skirmish. There is no automatic age, count or
byte quota for this history. The cross-rival view displays the latest 100
entries. An individual rival's history includes every linked encounter.

**Debug Evidence** covers API samples, repeated readings, rejection reasons
and meter session diagnostics. It can be compacted or cleared. The core
timeline and saved damage, healing and absorb amounts remain available for
future timeline views. A user's explicit reset or profile deletion follows
the existing confirmation flow.

## 8. Real encounter: Duskwood, 22 November 2026

The motivating case is an open-world PvP clash entered while fighting was already underway. The saved card currently presents **1 vs 2, Unknown** because it captured only the local hunter and two enemies she finished.

The diagnostic observations support a larger picture:

- **Alliance:** the local hunter, plus a priest who was in the party and demonstrably acted in combat.
- **Horde:** two opponents with confirmed deaths, plus a third hostile player who attacked participants but whose death is not confirmed.
- At least one additional friendly player was seen around the period, but an appearance near the fight alone is not evidence that they participated. Do not add them without a qualifying link.
- Other players could have fought before the hunter arrived, but unavailable pre-arrival history must not be invented.

**Expected product result:** record at least **two observed Alliance participants and three observed Horde participants** with their available character details, exactly two confirmed enemy deaths, and a **Victory** if the recorded confrontation resolves with Alliance remaining and the opposing force dispersed. The full historical roster may still be incomplete.

The old **Unknown** is not acceptable *merely because* the third enemy was last seen alive or the observed roster was incomplete. This example must become a regression/acceptance scenario when implementation is undertaken.

## 9. Acceptance scenarios

1. **Ordinary duel:** two players fight; one side wins. Save 1 vs 1 and the correct side result.
2. **Group fight:** every observed damage dealer, victim, and support player involved in the connected fight is represented, regardless of who landed the final blows.
3. **Unpartied allies:** friendly players in different parties fighting the same opponents belong on the same side.
4. **Healer only:** a priest who heals or shields a participant, with zero damage dealt, is included.
5. **Pet sent from range:** the hunter may enter the engagement before either health damage or visible nameplates; the pet is not a separate roster player. If nothing ever connects, don't invent a completed fight.
6. **Late arrival:** an existing fight is joined midway; retain known earlier participants and observations.
7. **Unobserved earlier deaths:** do not invent dead players who were never identifiable to the local character.
8. **Bystander and party member:** presence, party membership, targeting, or an unrelated NPC fight alone do not qualify.
9. **Enemy retreats alive:** enemy remains in the roster without a death marker; our side can win if it drives them off.
10. **Local player dies, allies win:** record a side Victory, not an automatic personal Defeat.
11. **Local player survives, allies lose:** record a side Defeat.
12. **Short pause or temporary stealth:** do not split a continuing engagement into multiple records.
13. **Separate nearby clashes:** do not merge separate fights simply because their time or location overlaps.
14. **Mutual disengagement:** retain the fight with an Unknown result and no invented rewards; do not count it as a win or loss.
15. **No rewards:** a confirmed meaningful skirmish with zero HKs or Honor Points still belongs in history.
16. **Duskwood reference:** reconstruct observed 2 vs 3 participation, two confirmed deaths, and Victory when the opposing force has dispersed and Alliance holds the field.
17. **Battleground enabled (default):** a real connected local battleground fight is saved as its own skirmish, with the **Battleground** context label by the location on compact and expanded cards; the match as a whole is not incorrectly treated as one giant fight.
18. **Battleground recording disabled:** no new BG skirmishes, kills, deaths, rewards or BG-driven score changes; previously known enemies still show historical win/loss indicators in nameplates and tooltips, using the separate existing visibility settings. Open-world tracking continues.
19. **Battleground vs match outcome:** win an objective-area clash and later lose the match; the clash retains its **Victory**, without importing the match's **Defeat**.
20. **Distinct battleground clashes:** die or disengage, later respawn or travel to a different fight; do not merge unrelated encounters because they share a BG instance.
21. **Cross-context rival:** face an opponent on a BG and meet them later in the open world; both recorded encounters appear under **one rival profile**, each with the correct context.
22. **Known rival on BG, recording OFF:** defeat a mage in the open world, then encounter the same mage on a BG with BG tracking disabled. Show the saved score in the mage's tooltip and nameplate, but do not add BG results or rewards to the journal.
23. **Independent display settings:** disable nameplate icons while BG recording stays ON; BG fights are still recorded and unit tooltips can still show known rivals if their separate switch is enabled.
24. **BG unresolved fight:** a genuine clash with no clear winner, no kills, and no honor stays in history as **Unknown**.

## 10. Boundaries and follow-up work

- **Do not force battleground outcomes to equal match wins/losses.** The skirmish result always belongs to the local fight.
- **No manual editing of participants or outcomes** as part of this redesign. Do not create a correction UI just to avoid solving automatic inference.
- Existing manual-entry features are separate and are not implicitly removed by this specification.
- **Later, separately:** add a visible **Beta / Report a Problem** action directly within the journal, opening the project's GitHub Issues reporting path. Existing support in settings remains. Do not expose private saved-data logs automatically.
- This document is deliberately **product behavior, not implementation design**. The actual evidence sources, privacy/secret-value restrictions, fight correlation, timeouts, and event handling need their own technical design and in-client tests.
- Before changing behavior, reconcile the current README and code, which describe a narrower kill-led/roster-elimination model. This specification describes the desired replacement, not the current shipping behavior.

---

**Guiding principle:** **Record the local fight that actually happened, in the open world or on an enabled battleground. Show as many genuine participants as can be observed. Award victory for a won confrontation, not only for exterminating every opponent. Keep Unknown for genuinely uncertain outcomes—not as a substitute for recognizing a clear win.**
