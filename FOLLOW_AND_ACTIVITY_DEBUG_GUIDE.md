# Follow User & ActivityView Debug Guide 🔧

## 🚨 Issues Reported

1. **Follow user failing** - "Failed to follow user" error
2. **ActivityView Firebase issue**

---

## 🔍 Issue #1: Follow User Failure

### Potential Causes

#### Cause A: Missing Fields in User Document

Your user documents need these fields:
```javascript
{
  followersCount: 0,    // ← Must exist!
  followingCount: 0,    // ← Must exist!
  connectionsCount: 0   // ← Must exist!
}
```

**How to check:**
1. Open Firebase Console → Firestore
2. Navigate to `users` → `{your-user-id}`
3. Look for these 3 fields

**If missing:**
```javascript
// Add them manually in Firebase Console:
followersCount: 0
followingCount: 0
connectionsCount: 0
```

---

#### Cause B: EventTriggerService Not Set

The follow operation tries to trigger notifications but EventTriggerService might not be initialized.

**Check console logs for:**
```
⚠️ FollowsService: EventTriggerService not set - no notification will be created
```

**Fix:** The service should still work even without notifications, so this is a warning not a blocker.

---

#### Cause C: Network/Firestore Connection

**Symptoms:**
- Timeout errors
- "Failed to follow user" with no specific reason

**Check:**
1. Internet connection
2. Firebase project connected
3. Firestore database exists and is accessible

---

### Quick Fix Script

Run this in Flutter DevTools console or add temporarily to your code:

```dart
// Check and fix user document fields
Future<void> fixUserFields(String userId) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .get();
      
  if (doc.exists) {
    final data = doc.data()!;
    
    final Map<String, dynamic> updates = {};
    
    if (!data.containsKey('followersCount')) {
      updates['followersCount'] = 0;
    }
    if (!data.containsKey('followingCount')) {
      updates['followingCount'] = 0;
    }
    if (!data.containsKey('connectionsCount')) {
      updates['connectionsCount'] = 0;
    }
    
    if (updates.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(updates);
      print('✅ Fixed missing fields: $updates');
    } else {
      print('✅ All fields present');
    }
  }
}

// Call it:
final currentUser = FirebaseAuth.instance.currentUser;
if (currentUser != null) {
  await fixUserFields(currentUser.uid);
  // Also fix for the user you're trying to follow:
  await fixUserFields(targetUserId);
}
```

---

## 🔍 Issue #2: ActivityView Firebase Issue

### Potential Causes

#### Cause A: Missing notifications/{userId} Document

ActivityView expects this structure:
```
notifications/
  └─ {userId}/
      └─ items/
          └─ {notificationId}/
```

**Check Firebase Console:**
1. Go to `notifications` collection
2. Look for your user ID as a document
3. Check if `items` subcollection exists

**If missing:**
The document is auto-created when first notification is sent. No notifications = empty state (this is normal).

---

#### Cause B: Permission Denied

**Console error:**
```
🚨 Real-time listener error: permission-denied
```

**Fix:**
Your rules look correct, but verify in Firebase Console → Firestore → Rules tab

Required rule:
```javascript
match /notifications/{userId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow create: if request.auth != null;
  
  match /items/{itemId} {
    allow read: if request.auth != null && request.auth.uid == userId;
    allow create: if request.auth != null;
  }
}
```

---

#### Cause C: User Converter Parsing Error

**Console error:**
```
🚨 Real-time update parsing error: ...
```

**This means:** Notification data format doesn't match expected structure.

**Check notification document in Firebase:**
```javascript
{
  type: "follow",
  user: {           // ← Must be an object!
    id: "user123",
    username: "john",
    displayName: "John Doe",
    avatarURL: "https://..."
  },
  timestamp: Timestamp,
  status: "pending"
}
```

---

## 🔧 Complete Diagnostic

Run this to check everything:

```dart
Future<void> runDiagnostics() async {
  print('🔍 Running diagnostics...\n');
  
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    print('❌ No authenticated user');
    return;
  }
  
  print('✅ User authenticated: ${currentUser.uid}\n');
  
  // Check 1: User document fields
  print('📋 Checking user document fields...');
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser.uid)
      .get();
      
  if (userDoc.exists) {
    final data = userDoc.data()!;
    print('  followersCount: ${data['followersCount'] ?? '❌ MISSING'}');
    print('  followingCount: ${data['followingCount'] ?? '❌ MISSING'}');
    print('  connectionsCount: ${data['connectionsCount'] ?? '❌ MISSING'}');
  } else {
    print('  ❌ User document does not exist!');
  }
  
  // Check 2: Follows collection access
  print('\n📋 Checking follows collection access...');
  try {
    final followsSnapshot = await FirebaseFirestore.instance
        .collection('follows')
        .limit(1)
        .get();
    print('  ✅ Can read follows collection');
    print('  Total follows: ${followsSnapshot.docs.length}');
  } catch (e) {
    print('  ❌ Cannot read follows collection: $e');
  }
  
  // Check 3: Can write to follows collection
  print('\n📋 Checking write permission to follows collection...');
  try {
    final testDoc = FirebaseFirestore.instance
        .collection('follows')
        .doc('test_${currentUser.uid}');
    
    await testDoc.set({
      'followerId': currentUser.uid,
      'followedId': 'test_user',
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    print('  ✅ Can write to follows collection');
    
    // Clean up test document
    await testDoc.delete();
    print('  ✅ Test document cleaned up');
  } catch (e) {
    print('  ❌ Cannot write to follows collection: $e');
  }
  
  // Check 4: Notifications collection
  print('\n📋 Checking notifications collection...');
  try {
    final notifSnapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .doc(currentUser.uid)
        .collection('items')
        .limit(1)
        .get();
    print('  ✅ Can read notifications');
    print('  Notifications: ${notifSnapshot.docs.length}');
  } catch (e) {
    print('  ❌ Cannot read notifications: $e');
  }
  
  print('\n✅ Diagnostics complete!');
}
```

---

## 🚀 Quick Fixes

### Fix 1: Add Missing Fields to User Documents

```dart
// Run this for YOUR user:
await FirebaseFirestore.instance
    .collection('users')
    .doc(FirebaseAuth.instance.currentUser!.uid)
    .set({
      'followersCount': 0,
      'followingCount': 0,
      'connectionsCount': 0,
    }, SetOptions(merge: true));

print('✅ Your user document fixed');

// ALSO run for the user you're trying to follow:
await FirebaseFirestore.instance
    .collection('users')
    .doc(targetUserId)  // The user you're trying to follow
    .set({
      'followersCount': 0,
      'followingCount': 0,
      'connectionsCount': 0,
    }, SetOptions(merge: true));

print('✅ Target user document fixed');
```

---

### Fix 2: Check Console for Specific Error

When you try to follow someone, check console output for:

**Look for:**
```
❌ FollowsService: Error following user: [specific error]
```

**Common errors:**

| Error Message | Cause | Fix |
|---------------|-------|-----|
| `permission-denied` | Firestore rules | Check rules in Firebase Console |
| `not-found` | Document doesn't exist | User not properly created |
| `Field 'followersCount' not found` | Missing field | Run Fix 1 above |
| `Transaction failed` | Concurrent updates | Retry the follow |
| `Network error` | No internet | Check connection |

---

### Fix 3: Redeploy Firestore Rules

If rules are out of sync:

```bash
cd /Users/tristanmartin/Desktop/flutterST
firebase deploy --only firestore:rules
```

---

## 🧪 Test Follow After Fixes

### Test 1: Simple Follow Test

```dart
// In Flutter DevTools console or temporary button:
final success = await FollowsService().followUser('target_user_id');
if (success) {
  print('✅ Follow succeeded!');
} else {
  print('❌ Follow failed - check console for errors');
}
```

### Test 2: Check Follow Document Created

After attempting to follow:

1. Open Firebase Console → Firestore
2. Navigate to `follows` collection
3. Look for document: `{your-uid}_{target-uid}`
4. Should exist with:
   ```javascript
   {
     followerId: "your_uid",
     followedId: "target_uid",
     createdAt: Timestamp
   }
   ```

---

## 🎯 Most Likely Fixes

### 90% chance it's one of these:

1. **Missing counter fields** - Run Fix 1 above
2. **User document doesn't exist** - Check Firebase Console
3. **Network connectivity** - Check internet

### For ActivityView Issue:

1. **No notifications yet** - This is normal! Empty state is fine
2. **Permission error** - Redeploy rules
3. **Parse error** - Check notification document structure in Firebase

---

## 📝 Action Items

**For Follow Issue:**
- [ ] Run diagnostics script above
- [ ] Add missing fields (followersCount, followingCount, connectionsCount)
- [ ] Test follow again
- [ ] Check console for specific error

**For ActivityView Issue:**
- [ ] Check if `notifications/{your-uid}/items/` exists in Firebase
- [ ] If empty, try creating a test notification
- [ ] Check console for specific error message
- [ ] Verify Firestore rules deployed

---

## 💡 Quick Debug

Add this button temporarily to your app to run diagnostics:

```dart
FloatingActionButton(
  onPressed: () async {
    await runDiagnostics();
    print('Check console for results');
  },
  child: Icon(Icons.bug_report),
)
```

Then check the console output for specific errors!

---

**Run the diagnostics and let me know what errors you see!** 🔍

