# Secret and key management profile

OpenBao is the recommended self-hosted secret-management option evaluated for CrisisWeave. A managed cloud secret/KMS service is also acceptable. OpenBao is pinned in `../../ecosystem/components.lock.json` but is not currently deployed by this repository.

## Store outside Git

At minimum treat these as runtime secrets:

- `CW_TOKEN_PEPPER`
- `CW_WORKSITES_TOKEN` when the internal worksite API is protected
- OIDC client secret and oauth2-proxy cookie secret
- Litestream remote-storage credentials or signed replica configuration
- restic repository password and backup-storage credentials
- any future Crisis Cleanup or partner API credential

Do not store survivor data in the secret manager merely because it is encrypted. Survivor records belong in the private application data store with retention/access controls.

## Injection model

Prefer short-lived workload identity or an authenticated secret-agent/sidecar. If the deployment must render environment variables, inject them only into the service process at runtime. Do not write a populated `.env` into the repository, container image, static web root, CI logs or build artifacts.

## Rotation

- Rotate a compromised worksite upstream token immediately.
- Rotate OIDC client credentials at the IdP and proxy together.
- Rotating `CW_TOKEN_PEPPER` invalidates existing CrisisWeave token digests, so plan to reissue application bearer tokens.
- Rotate backup credentials without making old encrypted backups unreadable until their retention period expires.

## OpenBao deployment boundary

Run OpenBao on a private network with TLS, authenticated storage and an audited unseal/key-management process. Do not run a development-mode server for a real CrisisWeave deployment.

The secret manager does **not** replace encrypted database volumes, backup encryption, application RBAC or data-retention policy.

## Repository guardrail

`crisisweave-infra/scripts/check-secrets.py` rejects common secret-bearing filenames and suspicious literal credential assignments. Placeholders are allowed so configuration shape can remain reviewable without exposing values.
