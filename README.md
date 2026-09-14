# crisisweave-infra

Public, secret-free deployment and operational configuration for CrisisWeave.

This repository is deliberately safe to make public. It contains deployment metadata, a static public landing page, monitoring configuration, and CI guardrails. It must never contain API keys, bearer tokens, passwords, private survivor data, private keys, `.env` files, or production database files.

## Public endpoints

- Netlify origin: `https://crisisweave.netlify.app`
- Requested public alias: `https://crisisweave.thedev.me`

The `thedev.me` alias is managed through the upstream `thedev-me/register` project and may remain pending until its pull request is approved.

## Repository responsibilities

- static public landing page in `site/`
- Netlify build and security-header configuration
- CI secret scanning and configuration checks
- availability monitoring workflow
- deployment/runbook documentation
- examples of required environment variable names without secret values

## Secret policy

Secrets belong in the hosting provider or a secret manager, never in Git.

Required backend secret names are documented in `.env.example` using placeholders only. In particular, `CW_TOKEN_PEPPER` must be generated outside this repository and injected at runtime.

The CI workflow runs `scripts/check-secrets.py` and fails when it sees common token/key patterns or forbidden secret-bearing filenames.

## Architecture boundary

`crisisweave-infra` does not duplicate application logic. The authenticated API remains in `crisisweave-platform`, operational worksite state remains in `crisisweave-worksites`, and public incident/recovery logic remains in the specialist repositories.

A public website being reachable does not make CrisisWeave an emergency authority or a production humanitarian dispatch system.
