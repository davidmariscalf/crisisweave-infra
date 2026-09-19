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

# Seal both ordered audit histories independently of SQLite page layout.
python3 - "$out/platform.sqlite3" "$out/worksites.sqlite3" "$out/AUDIT_SEALS.json" <<'PY'
import hashlib
import json
import sqlite3
import sys
from pathlib import Path

platform_path, worksites_path, destination = map(Path, sys.argv[1:])


def chain(path: Path, query: str) -> dict:
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

seal = {
    "format": "crisisweave-audit-chains-v1",
    "platform": chain(
        platform_path,
        "SELECT seq,at,organisation_id,principal_id,action,target,outcome,details FROM audit ORDER BY seq",
    ),
    "worksites": chain(
        worksites_path,
        "SELECT seq,worksite_id,at,actor,action,from_state,to_state,note,details FROM audit ORDER BY seq",
    ),
}
destination.write_text(json.dumps(seal, sort_keys=True, indent=2) + "\n", encoding="utf-8")
PY

(
  cd "$out"
  sha256sum platform.sqlite3 private.sqlite3 worksites.sqlite3 AUDIT_SEALS.json > SHA256SUMS
)
chmod 600 "$out"/*.sqlite3 "$out/AUDIT_SEALS.json" "$out/SHA256SUMS"

platform_commit="$(python3 -c 'import json; print(json.load(open("release-pins.json", encoding="utf-8"))["platform"]["commit"])')"
worksites_commit="$(python3 -c 'import json; print(json.load(open("release-pins.json", encoding="utf-8"))["worksites"]["commit"])')"

cat > "$out/METADATA" <<EOF
created_at=$stamp
format=crisisweave-stack-backup-v3
platform_commit=$platform_commit
worksites_commit=$worksites_commit
audit_seals=AUDIT_SEALS.json
EOF
chmod 600 "$out/METADATA"

printf '%s\n' "$out"
