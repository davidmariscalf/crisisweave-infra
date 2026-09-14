#!/bin/sh
set -eu

cd "$(dirname "$0")"
umask 077

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl is required to generate local secret files" >&2
  exit 1
fi

mkdir -p secrets
chmod 700 secrets

create_secret() {
  path="$1"
  if [ ! -s "$path" ]; then
    openssl rand -hex 32 > "$path"
    chmod 600 "$path"
    echo "created $path"
  else
    chmod 600 "$path"
    echo "kept existing $path"
  fi
}

create_secret secrets/cw_token_pepper
create_secret secrets/cw_worksites_token

if [ ! -f .env ]; then
  cp .env.example .env
  chmod 600 .env
  echo "created .env from .env.example"
else
  chmod 600 .env
  echo "kept existing .env"
fi

cat <<'EOF'
Initialization complete.

Next:
1. Edit deploy/stack/.env and set CW_API_HOST to the DNS name that points at this server.
2. Run: docker compose up -d --build
3. Run: ./verify.sh

Secret values were written only to deploy/stack/secrets/ and were not printed.
EOF
