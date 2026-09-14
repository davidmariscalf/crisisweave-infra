# Deployment runbook

## Public web

`site/` is intentionally static and contains no credentials. Netlify publishes it with the security headers in `netlify.toml`.

Origin: `https://crisisweave.netlify.app`
Requested alias: `https://crisisweave.thedev.me`

## Backend

The backend is `crisisweave-platform`; `crisisweave-worksites` remains the operational state service behind it. A production deployment must provide persistent encrypted storage, TLS, a secret manager, backups/restores and monitoring.

Required secret material, especially `CW_TOKEN_PEPPER`, must be injected by the host. Never copy a generated value into this repository, a Docker image, a public issue, logs, or documentation.

## Domain

The free `thedev.me` request uses a CNAME to the public origin. Approval is controlled by the external `thedev-me/register` maintainers. DNS approval alone is not evidence that the backend is production-ready.
