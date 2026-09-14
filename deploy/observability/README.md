# Observability profile

Prometheus plus blackbox_exporter is the recommended minimum central monitoring profile for a deployed CrisisWeave backend. Versions are pinned in `../../ecosystem/components.lock.json`. This profile is not currently deployed by the public Netlify site.

## What to monitor

External probes:

- public project site
- backend TLS endpoint
- `/healthz`
- `/readyz`
- certificate validity / DNS reachability

Application metrics, once the backend is deployed:

- total HTTP requests by status class
- authentication failures
- authorisation denials
- rate-limit responses
- upstream worksite failures
- platform process uptime
- database health/readiness

Do not label metrics with survivor IDs, worksite IDs, bearer-token prefixes, email addresses, source URLs, request bodies or arbitrary query strings. High-cardinality identifiers make monitoring less useful and can create a secondary privacy leak.

## Alert principles

Alert on conditions that require action, for example:

- public API probe failing for several consecutive intervals
- readiness failing while liveness still passes
- persistent 5xx/upstream failure increase
- backup/restore drill overdue
- repeated privileged authentication failures
- storage nearing capacity

Do not send sensitive request data into alert labels or messages.

## Existing public monitoring

GitHub Actions already performs secret-free checks of `crisisweave.netlify.app`. Prometheus is intended for the future backend/operational deployment, not as a replacement for those simple public checks.

## Files

- `blackbox.yml.example` defines safe HTTP probes.
- `prometheus.yml.example` shows a minimal scrape configuration with placeholder backend hostname.
