#!/bin/sh
set -eu

cd "$(dirname "$0")"
umask 077

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl is required to generate local secrets" >&2
  exit 1
fi

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

cat <<'EOF'
Initialization complete.

Next:
1. Edit deploy/stack/.env and set CW_API_HOST to the DNS name that points at this server.
2. Run: docker compose up -d --build
3. Run: sh verify.sh

Secret values remain only in the ignored, mode-0600 deploy/stack/.env file and were not printed.
EOF
