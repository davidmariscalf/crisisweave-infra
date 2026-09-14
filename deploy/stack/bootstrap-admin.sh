#!/bin/sh
set -eu

cd "$(dirname "$0")"

if [ "$#" -ne 4 ]; then
  cat >&2 <<'EOF'
Usage:
  sh bootstrap-admin.sh ORG_ID "Organisation Name" ADMIN_ID "Administrator Name"

Example identifiers must use letters, numbers, dot, underscore, colon or hyphen.
The issued bearer token is printed once to this terminal. Store it securely and do not put it in Git, chat, email or logs.
EOF
  exit 2
fi

org_id="$1"
org_name="$2"
admin_id="$3"
admin_name="$4"

for required in docker; do
  command -v "$required" >/dev/null 2>&1 || { echo "$required is required" >&2; exit 1; }
done

docker compose exec -T platform python crisisweave_platform.py create-org "$org_id" "$org_name"
docker compose exec -T platform python crisisweave_platform.py create-principal "$admin_id" --org "$org_id" --name "$admin_name" --role admin

printf '%s\n' 'Administrator created. The next JSON contains the bearer token once:'
docker compose exec -T platform python crisisweave_platform.py issue-token "$admin_id" --ttl-hours 8
