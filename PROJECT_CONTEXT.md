# Names in Red — Project context and conversation handoff

**Snapshot: 24 November 2026.** Read this first when starting a fresh ChatGPT,
Codex or other coding session. This is a compact record of decisions, evidence
and status, not a raw chat transcript. Verify live repository and release state
before acting. The authoritative target behavior is
[the Character POV product specification](docs/skirmish-product-spec.md);
the shipped README and CurseForge copy describe 1.1.0 until new behavior ships.

## Owner intent and workflow

- Repository: https://github.com/nick-sidorin/names-in-red
- Project: a Warcraft-native personal PvP rival journal, "Remember who got you.
  Plan your revenge." Immersive gameplay and the personal story matter more than
  an esport scoreboard. The owner plays a night elf hunter in Forever with a
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
- Codex hit its usage limit partway through release; ChatGPT finished GitHub
  publication and cleanup. No permanent GitHub release workflow remains.
  CurseForge automatic upload/type/status was **not confirmed** in this chat.
  Check https://www.curseforge.com/wow/addons/names-in-red/files/all and author
  project 1819566; do not duplicate an automatic package. Intended type Release,
  Forever 1.60.1. Copy-ready texts live in docs/curseforge-description.md and
  docs/curseforge-summary.txt. Do not claim they were applied on CurseForge.
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

1. Personal result of the skirmish: final participation is Victory, Defeat or
   Unknown. Terminal PvP death without return is Defeat; a real revival/return
   to the same confrontation can change the final result. Clear local survival
   and overcoming/forcing off opponents is Victory even without kills. Forced
   retreat is Defeat; mutual disengagement or truly missing evidence is Unknown.
   Death is a fact; lack of a perfect site anchor/complete roster/terminal
   samples is not a universal veto. Never infer death from invisibility.
2. Personal rival score: meaningful contribution to defeating **that rival**,
   not the entire side's outcome and not only last hits. The owner explicitly
   requires damage + teammate's kill and pure healing/support of the ally who
   defeats the rival to count as personal victories. Include reliable control,
   shield/absorb, pet and other relevant support. Opposing involvement in our
   death should be evidence-based as well, not a blanket loss against the
   roster. Keep literal killing blows, deaths from a particular finisher, HKs
   and honor separate. A mage I help kill and a rogue who later kills me give
   mage credit and rogue loss even though the skirmish itself is Defeat.
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
  versioned JSONL, optional detail pages with stable aliases, 24 KiB/page.
  Reports distinguish observations, aggregates, inferred results, restriction
  status and retention/truncation. Optional attachment of existing NamesInRed.lua
  as-is; no manual anonymization, no hunt for timestamps, no prerequisite
  /combatlog or external WoWCombatLog. Short public-file warning (names/GUIDs,
  public GitHub attachment); built-in report stays pseudonymized. Never auto-upload
  data. Private captures are not committed; keep anonymous regression fixtures.

## Technical map and limitations

- NamesInRed/Ledger.lua: saved records, index, existing SkirmishOutcome,
  IndexSkirmish, PersonalScore, PersonalCombatScore. Currently side outcome is
  copied to all enemy profiles; personal killing blows/deaths separate already.
  Rework projections/indexes rather than destructively overwrite old records.
- NamesInRed/SkirmishOutcomes.lua: current world evaluator, site anchor,
  terminal samples, ConfirmedDeaths, IsolatedLethalRecap, SiteFreeElimination.
  Currently missing terminal samples can return Unknown before considering
  non-isolated deaths. New personal evaluator should not depend on global
  terminal samples; retain old group result as separately versioned context.
- NamesInRed/WorldSkirmishes.lua, SkirmishEvidence.lua, Debug.lua, Kills.lua,
  Deaths.lua, Honor.lua, Encounter.lua: event correlation, roster and life
  observations, late windows, group/pet identity, accepted meter links and
  rewards. Debug.lua currently requires explicit feign=false to add dead life
  samples; assess class-aware corroboration without blindly treating nil as false.
- CombatDiagnostics.lua and IssueReport.lua capture/export bounded evidence.
  Ledger.RecordMeterAggregates preserves linked pairs/spell/amount permanently.
  Book.lua, EncounterCards.lua, Nameplates.lua, Portraits.lua, Locale.lua and
  relevant tooltip code must agree on changed score semantics; use native
  templates and concise localized labels, consistent EN/RU and all supported
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

## Next work (approved direction, not yet implemented)

24 November follow-up: all five roadmap scoring decisions are accepted.
Three enemies damaging our character in the same lethal episode each earn a
rival loss; the final personal skirmish loss is still one. The owner clarified
that a fight waits for plausible continuation, including a real return after
resurrection or stealth, but must close on reliable ending/quiet evidence.
Ordinary zone borders alone must not split it. Unrelated later PvE and a
regrouped revenge fight are separate episodes. No exact timeout selected.
Abandoning a fight with fallen allies and surviving enemies is Defeat even
if we live under the previously agreed outcome model. The owner subsequently
rejected ordinary survival/escape as Victory and proposed replacing outcome
inference with observed casualty counts: Victory for fewer friendly deaths,
Defeat for more, Draw for equal (including 0:0), plus In progress as lifecycle.
No routine public Unknown; incomplete evidence remains explicit metadata.
This is a proposed replacement, not yet an approved evaluator contract: resolve
whether terminal personal death overrides a favorable/equal casualty count.
Keep the already approved rival credit independent; no change to retention,
rewards or encounter continuation. See section 6 of the product spec.

A proposed staged [Character POV milestone roadmap](docs/character-pov-roadmap.md)
organizes the next work into a product-decision checkpoint, personal outcome,
rival attribution, integrated UI/migration/reporting, and release verification.
It is a planning document, not approval of the proposed casualty-outcome refinement,
a final version number, runtime implementation, or publication.

1. Keep 1.1.0 stable. Start from current main, read this spec and the existing
   tests. Do not reopen the release or build unnecessary global replay/sync.
2. Design independent personal participation/end boundaries and versioned
   personal outcome inference. Preserve group context and legacy results;
   re-evaluate only from retained evidence. Cover death/revival, retreat,
   interruption, NPC vs PvP, 1v1, group and BG cases.
3. Design attributable contribution to an opponent's defeat or our death:
   direct, assisted damage and meaningful linked healing/support, pets; prevent
   cross-window/roster-wide credit and duplicates. Apply the approved per-death
   counting unit and repeat-death rules; resolve legacy/manual representation
   in the implementation design.
   Preserve facts permanently, distinguish contribution from actual last hit
   and game-awarded rewards. No arbitrary damage threshold or healer penalty.
4. Integrate Ledger and the UI consistently: rival score and compact card,
   personal outcome in full skirmish card, optional group context, tooltips,
   nameplates, report reasons and localization. Review migration with actual
   saved data; don't reset old records or re-label unsupported legacy wins.
5. Replay original anonymized examples and new healer/assist cases, automated
   Checks and narrow real-client smoke checks. Update shipped documentation
   only when feature actually ships. Release with separate authorization.
6. Later ideas (not blockers): full timeline viewer, general history pagination,
   optional consenting peer observations, formal duel history, target-frame
   marker, ranks/achievements. See docs/future-ideas.md.

To resume in a new chat: provide the repository link and ask the assistant to
read this file and docs/skirmish-product-spec.md, verify main/PR/release state,
and continue with the Character POV implementation design. No need to repeat
the entire conversation.
