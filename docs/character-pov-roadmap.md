# Character POV — milestone roadmap

**Status:** Character POV is accepted and [2.0.0 is published on GitHub](https://github.com/nick-sidorin/names-in-red/releases/tag/v2.0.0).
PR #50 squash-merged at `a58fccad`; published tag `89ba7eb` has the identical
runtime and current owner-only workflow. Issues #47 and #49 are closed.
CurseForge public availability remains unverified. Next: existing-product polish.

**Baseline:** GitHub v1.1.0, with permanent battle history, automatic diagnostics,
in-game issue reporting, and the existing side-outcome scoring model. The
new milestone is a semantic redesign, not a rewrite of the whole addon.

**Release:** 2.0.0 — Character POV, reflecting the new rival score semantics.
No deadline is committed. A fast iteration is desirable, but client restrictions
and migration evidence determine readiness.

## Goal and release scope

Deliver an end-to-end character-centered journal:

- Primary skirmish result uses the approved observed-resolution / terminal-death
  / casualty-balance priority order. Draw is a normal final result, Unknown
  exceptional, In progress a separate lifecycle state.
- Personal rival score credits demonstrated participation in defeating a
  particular rival, including damage, control, pets and meaningful linked
  healing/support. No last-hit requirement and no blanket roster-wide credit.
  Rival loss attribution follows the same evidence-based principle.
- Literal killing blows/deaths, game-awarded HKs/honor and optional observed
  group context remain distinct.
- Old and new history remains readable and permanent. Preserve recorded facts,
  existing reward totals, settings and legacy semantics. New derivations are
  versioned and explainable; do not fabricate missing historical evidence.
- Cards, profiles, nameplates, tooltips and reports agree on the new meanings.
  Reuse the existing native UI, evidence collection and regression suite.

Not required for this milestone: full timeline viewer, peer synchronization,
formal duels, ranks/achievements, general-history pagination, manual correction
UI, unrelated interface redesign, or a replacement combat-log collector.
See [future ideas](future-ideas.md).

## Step 0 — completed product decisions

The owner approved all five proposed rival-score rules on 24 November:

- One credit per rival per genuine death episode, per direction, including
  repeat deaths after revival. No double count from replay or overlapping signals.
- Non-lethal endings use the approved outcome rules, but do not give
  rival credit in this milestone.
- Preserve original historical outcomes; recompute only from supported evidence.
- A confirmed death and linked contribution suffice even without a known finisher.
- Link healing/support to the relevant ally/opponent episode, not every enemy.
  Likewise all three enemies who contributed damage to our lethal episode
  receive a rival loss, even though the skirmish has one final personal result.

The owner also clarified settling/continuation, real return after revival,
crossing zone borders, unrelated later PvE and a distinct later revenge fight. These are now in the product spec.
Do not choose a timeout from the five-minute revenge example.

The owner approved proceeding with the hybrid contract in spec section 6:
corroborated decisive elimination first (mutual elimination is Draw),
terminal personal death with lost observation before a reliable ending
second, and casualty comparison for observed non-elimination endings third.
A dead solo player who killed two of three enemies still loses; a dead player
who observes surviving allies eliminate the opposition can win. Ordinary
zero/equal-loss endings are Draw. Genuine insufficient evidence is exceptional
Unknown, not a lifecycle state. Preserve reasons and coverage independently.
No more product checkpoint is required before PR A. Discuss genuinely new
edge cases as they emerge; exact timers, evidence predicates and storage/UI
contracts are implementation design. Preserve original historical facts.

Before runtime work, follow [engineering best practices](best-practices.md).
Have the first fresh developer session (or the existing Codex session if
still accessible) reconcile any missing prior technical lessons into the
best-practices/validation documents; this is a focused onboarding review,
not a new requirement to redesign the entire addon.

## Implementation PR A — Personal outcome and participation boundaries

**Objective:** build an independent personal-outcome evaluator alongside
the current group/legacy outcome. Reuse the existing roster, segments,
life events, contact evidence and outcome-reason machinery.

Inspect Ledger.lua, WorldSkirmishes.lua, SkirmishOutcomes.lua and existing
fixtures before deciding exact storage and function names.

- Introduce a versioned, separate result/reason/coverage contract for personal
  participation. Retain old side results rather than overwrite them.
- Implement the approved section 6 priority order, including Draw and
  exceptional Unknown. Separate lifecycle, actual observation boundary and
  final result. Handle death, spirit release, revival/return, quiet intervals,
  late evidence, ordinary zone borders, unrelated PvE and later revenge.
  Reuse or revise existing timers based on evidence; document chosen values.
- Use corroborated evidence for decisive elimination and observed endings
  without demanding a perfect site anchor or complete roster. Do not infer
  territory control or forced retreat as outcomes. Feign Death, token identity,
  NPC-only deaths and missing fields remain meaningful safeguards.
- Add focused tests for world:7 and world:14 terminal deaths, world:12,
  death/revival, world:4 and Duskwood evidence, non-lethal disengagement,
  mixed PvE/PvP, and BG boundaries. Do not hard-code fixture IDs.
- Keep existing public score/UI behavior while the new data/evaluator is
  being introduced, unless the integration is explicitly combined with PR C.

**Done:** independent personal results can be evaluated and retained;
the previous group/legacy information and all original facts survive.
Explain any old fixture whose evidence still cannot establish a victory.

## Implementation PR B — Rival contribution credit

**Depends on:** the agreed scoring contract and PR A's episode/boundary model.

**Objective:** independently derive which rivals the local character helped
defeat and which rivals demonstrably contributed to the local death.

Inspect Ledger.lua, SkirmishEvidence.lua, Debug.lua, Kills.lua, Deaths.lua,
CombatDiagnostics.lua and the permanently saved accepted meter links/amounts.

- Reuse already available accepted actor/target links, confirmed death events,
  relevant actions and meter aggregates. Promote the minimum necessary
  durable attribution evidence before technical diagnostic pruning.
- Credit direct and assisted damage, healer-only participation, relevant
  protection/control and known pet ownership when linked to the episode.
- Keep actual finishing blows, participation credit, HKs and honor separate.
  Do not turn membership, unrelated heals, unknown endpoints or global totals
  into credit. Do not assume an aggregate read time is a hit time.
- Deduplicate repeat signals and overlapping categories; retain real repeated
  defeats across revivals according to the agreed counting unit.
- Test mage/brother last-hit and pure-healer cases, opposing assists, mixed
  rival win/loss, unrelated nearby fights, multiple opponents and life
  episodes, restricted endpoints, reload and diagnostic compaction.

**Done:** each credited result has a traceable rival and defeat episode;
the new score can be queried independently of the skirmish/group result.
If current Forever evidence cannot establish a link, record the limitation
and avoid inventing an attribution. Do not rewrite the collector just to
manufacture perfect coverage.

## Implementation PR C — Integrate score, history, UI and report

**Depends on:** PR A and PR B. This is the user-facing activation point.

- Update Ledger indexes and the rival profile/compact cards, full journal
  cards, nameplates, tooltips and shared counters consistently.
- Put rival contribution behind a shared ledger index or invalidated cache
  before using it on nameplate and tooltip update paths. The shared index
  builds once per loaded ledger, replaces the affected battle on save,
  and serves per-rival totals for warm queries. Tests verify late evidence,
  deletion, reset and repeat reload on 1,050 battles. Permanent history
  and the latest-100 presentation limit retain their separate scopes.
- Full card: primary personal outcome. Rival card: rival-specific credit,
  including both directions if applicable; no misleading blanket group
  badge. Optional observed group outcome is secondary. Do not require a new
  group-outcome UI if existing context can be kept without confusion.
- Migrate old SavedVariables additively and idempotently. Re-evaluate only
  when retained evidence warrants it, preserve original legacy/manual data,
  and label unsupported old semantics accurately. No reset, no silent
  deletion, no invented old credit. Preserve honor/HKs and BG/display settings.
- Extend issue reports with versioned personal outcome and credit rationale,
  missing/partial evidence and group context when available. Preserve stable
  aliases, one copyable report, explicit export limits and optional SavedVariables instructions.
- Keep Blizzard-native look, use existing assets/templates, localize changed
  UI across all supported locales, and update product-facing text only when
  corresponding behavior is actually delivered.
- Replay old fixtures and representative old saves, including long history
  (more than 100 records) and reload after diagnostic pruning.

**Done:** the end-to-end journal conveys the same new semantics in every
view, without corrupting old data or regressing v1.1.0 behavior outside the
intended changes.

## Integration and release gate

After PR C, prepare one installable preview of the entire milestone.

- Run the existing bash scripts/check.sh plus new focused tests and CI on
  exact PR heads and the integrated main. Keep all prior regressions.
- Validate a copy of actual older SavedVariables, migration twice, old
  rival/history access, retained rewards and no duplicate score.
- Smoke test in Forever: open journal/profile/full/compact card, tooltip,
  nameplate and issue report, reload, and inspect a fresh normal PvP event
  when available. A controlled assist/healer case is valuable if feasible;
  distinguish real client checks from fixture tests. Do not require the
  owner to recreate every historical edge case. No promise of complete
  combat evidence in every API-restricted situation.
- Review observed Unknown cases for meaningful personal reasons rather than
  missing optional global evidence. Do not use an arbitrary target win rate.
- Check runtime size/performance and report data retention against the existing
  limits; no new quota on permanent history.
- Resolve actual release blockers; put non-blocking improvements into
  future ideas or follow-up issues rather than extend the milestone.
- Prepare the approved version, changelog, listing copy and reviewed
  publisher in a release PR. Start the permanent owner-only publisher via
  a request-only PR, main dispatch, or stable tag only after final owner
  approval. GitHub and CurseForge publication are checked independently.
  The GitHub publisher builds from the exact tag. CurseForge uses the
  existing source packager and `.pkgmeta`.

### 2.0.0 gate status

- Merged main `9b6876bd314d36f3336d18402160444fec6c555b` passed
  [GitHub Checks](https://github.com/nick-sidorin/names-in-red/actions/runs/45654965236).
- The owner accepted restored world:16 and world:19–21 outcomes, roster,
  score and reload on preview `22fada7`. The owner confirmed recovered
  world:22–24 history in Forever on `218f1b1`. The release replay uses copies
  of the original SavedVariables with repeat loads and checks direct stats,
  separate awards and durable history.
- The suite covers legacy and manual entries, 1,050-battle score indexing,
  diagnostic compaction, localization and all existing combat replays.
  CI checks the package manifest and versions in addition to the installable
  feature preview.
- Issue #49's private save reproduces a missing fight on the previous
  release-preparation build. Replay on the repaired build restores a 2×1
  Victory, one rival win and 1 HK / 4 honor on both the card and rival profile.
  Older preview cards reclassify verified awards in place. The indexed result
  survives repeat loads and removal prevents recovery from replaying it.
  [Outgoing-only recovery](forever-validation.md#outgoing-only-aid-in-forever-71091)
- The owner verified the restored card and compact report in Forever on
  `6961d33`. The owner confirmed the corrected rival profile on `b7870aa`.
  The original card has no captured map position. Both exact-head Checks
  passed, including independent byte-identical ZIP builds. The owner authorized
  publication; separate reload of the final preview was not explicitly reported.
  Post-release polish is tracked in the product spec; larger ideas are deferred.

### Non-blocking live follow-ups

- Verify a fresh group fight with a healer, late join or overlapping
  combat windows. Available reports and raw samples vary by combat and
  restrict which supporting players can be credited.
- Verify a readable hostile pet-owner token during Death Recap across the
  post-combat retries. Unknown owner stays valid when the native identity
  read is absent, secret or ambiguous.
- Verify rare return-after-revival and true battleground reset boundaries
  when they are observed. Vary active observation and client restrictions.
  Keep the existing replay fixtures as the regression baseline.

## Agent workflow

Use one coherent task per PR, preferably a fresh Codex session per task.
Read AGENTS.md, PROJECT_CONTEXT.md, the relevant product specification and
validation evidence, current main and tests. Give the agent the specific PR
objective and acceptance cases, not the full historical chat.

Each implementation PR must read and apply the engineering best practices,
run the relevant pre-PR/pre-merge checklist, and record newly learned durable
technical conventions in the same PR (especially owner-requested corrections).
Each implementation PR should report: changes, tests, actual evidence,
limitations, migration impact, and what remains. Product partner reviews
the exact diff and CI before squash merge. Reconcile project documentation
with accepted findings immediately. Start the next dependent task from the
latest accepted main; avoid parallel changes to shared scoring/storage
contracts. Independent fixture preparation may be parallelized only if
it does not create conflicting changes.

Owner acceptance of preview `22fada7` covered the restored world:19–21
rosters and victories, rival scores, world:16 Defeat and persistence after
reload. The owner also confirmed the world:22–24 recovery in the Forever
preview `218f1b1`. Fresh group encounters and live pet-owner attribution
remain useful follow-ups. The owner accepts shipping a completed milestone
while uncommon live scenarios are still unobserved. Data integrity,
stability, core behavior, CI and installable-package checks stay part of the
release gate.
[PR C acceptance](https://github.com/nick-sidorin/names-in-red/pull/45#pullrequestreview-6060358381) ·
[Control-gap validation](forever-validation.md#control-gap-replay-world2324)
