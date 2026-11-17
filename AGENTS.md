# Names in Red

Read README.md, idea.md, docs/forever-validation.md and the pinned guidance in
docs/standards/AGENTS.md and docs/standards/FIELD_NOTES.md before substantive work.
The owner conversation is in Russian. Repository contributions are in English.

Target WoW: Forever 1.60.1 (Camelot), TOC interface 16001, Lua 5.1 compatibility.
Run `bash scripts/check.sh` before submitting changes. Use feature branches,
pull requests and squash merges. Require the Checks job before merging
implementation and verify behavior in the real Forever client before release.

The installable addon is NamesInRed/. The standards are a development dependency.
Refresh them from a reviewed upstream commit using scripts/standards.py.
