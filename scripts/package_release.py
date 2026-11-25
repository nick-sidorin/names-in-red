"""Build a verified installable ZIP and GitHub release notes from one Git commit."""

import argparse
import io
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tarfile
import tempfile
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


REPO = Path(__file__).resolve().parent.parent


def git(*args):
    return subprocess.check_output(["git", *args], cwd=REPO)


def release_notes(changelog, version):
    heading = f"## {version}"
    lines = changelog.splitlines()
    if lines.count(heading) != 1:
        raise ValueError(f"Expected one changelog heading {heading}")
    start = lines.index(heading) + 1
    end = next((i for i in range(start, len(lines)) if lines[i].startswith("## ")), len(lines))
    notes = "\n".join(lines[start:end]).strip()
    if not notes:
        raise ValueError(f"Empty changelog for {version}")
    return notes


def runtime_files(commit):
    members = git("ls-tree", "-r", "-z", "--name-only", commit, "--", "NamesInRed")
    expected = set(members.decode().rstrip("\0").split("\0"))
    archive = git("archive", "--format=tar", commit, "NamesInRed")
    files = {}
    with tarfile.open(fileobj=io.BytesIO(archive)) as source:
        for item in source:
            if item.isdir():
                continue
            path = PurePosixPath(item.name)
            if not item.isfile() or path.is_absolute() or ".." in path.parts or item.name in files:
                raise ValueError(f"Unexpected runtime entry {item.name}")
            files[item.name] = source.extractfile(item).read()
    if files.keys() != expected:
        raise ValueError("Git archive does not match the committed runtime inventory")
    return files


def verify_source(version, files):
    toc = files["NamesInRed/NamesInRed.toc"].decode()
    if re.findall(r"^## Version: (.*)$", toc, re.M) != [version]:
        raise ValueError("TOC version and requested release version differ")
    if re.findall(r"^## Interface: (.*)$", toc, re.M) != ["16001"]:
        raise ValueError("The release must target WoW Forever interface 16001")
    if re.search(r"^## X-Preview-Revision:", toc, re.M):
        raise ValueError("A public archive cannot contain a preview stamp")

    with tempfile.TemporaryDirectory() as folder:
        for name, content in files.items():
            path = Path(folder) / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
        subprocess.run([sys.executable, str(REPO / "scripts/check_manifest.py")], cwd=folder, check=True)


def package(revision, version, output):
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ValueError("Expected a stable major.minor.patch version")
    commit = git("rev-parse", "--verify", "--end-of-options", f"{revision}^{{commit}}").decode().strip()
    files = runtime_files(commit)
    verify_source(version, files)
    notes = release_notes(git("show", f"{commit}:CHANGELOG.md").decode(), version)

    output.mkdir(parents=True, exist_ok=True)
    path = output / f"NamesInRed-{version}.zip"
    with ZipFile(path, "w") as archive:
        for name, content in sorted(files.items()):
            member = ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            member.create_system = 3  # Unix metadata on every runner.
            member.external_attr = 0o100644 << 16
            archive.writestr(member, content, compress_type=ZIP_DEFLATED, compresslevel=6)
    with ZipFile(path) as archive:
        if archive.testzip() or sorted(archive.namelist()) != sorted(files):
            raise ValueError("ZIP paths, CRC or inventory differ")
        for name, content in files.items():
            if archive.read(name) != content:
                raise ValueError(f"ZIP does not match {commit}:{name}")
    (output / "release-notes.md").write_text(
        f"{notes}\n\n<!-- names-in-red-source: {commit} -->\n", encoding="utf-8"
    )
    print(f"Verified {len(files)} files in {path} from {commit}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    package(args.commit, args.version, args.output)
