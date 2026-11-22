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
- **Skirmishes won:** local confrontations won by the character's side, as
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
