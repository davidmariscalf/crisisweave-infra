#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 BACKUP_DIRECTORY" >&2
  exit 2
fi

backup="$1"
for file in platform.sqlite3 private.sqlite3 worksites.sqlite3 SHA256SUMS METADATA; do
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
PY

# This script intentionally never writes into live Docker volumes. A real
# restoration must be a separate, explicit maintenance operation after the
# operator has selected the exact backup and stopped application writers.
echo "restore drill passed; live data was not modified"
