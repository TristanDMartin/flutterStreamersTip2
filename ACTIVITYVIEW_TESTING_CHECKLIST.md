# ✅ ActivityView Testing Checklist - Step by Step

## 🎯 **Testing Session Started**

Follow these tests in order. Check off each one as you complete it.

---

## **Test 1: Video Resume Functionality** 🎬

### **Purpose**: Verify videos auto-resume when returning from ActivityView

### **Steps**:
```
1. ✅ Launch the app
2. ✅ Ensure you're on HomeView with a video playing
3. ✅ Tap DiscoverView in bottom navigation
4. ✅ Tap the bell icon (🔔) in top right
5. ✅ ActivityView should open
6. ✅ Verify video paused in background
7. ✅ Press BACK button (or swipe back on iOS)
8. ✅ Return to HomeView
```

### **Expected Result**:
- [ ] Video should **AUTO-RESUME** within ~150-200ms
- [ ] Audio should be unmuted
- [ ] No manual tap required
- [ ] Smooth transition with no lag

### **Debug Logs to Find**:
Look for these in your console/logcat:
```
🔄 ActivityView: Popped - resuming HomeView video
▶️ PlaybackManager: Resuming after tab switch
▶️ PlaybackManager: Resumed active video [some-video-id]
```

### **Test Result**:
- [ ] ✅ PASS - Video auto-resumed
- [ ] ❌ FAIL - Video stayed paused

**Notes**: ____________________________________________

---

## **Test 2: Memory Leak & Listener Cleanup** 🧹

### **Purpose**: Verify Firestore listeners are properly cancelled

### **Steps**:
```
1. ✅ Open ActivityView (bell icon from DiscoverView)
2. ✅ Wait for notifications to load (2-3 seconds)
3. ✅ Check console for setup logs
4. ✅ Press BACK button to close ActivityView
```

### **Expected Result**:
- [ ] See setup log when opening
- [ ] See dispose log when closing
- [ ] No errors or warnings

### **Debug Logs to Find**:

**When Opening**:
```
🔄 ActivityNotifier.init called for user: [userId]
🔍 ActivityNotifier: Setting up Firestore listener for user: [userId]
🔍 ActivityNotifier: Initial load - X documents
✅ Initial Firestore data loaded successfully with X notifications
```

**When Closing**:
```
🧹 ActivityNotifier: Disposing and cancelling listeners
```

### **Advanced Test** (Do this 5 times):
```
Open ActivityView → Wait 2 sec → Close → Repeat 5x
```

**Expected**:
- [ ] Each open shows 1 setup log
- [ ] Each close shows 1 dispose log
- [ ] No duplicate listener warnings
- [ ] No memory warnings
- [ ] App remains responsive

### **Test Result**:
- [ ] ✅ PASS - Clean disposal every time
- [ ] ❌ FAIL - Missing dispose logs or errors

**Notes**: ____________________________________________

---

## **Test 3: Single Initialization (No Duplicates)** 🔢

### **Purpose**: Verify only ONE initialization per view open

### **Steps**:
```
1. ✅ Open ActivityView
2. ✅ Count init logs (should be exactly 1)
3. ✅ While ActivityView is open, rotate device
4. ✅ Check logs again (should be NO new init)
5. ✅ Close ActivityView
6. ✅ Open ActivityView again
7. ✅ Check logs (should be exactly 1 NEW init)
```

### **Expected Result**:
- [ ] First open: Exactly 1 init log
- [ ] Device rotation: 0 additional init logs
- [ ] Close: 1 dispose log
- [ ] Second open: Exactly 1 new init log

### **Debug Logs Pattern**:
```
[First Open]
🔄 ActivityNotifier.init called for user: abc123
🔍 ActivityNotifier: Setting up Firestore listener

[Rotate Device]
(no new init logs - just rebuilds)

[Close]
🧹 ActivityNotifier: Disposing and cancelling listeners

[Second Open]
🔄 ActivityNotifier.init called for user: abc123  ← Only 1 new init
🔍 ActivityNotifier: Setting up Firestore listener
```

### **Test Result**:
- [ ] ✅ PASS - Single init per open, no duplicates
- [ ] ❌ FAIL - Duplicate inits detected

**Notes**: ____________________________________________

---

## **Test 4: Error Display (No SnackBars)** 🚫

### **Purpose**: Verify errors shown in UI center, not SnackBars

### **Steps to Trigger Error**:
```
1. ✅ Enable Airplane Mode on device
2. ✅ Force close the app
3. ✅ Reopen the app
4. ✅ Navigate to DiscoverView → Tap bell icon
5. ✅ ActivityView opens (may show loading)
```

### **Expected Result**:
- [ ] Error shown in **center of screen**
- [ ] Red error icon (⚠️) visible
- [ ] Text: "Something went wrong"
- [ ] "Try Again" button visible
- [ ] **NO SnackBar** appearing at bottom

### **Visual Verification**:
```
Center of Screen Should Show:
┌─────────────────────────┐
│                         │
│      ⚠️ (red icon)      │
│                         │
│  Something went wrong   │
│   [error description]   │
│                         │
│   [Try Again Button]    │
│                         │
└─────────────────────────┘
```

### **Test Result**:
- [ ] ✅ PASS - Error in center, no SnackBar
- [ ] ❌ FAIL - SnackBar appeared or no error shown

**Notes**: ____________________________________________

---

## **Test 5: Rapid Navigation Stress Test** ⚡

### **Purpose**: Ensure app handles rapid open/close without crashes

### **Steps**:
```
Do this sequence 10 times rapidly:
1. ✅ Tap bell icon → ActivityView opens
2. ✅ Immediately tap back → ActivityView closes
3. ✅ Repeat 10 times as fast as possible
```

### **Expected Result**:
- [ ] No crashes or freezes
- [ ] App remains responsive
- [ ] All opens/closes work correctly
- [ ] Each has proper setup/dispose logs
- [ ] No memory warnings

### **Check Console**:
Should see 10 pairs of:
```
🔄 ActivityNotifier.init called
[... loading ...]
🧹 ActivityNotifier: Disposing and cancelling listeners
```

### **Test Result**:
- [ ] ✅ PASS - All 10 cycles clean, no crashes
- [ ] ❌ FAIL - Crash, freeze, or errors

**Notes**: ____________________________________________

---

## **Test 6: Background/Foreground Handling** 📱

### **Purpose**: Verify proper behavior when app goes to background

### **Steps**:
```
1. ✅ Open ActivityView
2. ✅ Let notifications load
3. ✅ Press HOME button (app goes to background)
4. ✅ Wait 5-10 seconds
5. ✅ Return to app (tap app icon or recent apps)
```

### **Expected Result**:
- [ ] ActivityView still visible
- [ ] Data still loaded
- [ ] Listeners still active (if short time)
- [ ] No crashes
- [ ] Can scroll and interact normally

### **Extended Background Test** (1+ minute):
```
1. ✅ Open ActivityView
2. ✅ Press HOME button
3. ✅ Wait 1+ minute
4. ✅ Return to app
```

**Expected**:
- [ ] ActivityView may reload
- [ ] Data refreshes properly
- [ ] No duplicate listeners

### **Test Result**:
- [ ] ✅ PASS - Handles background/foreground correctly
- [ ] ❌ FAIL - Crash or duplicate listeners

**Notes**: ____________________________________________

---

## **Test 7: Low Memory Conditions** 💾

### **Purpose**: Verify proper rebuild after activity destruction

### **Android Only** (iOS automatically manages this):
```
1. ✅ Enable Developer Options
2. ✅ Enable "Don't keep activities"
   (Settings → Developer Options → Don't keep activities)
3. ✅ Open ActivityView
4. ✅ Press HOME button
5. ✅ Wait 3 seconds
6. ✅ Return to app
```

### **Expected Result**:
- [ ] ActivityView rebuilds from scratch
- [ ] Data loads correctly
- [ ] Only 1 new init (not duplicates)
- [ ] No crashes
- [ ] Dispose called before rebuild

### **Debug Logs Pattern**:
```
[Press HOME]
🧹 ActivityNotifier: Disposing and cancelling listeners

[Return to App]
🔄 ActivityNotifier.init called for user: abc123
🔍 ActivityNotifier: Setting up Firestore listener
```

### **Test Result**:
- [ ] ✅ PASS - Rebuilds cleanly, no duplicates
- [ ] ❌ FAIL - Duplicate listeners or crash
- [ ] ⚠️ SKIP - iOS or not applicable

**Notes**: ____________________________________________

---

## **📊 Final Test Summary**

| Test # | Test Name | Result | Notes |
|--------|-----------|--------|-------|
| 1 | Video Resume | [ ] ✅ / [ ] ❌ | _________ |
| 2 | Listener Cleanup | [ ] ✅ / [ ] ❌ | _________ |
| 3 | Single Init | [ ] ✅ / [ ] ❌ | _________ |
| 4 | Error Display | [ ] ✅ / [ ] ❌ | _________ |
| 5 | Rapid Navigation | [ ] ✅ / [ ] ❌ | _________ |
| 6 | Background/Foreground | [ ] ✅ / [ ] ❌ | _________ |
| 7 | Low Memory | [ ] ✅ / [ ] ❌ / [ ] ⚠️ | _________ |

---

## **🎯 Overall Test Result**

**Tests Passed**: ___ / 7

**Tests Failed**: ___ / 7

**Tests Skipped**: ___ / 7

---

## **Issues Found** (if any):

### **Issue #1**:
**Test**: _________________
**Problem**: _________________
**Error Logs**: _________________
**Expected**: _________________
**Actual**: _________________

### **Issue #2**:
**Test**: _________________
**Problem**: _________________
**Error Logs**: _________________
**Expected**: _________________
**Actual**: _________________

---

## **Next Steps**:

### **If All Tests Pass** ✅:
- [ ] Document success
- [ ] Proceed to Phase 2: Enhancements
- [ ] Start with Pagination implementation

### **If Any Tests Fail** ❌:
- [ ] Document exact failure
- [ ] Share error logs
- [ ] We'll debug and fix
- [ ] Retest after fix

---

## **🚀 Ready to Test?**

**Instructions**:
1. Save this checklist
2. Have your device/emulator ready
3. Open your app
4. Go through each test in order
5. Check off boxes as you go
6. Take notes of any issues
7. Report back with results

**Estimated Time**: 15-20 minutes for all tests

**Let me know when you're ready to start or if you need help with any test!** 🧪
