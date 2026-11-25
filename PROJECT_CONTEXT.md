# Names in Red — Project context and conversation handoff

**Snapshot: 25 November 2026.** Read this first when starting a fresh ChatGPT,
Codex or other coding session. This is a compact record of decisions, evidence
and status, not a raw chat transcript. Verify live repository and release state
before acting. The authoritative target behavior is
[the Character POV product specification](docs/skirmish-product-spec.md);
the release branch README and CurseForge copy describe the 2.0.0 candidate.
The published 1.1.0 listing remains current until release and listing updates
are separately verified.

## Owner intent and workflow

- Repository: https://github.com/nick-sidorin/names-in-red
- Project: a Warcraft-native personal PvP rival journal, "Remember who got you.
  Plan your revenge." Immersive gameplay and the personal story matter more than
  an esport scoreboard. Public listing copy emphasizes personal rivalries and
  the revenge theme; the short summary naturally includes vendetta and revenge
  alongside PvP and rival statistics. Keep the permanent listing evergreen:
  feature bullets first, then topical details, no addon release numbers or
  changelog sections. The owner plays a night elf hunter in Forever with a
  brother (druid in Gnomeregan); also consider pure healer and solo play.
- Talk to the owner in Russian; repository docs/code/PRs in English. Read root
  [AGENTS.md](AGENTS.md), pinned [standards](docs/standards/AGENTS.md),
  [field notes](docs/standards/FIELD_NOTES.md), [README](README.md),
  [product spec](docs/skirmish-product-spec.md), relevant
  [validation](docs/forever-validation.md), and [future ideas](docs/future-ideas.md).
- Use feature branches, pull requests, squash merges, protected main and required
  Checks. Run bash scripts/check.sh (Lua 5.1, Python 3). Do not bypass protection.
  Prefer scoped regressions and Blizzard-native assets/templates; no repeated
  broad test requests to the owner. Release only with authorization. Separate
  actual live-client observations, mock tests and inference.
- The owner uses ChatGPT for product design, investigation and reviews and Codex
  for most implementation. Context limits can interrupt work. Update durable
  product/technical notes instead of relying on chat continuity. Do not restart
  the already shipped release or undo earlier regression fixes.

### Continuous documentation

The owner explicitly agreed on 24 November 2026 that decisions should be
captured as they arise, rather than accumulated until a chat becomes too long.
After a clear product decision, meaningful context change or sufficiently
articulated future idea, immediately update the relevant document(s) in a
small documentation-only PR, run Checks and squash-merge when green.
No repeated permission is needed for this documentation workflow. Clarify
ambiguous ideas through discussion first; record optional ideas as proposals,
not implementation commitments. Reconcile superseded decisions in the spec,
keep this handoff concise, and record technical evidence in the validation
notes when applicable. See the standing rule in [AGENTS.md](AGENTS.md).
Runtime changes and releases remain separately scoped.

### Continuous engineering learning

The owner requires the same living-documentation approach for technical
conventions, not only product decisions. [Best practices](docs/best-practices.md)
is a mandatory entry point for each fresh agent; it links actual native UI
references, reusable components, API safeguards and the pre-PR/pre-merge
checklist. If a correction is a durable convention (for example, use the
modern native red button, reuse a shared portrait, or match native sounds),
record it in the same implementation PR as the correction. Do not rely on
Codex conversation history. Audit any accessible prior Codex sessions and
repository history for missing reusable lessons; mark unverified details
rather than invent them. Generic continuous engineering learning is also a
potential Evercanon pattern, not a change to that separate repository.

## Released baseline: 1.1.0

- Target WoW: Forever 1.60.1 (Camelot), interface 16001, Lua 5.1. Research initially
  used build 70959; latest owner captures use build 71037. Verify APIs on matching
  build; Retail/Classic assumptions do not establish availability.
- GitHub stable [v1.1.0](https://github.com/nick-sidorin/names-in-red/releases/tag/v1.1.0)
  published 23 November 2026 at 22:57:03 UTC, on commit
  e8bcee6a98c5fb95ebb5d62d4a6c1a82039fa588. ZIP:
  https://github.com/nick-sidorin/names-in-red/releases/download/v1.1.0/NamesInRed-1.1.0.zip
  (399,300 bytes; 29 runtime files verified against that commit).
- PR #27 prepared version metadata. #25 added Report an Issue, #26 battlegrounds,
  #28 Gnomeregan fixes, #29 primary combat evidence, #30 retained bounded
  diagnostic samples, #31 permanent battle history/aggregates and report-button
  native styling. #32 refreshed release notes and added a one-time publish
  workflow. #33 repaired tag check (404 body misinterpreted as tag; use git
  ls-remote). #34 removed that temporary workflow after successful publication.
  Main at handoff before this docs update: 84b4c3a1e9a2171d3ff2687ed427b313cd38bbae;
  all checks passed and no open PRs then. Tagged commit remains unchanged.
- Codex hit its usage limit partway through release. ChatGPT finished GitHub
  publication and cleanup. The retrospective independently verified the
  public [CurseForge 1.1.0 file](https://www.curseforge.com/wow/addons/names-in-red/files/9782367)
  as Release for Forever 1.60.1 and compared both archives to the tag.
  No permanent GitHub release workflow remains. Verify the automatic
  packaging status before any manual upload. Copy-ready listing texts
  live in [the full description](docs/curseforge-description.md) and
  [short summary](docs/curseforge-summary.txt). Their publication on the
  CurseForge project page was not verified.
- Earlier 1.1.0 live smoke test: Sanya Paint card changed to Defeat; skull level
  absent because no readable level was saved. Most Gnomeregan records remained
  Unknown. The final #31 button layout, detail report pages, and client frame
  time were not independently smoke-tested in the chat. Automated tests passed.

## Product evolution and next approved direction

The 23 November side-outcome model attempted to infer which local side won
the whole connected confrontation, with survivors/withdrawal/terminal samples.
It also copied that side result into every rival's personal score. This caused
discomfort and frequent Unknowns, particularly if a player died or observation
ended before allied continuation resolved.

On 24 November the owner and assistant agreed to replace that model with
**Character POV — Personal PvP Journal** for a subsequent version, not block
1.1.0. The addon should reflect the character's own experienced episode, not
establish objective truth for every player. Three separate questions:

1. Primary skirmish result uses the approved ordered hybrid: decisive
   observed elimination first (mutual elimination = Draw); terminal PvP death
   with lost observation before a reliable ending = Defeat; otherwise compare
   distinct confirmed death episodes at an observed non-elimination ending
   (fewer friendly deaths = Victory, more = Defeat, equal including 0:0 = Draw).
   Genuine insufficient ending evidence can exceptionally be Unknown.
   In progress is lifecycle, not outcome. Death while still observing an
   allied victory need not be Defeat; solo death to a surviving enemy is.
   Actual revival/return can continue the encounter. No universal site anchor,
   complete roster or terminal sample requirement; never invent deaths.
   Survival/retreat alone is not an outcome.

2. Personal rival score: meaningful contribution to defeating **that rival**,
   not the entire side's outcome and not only last hits. The owner explicitly
   requires damage + teammate's kill and pure healing/support of the ally who
   defeats the rival to count as personal victories. Include reliable control,
   shield/absorb, pet and other relevant support. Opposing involvement in our
   death should be evidence-based as well, not a blanket loss against the
   roster. Keep literal killing blows, deaths from a particular finisher, HKs
   and honor separate. A mage I help kill and a rogue who later kills me give
   mage credit and rogue loss even if the skirmish itself is Defeat.
   The owner approved one credit per rival per genuine death episode, with
   repeated deaths after revival counted separately, no non-lethal rival
   credits for this milestone, original legacy results retained and supported
   re-evaluation only. A confirmed death plus linked contribution qualifies
   even with unknown finisher. Exact legacy/manual UI remains a design choice.
3. Observed group context: preserve allied continuation, known casualties and
   any supported group result; it can differ from personal result and need not
   be knowable. The character at a graveyard does not magically know the final
   result because the owner heard it on Discord. Do not throw away readable
   client evidence just because it is indirect.

No global synchronization dependency. Optional friend/party addon messaging
is a later exploration only; there will rarely be another installed copy among
all combatants. The full chronological battle viewer is also later; preserve
available product data now. No new version number committed; earlier informal
suggestion was 1.1.x fixes / 1.2.0 larger features. Do not bundle unrelated
features into an approved release. See product spec for all acceptance rules.

## Permanent history versus temporary evidence

- Every rival, encounter, roster, date/location, recorded/derived outcome,
  confirmed timeline, rewards and accepted meter aggregates must remain
  indefinitely unless the owner explicitly deletes/resets them. The latest 100
  cross-rival view is an interface cap only. Individual rival history reaches
  all recorded encounters. Future contribution facts needed for the personal
  score/viewer must also be permanent, not pruned with diagnostic detail.
- Per-character SavedVariables: NamesInRedDB and NamesInRedDebugDB in
  _forever_/WTF/Account/<account>/<realm>/<character>/SavedVariables/NamesInRed.lua.
  User has sent full .lua files for investigation. WoW flushes SavedVariables
  normally on logout/reload. Local backups matter; no cloud sync promised.
- The rolling debug log has 1,000 rows; #30 keeps details for newest 24 fights
  (estimated 64 KiB per fight), compact context for old cards. #31 keeps accepted
  linked meter damage/healing/absorb samples permanently per segment independent
  of pruning; legacy samples promoted only on unique matching segment/read.
  140-encounter test opened a 2020 card after diagnostic pruning/reload.
- Test serialization: mixed 8,127 bytes, dense 47,237 bytes, compact 3,685 bytes;
  24 dense logs 1,118,784 bytes, 26 stress cards ~1,656 KiB Lua heap. These are
  fixture measurements, not frame-time proof or caps on permanent history.
- Report an Issue: from header/settings or compact/full card bug icon, copy
  one versioned JSONL report with stable aliases and one full-text selection.
  The 60 KiB export budget leaves room in the GitHub issue body. The report
  identifies omitted sections and can rebuild for a smaller EditBox capacity.
  Reports distinguish observations, aggregates, inferred results, restriction
  status and retention/truncation. Optional attachment of existing NamesInRed.lua
  as-is; no manual anonymization, no hunt for timestamps, no prerequisite
  /combatlog or external WoWCombatLog. Short public-file warning (names/GUIDs,
  public GitHub attachment); built-in report stays pseudonymized. Never auto-upload
  data. Private captures are not committed; keep anonymous regression fixtures.

## Technical map and limitations

- NamesInRed/Ledger.lua owns saved records and the in-memory journal index.
  On first use it projects each battle once. Warm lookups read per-rival
  totals for contribution, finishing blows and rewards. A save replaces one
  battle's numeric snapshot even when the recorder updates the same table.
  The index and projections used by the report are rebuilt from durable
  evidence after reload.
- NamesInRed/SkirmishOutcomes.lua continues to derive the legacy side result
  from its site, range and terminal samples. NamesInRed/PersonalSkirmishOutcomes.lua
  implements the Character POV projection from durable timeline and local ending
  evidence. WorldSkirmishes owns participation transitions. Ledger persists the
  versioned projection alongside the legacy result. The full journal uses
  the personal result, with active and awaiting shown as In progress. The durable timeline
  includes sample-observed revivals and witnessed per-pair action offsets
  within each segment for replay across separate lives.
- NamesInRed/WorldSkirmishes.lua, SkirmishEvidence.lua, Debug.lua, Kills.lua,
  Deaths.lua, Honor.lua, Encounter.lua: event correlation, roster and life
  observations, late windows, group/pet identity, accepted meter links and
  rewards. Debug.lua currently requires explicit feign=false to add dead life
  samples; assess class-aware corroboration without blindly treating nil as false.
- NamesInRed/RivalContributions.lua derives versioned per-rival credits from
  the shared PvP death episodes used by the personal outcome. The profile,
  compact cards, nameplates and unit tooltip read the same indexed credit.
  Scoped legacy and manual results remain available. Accepted meter pairs
  and scoped recap contributors survive diagnostic pruning. See the
  [PR B evidence](docs/forever-validation.md#character-pov-pr-b) and
  [PR C journal validation](docs/forever-validation.md#character-pov-pr-c).
- CombatDiagnostics.lua and IssueReport.lua capture/export bounded evidence.
  Ledger.RecordMeterAggregates preserves linked pairs/spell/amount permanently.
  Report cards include the personal outcome's coverage, boundary and
  casualties, and aliased credit evidence linked to durable event indexes.
  Book.lua, EncounterCards.lua, Nameplates.lua and Portraits.lua share
  existing frames and counter art. Labels and tooltips cover all supported
  locales. Keep skull level (-1) distinct from death skull and missing level.
- Full structured COMBAT_LOG_EVENT_UNFILTERED restricted in Forever; do not
  bypass it. UNIT_COMBAT may give recipient/effect/amount (secret possible) but
  not actor/spell. UNIT_AURA / spellcast data may be secret, cast success does
  not prove target or hit. C_DamageMeter supplies readable, session-scoped
  aggregate links and sampled spell amounts; categories overlap, receipt time
  is not individual hit time. PARTY_KILL gives readable GUIDs when permitted;
  Death Recap can identify lethal hit and prior readable entries. Unit flags
  need identity and feign/revival handling. API absence/secret is not false.
- Honor scopes: attributable rival, skirmish without rival, global unassigned;
  no false award-to-killer attribution, no retroactive invented points.
- BG recording default ON, independent visibility toggles; OFF stops new BG
  data but keeps known rivals and historical icons. Match result is never
  local fight result. Manual entries remain separate and explicit.

## Actual regression evidence (all times MSK, 22–23 November 2026)

The detailed evidence is in docs/forever-validation.md and anonymized tests
(especially tests/gnomeregan-world.lua and tests/gnomeregan-outcomes.lua).
Owner shared SavedVariables and screenshots; private captures were not added
to source control. Original attachments in the previous ChatGPT chat included
NamesInRed(1).lua, NamesInRed(2).lua and a generated investigation markdown
report. Those original files are not guaranteed to be available in a fresh
session; use repository fixtures and ask for the original only if necessary.

- Duskwood 22 Nov: 2 vs 3 after recovered priest ally, two finishing blows,
  five honor, Unknown in retained replay. Owner expects recognizable local
  Victory if surviving allies overcame/dispersed foes; no invented third death.
- Gnomeregan world:4 at 20:08: 2 vs 2. Brother kills shaman at +32.494 s.
  Paladin contact dead=true at +28.043 s on nameplate removal; feign missing,
  no durable death event for him. Shaman dead contact +32.781 s. Both allies
  alive and out of combat in two later terminal samples (~39.631, 41.628 s).
  Old Unknown / site-anchor-missing. Strong candidate for POV Victory based
  on corroborated evidence; exact second death still needs assessment. No
  hard-coded fixture win and no automatic personal credit for every enemy.
- world:5 at 20:09: ally kills Mimza Rella and local hunter kills Huit within
  seconds, old card only 1v1. #28 staged off-target PARTY_KILL using original
  GUID/time and confirmed links; reject unrelated nearby kills.
- world:7 at 20:11: 2 vs 3. Ally kills rogue +3.483 s; local character killed
  +6.262 s (death recap); hostile Paladin aura to ally +13.524 s; other enemy
  observed death +16.970 s; ally observed dead +17.528 s; spirit release
  +17.528 s; meter read advances +18.651 s; area-changed no terminal samples.
  Old Unknown group result. New POV: personal Defeat absent return, independent
  of final group ending. Meter read offset not an attack timestamp.
- world:8 at 20:20: ally 735 damage vs local 383 on same enemy; old 1v1 because
  local 8.56 s and meter 11 s mismatch. #28 accepted anchored pair plus scoped
  activity, did not loosen all duration rules.
- 20:21 missing card: first read lost to next combat session. #28 saves first
  qualified links before handoff. Cannot restore missing historical data.
- Honor: historical 39 earned vs 25 attached, 14 unassigned. New scopes retain
  future earned totals. No automatic backfill of historical 14.
- world:12 at 22:22: hostile high-level player lands lethal PvP hit after NPC
  damage, overkill 140, local dead then ghost, area change. #28 repaired isolated
  defeat, verified live. Level not available historically; explicit -1 renders
  skull, positive number renders number, absent hides.
- world:14 at 22:37: local 33 hunter killed by enemy Paladin 47 at +16.166 s,
  two other linked opponents, no terminal samples, spirit release +17.483 s
  and area change. Old Unknown. New POV personal Defeat absent return; group
  unknown; only evidenced rivals get death participation credit.
- The last reports for world:4 and world:7 were from preview.10; earlier
  historical cards lack new combatCapture data. #30 replay still left them
  Unknown under the old semantics; this is a product-model change, not evidence
  that #30 failed to implement its stated diagnostic scope.

## Character POV implementation and next work

24 November follow-up: all five roadmap scoring decisions are accepted.
Three enemies damaging our character in the same lethal episode each earn a
rival loss; the final personal skirmish loss is still one. The owner clarified
that a fight waits for plausible continuation, including a real return after
resurrection or stealth, but must close on reliable ending/quiet evidence.
Ordinary zone borders alone must not split it. Unrelated later PvE and a
regrouped revenge fight are separate episodes. Exact timing is an implementation decision.
The owner rejected survival alone as Victory, considered pure casualty scoring,
then approved starting implementation of the hybrid model described above and
in spec section 6. The decisive-resolution / terminal-death / observed
casualty-balance priority order replaces earlier withdrawal and automatic
terminal-death assumptions. Keep rival credit, permanent history and rewards
independent. New edge cases may be refined during implementation; no further
product approval checkpoint is needed for PR A. Exact UI presentation and
technical evidence predicates remain implementation choices.

PR A implements the independent personal result and participation lifecycle.
See [the timing and replay notes](docs/forever-validation.md#character-pov-pr-a)
for the 12-second settlement window, evidence rules and historical results.
PR A (#43), PR B (#44), PR C (#45) and the control-gap fix (#48) are
merged. Issue #47 is closed and the owner confirmed restored history in
Forever on preview `218f1b1`. The pre-release integration baseline was `9b6876b`. The owner accepted
Character POV and authorized publication of 2.0.0. PR #50 is squash-merged
at `a58fccad02de7e50357e63546b1b3710cd1ea01f`; Issue #49 is closed. PR #46
is superseded and closed without a second merge. Public availability remains
unverified until the tag-driven publisher and CurseForge are checked.

1. Prepare the 2.0.0 release PR and preview the single-copy issue report.
   Complete final product and technical review before pushing a public
   version tag. Follow the [integration gate](docs/character-pov-roadmap.md#integration-and-release-gate).
   PR #50 also fixes Issue #49. A concordant outgoing pair can record a
   skirmish independently of a killing blow. The exact private replay
   recovers the assisted 2×1 Victory with one rival win and the same 1 HK /
   4 honor on the card and rival profile. The owner verified the restored
   card and compact report on `6961d33`. The owner confirmed the corrected rival statistics in Forever on `b7870aa`. Its old diagnostic window carries
   no map position. The release gate checks deterministic ZIP output. See
   [Forever validation](docs/forever-validation.md#outgoing-only-aid-in-forever-71091).
2. Preserve the earlier real-client acceptance of restored world:19–21,
   world:16 Defeat, rival scores and reload. The owner confirmed the two-fight
   recovery from #48 after that check. Unobserved rare group and hostile
   pet-owner scenarios stay as follow-ups under the accepted release policy.
   [PR C acceptance](https://github.com/nick-sidorin/names-in-red/pull/45#pullrequestreview-6060358381) ·
   [Control-gap validation](docs/forever-validation.md#control-gap-replay-world2324)
3. Known data loss, crashes, core behavior defects, failing checks and
   package problems still block publication. Verify GitHub and CurseForge
   artifacts independently once the owner accepts the final release.
4. After 2.0.0 publication, prioritize polishing the existing journal, not new
   feature milestones. See the approved post-release polish requirements in
   the product spec. A known manual-entry duplicate report needs investigation
   and safe correction; visual and roster-warning refinements are also queued.
   All larger ideas, including target menu and ally profiles, are deferred in
   docs/future-ideas.md.

To resume in a new chat: provide the repository link and ask the assistant to
read this file and docs/skirmish-product-spec.md, verify main/PR/release state,
and continue with the current release/polish scope. No need to repeat
the entire conversation.
