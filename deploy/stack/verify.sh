#!/bin/sh
set -eu

cd "$(dirname "$0")"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required" >&2
  exit 1
fi

printf '%s\n' 'Checking container state...'
docker compose ps

printf '%s\n' 'Checking worksites health from its private container...'
docker compose exec -T worksites python - <<'PY'
import json, urllib.request
with urllib.request.urlopen('http://127.0.0.1:8787/api/health', timeout=3) as r:
    data = json.load(r)
    assert r.status == 200 and data.get('ok')
print('worksites: ok')
PY

printf '%s\n' 'Checking platform health/readiness/metrics from its private container...'
docker compose exec -T platform python - <<'PY'
import urllib.request
for path in ('/healthz', '/readyz', '/metrics'):
    with urllib.request.urlopen('http://127.0.0.1:8080' + path, timeout=3) as r:
        assert r.status == 200
        body = r.read()
        assert body
        print(path + ': ok')
PY

printf '%s\n' 'Checking internal Caddy readiness route...'
docker compose exec -T caddy wget -q -O /dev/null http://127.0.0.1:8081/healthz

echo 'CrisisWeave stack verification passed.'
