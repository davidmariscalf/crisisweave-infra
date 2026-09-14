#!/bin/sh
set -eu

cd "$(dirname "$0")"
umask 077

root="${1:-./backups}"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
out="$root/$stamp"
mkdir -p "$out"

platform_id="$(docker compose ps -q platform)"
worksites_id="$(docker compose ps -q worksites)"

if [ -z "$platform_id" ] || [ -z "$worksites_id" ]; then
  echo "platform and worksites must be running" >&2
  exit 1
fi

platform_tmp="/data/.cw-backup-platform-$stamp.sqlite3"
private_tmp="/data/.cw-backup-private-$stamp.sqlite3"
worksites_tmp="/data/.cw-backup-worksites-$stamp.sqlite3"

cleanup() {
  docker compose exec -T platform rm -f "$platform_tmp" "$private_tmp" >/dev/null 2>&1 || true
  docker compose exec -T worksites rm -f "$worksites_tmp" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

# SQLite's online backup API produces transactionally valid snapshots while the
# services stay available. Each database is backed up independently; this is a
# disaster-recovery snapshot, not a cross-service distributed transaction.
docker compose exec -T \
  -e CW_BACKUP_PLATFORM="$platform_tmp" \
  -e CW_BACKUP_PRIVATE="$private_tmp" \
  platform python - <<'PY'
import os
import sqlite3

for src_path, dst_path in (
    ("/data/platform.db", os.environ["CW_BACKUP_PLATFORM"]),
    ("/data/private.db", os.environ["CW_BACKUP_PRIVATE"]),
):
    src = sqlite3.connect(src_path, timeout=10)
    dst = sqlite3.connect(dst_path)
    try:
        src.backup(dst)
        result = dst.execute("PRAGMA integrity_check").fetchone()[0]
        if result != "ok":
            raise SystemExit(f"integrity_check failed for {src_path}: {result}")
    finally:
        dst.close()
        src.close()
PY

docker compose exec -T \
  -e CW_BACKUP_WORKSITES="$worksites_tmp" \
  worksites python - <<'PY'
import os
import sqlite3

src = sqlite3.connect("/data/worksites.db", timeout=10)
dst = sqlite3.connect(os.environ["CW_BACKUP_WORKSITES"])
try:
    src.backup(dst)
    result = dst.execute("PRAGMA integrity_check").fetchone()[0]
    if result != "ok":
        raise SystemExit(f"integrity_check failed for worksites: {result}")
finally:
    dst.close()
    src.close()
PY

docker cp "$platform_id:$platform_tmp" "$out/platform.sqlite3" >/dev/null
docker cp "$platform_id:$private_tmp" "$out/private.sqlite3" >/dev/null
docker cp "$worksites_id:$worksites_tmp" "$out/worksites.sqlite3" >/dev/null

cleanup
trap - EXIT INT TERM

# Seal the ordered audit history independently of SQLite page layout. Details
# are parsed and canonicalised so semantically identical JSON has one encoding.
python3 - "$out/platform.sqlite3" "$out/AUDIT_SEAL.json" <<'PY'
import hashlib
import json
import sqlite3
import sys
from pathlib import Path

source, destination = map(Path, sys.argv[1:])
con = sqlite3.connect(f"file:{source}?mode=ro", uri=True)
con.row_factory = sqlite3.Row
try:
    rows = con.execute(
        "SELECT seq,at,organisation_id,principal_id,action,target,outcome,details "
        "FROM audit ORDER BY seq"
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

seal = {
    "format": "crisisweave-audit-chain-v1",
    "rows": len(rows),
    "head_sha256": head.hex(),
}
destination.write_text(json.dumps(seal, sort_keys=True, indent=2) + "\n", encoding="utf-8")
PY

(
  cd "$out"
  sha256sum platform.sqlite3 private.sqlite3 worksites.sqlite3 AUDIT_SEAL.json > SHA256SUMS
)
chmod 600 "$out"/*.sqlite3 "$out/AUDIT_SEAL.json" "$out/SHA256SUMS"

cat > "$out/METADATA" <<EOF
created_at=$stamp
format=crisisweave-stack-backup-v2
platform_commit=9e7aa0d2aaaf2ecb36688e1632e50da4c1218563
worksites_commit=cd8e4c99602fea231b7b9209f2f2a0139645f93e
audit_seal=AUDIT_SEAL.json
EOF
chmod 600 "$out/METADATA"

printf '%s\n' "$out"
