# crisisweave-infra

Public, secret-free deployment and operational configuration for CrisisWeave.

This repository is deliberately safe to make public. It contains deployment metadata, a static public landing page, monitoring configuration, evaluated external-component profiles and CI guardrails. It must never contain API keys, bearer tokens, passwords, private survivor data, private keys, `.env` files, or production database files.

## Public endpoints

- Netlify origin: `https://crisisweave.netlify.app`
- Requested public alias: `https://crisisweave.owns.it.com`
- Domain request: `https://github.com/domainsproject/register/pull/191`

The custom alias remains pending until the external domain registry accepts the pull request and DNS propagates.

## Free cloud deployment from a phone

CrisisWeave has a standalone Oracle Cloud Infrastructure Resource Manager stack in the `oci-free-deploy` branch. Oracle runs Terraform in its own cloud, so this path does not require a personal computer to stay online or a local Terraform installation.

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/davidmariscalf/crisisweave-infra/archive/refs/heads/oci-free-deploy.zip)

The template defaults are capped at 2 OCPUs, 12 GB RAM and a 50 GB boot volume, creates the network/firewall automatically, installs Docker on Ubuntu ARM, generates CrisisWeave backend secrets only on the VM, and starts the existing Compose stack. The branch is independently checked with `terraform fmt`, `terraform init`, `terraform validate` and bootstrap shell-syntax CI.

See `deploy/OCI_FREE.md` for the mobile workflow, capacity caveats and the HTTPS boundary. Always Free eligibility and remaining quota are tenancy-wide Oracle properties, not a guarantee made by CrisisWeave.

## One-command backend stack

`deploy/stack/` is the reproducible Docker Compose baseline for a small Linux/VPS deployment. It combines:

- `crisisweave-worksites` on a private application network
- `crisisweave-platform` as the authenticated API boundary
- Caddy 2.11.4 as the only public HTTP/TLS edge
- Prometheus 3.14.0 and blackbox_exporter 0.28.0 on the private monitoring network
- persistent Docker volumes for application state
- non-root application containers, read-only root filesystems, dropped Linux capabilities and health/readiness checks

The application build contexts are pinned to reviewed Git commit SHAs. CI builds the remote contexts and runs the full Compose stack before accepting the deployment baseline.

```bash
git clone https://github.com/davidmariscalf/crisisweave-infra.git
cd crisisweave-infra/deploy/stack
sh init.sh
# edit .env and set CW_API_HOST
docker compose up -d --build
sh verify.sh
```

`init.sh` creates random backend secrets only inside the ignored local `.env` file with mode `0600` and never prints them. For a real production deployment, migrate runtime secret material to OpenBao or an equivalent managed secret store.

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
- Caddy for the TLS/reverse-proxy edge
- OpenBao for runtime secret/key management
- Litestream for continuous SQLite disaster-recovery replication
- restic for encrypted backup snapshots and restore drills
- Prometheus + blackbox_exporter for internal metrics and readiness probes
- rqlite as a future multi-node candidate only, not an active dependency
- Crisis Cleanup's public web repository as a partner-model reference only

The base stack deploys Caddy, Prometheus and blackbox_exporter. Identity, managed secrets and off-host disaster recovery remain opt-in because they require organisation-specific bootstrap/recovery configuration. No upstream source code is copied into CrisisWeave.

## Deployment profiles

- `deploy/stack/` — current one-command backend baseline
- `deploy/identity/` — external OIDC/MFA boundary without hand-written authentication cryptography
- `deploy/secrets/` — runtime secret/KMS practices with OpenBao or an equivalent managed service
- `deploy/dr/` — Litestream + restic disaster-recovery model and restore drill
- `deploy/edge/` — standalone Caddy edge guidance
- `deploy/observability/` — standalone Prometheus/blackbox guidance

The profiles deliberately distinguish configuration readiness from production deployment.

## Netlify build provenance

For a source-linked Netlify deployment, `netlify.toml` runs:

```bash
python scripts/build-site.py
```

and publishes `dist/`. The builder copies the public site and stamps both `build.json` and `health.json` with the exact 40-character source revision from Netlify's `COMMIT_REF` (or the local Git revision when run outside Netlify).

This makes a deployed public site traceable back to reviewed source without embedding credentials in the repository.

### Deploying from a different Netlify account

The Netlify account does not need to be the account that created the current public site. A different account can deploy the same reviewed build safely as long as it:

1. connects GitHub and is granted access to `davidmariscalf/crisisweave-infra`;
2. creates a site from this repository, using the repository root as the base;
3. lets `netlify.toml` run `python scripts/build-site.py` and publish `dist/`;
4. deploys the exact reviewed `main` revision rather than uploading an unstamped folder;
5. verifies the result with:

```bash
python scripts/verify-deploy.py https://YOUR-SITE.netlify.app --expected-revision "$(git rev-parse HEAD)"
```

The default `crisisweave.netlify.app` subdomain is already owned by the existing Netlify project. A second account must use a different temporary `*.netlify.app` name unless the existing site is transferred, renamed, or the custom domain is moved deliberately.

If the canonical public URL changes, set the GitHub repository variable `CW_PUBLIC_SITE_URL` to the new HTTPS origin so the scheduled uptime/provenance workflow checks the new deployment.

### Manual Drop fallback

If Netlify Drop is used, build the stamped directory first:

```bash
python scripts/build-site.py --revision "$(git rev-parse HEAD)"
```

Then upload the **entire `dist/` directory**, not only `index.html`. It contains the deploy-safe headers/redirects, health metadata and `build.json` provenance record.

A manual Drop is still less desirable than a source-linked deployment because Netlify itself will not attach a Git commit to the deploy record. The embedded revision at least makes the served files auditable until the account is linked to Git.

No Netlify token, API key or password is required inside this repository.

## Secret policy

Secrets belong in the hosting provider or a secret manager, never in Git.

Required backend secret names are documented with empty placeholders only. The local one-command stack stores generated development/small-deployment secrets in its ignored mode-0600 `.env`; a hardened production deployment should inject them from OpenBao or an equivalent provider.

The CI workflow runs `scripts/check-secrets.py` and fails when it sees common token/key patterns or forbidden secret-bearing filenames. Environment-variable/placeholders are allowed only so configuration shape can be versioned without values.

## Architecture boundary

`crisisweave-infra` does not duplicate application logic. The authenticated API remains in `crisisweave-platform`, operational worksite state remains in `crisisweave-worksites`, and public incident/recovery logic remains in the specialist repositories.

A public website being reachable does not make CrisisWeave an emergency authority or a production humanitarian dispatch system. External components only close their specific deployment gaps; they do not certify the complete system.
