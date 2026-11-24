# Names in Red — Engineering best practices

**Mandatory project-local conventions.** Read this with [AGENTS.md](../AGENTS.md),
[shared WoW Addon Standards](standards/AGENTS.md), [field notes](standards/FIELD_NOTES.md),
[product specification](skirmish-product-spec.md) and
[Forever validation](forever-validation.md). This is a living implementation
contract, not a replacement for the pinned standards or a list of cosmetic
suggestions. The owner has repeatedly corrected the same UI and component
mistakes in past Codex sessions; prevent their recurrence in every new session.

This initial edition (24 November 2026) records the owner's stated conventions
and cross-checks the existing code and validation notes. It is not a complete
audit of all private Codex chats. Add missing verified lessons from those
sessions or repository history in the relevant PR; don't invent old decisions.

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
| Modern text buttons | `SharedButtonSmallTemplate`, `128-RedButton` three-slice art, `SetTextToFit`; Book.lua header/add, IssueReport.lua footer, ManualDialog.lua add/cancel. PR #31 corrected report-button template. | New equivalent modern red buttons use this native path, including hover/pressed/disabled states and localized text sizing. Do not regress to older button art just because it is easy to instantiate. |
| Other controls | EncounterCards.lua uses `CommonSquareIconButtonTemplate` for compact actions; Back in Book.lua follows `UIPanelButtonTemplate` from the professions crafter order reference. | Choose the actual reference-specific control; no blanket replacement of every old-named template. Explain exceptions. |
| Journal window and layout | Book.lua: `PortraitFrameTemplate`, Camelot ProfessionsFrame/ProfessionsCrafting, `Profession-Background-Overview`, `Profession-Background-Template2`, `Professions-background-summarylist`, `LargeSideTabButtonTemplate`, `PanelTopTabButtonTemplate`. | Retain the professions reference's authored geometry, tab anchors, list/detail relationship, padding and continuous background; use native components first. |
| Profession rows and statistics | RivalList.lua: `ProfessionsRecipeListRecipeTemplate` with safe handling of handlers that need recipe IDs. Book.lua: `ProfessionsReagentSlotBaseTemplate`, its intrinsic ItemButton mask/layers, `Professions-Slot-bg`, `Professions-Slot-Frame` fallback. | Reuse native reagent/recipe layouts and actual spacing, label anchors and selection art. Don't invent another card/slot style. |
| Character portraits and framed icons | Portraits.lua: `addon.CreateParticipantPortrait(parent, options)`, shared mask/rim/badge helpers and `addon.CreateFramedMarker`; used by Book.lua and EncounterCards.lua. | A single canonical implementation owns circle, crop, facing, rim, class/level/death markers, layers and spacing. Callers configure differences through options. Do not clone the portrait in another screen. |
| Window ordering | Book.lua: independent movable top-level `MEDIUM` frame, `SetToplevel(true)`, `Raise()` on show, native close/Escape via UISpecialFrames. | Main windows must coexist and raise naturally like native panels; a permanent DIALOG stratum can prevent ordinary panels rising above them. Genuine dialogs may have different ordering, e.g. existing IssueReport.lua. Check overlap, clicking, dragging, close/Escape and focus. Don't add all windows to a protected native manager blindly. |
| Sounds | ProfessionsMixin:OnShow/OnHide in the matching Camelot/shared source; Book.lua uses `SOUNDKIT.UI_PROFESSIONS_WINDOW_OPEN` and `UI_PROFESSIONS_WINDOW_CLOSE`. | Match the reference's sounds on equivalent actions (open/close, tabs, buttons, selection where the native reference actually plays them). Inspect native inherited handlers to avoid duplicate playback. Play once per actual transition, not on redundant Show/Hide or refresh. |
| Minimap | Book.lua shortcut follows Azeroth Fitness Shortcut:Init; `MiniMap-TrackingBorder`, `UI-Minimap-Background`, circle mask, native highlight, stored angle and size-change positioning. | Center artwork in the visible opening, not blindly in the full texture. Preserve drag and left/right-click meanings, tooltip anchoring, scale and position persistence. |
| Issue report | IssueReport.lua: `PortraitFrameTemplate`, `InputBoxTemplate`, `InputScrollFrameTemplate`, modern buttons, optional detail pages. | Retain native selection/scroll/focus/close behavior and public-sharing warning. No automatic upload or requiring external combat logging. |

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

- Match Forever build/source and distinguish documented APIs, actual delivery,
  readable fields, test mocks and observed real-client behavior. For exact
  API research, record source/build/symbol and evidence in Forever validation.
- Secret values/tables and absent data must be checked before comparison,
  indexing, serialization, arithmetic or printing. Use the existing Readable
  and restricted-field handling. `pcall` alone is not permission. Do not
  subscribe to blocked CLEU or attempt to bypass combat/taint restrictions.
- Reuse existing event/identity and meter qualification paths. A readable
  aggregate has no exact individual hit time; a cast success has no proven
  target or hit; a missing flag is not false. Validate actor/target, ownership,
  session, segment and life-episode scope. Reject stale/ambiguous signals.
- Use product rules rather than incidental API flags for fight boundaries.
  Current short late-event/bridge/terminal timers are implementation details,
  not product constants. No infinite waits, raw uptime persisted as absolute
  time, or unbounded polling. Keep late evidence and ongoing participation
  distinct. Preserve old regressions and test area transitions, reload and
  deduplication when relevant.
- Preserve per-character history, old facts, explicit manual entries and
  earned rewards; migration additive, versioned and idempotent. Temporary
  diagnostics may compact, permanent facts and contribution evidence may not
  be discarded by diagnostic pruning. No invented old credits or score
  changes on disabled BG recording.
- Keep JSONL aliases, bounded exports and optional SavedVariables report path
  intact. No real private captures, secrets or unnecessary personal data in
  Git. Add focused anonymous fixtures instead.

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

## 8. Initial knowledge backfill for Codex

Before starting Character POV, ask an agent with access to its previous
implementation sessions and/or local repository history to check for missing
**durable** technical lessons: exact native button and professions references,
window lifecycle/z-order/sounds, minimap/portrait crop decisions, reuse fixes,
API restrictions, tests and earlier rejected approaches. Reconcile any new
verified findings into this file and Forever validation with links to code,
PRs or observed evidence. Do not reimplement anything during the audit or
dump chat transcripts. If prior session access is unavailable, state the
limit and rely on existing source/history. This backfill is a targeted
documentation task; ongoing corrections are captured immediately in the
implementation PR that learns them.
