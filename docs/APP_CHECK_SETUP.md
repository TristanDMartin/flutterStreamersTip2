# App Check Setup

## Current State

Dart startup **awaits** `activateAppCheckIfEnabled()` in
`lib/core/firebase_app_check_startup.dart` immediately after Firebase init
(`lib/main.dart`).

| Build | Provider | Enabled? |
|-------|----------|----------|
| Debug / Profile | `AndroidDebugProvider` / `AppleDebugProvider` | Yes (default) |
| Release | Play Integrity / DeviceCheck | Yes (default) |

Opt out only with:

```bash
--dart-define=ST_DISABLE_APP_CHECK=true
```

Upload and optimistic placeholder writes call `ensureAppCheckReadyForFirestore()`
first. That waits for activation, then fetches a real token.

If you see `No AppCheckProvider installed` or placeholder-token errors:

1. Confirm cold start logs `✅ Firebase App Check activated (debug provider)`
2. Register the printed **DEBUG TOKEN** in Firebase Console → App Check
3. Or set Firestore/Storage App Check APIs to **Unenforced** while testing
   (see `docs/APP_CHECK_DEBUG_RUNBOOK.md`)

## Firebase Console

1. Project → App Check
2. Register Android app `com.streamerstip.streamersTipApp` (SHA-1 / SHA-256)
3. Release: **Play Integrity**
4. Debug: **Manage debug tokens** → paste token from logcat / flutter run

## HTTP backends

Authenticated HTTP calls attach `X-Firebase-AppCheck` via
`buildAuthenticatedHttpHeaders` (Mux direct-upload, Tippy, billing, etc.).

## Publish telemetry

Filter one publish attempt:

```bash
adb logcat | grep -E 'PUBLISH|RENDER_|APP_CHECK|DIRECT_UPLOAD|UPLOAD_|MUX_|FEED_READY'
```
