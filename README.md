# BCOMMEND

Mobile-first notes and reminders, designed for Persian/English content and approximately 10 low-volume daily users. The product scope includes a free canvas, vector handwriting, PDF annotations, audio, recurring reminders, offline editing, OCR, and collaboration.

**Current delivery: Stage 1 backend foundation only. This is not yet a mobile application or a production service.**

## Implemented

- Cloudflare Worker with a public liveness endpoint and authenticated API.
- D1 migrations for users, hashed expiring sessions, and private plain-text notes.
- Owner-isolated create/read/update/soft-delete operations with atomic version checks.
- Bounded note lists and input validation, safe error responses, and no public registration route.
- Deterministic preview of one-time and elapsed-time interval schedules, including count or end-date limits.
- Worker-runtime integration tests, schedule unit tests, local HTTP smoke checks, and GitHub Actions verification.

There is **no** Flutter UI, complete editor, notebook hierarchy API, persisted reminder CRUD, notification delivery, OAuth login, CRDT sync, file upload, OCR, or live Cloudflare deployment yet. Notes are currently plain text, not a final portable canvas format. A version counter is not retained version history. Soft deletion is not a complete trash/restore feature.

## Quick Start

Requirements: Node.js 22.12+ (Node 22 LTS recommended) and npm. No Cloudflare account or API token is needed for local development.

```sh
npm ci
npm run check
npm run db:migrate:local
npm run dev:session
npm run dev
```

Open `http://localhost:8787/health`. The session command prints a **local-only**, seven-day bearer token once. Use it in an `Authorization: Bearer <token>` header; never put it in a URL, screenshot, issue, commit, or chat.

Each provisioning run creates a **different disposable user**. It does not recover a prior user's notes after session expiry/revocation. Do not use this development database for important information. Production identity and account recovery are separate future work.

The committed Wrangler configuration is intentionally local-only: it has a placeholder D1 ID, disables `workers.dev` and preview URLs, and supplies no production secrets. `npm run build` is a dry run, not a deployment.

If npm 10 encounters `Cannot read properties of null (reading 'edgesOut')` while resolving new dependencies, use `npx --yes npm@11.12.0 install`. Normal locked installs use `npm ci`.

## Windows Runtime Workaround

On the development machine, native `workerd` exits with Windows access violation `0xc0000005`. Type checking and bundling work, but native tests/local D1 cannot run there. This is not a passing native-Windows test result. Cloudflare recommends checking the Microsoft Visual C++ Redistributable installation for this failure.

With Docker Desktop running in Linux-container mode:

```sh
docker build --file Dockerfile.verify --tag bcommend-verify .
```

This installs locked dependencies in Linux, runs the tests and dry-run build, applies local migrations twice, and exercises a real local HTTP Worker with a temporary session. No remote resources or credentials are used.

To try the development API in Docker with persistent, local-only storage:

```sh
docker run --rm -it -p 127.0.0.1:8787:8787 -v bcommend-local:/workspace/apps/api/.wrangler bcommend-verify sh
```

Inside the container:

```sh
npm run db:migrate:local
npm run dev:session
npm run dev -- --ip 0.0.0.0 --port 8787
```

The port is published only to localhost on the host. The named volume is development data, not a backup. Do not push the verification image to a public registry; it is a local verification tool, not a production image.

## Layout

- `apps/api/src/`: Worker and deterministic schedule core.
- `apps/api/migrations/`: D1 schema migrations.
- `tests/`: synthetic-data Worker/D1 integration and scheduling tests.
- `scripts/`: local-only credential provisioning and smoke verification.
- `docs/PRD.md`: full proposed product scope and acceptance criteria.
- `docs/ROADMAP.md`: staged delivery with explicit gates.
- `docs/API.md`: implemented API contract and examples.
- `docs/SETUP.md`: user preparation and deployment safety requirements.
- `SECURITY.md`: security boundaries and reporting guidance.

## Delivery Policy

Every completed stage is reviewed, tested, committed, and pushed independently. A Git push is **not** a deployment or an assertion that all product features exist. GitHub Actions performs checks only; it has no Cloudflare deployment credentials.

The next stage is the editor/ink, offline collaboration, and OCR feasibility work plus a confirmed mobile platform/identity decision. Flutter is not installed in the current development environment.

## Capacity and Cost

Ten daily users is a low-volume planning assumption, not a guarantee of zero cost. Workers/D1 quotas, future R2 storage and operations, collaboration messages, and OCR budgets still need measurement. R2 overage can be billable. FCM/APNs setup and app-store distribution are separate from Cloudflare hosting. No paid resource has been created by this foundation.

## License

No project license has been selected yet. Public visibility alone does not grant an open-source license. Select a license before accepting external contributions or distributing the app; dependency licenses also need review during editor selection.
