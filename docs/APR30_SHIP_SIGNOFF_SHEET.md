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

## Automated evidence (2026-04-29, dev / agent)

- **Unit + widget (Tippy):** `flutter test test/unit/features/tippy test/widgets/tippy_chat_page_test.dart` — **17 passed**.
- **Static analysis:** `dart analyze` — **No issues found**.
- **Firestore rules dry run:** `npx firebase-tools deploy --only firestore:rules --project streamerstip-6cfdb --dry-run` — rules compiled successfully; Firebase reported non-blocking `$(database)` warnings in existing helper references.
- **Security tightening completed:** broad authenticated writes narrowed for engagement, retention, hashtag permissions, analytics, feed writes, moderation, and Tippy telemetry/rate-limit collections.
- **Credits consistency completed:** caption and analyze-content success paths now refresh cached credits, with regression coverage.

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
