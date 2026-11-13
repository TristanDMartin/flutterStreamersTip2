# Staging isolation

Production Firebase project: `streamerstip-6cfdb`.
Staging Firebase project: `streamerstip-stg`.
Staging site API: `https://staging.streamerstip.com`.

Default app builds stay on production. A staging build must set every
target together. Mixed targets throw `BackendIsolationException`
before Firebase is used.

Required dart-defines for staging:

- `FIREBASE_PROJECT_ID=streamerstip-stg`
- `SITE_API_BASE=https://staging.streamerstip.com`
- `STAGING_FIREBASE_API_KEY`
- `STAGING_FIREBASE_APP_ID`
- `STAGING_FIREBASE_MESSAGING_SENDER_ID`
- `MOBILE_BILLING_VERIFY_URL` (must not contain `streamerstip-6cfdb`)
- `RETENTION_TRACK_URL` (must not contain `streamerstip-6cfdb`). This repo does not export `apiRetentionTrack`. Point staging at `https://staging.streamerstip.com/api/track` unless that function is deployed on `streamerstip-stg`.
- `CLOUDFLARE_WORKER_BASE_URL` (must not be `https://streamerstip-mux-api.streamerstip.workers.dev`). Mux upload, R2, cross-post, content planning, creator score, and gamification follow this value unless a more specific dart-define is set.

`scripts/mobile_feed_playback_matrix.sh` exits before credentials,
install, or `flutter test` unless those variables are set and both
`android/app/google-services.json` and
`ios/Runner/GoogleService-Info.plist` report project id
`streamerstip-stg`.

Those packaged files are still the production apps. Do not replace
them in git with secret values, and do not run the device matrix
until a staging build is prepared outside this repository's production
configs. The feed E2E test also fails before `app.main()` if the
compiled project or the live Firebase app is not `streamerstip-stg`.

This is not evidence that staging exists or that a device run passed.

## Connection status on 2026-11-13

The checkout is not connected to staging.

- Packaged Android and iOS Firebase configs still report `streamerstip-6cfdb`.
- `staging.streamerstip.com` has no DNS record, so the Cloudflare/site API is not reachable.
- `streamerstip-stg.firebasestorage.app` has no DNS record.
- `streamerstip-stg.firebaseapp.com` resolves to the same Google address as the production Firebase host. That does not show a staging project, bucket, or app.
- No staging client config was available to install. The committed production files were left in place.

`scripts/prove_staging_isolation_guard.sh` checks three things: this repo's packaged configs fail the guard, a temporary tree whose project id is `streamerstip-stg` passes it, and that same tree is refused when `CLOUDFLARE_WORKER_BASE_URL` is the production Mux worker. A pass on the temporary tree is not a staging environment.

Device playback, physical iOS attach, and the disposable account-deletion smoke stay stopped until the packaged configs and the staging host exist.
