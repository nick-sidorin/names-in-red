#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

commit=$1
output=$2
version=$(git show "$commit:NamesInRed/NamesInRed.toc" | sed -n 's/^## Version: //p')
archive="NamesInRed-$version.zip"
python3 scripts/package_release.py --commit "$commit" --version "$version" --output "$output/first"
# ZIP's legacy timestamp has two-second granularity.
sleep 2
python3 scripts/package_release.py --commit "$commit" --version "$version" --output "$output/second"
cmp "$output/first/$archive" "$output/second/$archive"
sha256sum "$output/first/$archive" "$output/second/$archive"
