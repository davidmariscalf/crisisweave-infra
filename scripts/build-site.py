#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "site"
SHA40 = re.compile(r"^[0-9a-f]{40}$")


def detect_revision(explicit: str | None = None) -> str:
    candidates = [
        explicit,
        os.getenv("COMMIT_REF"),
        os.getenv("GITHUB_SHA"),
    ]
    for value in candidates:
        value = (value or "").strip().lower()
        if SHA40.fullmatch(value):
            return value

    proc = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    value = proc.stdout.strip().lower()
    if proc.returncode == 0 and SHA40.fullmatch(value):
        return value
    raise RuntimeError("could not determine a 40-character source revision")


def build(output: Path, revision: str) -> None:
    if not SOURCE.is_dir():
        raise RuntimeError(f"missing site directory: {SOURCE}")
    if output.exists():
        shutil.rmtree(output)
    shutil.copytree(SOURCE, output)

    metadata = {
        "service": "crisisweave-public-site",
        "source_repository": "https://github.com/davidmariscalf/crisisweave-infra",
        "source_revision": revision,
    }
    (output / "build.json").write_text(
        json.dumps(metadata, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    health_path = output / "health.json"
    health = json.loads(health_path.read_text(encoding="utf-8"))
    health["source_revision"] = revision
    health_path.write_text(
        json.dumps(health, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a revision-stamped CrisisWeave public site")
    parser.add_argument("--output", type=Path, default=ROOT / "dist")
    parser.add_argument("--revision")
    args = parser.parse_args()

    revision = detect_revision(args.revision)
    build(args.output.resolve(), revision)
    print(json.dumps({"ok": True, "output": str(args.output.resolve()), "source_revision": revision}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
