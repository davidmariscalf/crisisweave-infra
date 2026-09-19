#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SHA40 = re.compile(r"^[0-9a-f]{40}$")


def main() -> int:
    pins = json.loads((ROOT / "release-pins.json").read_text(encoding="utf-8"))
    if pins.get("schema_version") != 1:
        raise SystemExit("unsupported release-pins.json schema")

    expected = {}
    for name in ("worksites", "platform"):
        entry = pins.get(name) or {}
        repo = str(entry.get("repository") or "")
        commit = str(entry.get("commit") or "")
        if not repo.startswith("davidmariscalf/crisisweave-") or not SHA40.fullmatch(commit):
            raise SystemExit(f"invalid {name} release pin")
        expected[name] = (repo, commit)

    compose = (ROOT / "compose.yaml").read_text(encoding="utf-8")
    env_example = (ROOT / ".env.example").read_text(encoding="utf-8")
    for name, (repo, commit) in expected.items():
        context = f"https://github.com/{repo}.git#{commit}"
        if context not in compose:
            raise SystemExit(f"compose.yaml does not use canonical {name} pin {commit}")
        if context not in env_example:
            raise SystemExit(f".env.example does not document canonical {name} pin {commit}")

    backup = (ROOT / "backup.sh").read_text(encoding="utf-8")
    if 'open("release-pins.json"' not in backup:
        raise SystemExit("backup.sh does not read canonical release pins")
    for key in ("platform_commit=$platform_commit", "worksites_commit=$worksites_commit"):
        if key not in backup:
            raise SystemExit(f"backup metadata is missing {key}")
    if re.search(r"^(?:platform|worksites)_commit=[0-9a-f]{40}$", backup, re.MULTILINE):
        raise SystemExit("backup.sh contains a legacy hard-coded application revision")

    bootstrap = (ROOT / "bootstrap-admin.sh").read_text(encoding="utf-8")
    if "crisisweave_platform.py bootstrap" not in bootstrap:
        raise SystemExit("bootstrap-admin.sh does not use atomic platform bootstrap")

    print(json.dumps({
        "ok": True,
        "platform": expected["platform"][1],
        "worksites": expected["worksites"][1],
        "backup_metadata": "canonical",
        "bootstrap": "atomic",
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
