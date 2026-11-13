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
- `RETENTION_TRACK_URL` (must not contain `streamerstip-6cfdb`)

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
