# BCOMMEND

Android 11+ notes and reminders with required end-to-end encryption (E2EE), intended for public availability on phones and tablets, not one handset. Approximately 10 low-volume daily users is an initial capacity assumption. The full Persian/English product scope includes a free canvas, finger handwriting without a stylus, PDF annotations, audio, recurring reminders, offline editing, local OCR/search, collaboration, portable exports, and a browser clipper.

**Current delivery: locally verified Stage 2A encrypted transport plus a Flutter Android local preview with three successfully built debug APKs. Physical-device and emulator validation are pending. This is not a complete production E2EE application or service.** See [Android preview](docs/ANDROID_PREVIEW.md) for build instructions, artifact evidence, and data-loss warnings.

Local mobile checks passed: **45 Flutter tests and `flutter analyze` with zero issues**. This records the completed run; the final rebuild, hashes, and any later test totals belong in [verification](docs/VERIFICATION.md). No remote GitHub Actions or artifact availability is verified.

Built files under `apps/mobile/build/app/outputs/flutter-apk/` (never commit APKs to Git):

- `app-arm64-v8a-debug.apk`: recommended for most modern phones, not all phones.
- `app-armeabi-v7a-debug.apk`: legacy 32-bit ARM devices that meet the Android minimum.
- `app-x86_64-debug.apk`: primarily x86-64 emulators.

## Foundation Status

- Cloudflare Worker with a public liveness endpoint and authenticated API.
- D1 migrations for users, hashed expiring sessions, and a separate encrypted-notes table in migration `0002`.
- Owner-isolated create/read/update/soft-delete operations with atomic version checks.
- Bounded note lists and input validation, safe error responses, and no public registration route.
- Envelope validation in `packages/protocol/src/note-envelope.ts` and a WebCrypto client reference in `packages/crypto/src/notes.ts`; note lists expose metadata only.
- The pure once/interval scheduling core remains; the authenticated reminder preview endpoint is retired with `410` because private scheduling belongs on the client.
- Local Workers verification includes a real HTTP encrypted round-trip against the built Worker. Mobile crypto/model/repository tests have passed, including a fixed Node interoperability vector. Final counts and build evidence belong in [verification](docs/VERIFICATION.md); remote GitHub Actions status is not yet verified.

The Flutter preview provides Persian RTL, warm-paper Material 3 light/dark phone/tablet layouts, local note CRUD, typed text and fixed 1000 x 1400 finger ink in separate tabs, explicit draw/navigation modes, one-finger drawing, two-finger pan/zoom, undo, three colors, and local string search. It uses explicit Save, not autosave; back navigation offers save/discard and a failed save retains edits. This is not the full mixed-content free canvas.

Backup, recovery, sync, OAuth, UI reminders/notifications, OCR, PDF, audio, export, collaboration, notebook hierarchy, and a live Cloudflare deployment are **not implemented**. Envelopes are not a final portable canvas format. A version counter is not retained version history. Soft deletion is not a complete trash/restore feature.

**Do not store important data. Manually save before killing the app; unsaved edits are lost. Uninstall, app-data clearing, or key loss makes saved notes unrecoverable; no recovery codes or backup exist.** The mobile per-installation AES-256-GCM key persists across app restarts through Android Keystore-backed secure storage; it is not a hardware-only AES handle and is exportable inside the Dart process. The separate TypeScript `generateNoteKey()` reference remains nonexportable and memory-only. Authentication sessions do not decrypt content, and OAuth account recovery is not data recovery. The local random owner UUID is not a backend account; sync requires future enrollment and re-encryption. See [security](SECURITY.md).

Migration `0002` leaves old plaintext notes untouched and unreachable through the current API. It neither encrypts old data nor securely purges disks or backups. There are no shipped consumers requiring a legacy plaintext fallback. Do not delete development data without authorization.

Private titles, bodies, ink, OCR indexes/results, reminder rules, audio, filenames, attachments, and comments must be encrypted before upload. OCR, search, and reminder scheduling run locally; Workers AI must not receive private content. Server-visible metadata still includes owner/document/key IDs, revisions, timestamps, lengths, and network/access information. E2EE does not promise full anonymity or malicious-server rollback defense. See the [architecture decision](docs/architecture/0001-android-e2ee.md) and [security boundary](SECURITY.md).

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
- `apps/mobile/`: Flutter Android local preview and encrypted local repository.
- `packages/protocol/src/note-envelope.ts`: encrypted note envelope validation.
- `packages/crypto/src/notes.ts`: WebCrypto client reference, not a durable key vault.
- `tests/`: synthetic-data Worker/D1 integration and scheduling tests.
- `scripts/`: local-only credential provisioning and smoke verification.
- `docs/PRD.md`: full proposed product scope and acceptance criteria.
- `docs/ROADMAP.md`: staged delivery with explicit gates.
- `docs/API.md`: implemented API contract and examples.
- `docs/SETUP.md`: user preparation and deployment safety requirements.
- `docs/ANDROID_PREVIEW.md`: Docker build, install safety, compatibility and pending preview checks.
- `SECURITY.md`: security boundaries and reporting guidance.

## Delivery Policy

Every completed stage is reviewed, tested, committed, and pushed independently. A Git push is **not** a deployment, public APK publication, or an assertion that all product features exist. GitHub Actions has no Cloudflare deployment credentials; future preview artifacts are not an automatic public release.

Next gates include preview device validation, reviewed vault/recovery design, full mixed-canvas feasibility, encrypted collaboration, and local OCR. Flutter 3.35.7 is available in the local `ghcr.io/cirruslabs/flutter:3.35.7` Docker image; no host Flutter/SDK installation is needed. The image includes SDK 35 only; [Docker instructions](docs/ANDROID_PREVIEW.md) install SDK 36 and the required NDK into a persistent volume. Android 11+ (`minSdk 30`), finger-only input, and required E2EE are confirmed. iOS, APNs, macOS workflows, stylus input, pressure, and palm rejection are out of scope. No physical model is required to settle scope, but physical-device gesture and compatibility tests remain release gates.

## Capacity and Cost

Ten daily users is a low-volume planning assumption, not a guarantee of zero cost. Workers/D1 quotas, future R2 storage and operations, encrypted collaboration messages, and local OCR device budgets still need measurement. R2 overage can be billable. Any future content-free FCM wake-up setup and Android distribution are separate from Cloudflare hosting. No cloud deployment resources have been created.

## License

No project license has been selected yet. Public visibility alone does not grant an open-source license. Select a license before accepting external contributions or distributing the app; dependency licenses also need review during editor selection.
