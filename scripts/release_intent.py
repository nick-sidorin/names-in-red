"""Validate a release trigger before resolving or executing any target source."""
import json
import os
import re
from pathlib import Path
import subprocess
import sys

REPO = "nick-sidorin/names-in-red"
OWNER = "nick-sidorin"
REQUEST = ".github/release-request.json"


def parse_intent(repository, actor, triggering_actor, event_name, ref, event, request=None):
    if (repository, actor, triggering_actor) != (REPO, OWNER, OWNER):
        raise ValueError("Only the repository owner may initiate or retry publication")
    if event_name == "push" and event.get("deleted") is not False:
        raise ValueError("Not a live push")
    if event_name == "push" and ref.startswith("refs/tags/"):
        tag = ref.removeprefix("refs/tags/")
        if not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+", tag):
            raise ValueError("Expected a stable version tag")
        return tag[1:], None, "tag"
    if ref != "refs/heads/main":
        raise ValueError("Release requests must run on main")
    if event_name == "workflow_dispatch":
        request = event.get("inputs")
    elif event_name != "push":
        raise ValueError("Unexpected release trigger")
    if not isinstance(request, dict) or set(request) != {"version", "commit"}:
        raise ValueError("Request must contain only version and commit")
    version, commit = request["version"], request["commit"]
    if not isinstance(version, str) or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ValueError("Expected stable major.minor.patch version")
    if not isinstance(commit, str) or not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("Expected exact lowercase commit SHA")
    return version, commit, "request"


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def load_request():
    # A request is an explicit, separate main commit, never an ordinary code
    # merge, and never a persistent instruction executed on later pushes.
    if git("diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD^", "HEAD") != REQUEST:
        raise ValueError("The main push must change only the release request")
    return json.loads(git("show", "HEAD:" + REQUEST))


def main():
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
    args = [os.environ[k] for k in ("GITHUB_REPOSITORY", "GITHUB_ACTOR",
            "RELEASE_TRIGGERING_ACTOR", "GITHUB_EVENT_NAME", "GITHUB_REF")]
    request = load_request() if args[3:] == ["push", "refs/heads/main"] else None
    version, commit, mode = parse_intent(*args, event, request)
    if git("rev-parse", "HEAD") != git("rev-parse", os.environ["GITHUB_SHA"] + "^{commit}"):
        raise ValueError("Checkout differs from trigger commit")
    if mode == "tag":
        commit = git("rev-parse", f"refs/tags/v{version}^{{commit}}")
        if commit != git("rev-parse", "HEAD"):
            raise ValueError("Tag differs from trigger commit")
    # No user-supplied data reaches shell code; values are strictly validated.
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        print(f"version={version}\ncommit={commit}\nmode={mode}", file=output)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, subprocess.CalledProcessError, KeyError) as error:
        sys.exit(str(error))
