# Security Policy

This repository defines the CrisisWeave deployment and go-live boundary. Treat deployment configuration, credentials, recovery material and operational contacts as sensitive.

## Reporting a vulnerability

Do not publish credentials, webhook URLs, recovery keys, private deployment topology, personal data, or exploitable production details in a public issue.

Use GitHub private vulnerability reporting when available. Otherwise contact the repository owner through GitHub before public disclosure so a private reporting channel can be arranged.

Include the affected revision, a minimal synthetic reproduction, impact and any safe remediation ideas.

## High-priority classes

- secret leakage through configuration, CI, logs or generated files
- bypasses of the production go-live gate
- unsafe defaults that expose monitoring, databases or internal services publicly
- backup/restore failures that silently lose integrity or confidentiality
- alerting failures that falsely report healthy operation
- mutable or unpinned production component sources
- container or reverse-proxy configuration that weakens service isolation
- dependency or build-chain compromise

## Deployment safety

Do not use real survivor data, operational credentials, private DNS or organisation secrets when reproducing an issue. Use synthetic values and local or isolated test environments.

The go-live gate is intentionally fail-closed. Do not weaken it merely to make a deployment pass; satisfy the missing operator-owned requirement or keep the deployment in evaluation mode.
