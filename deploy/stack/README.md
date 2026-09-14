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

Then deploy:

```bash
docker compose up -d --build
```

Verify:

```bash
sh verify.sh
```

The initializer generates two random 256-bit values inside the ignored, mode-0600 local `.env` file and never prints them. Do not send that file through chat, email, issues, logs or Git. Docker administrators can inspect container environment variables and should therefore be treated as privileged host administrators; move runtime secrets to OpenBao or an equivalent secret manager for a real production deployment.

## Updates

The application build contexts are pinned to reviewed Git commit SHAs in `compose.yaml`. To upgrade, update the pinned refs deliberately, run CI, then:

```bash
docker compose build --pull
docker compose up -d
sh verify.sh
```

## Operations

```bash
docker compose ps
docker compose logs --tail=100 caddy
docker compose logs --tail=100 platform
docker compose logs --tail=100 worksites
```

Prometheus is available only from the host at `http://127.0.0.1:9090` by default. The public Caddy route returns 404 for `/metrics`.

Persistent state lives in Docker named volumes. Back up `worksites_data`, `platform_data` and Caddy state off-host, and test restoration before using real operational data. The separate Litestream/restic profiles in `crisisweave-infra` remain the recommended disaster-recovery layer.

External IdP/MFA (authentik/oauth2-proxy) and OpenBao are intentionally not forced into this base stack because they require organisation-specific bootstrap and recovery procedures. Add them before accepting real sensitive data in a production humanitarian deployment.
