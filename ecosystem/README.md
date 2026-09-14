# CrisisWeave external component decisions

CrisisWeave should not reimplement identity, TLS automation, secret management, monitoring, encrypted backup, or SQLite disaster recovery from scratch. The pinned projects in `components.lock.json` are evaluated upstream components, not copied source dependencies.

## Adopt as deployment options

### authentik + oauth2-proxy

Use authentik as the external identity provider and MFA policy engine, speaking OAuth2/OIDC. Put oauth2-proxy at the HTTP authentication boundary when a deployment wants browser SSO without adding JWT/OIDC cryptography to the stdlib Python gateway.

The CrisisWeave application must still enforce its own organisation and role permissions. Successful login is not equivalent to authorisation to mutate a worksite.

### Caddy

Use Caddy as the small-deployment TLS/reverse-proxy boundary in front of the backend. Keep application services on a private network and expose only the TLS edge. The checked-in example blocks `/metrics` from the public edge so internal Prometheus scraping does not become a new public information surface.

### OpenBao

Use OpenBao or an equivalent managed secret/KMS product for runtime secret material such as token peppers, upstream service credentials and backup credentials. Secrets must be injected at runtime and must never be written to Git, static site files or application logs.

OpenBao does not by itself encrypt the CrisisWeave SQLite files. The deployment still needs encrypted persistent volumes or managed encrypted storage.

### Litestream

Use Litestream for continuous disaster-recovery replication of single-writer SQLite databases. It is a recovery mechanism, not multi-writer consensus. CrisisWeave must remain single-writer per SQLite database while this storage mode is used.

### restic

Use restic for encrypted snapshot backups of deployment state and for scheduled restore drills. A backup that has never been restored in a test environment is not considered a verified disaster-recovery plan.

### Prometheus + blackbox_exporter

Use Prometheus for central collection/alert evaluation and blackbox_exporter for external HTTP/TLS probes. `crisisweave-platform` now has an instrumented server with low-cardinality `/metrics` output. Do not expose that endpoint through the public edge or add identifiers/PII as metric labels.

GitHub Actions continues to provide a separate simple public check for the Netlify site.

## Evaluated but not adopted

### rqlite

rqlite is a plausible future option if CrisisWeave genuinely needs a replicated multi-node transactional store while retaining SQLite semantics. It is intentionally not wired into the current assignment path because changing the consistency model before a real multi-node requirement would increase operational risk.

For a larger deployment, managed PostgreSQL or CloudNativePG should also be evaluated rather than assuming rqlite is automatically the right answer.

### Upptime

Upptime is useful for GitHub-based public status pages, but CrisisWeave already runs public endpoint checks in GitHub Actions. Adding a second public monitoring framework now would duplicate capability rather than close a gap.

## Partner reference

`CrisisCleanup/crisiscleanup-4-web` is used only to understand the shape of the public client model. The current CrisisWeave adapter accepts an authorised JSON export and strips/directly avoids survivor name, address, phones and email. No live Crisis Cleanup API contract or credentials are assumed.

## Upgrade policy

Pinned versions must be updated deliberately. Before updating an external component:

1. read its release notes and security notes;
2. update `components.lock.json` in reviewable source control;
3. run CrisisWeave CI and disaster-recovery tests;
4. test rollback to the previous known-good version;
5. never put migration secrets into the repository.
