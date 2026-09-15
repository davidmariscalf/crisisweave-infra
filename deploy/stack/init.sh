#!/bin/sh
set -eu

cd "$(dirname "$0")"
umask 077

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl is required to generate local secrets" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
  echo "Python 3 is required for production configuration checks" >&2
  exit 1
fi
PYTHON_BIN="$(command -v python3 || command -v python)"

if [ ! -f .env ]; then
  cp .env.example .env
  chmod 600 .env
  echo "created .env from .env.example"
else
  chmod 600 .env
  echo "kept existing .env"
fi

set_secret() {
  key="$1"
  if grep -Eq "^${key}=.+$" .env; then
    echo "kept existing ${key}"
    return
  fi
  value="$(openssl rand -hex 32)"
  tmp=".env.tmp.$$"
  grep -v "^${key}=" .env > "$tmp" || true
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  chmod 600 "$tmp"
  mv "$tmp" .env
  echo "generated ${key}"
}

set_secret CW_TOKEN_PEPPER
set_secret CW_WORKSITES_TOKEN

if grep -Eq '^CW_ALERT_WEBHOOK_URL=https://.+' .env; then
  "$PYTHON_BIN" generate-alertmanager-config.py
else
  echo "alert delivery is not configured yet; set CW_ALERT_WEBHOOK_URL before production go-live"
fi

cat <<'EOF'
Initialization complete.

Next:
1. Edit deploy/stack/.env and set the deployment, DNS, alerting, backup and ownership values.
2. For production, run: python3 generate-alertmanager-config.py
3. Run: docker compose up -d --build
4. Run: sh verify.sh
5. Before accepting real traffic, run: python3 go-live-check.py

Secret values remain only in ignored, mode-0600 local files and were not printed.
EOF
