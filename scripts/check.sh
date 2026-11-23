#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 scripts/standards.py check --target .
python3 scripts/check_manifest.py
for file in NamesInRed/*.lua tests/*.lua; do
    luac5.1 -p "$file"
done
lua5.1 tests/ledger.lua
lua5.1 tests/outcomes.lua
lua5.1 tests/debug.lua
lua5.1 tests/kills.lua
lua5.1 tests/deaths.lua
lua5.1 tests/book.lua
lua5.1 tests/waypoints.lua
lua5.1 tests/nameplates.lua
lua5.1 tests/settings.lua
lua5.1 tests/world.lua
