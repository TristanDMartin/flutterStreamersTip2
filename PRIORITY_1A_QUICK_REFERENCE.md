# Priority 1A - Quick Reference Card

**GATE 1: Account Deletion Smoke Test**

## 🚨 CRITICAL RULES

1. **USE DISPOSABLE ACCOUNTS ONLY**
2. **NEVER DELETE PRIMARY TECHNQS ACCOUNT**
3. Test on PRODUCTION Firebase project
4. Must pass BOTH web AND Flutter paths
5. STOP if gate fails - do not proceed to Priority 1B

---

## ⚡ Fast Checklist

### Prerequisites
- [ ] `apiAccountDelete` deployed to production
- [ ] Firestore rules deployed
- [ ] 2+ disposable test accounts created
- [ ] Test account credentials documented securely

### Web Path (30 min)
1. [ ] Sign in with disposable account #1
2. [ ] Document UID, username, video count
3. [ ] Settings → Account → Type `DELETE` → Confirm
4. [ ] Verify Firebase: Auth deleted, `users/{uid}` gone, videos tombstoned
5. [ ] Recreate with SAME email → MUST land on Meet Tippy/Welcome
6. [ ] Must NOT see: old data, Home feed, mid-funnel, bypass

### Flutter Path (30 min)
1. [ ] Install/run current Flutter build
2. [ ] Sign in with disposable account #2
3. [ ] Document UID, username
4. [ ] Profile → Manage Account → Type `DELETE` → Confirm
5. [ ] Check logs: `[ACCOUNT_DELETE_RESPONSE] httpStatus=200 ok=true`
6. [ ] Verify Firebase: same cleanup as web
7. [ ] Recreate with SAME provider → MUST land on Meet Tippy/Welcome
8. [ ] Must NOT see: old data, Home feed, mid-funnel, bypass

---

## ✅ Pass Criteria (ALL must be true)

**Web:**
- ✅ Auth user deleted
- ✅ `users/{uid}/**` deleted
- ✅ `publicUsers/{uid}` deleted
- ✅ Videos tombstoned (ownerActive/feedEligible/isDeleted)
- ✅ Twitch/tippyBotChannels cleaned
- ✅ Recreation → Meet Tippy/Welcome ONLY

**Flutter:**
- ✅ HTTP 200, ok=true response
- ✅ Proper logs ([ACCOUNT_DELETE_REQUEST/RESPONSE])
- ✅ Same cleanup as web
- ✅ App signs out automatically
- ✅ Recreation → Meet Tippy/Welcome ONLY

---

## ❌ Common Failures

| Symptom | Likely Cause | Quick Fix |
|---------|--------------|-----------|
| Recreation shows Home | Onboarding bypass not checking fresh account | Check `account_enforcement.dart` |
| Old data after recreation | Incomplete cleanup or cached data | Check `account_deletion_service.dart` |
| Videos still in feed | Tombstoning failed | Verify ownerActive/feedEligible/isDeleted |
| HTTP 404/502/503 | Backend not deployed | Verify Cloud Function deployment |
| Recreation shows mid-funnel | Tippy session not invalidated | Check `TippyOnboardingSessionStore` |

---

## 🔧 Helper Commands

**Verify deletion:**
```bash
bash scripts/verify_account_deletion.sh <uid>
```

**Check Firebase project:**
```bash
cd /Users/tristanmartin/Projects/streamerstipReact
firebase use
```

**Deploy backend (if needed):**
```bash
cd /Users/tristanmartin/Projects/streamerstipReact
firebase deploy --only functions:apiAccountDelete
firebase deploy --only firestore:rules
firebase deploy --only storage
```

**Run Flutter app:**
```bash
cd /workspace
flutter clean && flutter pub get
flutter run --release  # or --debug
```

**View Flutter logs (during deletion):**
```bash
# Android:
adb logcat | grep -E "ACCOUNT_DELETE|AccountDeletionService"

# iOS:
# Use Xcode console or flutter run output
```

---

## 📝 Quick Test Log

**Test Date:** __________

**Web Test:**
- Account UID: __________
- Deletion result: PASS / FAIL
- Recreation result: PASS / FAIL
- Notes: __________

**Flutter Test:**
- Account UID: __________
- HTTP status: __________
- Logs ok: YES / NO
- Deletion result: PASS / FAIL
- Recreation result: PASS / FAIL
- Notes: __________

**Overall Gate 1 Result:** ✅ PASS / ❌ FAIL

---

## 📋 Next Steps

**If PASS:**
1. Update `docs/PRODUCTION_HARDENING_CHECKLIST.md` GATE 1 → [x] PASS
2. Save test evidence (screenshots, logs)
3. Update `PRIORITY_1A_ACCOUNT_DELETION_TEST_PLAN.md` with results
4. **Proceed to Priority 1B: First Obfuscated Release Build**

**If FAIL:**
1. Document failures in detail
2. Fix code (web/Flutter/backend)
3. Redeploy
4. **Re-run entire test**
5. DO NOT proceed to 1B until PASS

---

## 🎯 Success Definition

Both web AND Flutter paths must:
- Complete deletion successfully (HTTP 200, ok=true)
- Clean up ALL Firebase data (Auth, Firestore, references)
- Tombstone videos (not fully delete yet - Mux cleanup is background)
- Sign out automatically
- Recreation with SAME credentials lands on Meet Tippy/Welcome ONLY
- NO old data, NO mid-funnel, NO Home feed, NO bypass

**When this happens → GATE 1 PASSES → Ready for Priority 1B**
