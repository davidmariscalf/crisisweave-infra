#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 BACKUP_DIRECTORY" >&2
  exit 2
fi

backup="$1"
for file in platform.sqlite3 private.sqlite3 worksites.sqlite3 AUDIT_SEALS.json SHA256SUMS METADATA; do
  if [ ! -f "$backup/$file" ]; then
    echo "missing backup file: $file" >&2
    exit 1
  fi
done

(
  cd "$backup"
  sha256sum -c SHA256SUMS
)

python3 - "$backup" <<'PY'
import hashlib
import json
import pathlib
import sqlite3
import sys

root = pathlib.Path(sys.argv[1])
for name in ("platform.sqlite3", "private.sqlite3", "worksites.sqlite3"):
    path = root / name
    con = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    try:
        result = con.execute("PRAGMA integrity_check").fetchone()[0]
        if result != "ok":
            raise SystemExit(f"{name}: integrity_check failed: {result}")
    finally:
        con.close()
    print(f"{name}: ok")


def verify_triggers(path: pathlib.Path, label: str) -> None:
    con = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    try:
        triggers = {
            r[0]
            for r in con.execute(
                "SELECT name FROM sqlite_master WHERE type='trigger' AND name IN ('audit_no_update','audit_no_delete')"
            )
        }
    finally:
        con.close()
    if triggers != {"audit_no_update", "audit_no_delete"}:
        raise SystemExit(f"{label} backup is missing audit immutability triggers")


def chain(path: pathlib.Path, query: str) -> dict:
    con = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    try:
        rows = con.execute(query).fetchall()
    finally:
        con.close()
    head = bytes(32)
    for row in rows:
        item = dict(row)
        if "details" in item:
            try:
                item["details"] = json.loads(item["details"])
            except json.JSONDecodeError as exc:
                raise SystemExit(f"audit row {item.get('seq')} contains invalid details JSON") from exc
        encoded = json.dumps(item, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        head = hashlib.sha256(head + b"\n" + encoded).digest()
    return {"rows": len(rows), "head_sha256": head.hex()}

platform = root / "platform.sqlite3"
worksites = root / "worksites.sqlite3"
verify_triggers(platform, "platform")
verify_triggers(worksites, "worksites")
expected = {
    "format": "crisisweave-audit-chains-v1",
    "platform": chain(
        platform,
        "SELECT seq,at,organisation_id,principal_id,action,target,outcome,details FROM audit ORDER BY seq",
    ),
    "worksites": chain(
        worksites,
        "SELECT seq,worksite_id,at,actor,action,from_state,to_state,note,details FROM audit ORDER BY seq",
    ),
}
actual = json.loads((root / "AUDIT_SEALS.json").read_text(encoding="utf-8"))
if actual != expected:
    raise SystemExit("audit seal mismatch")
print(
    "audit seals: ok "
    f"(platform={expected['platform']['rows']} rows, worksites={expected['worksites']['rows']} rows)"
)
PY

# This script intentionally never writes into live Docker volumes. A real
# restoration must be a separate, explicit maintenance operation after the
# operator has selected the exact backup and stopped application writers.
echo "restore drill passed; live data was not modified"
