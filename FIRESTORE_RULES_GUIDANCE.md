# Firestore Security Rules - Permission Denied Fix Guidance

## Root Cause Analysis

The PERMISSION_DENIED errors are from **Firestore Security Rules blocking real-time listeners** (`snapshots()`), NOT from missing indexes. Every error is: `Listen for Query(...) failed: PERMISSION_DENIED`

## Collections Causing Issues

1. **engagement** - Multiple queries with videoId, lastUpdated range, engagementScore > 5, ordered
2. **tags** - Query where videoId == ...
3. **scheduled_posts** - Query where authorId == ... and status == scheduled
4. **creator_stats/{uid}/follower_history** - Subcollection read
5. **user_retention_profiles/{uid}** - Doc read

## Common Causes (in order)

### 1. Listeners Starting Before Auth is Ready ⚠️ MOST COMMON
If rules require `request.auth != null`, and listeners start before auth is ready, you'll get permission denied spam.

**Fix:** Only attach listeners after `FirebaseAuth.instance.authStateChanges()` returns a non-null user, or gate them behind your auth provider "ready" state.

### 2. Rules Allow Doc Reads, But Not Query Pattern
Rules are evaluated per document. If your rule says:
```
allow read: if request.auth.uid == resource.data.userId;
```
But documents don't have that field, or it doesn't match, every doc fails and the whole query is denied.

### 3. Querying Server-Only Collections
Collections like `engagement`, `creator_stats`, `user_retention_profiles` often contain analytics/derived data. If locked down (good), UI must fetch via:
- Callable Cloud Function, OR
- Public "safe" projection docs (e.g. `video_public_stats/{videoId}`)

### 4. Path/Structure Mismatch
Example: rules written for `/creator_stats/{uid}` but app reads `/creator_stats/{uid}/follower_history/{doc}` and forgot to add a match block for the subcollection.

## Recommended Fixes by Collection

### ✅ tags (Usually Safe to Allow Reads)
If tags are not sensitive:
```javascript
match /tags/{tagId} {
  allow read: if true;              // or request.auth != null
  allow write: if request.auth != null; // or stricter
}
```

### ✅ scheduled_posts (Private to Author)
Query: `where authorId == bU0R...` - rules must allow reads only if doc's authorId matches signed-in user:
```javascript
match /scheduled_posts/{postId} {
  allow read, list: if request.auth != null
                    && resource.data.authorId == request.auth.uid;

  allow create: if request.auth != null
                && request.resource.data.authorId == request.auth.uid;

  allow update, delete: if request.auth != null
                        && resource.data.authorId == request.auth.uid;
}
```
**Important:** For queries, `resource.data.authorId` must exist on the stored doc.

### ✅ creator_stats/{uid}/follower_history (Private to Creator OR Public)
If only creator should see it:
```javascript
match /creator_stats/{uid} {
  allow read: if request.auth != null && request.auth.uid == uid;

  match /follower_history/{docId} {
    allow read: if request.auth != null && request.auth.uid == uid;
  }
}
```
If you want follower history public, change to `allow read: if true;` on the subcollection.

### ✅ user_retention_profiles/{uid} (Private)
```javascript
match /user_retention_profiles/{uid} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
```

### ⚠️ engagement (Server-Only Recommended)
Client is querying advanced analytics:
- `where lastUpdated > ... AND < ...`
- `where engagementScore > 5`
- `ordering by engagementScore, lastUpdated`

**Best Pattern (Recommended):**
Keep `/engagement` locked, expose safe aggregated doc:
- Write server-side into `video_public_stats/{videoId}` containing `{ likeCount, commentCount, score, ... }`
- Client reads only that

```javascript
match /engagement/{id} {
  allow read, write: if false; // server-only (Admin SDK bypasses rules)
}

match /video_public_stats/{videoId} {
  allow read: if true;
  allow write: if false; // server-only
}
```

**If you really want client reads (not recommended):**
```javascript
match /engagement/{id} {
  allow read: if request.auth != null; // or true
  allow write: if false; // keep writes server-only
}
```

## Clean Rules Baseline

Here's a safe baseline that matches typical app patterns (public tags + public video stats, private scheduled posts/retention, server-only engagement):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function signedIn() { return request.auth != null; }
    function isOwner(uid) { return signedIn() && request.auth.uid == uid; }

    // Public tags (or set to signedIn() if you want)
    match /tags/{id} {
      allow read: if true;
      allow write: if signedIn(); // tighten later
    }

    // Scheduled posts: private to author
    match /scheduled_posts/{postId} {
      allow read: if signedIn() && resource.data.authorId == request.auth.uid;
      allow create: if signedIn() && request.resource.data.authorId == request.auth.uid;
      allow update, delete: if signedIn() && resource.data.authorId == request.auth.uid;
    }

    // Creator stats + follower history: private to that creator
    match /creator_stats/{uid} {
      allow read: if isOwner(uid);

      match /follower_history/{docId} {
        allow read: if isOwner(uid);
      }
    }

    // Retention: private
    match /user_retention_profiles/{uid} {
      allow read, write: if isOwner(uid);
    }

    // Engagement: server-only (recommended)
    match /engagement/{id} {
      allow read, write: if false;
    }

    // Public computed stats (client-safe)
    match /video_public_stats/{videoId} {
      allow read: if true;
      allow write: if false;
    }
  }
}
```

## Debug Checklist

1. **Confirm auth at the moment listeners start:**
   - Log `FirebaseAuth.instance.currentUser?.uid`
   - If null → you're attaching listeners too early

2. **Use the Firestore Rules Simulator:**
   - Pick one example doc from each collection
   - Simulate: Read, and query (list) access for that user

3. **Verify required fields exist:**
   - For scheduled posts: every doc must have `authorId`
   - For creator stats: make sure the path uses the same uid

4. **Don't forget list:**
   - Using `allow read:` is usually enough
   - If you used get/list split rules, make sure queries are allowed too

## What We've Fixed in Code

✅ **Disabled client-side queries** in services:
- `network_effects_service.dart` - Disabled engagement and user_retention_profiles queries
- `realtime_trending_service.dart` - Disabled engagement queries
- `retention_prediction_service.dart` - Added note about current user only
- `creator_growth_service.dart` - Added error handling for permission errors

✅ **Services now return safe defaults** instead of querying:
- Functions return `0.0`, empty lists, or safe defaults
- No more PERMISSION_DENIED errors from these queries

## Next Steps

1. **Update Firestore Rules** using the baseline above
2. **Check for any remaining real-time listeners** that start before auth is ready
3. **Move analytics features to server-side** (Cloud Functions) if needed
4. **Use public aggregated docs** (`video_public_stats`) instead of raw `engagement` queries

