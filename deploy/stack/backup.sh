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

# SQLite's online backup API produces transactionally valid snapshots while the
# services stay available. Each database is backed up independently; this is a
# disaster-recovery snapshot, not a cross-service distributed transaction.
docker compose exec -T platform python - <<'PY'
import sqlite3
for src_path, dst_path in (
    ("/data/platform.db", "/tmp/cw-platform.sqlite3"),
    ("/data/private.db", "/tmp/cw-private.sqlite3"),
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

docker compose exec -T worksites python - <<'PY'
import sqlite3
src = sqlite3.connect("/data/worksites.db", timeout=10)
dst = sqlite3.connect("/tmp/cw-worksites.sqlite3")
try:
    src.backup(dst)
    result = dst.execute("PRAGMA integrity_check").fetchone()[0]
    if result != "ok":
        raise SystemExit(f"integrity_check failed for worksites: {result}")
finally:
    dst.close()
    src.close()
PY

docker cp "$platform_id:/tmp/cw-platform.sqlite3" "$out/platform.sqlite3" >/dev/null
docker cp "$platform_id:/tmp/cw-private.sqlite3" "$out/private.sqlite3" >/dev/null
docker cp "$worksites_id:/tmp/cw-worksites.sqlite3" "$out/worksites.sqlite3" >/dev/null

docker compose exec -T platform rm -f /tmp/cw-platform.sqlite3 /tmp/cw-private.sqlite3
docker compose exec -T worksites rm -f /tmp/cw-worksites.sqlite3

(
  cd "$out"
  sha256sum platform.sqlite3 private.sqlite3 worksites.sqlite3 > SHA256SUMS
)
chmod 600 "$out"/*.sqlite3 "$out/SHA256SUMS"

cat > "$out/METADATA" <<EOF
created_at=$stamp
format=crisisweave-stack-backup-v1
platform_commit=74ce5b52a1c9eedefdff992f7080b6532415213b
worksites_commit=7aababcccfb26ffe4e949835e7b4bf1183cee93a
EOF
chmod 600 "$out/METADATA"

printf '%s\n' "$out"
