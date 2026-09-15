# CrisisWeave production go-live

This checklist is the minimum technical gate for a real deployment. Passing it does not make CrisisWeave an emergency authority or replace organisation-specific privacy, safeguarding or legal approval.

## 1. Infrastructure ownership

Before changing `CW_DEPLOYMENT_ENV` to `production`, put real values in the ignored `deploy/stack/.env` for:

- `CW_API_HOST`: public API DNS name
- `CW_ALLOWED_ORIGIN`: exact HTTPS browser origin
- `CW_ALERT_WEBHOOK_URL`: HTTPS receiver controlled by the operations team
- `CW_BACKUP_AGE_RECIPIENT`: public `age` recipient whose private key is kept off-host
- `CW_DATA_RETENTION_DAYS`: approved private-data retention horizon
- `CW_INCIDENT_RESPONSE_CONTACT`: named on-call/security owner
- `CW_PRIVACY_CONTACT`: named privacy/data owner
- `CW_BACKUP_OWNER`: named restore/recovery owner

Generate the secret-bearing Alertmanager file locally:

```bash
python3 generate-alertmanager-config.py
```

Then set:

```text
CW_ALERTMANAGER_CONFIG=./alertmanager.generated.yml
CW_DEPLOYMENT_ENV=production
```

## 2. Fail-closed preflight

Run:

```bash
python3 go-live-check.py
```

Do not bypass a failing check. The command intentionally rejects placeholder DNS, non-HTTPS origins/alert receivers, weak/reused application secrets, missing off-host backup encryption and unnamed operational ownership.

## 3. Deploy and validate

```bash
docker compose up -d --build
sh verify.sh
```

`verify.sh` checks application health, private authentication boundaries, audit immutability, metrics isolation, Prometheus rules, Alertmanager readiness and the production go-live gate.

## 4. Recovery evidence

Before accepting private data:

```bash
backup_dir="$(sh backup.sh)"
sh restore-drill.sh "$backup_dir"
CW_BACKUP_AGE_RECIPIENT="$(grep '^CW_BACKUP_AGE_RECIPIENT=' .env | cut -d= -f2-)" \
  sh prepare-offsite-backup.sh "$backup_dir" /secure/offsite-staging
```

Copy the encrypted bundle and checksum to storage that is physically/provider independent from the application host. A local backup does not count as disaster recovery.

## 5. Alert delivery test

Prometheus being green is insufficient. Trigger a controlled test alert in the operations environment and confirm the configured receiver actually receives and resolves it. Record the result and date in the organisation's operational log.

## 6. Data lifecycle

Schedule the platform retention command at the approved cadence. Always run dry-run reporting first and review unexpectedly large deletion counts before applying. Backup retention must be aligned separately because deleting the live database does not erase old backup copies.

## 7. First administrator

Create the first organisation/admin only after the host and secret storage are under operator control:

```bash
sh bootstrap-admin.sh relief-org "Relief Organisation" admin-1 "Initial Administrator"
```

Store the one-time bearer token in an approved password/secret manager. Rotate or revoke bootstrap credentials after the organisation has established normal access procedures.

## 8. Rollback

Deploy reviewed releases by exact infrastructure commit SHA with:

```bash
sh update-pinned-release.sh <40-character-infra-sha>
```

The updater creates a verified backup before changing the stack and rolls code/configuration back if the new release fails verification. It deliberately does not auto-restore databases. Database restoration is a separate operator decision using a verified backup to avoid destructive rollback of newer valid data.

## 9. Stop conditions

Do not accept real sensitive data if any of these is true:

- production go-live check fails
- restore drill has never succeeded
- off-host encrypted backup is not configured
- alert delivery is not confirmed
- no named incident/privacy/recovery owner exists
- public/private data boundaries have been modified without review
- a deployment uses floating application branches/tags instead of reviewed SHAs
- external identity/MFA required by the deploying organisation has not been provisioned

The last item is intentionally organisation-specific. The base CrisisWeave stack protects its API with short-lived bearer credentials, but a sensitive multi-user deployment should put the approved external identity/MFA boundary in front of interactive operator access.
