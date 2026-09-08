# Delivery Roadmap

## Reading This Roadmap

This is a gated implementation sequence, not a schedule. The full product and acceptance criteria are in `PRD.md`. Stage 2A encrypted transport is implemented and locally verified; see `VERIFICATION.md`. Later product stages remain PROPOSED. A stage becomes complete only when its exit evidence is reviewed, not when a stub, schema, or document exists.

Current constraints: the repository is being built concurrently; Flutter is not installed; no mobile app, complete editor, live Cloudflare resources, or production identity exists. The public repository is https://github.com/ebrahimbdev/BCOMMEND.git. This roadmap does not certify the current code or CI state.

## Stage 1: Backend Foundation

**Status: historical locally verified foundation; no new remote CI claim.** Requirements: REQ-001 through REQ-004. The 2026-09-07 Linux Docker result of 69 tests, TypeScript checks, dry-run bundle, migration replay, and local HTTP smoke checks is historical only. It is not a current Stage 2A count or certification. Native Windows workerd has an access-violation blocker. No deployment occurred. Current evidence belongs to the main implementation's `VERIFICATION` record.

Scope:

- Bootstrap the Cloudflare Worker API, D1 schema/migrations, and repeatable local development setup.
- Implement hashed, manually provisioned, expiring sessions with local-only development provisioning. Do not expose a deployed credential-provisioning endpoint.
- Implement owner-isolated versioned notes CRUD with explicit stale-write rejection and input validation.
- Implement only a deterministic once/fixed-interval scheduling core with explicit clock inputs.
- Add integration tests and CI for local setup, authentication, owner isolation, version conflicts, and scheduling boundaries.

Exit evidence:

- A clean local setup can apply migrations and run tests without production credentials or deployed resources.
- Integration tests demonstrate token rejection/expiry, no raw-token persistence/logging, cross-owner isolation, and stale-update handling.
- Scheduling tests document deterministic behavior and distinguish computation from actual notification dispatch.
- CI checks run against synthetic data, and the implemented API limitations are documented.

Not included: a complete editor, Flutter client, notebook UI, CRDT synchronization, production OAuth, calendar/Jalali recurrence, OCR, notification delivery, or Cloudflare deployment. Versioned CRUD is a foundation, not collaborative editing or retained history.

## Stage 2: Architecture and Feasibility Gates

**Status: Stage 2A locally verified; other feasibility and key-management gates PROPOSED.** Relevant requirements: REQ-011, REQ-012, REQ-020, REQ-040, and REQ-061. Android-only, finger handwriting without a stylus, and required E2EE are confirmed. iOS, APNs, macOS workflows, pressure, palm rejection, and stylus features are out of scope, not pending.

### Stage 2A: Encrypted Transport Foundation

- Validate envelopes in `packages/protocol/src/note-envelope.ts`; provide the WebCrypto reference `generateNoteKey()`, `encryptNote(key,context,plaintext Uint8Array)`, and `decryptNote(key,context,envelope)` in `packages/crypto/src/notes.ts`. The exact AES-256-GCM, nonce/tag, canonical base64url, AAD, and size contract is in `API.md`.
- Accept `{envelope,expectedVersion}` with revision equal to expected version plus one; preserve owner isolation, CAS, deletion, and same-envelope initial retry `200`. Reject old plaintext payloads with `400`; return envelope plus metadata for GET and metadata only for lists.
- Retire authenticated `/v1/reminders/preview` with `410`, retaining the pure `schedule.ts` core. Private reminder scheduling runs locally.
- Use migration `0002` with a separate encrypted-notes table. Leave old notes untouched and unreachable by the API, with no legacy fallback because there are no shipped consumers. Migration is not automatic encryption or secure purge; plaintext remains possible on disk/backups. Never delete development data without authorization.

Local exit evidence: 117 tests passed, along with TypeScript, the dry-run bundle, migration replay, and a real encrypted HTTP round-trip against the built Worker. See `VERIFICATION.md`. Remote CI remains unverified. Shape validation cannot establish whether a buggy client uploaded base64 plaintext; only clients verify AEAD. Ciphertext storage is not complete application E2EE.

**Startup blocker for important data: keys are nonexportable and generated in memory only. Process exit can make content unrecoverable.** Secure vault/persistence, wrapping, recovery, device pairing, key authentication, and encrypted sharing are absent. Authentication sessions do not decrypt; OAuth account recovery is not data recovery.

### Next Security and Feasibility Gates

Propose and review a random vault root, wrapped per-document keys, Android Keystore device wrapping, a user-held offline recovery code, and trusted-device transfer, with no server master key. Obtain recovery UX approval and test failure/recovery flows. Loss of all trusted devices and recovery material means content cannot be recovered. These are not delivered features. Require independent crypto/security review and Kotlin/Dart interoperability vector tests before launch; see `architecture/0001-android-e2ee.md`.

Run architecture spikes before committing to the later mobile implementation or full recurrence engine:

- Editor/ink: compare Flutter/native/embedded approaches for Android mixed rich text, images, finger vector strokes, spatial selection, RTL, PDF, accessibility, and licensing. Require explicit draw/navigation modes, one-finger ink in draw mode, and two-finger pan/zoom. Test ambiguous gestures, second-finger arrival, cancellation/lift, and mode transitions without unintended ink. No pressure promise. Prototypes are evidence, not a delivered app.
- CRDT: test concurrent text, geometry, strokes, hierarchy, deletion, undo, reconnect, and schema evolution on clients. Durable Objects may relay encrypted CRDT updates, not merge plaintext. Measure encrypted operation growth and synchronization cost.
- OCR: evaluate local Persian/English printed and handwritten recognition on a consented or synthetic corpus. Agree numerical quality thresholds and measure errors, latency, and device budgets. Workers AI must not receive private content.
- Security and device setup: select the Android test model/minimum OS, install Flutter and Android SDK, choose OAuth/license, and approve recovery UX. E2EE and Android-only scope are settled.

Exit evidence:

- Recorded architecture decisions with reproducible spike results, explicit performance budgets, dependencies/licenses, and unresolved risks.
- An encrypted CRDT convergence harness and documented format migration; any conversion or deletion of old development data needs explicit authorization.
- An OCR quality report against agreed thresholds. A failed category blocks that promise until remediation or explicit user approval of reduced scope.
- A feasible required-E2EE design and cost/device-resource model covering storage, operations, local OCR/search/reminders, and encrypted coordination. Private titles, bodies, ink, OCR indexes/results, reminder rules, audio, filenames, attachments, and comments are encrypted before upload. Owner/document/key IDs, revisions, timestamps, lengths, and network/access metadata remain visible; no full anonymity or malicious-server rollback defense is promised.

Do not bypass failed gates by labeling an untested provider or editor package production-ready.

## Stage 3: Local-First Mobile Capture

**Status: PROPOSED; depends on Stage 2 decisions.** Requirements: REQ-010 through REQ-014, REQ-062, and the local persistence portion of REQ-040.

- Install and validate Flutter and Android SDK, then implement the Android shell and reviewed secure local durable storage.
- Build notebook/section/page/subpage organization and the selected mixed-content free canvas.
- Add finger-only vector ink with explicit draw/navigation modes, one-finger drawing, two-finger pan/zoom, image handling, and Persian/English rich text. Exclude pressure and palm rejection features.
- Add PDF annotation and consent-based audio recording with time anchors, using explicit attachment and recording limits.
- Define the portable document schema early enough to avoid trapping content in editor-specific state.

Exit evidence: Android device tests cover secure restart recovery, offline capture, spatial editing, ambiguous finger gestures, hierarchy changes, RTL/accessibility, PDF coordinates, and recording interruptions. Demonstrate measured ink behavior rather than assuming support from an API flag. Network collaboration is not claimed at this stage.

## Stage 4: Identity and Private Synchronization

**Status: PROPOSED; depends on Stages 2 and 3.** Requirements: REQ-040 and the identity/security portions of REQ-060 and REQ-061.

- Implement the selected production identity flow, secure session lifecycle, account recovery/deletion, and device handling. Keep development provisioning local-only.
- Integrate the selected CRDT and durable offline outbox with authenticated synchronization and attachment transfer.
- Enforce owner isolation for every API, sync channel, and attachment; implement reviewed E2EE/key handling. Keep plaintext search indexes local and encrypt any synchronized index material.
- Add version migration, duplicate/reordered operation handling, deletion semantics, compaction, and observable recovery paths.

Exit evidence: two devices owned by one user converge after disconnection, concurrent changes, process restart, retries, and attachment failures; unauthorized access tests pass; revocation and key/account recovery behaviors match the threat model. Local/emulated tests are not a substitute for later deployed validation.

## Stage 5: Complete Recurrence and Notifications

**Status: PROPOSED; requires the architecture gates and stable mobile/data contracts.** Requirements: REQ-030 through REQ-032.

- Approve and document calendar, Jalali conversion, time-zone, DST gap/fold, month-end, travel, and time-zone database update policies before implementing the complete recurrence model.
- Extend the once/interval foundation with calendar schedules, repeat counts, until limits, and after-completion rules. Distinguish elapsed durations from calendar delays.
- Define missed occurrences, snooze, completion replay, edits to a single/future occurrence, and cancellation semantics.
- Implement private scheduling and notifications locally on Android with retries, deduplication, and permission handling. Any future FCM wake-up must be content-free; private rules and notification content never go to the server.

Exit evidence: deterministic fixtures cover Gregorian/Jalali boundaries, leap years, DST transitions, count/until limits, and delayed completion; Android tests cover offline/restart behavior, denied permissions, background restrictions, delayed delivery, and notification navigation. If content-free FCM wake-ups are included, test them with separately authorized provisioning. Delivery is best effort, not exact-time or exactly-once.

## Stage 6: Recognition and Search

**Status: PROPOSED; depends on local OCR quality and required-E2EE gates and content contracts.** Requirements: REQ-020 and REQ-021.

- Integrate only local OCR paths that meet printed/handwritten Persian/English quality gates, with consent, device limits, retries, and reviewable output.
- Preserve original images/ink and allow corrections without destructive replacement.
- Implement local authorized search over titles, typed content, and OCR results, including Persian normalization and source navigation. Encrypt indexes/results before any upload.
- Document local/offline coverage, indexing delay, and deletion/re-indexing. Do not send private content to Workers AI or another cloud recognition/search processor.

Exit evidence: repeatable quality results for each advertised category, private-content isolation and indexing/deletion tests, and measured device/cost budgets. Failed local handwriting quality blocks the promise pending remediation or explicit scope approval; do not silently drop OCR or weaken E2EE.

## Stage 7: Collaboration and Sharing

**Status: PROPOSED; depends on private synchronization and production identity.** Requirements: REQ-040 through REQ-042.

- Add invitations, owner/editor/commenter/viewer roles, inheritance, ownership rules, and revocation.
- Extend CRDT collaboration from private multi-device use to authorized multi-user editing and add anchored comments/resolution.
- Encrypt comments and CRDT updates before upload; authorized clients merge after decryption. Implement reviewed recipient-key authentication and key distribution. Public sharing is not shipped; any future key-delivery flow needs review and must never put keys in URL query parameters sent to a server.
- Apply permissions consistently to live sync, cached operations, search, attachments, exports, and discussion threads.
- Publish the policy for queued edits after revocation and the limits of revoking previously downloaded data.

Exit evidence: concurrent multi-user partition/reconnect tests converge; a role matrix is enforced server-side; revoked users cannot obtain subsequent server data; comment anchors and attribution survive supported edits/deletions. Role checks in the UI alone do not meet the gate.

## Stage 8: Recovery and Portability

**Status: PROPOSED; depends on stable content and permission models.** Requirements: REQ-050 through REQ-052.

- Implement bounded history, trash, restores, permanent deletion, and attachment/index cleanup.
- Implement a documented versioned portable archive and its import/validation path, plus readable PDF export with Persian/English fidelity.
- Implement the browser clipper with minimal permissions, sanitization, attribution, reviewed key access, encryption before upload, and recoverable offline uploads. Require explicit user choice when exporting plaintext.

Exit evidence: archive round trips preserve the documented fields/assets; restores behave correctly under concurrent edits; PDFs retain visible annotations; retention/deletion tests cover derived data; clipper security and offline/error paths are tested. Explicitly document export exclusions and that PDF is not a lossless editable backup.

## Stage 9: Deployment and Limited Release

**Status: PROPOSED; requires the applicable feature gates and explicit user provisioning.** Requirements: REQ-060 through REQ-063 plus all capabilities advertised for release.

- Have the user provision Cloudflare resources, production identity, and any selected content-free FCM wake-up credentials through secure channels. No secrets belong in the public repository or chat. No cloud deployment resources exist now.
- Configure environments, managed secrets, migrations, attachment storage if selected, monitoring, backups, and rollback/recovery procedures.
- Verify current service quotas/pricing and measure the approximately 10-daily-user low-volume workload. Apply upload/recording limits, rate limits, OCR budgets, retention, and tested degradation behavior.
- Run deployed end-to-end authorization, synchronization, recurrence, push, restore, and deletion tests on the confirmed devices.
- Review privacy notices, recording/OCR consent, dependency licenses, accessibility limitations, support procedures, and distribution costs before release.

Exit evidence: independent crypto/security review, Kotlin/Dart interoperability vector tests, successful vault recovery/restore exercises, deployed Android tests, observable usage, and accepted budgets. R2 overage remains billable; alerts are not guaranteed hard caps. Any FCM setup and Android distribution costs are separate from Cloudflare hosting.

Release only the explicitly accepted feature set and label omissions clearly. If the limited release excludes any full-product requirement, obtain a scope decision rather than silently treating the full OneNote-like goal as complete.

## Progress Reporting Rules

- Track work against PRD requirement IDs and attach test or review evidence to stage exits.
- Distinguish proposed design, local prototype, implemented code, passing CI, deployed service, and validated user-facing behavior.
- Record stage-specific evidence in `VERIFICATION.md`. Historical results are not current-stage evidence; do not infer remote CI success from local tests.
- Preserve the owner's stage-by-stage commit/push authorization, subject to review and verification gates. A push is not deployment authorization or completion evidence; do not push concurrent unfinished implementation as a completed stage.
- Update decisions and gates as evidence changes; do not convert this sequence into unsupported dates or effort estimates.
- Preserve concurrent contributors' work. Documentation status is not authorization to deploy, create paid resources, publish an app, or modify repository history.
