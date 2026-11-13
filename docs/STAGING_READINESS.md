# Staging readiness

**Checked:** 2026-11-13, about 1:05 AM America/New_York.

**Device testing: NO-GO.** Production launch remains NO-GO. No store build, production rules deploy, or production device test was run. No Firebase project was created.

## Authenticated access

`streamerstip-stg` was not verified through an authenticated Firebase or Google Cloud session.

- `firebase` and `gcloud` are not installed.
- The local Firebase CLI config has no logged-in user.
- No `GOOGLE_APPLICATION_CREDENTIALS`, Firebase, or Cloudflare environment variables are set.
- `.firebaserc` names only `streamerstip-6cfdb`.

A missing DNS record does not prove the Firebase project is absent. It also does not prove the project exists. Existence still requires an authenticated `projects:list` or console check by someone who can see the project. This environment stopped at that credential gate.

## What is already known

| Surface | Observed | Isolated from production? |
|---|---|---|
| Android `google-services.json` | `project_id` is `streamerstip-6cfdb` | No |
| iOS `GoogleService-Info.plist` | `PROJECT_ID` is `streamerstip-6cfdb` | No |
| Default `SITE_API_BASE` | `https://streamerstip.com` | No |
| `staging.streamerstip.com` | No DNS record on this check | Endpoint unavailable |
| `streamerstip-stg.firebasestorage.app` | No DNS record on this check | Endpoint unavailable |
| `streamerstip-stg.firebaseapp.com` | Same Google address as the production Firebase host | Not proof of a project |
| PR #23 guard | Refuses this checkout. Passes only on a temporary tree | Guard behavior only |

## Required staging resources

These must exist and be proven separate from `streamerstip-6cfdb` and from `https://streamerstip.com` before a device matrix or a disposable account deletion.

### Firebase project

Use the existing `streamerstip-stg` project if an authenticated check finds it. Do not create a second project with the same id.

### Auth

- Email and password, matching the app login.
- Google sign-in for the staging Android and iOS app ids.
- The iOS URL scheme must come from the staging `GoogleService-Info.plist`, not the production client id.
- Account delete, provision, deactivate, and reactivate stay on the staging website routes below. The app does not call a delete callable.

### Firestore and Storage

- Same rules and indexes as this repo (`firestore.rules`, `firestore.indexes.json`, `storage.rules`). Deploy them to `streamerstip-stg` only after a separate approval. Do not deploy them to production from this work.
- Storage paths the app writes include `avatars/{userId}/…` and owner video objects.
- Client video creates must still be unable to set `feedEligible`, `ownerActive`, Mux ids, or `canonicalPlaybackUrl`.

### Cloud Functions (`us-central1`)

The mobile client calls these by name. A staging build must resolve them to `streamerstip-stg`, not `streamerstip-6cfdb`:

- `verifyMobilePurchase` — default billing URL today is the production function.
- `tippyApi`
- `meEntitlements`
- `gamificationEvents` — only if the build does not use a staging worker instead.
- `apiRetentionTrack` — the Flutter fallback URL uses this name. This repo's `cloud_functions/index.js` does not export it. The live path is the website `POST /api/track`. Confirm which one staging will own before calling it.

Other functions in `cloud_functions/index.js` (video transcode, bookmarks, messages, feed mirror, schedules) are part of the production backend. Copy only the ones a staging phone session actually invokes, after approval.

### Cloudflare

The app currently hardcodes the production worker `https://streamerstip-mux-api.streamerstip.workers.dev` for:

- `POST /mux/direct-upload` (`lib/services/mux_upload_service.dart`)
- R2 media, cross-post, content planning, creator score, and the default gamification events URL

A staging phone would upload and write through that production worker even if Firebase were `streamerstip-stg`. Staging needs its own worker and its own Mux credentials. The production worker URL has to be replaced only in the staging build.

`https://staging.streamerstip.com` must serve the same `/api/*` routes the app already calls, including:

- `/api/account/delete`, `/api/account/provision`, `/api/account/deactivate`, `/api/account/reactivate`
- `/api/auth/resolve-login`, `/api/auth/email-verification/send`, `/api/auth/password-reset/request`
- `/api/billing/apple/verify`, `/api/billing/google/verify`
- `/api/user/entitlements`, `/api/user/credits`
- `/api/track`
- `/api/avatar/save`, `/api/avatar/sync`
- `/api/tippy/chat`, `/api/tippy/credits`, `/api/tippy/onboarding/attach`

DNS for that host is not in place. Creating the worker, the DNS record, and the Mux token is an infrastructure and billing approval.

### Billing and retention

- `MOBILE_BILLING_VERIFY_URL` must be the staging verify function or `https://staging.streamerstip.com/api/billing/…`. It must not contain `streamerstip-6cfdb`.
- `RETENTION_TRACK_URL` and `SITE_API_BASE` must likewise stay off production.
- Do not send a receipt or a retention event until those URLs are proven.

### Mobile config files

Keep the committed production `google-services.json` and `GoogleService-Info.plist` for release builds. Put staging files only in a staging build flavor or an uncommitted staging config directory. Generate them from the `streamerstip-stg` Android and iOS apps after the authenticated project check. Then run `scripts/prove_staging_isolation_guard.sh` logic against those real files, not against a temporary tree.

Dart-defines for that build:

- `FIREBASE_PROJECT_ID=streamerstip-stg`
- `SITE_API_BASE=https://staging.streamerstip.com`
- `STAGING_FIREBASE_API_KEY`, `STAGING_FIREBASE_APP_ID`, `STAGING_FIREBASE_MESSAGING_SENDER_ID`
- `MOBILE_BILLING_VERIFY_URL`
- `RETENTION_TRACK_URL`
- A staging Mux worker base URL, once one exists

## Device-test gate

Start the Android and iOS matrix, playback diagnosis, physical iOS VM attach, and disposable account deletion only when every item below is true:

1. An authenticated session can see `streamerstip-stg` and no second project was created.
2. Staging Auth, Firestore, Storage, and the functions listed above are in that project.
3. The staging worker and `staging.streamerstip.com` answer, and the production worker URL is not compiled into that build.
4. Billing and retention URLs do not contain `streamerstip-6cfdb` or `streamerstip.com` without the `staging.` host.
5. The isolation guard passes on the packaged staging configs.
6. The account used for deletion is disposable and belongs to staging.

None of those are true today.
