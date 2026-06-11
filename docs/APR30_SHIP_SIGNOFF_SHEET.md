# Apr 30 Ship Sign-Off Sheet

Release: StreamersTip + Tippy  
Date: __________  
Build Version: __________  
Commit SHA: __________  
Environment: Staging [ ]  Production [ ]

---

## Automated evidence (2026-04-27, dev / agent)

Use this block as paste-in evidence for the release record; it does **not** replace mandatory iOS/Android smokes below.

- **Unit + widget (Tippy):** `flutter test test/unit/features/tippy test/widgets/tippy_chat_page_test.dart` — **15 passed**.
- **Static analysis:** `flutter analyze` — no blocking **errors** in the triaged pass; follow-up on remaining infos/warnings in CI.
- **Staging matrix / device smokes:** not executed in agent environment (no Firebase CLI session, no device farm). Complete the iOS and Android rows below on staging before **GO**.

## Automated evidence (2026-06-11, release prep pass)

- **Onboarding:** `flutter test test/widgets/onboarding_widgets_test.dart test/unit/services/onboarding_service_test.dart` — **10 passed** (welcome, goals, platforms, level unlock, service V1).
- **Static analysis:** `dart analyze` — **No issues found**.
- **Cloud Functions unit:** `node tippy_credit_manager_test.js` + `node entitlements_test.js` — **all passed**.
- **Firestore rules dry run:** rules compiled successfully (`firebase deploy --only firestore:rules --dry-run`).
- **iOS CI matrix:** pre-build `flutter build ios --simulator --debug` added to QA workflow and integration runner to fix VM service discovery hang.
- **Blocked (needs founder auth / devices):** Firebase CLI reauth for staging deploy + backfill; mandatory iOS/Android smoke rows; FCM/APNs physical device pass; public beta hold remains **NO-GO**.

## Automated evidence (2026-04-29, dev / agent)

- **Unit + widget (Tippy):** `flutter test test/unit/features/tippy test/widgets/tippy_chat_page_test.dart` — **17 passed**.
- **Static analysis:** `dart analyze` — **No issues found**.
- **Firestore rules dry run:** `npx firebase-tools deploy --only firestore:rules --project streamerstip-6cfdb --dry-run` — rules compiled successfully; Firebase reported non-blocking `$(database)` warnings in existing helper references.
- **Security tightening completed:** broad authenticated writes narrowed for engagement, retention, hashtag permissions, analytics, feed writes, moderation, and Tippy telemetry/rate-limit collections.
- **Credits consistency completed:** caption and analyze-content success paths now refresh cached credits, with regression coverage.

## Production engineering pass (2026-06-10)

### PR summary

- Unified feed playback around the global owner/focus contract, four-controller
  warm window, first-frame watchdog, one recovery remount, lifecycle pause/resume,
  and safe skip behavior.
- Enforced explicit `isReadyForFeed == true` across Home, Following, Discover,
  playback health checks, profile counts, and server feed ranking.
- Aligned Firestore rules/index coverage for video metadata, interactions,
  device tokens, bookmarks, follows, likes, and comments.
- Hardened OAuth/auth-shell routing, entitlement-backed feature gates, Tippy
  retry/error handling, credit deductions, notification token storage, and
  server-backed insights empty states.
- Guarded Firebase-dependent startup helpers, removed a raw admin UID log, and
  kept analyzer output clean.

### Risk notes

- Physical iOS/Android playback, OAuth provider UI, store restore/cancel/grace
  periods, APNs/FCM delivery, and notification deep links still require the
  real-device smoke matrix below.
- Video metadata backfill must run before legacy videos without
  `isReadyForFeed: true` can return to production feeds.
- Firestore rules tests pass locally; deploy rules and indexes together.

### Automated testing

- `dart analyze` - **No issues found**.
- `flutter test` - full unit/widget suite.
- `npm run lint` - Cloud Functions lint passed.
- `node tippy_credit_manager_test.js` and `node entitlements_test.js` - passed.
- Firestore emulator suites passed for videos, interactions/device tokens,
  follows, likes, and comments.
- `git diff --check` - passed.

### Release testing instructions

1. Deploy Firestore rules and indexes together to staging.
2. Run the video metadata backfill in dry-run mode, review counts, then apply.
3. Complete the iOS and Android smoke rows below, including feed tab switching,
   background/foreground playback, OAuth, Tippy failure paths, and billing
   restore/expiry/grace-period checks.
4. Validate a real FCM/APNs notification from receipt through destination route.
5. Hold public release for any open P0/P1 or credit/playback inconsistency.

## 9/10 Readiness Gates

| Area | Current Target | 9/10 Gate |
| --- | ---: | --- |
| Controlled beta | 9/10 candidate | Firestore rules dry run passes, Tippy tests pass, analyzer clean, iOS + Android smoke matrix passes on staging. |
| Public beta | Not yet 9/10 | Controlled beta stable for 24-48h with no P0/P1, no credits anomalies, no auth/upgrade regressions, and logs verified. |
| Security confidence | 9/10 candidate after staging validation | No broad unauthenticated writes, Tippy server-only telemetry/rate-limit collections denied to clients, owner/admin write checks validated against real flows. |
| Visual polish | Pending device pass | Tippy chat, caption, upgrade, retry, and exhaustion states pass on physical iOS and Android without overflow/jank. |

## Public Beta Hold

Public beta remains **NO-GO** until all of the following are true:

- Controlled beta has run for **24-48 hours** without P0/P1 issues.
- Real-device iOS and Android polish pass is complete.
- Backend logs show no auth, upgrade, rate-limit, or credits anomalies.
- Credit balances remain consistent after success, failure, relaunch, and exhaustion paths.
- Founder explicitly converts the launch scope from controlled beta to public beta.

---

## P0 / P1 Gate

- Open P0 issues: Yes [ ] No [ ]
- Open P1 issues: Yes [ ] No [ ]
- If Yes, list IDs: _______________________________________________

**Hard rule:** Any open P0 = **NO-GO**

---

## Mandatory Smoke Run (iOS + Android)

### iOS
- Login: Pass [ ] Fail [ ]
- Open Tippy: Pass [ ] Fail [ ]
- Chat send: Pass [ ] Fail [ ]
- AI caption: Pass [ ] Fail [ ]
- Create plan: Pass [ ] Fail [ ]
- Credits update after success: Pass [ ] Fail [ ]
- Credit exhaustion -> upgrade prompt: Pass [ ] Fail [ ]
- Retry after failure: Pass [ ] Fail [ ]
- No crash / no freeze: Pass [ ] Fail [ ]

### Android
- Login: Pass [ ] Fail [ ]
- Open Tippy: Pass [ ] Fail [ ]
- Chat send: Pass [ ] Fail [ ]
- AI caption: Pass [ ] Fail [ ]
- Create plan: Pass [ ] Fail [ ]
- Credits update after success: Pass [ ] Fail [ ]
- Credit exhaustion -> upgrade prompt: Pass [ ] Fail [ ]
- Retry after failure: Pass [ ] Fail [ ]
- No crash / no freeze: Pass [ ] Fail [ ]

---

## Part 4 — Real-Device Push Notification Validation

The simulator does not fully validate APNs delivery. Run this gate using a TestFlight or release build on a physical iPhone.

### Setup
- TestFlight / release build installed on a physical iPhone: Pass [ ] Fail [ ]
- User logged in: Pass [ ] Fail [ ]
- Notification permission allowed when prompted: Pass [ ] Fail [ ]
- FCM token present in device logs or Firestore at `users/{uid}/deviceTokens/{token}`: Pass [ ] Fail [ ]

### Delivery Test
- Firebase Console → Cloud Messaging → Send test message to the device FCM token: Pass [ ] Fail [ ]
- Or trigger a real notification-producing event (message, follow, etc.): Pass [ ] Fail [ ]
- Notification appears on the lock screen or as a banner: Pass [ ] Fail [ ]
- Tapping the notification opens the expected app destination: Pass [ ] Fail [ ]

### Failure Checks
- Xcode device logs contain no `APNS token not ready yet` registration failure: Pass [ ] Fail [ ]
- Xcode device logs contain no FCM token or delivery errors: Pass [ ] Fail [ ]
- If failed, capture the FCM message result and relevant device log lines: Done [ ] Missing [ ]

### Evidence
- Device model / iOS version: ______________________________________
- Build version: ___________________________________________________
- Test account UID: ________________________________________________
- Test method (Firebase / real event): ______________________________
- Screenshot / screen recording / log link: _________________________

---

## Credits + Auth Integrity

- Successful AI actions decrement credits exactly once: Pass [ ] Fail [ ]
- Failed requests do not decrement credits: Pass [ ] Fail [ ]
- Credits remain accurate after app relaunch: Pass [ ] Fail [ ]
- Expired auth handled correctly (`401` path): Pass [ ] Fail [ ]
- Upgrade flow works on `402`: Pass [ ] Fail [ ]

---

## Reliability + Observability

- Rate limit returns `429` and recovers after cooldown: Pass [ ] Fail [ ]
- `5xx` / timeout / offline retry UX works with preserved input: Pass [ ] Fail [ ]
- No duplicate sends under rapid taps: Pass [ ] Fail [ ]
- Backend logs show `requestId`, `endpoint`, `status`, `latencyMs`: Pass [ ] Fail [ ]
- No sensitive user content in logs: Pass [ ] Fail [ ]

---

## Final Go / No-Go

- Decision: **GO [ ] / NO-GO [ ]**
- Decision Time (UTC): __________
- Launch Scope: Beta [ ] Full [ ]
- Notes / Conditions: ______________________________________________

---

## Team Sign-Off

- Backend Lead: ____________________  Date/Time: ____________________
- Frontend Lead: ___________________  Date/Time: ____________________
- QA Lead: _________________________  Date/Time: ____________________
- Founder (Final): _________________  Date/Time: ____________________

---

## Failure Log Reference

For any failed line item, record:

- Route:
- Action:
- Account type:
- Expected:
- Actual:
- Error code:
- Request ID:
- Screenshot/log link:
