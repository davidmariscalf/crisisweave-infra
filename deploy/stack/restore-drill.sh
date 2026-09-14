#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 BACKUP_DIRECTORY" >&2
  exit 2
fi

backup="$1"
for file in platform.sqlite3 private.sqlite3 worksites.sqlite3 AUDIT_SEAL.json SHA256SUMS METADATA; do
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

platform = root / "platform.sqlite3"
con = sqlite3.connect(f"file:{platform}?mode=ro", uri=True)
con.row_factory = sqlite3.Row
try:
    triggers = {
        r[0]
        for r in con.execute(
            "SELECT name FROM sqlite_master WHERE type='trigger' AND name IN ('audit_no_update','audit_no_delete')"
        )
    }
    if triggers != {"audit_no_update", "audit_no_delete"}:
        raise SystemExit("platform backup is missing audit immutability triggers")
    rows = con.execute(
        "SELECT seq,at,organisation_id,principal_id,action,target,outcome,details FROM audit ORDER BY seq"
    ).fetchall()
finally:
    con.close()

head = bytes(32)
for row in rows:
    item = dict(row)
    try:
        item["details"] = json.loads(item["details"])
    except json.JSONDecodeError as exc:
        raise SystemExit(f"audit row {item['seq']} contains invalid details JSON") from exc
    encoded = json.dumps(item, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    head = hashlib.sha256(head + b"\n" + encoded).digest()

seal = json.loads((root / "AUDIT_SEAL.json").read_text(encoding="utf-8"))
expected = {
    "format": "crisisweave-audit-chain-v1",
    "rows": len(rows),
    "head_sha256": head.hex(),
}
if seal != expected:
    raise SystemExit("audit seal mismatch")
print(f"audit seal: ok ({len(rows)} rows)")
PY

# This script intentionally never writes into live Docker volumes. A real
# restoration must be a separate, explicit maintenance operation after the
# operator has selected the exact backup and stopped application writers.
echo "restore drill passed; live data was not modified"
