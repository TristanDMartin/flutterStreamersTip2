# Firestore Permissions Fix - Client-Side Query Cleanup

## Summary
Fixed Firestore PERMISSION_DENIED errors by removing client-side queries that violate security rules.

## Important Note
These PERMISSION_DENIED errors are from **Firestore Security Rules blocking real-time listeners** (`snapshots()`), NOT from missing indexes. See `FIRESTORE_RULES_GUIDANCE.md` for detailed rules guidance.

## Changes Made

### 1. ✅ Removed Client-Side user_retention_profiles Queries
**Problem:** Client was querying `user_retention_profiles` collection, including other users' profiles.

**Files Modified:**
- `lib/services/network_effects_service.dart`: Commented out queries to `user_retention_profiles` in `_calculateSimilarUsersEngagement()`. This should be server-side only.

**Impact:** 
- Function `_calculateSimilarUsersEngagement()` now returns 0.0 (safe default)
- This feature should be moved to server-side (Cloud Functions) if needed

### 2. ✅ Removed Client-Side engagement Collection Queries
**Problem:** Multiple services querying `engagement` collection with complex filters that require indexes and violate security.

**Files Modified:**
- `lib/services/network_effects_service.dart`: Commented out engagement queries
- `lib/services/realtime_trending_service.dart`: Commented out engagement queries in `getTrendingInNetwork()`
- `lib/services/enhanced_algorithm_service.dart`: (To be reviewed - may need server-side)

**Impact:**
- These features return safe defaults (0.0, empty lists)
- Core functionality preserved
- Features should be moved to server-side if needed

### 3. ✅ Fixed creator_stats/follower_history Queries
**Problem:** Querying follower_history requires proper authentication context.

**Files Modified:**
- `lib/services/creator_growth_service.dart`: Added error handling - returns 0.0 on permission errors (which is expected for non-creator users)

**Impact:** 
- Service gracefully handles permission errors
- Returns safe default values

### 4. ✅ Tags Collection Queries
**Status:** Tags queries by videoId are acceptable if rules allow public read. These should work with proper rules.

**Recommendation:** Ensure Firestore rules allow:
```
match /tags/{tagId} {
  allow read: if true; // or signedIn()
}
```

### 5. ✅ Likes Collection Pattern
**Status:** Most services already use the correct pattern: `likes/{videoId}/byUser/{userId}`

**Issue Found:** `network_effects_service.dart` was querying root `likes` collection with `where('videoId')` and `where('userId', whereIn: [...])` - this has been disabled.

**Fix Applied:** `_getConnectionsWhoLiked()` now returns empty list. This feature should either:
- Use deterministic paths: `videos/{videoId}/likes/{uid}` with individual get() calls for each connection
- OR: Move to server-side (Cloud Functions) which can query more efficiently

## Next Steps (Server-Side Migration)

For production, these features should be moved to Cloud Functions:

1. **Similar Users Engagement**: Calculate on server, store public aggregates
2. **Network Trending**: Compute on server, expose via public endpoints
3. **User Retention Profiles**: Server-side only (privacy-sensitive)

## Firestore Rules Recommendations

See the user's provided rules template in the original request. Key points:
- Use deterministic paths: `videos/{videoId}/likes/{uid}` instead of queries
- Restrict `user_retention_profiles` to self or admin only
- Move engagement scoring to server-side
- Make creator_stats publicly readable for aggregates only

