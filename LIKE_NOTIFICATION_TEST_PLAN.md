# 🧪 Like Notification Test Plan

## 🔍 **What I See in Your Logs**

### **From Process 30582 (Latest Logs):**

**Line 638**: `✅ Initial Firestore data loaded successfully with 21 notifications`

**Real notifications from Smove50:**
- Line 617: Comment "this is amazing love it" ✅
- Line 618: Comment "😂😂😂😂" ✅
- Line 634: Comment "😍" ✅
- Line 635: Comment "leaving a new message" ✅

**Missing:**
- ❌ NO like notifications from Smove50!

---

## 🚨 **The Issue: Cloud Function Deployed But Not Tested Yet**

The Cloud Function was **just deployed** at `2025-10-11T20:28:07Z`, but:
- ✅ The function is deployed and active
- ❌ You haven't liked a video SINCE the deployment
- ❌ Old likes (before deployment) won't trigger the function

**Critical:** Cloud Functions only trigger for **NEW documents** created AFTER deployment!

---

## ✅ **How to Test (Step-by-Step)**

### **Step 1: Switch to Smove50 Account**
1. Open the app
2. Sign out from technqs account
3. Sign in as Smove50 (QXii8VwEPXWMikqCxST8nsISEYC2)

### **Step 2: Like a Video from technqs**
1. Go to HomeView (or DiscoverView)
2. Find a video posted by technqs
3. **Double-tap to like** the video (or tap the heart button)
4. Look for this log:
   ```
   💖 Persisting like: video=[videoId], user=QXii8VwEPXWMikqCxST8nsISEYC2 (3 operations)
   ```

### **Step 3: Switch Back to technqs Account**
1. Sign out from Smove50
2. Sign in as technqs (bU0RxyZ2L4ULAv1Co5L4f825yV73)

### **Step 4: Check ActivityView**
1. Open ActivityView (bell icon from DiscoverView)
2. You should now see:
   ```
   Smove50 liked your video
   [Video thumbnail]
   [Timestamp]
   ```

---

## 🔍 **What to Look For in Logs**

### **When Smove50 Likes the Video:**

**App Logs (Smove50's device):**
```
💖 Persisting like: video=[videoId], user=QXii8VwEPXWMikqCxST8nsISEYC2
✅ LikeService: Successfully liked video [videoId]
```

**Cloud Function Logs (Firebase Console):**
```
👍 Like created: Video [videoId] by user QXii8VwEPXWMikqCxST8nsISEYC2
✅ Like notification created: QXii8VwEPXWMikqCxST8nsISEYC2 -> bU0RxyZ2L4ULAv1Co5L4f825yV73
```

### **When technqs Opens ActivityView:**

**App Logs (technqs's device):**
```
🔍 ActivityNotifier: Processing document [docId]: {
  type: like,
  user: {
    id: QXii8VwEPXWMikqCxST8nsISEYC2,
    username: smove50,
    displayName: Smove50,
    avatarURL: [...]
  },
  videoId: [videoId],
  postThumbnailUrl: [...]
  timestamp: [...]
}
```

---

## ⚠️ **Important Notes**

1. **Old likes won't create notifications** - Only NEW likes after deployment
2. **Function takes ~2-5 seconds** - Wait a moment after liking before switching accounts
3. **Check Cloud Function logs** - If you don't see the notification, check Firebase Console → Functions → onLikeCreate → Logs to see if the function triggered

---

## 🎯 **Quick Test Script**

```
1. Smove50: Open app → Like technqs video → See "💖 Persisting like" log
2. Wait 5 seconds (let Cloud Function run)
3. technqs: Open app → Open ActivityView → See "Smove50 liked your video"
```

**If you still don't see the notification after this test, share the logs and I'll investigate further!** 🚀

