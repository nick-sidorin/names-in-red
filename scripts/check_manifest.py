"""Check the TOC and explicit runtime asset inventory."""
from pathlib import Path

root = Path("NamesInRed")
toc = root / "NamesInRed.toc"
entries = [
    line.strip()
    for line in toc.read_text(encoding="utf-8").splitlines()
    if line.strip() and not line.lstrip().startswith("#")
]
assets = {
    "Art/Victory.tga": (128, 24),
    "Art/Gravestone.tga": (128, 24),
    "Art/Battlefield.tga": (512, 32),
    "Art/CrossedSwords.tga": (128, 24),
    "Art/CrossedSwordsPortrait.tga": (128, 24),
    "Art/CrossedSwordsSlot.tga": (128, 24),
    "Art/Skull.tga": (128, 24),
    "Art/SkullSlot.tga": (128, 24),
    "Art/LevelBadge.tga": (64, 32),
    "Art/TooltipVictory.tga": (64, 32),
    "Art/TooltipSkull.tga": (64, 32),
}
actual = {
    path.relative_to(root).as_posix()
    for path in root.rglob("*")
    if path != toc and (not path.is_dir() or path.is_symlink())
}
if (
    not entries
    or len(entries) != len(set(entries))
    or (set(entries) | set(assets)) != actual
    or any(
        not name.endswith(".lua")
        or Path(name).name != name
        or not (root / name).is_file()
        or (root / name).is_symlink()
        for name in entries
    )
):
    raise SystemExit("Runtime inventory must match the TOC and asset list")

for name, (size, depth) in sorted(assets.items()):
    path = root / name
    data = path.read_bytes()
    if path.is_symlink() or path.parent.is_symlink() or (
        len(data) < 18 + size * size * (depth // 8)
        or data[:3] != bytes((0, 0, 2))
        or data[12:17] != size.to_bytes(2, "little") * 2 + bytes((depth,))
    ):
        raise SystemExit(f"Expected an uncompressed {size}x{size} {depth}-bit TGA in {name}")
