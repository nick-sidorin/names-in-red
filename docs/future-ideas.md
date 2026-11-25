# Future ideas

This is a list of possible later enhancements, **not implemented features, approved
requirements, or a committed roadmap**. The agreed core skirmish behavior belongs
in the [PvP skirmish product specification](skirmish-product-spec.md), not here.

## PvP progression

Add optional long-term goals to the existing personal rival journal. The idea
is to reward continued PvP activity without replacing the record of individual
skirmishes or changing how their outcomes are determined.

### Achievements

Possible milestones:

- Earn the first **Honorable Kill**.
- Defeat a chosen number of **distinct rivals**.
- Reach a lifetime amount of **Honor Points earned**.

These are examples, not a finalized list of achievements or thresholds.

### Ranks

Consider a progression system with ranks and milestones based on some or all of
three distinct signals:

- **Honor earned:** points actually awarded to the character.
- **Honorable Kills:** kills credited by the game.
- **Skirmishes won:** local confrontations won by the character from their own POV, as
  defined in the [product specification](skirmish-product-spec.md), rather than
  personal finishing blows or the final result of a battleground match.

The progression metric, rank names/artwork, thresholds, repeat-rival rules, and
relative weight of each signal are **undecided**. Avoid automatically stacking
several progress rewards for the same event without an explicit design decision.
Unknown-outcome skirmishes must not be counted as wins.

If progression eventually supports both open-world and battleground records,
decide how the optional **Track Battleground Skirmishes** recording switch
affects the progression source data. Do not invent unrecorded BG rewards or
retroactively change score semantics.

## Duel history

Consider a **dedicated history of formal in-game duels** (the game's duel
challenge mechanic), including friendly duels with characters of the same
faction. Duels should not be confused with a spontaneous open-world **1 vs 1
PvP skirmish**.

Possible information to remember:

- Opponent's identity and available character details.
- Date and place of the duel.
- Win or loss, or an inconclusive result when a duel ends without reliable
  outcome evidence.
- A chronological history and per-opponent duel record, so a familiar sparring
  partner can be recognized on a later meeting.

How a duel begins/ends, how a forfeited or interrupted duel is classified,
whether duel results share the main rival profile or have a separate section,
and which in-game signals can reliably support this on WoW Forever are **open
design and feasibility questions**.

A duel must not automatically be counted as a normal faction skirmish,
Honorable Kill, Honor Points award, or ordinary open-world PvP victory. This
feature is an optional future idea, **not** part of the currently agreed
skirmish redesign.

## Target-frame rival indicator

An early concept, not yet part of the implemented UI: show a small, restrained
history badge or strip beside Blizzard's existing **target frame** when the
selected opposing player is an already recognized rival.

- Use the same trustworthy opponent identity and historical score as the
  tooltip/nameplate indicators.
- Preserve Blizzard's original target frame, functionality, and combat safety.
- Hide the badge for unrelated or unidentified targets.
- Keep the native Warcraft visual language; avoid unnecessary explanatory text.

The precise placement, whether it adds enough value beyond the existing
tooltip and nameplate display, and how it should be configured are **open**.
Do not treat it as required for the current skirmish redesign.

## Detailed combat timeline

Consider a chronological viewer for permanent battle history: observed casts,
damage/healing/absorbs where readable, death and revival, participation and
contribution, plus separate Damage Meter aggregates. Distinguish true event
times from snapshot receipt and never manufacture individual hits. No full
combat-log API or external file logging dependency.

## Optional cooperative observation

Explore a consenting friend's or party member's addon-to-addon observations
through permitted Forever addon messages. Research client restrictions and
explicit opt-in, provenance, duplicate/overlap handling and conflicts. This
may improve coverage after one character loses sight of a fight, but must
not be required to record or evaluate a solo character's story. No opponent
installation requirement; no current implementation commitment.

## Target portrait context menu

Consider a native target portrait right-click menu section labeled **Names in Red**, with an **Open statistics** action when the currently targeted character has a known profile. Open the journal directly with that character selected. Initially this can use the existing rival database; later it could support ally profiles too. Research Forever's native unit menu extension and combat safety before design/implementation. Do not expose the action for an unidentified or unknown profile. This is a deferred idea, not part of the post-2.0.0 polish.

## Ally history

Consider remembering allied players as well as opposing rivals, with separate lists and profiles. Possible ally-specific statistics: shared skirmishes, shared victories and shared defeats; distinct iconography. Do not copy enemy-rival honor/HK counters or personal adversarial score into ally profiles. Decide exact participation, win/loss semantics, identity, storage, navigation and artwork later. This is exploratory and deferred until the existing product is polished.
