# Product Requirements Document

## Status and Purpose

This document defines the proposed product, not a statement of delivered capabilities. The goal is a mobile-first, OneNote-like notes and reminders application for approximately 10 daily users with low activity volume. English and Persian content are first-class requirements. The public repository is https://github.com/ebrahimbdev/BCOMMEND.git.

Stage 1 implementation is locally verified: a Cloudflare Worker and D1, hashed manually provisioned expiring development sessions, owner-isolated versioned notes CRUD, and a deterministic once/interval scheduling core. Linux Docker verification passed 69 tests, a dry-run build, migration replay, and local HTTP smoke checks. GitHub Actions is configured; its remote result must be checked after pushing. Stage 1 remains IN PROGRESS below until that CI gate is checked. There is no complete editor yet.

Flutter is not installed and the mobile application is not implemented. No live Cloudflare resources or production identity system have been provisioned. All capabilities beyond the Stage 1 scope below are proposed future work and require the relevant roadmap gates.

## Product and Deployment Constraints

- Prefer Cloudflare free-tier services where feasible, subject to measured limits and current service terms. Approximately 10 daily users is a planning assumption, not proof of affordability.
- Free tier is bounded; neither unlimited usage nor a guaranteed zero-dollar bill is promised. Storage, operations, compute, external OCR, transcription, and transfer must be budgeted. R2 overage is billable.
- Worker and D1 are the Stage 1 backend targets. R2 for attachments and Durable Objects or another coordination service for collaboration are candidates, not deployed dependencies or settled architecture.
- Remote push notifications require FCM and/or APNs and their credentials and platform setup. A Cloudflare backend alone does not provide mobile push delivery.
- Published application distribution, developer accounts, and app-store costs are separate from hosting costs.
- The user must provision Cloudflare resources later. Never place secrets, session tokens, private keys, or real user data in the repository, issues, documentation, or chat. Use local secret configuration and managed deployment secrets.
- The public repository must contain only synthetic fixtures and distributable assets. CI must not depend on production credentials for ordinary tests or untrusted contributions.

## Users and Primary Workflows

An owner captures a page containing typed content, images, and pen strokes; organizes it in a notebook; attaches a reminder; finds it using text or recognized handwriting; and continues working offline. Future collaborators can receive limited access, discuss a page, and edit concurrently when authorized. Persian users need correct right-to-left rendering, Persian search, and Jalali scheduling without losing interoperability with English content or Gregorian dates.

The product targets touch and stylus mobile use first. Flutter is the proposed client technology. Android versus iOS launch order, minimum OS versions, tablet support, stylus hardware coverage, and any desktop/web editor are pending confirmation. A future browser clipper does not imply a complete browser editor.

## Requirements and Acceptance Criteria

The status on each requirement describes planned delivery scope. Acceptance criteria are gates to verify, not assertions that tests already pass.

### Backend Foundation

**REQ-001: Backend bootstrap (Stage 1, IN PROGRESS).** Provide a Worker API and D1 schema with repeatable local setup and schema migrations. Acceptance: a clean local environment can apply migrations, run the API, and execute integration tests without live Cloudflare resources or secrets; CI runs the applicable checks. Deployment is a later, separately authorized action.

**REQ-002: Development sessions (Stage 1, IN PROGRESS).** Manually provision expiring sessions only for local development; store token hashes rather than raw bearer tokens. Acceptance: missing, malformed, unknown, and expired credentials are rejected; raw tokens are absent from database persistence and server logs; provisioning cannot create credentials in a deployed environment. The local CLI displays a token once to its operator; that output must not be shared. This is not production sign-in, OAuth, account recovery, or a shipped authentication flow.

**REQ-003: Private versioned notes (Stage 1, IN PROGRESS).** Provide owner-isolated notes create, read, update, and delete operations with explicit version checks. Acceptance: one owner's credentials cannot read or mutate another owner's records, including list and direct-ID requests; stale updates are rejected without overwriting newer content; validation and error cases are integration-tested. Versioned CRUD is not CRDT merging, page history, or a full rich-text editor.

**REQ-004: Basic scheduling core (Stage 1, IN PROGRESS).** Deterministically compute once and fixed-interval schedules with explicit time inputs and validation. Acceptance: tests cover one-time boundaries, interval advancement, invalid inputs, and repeatability for identical inputs. This core does not establish calendar recurrence, push dispatch, background execution, or end-to-end reminder delivery.

### Organization and Free Canvas

**REQ-010: Notebook hierarchy (Future).** Support notebooks, ordered sections, pages, and subpages with rename, move, reorder, and deletion behavior. Acceptance: the hierarchy survives restart and synchronization; cycles and unauthorized cross-owner moves are prevented; moving or deleting a parent has an explicit, tested descendant policy.

**REQ-011: Mixed-content free canvas (Future; architecture gate required).** Combine independently positioned rich text, images, and vector ink on one spatial page rather than limiting content to a linear document. Rich text includes headings, lists, checklists, links, and formatting. Acceptance: users can select, move, resize, and layer supported content; save/reopen and synchronization preserve geometry and formatting; pan/zoom, undo/redo, and mixed Persian/English input work on the agreed device matrix. Unsupported imported content must not disappear silently.

**REQ-012: Stylus and touch input (Future; architecture gate required).** Preserve vector strokes and available pressure data, provide pen/highlighter/eraser tools, and support palm rejection on compatible hardware. Acceptance: pressure changes affect the selected brush, stroke data remains editable after synchronization, and measured stylus latency and accidental-touch rates meet budgets agreed during the spike. Test real target devices. Document hardware/OS limitations and a touch fallback; do not promise universal palm rejection.

**REQ-013: PDF annotation (Future).** Import PDFs and attach ink, highlights, and text to stable PDF page coordinates. Acceptance: annotations remain aligned through zoom, rotation, restart, and synchronization; export preserves the source pages and visible annotations; large, corrupt, encrypted, and unsupported files produce explicit outcomes within agreed size limits.

**REQ-014: Audio and time anchors (Future).** Record with consent and attach note or ink anchors to recording offsets. Acceptance: tapping an anchor seeks to the corresponding recording position, offsets survive synchronization/export, and interruption or permission denial does not silently discard captured content. Recording indicators, storage limits, and deletion behavior must be visible. Automatic transcription is not committed scope and needs a separate decision.

### Recognition and Search

**REQ-020: Persian and English OCR (Future; quality gate required).** Evaluate printed and handwritten recognition for both languages, including image and ink-derived input. Acceptance: a consented or synthetic representative evaluation set covers all four language/input combinations; report character/word error metrics, normalization behavior, latency, cost, and privacy exposure. Numerical release thresholds must be agreed before provider selection or a delivery commitment. Recognition results remain reviewable and correctable and never replace original content. Failed handwriting quality may require an explicitly approved scope change, not a silent claim of support.

**REQ-021: Search (Future).** Search titles, typed text, and approved OCR results within authorized notebooks/pages, with snippets and source navigation. Acceptance: Persian/Arabic letter variants, diacritics, mixed directionality, and English queries follow documented normalization rules; indexing and deletion propagate within a declared window; inaccessible content never appears in results. Define offline search coverage explicitly, and label unavailable or not-yet-indexed attachment content.

### Reminders and Calendars

**REQ-030: Complete recurrence model (Future except REQ-004).** Support once, calendar-based, fixed-interval, and after-completion schedules, with repeat-count and until limits. Calendar rules must cover user-selected daily, weekly, monthly, and yearly patterns. Acceptance: tests specify occurrence identity, count semantics, inclusive/exclusive until boundaries, missed occurrences, snooze, edits to one versus future occurrences, cancellation, and idempotent completion. A reminder attached to a page remains navigable or has an explicit deleted-page outcome.

**REQ-031: Jalali, time zones, and DST (Future).** Preserve the chosen calendar, named time zone, and rule semantics rather than treating every recurrence as a fixed duration. Acceptance: Jalali/Gregorian conversion, leap years, month ends, travel/device-zone changes, and time-zone database updates have documented behavior and boundary tests. The approved policy must specify whether invalid month days skip or clamp; whether nonexistent DST local times skip or shift; and which occurrence of an ambiguous local time is used. Fixed intervals use elapsed-time semantics; calendar rules use their chosen wall-clock zone. After-completion rules must explicitly distinguish duration from calendar delay. No silent calendar substitution is allowed.

**REQ-032: Reminder execution and delivery (Future).** Coordinate server scheduling, local notifications, and remote push with visible permission and connectivity states. Acceptance: dispatch retries are idempotent at the occurrence level, notification taps open the correct content, revocation/cancellation invalidates future work, and tests cover denied permissions, offline devices, token rotation, and delayed push. State OS background restrictions and best-effort delivery; do not guarantee exact-time or exactly-once visible notifications.

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

**REQ-061: Privacy and encryption (Future; decision required).** Decide whether to provide end-to-end encryption (E2EE) before fixing the synchronization, OCR, search, and export architecture. Acceptance: document a threat model, key ownership/recovery, device enrollment/revocation, metadata exposure, and implications for collaboration and provider-side processing. TLS or storage encryption must not be represented as E2EE. Obtain explicit consent before content is sent to external recognition services.

**REQ-062: Accessibility and Persian UX (Future).** Support RTL navigation where appropriate, mixed-direction text, scalable text, sufficient contrast, screen-reader labels, and non-stylus alternatives for essential actions. Acceptance: test representative Persian/English flows with assistive technology and agreed phone/tablet layouts; describe accessible alternatives and limitations for spatial ink content.

**REQ-063: Bounded resource use (Future; launch gate required).** Set per-user and global limits for attachments, recordings, OCR, collaboration, and scheduled work. Acceptance: usage monitoring, budgets, alerts, throttling, and degradation behavior are tested against a stated low-volume workload; exceeded limits fail visibly without data corruption. Alerts alone are not a hard spending cap. Verify actual service pricing and controls before deployment without asserting fixed quotas here.

## Pending Decisions and Release Gates

- Platform confirmation: launch OS order, tablet/stylus devices, minimum versions, browser targets, and distribution method.
- Editor/ink architecture: native versus embedded components, spatial data model, RTL fidelity, PDF engine, licensing, accessibility, and device performance budgets.
- CRDT architecture: document granularity, collaborative undo, attachment lifecycle, coordinator choice, deletion semantics, migration, and bounded storage/operation growth.
- E2EE: threat model and whether server-side OCR/search and practical key recovery are compatible with the selected promise.
- Production OAuth/identity: provider, account linking, session lifecycle, recovery, revocation, deletion, and mobile redirect security. No provider is implemented or selected by this document.
- OCR quality: evaluation corpus ownership, numerical thresholds per language/input type, provider versus on-device processing, cost envelope, and fallback if handwriting fails the gate.
- Recurrence policy: Jalali rule representation, DST gap/fold choices, month-end handling, count/until semantics, missed occurrences, and after-completion behavior.
- Retention and costs: history/trash periods, attachment budgets, backup retention, notification setup, and acceptable paid dependencies or overage exposure.

## Success and Scope Control

Success means the agreed device set can capture, retrieve, remind, and synchronize reliably in Persian and English within explicit security and resource bounds. Establish measurable usability, performance, sync, OCR, and reminder-dispatch targets during the architecture gates; user volume alone is not a success metric.

The full product scope is preserved above, but no release date or stage duration is estimated. Architecture spikes may require user-approved scope or budget changes. Do not describe a capability as implemented until its acceptance evidence exists. Enterprise administration, unlimited storage, guaranteed notification timing, and automatic audio transcription are not committed requirements.
