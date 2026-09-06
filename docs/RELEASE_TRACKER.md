# StreamersTip Release Tracker

Use this tracker during beta prep and final submission review.

**Automation (Phase 2):**

```bash
bash scripts/release_preflight.sh
bash scripts/check_release_dart_defines.sh   # after sourcing .env.release
```

SLO dashboards: [LAUNCH_SLOS.md](./LAUNCH_SLOS.md)

## How To Run This Tracker

Run the release process in this order:

1. Configure Android signing
2. Build the Android release artifact
3. Deploy Firebase rules
4. Run Firebase smoke tests against the live project
5. Run iPhone QA on a real device
6. Run Android QA on a real device using the release build
7. Confirm launch SLOs + dart-defines + store listing
8. Review the beta submission gate

### Android Release Build

Create `android/key.properties` from `android/key.properties.example`, then fill in the real keystore values.

**Canonical command (obfuscated + versioned symbols):**

```bash
cd /Users/tristanmartin/Projects/flutterST
set -a && source .env.release && set +a
bash scripts/release_preflight.sh
bash scripts/build_store_release.sh android
```

This always passes:

- `--release`
- `--obfuscate`
- `--split-debug-info=symbols/<versionName+buildNumber>/`

Retain that symbols folder for every store upload. Optional Crashlytics upload:

```bash
export FIREBASE_ANDROID_APP_ID='1:…:android:…'
bash scripts/upload_crashlytics_symbols.sh
```

Optional APK for direct device install:

```bash
bash scripts/build_store_release.sh android-apk
```

iOS IPA (macOS + signing):

```bash
bash scripts/build_store_release.sh ios
```

Do **not** ship store builds with bare `flutter build … --release` (no obfuscation).

### Firebase Rules Deploy

Run these from the repo root after confirming the correct Firebase project is selected:

```bash
cd /Users/tristanmartin/Projects/flutterST
firebase deploy --only firestore:rules
firebase deploy --only storage
```

If your Firebase CLI config uses aliases, verify the active project first:

```bash
cd /Users/tristanmartin/Projects/flutterST
firebase use
```

### Recommended QA Order

Run QA in this sequence so blockers surface early:

1. Auth
2. Feed playback
3. Publish
4. Messaging
5. Shared drafts
6. Notifications
7. Video download/save on Android

### Minimum Evidence To Capture

- Build output for the signed release artifact
- Firebase deploy output
- Device model + OS version for each QA device
- Notes for each failed test case
- Screen recording for any blocker or high-severity bug
- Crashlytics crash-free screenshot (7-day) for Android + iOS

Status legend:
- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete
- `[!]` Blocked

## 1. Android Signing

### Must Complete
- [ ] Create `android/key.properties` from `android/key.properties.example`
- [ ] Add the real upload keystore path
- [ ] Add the real store password
- [ ] Add the real key alias
- [ ] Add the real key password
- [ ] Build a signed Android release artifact

### Pass / Fail Checks
- [ ] Pass: release build uses upload keystore, not debug signing
- [ ] Pass: package id matches Firebase and Play Console setup
- [ ] Pass: generated artifact is accepted by Play Console internal testing
- [ ] Fail if any release build still falls back to debug signing

### Evidence To Confirm
- [ ] Save successful `flutter build appbundle --release` output
- [ ] Save Play Console upload confirmation
- [ ] Confirm artifact tested was the release build

### Owner / Action
- Owner: ____________________
- Action date: ____________________
- Notes: ____________________

### Beta-Ready Criteria
- [ ] Signed `.aab` installs and uploads without signing errors

---

## 2. Firebase Deploy + Smoke Test

### Must Complete
- [ ] Deploy `firestore.rules`
- [ ] Deploy `storage.rules`
- [ ] Confirm deploy succeeded against the real Firebase project
- [ ] Run live smoke test against production/staging backend

### Pass / Fail Checks
- [ ] Pass: auth works
- [ ] Pass: publish/upload works
- [ ] Pass: feed playback works
- [ ] Pass: messaging works
- [ ] Pass: shared drafts work
- [ ] Pass: notifications work
- [ ] Fail if any core flow hits `permission-denied`

### Evidence To Confirm
- [ ] Save Firebase deploy output
- [ ] Capture screenshots or screen recordings of:
- [ ] auth success
- [ ] upload success
- [ ] feed playback success
- [ ] message send/read success
- [ ] shared draft send/open success
- [ ] notification receive/open success

### Owner / Action
- Owner: ____________________
- Action date: ____________________
- Firebase project: ____________________
- Notes: ____________________

### Beta-Ready Criteria
- [ ] No permission/rules failures in any core flow

---

## 3. iPhone QA

### Must Complete
- [ ] Test on at least one real iPhone
- [ ] Record device model
- [ ] Record iOS version
- [ ] Run auth flow
- [ ] Run feed playback flow
- [ ] Run publish flow
- [ ] Run messaging flow
- [ ] Run shared drafts flow
- [ ] Run notifications flow

### Pass / Fail Checks
- [ ] Pass: long feed scroll is stable
- [ ] Pass: no audio bleed across screens/tabs
- [ ] Pass: no black-screen-with-audio issue
- [ ] Pass: camera opens and records
- [ ] Pass: publish completes
- [ ] Pass: login/signup/logout works
- [ ] Pass: chat send/read works
- [ ] Pass: shared drafts open correctly
- [ ] Pass: push/local notification routing works
- [ ] Fail if any blocker or high-severity bug appears

### Evidence To Confirm
- Device model: ____________________
- iOS version: ____________________
- Tester: ____________________
- [ ] QA notes captured
- [ ] Screen recordings captured for failures

### Owner / Action
- Owner: ____________________
- Action date: ____________________
- Notes: ____________________

### Beta-Ready Criteria
- [ ] No blocker or high-severity issue in core flows on iPhone

---

## 4. Android QA

### Must Complete
- [ ] Test on at least one real Android device
- [ ] Record device model
- [ ] Record Android version
- [ ] Test the release-signed build
- [ ] Run auth flow
- [ ] Run feed playback flow
- [ ] Run publish flow
- [ ] Run messaging flow
- [ ] Run shared drafts flow
- [ ] Run notifications flow
- [ ] Run video download/save flow

### Pass / Fail Checks
- [ ] Pass: release build installs cleanly
- [ ] Pass: feed playback remains stable over long sessions
- [ ] Pass: publish works
- [ ] Pass: messaging works
- [ ] Pass: shared drafts work
- [ ] Pass: notifications work
- [ ] Pass: save/download behavior works with scoped storage
- [ ] Fail if install, permissions, playback, or media flows break

### Evidence To Confirm
- Device model: ____________________
- Android version: ____________________
- Tester: ____________________
- [ ] QA notes captured
- [ ] Screen recordings captured for failures

### Owner / Action
- Owner: ____________________
- Action date: ____________________
- Notes: ____________________

### Beta-Ready Criteria
- [ ] No blocker or high-severity issue in core flows on Android release build

---

## 5. Core Flow Verification Matrix

Mark each flow only after it has been tested on both iPhone and Android.

| Flow | iPhone | Android | Notes |
|---|---|---|---|
| Auth: sign up | [ ] | [ ] | |
| Auth: log in | [ ] | [ ] | |
| Auth: log out | [ ] | [ ] | |
| Feed: open app into feed | [ ] | [ ] | |
| Feed: long scroll stability | [ ] | [ ] | |
| Feed: pause/resume on navigation | [ ] | [ ] | |
| Feed: comments open/close | [ ] | [ ] | |
| Feed: share sheet | [ ] | [ ] | |
| Publish: camera record | [ ] | [ ] | |
| Publish: gallery select | [ ] | [ ] | |
| Publish: StreamersTip-only publish | [ ] | [ ] | |
| Publish: cross-post partial failure handling | [ ] | [ ] | |
| Publish: Manage Posts recovery | [ ] | [ ] | |
| Messaging: open inbox | [ ] | [ ] | |
| Messaging: send text | [ ] | [ ] | |
| Messaging: read state updates | [ ] | [ ] | |
| Shared drafts: send | [ ] | [ ] | |
| Shared drafts: open on recipient side | [ ] | [ ] | |
| Notifications: receive | [ ] | [ ] | |
| Notifications: open target route | [ ] | [ ] | |

---

## 6. Beta Submission Gate

### Must Complete
- [ ] Android signing completed
- [ ] Firebase rules deployed
- [ ] iPhone QA passed
- [ ] Android QA passed
- [ ] Core flow matrix completed
- [ ] Launch SLOs reviewed (section 8)
- [ ] Release dart-defines verified (section 9)
- [ ] Store listing essentials ready (section 10)
- [ ] No unresolved blocker remains

### Pass / Fail Checks
- [ ] Pass: all previous sections are complete
- [ ] Pass: no unresolved blocker in feed, publish, auth, messaging, shared drafts, or notifications
- [ ] Fail if any launch-critical issue is still open

### Evidence To Confirm
- [ ] Signed Android artifact
- [ ] Firebase deploy confirmation
- [ ] iPhone QA notes
- [ ] Android QA notes
- [ ] Blocker list reviewed and empty

### Owner / Action
- Final approver: ____________________
- Decision date: ____________________
- Beta go / no-go: ____________________
- Notes: ____________________

### Beta-Ready Criteria
- [ ] We can truthfully say the app is stable on real devices, correctly signed, backed by deployed rules, and free of launch-critical blockers

---

## 7. Open Issues Log

Use this section to track anything discovered during beta prep.

| Severity | Area | Issue | Owner | Status | Notes |
|---|---|---|---|---|---|
|  |  |  |  |  |  |
|  |  |  |  |  |  |
|  |  |  |  |  |  |

---

## 8. Launch SLOs (Crashlytics / Analytics)

See [LAUNCH_SLOS.md](./LAUNCH_SLOS.md) for dashboard setup.

### Must Complete
- [ ] Crashlytics enabled on release builds (Android + iOS)
- [ ] Confirm Analytics events `slo_first_frame`, `slo_feed_error` appear after a Home session
- [ ] Capture 7-day crash-free sessions ≥ 99.5% Android
- [ ] Capture 7-day crash-free sessions ≥ 99.5% iOS
- [ ] Triage feed errors / BAD_INDEX proxy after matrix run

### Pass / Fail Checks
- [ ] Pass: crash-free ≥ 99.5% both platforms
- [ ] Pass: no unresolved fatal Crashlytics issues in core browse/publish
- [ ] Fail if routine used-after-disposed / AVPlayer / ExoPlayer crashes remain

### Evidence To Confirm
- [ ] Crashlytics dashboard screenshot (Android)
- [ ] Crashlytics dashboard screenshot (iOS)
- [ ] Analytics Exploration or event counts for SLO events

### Owner / Action
- Owner: ____________________
- Action date: ____________________
- Notes: ____________________

---

## 9. Release dart-defines

Copy `.env.release.example` → `.env.release` (gitignored).

### Must Complete
- [ ] `GIPHY_API_KEY` set (no placeholder)
- [ ] `MOBILE_BILLING_VERIFY_URL` set to live verify function
- [ ] `TIPPY_API_BASE` set if not using project-derived default
- [ ] `bash scripts/check_release_dart_defines.sh` passes
- [ ] Release AAB/IPA built with the same defines

### Pass / Fail Checks
- [ ] Pass: no empty Giphy key in release
- [ ] Pass: IAP verify URL reaches production function
- [ ] Fail if release build still uses debug placeholders

### Evidence To Confirm
- [ ] Preflight output saved
- [ ] Build command line / CI secrets checklist saved (no secret values)

---

## 10. Store listing

### Must Complete
- [ ] Privacy policy URL live
- [ ] Data safety form completed (Play)
- [ ] App Privacy nutrition labels completed (App Store)
- [ ] Camera / mic / photo library permission justifications match usage
- [ ] Review notes for video/social app (demo account if needed)
- [ ] Store icons / screenshots for phone sizes

### Pass / Fail Checks
- [ ] Pass: listing accepted by store review without permission-policy rejection
- [ ] Fail if permission text does not match actual features

### Evidence To Confirm
- [ ] Privacy policy URL
- [ ] Screenshot of Data Safety / App Privacy sections
- [ ] Review notes draft

---

## 11. Device matrix / nightly schedule

### Must Complete
- [ ] Pixel (or primary Android) matrix green via `scripts/mobile_feed_playback_matrix.sh`
- [ ] iPhone matrix or manual QA covering Home gate scenarios
- [ ] Schedule recurring run (local cron, device farm, or Monday manual)

### Suggested local schedule

```bash
# Example Monday preflight + matrix (fill device IDs)
# 0 10 * * 1 cd /Users/tristanmartin/Projects/flutterST && bash scripts/release_preflight.sh
# 0 11 * * 1 DEVICES="PIXEL_ID IPHONE_ID" ./scripts/mobile_feed_playback_matrix.sh
```

GitHub workflow `release-preflight.yml` runs repo-side preflight on a weekly schedule (no devices).

### Evidence To Confirm
- [ ] Latest matrix summary attached
- [ ] Owner assigned for weekly run
