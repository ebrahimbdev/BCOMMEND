# Security

## Current Boundary

This is an early, local-only backend foundation. It is not ready to hold production private data. There is no public registration endpoint, production identity, rate/storage quota enforcement, attachment processing, or cloud deployment. Ordinary CI uses synthetic test data and no deployment secrets.

All private routes validate a hashed, expiring, revocable session and bind note queries to its owner. Updates and deletes use atomic expected-version checks. Unexpected storage failures return generic errors instead of SQL or request contents.

The local provisioning command intentionally prints the raw token **once to the user's terminal**; it does not persist it in D1. Do not record/share that terminal output. Tests and smoke checks use synthetic accounts and capture provisioning output without printing credentials. Local SQLite development storage is not encrypted by this project.

## Public Repository Hygiene

- Never commit `.dev.vars`, `.env`, private keys, app-signing files, local databases, or real user documents.
- Do not include bearer tokens in URLs, logs, screenshots, issues, or API examples.
- Keep app data out of analytics; implement redacted diagnostics before production.
- Do not deploy the manual local session workflow as user authentication.
- Enable GitHub secret scanning and push protection where available.
- Review dependencies and licenses before shipping; `npm audit` is useful but is not a complete security review.

## Reporting

Please do not open a public issue containing exploitable details, credentials, or personal data. If the repository owner has enabled GitHub private vulnerability reporting, use that channel. Otherwise contact the owner privately to arrange a secure reporting channel before sharing sensitive details. No guaranteed response SLA is established for this early project.

## Before Release

Production sign-in/account recovery, request and storage quotas, file authorization, safe diagnostics, privacy disclosures, backup/restore testing, threat modeling, and a decision about E2EE are required. TLS and provider storage encryption are not E2EE. Revoking access cannot recall data already downloaded or exported by a user.
