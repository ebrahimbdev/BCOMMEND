# User Preparation and Deployment Gates

## Needed Now

1. Confirm launch order: Android first, or Android and iOS together. Name a real phone/tablet and stylus available for testing.
2. Confirm E2EE requirements before the canvas/sync model is locked. E2EE changes key recovery, collaboration, and server OCR/search.
3. Choose a production identity direction (for example Google and Apple sign-in) and a project license. Public source is not automatically open source.
4. Install Flutter stable and the Android SDK/Android Studio on the development machine for the upcoming mobile stage. Validate with `flutter doctor -v`. iOS compilation, signing, and device validation require macOS/Xcode or an appropriately secured macOS CI environment.
5. Create or confirm ownership of the Cloudflare account. No account ID, API token, payment method, or cloud database is needed for the current local stage.

Do not send passwords, API tokens, signing keys, session tokens, or private documents in chat or GitHub issues. When credentials become necessary, use interactive login or local/managed secret storage. Do not grant administrator access just to run tests.

## GitHub

The owner has authorized stage-by-stage commits and pushes to `ebrahimbdev/BCOMMEND`. Git operations use the machine's credential manager; source code must never embed GitHub credentials. If push authentication fails, sign into the correct GitHub account using Git Credential Manager or `gh auth login`, then retry. Avoid personal tokens in remote URLs.

Enable GitHub secret scanning/push protection where available. After the first successful Actions run, enable branch protection/rulesets for the default branch with the verification check required. Keep workflow permissions read-only and never provide production secrets to fork pull requests.

GitHub CLI is useful for checking runs, but its absence does not prevent ordinary authenticated `git push`. Installation may require Windows administrator approval.

## Before Cloudflare Deployment

This foundation is deliberately **not ready for public deployment**. A public repository does not require a public, unprotected API.

Complete production authentication, request/storage quotas, observable safe logging, account lifecycle, and a security review first. Then:

1. Authenticate Wrangler locally using `npx wrangler login` (not a token pasted into this repository).
2. Create a dedicated D1 database in the intended account after approving that deployment step.
3. Create an ignored environment-specific Wrangler configuration with the real database binding and chosen routes. Do not replace the committed local database placeholder casually.
4. Review migrations, take an appropriate backup, and explicitly choose the remote target. All existing npm migration/provisioning commands are local-only.
5. Configure production identity secrets through Wrangler/Cloudflare managed secrets. There is no deployed manual provisioning endpoint.
6. Apply remote migrations and deploy only after explicit environment confirmation. No CI deployment token is configured by this stage.
7. Test cross-user access, session revocation, quotas, and recovery on the deployed environment before adding real private notes.

R2 is not required in Stage 1. Later attachment support needs a private bucket, short-lived authorized access, object limits, and billing controls. Its included free usage is not a guaranteed hard spending cap. Do not activate a paid service or accept overage exposure without an explicit decision.

## Later Platform Setup

- Android push requires Firebase/FCM configuration; keep service credentials private.
- Apple push/signing requires Apple account configuration, APNs credentials, and a macOS signing workflow.
- OAuth requires registered mobile redirect URIs/application IDs; production sign-in must use an appropriate secure native flow.
- Store accounts, app signing, domain registration, and any paid OCR service are separate from Cloudflare free-tier hosting.
- Set measured upload/audio/OCR limits for the 10-user workload; do not promise an unlimited allowance.

## Verification Status

The repeatable verification commands are in the README and GitHub Actions. The Linux Docker path works around a Windows-native workerd access violation; it does not repair the host runtime. No Flutter build, device notification test, OCR quality benchmark, production load test, or cloud deployment is claimed by the backend foundation.
