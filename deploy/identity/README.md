# External identity profile

Recommended components are pinned in `../../ecosystem/components.lock.json`.

## Goal

Move human authentication and MFA out of the CrisisWeave Python application. Use a real OIDC identity provider such as authentik and a maintained OIDC-aware reverse proxy such as oauth2-proxy at the HTTP boundary.

This profile is **not enabled by default** and these components are not currently deployed by CrisisWeave.

## Trust boundary

1. Internet traffic terminates TLS at the deployment ingress.
2. Browser authentication happens at the IdP and oauth2-proxy.
3. `crisisweave-platform` stays on a private application network.
4. The platform continues to enforce CrisisWeave organisation/role permissions for API mutations.
5. `crisisweave-worksites` remains private behind the platform gateway.

Do not expose the platform directly and then trust identity headers supplied by arbitrary clients. CrisisWeave does not currently implement a trusted-header authentication mode; adding one without network isolation and cryptographic binding would create an impersonation path.

## authentik

Use authentik for user lifecycle, MFA and OIDC. Create a dedicated CrisisWeave OIDC application/provider. Require MFA for privileged coordinator/admin access. Keep client credentials in OpenBao or the deployment secret manager, never in this repository.

## oauth2-proxy

The example environment file documents the non-secret shape for an OIDC proxy. It deliberately leaves secret values empty. The proxy can be used first to protect human-facing administrative routes while CrisisWeave's API continues using its own short-lived, revocable bearer tokens.

A later migration can replace application bearer tokens with direct OIDC token validation, but that should use a maintained JWT/OIDC library or a trusted gateway rather than hand-written cryptography.

## Rollout sequence

1. Deploy authentik privately and configure TLS.
2. Create the CrisisWeave OIDC application/provider and MFA policy.
3. Store OIDC client credentials in OpenBao or an equivalent secret manager.
4. Deploy oauth2-proxy in front of the human admin surface.
5. Verify unauthenticated requests cannot reach protected routes.
6. Verify a normal volunteer identity cannot gain coordinator/admin capabilities.
7. Keep an emergency rollback path that restores the previous known-good gateway configuration.

## Not solved by this profile

OIDC login does not automatically solve CrisisWeave authorisation, survivor-data governance, encrypted database storage or multi-node consistency. Those remain separate controls.
