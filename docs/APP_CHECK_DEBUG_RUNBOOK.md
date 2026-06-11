# App Check debug runbook (streamerstip-6cfdb)

Use this when publish fails with `App attestation failed`, `placeholder token`, or
`PERMISSION_DENIED` even though `UIDs match: true`.

## Your Android app

| Field | Value |
|-------|--------|
| Firebase project | `streamerstip-6cfdb` |
| Package name | `com.streamerstip.streamersTipApp` |
| Debug SHA-256 | `5A:0B:DE:93:25:A7:6D:4F:AC:AA:5B:A5:D6:50:C9:D2:F6:43:54:E5:4F:CC:84:D4:26:2A:5F:22:8D:92:71:D6` |

Console links:

- [App Check](https://console.firebase.google.com/project/streamerstip-6cfdb/appcheck)
- [Project settings → Your apps (SHA)](https://console.firebase.google.com/project/streamerstip-6cfdb/settings/general)

---

## Path A — Fastest for local dev (recommended first)

Unenforce App Check on Firestore while you test uploads.

1. Open [App Check → APIs](https://console.firebase.google.com/project/streamerstip-6cfdb/appcheck/products)
2. Click **Cloud Firestore**
3. Set enforcement to **Unenforced** (not Enforced)
4. Repeat for **Cloud Storage** if uploads use Storage
5. **Stop the app completely** (swipe away), then:

```bash
cd /Users/tristanmartin/Projects/flutterST
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
flutter run
```

6. Try **Publish Now** again. In logs you want:

   - `✅ Firebase App Check activated (debug provider)`
   - `✅ OptimisticVideoService: verified videos/... in Firestore`

---

## Path B — Register debug token (keep enforcement on)

1. Rebuild and run (required — old builds show `No AppCheckProvider installed`):

```bash
cd /Users/tristanmartin/Projects/flutterST
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
flutter run
```

2. In another terminal, capture the debug token:

```bash
export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
adb logcat -c
# cold-start the app (force-stop then open), then:
adb logcat | grep -iE "App Check|DEBUG TOKEN|FirebaseAppCheck"
```

Also check the **flutter run** terminal for:

```text
🔐 App Check DEBUG TOKEN (register in Firebase Console → App Check):
   <long-token-string>
```

3. [App Check](https://console.firebase.google.com/project/streamerstip-6cfdb/appcheck) → your **Android** app → **Manage debug tokens** → **Add debug token** → paste token → Save

4. Confirm debug SHA-256 is listed under [Project settings](https://console.firebase.google.com/project/streamerstip-6cfdb/settings/general) → Android app → SHA certificate fingerprints

5. **Force-stop app**, run `flutter run` again (not hot reload `r`)

---

## Client backoff (Phase 2)

If attestation fails, the app logs `APP_CHECK_ATTESTATION_FAILED` once per 30s
and avoids hammering `getToken(true)`. Register the debug token or unenforce
APIs as above — retries alone will not fix 403.

## Verify success

| Log | Meaning |
|-----|---------|
| `✅ Firebase App Check activated (debug provider)` | Provider installed |
| `🔐 App Check DEBUG TOKEN` or `token refreshed` | Real token (good) |
| `App attestation failed` / `placeholder token` | Still blocked — repeat Path A or B |
| `✅ OptimisticVideoService: verified videos/...` | Firestore placeholder OK |
| `❌ [App Check]` in upload logs | Upload blocked before Mux |
| `❌ [Firestore rules]` | Rules issue (separate from App Check) |

---

## Priority checklist

- [ ] **P0** Path A (unenforce Firestore) **or** Path B (register debug token)
- [ ] **P0** Full app restart after Firebase change
- [ ] **P1** Log shows `verified videos/...`
- [ ] **P2** `creator_metrics` / `scheduled_posts` errors gone
- [ ] **P3** No `deactivated widget's ancestor` on progression panel

If it still fails, paste log lines containing `[App Check]` or `[Firestore rules]`.
