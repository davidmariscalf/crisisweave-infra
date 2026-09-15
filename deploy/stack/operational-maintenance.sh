#!/bin/sh
set -eu

cd "$(dirname "$0")"

mode="dry-run"
if [ "${1:-}" = "--apply-retention" ]; then
  mode="apply"
elif [ -n "${1:-}" ]; then
  echo "usage: sh operational-maintenance.sh [--apply-retention]" >&2
  exit 2
fi

if [ ! -f .env ]; then
  echo "deploy/stack/.env is missing" >&2
  exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required" >&2
  exit 1
fi

read_numeric_env() {
  key="$1"
  fallback="$2"
  value="$(sed -n "s/^${key}=//p" .env | tail -n 1)"
  [ -n "$value" ] || value="$fallback"
  case "$value" in
    *[!0-9]*|'') echo "${key} must be a positive integer" >&2; exit 1 ;;
  esac
  if [ "$value" -lt 1 ] || [ "$value" -gt 3650 ]; then
    echo "${key} must be between 1 and 3650" >&2
    exit 1
  fi
  printf '%s' "$value"
}

private_days="$(read_numeric_env CW_DATA_RETENTION_DAYS 90)"
credential_days="$(read_numeric_env CW_TOKEN_RETENTION_DAYS 30)"

printf '%s\n' 'Checking platform audit immutability before maintenance...'
docker compose exec -T platform python audit_guard.py verify >/dev/null
printf '%s\n' 'Checking worksite audit immutability before maintenance...'
docker compose exec -T worksites python audit_guard.py verify >/dev/null

printf '%s\n' "Private-data retention report (${private_days} days) and credential retention (${credential_days} days):"
if [ "$mode" = "apply" ]; then
  docker compose exec -T platform sh -c \
    'python maintenance.py --db "$CW_DB" --private-db "$CW_PRIVATE_DB" --pepper "$CW_TOKEN_PEPPER" --private-retention-days '"$private_days"' --token-retention-days '"$credential_days"' --apply'
else
  docker compose exec -T platform sh -c \
    'python maintenance.py --db "$CW_DB" --private-db "$CW_PRIVATE_DB" --pepper "$CW_TOKEN_PEPPER" --private-retention-days '"$private_days"' --token-retention-days '"$credential_days"''
fi

printf '%s\n' 'Open-work freshness report:'
docker compose exec -T worksites python staleness.py --db /data/worksites.db

printf '%s\n' 'Rechecking audit immutability after maintenance...'
docker compose exec -T platform python audit_guard.py verify >/dev/null
docker compose exec -T worksites python audit_guard.py verify >/dev/null

if [ "$mode" = "apply" ]; then
  echo 'Retention maintenance applied. Review output and create/verify an off-host backup according to policy.'
else
  echo 'Dry run complete. No records were deleted. Use --apply-retention only after reviewing the report.'
fi
