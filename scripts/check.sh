#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 scripts/standards.py check --target .
python3 scripts/check_manifest.py
for file in NamesInRed/*.lua tests/*.lua; do
    luac5.1 -p "$file"
done
lua5.1 tests/ledger.lua
