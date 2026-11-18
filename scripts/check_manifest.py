"""Check the TOC and explicit runtime asset inventory."""
from pathlib import Path

root = Path("NamesInRed")
toc = root / "NamesInRed.toc"
entries = [
    line.strip()
    for line in toc.read_text(encoding="utf-8").splitlines()
    if line.strip() and not line.lstrip().startswith("#")
]
assets = {"Art/Victory.tga", "Art/Gravestone.tga"}
actual = {
    path.relative_to(root).as_posix()
    for path in root.rglob("*")
    if path != toc and (not path.is_dir() or path.is_symlink())
}
if (
    not entries
    or len(entries) != len(set(entries))
    or (set(entries) | assets) != actual
    or any(
        not name.endswith(".lua")
        or Path(name).name != name
        or not (root / name).is_file()
        or (root / name).is_symlink()
        for name in entries
    )
):
    raise SystemExit("Runtime inventory must match the TOC and asset list")

for name in sorted(assets):
    path = root / name
    data = path.read_bytes()
    if path.is_symlink() or path.parent.is_symlink() or (
        len(data) < 18 + 128 * 128 * 3
        or data[:3] != bytes((0, 0, 2))
        or data[12:17] != bytes((128, 0, 128, 0, 24))
    ):
        raise SystemExit(f"Expected an uncompressed 128x128 RGB TGA in {name}")
