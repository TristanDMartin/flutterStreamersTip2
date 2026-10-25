# Priority 1A: Account Deletion Smoke Test - Execution Plan

**Status:** 🔴 NOT STARTED  
**Gate:** HARD BLOCKER - Must pass before Priority 1B (obfuscated build)  
**Date Started:** _________________  
**Date Completed:** _________________

---

## ⚠️ CRITICAL WARNINGS

### Protected Production Identity

- **USE DISPOSABLE PRODUCTION ACCOUNT ONLY**
- **NEVER DELETE OR RECYCLE THE PRIMARY TECHNQS ACCOUNT**
- Create new test accounts specifically for deletion testing
- Do not use any account you need to preserve

### Test Environment

- Use **PRODUCTION** Firebase project (`streamerstip-6cfdb`)
- Both web and Flutter must test against the same production backend
- Do not use staging/dev for this gate

---

## Prerequisites Checklist

### Backend Deployment

- [ ] `apiAccountDelete` Cloud Function deployed to production
- [ ] Firestore rules deployed
- [ ] Storage rules deployed

**Deploy commands** (run from website repo):
```bash
cd /Users/tristanmartin/Projects/streamerstipReact
firebase use  # Verify correct project
npm run deploy:functions
# OR: firebase deploy --only functions:apiAccountDelete
firebase deploy --only firestore:rules
firebase deploy --only storage
```

### Test Account Setup

- [ ] Create 2+ disposable test accounts with Google/Apple/Email+Password
- [ ] At least one test account has completed Tippy onboarding
- [ ] At least one test account has uploaded a video
- [ ] At least one test account has Twitch connected (optional but recommended)
- [ ] Document test account credentials in a secure location (NOT in git)

**Test Account Template:**
```
Account #1:
- Email: disposable_test_1@example.com
- Provider: Google / Apple / Password
- Has Tippy progress: Yes/No
- Has videos: Yes/No
- Has Twitch: Yes/No
- UID (will fill in after creation): ________________
```

---

## Test Execution Sequence

### Phase 1: Web Account Deletion Test

**Test Account:** Use disposable account #1

#### Step 1: Pre-deletion State Capture

- [ ] Sign in to web app (https://streamerstip.com or your production URL)
- [ ] Navigate to Settings → Account
- [ ] **Document the following:**
  - Firebase Auth UID: ________________
  - Username: ________________
  - Email: ________________
  - Has videos: Yes/No (count: ____)
  - Has Twitch connected: Yes/No
  - Tippy progress completed: Yes/No

- [ ] **Open Firebase Console and document:**
  - `users/{uid}` exists: Yes/No
  - `publicUsers/{uid}` exists: Yes/No
  - `twitchConnections/{uid}` exists: Yes/No (if Twitch connected)
  - `videos` where `ownerId == uid`: count = ____
  - `tippyBotChannels` where `userId == uid`: count = ____

#### Step 2: Execute Deletion

- [ ] On web app: Settings → Account → Scroll to bottom
- [ ] Click "Delete Account" button
- [ ] **Type exactly:** `DELETE`
- [ ] Confirm deletion
- [ ] **Document what happens:**
  - Shows confirmation dialog: Yes/No
  - Sign-out occurs: Yes/No
  - Redirect location: ________________
  - Any error messages: ________________

#### Step 3: Verify Server-side Cleanup

**Wait 30-60 seconds for cleanup to complete**

- [ ] **Firebase Console - Auth:**
  - User with UID deleted from Authentication: Yes/No
  - If No, document error: ________________

- [ ] **Firebase Console - Firestore:**
  - `users/{uid}` deleted: Yes/No
  - `users/{uid}` subcollections deleted: Yes/No (check tippy, preferences, etc.)
  - `publicUsers/{uid}` deleted: Yes/No
  - `twitchConnections/{uid}` deleted: Yes/No
  - `tippyBotChannels` docs for this UID removed: Yes/No

- [ ] **Video Cleanup:**
  - All videos where `ownerId == uid` have:
    - `isDeleted: true` OR
    - `ownerActive: false` OR
    - `feedEligible: false` OR
    - Video doc deleted entirely
  - Verify on web app: Navigate to For You feed, scroll 20+ videos
    - No videos from deleted UID appear: Confirmed/Failed
  - Verify `canonicalPlaybackUrl` or `muxPlaybackId` still exists (Mux not deleted yet)

- [ ] **Storage/Mux (if time permits):**
  - Storage assets for deleted account: Check later in cleanup
  - Mux assets: Check in Mux dashboard (deletion happens later)

#### Step 4: Recreation Test (CRITICAL)

**Use the SAME email/provider as the deleted account**

- [ ] Sign in/sign up with same credentials
- [ ] **MUST land on:** Meet Tippy / Welcome screen
- [ ] **MUST NOT see:**
  - [ ] Resumed Creator DNA mid-step
  - [ ] Old profile information
  - [ ] Guided onboarding mid-flow
  - [ ] Home feed / app shell
  - [ ] Legacy onboarding bypass
  - [ ] Any restored data (videos, follows, etc.)

- [ ] **Document actual behavior:**
  - First screen shown: ________________
  - Any old data visible: Yes/No (describe): ________________
  - New UID assigned: ________________ (should be different from deleted UID)

#### Step 5: Web Test Results

**PASS Criteria:**
- ✅ Auth user deleted
- ✅ `users/{uid}/**` deleted
- ✅ `publicUsers/{uid}` deleted
- ✅ Videos tombstoned (ownerActive/feedEligible/isDeleted set)
- ✅ Twitch cleanup completed (if applicable)
- ✅ Recreation lands on Meet Tippy / Welcome ONLY

**Result:** [ ] PASS [ ] FAIL

**If FAIL, document blockers:**
1. ________________
2. ________________
3. ________________

---

### Phase 2: Flutter Account Deletion Test

**Test Account:** Use disposable account #2 (or recreated account #1 after completing Tippy)

#### Step 1: Build and Install Current Flutter App

- [ ] Hot restart or reinstall Flutter app to ensure latest deletion code
```bash
cd /workspace
flutter clean
flutter pub get
# For Android:
flutter run --release  # Or debug for testing
# For iOS:
flutter run --release  # Requires macOS
```

- [ ] Verify app is running and signed in
- [ ] Navigate to Profile → Settings → Manage Account

#### Step 2: Pre-deletion State Capture

- [ ] **Document the following:**
  - Firebase Auth UID: ________________
  - Username in app: ________________
  - Email: ________________
  - Has videos: Yes/No (count: ____)
  - Has Tippy progress: Yes/No

- [ ] **Open Firebase Console and document:**
  - `users/{uid}` exists: Yes/No
  - `publicUsers/{uid}` exists: Yes/No
  - Video count for this UID: ____

#### Step 3: Execute Deletion from Flutter

- [ ] In Flutter app: Profile → Manage Account → Scroll to bottom
- [ ] Tap "Delete Account"
- [ ] **Type exactly:** `DELETE`
- [ ] Tap Confirm

#### Step 4: Monitor Logs

**During deletion, check Flutter logs for:**

- [ ] `[ACCOUNT_DELETE_REQUEST]` appears
  - Document: `attempt=?` `hasAppCheck=?`
  - Log output: ________________

- [ ] `[ACCOUNT_DELETE_RESPONSE]` appears
  - Document: `httpStatus=?` `ok=?` `deletedAuth=?` `alreadyDeleted=?`
  - Log output: ________________

**Expected:**
```
[ACCOUNT_DELETE_REQUEST] attempt=1 hasAppCheck=true/false
[ACCOUNT_DELETE_RESPONSE] httpStatus=200 ok=true deletedAuth=true
```

**If 404/502/503:** Should auto-retry up to 3 times

- [ ] App signs out automatically: Yes/No
- [ ] Returns to auth/welcome screen: Yes/No

#### Step 5: Verify Server-side Cleanup

**Wait 30-60 seconds**

- [ ] **Firebase Console - Auth:**
  - User deleted: Yes/No

- [ ] **Firebase Console - Firestore:**
  - `users/{uid}` deleted: Yes/No
  - `publicUsers/{uid}` deleted: Yes/No
  - Videos tombstoned: Yes/No

#### Step 6: Recreation Test from Flutter (CRITICAL)

**Use the SAME provider (Google/Apple) as deleted account**

- [ ] Sign in/sign up with same credentials in Flutter app
- [ ] **MUST land on:** Meet Tippy / Welcome screen
- [ ] **MUST NOT see:**
  - [ ] Resumed Tippy session mid-funnel
  - [ ] Old profile information
  - [ ] Home feed immediately
  - [ ] Legacy onboarding bypass
  - [ ] Any restored videos or data

- [ ] **Document actual behavior:**
  - First screen: ________________
  - Any old data: Yes/No (describe): ________________
  - New UID: ________________

#### Step 7: Flutter Test Results

**PASS Criteria:**
- ✅ HTTP `/api/account/delete` succeeds (status 200, ok=true)
- ✅ Logs show proper request/response
- ✅ Auth user deleted
- ✅ `users/{uid}` deleted
- ✅ App signs out
- ✅ Recreation lands on Meet Tippy / Welcome ONLY

**Result:** [ ] PASS [ ] FAIL

**If FAIL, document blockers:**
1. ________________
2. ________________
3. ________________

---

### Phase 3: Partial Failure Testing (Staging/Dev)

**Purpose:** Verify graceful degradation and actionable error messages

**Skip this if you don't have staging environment configured**

#### Setup

- [ ] Switch to staging/dev environment
- [ ] Temporarily break one cleanup step (e.g., unset Mux credentials)

#### Test

- [ ] Attempt deletion
- [ ] **Verify:**
  - Response still shows `ok: true` if Auth + user tree deleted
  - Response includes `warnings[]` array
  - Warning messages are actionable (name the failed step, not vague)
  - Example: `"Failed to delete Mux asset abc123"` not `"Something failed"`

- [ ] Retry deletion on same account
  - Should be idempotent (safe to retry)
  - No zombie Auth user left

#### Results

- [ ] Partial failure handled gracefully: Yes/No
- [ ] Warnings are actionable: Yes/No
- [ ] Retry is safe: Yes/No

---

## Final Gate Results

### Summary

| Test | Result | Notes |
|------|--------|-------|
| Web deletion cleanup | [ ] PASS [ ] FAIL | |
| Web recreation landing | [ ] PASS [ ] FAIL | |
| Flutter deletion cleanup | [ ] PASS [ ] FAIL | |
| Flutter recreation landing | [ ] PASS [ ] FAIL | |
| Partial failure handling | [ ] PASS [ ] FAIL [ ] SKIPPED | |

### Overall Gate Status

**GATE 1 (Account Deletion):** [ ] ✅ PASS [ ] ❌ FAIL

---

## If Gate FAILS

### Do NOT proceed with:
- ❌ Priority 1B (obfuscated build)
- ❌ Any other production hardening
- ❌ R8 enablement
- ❌ Store submission prep

### Required Actions:
1. Document all failures in detail above
2. Fix deletion logic in code (web or Flutter or backend)
3. Redeploy fixed code
4. **Re-run this entire test from the beginning**
5. Gate must pass completely before moving forward

### Common Issues and Fixes

**Issue:** Recreation lands on Home instead of Meet Tippy
- **Cause:** Onboarding bypass logic not checking for fresh account
- **Fix:** Review `account_enforcement.dart` and onboarding routing

**Issue:** Old data appears after recreation
- **Cause:** Incomplete Firestore cleanup or cached data
- **Fix:** Review `account_deletion_service.dart` cleanup logic

**Issue:** Videos still appear in feed after deletion
- **Cause:** Video tombstoning not working
- **Fix:** Verify `ownerActive`, `feedEligible`, `isDeleted` fields set correctly

**Issue:** HTTP 404/502/503 on delete
- **Cause:** Backend not deployed or network issues
- **Fix:** Verify Cloud Function deployment, check Firebase logs

---

## If Gate PASSES

### Next Steps:
1. ✅ Mark this document as COMPLETE
2. ✅ Update `docs/PRODUCTION_HARDENING_CHECKLIST.md` GATE 1 status
3. ✅ Document test account UIDs and results
4. ✅ Proceed to **Priority 1B: First Obfuscated Release Build**

### Archive Test Evidence:
- [ ] Screenshot of Firebase Console showing deleted users
- [ ] Screenshot of Meet Tippy screen after recreation (web)
- [ ] Screenshot of Meet Tippy screen after recreation (Flutter)
- [ ] Copy of Flutter logs showing successful deletion
- [ ] Save this completed checklist

**Evidence Location:** ________________

---

## Sign-off

**Tester Name:** ________________  
**Date Completed:** ________________  
**Gate Result:** PASS / FAIL  
**Reviewer:** ________________  
**Reviewer Sign-off:** ________________

---

## Notes / Observations

Use this space to document any unusual behavior, edge cases discovered, or recommendations:

________________
________________
________________
________________
