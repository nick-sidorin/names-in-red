# Names in Red — Engineering best practices

**Mandatory project-local conventions.** Read this with [AGENTS.md](../AGENTS.md),
[shared WoW Addon Standards](standards/AGENTS.md), [field notes](standards/FIELD_NOTES.md),
[product specification](skirmish-product-spec.md) and
[Forever validation](forever-validation.md). This is a living implementation
contract, not a replacement for the pinned standards or a list of cosmetic
suggestions. The owner has repeatedly corrected the same UI and component
mistakes in past Codex sessions; prevent their recurrence in every new session.

## 1. Native-first workflow: reproduce the reference, not a visual approximation

When the owner names a Blizzard window, widget or interaction as a reference,
**inspect the actual matching Forever client source before writing code**.
Screenshot resemblance alone is not sufficient.

1. Identify the exact client build, native window/addon, XML template,
   inheritance, mixins, Lua call path, load-on-demand dependencies and relevant
   client-specific overrides. The project targets Forever 1.60.1 / 16001 /
   Lua 5.1, not arbitrary Retail or Classic.
2. Inspect the authored layout: frame size, anchors, margins, gaps, row height,
   scroll gutters, fonts, art dimensions, masks, texcoords, draw layer and
   sublevel, colors, selection/hover/pressed/disabled states, sounds, tooltips,
   visibility, z-order and input behavior. Record the exact source path and
   symbol or permalink. Reuse the same permitted native widget/template and
   geometry whenever it fits addon-owned data.
3. Preserve native behavior, not only appearance. For custom data, adapt the
   minimal necessary parts of the native pattern within addon-owned frames.
   Respect applicable source/asset licenses. Do not blindly copy protected
   handlers or calls requiring real recipe/item/player data, mutate Blizzard
   pools/caches, or introduce taint. A registered template can be forbidden;
   a successful pcall is not proof of permission or taint safety.
4. If reuse is unsafe or unavailable, document the precise reason, use native
   art/geometry and minimal addon-owned fallback, and test it. Do not create
   custom widgets as the default. Do not guess values merely to pass a visual
   review. Use the reference as a source of truth; compare in the client when
   the change is visual or behavior depends on native UI.
5. Keep explanatory labels concise, use tooltips for detail when appropriate,
   and preserve the owner's immersive Warcraft visual language.

## 2. Established native patterns and local implementations

Use the following as the first lookup, not as universal template mandates.
See the detailed source references and live-test limits in
[Forever validation](forever-validation.md). Re-inspect exact current source
if a reference or target build changes.

| Area | Existing reference / project implementation | Convention |
| --- | --- | --- |
| Modern text buttons | `SharedButtonSmallTemplate`, `128-RedButton` three-slice art, `SetTextToFit`; Book.lua header/add, IssueReport.lua footer, ManualDialog.lua add/cancel. PR #31 corrected report-button template. | Use the native height and state art for equivalent modern actions. Refit labels that change at runtime, including localized state labels. Keep adjacent actions in one control family. |
| Other controls | EncounterCards.lua uses `CommonSquareIconButtonTemplate` for compact actions; Back in Book.lua follows `UIPanelButtonTemplate` from the professions crafter order reference. | Choose the actual reference-specific control; no blanket replacement of every old-named template. Explain exceptions. |
| Journal window and layout | Book.lua: `PortraitFrameTemplate`, Camelot ProfessionsFrame/ProfessionsCrafting, `Profession-Background-Overview`, `Profession-Background-Template2`, `Professions-background-summarylist`, `LargeSideTabButtonTemplate`, `PanelTopTabButtonTemplate`. | Retain the professions reference's authored geometry, tab anchors, list/detail relationship, padding and continuous background; use native components first. |
| Profession rows and statistics | RivalList.lua: `ProfessionsRecipeListRecipeTemplate` with safe handling of handlers that need recipe IDs. Book.lua: `ProfessionsReagentSlotBaseTemplate`, its intrinsic ItemButton mask/layers, `Professions-Slot-bg`, `Professions-Slot-Frame` fallback. | Reuse native reagent/recipe layouts and actual spacing, label anchors and selection art. Don't invent another card/slot style. |
| Character portraits and framed icons | Portraits.lua: `addon.CreateParticipantPortrait(parent, options)`, shared mask/rim/badge helpers and `addon.CreateFramedMarker`; used by Book.lua and EncounterCards.lua. | Share the profile portrait and level badge dimensions, font and frame across both skirmish layouts. Keep side-facing and class, level and casualty states in the shared widget. Use the reusable options for genuine differences in other contexts. |
| Window ordering | Book.lua: independent movable top-level `MEDIUM` frame, `SetToplevel(true)`, `Raise()` on show, native close/Escape via UISpecialFrames. | Main windows must coexist and raise naturally like native panels; a permanent DIALOG stratum can prevent ordinary panels rising above them. Genuine dialogs may have different ordering, e.g. existing IssueReport.lua. Check overlap, clicking, dragging, close/Escape and focus. Don't add all windows to a protected native manager blindly. |
| Sounds | ProfessionsMixin:OnShow/OnHide in the matching Camelot/shared source; Book.lua uses `SOUNDKIT.UI_PROFESSIONS_WINDOW_OPEN` and `UI_PROFESSIONS_WINDOW_CLOSE`. | Match the reference's sounds on equivalent actions (open/close, tabs, buttons, selection where the native reference actually plays them). Inspect native inherited handlers to avoid duplicate playback. Play once per actual transition, not on redundant Show/Hide or refresh. |
| Minimap | Book.lua shortcut follows Azeroth Fitness Shortcut:Init; `MiniMap-TrackingBorder`, `UI-Minimap-Background`, circle mask, native highlight, stored angle and size-change positioning. | Center artwork in the visible opening, not blindly in the full texture. Preserve drag and left/right-click meanings, tooltip anchoring, scale and position persistence. |
| Issue report | IssueReport.lua: `PortraitFrameTemplate`, `InputBoxTemplate`, `InputScrollFrameTemplate`, one Select Report button and one scroll field. | Keep native selection, scrolling, focus and close behavior. Preserve the public-sharing warning. |

### Geometry and icon centering

Do not fix perceived misalignment by scattering magic offsets across callers.
Check native atlas dimensions and padding, texture-local coordinates, mask/rim
geometry, visible painted area and effective UI scale. Keep the same canonical
crop/geometry for the same component; intentional artwork-specific crop offsets
belong at a shared owner with a reason, not repeated by screen.

Prior research: the minimap border's visible opening is near (20, 19.5) in its
64×64 source; the current icon/crop and the First Aid/Linen/Wool reference
comparison are documented under the icon and window sections of Forever
validation. The numbers are evidence for those assets, not general constants
for other frames. Use `/nirdebug icons` if still supported on the target build
to compare the same frame with native reference art; check both normal and
reduced UI scales. Region bounds include transparent padding and do not prove
optical centering. Preserve the original source reference and visually verify.

When a pane grows, inspect native artwork coordinates separately from layout
coordinates. Keep an authored header band or seam visible, preserve the
visible gap beneath section headings, and measure it to the painted button
edge. Match both the Information and History surfaces with empty panes before
comparing content. For replacement bitmaps, compare the established asset
encoding and orientation as well as the decoded image. See the
[profession and art checks](forever-validation.md#skirmish-cards-and-the-world-map).

### Input ownership and cleanup

Use `UISpecialFrames` and the native close callback for addon-owned portrait
windows. Limit window dragging to its title region, outside title-bar controls.
End dragging on mouse release and hide. Clear focus, addon-owned popups and
tooltips where the owning surface hides or is recycled. A modal with native
autocomplete gives Enter and Escape to the suggestion list first, then acts
on the dialog if the list did not consume the key. See the
[window lifecycle checks](forever-validation.md#window-ordering-sounds-and-minimap-hint).

Keep report selection independent of viewport height. When resizing an
anchored `InputScrollFrameTemplate`, check the multiline EditBox width as
well, and exercise selection on every report part. Keep long paths and
localized prose readable and retain native focus and scrolling. See the
[report dialog checks](forever-validation.md#public-issue-reports).

## 3. One reusable component, many configurations

Search existing local code before creating any widget/helper or calculating
a score. A repeated element that must look or behave consistently must have
one implementation. This includes portraits, badges, result markers, counters,
card actions, common framing, icon placement, and the shared score projection
used by cards, profile, tooltip and nameplate.

- Put shared geometry, artwork, layout, state transitions and lifecycle in the
  canonical constructor/updater. Pass explicit parameters (size, facing,
  show/hide level, class, casualty or revived state) and data to the component.
  Do not fork just because a caller needs a different option.
- Preserve native template behavior through safe composition, rather than
  replacing inherited scripts without checking them. Use small helpers and
  reuse only meaningful shared behavior; avoid speculative frameworks.
- When a common spacing/state/visual rule changes, review all consumers.
  Changing a portrait offset once should fix every equivalent portrait.
- Before PR, search for repeated constructors, masks, atlas/anchor constants,
  duplicated scoring or life-state projections, and near-copy-pasted handlers.
  Consolidate accidental duplicates touched by the change; document any
  intentionally distinct variants. Do not trigger an unrelated mass refactor.
- Use native asset reuse rather than unnecessary custom artwork. Preserve
  semantic differences (confirmed skull level vs death skull, unknown level,
  revived portrait, real finishing blow vs participation credit).

## 4. API and evidence conventions

- Export one pseudonymized JSONL block with a native full-text selection.
  Distinguish the submission service's body limit from the EditBox viewport
  and clipboard behavior. Measure widget storage by reading the text back.
  If an export must fit a verified bound, preserve core facts and the most
  useful evidence first. Emit complete rows and label every shortened section
  separately from capture omissions. Keep attaching SavedVariables optional.
  [Transport and native behavior](forever-validation.md#public-issue-reports)

- Match Forever build/source and distinguish documented APIs, actual delivery,
  readable fields, test mocks and observed real-client behavior. For exact
  API research, record source/build/symbol and evidence in Forever validation.
- Use `issecretvalue` before value inspection. For a returned table, check
  `canaccesstable` when available before indexing or iterating it. Check
  each field again through `addon.Readable` or the existing typed diagnostic
  reader before comparison, arithmetic or serialization. Preserve separate
  absent, secret, restricted-table and error statuses where diagnostics need
  them. `pcall` catches call failures. Do not subscribe to blocked CLEU or
  attempt to bypass combat/taint restrictions.
- Reuse existing event/identity and meter qualification paths. A readable
  aggregate has no exact individual hit time; a cast success has no proven
  target or hit; a missing flag is not false. Validate actor/target, ownership,
  session, segment and life-episode scope. Reject stale/ambiguous signals.
- Promote accepted attribution links from the full, qualified read before
  diagnostic sampling drops rows. Keep direction, positive pair evidence,
  source ownership and window scope. For untimed support require an
  independently linked opponent of the recipient in the same life window.
  Multiple plausible opponent links leave the support unassigned.
- Confirm PvP death once per life before projecting casualties or rival
  attribution. A directed aggregate can corroborate a durable corpse only
  within an unambiguous, single-life window. Casualty totals count confirmed
  episodes independently of participant credits. Reconcile a partial native
  lethal recap by exact timestamp and owning record. A later validated native
  timestamp belongs to another episode even when revival was unobserved.
  For aggregate-only local deaths, require independent terminal evidence
  within the scoped life. Preserve positive NPC and environmental vetoes
  across retries and reload. A failed recap supplies no lethal attribution.
  Keep the terminal read in its owning combat segment when later samples
  replace skirmish-level assessment.
  Validate the derived timing bounds using the resolved offset. Retain an
  absent runtime field in an anonymized regression from a real save. Keep
  the literal pet finisher, verified owner and other recap attackers
  separate. Use only verified players as journal actors. Recheck a
  GUID-resolved pet token before and after reading ownership. Limit
  late attempts to the originating window and keep secret or absent API
  results distinct from contradictory owner claims. Defer owner-only
  roster admission until the skirmish closes so a revoked claim cannot
  create a rival. Keep independent participant evidence on its ordinary
  path. Append bounded probe statuses to the durable death even when a
  duplicate needs no outcome or score recalculation. Spell aggregates
  preserve participation evidence without assigning ownership.
  Recover diagnostic evidence only when a unique session, local
  death and combat window match. Attach it without rewriting the original
  timeline or requiring the diagnostic log on later loads.
- Treat a native `EnemyDamageTaken` no-spell row as a player-pair
  aggregate only when the readable complete source totals reconcile
  against same-selection GUID-keyed `DamageDone` and the full names are
  unique. Keep the proof on the literal window of the separately
  confirmed target. A shared session can cover another opposing player
  or predate local combat. For a longer session with late updates,
  require an isolated selection and independently observed combat and
  reciprocal damage for the joined pair. Keep this proof out of the
  passive strict-detail baseline. A brief generic ally combat flag
  alone cannot override a witnessed elimination.
- Preserve witnessed action times on both sides of a life transition. Per-pair
  first/last/count summaries alone can drop the only action that links an
  earlier corpse to PvP. Reconcile confirmed death and revival from readable,
  identity-checked samples into the life timeline as they arrive, including
  when no separate event fires. Keep the observed corpse, PvP linkage and
  attributed finishing blow distinct. Preserve window invalidation and the
  post-kill settling guard on both live capture and replay. See
  [Character POV PR A](forever-validation.md#character-pov-pr-a).
- Use product rules rather than incidental API flags for fight boundaries.
  Current short late-event/bridge/terminal timers are implementation details,
  not product constants. No infinite waits, raw uptime persisted as absolute
  time, or unbounded polling. Keep late evidence and ongoing participation
  distinct. A window-bound late read may enrich an earlier episode but its
  receipt must never refresh the continuation deadline. Use real recording
  scope and matched evidence across ordinary map/zone borders, and test those
  borders separately from loading, instance or match abandonment. Preserve
  old regressions and test reload and life-episode deduplication when relevant.
- Hold quiet finalization only for one already opened successor with a
  verified pursuit across the gap. Resolve it with hostility tied to the
  same pair and successor window. Bound the hold from capture and stop
  sampling the predecessor once the successor takes over observation.
  Recover split history only from uniquely matching captured windows
  and a documented premature boundary. Rebase battle-relative offsets
  from the original monotonic clocks and keep segment-relative data,
  native timestamps, death attribution and earned rewards intact.
- Preserve per-character history, old facts, explicit manual entries and
  earned rewards through additive, idempotent migrations. Age, count and
  byte budgets apply to temporary evidence. The recent-view limit applies
  at presentation. A future timeline must read permanent facts and linked
  aggregates from the saved fight. Promote old aggregates only from a
  uniquely matched accepted segment. Keep diagnostic reset, explicit data
  reset and stale callback invalidation separate. See the
  [retention and reset checks](forever-validation.md#permanent-battle-history).
  Preserve historical scores when BG recording is disabled.
- Put history-derived data queried by nameplates and tooltips behind one
  shared ledger index. Cache numeric per-battle deltas independently of the
  live record table so late in-place edits can replace an old contribution
  exactly once. Validate the number of computations in a long-history
  test after writes, deletes and rebuilds. Keep presentation and diagnostic
  limits out of permanent storage. See
  [Character POV PR C](forever-validation.md#character-pov-pr-c).
- Keep JSONL aliases, bounded exports and optional SavedVariables report path
  intact. No real private captures, secrets or unnecessary personal data in
  Git. In anonymous fixtures, redact identity values and preserve status
  enums even when they use the same field names.

## 5. Tests: behavior and regression, not implementation snapshots

The existing gate is `bash scripts/check.sh`: pinned standards verification,
manifest checks, Lua 5.1 syntax for runtime/tests, and suites for ledger,
outcomes, debug, kills, deaths, book, waypoints, nameplates, settings, world,
issue report, battlegrounds, Gnomeregan outcomes/world, combat diagnostics.
Update that entry point if new suites are added. Every runtime PR includes
meaningful tests for changed behavior, unless a concrete reason is stated
(e.g. purely authored visual placement that requires a client comparison).

- For a confirmed bug reproduce it with a focused fixture that fails before
  the fix when feasible. Add the regression to the same PR; don't merely
  assert that a particular new helper was called or mirror implementation.
- Cover happy path and relevant boundary/negative cases: missing/secret
  fields, stale or reused tokens, ordering/late events, independent fights,
  death/revival, reload/migration/deduplication, settings OFF, and permitted
  context (world/BG) as applicable. Reuse anonymized actual Gnomeregan/Duskwood
  evidence. No unrelated exhaustive test matrix for each tiny change.
- For UI logic test reusable component configuration and states, selection,
  layout relationships where meaningful, callbacks, focus/close, and
  localization completeness/placeholders. Mocks can verify logic and wiring,
  not actual pixels, native availability, sound audibility or absence of
  taint. Avoid brittle exact pixel snapshots for unverified geometry.
- For native UI appearance and UX changes, do a focused Forever comparison:
  reference window, normal/reduced scale, relevant enabled/disabled and
  selected/hover states, overlap and Escape, one correct sound per action.
  State which were tested by an agent/owner vs not tested. For runtime API
  changes smoke test relevant live behavior if feasible; do not make the
  owner repeat dozens of historical encounters. Preserve meaningful gaps as
  explicit limitations and release blockers when warranted.
- Run the full existing checks locally before submitting when a checkout is
  available. CI must pass on the exact final PR head. If local execution is
  unavailable, state that and use actual CI evidence; do not claim local tests.
  No bypasses, no fake test success, no merging a red runtime PR.

### Preview and release provenance

For a visual retest, link the GitHub Actions artifact from the exact head
that includes the approved UI changes. Stage the install folder from
the PR head tree even when the workflow checks out GitHub's merge commit to
test integration. Stamp the packaged TOC with the exact commit in
`X-Preview-Revision` so a report can identify the installed build without a
version bump. Verify the archive against the head and the expected stamp
before supplying it. Before publishing,
resolve the remote tag explicitly and verify the published asset against
the tagged files. Compare the public CurseForge file independently and
check pending automatic packaging before any manual upload. The
[preview and release incidents](forever-validation.md#preview-and-release-provenance)
record why these checks matter.

## 6. Living technical memory: learn from every durable correction

The owner does not want each fresh Codex agent to relearn the same lessons.
When the owner corrects an approach and says this is the standard for future
work, or implementation exposes a reusable technical pitfall, update this
document **in the same implementation PR** as the correction. Add a concise
normative rule and link evidence/example/code where useful. Reconcile prior
conflicting instructions rather than accumulate competing rules. Put detailed
build-specific evidence in Forever validation; this document stays practical
and prescriptive. Update project context for major state or architectural
changes; update product spec only for actual agreed product changes.

A one-off screen offset or tentative experiment is not automatically a
universal rule. Record scope, rationale and verification limits. If a lesson
may apply to other addons, propose it for the shared standards upstream
separately; do not edit pinned standards copies as a shortcut. No need to
ask again to document a settled correction. If no durable lesson emerged,
say so in the PR; no ritual edits.

## 7. Required pre-PR and pre-merge self-review

Run the relevant checks before opening/updating a PR; reviewer repeats them
on the exact final diff before merging. Mark not-applicable items with a
reason instead of claiming they were tested. A short evidence summary in
the PR is sufficient; no excessive paperwork.

- [ ] Read AGENTS.md, this document, shared standards, current context,
      relevant spec and validation. Verify current main/parallel work.
- [ ] Scope matches approved product behavior; no opportunistic changes.
- [ ] For native UI/UX changes: source file/template/mixin inspected first,
      native component/geometry/sounds reused; custom fallback justified.
- [ ] Shared components/helpers used; review all relevant consumers and
      duplicate implementations; no local fork of a common visual or score.
- [ ] API restriction, event/lifecycle, storage/migration and privacy
      safeguards handled where relevant.
- [ ] User-facing strings localized, layout/interaction/visual evidence
      described honestly; any required client smoke test identified.
- [ ] Focused regression and negative cases added where appropriate;
      existing suite and manifest/package checks pass.
- [ ] Durable new technical lesson/owner correction recorded in this same PR;
      related docs reconciled (or explicitly no new convention).
- [ ] Exact head CI green; scope/diff reviewed; branch protections respected;
      squash merge only as authorized. Separate release approval.

The checklist is an agent/reviewer working agreement, not a claim that CI
can mechanically verify these semantic or visual obligations. No new CI
enforcement mechanism or runtime change is introduced by this document.

## 8. Retrospective evidence limits

The 1.1.0 retrospective used the available conversation, checked-in source
and tests, repository history, owner screenshots and recorded client
findings, pinned Forever UI dumps, and published artifacts. Private Codex
sessions outside the available conversation were inaccessible. A source
match, a mock or a checked ZIP establishes only its own verification scope.
Use the [Forever validation notes](forever-validation.md) for concrete
examples and client checks still pending. Section 6 governs subsequent
corrections.
