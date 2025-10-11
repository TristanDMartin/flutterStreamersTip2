# 🧹 Mock Notification Cleanup - Quick Guide

## 🎯 **Problem**

Your ActivityView shows 21 notifications, but most are **mock/test data**:
- ❌ test_user_1, test_user_2, test_user_3, test_user_4, test_user_5
- ❌ video_1, video_2, video_3, video_4, video_5, video_6
- ❌ test_video
- ❌ Unsplash stock photos

**Only 2-4 notifications are real** (from user "Smove50").

---

## ✅ **Solution: One-Tap Cleanup**

I've added a temporary cleanup button that will:
1. ✅ Delete all mock/test notifications
2. ✅ Keep all real notifications
3. ✅ Safe - runs in a batch transaction

---

## 🚀 **How to Clean Up (Easy Way)**

### **Step 1: Hot Reload the App**
```bash
# The app is already running, just hot reload:
Press 'r' in the terminal
```

### **Step 2: Tap the Cleanup Button**
```
1. Open ActivityView (bell icon)
2. Look for red "Clean Mock Data" button (bottom right)
3. Tap it
4. Confirm "Clean Up" in dialog
5. Wait for "Cleanup complete!"
6. Pull to refresh ActivityView
```

### **Step 3: Remove the Button (After Cleanup)**
Once cleanup is done, I'll remove the button code.

---

## 📊 **What Gets Deleted**

The cleanup service identifies mock data by checking:

### **Mock User IDs:**
- Starts with `test_user` (test_user_1, test_user_2, etc.)
- Exactly `test_user`
- Contains `test_`

### **Mock Video IDs:**
- Exactly `test_video`
- Starts with `video_` (video_1, video_2, etc.)
- Matches pattern `video_\d+`

### **Mock Avatars:**
- URLs containing `images.unsplash.com` (stock photos)

---

## ✅ **What Gets Kept**

### **Real Notifications:**
```dart
{
  user: { id: "QXii8VwEPXWMikqCxST8nsISEYC2" },  // Real user!
  videoId: "1759345724472_1006",  // Real video!
  avatarUrl: null or Firebase Storage URL  // Real avatar!
}
```

**Examples from your logs:**
- Document `PCSySDKXSovuvAotqrwy` - Comment from Smove50 ✅
- Document `CLu3kWv5L8TV7lO0sNg4` - Comment from Smove50 ✅  
- Document `5FScu2M0oj2rmaOMwVHr` - Comment from Smove50 ✅
- Document `mOS9Xk7Y8lZOMtalNSMu` - Comment from Smove50 ✅

---

## 🧪 **Expected Results**

### **Before Cleanup:**
```
✅ Initial Firestore data loaded successfully with 21 notifications
🔍 ActivityView: 4 sections, 4 filtered

Notifications:
  - test_user_1 liked your video ❌
  - test_user_2 started following you ❌
  - test_user_3 commented ❌
  - Smove50 commented "😍" ✅
  - Smove50 commented "leaving a new message" ✅
  ... 16 more mock notifications ❌
```

### **After Cleanup:**
```
✅ Initial Firestore data loaded successfully with 2-4 notifications
🔍 ActivityView: 1 section, 1 filtered

Notifications:
  - Smove50 commented "😂😂😂😂" ✅
  - Smove50 commented "this is amazing love it" ✅
  - Smove50 commented "😍" ✅
  - Smove50 commented "leaving a new message" ✅
```

---

## 🔍 **Manual Cleanup (Alternative)**

If you prefer to clean up via Firebase Console:

```
1. Go to: https://console.firebase.google.com/project/streamerstip-6cfdb/firestore
2. Navigate to: notifications/bU0RxyZ2L4ULAv1Co5L4f825yV73/items
3. Delete documents where:
   - user.id starts with "test_"
   - videoId starts with "video_"
   - videoId == "test_video"
```

---

## 📝 **Files Created**

1. **`lib/services/cleanup_mock_notifications.dart`**
   - Service to identify and delete mock data
   - Safe batch operations
   - Preview mode to see what would be deleted

2. **`lib/widgets/cleanup_mock_notifications_button.dart`**
   - Temporary UI button
   - Only shows in debug mode
   - Confirmation dialog for safety

3. **Modified: `lib/widgets/activity_view.dart`**
   - Added cleanup button to body Stack
   - Only visible in kDebugMode
   - Will be removed after cleanup

---

## 🚀 **After Cleanup**

Once the mock data is gone:

1. **Test Like Notifications:**
   - Have Account A like your video
   - Notification appears instantly ✅
   - Tap thumbnail → Video opens ✅
   - Tap name → Profile opens ✅

2. **Test Name Taps:**
   - Should now work without type errors ✅
   - Look for log: `👆 ActivityView: Profile tap - userId: ..., username: ...`

3. **Remove Cleanup Button:**
   - I'll remove the button code after cleanup is confirmed

---

## 🎯 **Summary**

**Current State:**
- ✅ Code is correct
- ✅ Cloud Functions deployed
- ✅ Navigation wired
- ❌ Mock data in Firestore (21 notifications)

**After Cleanup:**
- ✅ Only real notifications (2-4 from Smove50)
- ✅ All interactions work
- ✅ Ready for two-account testing

**Next Step:** Hot reload and tap the "Clean Mock Data" button! 🚀

