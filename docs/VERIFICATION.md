# Stage 1 Verification

Date: 2026-09-07. This report covers local foundation code, not the full product or a deployed service.

## Passed

- `npm run typecheck` on Windows.
- `npm audit --audit-level=moderate`: zero known vulnerabilities at the time of verification.
- `docker build --file Dockerfile.verify --tag bcommend-verify .` on Docker Desktop Linux containers with Node 22.
- 69 tests inside the actual Workers runtime: 39 API/D1 tests and 30 deterministic schedule tests.
- Dry-run Worker bundle with its artifact verified under repository-local `dist/api/index.js`.
- Local D1 migrations followed by a second application with no pending migrations.
- Real local HTTP Worker smoke test: local credential provisioning, identity, note creation/read, session revocation, and subsequent denial.
- Provisioning rejects `--remote`; smoke verification does not print generated tokens.

Coverage includes missing/invalid/expired/revoked sessions, cross-owner access, concurrent writes/create/delete, stale versions, tombstone resurrection prevention, request limits including streaming input, pagination, malformed JSON, SQL-like content, mixed RTL text, counted recurrence, exclusive cursor/inclusive end boundaries, large gaps, and date validation.

## Review

An independent code review examined authentication, owner isolation, SQL, request limits, recurrence, and scripts. A concern about nested-config build output was addressed by using an absolute repository-local output directory and asserting the build artifact in the smoke test. Additional create/update/delete concurrency and streaming-body regression tests passed.

## Not Verified or Delivered

- GitHub-hosted Actions result: pending first push/run at the time this report was authored.
- Native Windows workerd: fails to start with access violation `0xc0000005`; use the documented Linux Docker path.
- Flutter/device builds, editor/ink performance, OCR quality, calendar/Jalali recurrence, notifications, CRDT, attachments, production identity, deployed latency/quota behavior, and production backup recovery are future stages.

Passing tests and a clean dependency audit do not establish production readiness or eliminate all security risks. Development accounts/data are disposable; no live Cloudflare resource was created.
