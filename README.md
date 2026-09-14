# crisisweave-infra

Public, secret-free deployment and operational configuration for CrisisWeave.

This repository is deliberately safe to make public. It contains deployment metadata, a static public landing page, monitoring configuration, evaluated external-component profiles and CI guardrails. It must never contain API keys, bearer tokens, passwords, private survivor data, private keys, `.env` files, or production database files.

## Public endpoints

- Netlify origin: `https://crisisweave.netlify.app`
- Requested public alias: `https://crisisweave.owns.it.com`
- Domain request: `https://github.com/domainsproject/register/pull/191`

The custom alias remains pending until the external domain registry accepts the pull request and DNS propagates.

## Repository responsibilities

- static public landing page and synthetic evaluator demos in `site/`
- deploy-safe `_headers` and `_redirects` files inside the published directory
- Netlify build and security-header configuration
- public `health.json`, robots metadata, sitemap and `security.txt`
- CI secret scanning and configuration checks
- scheduled public availability checks without third-party API keys
- deployment/runbook documentation
- explicit external-component decision/lock file
- examples of required environment variable names without secret values

## Evaluated production components

`ecosystem/components.lock.json` records versions and adoption status for infrastructure that CrisisWeave should integrate rather than rewrite:

- authentik for IdP/MFA/OIDC
- oauth2-proxy for a maintained OIDC-aware HTTP authentication boundary
- OpenBao for runtime secret/key management
- Litestream for continuous SQLite disaster-recovery replication
- restic for encrypted backup snapshots and restore drills
- rqlite as a future multi-node candidate only, not an active dependency
- Crisis Cleanup's public web repository as a partner-model reference only

These projects are **not automatically deployed** by cloning this repository. Their runbooks are under `deploy/`. No upstream source code is copied into CrisisWeave.

## Deployment profiles

- `deploy/identity/` — external OIDC/MFA boundary without hand-written authentication cryptography
- `deploy/secrets/` — runtime secret/KMS practices with OpenBao or an equivalent managed service
- `deploy/dr/` — Litestream + restic disaster-recovery model and restore drill

The profiles are opt-in and deliberately distinguish configuration readiness from production deployment.

## Netlify Drop

If Netlify Drop is used, upload the **entire `site/` directory**, not only `index.html`. The directory contains `_headers`, `_redirects`, `health.json` and the other public deployment metadata that make the static deployment match the repository configuration.

No Netlify token, API key or password is required inside this repository.

## Secret policy

Secrets belong in the hosting provider or a secret manager, never in Git.

Required backend secret names are documented in `.env.example` using placeholders only. In particular, `CW_TOKEN_PEPPER` must be generated outside this repository and injected at runtime.

The CI workflow runs `scripts/check-secrets.py` and fails when it sees common token/key patterns or forbidden secret-bearing filenames. Environment-variable/placeholders are allowed only so configuration shape can be versioned without values.

## Architecture boundary

`crisisweave-infra` does not duplicate application logic. The authenticated API remains in `crisisweave-platform`, operational worksite state remains in `crisisweave-worksites`, and public incident/recovery logic remains in the specialist repositories.

A public website being reachable does not make CrisisWeave an emergency authority or a production humanitarian dispatch system. External components only close their specific deployment gaps; they do not certify the complete system.
