# Delivery Roadmap

## Reading This Roadmap

This is a gated implementation sequence, not a schedule, estimate, or completion report. The full product and acceptance criteria are in `docs/PRD.md`. Only Stage 1 is IN PROGRESS; all later stages are PROPOSED and not implemented. A stage becomes complete only when its exit evidence is reviewed, not when a stub, schema, or document exists.

Current constraints: the repository is being built concurrently; Flutter is not installed; no mobile app, complete editor, live Cloudflare resources, or production identity exists. The public repository is https://github.com/ebrahimbdev/BCOMMEND.git. This roadmap does not certify the current code or CI state.

## Stage 1: Backend Foundation

**Status: IMPLEMENTED AND LOCALLY VERIFIED; remote CI gate pending.** Requirements: REQ-001 through REQ-004. On 2026-09-07, the Linux Docker verification passed 69 tests, TypeScript checks, the dry-run Worker bundle, migration replay, and local HTTP provisioning/CRUD/revocation smoke checks. Dependency audit reported no known vulnerabilities. Native Windows workerd has an access-violation blocker; the Docker path is verified. No deployment occurred.

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

**Status: PROPOSED; next gate after the foundation.** Relevant requirements: REQ-011, REQ-012, REQ-020, REQ-040, REQ-061, and cross-cutting platform decisions.

Run architecture spikes before committing to the later mobile implementation or full recurrence engine:

- Editor/ink: compare candidate Flutter/native/embedded approaches for mixed rich text, images, vector strokes, spatial selection, RTL, PDF integration, pressure, palm rejection, accessibility, and licensing. Temporary device prototypes are evidence, not a delivered mobile app.
- CRDT: test concurrent text, geometry, strokes, hierarchy, deletion, undo, reconnect, and schema evolution. Measure operation growth and synchronization cost, and decide whether Cloudflare coordination services fit the budget.
- OCR: evaluate Persian/English printed and handwritten content on a representative consented or synthetic corpus. Agree numerical quality thresholds first; measure errors, latency, cost, and privacy implications for each category.
- Security and platform: confirm launch platforms/devices, decide E2EE and its OCR/search implications, and select a production identity/OAuth approach before locking data and sync architecture.

Exit evidence:

- Recorded architecture decisions with reproducible spike results, explicit performance budgets, dependencies/licenses, and unresolved risks.
- A CRDT convergence test harness and a documented mapping between Stage 1 records and the proposed collaborative format, including whether existing development data is disposable.
- An OCR quality report against agreed thresholds. A failed category blocks that promise until remediation or explicit user approval of reduced scope.
- Confirmed platform scope and a cost model covering storage, operations, OCR, coordination, and notifications. E2EE is either selected with a feasible design or explicitly not promised.

Do not bypass failed gates by labeling an untested provider or editor package production-ready.

## Stage 3: Local-First Mobile Capture

**Status: PROPOSED; depends on Stage 2 decisions.** Requirements: REQ-010 through REQ-014, REQ-062, and the local persistence portion of REQ-040.

- Install and validate the Flutter toolchain for the confirmed target platforms, then implement the mobile shell and local durable storage.
- Build notebook/section/page/subpage organization and the selected mixed-content free canvas.
- Add vector ink, pressure-aware brushes, compatible-device palm rejection, image handling, and rich text with Persian/English input.
- Add PDF annotation and consent-based audio recording with time anchors, using explicit attachment and recording limits.
- Define the portable document schema early enough to avoid trapping content in editor-specific state.

Exit evidence: representative device tests cover restart recovery, offline capture, spatial editing, hierarchy changes, RTL/accessibility, PDF coordinate alignment, recording interruptions, and hardware fallbacks. Demonstrate measured ink behavior rather than assuming support from an API flag. Network collaboration is not claimed at this stage.

## Stage 4: Identity and Private Synchronization

**Status: PROPOSED; depends on Stages 2 and 3.** Requirements: REQ-040 and the identity/security portions of REQ-060 and REQ-061.

- Implement the selected production identity flow, secure session lifecycle, account recovery/deletion, and device handling. Keep development provisioning local-only.
- Integrate the selected CRDT and durable offline outbox with authenticated synchronization and attachment transfer.
- Enforce owner isolation for every API, sync channel, attachment, and index; implement selected encryption/key handling.
- Add version migration, duplicate/reordered operation handling, deletion semantics, compaction, and observable recovery paths.

Exit evidence: two devices owned by one user converge after disconnection, concurrent changes, process restart, retries, and attachment failures; unauthorized access tests pass; revocation and key/account recovery behaviors match the threat model. Local/emulated tests are not a substitute for later deployed validation.

## Stage 5: Complete Recurrence and Notifications

**Status: PROPOSED; requires the architecture gates and stable mobile/data contracts.** Requirements: REQ-030 through REQ-032.

- Approve and document calendar, Jalali conversion, time-zone, DST gap/fold, month-end, travel, and time-zone database update policies before implementing the complete recurrence model.
- Extend the once/interval foundation with calendar schedules, repeat counts, until limits, and after-completion rules. Distinguish elapsed durations from calendar delays.
- Define missed occurrences, snooze, completion replay, edits to a single/future occurrence, and cancellation semantics.
- Implement scheduler dispatch, local notifications, and FCM/APNs integration with secure credentials, retries, deduplication, and permission handling.

Exit evidence: deterministic fixtures cover Gregorian/Jalali boundaries, leap years, DST transitions, count/until limits, and delayed completion; device tests cover offline behavior, token rotation, denied permissions, delayed delivery, and notification navigation. Remote device tests require provisioned services and platform credentials; this stage cannot be called complete without them. Delivery is best effort, not an exact-time or exactly-once guarantee.

## Stage 6: Recognition and Search

**Status: PROPOSED; depends on the Stage 2 OCR/E2EE decisions and content contracts.** Requirements: REQ-020 and REQ-021.

- Integrate only OCR paths that satisfy the agreed printed/handwritten Persian/English quality gates, with consent, quotas, retries, and reviewable output.
- Preserve original images/ink and allow corrections without destructive replacement.
- Implement authorized search over titles, typed content, and OCR results, including Persian normalization and source navigation.
- Document offline search coverage, indexing delay, provider exposure, and deletion/re-indexing behavior.

Exit evidence: repeatable quality results for each advertised category, private-content isolation tests, accurate indexing/deletion tests, and a measured low-volume cost envelope. Revisit the product decision if handwriting accuracy or E2EE compatibility is inadequate.

## Stage 7: Collaboration and Sharing

**Status: PROPOSED; depends on private synchronization and production identity.** Requirements: REQ-040 through REQ-042.

- Add invitations, owner/editor/commenter/viewer roles, inheritance, ownership rules, and revocation.
- Extend CRDT collaboration from private multi-device use to authorized multi-user editing and add anchored comments/resolution.
- Apply permissions consistently to live sync, cached operations, search, attachments, exports, and discussion threads.
- Publish the policy for queued edits after revocation and the limits of revoking previously downloaded data.

Exit evidence: concurrent multi-user partition/reconnect tests converge; a role matrix is enforced server-side; revoked users cannot obtain subsequent server data; comment anchors and attribution survive supported edits/deletions. Role checks in the UI alone do not meet the gate.

## Stage 8: Recovery and Portability

**Status: PROPOSED; depends on stable content and permission models.** Requirements: REQ-050 through REQ-052.

- Implement bounded history, trash, restores, permanent deletion, and attachment/index cleanup.
- Implement a documented versioned portable archive and its import/validation path, plus readable PDF export with Persian/English fidelity.
- Implement the browser clipper for confirmed browsers with minimal permissions, sanitization, source attribution, and recoverable uploads.

Exit evidence: archive round trips preserve the documented fields/assets; restores behave correctly under concurrent edits; PDFs retain visible annotations; retention/deletion tests cover derived data; clipper security and offline/error paths are tested. Explicitly document export exclusions and that PDF is not a lossless editable backup.

## Stage 9: Deployment and Limited Release

**Status: PROPOSED; requires the applicable feature gates and explicit user provisioning.** Requirements: REQ-060 through REQ-063 plus all capabilities advertised for release.

- Have the user provision Cloudflare resources, production identity settings, and FCM/APNs credentials through appropriate secure channels. No secrets belong in the public repository or chat.
- Configure environments, managed secrets, migrations, attachment storage if selected, monitoring, backups, and rollback/recovery procedures.
- Verify current service quotas/pricing and measure the approximately 10-daily-user low-volume workload. Apply upload/recording limits, rate limits, OCR budgets, retention, and tested degradation behavior.
- Run deployed end-to-end authorization, synchronization, recurrence, push, restore, and deletion tests on the confirmed devices.
- Review privacy notices, recording/OCR consent, dependency licenses, accessibility limitations, support procedures, and distribution costs before release.

Exit evidence: approved security review, successful restore exercise, deployed device test results, observable resource usage, and accepted budget/limits. R2 overage remains billable; billing alerts are not guaranteed hard caps. FCM/APNs setup and app-store/developer-account costs are separate prerequisites, not benefits included with Cloudflare hosting.

Release only the explicitly accepted feature set and label omissions clearly. If the limited release excludes any full-product requirement, obtain a scope decision rather than silently treating the full OneNote-like goal as complete.

## Progress Reporting Rules

- Track work against PRD requirement IDs and attach test or review evidence to stage exits.
- Distinguish proposed design, local prototype, implemented code, passing CI, deployed service, and validated user-facing behavior.
- Keep Stage 1 marked IN PROGRESS until its evidence is verified. This document makes no claim that integration tests or CI already pass.
- Update decisions and gates as evidence changes; do not convert this sequence into unsupported dates or effort estimates.
- Preserve concurrent contributors' work. Documentation status is not authorization to deploy, create paid resources, publish an app, or modify repository history.
