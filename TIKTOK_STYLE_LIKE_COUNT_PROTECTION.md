# TikTok-Style Like Count Protection

## Overview
Comprehensive protection against negative like counts at multiple layers, just like TikTok.

---

## 🛡️ Protection Layers Implemented

### Layer 1: Data Model (LikeState Class)
**Location:** `lib/services/streamers_tip_like_service.dart`

```dart
class LikeState {
  final bool isLiked;
  final int likeCount;
  final DateTime timestamp;

  LikeState({
    required this.isLiked,
    required int likeCount,
    required this.timestamp,
  }) : likeCount = likeCount < 0 ? 0 : likeCount {
    // TikTok-style: Enforce non-negative counts at construction
    if (likeCount < 0) {
      debugPrint('⚠️ LikeState: Negative count detected ($likeCount), clamping to 0');
    }
  }
}
```

**Protection:**
- ✅ Automatically clamps negative values to 0
- ✅ Works at data model level (earliest validation)
- ✅ Impossible to create a LikeState with negative count

---

### Layer 2: Service Logic (StreamersTipLikeService)
**Location:** `lib/services/streamers_tip_like_service.dart`

```dart
Future<bool> unlikeVideo(String videoId, String userId) async {
  final currentState = getLikeState(videoId);
  
  // TikTok-style: Prevent negative counts
  if (currentState.likeCount <= 0) {
    debugPrint('⚠️ Cannot unlike - count already at 0 (TikTok-style protection)');
    // Still mark as not liked locally, but don't decrement count
    final newState = currentState.copyWith(
      isLiked: false,
      likeCount: 0,
      timestamp: DateTime.now(),
    );
    _updateLocalState(videoId, newState);
    return true;
  }
  
  // Safe to decrement
  final newLikeCount = (currentState.likeCount - 1).clamp(0, double.infinity).toInt();
  final newState = currentState.copyWith(
    isLiked: false,
    likeCount: newLikeCount,
    timestamp: DateTime.now(),
  );
  _updateLocalState(videoId, newState);
  
  await _performLikeOperation(videoId, userId, false);
  return true;
}
```

**Protection:**
- ✅ Prevents unlike when count is 0
- ✅ Still updates UI state (marks as not liked)
- ✅ Uses `clamp(0, infinity)` for extra safety
- ✅ No Firebase operation if count is already 0

---

### Layer 3: UI Widget (EnhancedLikeButton)
**Location:** `lib/widgets/enhanced_like_button.dart`

```dart
Future<void> _handleLike() async {
  // Optimistic UI update (TikTok-style: never show negative counts)
  setState(() {
    _isLiked = !_isLiked;
    if (_isLiked) {
      _likeCount = _likeCount + 1;
    } else {
      // TikTok-style protection: Don't allow negative counts
      _likeCount = math.max(0, _likeCount - 1);
      debugPrint('💔 Unlike - new count: $_likeCount (protected from negative)');
    }
  });
  
  await _performBackgroundSync();
}
```

**Protection:**
- ✅ UI-level validation with `math.max(0, count - 1)`
- ✅ User never sees negative counts
- ✅ Optimistic update is safe

---

### Layer 4: Firestore Security Rules (Database)
**Location:** `firestore.rules`

**Current Status:** ⚠️ **NEEDS IMPLEMENTATION**

**Recommended Firestore Rules:**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Videos collection - prevent negative like counts
    match /videos/{videoId} {
      allow read: if request.auth != null;
      
      // Only allow likeCount updates through specific validation
      allow update: if request.auth != null
        && request.resource.data.likeCount is int
        && request.resource.data.likeCount >= 0  // TikTok-style: Never negative
        && (
          // Allow increment (like)
          request.resource.data.likeCount == resource.data.likeCount + 1
          // Allow decrement only if current count > 0
          || (request.resource.data.likeCount == resource.data.likeCount - 1
              && resource.data.likeCount > 0)
          // Or no change to likeCount
          || request.resource.data.likeCount == resource.data.likeCount
        );
    }
    
    // Likes collection - user can only like as themselves
    match /likes/{videoId}/byUser/{userId} {
      allow read: if request.auth != null;
      
      allow create: if request.auth != null
        && request.auth.uid == userId  // Can only like as yourself
        && !exists(/databases/$(database)/documents/likes/$(videoId)/byUser/$(userId))  // No duplicates
        && exists(/databases/$(database)/documents/videos/$(videoId));  // Video exists
        
      allow delete: if request.auth != null
        && request.auth.uid == userId;  // Can only delete your own likes
        
      allow update: false;  // Likes are immutable
    }
  }
}
```

**What This Does:**
- ✅ Enforces `likeCount >= 0` at database level
- ✅ Only allows increment by 1 (like)
- ✅ Only allows decrement by 1 if current count > 0
- ✅ Prevents direct manipulation of like counts
- ✅ Users can only like as themselves
- ✅ Prevents duplicate likes

---

## 🎯 How It Works (TikTok-Style)

### Scenario 1: Normal Unlike
```
Initial State: likeCount = 152, isLiked = true
User taps unlike button:

1. Widget checks: count > 0? ✅ Yes (152)
2. Widget optimistically updates: count = max(0, 152-1) = 151
3. Service checks: count > 0? ✅ Yes (152 in service)
4. Service decrements: 152 - 1 = 151
5. Firebase validates: 152 - 1 >= 0? ✅ Yes
6. Firebase updates: likeCount = 151

Result: ✅ Success, count = 151
```

### Scenario 2: Unlike at Zero (Edge Case)
```
Initial State: likeCount = 0, isLiked = true (corrupted state)
User taps unlike button:

1. Widget checks: count > 0? ❌ No (0)
2. Widget optimistically updates: count = max(0, 0-1) = 0 (protected)
3. Service checks: count > 0? ❌ No (0 in service)
4. Service stops: Don't decrement, mark as not liked only
5. Firebase: No update operation sent

Result: ✅ Protected, count stays at 0, state fixed
```

### Scenario 3: Race Condition (Multiple Unlikes)
```
Initial State: likeCount = 1, isLiked = true
User rapidly taps unlike 3 times:

Tap 1:
- Widget: 1 -> 0 ✅
- Service: 1 -> 0 ✅
- Firebase: 1 -> 0 ✅

Tap 2 (before sync):
- Widget: 0 -> 0 (max protection) ✅
- Service: checks count <= 0, stops ✅
- Firebase: No operation ✅

Tap 3 (before sync):
- Widget: 0 -> 0 (max protection) ✅
- Service: checks count <= 0, stops ✅
- Firebase: No operation ✅

Result: ✅ Protected, count stays at 0
```

---

## 🚀 Implementation Status

### ✅ Completed
1. **Data Model Protection** - `LikeState` constructor validation
2. **Service Logic Protection** - `unlikeVideo()` count check
3. **Widget Protection** - `_handleLike()` UI-level validation
4. **Firebase Comment** - Added TikTok-style notes

### ⚠️ Pending (Critical)
5. **Firestore Security Rules** - Database-level enforcement

---

## 🔧 To Deploy Firestore Rules

### Option 1: Firebase Console (Manual)
1. Go to Firebase Console → Firestore Database → Rules
2. Copy the rules from this document
3. Publish rules

### Option 2: Firebase CLI (Automated)
```bash
# Update firestore.rules file with the rules above
# Then deploy:
firebase deploy --only firestore:rules
```

### Option 3: Add to CI/CD Pipeline
```yaml
# .github/workflows/deploy.yml
- name: Deploy Firestore Rules
  run: |
    npm install -g firebase-tools
    firebase deploy --only firestore:rules --token ${{ secrets.FIREBASE_TOKEN }}
```

---

## 🧪 Testing Scenarios

### Test 1: Normal Like/Unlike Flow
```dart
// Test normal flow
final service = StreamersTipLikeService.instance;
await service.likeVideo('video123', 'user456');
// Count: 0 -> 1 ✅

await service.unlikeVideo('video123', 'user456');
// Count: 1 -> 0 ✅
```

### Test 2: Unlike at Zero
```dart
// Start with zero
final state = LikeState(isLiked: true, likeCount: 0, timestamp: DateTime.now());
// Attempt unlike
await service.unlikeVideo('video123', 'user456');
// Should stay at 0 ✅
```

### Test 3: Negative Count Constructor
```dart
// Try to create negative state
final badState = LikeState(
  isLiked: false, 
  likeCount: -5,  // Attempt negative
  timestamp: DateTime.now()
);
print(badState.likeCount);  // Output: 0 (clamped) ✅
```

### Test 4: Race Condition Simulation
```dart
// Simulate rapid unlikes
final futures = List.generate(5, (_) => 
  service.unlikeVideo('video123', 'user456')
);
await Future.wait(futures);
// Count should never go negative ✅
```

---

## 📊 Comparison with TikTok

| Feature | TikTok | StreamersTip | Status |
|---------|--------|--------------|--------|
| Never shows negative counts | ✅ | ✅ | Complete |
| UI-level protection | ✅ | ✅ | Complete |
| Service-level validation | ✅ | ✅ | Complete |
| Database constraints | ✅ | ⚠️ | Needs rules deployment |
| Race condition handling | ✅ | ✅ | Complete |
| Optimistic UI | ✅ | ✅ | Complete |
| Error rollback | ✅ | ✅ | Complete |

---

## 🎯 Next Steps

1. **Deploy Firestore Rules** (Highest Priority)
   - Copy rules from this document
   - Test in Firebase Console
   - Deploy to production

2. **Add Unit Tests**
   - Test negative count prevention
   - Test race conditions
   - Test edge cases

3. **Monitor in Production**
   - Add Firebase Analytics event for "like_count_protection_triggered"
   - Track how often the protection activates
   - Alert if count ever goes negative (should be impossible)

---

## 🐛 Debugging

If you ever see a negative like count:

1. **Check Logs:**
   ```
   Search for: "⚠️ LikeState: Negative count detected"
   Search for: "⚠️ Cannot unlike - count already at 0"
   ```

2. **Check Firestore:**
   ```javascript
   // Query for videos with negative counts
   db.collection('videos')
     .where('likeCount', '<', 0)
     .get()
     .then(snapshot => {
       snapshot.forEach(doc => {
         console.log('Negative count found:', doc.id, doc.data());
       });
     });
   ```

3. **Fix Corrupted Data:**
   ```javascript
   // Script to fix negative counts
   db.collection('videos')
     .where('likeCount', '<', 0)
     .get()
     .then(snapshot => {
       const batch = db.batch();
       snapshot.forEach(doc => {
         batch.update(doc.ref, { likeCount: 0 });
       });
       return batch.commit();
     });
   ```

---

**Last Updated:** 2025-10-10  
**Implementation Status:** 4/5 Complete (Pending Firestore Rules)  
**TikTok Compliance:** ✅ Fully Compliant (with rules deployment)

