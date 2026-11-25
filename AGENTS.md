# Names in Red

Use the pinned WoW Addon Standards as part of these repository instructions.
At the start of a task involving development, documentation, packaging or
releases, explicitly open and apply `docs/standards/AGENTS.md`. Read the
relevant evidence in `docs/standards/FIELD_NOTES.md` and the local context in
`README.md`, `PROJECT_CONTEXT.md`, `docs/skirmish-product-spec.md`,
`docs/best-practices.md` and `docs/forever-validation.md` before substantive work. Consult `docs/future-ideas.md` when discussing optional
future features; those ideas are not committed product requirements.
`docs/standards/standards.lock.json` identifies the reviewed upstream version.
The owner conversation is in Russian. Repository contributions are in English.

## Keep project documentation current during discussion

Treat the repository as the durable source of truth, not the chat history.
When a discussion produces a settled product decision, a meaningful change
to the project context, or a sufficiently articulated future idea, record
it immediately in the same working session. Do not accumulate decisions
for a later documentation batch or wait for implementation to start.

- `docs/skirmish-product-spec.md`: agreed target behavior and acceptance
  criteria. Revise superseded or conflicting statements, not just append
  a competing rule.
- `PROJECT_CONTEXT.md`: durable context, rationale, important technical
  decisions, current implementation/release status and the next steps.
  Keep it compact and current rather than a conversation transcript.
- `docs/future-ideas.md`: meaningful optional ideas, clearly identified as
  exploratory and not approved implementation or a committed roadmap.
- `docs/forever-validation.md`: verified technical findings and their
  evidence/limitations, when relevant. Distinguish proposals from facts.
- `docs/best-practices.md`: mandatory project engineering conventions,
  reusable native UI decisions, known pitfalls and the review checklist.
  Capture durable owner corrections and proven lessons in the same PR that
  implements the fix. Do not leave them in an agent's conversation.

A tentative or ambiguous thought is not automatically a product decision.
Discuss and clarify it with the owner when necessary; an idea can be
documented as an optional future idea without settling every design detail.
Once it is sufficiently clear, update the relevant files without asking
again just for permission to document it. Reconcile related documents and
distinguish planned behavior from shipped behavior.

The owner has standing authorization for narrowly scoped documentation-only
PRs that capture these discussions: use a branch, create a PR, verify its
Checks, and squash-merge it when green and conflict-free. Report the PR and
actual merge/check status in the conversation. If blocked, report the blocker;
do not bypass protections. If implementation is already in progress, avoid
conflicting edits and coordinate with that work. This authorization does not
extend to runtime changes, settings, infrastructure or publishing releases.

## Engineering learning and mandatory review

Every fresh agent must explicitly read and apply [project best practices](docs/best-practices.md)
and the pinned shared standards before editing runtime code. Research the exact
native reference before implementing a Blizzard-like UI/UX; do not approximate
it first and wait for the owner to correct it. Reuse shared components.
Before opening or updating an implementation PR, self-review the diff against
the best-practices checklist, run the applicable tests and record new lessons.
Before merge, repeat the applicable checklist on the exact final diff/head;
green CI alone does not establish native visual fidelity or client behavior.
In the PR report the relevant source/template, reuse/fallback, test and live
verification status, and any updated convention (or state no new durable rule).
If the owner says a correction is how we should always do it, reconcile the
rule in the best-practices document in that same PR. For evidence-specific
findings, link the validation notes. No separate permission to document an
already authorized implementation correction is needed. Do not alter pinned
upstream standards locally; promote reusable lessons upstream only separately.

Target WoW: Forever 1.60.1 (Camelot), TOC interface 16001, Lua 5.1 compatibility.
Run `bash scripts/check.sh` before submitting changes. Use feature branches,
pull requests and squash merges. Require the Checks job before merging
implementation and verify behavior in the real Forever client before release.

Before making release changes, read the shared release section and inspect this
repository's current publishing workflow. The owner can run the permanent
Publish release workflow on main with an exact checked commit and version, or
authorize a request-only PR changing .github/release-request.json. A stable
version tag pushed by the owner remains supported. Use the single configured
publisher and verify GitHub and CurseForge independently.
If tag-driven publishing is missing, report the gap before creating a manual
GitHub Release or a separate package branch.

Build Names in Red to feel like part of the game. Reuse Blizzard's native
templates, assets, mixins and APIs wherever they cover the requested behavior.
Write addon-specific code only for behavior or presentation the client lacks.
When the owner asks to match Blizzard, inspect the exact implementation in the
matching Forever source before editing, for both UI and game behavior. Follow
the call path through XML, inheritance, Lua handlers and client overrides.
Check the actual atlases, masks, draw layers and anchors for visual changes.
If a native piece cannot be reused with addon data, preserve the behavior
established by the source and document the part that needs custom code.
Record the source file and symbol in the PR or `docs/forever-validation.md`,
along with any visual assumptions and the extent of real-client verification.

Keep reusable UI elements in one implementation. Configure shared components
with the data and options their callers need, such as portrait size, facing,
level, and casualty marker. Prefer simple composition and add abstractions
when current callers share behavior or an appearance that must stay in sync.

The installable addon is NamesInRed/. The standards are a development dependency.
Refresh them from a reviewed upstream commit using scripts/standards.py.
