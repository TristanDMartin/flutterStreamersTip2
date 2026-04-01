# StreamersTip Release Tracker

Use this tracker during beta prep and final submission review.

## How To Run This Tracker

Run the release process in this order:

1. Configure Android signing
2. Build the Android release artifact
3. Deploy Firebase rules
4. Run Firebase smoke tests against the live project
5. Run iPhone QA on a real device
6. Run Android QA on a real device using the release build
7. Review the beta submission gate

### Android Release Build

Create `android/key.properties` from `android/key.properties.example`, then fill in the real keystore values.

Recommended build commands:

```bash
cd /Users/tristanmartin/Desktop/flutterST
flutter clean
flutter pub get
flutter build appbundle --release
```

Optional APK build for direct device install:

```bash
cd /Users/tristanmartin/Desktop/flutterST
flutter build apk --release
```

### Firebase Rules Deploy

Run these from the repo root after confirming the correct Firebase project is selected:

```bash
cd /Users/tristanmartin/Desktop/flutterST
firebase deploy --only firestore:rules
firebase deploy --only storage
```

If your Firebase CLI config uses aliases, verify the active project first:

```bash
cd /Users/tristanmartin/Desktop/flutterST
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
