from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "build-site.py"

spec = importlib.util.spec_from_file_location("build_site", SCRIPT)
build_site = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(build_site)


class BuildSiteTests(unittest.TestCase):
    def test_build_stamps_revision_without_mutating_source(self):
        revision = "a" * 40
        source_health = (ROOT / "site" / "health.json").read_text(encoding="utf-8")

        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "dist"
            build_site.build(output, revision)

            metadata = json.loads((output / "build.json").read_text(encoding="utf-8"))
            health = json.loads((output / "health.json").read_text(encoding="utf-8"))

            self.assertEqual(metadata["source_revision"], revision)
            self.assertEqual(
                metadata["source_repository"],
                "https://github.com/davidmariscalf/crisisweave-infra",
            )
            self.assertEqual(health["source_revision"], revision)
            self.assertTrue((output / "index.html").is_file())
            self.assertEqual(
                (ROOT / "site" / "health.json").read_text(encoding="utf-8"),
                source_health,
            )

    def test_explicit_revision_must_be_full_sha(self):
        self.assertEqual(build_site.detect_revision("b" * 40), "b" * 40)


if __name__ == "__main__":
    unittest.main()
