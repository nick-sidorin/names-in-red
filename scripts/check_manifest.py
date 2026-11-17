"""Check the flat Lua-only addon inventory against the TOC."""
from pathlib import Path

root = Path("NamesInRed")
toc = root / "NamesInRed.toc"
entries = [
    line.strip()
    for line in toc.read_text(encoding="utf-8").splitlines()
    if line.strip() and not line.lstrip().startswith("#")
]
actual = {path.name for path in root.iterdir() if path != toc}
if (
    not entries
    or len(entries) != len(set(entries))
    or set(entries) != actual
    or any(
        not name.endswith(".lua")
        or Path(name).name != name
        or not (root / name).is_file()
        or (root / name).is_symlink()
        for name in entries
    )
):
    raise SystemExit("TOC must list each runtime Lua file exactly once")
