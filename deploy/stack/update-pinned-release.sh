#!/bin/sh
set -eu

cd "$(dirname "$0")"

if [ "$#" -ne 1 ]; then
  echo "usage: $0 EXACT_INFRA_COMMIT_SHA" >&2
  exit 2
fi

target="$1"
case "$target" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *)
    echo "release target must be an exact lowercase 40-character Git commit SHA" >&2
    exit 2
    ;;
esac

for cmd in git docker python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "$cmd is required" >&2; exit 1; }
done

repo_root="$(git rev-parse --show-toplevel)"
expected_origin="https://github.com/davidmariscalf/crisisweave-infra.git"
origin="$(git -C "$repo_root" remote get-url origin)"
case "$origin" in
  "$expected_origin"|"https://github.com/davidmariscalf/crisisweave-infra"|"git@github.com:davidmariscalf/crisisweave-infra.git") ;;
  *)
    echo "refusing release from unexpected Git origin: $origin" >&2
    exit 1
    ;;
esac

if [ -n "$(git -C "$repo_root" status --porcelain --untracked-files=no)" ]; then
  echo "refusing update because tracked files have local modifications" >&2
  exit 1
fi

previous="$(git -C "$repo_root" rev-parse HEAD)"
if [ "$target" = "$previous" ]; then
  echo "release $target is already checked out"
  sh verify.sh
  exit 0
fi

# Fetch only repository-owned history and prove the target is on origin/main.
git -C "$repo_root" fetch --no-tags --prune --depth 256 origin main "$target"
actual="$(git -C "$repo_root" rev-parse "$target^{commit}")"
if [ "$actual" != "$target" ]; then
  echo "fetched object does not match requested release SHA" >&2
  exit 1
fi
if ! git -C "$repo_root" merge-base --is-ancestor "$target" origin/main; then
  echo "refusing commit that is not an ancestor of origin/main" >&2
  exit 1
fi

# Fail closed unless GitHub records a successful full backend-stack run for this
# exact commit. This is public metadata; no GitHub token is required or stored.
python3 - "$target" <<'PY'
import json
import sys
import urllib.request

sha = sys.argv[1]
url = (
    "https://api.github.com/repos/davidmariscalf/crisisweave-infra/actions/runs"
    f"?head_sha={sha}&per_page=50"
)
req = urllib.request.Request(
    url,
    headers={
        "Accept": "application/vnd.github+json",
        "User-Agent": "crisisweave-release-verifier/1",
    },
)
try:
    with urllib.request.urlopen(req, timeout=10) as response:
        data = json.load(response)
except Exception as exc:
    raise SystemExit(f"could not verify release CI metadata: {type(exc).__name__}") from exc

ok = any(
    run.get("name") == "backend-stack"
    and run.get("head_sha") == sha
    and run.get("status") == "completed"
    and run.get("conclusion") == "success"
    for run in data.get("workflow_runs", [])
)
if not ok:
    raise SystemExit("target commit has no successful backend-stack run")
print("release CI: verified")
PY

backup_root="${CW_PREUPDATE_BACKUP_ROOT:-$HOME/.local/share/crisisweave/pre-update-backups}"
mkdir -p "$backup_root"
chmod 700 "$backup_root" 2>/dev/null || true
backup_dir="$(sh backup.sh "$backup_root")"
sh restore-drill.sh "$backup_dir"

if [ -n "${CW_BACKUP_AGE_RECIPIENT:-}" ] && command -v age >/dev/null 2>&1; then
  offsite_root="${CW_PREUPDATE_OFFSITE_ROOT:-$HOME/.local/share/crisisweave/pre-update-offsite}"
  encrypted="$(sh prepare-offsite-backup.sh "$backup_dir" "$offsite_root")"
  echo "encrypted pre-update backup: $encrypted"
else
  echo "pre-update backup verified locally; encrypted off-host export was not configured"
fi

rollback() {
  echo "new release failed verification; rolling stack definition back to $previous" >&2
  git -C "$repo_root" checkout --detach --force "$previous" >/dev/null 2>&1 || true
  cd "$repo_root/deploy/stack" || exit 1
  docker compose up -d --build || true
  for _ in $(seq 1 30); do
    if sh verify.sh >/dev/null 2>&1; then
      echo "previous release restored and healthy" >&2
      return 0
    fi
    sleep 2
  done
  echo "automatic code rollback did not restore health; use the verified pre-update backup for manual recovery" >&2
  return 1
}

trap 'rollback; exit 1' INT TERM HUP

git -C "$repo_root" checkout --detach --force "$target"
cd "$repo_root/deploy/stack"

# The ignored local .env survives exact-commit checkout. Refuse to continue if
# it is absent rather than regenerating secrets during an update.
if [ ! -f .env ]; then
  echo "target release has no local .env; refusing to regenerate deployment secrets" >&2
  rollback
  exit 1
fi
chmod 600 .env

for helper in init.sh verify.sh bootstrap-admin.sh backup.sh restore-drill.sh prepare-offsite-backup.sh update-pinned-release.sh; do
  sh -n "$helper"
done

docker compose config >/dev/null
docker compose build --pull worksites platform
docker compose up -d

healthy=0
for _ in $(seq 1 30); do
  if sh verify.sh >/dev/null 2>&1; then
    healthy=1
    break
  fi
  sleep 2
done

if [ "$healthy" -ne 1 ]; then
  rollback
  exit 1
fi
trap - INT TERM HUP

printf '%s\n' "$target" > "$HOME/.crisisweave-applied-release"
chmod 600 "$HOME/.crisisweave-applied-release"
echo "release applied and verified: $target"
