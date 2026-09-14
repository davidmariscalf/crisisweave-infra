#!/bin/sh
set -eu

cd "$(dirname "$0")"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required" >&2
  exit 1
fi

printf '%s\n' 'Checking container state...'
docker compose ps

printf '%s\n' 'Checking worksites health and internal authentication boundary...'
docker compose exec -T worksites python - <<'PY'
import json
import os
import urllib.error
import urllib.request

base = 'http://127.0.0.1:8787'
with urllib.request.urlopen(base + '/api/health', timeout=3) as r:
    data = json.load(r)
    assert r.status == 200 and data.get('ok')

try:
    urllib.request.urlopen(base + '/api/worksites', timeout=3)
except urllib.error.HTTPError as exc:
    assert exc.code == 401, exc.code
else:
    raise AssertionError('operational worksites read succeeded without internal token')

request = urllib.request.Request(
    base + '/api/worksites',
    headers={'Authorization': 'Bearer ' + os.environ['CW_COORDINATOR_TOKEN']},
)
with urllib.request.urlopen(request, timeout=3) as r:
    assert r.status == 200
    payload = json.load(r)
    assert isinstance(payload.get('worksites'), list)
print('worksites auth boundary: ok')
PY

printf '%s\n' 'Checking platform health/readiness/metrics from its private container...'
docker compose exec -T platform python - <<'PY'
import urllib.request

for path in ('/healthz', '/readyz'):
    with urllib.request.urlopen('http://127.0.0.1:8080' + path, timeout=3) as r:
        assert r.status == 200
        assert r.read()
        print(path + ': ok')

with urllib.request.urlopen('http://127.0.0.1:8080/metrics', timeout=3) as r:
    assert r.status == 200
    text = r.read().decode('utf-8')
    assert 'crisisweave_platform_data_volume_free_ratio ' in text
    assert 'crisisweave_platform_http_worker_limit ' in text
    for forbidden in ('principal=', 'organisation=', 'worksite=', 'token=', 'path='):
        assert forbidden not in text
    assert '/data/' not in text
print('/metrics: ok')
PY

printf '%s\n' 'Checking audit immutability guards...'
docker compose exec -T platform python audit_guard.py verify >/dev/null

printf '%s\n' 'Checking internal Caddy readiness and metrics isolation...'
docker compose exec -T caddy wget -q -O /dev/null http://127.0.0.1:8081/healthz
if docker compose exec -T caddy wget -q -O /dev/null http://127.0.0.1:8081/metrics 2>/dev/null; then
  echo 'Caddy unexpectedly exposed /metrics' >&2
  exit 1
fi

printf '%s\n' 'Checking Prometheus runtime health...'
docker compose exec -T prometheus /bin/promtool check config /etc/prometheus/prometheus.yml >/dev/null

echo 'CrisisWeave stack verification passed.'
