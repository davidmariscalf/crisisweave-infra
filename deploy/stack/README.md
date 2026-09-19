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
- `age` when encrypted off-host backup export is enabled
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

The helper calls the platform's atomic `bootstrap` operation, so organisation, first admin and initial 8-hour bearer token are created in one transaction. If bootstrap fails, it does not leave a partial admin/token behind. The token is shown once in the server terminal; store it in an appropriate secret/password manager and do not put it in source control or chat.

## Runtime hardening

The application servers have bounded HTTP worker pools and socket timeouts so slow or bursty clients cannot create an unlimited number of threads. The production worksite runtime requires its internal bearer token for every operational read/write; only `/api/health` is left unauthenticated for orchestration probes.

Caddy is the only public proxy. `CW_TRUST_PROXY=1` is set only on the platform instance isolated behind that Caddy boundary, allowing rate limiting to use a validated forwarded client IP without trusting arbitrary forwarded headers in standalone deployments.

The Compose file also applies process limits, memory ceilings, read-only root filesystems, dropped Linux capabilities and Docker JSON-log rotation. Defaults are intentionally conservative for a small/free VM and can be adjusted through the documented `.env` variables after measuring real load.

## Monitoring and alerts

Prometheus is available only from the host at `http://127.0.0.1:9090` by default. The public Caddy route returns 404 for `/metrics`.

The platform exports only low-cardinality operational metrics. It does not put user IDs, organisation IDs, worksite IDs, bearer tokens, source URLs or filesystem paths into metric labels. The stack monitors database health, worksite reachability, HTTP errors, worker capacity and free data-volume space.

`alerts.yml` contains internal Prometheus rules for platform/private SQLite health failure, worksite service outage, low data-volume space, repeated platform 5xx errors and internal Caddy readiness failure. These rules create Prometheus alert states only. They do not send notifications by themselves; delivery still requires an explicitly configured Alertmanager or equivalent receiver.

## Verified backups and restore drills

Create an online backup while services remain running:

```bash
backup_dir="$(sh backup.sh)"
sh restore-drill.sh "$backup_dir"
```

`backup.sh` uses SQLite's online backup API for `platform.db`, `private.db` and `worksites.db`, runs `PRAGMA integrity_check`, writes SHA256 checksums, records the exact application revisions from `release-pins.json` and seals both ordered audit histories in `AUDIT_SEALS.json`. The three database files are individually transactionally valid snapshots; they are not presented as a distributed cross-service transaction.

`restore-drill.sh` verifies every file hash, both audit chains, required audit immutability triggers and SQLite integrity while opening the snapshots read-only. It deliberately never writes into live Docker volumes.

### Encrypted off-host export

Generate an `age` identity on a trusted device or recovery vault, not on the application server. Keep the private key off-host. Put only its public recipient on the server for the export command:

```bash
export CW_BACKUP_AGE_RECIPIENT='age1...public-recipient...'
encrypted="$(sh prepare-offsite-backup.sh "$backup_dir" /secure/offsite-staging)"
echo "$encrypted"
```

`prepare-offsite-backup.sh` refuses to export a backup until the full restore drill passes. It streams the verified backup set directly from `tar` into `age`, so it does not create a plaintext tar archive, and writes a SHA256 for the encrypted bundle. Move that encrypted file and checksum to genuinely separate storage. The public recipient is not a decryption secret; the corresponding `age` private identity must stay outside the CrisisWeave host and repository.

Litestream/restic remain useful for continuous or provider-specific replication. A local backup alone is not off-host recovery, and a backup that has never passed a restore drill should not be treated as proven recoverable.

## Verified updates

Application build contexts in `compose.yaml` are pinned to reviewed Git commit SHAs. `release-pins.json` is the canonical application revision manifest, and `check-release-pins.py` makes CI/runtime verification fail if Compose, override examples, backup metadata or the bootstrap helper drift from it. Do not deploy `main`, a branch name or a floating tag directly.

After a candidate infrastructure commit has a successful `backend-stack` GitHub Actions run, apply that exact 40-character SHA with:

```bash
sh update-pinned-release.sh <exact-40-character-infra-commit-sha>
```

The updater fails closed unless the target is an exact lowercase SHA in `origin/main` and public GitHub Actions metadata shows a successful `backend-stack` run for that exact commit. Before changing code it creates a verified pre-update backup; when `CW_BACKUP_AGE_RECIPIENT` is configured it also creates an encrypted export. It preserves the existing ignored `.env`, validates the target stack, builds the pinned application revisions, starts them and runs `verify.sh`.

If application of the new revision fails, the updater checks the previous infrastructure commit back out and rebuilds the previous stack definition. It deliberately does not overwrite databases automatically. If rollback cannot restore health, use the pre-update verified backup through an explicit maintenance/recovery procedure rather than an automatic destructive restore.

CI itself builds the pinned application revisions, starts the complete stack, validates Prometheus configuration and rules, runs readiness checks, creates a real three-database backup, performs the non-destructive restore drill and exercises encrypted export before a deployment baseline is considered green.

## Operations

```bash
docker compose ps
docker compose logs --tail=100 caddy
docker compose logs --tail=100 platform
docker compose logs --tail=100 worksites
```

External IdP/MFA (authentik/oauth2-proxy) and OpenBao are intentionally not forced into this base stack because they require organisation-specific bootstrap and recovery procedures. Add them before accepting real sensitive data in a production humanitarian deployment.
