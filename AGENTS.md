# Names in Red

Read README.md, idea.md, docs/forever-validation.md and the pinned guidance in
docs/standards/AGENTS.md and docs/standards/FIELD_NOTES.md before substantive work.
The owner conversation is in Russian. Repository contributions are in English.

Target WoW: Forever 1.60.1 (Camelot), TOC interface 16001, Lua 5.1 compatibility.
Run `bash scripts/check.sh` before submitting changes. Use feature branches,
pull requests and squash merges. Require the Checks job before merging
implementation and verify behavior in the real Forever client before release.

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

The installable addon is NamesInRed/. The standards are a development dependency.
Refresh them from a reviewed upstream commit using scripts/standards.py.
