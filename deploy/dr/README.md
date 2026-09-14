# Disaster recovery profile

CrisisWeave currently uses SQLite for its MVP operational stores. The recommended recovery stack is Litestream for continuous SQLite replication plus restic for encrypted backup snapshots and restore drills.

These components are pinned in `../../ecosystem/components.lock.json` but are **not currently deployed** by this repository.

## Litestream

Litestream is used only for disaster recovery replication. It does not turn SQLite into a multi-writer database. Keep a single authoritative writer for each CrisisWeave SQLite database.

The template `litestream.yml.example` contains no storage credentials. Render the replica URLs at deployment time using OpenBao or the hosting platform's secret manager.

At minimum replicate:

- `platform.db`
- `private.db`
- `worksites.db`

Do not send a private database to a public bucket. Require encrypted transport, private object access and storage-side encryption.

## restic

Use restic for encrypted backup snapshots of:

- verified application database backups created by `crisisweave-platform backup`
- configuration needed to reconstruct a deployment, excluding generated credentials
- any operational state not already covered by Litestream

Keep the restic repository password and remote-storage credentials outside Git.

## Restore drill

A disaster-recovery system is not considered ready until restore is tested. A drill should:

1. provision an isolated empty environment;
2. restore the three databases to new paths;
3. run SQLite `PRAGMA integrity_check` on each restored database;
4. start worksites and platform against the restored copies;
5. check `/healthz` and `/readyz`;
6. verify organisation boundaries and token revocation state survived;
7. verify active worksite assignment state and audit history survived;
8. verify public export still removes operational-only fields;
9. destroy the isolated drill environment after recording the result.

## Recovery objectives

Do not publish an RPO or RTO until it has been measured. Record the observed recovery point and recovery time during each drill rather than inventing guarantees from configuration alone.

## Multi-node future

rqlite is tracked as an evaluated future candidate, not an active dependency. If CrisisWeave needs multiple concurrent writers, compare rqlite against managed PostgreSQL before changing the assignment consistency model.
