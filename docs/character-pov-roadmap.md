# Character POV — milestone roadmap

**Status:** Proposed high-level work plan, 24 November 2026. The Character POV
product direction is already owner-approved in [the product specification](skirmish-product-spec.md).
This roadmap organizes implementation; it does not approve unresolved scoring
rules, runtime changes, a release, or a final version number.

**Baseline:** GitHub v1.1.0, with permanent battle history, automatic diagnostics,
in-game issue reporting, and the existing side-outcome scoring model. The
new milestone is a semantic redesign, not a rewrite of the whole addon.

**Working title:** Character POV. Consider 2.0.0 because the meaning of rival
wins/losses changes; decide the release number with the owner before publishing.
No deadline is committed. A fast iteration is desirable, but client restrictions
and migration evidence determine readiness.

## Goal and release scope

Deliver an end-to-end character-centered journal:

- Primary skirmish result describes how the local character's participation
  ended, independently of the group ending.
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

## Step 0 — settle the narrow remaining product decisions

Before changing public counters, agree on:

1. **Counting unit:** recommended starting rule is one credit per rival per
   genuine death episode, deduplicated across observations, meter categories
   and reload/replay. A revival followed by another confirmed death is another
   episode. Keep this a proposal until accepted.
2. **Non-lethal rival outcomes:** recommended initial scope is death-linked
   contribution credit only. A clear non-lethal retreat can still determine
   the primary skirmish outcome. Separate opponent-specific non-lethal score
   rules can follow later.
3. **Legacy/manual display:** retain explicit historical/manual outcomes, label
   old side scores separately where needed, and do not turn an old side win
   into a new contribution win without supporting evidence. Decide concise
   user-facing labels and treatment of unprovable old credits.
4. **Evidence boundary:** agree what makes participation in a particular
   death episode sufficiently linked. Start with accepted same-episode direct
   damage, relevant hostile actions and support of a qualifying fighting ally.
   A broad session total may span multiple lives; do not infer per-hit timing
   or attribute unrelated opponents. No arbitrary damage threshold or healer
   penalty. Incomplete coverage is possible.

The spec already resolves terminal death, revival/return, retreat, group
context, BG scope, permanent history and support eligibility. Do not reopen
those decisions unnecessarily. Capture any newly settled semantics in the
spec and project context before assigning implementation.

## Implementation PR A — Personal outcome and participation boundaries

**Objective:** build an independent personal-outcome evaluator alongside
the current group/legacy outcome. Reuse the existing roster, segments,
life events, contact evidence and outcome-reason machinery.

Inspect Ledger.lua, WorldSkirmishes.lua, SkirmishOutcomes.lua and existing
fixtures before deciding exact storage and function names.

- Introduce a versioned, separate result/reason/coverage contract for personal
  participation. Retain old side results rather than overwrite them.
- Handle terminal PvP death, return to the same battle, unrelated new fight,
  forced withdrawal, local victory and genuine Unknown.
- Use corroborated evidence for observed defeat/retreat without demanding
  a perfect site anchor or complete roster. Feign Death, token identity,
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
  aliases, paging, report size bounds and optional SavedVariables instructions.
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
- Only after separate owner authorization, choose version, update changelog
  and listing copy, build verified ZIP, publish tag/GitHub Release and verify
  CurseForge separately. Do not assume a publisher exists just because 1.1.0
  was released; the temporary 1.1.0 workflow was removed.

## Agent workflow

Use one coherent task per PR, preferably a fresh Codex session per task.
Read AGENTS.md, PROJECT_CONTEXT.md, the relevant product specification and
validation evidence, current main and tests. Give the agent the specific PR
objective and acceptance cases, not the full historical chat.

Each implementation PR should report: changes, tests, actual evidence,
limitations, migration impact, and what remains. Product partner reviews
the exact diff and CI before squash merge. Reconcile project documentation
with accepted findings immediately. Start the next dependent task from the
latest accepted main; avoid parallel changes to shared scoring/storage
contracts. Independent fixture preparation may be parallelized only if
it does not create conflicting changes.

No release or runtime implementation is authorized by this proposed
roadmap alone. Next discussion: settle step 0, then authorize the first
implementation task.
