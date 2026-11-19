# Names in Red

Read README.md, idea.md, docs/forever-validation.md and the pinned guidance in
docs/standards/AGENTS.md and docs/standards/FIELD_NOTES.md before substantive work.
The owner conversation is in Russian. Repository contributions are in English.

Target WoW: Forever 1.60.1 (Camelot), TOC interface 16001, Lua 5.1 compatibility.
Run `bash scripts/check.sh` before submitting changes. Use feature branches,
pull requests and squash merges. Require the Checks job before merging
implementation and verify behavior in the real Forever client before release.

For a UI reference from the owner, find the exact widget in the matching
Forever UI source or the referenced addon's accessible source before editing.
Trace the requested visual state through XML, inherited templates and active
Lua handlers. Check the actual atlas, draw layers and anchors. Record the
source file and symbol in the PR or `docs/forever-validation.md`, along with
any assumptions from the screenshot and the extent of real-client verification.

The installable addon is NamesInRed/. The standards are a development dependency.
Refresh them from a reviewed upstream commit using scripts/standards.py.
