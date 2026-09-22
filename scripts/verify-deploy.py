#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import urllib.parse
import urllib.request

SHA40 = re.compile(r"^[0-9a-f]{40}$")
EXPECTED_REPOSITORY = "https://github.com/davidmariscalf/crisisweave-infra"


def load_json(base_url: str, path: str) -> dict:
    url = urllib.parse.urljoin(base_url.rstrip("/") + "/", path.lstrip("/"))
    request = urllib.request.Request(url, headers={"User-Agent": "CrisisWeave-deploy-verifier/1"})
    with urllib.request.urlopen(request, timeout=20) as response:
        if response.status != 200:
            raise RuntimeError(f"{url} returned HTTP {response.status}")
        return json.load(response)


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify a deployed CrisisWeave public site's provenance metadata")
    parser.add_argument("url", help="Public site URL, for example https://crisisweave.netlify.app")
    parser.add_argument("--expected-revision", help="Expected 40-character crisisweave-infra Git SHA")
    args = parser.parse_args()

    build = load_json(args.url, "build.json")
    health = load_json(args.url, "health.json")
    revision = str(build.get("source_revision", "")).lower()

    if not SHA40.fullmatch(revision):
        raise RuntimeError("build.json does not contain a valid 40-character source_revision")
    if build.get("service") != "crisisweave-public-site":
        raise RuntimeError("unexpected service in build.json")
    if build.get("source_repository") != EXPECTED_REPOSITORY:
        raise RuntimeError("unexpected source_repository in build.json")
    if health.get("source_revision") != revision:
        raise RuntimeError("build.json and health.json source revisions differ")
    if health.get("status") != "ok" or health.get("synthetic_demo_only") is not True:
        raise RuntimeError("health.json does not describe the expected synthetic public site")

    if args.expected_revision:
        expected = args.expected_revision.strip().lower()
        if not SHA40.fullmatch(expected):
            raise RuntimeError("--expected-revision must be a 40-character lowercase hexadecimal SHA")
        if revision != expected:
            raise RuntimeError(f"deployed revision {revision} does not match expected revision {expected}")

    print(json.dumps({"ok": True, "url": args.url.rstrip("/"), "source_revision": revision}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
