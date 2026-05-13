# StreamersTip QA checklist

**Flutter app (primary):** `integration_test/` + `lib/qa/qa_keys.dart`. CI runs
`flutter test integration_test -d linux`. Locally,
`scripts/run_flutter_integration_tests.sh` prefers **plugged physical Android,
then iOS** (override with `PREFER_INTEGRATION_DEVICE=ios`), then emulators,
then **linux → macOS → Windows** when no phone or emulator is available.

**Web (optional):** `tests/e2e/` (Playwright) — only runs in CI when repository
secret `E2E_BASE_URL` is set.

**CI:** `.github/workflows/qa.yml` — analyze, unit tests, Linux integration
harness, Functions lint, optional Playwright.

## Test accounts (Firebase Auth + product flags)

| Tier   | Purpose              | Env vars (example)        |
|--------|----------------------|---------------------------|
| Starter| Base subscription    | `QA_STARTER_EMAIL/PASSWORD` |
| Pro    | Mid tier             | `QA_PRO_EMAIL/PASSWORD`     |
| Studio | Top tier             | `QA_STUDIO_EMAIL/PASSWORD`  |
| Admin  | Shield / moderation  | `QA_ADMIN_EMAIL/PASSWORD`   |

Provision users in the **same Firebase project** as production/staging, with email verified where flows require it. Store secrets in GitHub Actions (repository secrets), never in git.

## Failure triage (required for each failing flow)

| Field | What to capture |
|--------|------------------|
| Root cause | Symptom + underlying reason |
| File path | Primary code location |
| Fix | Patch or config change |
| Verification | Exact test command + expected result |
| Evidence | Playwright trace/screenshot/video or Flutter logs |

Playwright is configured for **screenshot + video + trace on failure** (`tests/e2e/playwright.config.ts`).

## Real-user flows (track: automated / manual / blocked)

1. **Sign up, login, logout** — Web: `tests/e2e/specs/auth.flows.spec.ts` (backfill). Mobile: extend `integration_test/` with `QaKeys` + staging auth.
2. **Forgot password** — Web backfill + mobile dialog/route coverage.
3. **Profile setup and avatar upload** — Needs stable selectors on picker and save.
4. **Home / For You video playback** — Device/emulator; assert player surface + no crash.
5. **Discover page navigation** — Deep link + tab routing.
6. **Upload post** — Storage + Firestore; use staging bucket.
7. **Schedule post** — Scheduler UI + queue state.
8. **Cross-posting UI** — Toggle matrix visible per tier.
9. **Share sheet** — send to user, Instagram, Messages, WhatsApp, More (platform mocks / skips where OS-level).
10. **Network connections** — Follow/graph UI.
11. **Inbox and ChatView** — Avatars, message list, send.
12. **Tippy AI speed and credit handling** — Latency bounds + credit error UI.
13. **Tippy content plan → planner** — Create plan, open planner, assert items (sync with web).
14. **Subscription tier detection** — Starter vs Pro vs Studio gating.
15. **Light/dark mode globally** — Theme toggle + regression snapshots (optional).
16. **Admin shield (TechnQs, buzZz)** — Admin-only routes; use `QA_ADMIN_*`.
17. **Report, ban, upload review, remove video** — Moderation flows; legal/safety sensitive — staging only.
18. **Error states** — Offline, upload failed, expired auth, low credit — simulate via mocks or forced API errors.

## Local commands

```bash
# Flutter (app tests — use this path)
flutter pub get
flutter analyze
flutter test
./scripts/run_flutter_integration_tests.sh
# Same as CI explicitly:
flutter test integration_test -d linux

# Web E2E
cd tests/e2e && npm ci
export E2E_BASE_URL=https://your-next-origin
npx playwright install --with-deps chromium
npm test

# Cloud Functions lint (also in qa.yml)
cd cloud_functions && npm ci && npm run lint
```

## Selector conventions

- **Web:** `data-testid="st-*"` on interactive controls (add in Next.js; do not rely on CSS class names).
- **Flutter:** `QaKeys` in `lib/qa/qa_keys.dart` + `Semantics.label` where helpful for accessibility.

## Definition of done (automation task)

- [ ] Smallest relevant test added or updated first.
- [ ] `flutter analyze` clean for touched Dart.
- [ ] `flutter test` and `flutter test integration_test` pass.
- [ ] Playwright passes when `E2E_BASE_URL` is set (or skips cleanly when unset).
- [ ] On failure: artifact (screenshot/video/trace) attached to CI run.
