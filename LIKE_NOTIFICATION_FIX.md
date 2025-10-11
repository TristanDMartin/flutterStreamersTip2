# ✅ Like Notification Cloud Function - FIXED

## 🎯 **Root Cause Found**

**Problem:** The Cloud Function was listening for likes at the WRONG path!

### **What Was Wrong:**
```javascript
// ❌ INCORRECT (old):
document('videos/{videoId}/likes/{likeId}')

// ✅ CORRECT (new):
document('likes/{videoId}/byUser/{userId}')
```

### **Why It Failed:**
The app stores likes at:
- `likes/{videoId}/byUser/{userId}`

But the Cloud Function was listening at:
- `videos/{videoId}/likes/{likeId}` ❌ (doesn't exist!)

**Result:** When you liked a video from your other account, the like was stored correctly in Firestore, BUT the Cloud Function never triggered because it was watching a different path!

---

## ✅ **The Fix**

**Updated Cloud Function** (`cloud_functions/index.js` line 348):

```javascript
// Trigger: When a video is liked
exports.onLikeCreate = functions.firestore
  .document('likes/{videoId}/byUser/{userId}')  // ✅ CORRECT PATH!
  .onCreate(async (snap, context) => {
    const { videoId, userId } = context.params;
    const likeData = snap.data();
    const likerId = userId;

    console.log(`👍 Like created: Video ${videoId} by user ${likerId}`);

    try {
      // Get video data to find the owner
      const videoDoc = await admin.firestore().collection('videos').doc(videoId).get();
      if (!videoDoc.exists) {
        console.log(`❌ Video ${videoId} not found, skipping notification`);
        return;
      }

      const videoData = videoDoc.data();
      const videoOwnerId = videoData.userId;

      // Don't create notification if user likes their own video
      if (likerId === videoOwnerId) {
        console.log(`ℹ️ User ${likerId} liked their own video, skipping notification`);
        return;
      }

      // Get liker's user data
      const likerDoc = await admin.firestore().collection('users').doc(likerId).get();
      if (!likerDoc.exists) {
        console.log(`❌ Liker ${likerId} not found, skipping notification`);
        return;
      }

      const likerData = likerDoc.data();

      // Create notification for the video owner
      await admin.firestore()
        .collection('notifications')
        .doc(videoOwnerId)
        .collection('items')
        .add({
          type: 'like',
          user: {
            id: likerId,
            username: likerData.username || 'Unknown',
            displayName: likerData.displayName || 'Unknown',
            avatarURL: likerData.avatarURL || likerData.avatarUrl,
          },
          videoId: videoId,
          postThumbnailUrl: videoData.thumbnailUrl,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
          status: 'delivered',
        });

      console.log(`✅ Like notification created: ${likerId} -> ${videoOwnerId} for video ${videoId}`);
    } catch (error) {
      console.error(`❌ Error creating like notification:`, error);
    }
  });
```

---

## 🚀 **Deployment Status**

✅ **Deployed Successfully** at: `2025-10-11T20:28:07.388Z`

**Deployed Function:**
- `onLikeCreate(us-central1)` ✅ Updated with correct path

---

## 🧪 **How to Test**

### **Step 1: Like a Video from Another Account**
1. Open app on **Account A** (e.g., your main account)
2. Upload a video or navigate to an existing video
3. Switch to **Account B** (your other account)
4. Like the video from Account B

### **Step 2: Check ActivityView on Account A**
1. Switch back to **Account A**
2. Open ActivityView (bell icon)
3. You should now see:
   ```
   [Account B Username] liked your video
   [Video thumbnail]
   [Timestamp]
   ```

### **Step 3: Verify Cloud Function Logs (Optional)**
Check Firebase Console → Functions → `onLikeCreate` → Logs

You should see:
```
👍 Like created: Video [videoId] by user [userId]
✅ Like notification created: [likerId] -> [videoOwnerId] for video [videoId]
```

---

## 📊 **Expected Behavior Now**

### **Before Fix:**
- Like stored in Firestore ✅
- Like count incremented ✅
- Cloud Function NEVER triggered ❌
- NO notification created ❌

### **After Fix:**
- Like stored in Firestore ✅
- Like count incremented ✅
- Cloud Function TRIGGERS ✅
- Notification created instantly ✅
- Appears in ActivityView ✅

---

## 🔍 **Why Comments Worked But Likes Didn't**

**Comments:**
- App stores at: `videos/{videoId}/comments/{commentId}` ✅
- Cloud Function listens at: `videos/{videoId}/comments/{commentId}` ✅
- **MATCHED!** → Comments worked perfectly ✅

**Likes:**
- App stores at: `likes/{videoId}/byUser/{userId}` ✅
- Cloud Function was listening at: `videos/{videoId}/likes/{likeId}` ❌
- **MISMATCH!** → Likes never triggered Cloud Function ❌

---

## 🎉 **Summary**

✅ Like Cloud Function path corrected  
✅ Deployed to Firebase  
✅ Now matches actual Firestore like storage path  
✅ Should create notifications for ALL future likes  
✅ Past likes won't generate notifications (that's expected)

**Test now by liking a video from your other account!** 🚀

