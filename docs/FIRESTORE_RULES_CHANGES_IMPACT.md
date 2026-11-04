# Firestore Rules Changes - Website Compatibility Impact

**Date:** 2026-11-04  
**Changes:** Disabled client-side user creation (expired transitional rule)

---

## Changes Made

### 1. User Creation Rule (Line 520-523)

**Before:**
```javascript
// TRANSITIONAL (expires 2026-08-31): owner create until /api/account/provision.
// Target: allow create: if false;
// createWithStarterOnly() also blocks username/displayName on create.
allow create: if hasVerifiedEmail() && isOwner(userId) && createWithStarterOnly();
```

**After:**
```javascript
// PRODUCTION: Client-side user creation disabled (expired 2026-08-31).
// All user accounts must be provisioned via /api/account/provision server endpoint.
// This ensures proper validation, username locking, and server-side initialization.
allow create: if false;
```

### 2. Dual Bookmarks Bridge (Line 1547-1550)

**Before:**
```javascript
// DUAL BOOKMARKS (bridge through 2026-08-31):
```

**After:**
```javascript
// DUAL BOOKMARKS (bridge extended past 2026-08-31):
// TODO: Complete migration to video-scoped bookmarks, then restrict this to read-only.
```

---

## Website Compatibility Analysis

### ✅ **User Creation - NO BREAKING CHANGE**

**Why Safe:**
1. The transitional rule already expired (2026-08-31, today is 2026-11-04)
2. Both Flutter and website should be using `/api/account/provision` server endpoint
3. Client-side user creation was a temporary bridge during migration
4. The `/api/account/provision` endpoint exists and is actively used (see `lib/components/onboarding/complete_verified_activation.dart:277`)

**Website Impact:**
- ✅ If website uses `/api/account/provision` → **No impact**
- ❌ If website still uses client-side Firestore `.set()` for user creation → **Will break**

**Verification Needed:**
```bash
# In streamerstipReact repo, search for user creation patterns
grep -r "users.*\.set\|users.*\.add" src/
grep -r "account/provision" src/
```

**Expected Result:** Website should be using the API endpoint, not direct Firestore writes.

### ✅ **Bookmarks Bridge - NO BREAKING CHANGE**

**Why Safe:**
1. Dual write/read paths are still allowed (not changed)
2. Only updated comment to reflect extension past original deadline
3. Both top-level and video-scoped bookmarks remain accessible

**Website Impact:**
- ✅ No functional change to rules
- ✅ Both bookmark locations still readable/writable

---

## Canonical Contract Alignment

Per `docs/CANONICAL_CONTRACTS.md`:

### Account Creation (Section 3)
> "Signup / risk restrictions are **pre/during create** only."

✅ **Aligned:** Server-side provisioning ensures proper validation, username locking, and initialization.

### Video Ownership (Section 2)
> "A video is publicly feed-eligible only when **all** are true"

✅ **Aligned:** Rules require proper owner resolution and account status checks.

### Data Consistency (Intro)
> "Both repos implement the **same** backend/domain contracts."

✅ **Aligned:** By enforcing server-side account creation, both Flutter and website use the same code path.

---

## Rollback Plan (If Website Breaks)

### Option 1: Temporarily Re-enable Client Creation
```javascript
// EMERGENCY ROLLBACK: Re-enable client creation (temporarily)
allow create: if hasVerifiedEmail() && 
                isOwner(userId) && 
                createWithStarterOnly() &&
                // Add expiry date for accountability
                request.time < timestamp.date(2026, 12, 31);
```

### Option 2: Fix Website to Use API Endpoint
**Recommended permanent fix:**
1. Update website signup flow to call `/api/account/provision`
2. Remove any direct Firestore `.set()` calls for user creation
3. Test thoroughly on staging
4. Deploy website fix first, then re-deploy rules

---

## Testing Checklist

### Before Deploying Rules

- [ ] Verify website uses `/api/account/provision` for signup
- [ ] Test Flutter signup flow with new rules on emulator
- [ ] Test website signup flow with new rules on emulator
- [ ] Confirm no client-side `.set()` calls for user creation in website codebase

### After Deploying Rules

- [ ] Monitor Firestore denied operations dashboard
- [ ] Check Crashlytics for auth/signup errors
- [ ] Monitor user registration metrics
- [ ] Verify both Flutter and website signup flows work
- [ ] Check support tickets for signup issues

### Emergency Contacts

If website breaks:
1. **Immediate:** Check Firebase console → Firestore → denied operations
2. **Rollback:** Use Option 1 above (temporary re-enable)
3. **Fix:** Coordinate with website team to migrate to API endpoint
4. **Re-deploy:** Once website uses API, re-deploy production rules

---

## Deployment Status

- ✅ Rules changes committed to Flutter repo
- ❌ Rules NOT yet deployed to production Firebase
- ⚠️ **Action Required:** Verify website compatibility before deploying

### Deployment Command

```bash
# Deploy Firestore rules (requires ALLOW_FIREBASE_RULES_DEPLOY=1)
ALLOW_FIREBASE_RULES_DEPLOY=1 firebase deploy --only firestore:rules

# Deploy indexes
firebase deploy --only firestore:indexes
```

### Production Deployment Steps

1. **Verify website code** - Confirm it uses `/api/account/provision`
2. **Test on emulator** - Both Flutter and website signup flows
3. **Deploy during low traffic** - Minimize impact if issues arise
4. **Monitor closely** - First 30 minutes after deployment
5. **Have rollback ready** - Keep previous rules version available

---

## Conclusion

**Risk Level:** 🟡 **MEDIUM**

The rule changes are architecturally correct and align with canonical contracts. However, without verifying the website's current implementation, there's a risk of breaking website signup if it still uses client-side Firestore writes.

**Recommendation:**
1. ✅ **Verify website uses `/api/account/provision`** before deploying rules
2. ✅ **Test both platforms** with new rules on Firebase emulator
3. ✅ **Deploy during maintenance window** with monitoring
4. ✅ **Have rollback plan ready** (Option 1 above)

---

**Last Updated:** 2026-11-04  
**Status:** ⚠️ Rules committed but NOT deployed - Website verification pending
