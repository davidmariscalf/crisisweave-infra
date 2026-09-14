# CrisisWeave one-command backend stack

This directory deploys the current backend boundary with Docker Compose:

- `crisisweave-worksites` on a private application network
- `crisisweave-platform` on private application + monitoring networks
- Caddy as the only public HTTP/TLS edge
- Prometheus + blackbox_exporter on a private monitoring network

No application database port, worksite port, platform port or metrics endpoint is published to the internet. Only Caddy publishes 80/443. Prometheus is bound to `127.0.0.1` for operator access.

## Prerequisites

- Linux host or VPS
- Docker Engine with the Compose plugin
- Git
- OpenSSL
- DNS A/AAAA record for the API hostname pointing to the server
- inbound TCP 80/443 (and UDP 443 if HTTP/3 is desired)

The host storage used by Docker volumes should be encrypted. Docker named volumes do not provide encryption by themselves.

## First deployment

```bash
git clone https://github.com/davidmariscalf/crisisweave-infra.git
cd crisisweave-infra/deploy/stack
sh init.sh
```

Edit `.env` and set:

```text
CW_API_HOST=api.example.org
```

Then deploy and verify:

```bash
docker compose up -d --build
sh verify.sh
```

The initializer generates two random 256-bit values inside the ignored, mode-0600 local `.env` file and never prints them. Do not send that file through chat, email, issues, logs or Git. Docker administrators can inspect container environment variables and should therefore be treated as privileged host administrators; move runtime secrets to OpenBao or an equivalent secret manager for a real production deployment.

## First administrator

The stack intentionally ships with no universal/default account or token. After the host is under operator control, bootstrap the first organisation and administrator explicitly:

```bash
sh bootstrap-admin.sh relief-org "Relief Organisation" admin-1 "Initial Administrator"
```

The helper creates the organisation and admin through the platform CLI and issues an 8-hour bearer token. That token is shown once in the server terminal; store it in an appropriate secret/password manager and do not put it in source control or chat.

## Runtime hardening

The application servers have bounded HTTP worker pools and socket timeouts so slow or bursty clients cannot create an unlimited number of threads. The production worksite runtime requires its internal bearer token for every operational read/write; only `/api/health` is left unauthenticated for orchestration probes.

Caddy is the only public proxy. `CW_TRUST_PROXY=1` is set only on the platform instance isolated behind that Caddy boundary, allowing rate limiting to use a validated forwarded client IP without trusting arbitrary forwarded headers in standalone deployments.

The Compose file also applies process limits, memory ceilings, read-only root filesystems, dropped Linux capabilities and Docker JSON-log rotation. Defaults are intentionally conservative for a small/free VM and can be adjusted through the documented `.env` variables after measuring real load.

## Monitoring and alerts

Prometheus is available only from the host at `http://127.0.0.1:9090` by default. The public Caddy route returns 404 for `/metrics`.

The platform exports only low-cardinality operational metrics. It does not put user IDs, organisation IDs, worksite IDs, bearer tokens, source URLs or filesystem paths into metric labels. The stack monitors database health, worksite reachability, HTTP errors, worker capacity and free data-volume space.

`alerts.yml` contains internal Prometheus rules for:

- platform/private SQLite health failure
- worksite service outage
- less than 10 percent data-volume space free
- repeated platform 5xx errors
- failure of the internal Caddy readiness probe

These rules create Prometheus alert states only. **They do not send notifications by themselves.** Notification delivery still requires Alertmanager or another explicitly configured receiver.

## Verified backups and restore drills

Create an online backup while services remain running:

```bash
backup_dir="$(sh backup.sh)"
echo "$backup_dir"
```

`backup.sh` uses SQLite's online backup API for `platform.db`, `private.db` and `worksites.db`, runs `PRAGMA integrity_check`, writes SHA256 checksums and records the pinned application revisions. The three database files are individually transactionally valid snapshots; they are not presented as a distributed cross-service transaction.

Test a backup without touching live data:

```bash
sh restore-drill.sh "$backup_dir"
```

The drill verifies every SHA256 and opens each SQLite snapshot read-only before running another integrity check. It deliberately never writes into live Docker volumes.

Copy verified backups off-host and encrypt them. The separate Litestream/restic profiles remain the recommended continuous/off-host disaster-recovery layer. A backup that has never passed a restore drill should not be treated as proven recoverable.

## Updates

The application build contexts are pinned to reviewed Git commit SHAs in `compose.yaml`. To upgrade, update the pinned refs deliberately, run CI, then:

```bash
docker compose build --pull
docker compose up -d
sh verify.sh
```

CI builds the pinned application revisions, starts the complete stack, validates Prometheus configuration/rules, runs readiness checks, makes a real three-database backup and performs the non-destructive restore drill before the deployment baseline is considered green.

## Operations

```bash
docker compose ps
docker compose logs --tail=100 caddy
docker compose logs --tail=100 platform
docker compose logs --tail=100 worksites
```

External IdP/MFA (authentik/oauth2-proxy) and OpenBao are intentionally not forced into this base stack because they require organisation-specific bootstrap and recovery procedures. Add them before accepting real sensitive data in a production humanitarian deployment.
