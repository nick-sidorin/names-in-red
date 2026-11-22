# Names in Red

Use the pinned WoW Addon Standards as part of these repository instructions.
At the start of a task involving development, documentation, packaging or
releases, explicitly open and apply `docs/standards/AGENTS.md`. Read the
relevant evidence in `docs/standards/FIELD_NOTES.md` and the local context in
`README.md`, `idea.md` and `docs/forever-validation.md` before substantive work.
`docs/standards/standards.lock.json` identifies the reviewed upstream version.
The owner conversation is in Russian. Repository contributions are in English.

Target WoW: Forever 1.60.1 (Camelot), TOC interface 16001, Lua 5.1 compatibility.
Run `bash scripts/check.sh` before submitting changes. Use feature branches,
pull requests and squash merges. Require the Checks job before merging
implementation and verify behavior in the real Forever client before release.

Before making release changes, read the shared release section and inspect this
repository's current publishing workflow. The owner's release entry point is
the version tag. Use the configured tag-driven publisher and verify its output.
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
