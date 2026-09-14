# Deployment runbook

## Public web

`site/` is intentionally static and contains no credentials. Netlify publishes it with the security headers in `netlify.toml`.

Origin: `https://crisisweave.netlify.app`
Requested alias: `https://crisisweave.owns.it.com`
Domain request: `https://github.com/domainsproject/register/pull/191`

The custom alias is not considered active until the registry request is accepted, DNS resolves, and the hostname is added to the Netlify project so TLS can be provisioned.

## Backend

The backend is `crisisweave-platform`; `crisisweave-worksites` remains the operational state service behind it. The intended deployment order is:

1. private Docker network and encrypted persistent storage;
2. `crisisweave-worksites` bound only to the private network;
3. `crisisweave-platform` as the only application API boundary;
4. Caddy in front of the platform for HTTPS;
5. runtime secret injection from OpenBao or an equivalent managed secret store;
6. Litestream/restic recovery configuration and a tested restore;
7. Prometheus/blackbox monitoring;
8. external identity/MFA via authentik and oauth2-proxy when browser SSO is enabled.

Required secret material, especially `CW_TOKEN_PEPPER`, must be generated and injected by the deployment host. Never copy a generated value into this repository, a Docker image, a public issue, logs, or documentation.

`/metrics` is intended for the private monitoring network and should not be exposed through the public Caddy route.

## Production boundary

A successful container start is not production certification. Before real survivor or volunteer data is accepted, verify encrypted storage, access controls, off-host recovery, retention/deletion policy, operator ownership, monitoring, and an authorised integration path for any partner system such as Crisis Cleanup.
