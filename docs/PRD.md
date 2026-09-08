# Product Requirements Document

## Status and Purpose

This document defines the proposed product, not a statement of delivered capabilities. The goal is a mobile-first, OneNote-like notes and reminders application for approximately 10 daily users with low activity volume. English and Persian content are first-class requirements. The public repository is https://github.com/ebrahimbdev/BCOMMEND.git.

Stage 1 supplied Worker/D1, hashed development sessions, owner-isolated versioned CRUD, and the pure once/interval scheduling core. Stage 2A encrypted transport is locally verified with a built-Worker encrypted HTTP round-trip. A Flutter Android local preview is implemented; local Flutter tests, including a fixed Node interoperability vector, and analysis passed, and three split-ABI debug APKs built successfully. See `ANDROID_PREVIEW.md` for artifact inspection and `VERIFICATION.md` for final counts and evidence. No physical-device or emulator tests ran; no remote CI/artifact success, complete production E2EE application, publication, or deployment is claimed.

Flutter 3.35.7 is available through the locally present `ghcr.io/cirruslabs/flutter:3.35.7` Docker image; host Flutter and Android SDK are absent. The preview provides Persian RTL warm-paper Material 3 light/dark phone/tablet layouts, local CRUD, typed text and fixed 1000 x 1400 finger ink in separate tabs, draw/navigation modes, one-finger drawing, two-finger pan/zoom, undo, three colors, and local string search. It is not the full mixed-content free canvas. Save is explicit, with a back save/discard guard and edits retained after save failure; there is no autosave. Backup/recovery, sync/OAuth, UI reminders, OCR, PDF, audio, export, and collaboration are not implemented. No cloud resources or production identity have been provisioned. Full-product requirements below are retained, not silently removed by preview scope.

## Product and Deployment Constraints

- Prefer Cloudflare free-tier services where feasible, subject to measured limits and current service terms. Approximately 10 daily users is a planning assumption, not proof of affordability.
- Free tier is bounded; neither unlimited usage nor a guaranteed zero-dollar bill is promised. Storage, operations, compute, external OCR, transcription, and transfer must be budgeted. R2 overage is billable.
- Worker and D1 are the Stage 1 backend targets. R2 for attachments and Durable Objects or another coordination service for collaboration are candidates, not deployed dependencies or settled architecture.
- Private reminder scheduling and notifications run locally on Android. Any future content-free FCM wake-up requires separate credentials/setup; the backend must not receive private rules or notification content.
- Published application distribution, developer accounts, and app-store costs are separate from hosting costs.
- The user must provision Cloudflare resources later. Never place secrets, session tokens, private keys, or real user data in the repository, issues, documentation, or chat. Use local secret configuration and managed deployment secrets.
- The public repository must contain only synthetic fixtures and distributable assets. CI must not depend on production credentials for ordinary tests or untrusted contributions.

## Users and Primary Workflows

An owner captures a page containing typed content, images, and pen strokes; organizes it in a notebook; attaches a reminder; finds it using text or recognized handwriting; and continues working offline. Future collaborators can receive limited access, discuss a page, and edit concurrently when authorized. Persian users need correct right-to-left rendering, Persian search, and Jalali scheduling without losing interoperability with English content or Gregorian dates.

Android ONLY, Android 11+ (`minSdk 30`), finger handwriting WITHOUT a stylus, and E2EE REQUIRED are confirmed. Flutter is the preview client technology. The intended app is publicly available across compatible Android phones and tablets, not tailored to one handset. No physical model is needed to settle scope; physical-device testing remains a gate. iOS, APNs, macOS workflows, stylus support, pressure features, and palm rejection are out of scope, not pending. A future browser clipper remains in scope but does not imply a desktop or complete browser editor.

Stage 2A uses `packages/protocol/src/note-envelope.ts` for shape validation and `packages/crypto/src/notes.ts` for the WebCrypto reference. `PUT` accepts `{envelope,expectedVersion}`, GET returns an envelope plus metadata, and lists contain metadata only. Old plaintext payloads return `400`; authenticated reminder preview returns `410`, with the pure scheduling core retained. See `API.md` for the exact AES-GCM/AAD contract. Migration `0002` creates a separate table, leaving old plaintext untouched and unreachable by the API; it is not automatic encryption or secure purge, including disks/backups. No shipped consumers require a fallback. Do not delete development data without authorization.

**Do not store important data. Save manually before killing the app. Uninstall, app-data clearing, or key loss makes saved notes unrecoverable; no recovery codes exist.** Mobile encrypted files and the per-installation AES-256-GCM key persist across restarts using app-private storage and Android Keystore-backed secure storage. The Dart key is exportable inside the process, not a hardware-only AES handle. The separate TypeScript `generateNoteKey()` reference remains nonexportable and memory-only. The local owner UUID is not a backend account; future sync requires enrollment and re-encryption. Sessions do not decrypt data and OAuth recovery is not data recovery. See `../SECURITY.md` and `ANDROID_PREVIEW.md` for storage failure behavior and device boundaries.

## Requirements and Acceptance Criteria

The status on each requirement describes full planned delivery scope. Basic preview ink, local persistence/search, and RTL UI partially address REQ-012, REQ-021, REQ-040, and REQ-062, but do not complete their acceptance criteria. Acceptance criteria are gates to verify, not assertions that tests already pass.

### Backend Foundation

**REQ-001: Backend bootstrap (Stage 1 historical foundation).** Provide a Worker API and D1 schema with repeatable local setup and schema migrations. Acceptance: a clean local environment can apply migrations, run the API, and execute integration tests without live Cloudflare resources or secrets; CI runs the applicable checks. Deployment is a later, separately authorized action. Current Stage 2A migration changes require fresh verification.

**REQ-002: Development sessions (Stage 1 historical foundation).** Manually provision expiring sessions only for local development; store token hashes rather than raw bearer tokens. Acceptance: missing, malformed, unknown, and expired credentials are rejected; raw tokens are absent from database persistence and server logs; provisioning cannot create credentials in a deployed environment. The local CLI displays a token once to its operator; that output must not be shared. This is not production sign-in, OAuth, account recovery, or a shipped authentication flow.

**REQ-003: Private versioned notes (Stage 2A encrypted transport locally verified).** Provide owner-isolated encrypted notes create, read, update, and delete operations with explicit version checks. Acceptance: one owner's credentials cannot read or mutate another owner's records, including list and direct-ID requests; stale updates are rejected without overwriting newer content; envelope validation and error cases are integration-tested. Versioned CRUD is not CRDT merging, page history, or a full rich-text editor.

**REQ-004: Basic scheduling core (Stage 1 historical foundation).** Deterministically compute once and fixed-interval schedules with explicit time inputs and validation. Acceptance: tests cover one-time boundaries, interval advancement, invalid inputs, and repeatability for identical inputs. The pure core remains; Stage 2A retires server preview in favor of local private scheduling. This core does not establish calendar recurrence, push dispatch, background execution, or end-to-end reminder delivery.

### Organization and Free Canvas

**REQ-010: Notebook hierarchy (Future).** Support notebooks, ordered sections, pages, and subpages with rename, move, reorder, and deletion behavior. Acceptance: the hierarchy survives restart and synchronization; cycles and unauthorized cross-owner moves are prevented; moving or deleting a parent has an explicit, tested descendant policy.

**REQ-011: Mixed-content free canvas (Future; architecture gate required).** Combine independently positioned rich text, images, and vector ink on one spatial page rather than limiting content to a linear document. Rich text includes headings, lists, checklists, links, and formatting. Acceptance: users can select, move, resize, and layer supported content; save/reopen and synchronization preserve geometry and formatting; pan/zoom, undo/redo, and mixed Persian/English input work on the agreed device matrix. Unsupported imported content must not disappear silently.

**REQ-012: Android finger handwriting (Future; architecture gate required).** Preserve editable vector strokes without a stylus and provide pen/highlighter/eraser tools. Use explicit draw/navigation modes: one finger inks in draw mode, navigation mode does not ink, and two fingers pan/zoom. Acceptance: test real Android devices for latency, accidental marks, mode changes, and ambiguous gestures, including a second finger arriving during an ink stroke, finger lift/cancellation, and transitions back to one finger. Define deterministic commit/cancel behavior and prevent unintended ink while navigating. No pressure, palm rejection, or stylus support is promised.

**REQ-013: PDF annotation (Future).** Import PDFs and attach ink, highlights, and text to stable PDF page coordinates. Acceptance: annotations remain aligned through zoom, rotation, restart, and synchronization; export preserves the source pages and visible annotations; large, corrupt, encrypted, and unsupported files produce explicit outcomes within agreed size limits.

**REQ-014: Audio and time anchors (Future).** Record with consent and attach note or ink anchors to recording offsets. Acceptance: tapping an anchor seeks to the corresponding recording position, offsets survive synchronization/export, and interruption or permission denial does not silently discard captured content. Recording indicators, storage limits, and deletion behavior must be visible. Automatic transcription is not committed scope and needs a separate decision.

### Recognition and Search

**REQ-020: Persian and English OCR (Future; quality gate required).** Evaluate local printed and handwritten recognition for both languages, including image and ink-derived input. Acceptance: a consented or synthetic representative evaluation set covers all four language/input combinations; report character/word error metrics, normalization, latency, device resource use, and privacy. Agree numerical thresholds before engine selection or delivery commitment. Private content must not go to Workers AI or other server OCR. Results remain reviewable/correctable, never replace originals, and are encrypted before any upload. Failed quality requires remediation or an explicitly approved scope change, not a silent support claim.

**REQ-021: Local search (Future).** Search titles, typed text, and approved OCR results locally within authorized notebooks/pages, with snippets and source navigation. Private indexes/results must be encrypted before any upload; no server plaintext search. Acceptance: Persian/Arabic letter variants, diacritics, mixed directionality, and English queries follow documented normalization rules; indexing/deletion propagate within a declared window; inaccessible content never appears. Define local/offline coverage and label unavailable or not-yet-indexed attachments.

### Reminders and Calendars

**REQ-030: Complete recurrence model (Future except REQ-004).** Support once, calendar-based, fixed-interval, and after-completion schedules, with repeat-count and until limits. Calendar rules must cover user-selected daily, weekly, monthly, and yearly patterns. Acceptance: tests specify occurrence identity, count semantics, inclusive/exclusive until boundaries, missed occurrences, snooze, edits to one versus future occurrences, cancellation, and idempotent completion. A reminder attached to a page remains navigable or has an explicit deleted-page outcome.

**REQ-031: Jalali, time zones, and DST (Future).** Preserve the chosen calendar, named time zone, and rule semantics rather than treating every recurrence as a fixed duration. Acceptance: Jalali/Gregorian conversion, leap years, month ends, travel/device-zone changes, and time-zone database updates have documented behavior and boundary tests. The approved policy must specify whether invalid month days skip or clamp; whether nonexistent DST local times skip or shift; and which occurrence of an ambiguous local time is used. Fixed intervals use elapsed-time semantics; calendar rules use their chosen wall-clock zone. After-completion rules must explicitly distinguish duration from calendar delay. No silent calendar substitution is allowed.

**REQ-032: Local reminder execution and delivery (Future).** Schedule private rules and Android notifications locally with visible permissions and connectivity states. Encrypt rules before sync; any future FCM wake-up must be content-free and must not move private scheduling server-side. Acceptance: retries are idempotent per occurrence, taps open correct content, cancellation invalidates future work, and tests cover denied permissions, offline/restarted devices, Android background restrictions, and delayed wake-ups if introduced. Delivery is best effort, not exact-time or exactly-once.

### Offline Collaboration

**REQ-040: Offline editing and CRDT synchronization (Future; architecture gate required).** Persist edits locally and converge supported content with a chosen CRDT protocol when connectivity returns. Acceptance: two clients editing text, geometry, strokes, hierarchy, and deletions under partitions converge after reconnect without silent loss; replay and duplicate operations are safe; attachment upload failures are recoverable; local restart does not lose acknowledged edits. Specify operation/schema versioning, compaction, tombstones, and retention. Stage 1 optimistic version conflicts are not this capability.

**REQ-041: Sharing and roles (Future).** Support owner, editor, commenter, and viewer permissions with explicit inheritance and invitation/revocation rules. Acceptance: server-side checks cover API operations, sync streams, attachments, search, comments, and exports; editors cannot escalate privileges; revocation denies subsequent server access. Disclose that previously downloaded or exported data cannot be remotely recalled and decide how queued offline edits from revoked users are handled.

**REQ-042: Comments (Future).** Provide attributed discussion threads and resolution, anchored to pages or content where feasible. Acceptance: anchors behave predictably after content moves/deletion, permissions govern read/write actions, offline replay does not duplicate comments, and deleted accounts have a documented attribution policy.

### Retention and Portability

**REQ-050: History and trash (Future).** Provide recoverable page versions and soft deletion with explicit retention limits. Acceptance: an authorized user can preview and restore supported versions and trashed content; restores synchronize without silently overwriting concurrent edits; permanent deletion covers attachments, search indexes, and retained copies according to the published policy. History is distinct from a current-record version counter.

**REQ-051: Portable export and PDF export (Future).** Provide a documented, versioned archive format containing content, hierarchy, metadata, vector ink, attachment references/files, reminder rules, and audio anchors, plus a readable PDF representation. Acceptance: a validation/import round trip preserves supported archive fields and assets; exported PDFs render Persian and English text and annotations correctly; exclusions such as private discussions or historical versions are declared. PDF is a presentation export, not a lossless editable backup.

**REQ-052: Browser clipper (Future).** Capture selected text, links, source URL, capture time, and supported images into a selected page or inbox with user consent. Acceptance: define target browsers and permission scope; sanitize captured content, preview the result, and handle offline/failed uploads without silent loss. Do not bypass paywalls, authentication, or browser security boundaries.

### Security, Accessibility, and Operations

**REQ-060: Production security (Future; launch gate required).** Establish production identity, authorization, TLS, input validation, content sanitization, attachment access controls, rate/size limits, safe logging, secret management, and dependency review. Acceptance: adversarial tests cover cross-user access, expired/revoked credentials, injection, unsafe uploads, and privilege escalation; backups and restores are exercised; incident and account/data deletion procedures exist. Production provisioning must not reuse the local manual-session path.

**REQ-061: Required E2EE (Stage 2A transport locally verified; full security launch gates pending).** Encrypt private titles, bodies, ink, OCR indexes/results, reminder rules, audio, filenames, attachments, and comments before upload. OCR/search/reminders run locally. Durable Objects may relay encrypted CRDT updates, not merge plaintext; authorized clients decrypt/merge. Browser clipping must encrypt captured private data before upload, and exports require explicit user-controlled plaintext disclosure. Public sharing is unimplemented and needs a future reviewed key-delivery flow; keys must never enter URL queries sent to servers. Acceptance: document and test key ownership, enrollment/revocation, key authentication, recovery, and metadata exposure; obtain independent crypto/security review and Kotlin/Dart interoperability vector tests before launch. Server shape validation cannot prove encryption or reject all base64 plaintext from buggy clients; only clients verify AEAD. Visible metadata includes owner/document/key IDs, revisions, timestamps, lengths, and network/access information. No full anonymity or malicious-server rollback defense is promised.

The proposed next key-management gates are a reviewed vault root, wrapped per-document keys, a user-held offline recovery code, and trusted-device transfer, with no server master key. These are not delivered; the preview's Keystore-backed at-rest persistence is not this full vault/recovery design. Approve recovery UX and test recovery before real data use. Losing all trusted devices and recovery material makes content unrecoverable; OAuth account recovery cannot fix that.

**REQ-062: Accessibility and Persian UX (Future).** Support RTL navigation, mixed-direction text, scalable text, sufficient contrast, screen-reader labels, and accessible alternatives to finger gestures for essential actions. Acceptance: test Persian/English flows with Android assistive technology on agreed device layouts; describe alternatives and spatial ink limitations.

**REQ-063: Bounded resource use (Future; launch gate required).** Set per-user and global limits for attachments, recordings, OCR, collaboration, and scheduled work. Acceptance: usage monitoring, budgets, alerts, throttling, and degradation behavior are tested against a stated low-volume workload; exceeded limits fail visibly without data corruption. Alerts alone are not a hard spending cap. Verify actual service pricing and controls before deployment without asserting fixed quotas here.

## Pending Decisions and Release Gates

- Android 11+ (`minSdk 30`) is settled. Validate a broad phone/tablet and OS matrix, not one required handset; choose later browser-clipper targets and Play Store versus APK distribution. See `ANDROID_PREVIEW.md` for completed artifact inspections and pending device, 16 KB boot, renderer, and store-policy checks. APK availability is not an all-phone compatibility guarantee.
- Before public release, privately create a stable release signing key, select a license, and complete production identity/recovery gates. Debug preview artifacts and authorized source pushes do not authorize public APK publication.
- Editor/ink architecture: native versus embedded components, spatial data model, RTL fidelity, PDF engine, licensing, accessibility, and device performance budgets.
- CRDT architecture: document granularity, collaborative undo, attachment lifecycle, coordinator choice, deletion semantics, migration, and bounded storage/operation growth.
- Required E2EE: reviewed threat model, vault/recovery UX approval, key authentication, device transfer/revocation, and interoperability evidence. Server-side private OCR/search is excluded.
- Production OAuth/identity: provider, account linking, session lifecycle, recovery, revocation, deletion, and mobile redirect security. No provider is implemented or selected by this document.
- Local OCR quality: evaluation corpus ownership, numerical thresholds per language/input type, on-device engine, device budgets, and fallback if handwriting fails the gate.
- Recurrence policy: Jalali rule representation, DST gap/fold choices, month-end handling, count/until semantics, missed occurrences, and after-completion behavior.
- Retention and costs: history/trash periods, attachment budgets, backup retention, notification setup, and acceptable paid dependencies or overage exposure.

## Success and Scope Control

Success means the agreed device set can capture, retrieve, remind, and synchronize reliably in Persian and English within explicit security and resource bounds. Establish measurable usability, performance, sync, OCR, and reminder-dispatch targets during the architecture gates; user volume alone is not a success metric.

The full product scope is preserved above, but no release date or stage duration is estimated. Architecture spikes may require user-approved scope or budget changes. Do not describe a capability as implemented until its acceptance evidence exists. Enterprise administration, unlimited storage, guaranteed notification timing, and automatic audio transcription are not committed requirements.
