# Deployment runbook

## Public web

`site/` is intentionally static and contains no credentials. Netlify publishes it with the security headers in `netlify.toml`.

Origin: `https://crisisweave.netlify.app`
Requested alias: `https://crisisweave.owns.it.com`
Domain request: `https://github.com/domainsproject/register/pull/191`

The custom alias is not considered active until the registry request is accepted, DNS resolves, and the hostname is added to the Netlify project so TLS can be provisioned.

## Backend quick path

For a small Linux/VPS deployment, use `deploy/stack/` instead of starting each service manually:

```bash
git clone https://github.com/davidmariscalf/crisisweave-infra.git
cd crisisweave-infra/deploy/stack
sh init.sh
# set CW_API_HOST in .env
docker compose up -d --build
sh verify.sh
```

The stack builds the reviewed application commits, starts `crisisweave-worksites` and `crisisweave-platform` on private networks, exposes only Caddy on public 80/443, and starts Prometheus plus blackbox_exporter on the monitoring network. `/metrics` is not exposed through the public Caddy route.

`init.sh` generates random local token/pepper values without printing them. No default organisation, administrator or bearer token is created. Bootstrap deployment identities deliberately with `crisisweave-platform` after the host and access policy are under operator control; do not ship universal/default credentials.

## Backend boundary

The backend is `crisisweave-platform`; `crisisweave-worksites` remains the operational state service behind it. The intended hardening order is:

1. private Docker network and encrypted persistent storage;
2. `crisisweave-worksites` bound only to the private network;
3. `crisisweave-platform` as the only application API boundary;
4. Caddy in front of the platform for HTTPS;
5. runtime secret injection from OpenBao or an equivalent managed secret store;
6. Litestream/restic recovery configuration and a tested restore;
7. Prometheus/blackbox monitoring;
8. external identity/MFA via authentik and oauth2-proxy when browser SSO is enabled.

Required secret material, especially `CW_TOKEN_PEPPER`, must be generated and injected by the deployment host. Never copy a generated value into this repository, a Docker image, a public issue, logs, or documentation.

## Production boundary

A successful container start is not production certification. Before real survivor or volunteer data is accepted, verify encrypted storage, access controls, off-host recovery, retention/deletion policy, operator ownership, monitoring, and an authorised integration path for any partner system such as Crisis Cleanup.
