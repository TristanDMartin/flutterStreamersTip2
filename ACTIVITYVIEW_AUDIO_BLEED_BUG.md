# 🐛 CRITICAL BUG: Audio Bleeding to DiscoverView

## 🔴 **Issue Discovered During Testing**

**Test**: Test 1 - Video Resume
**Severity**: 🔴 **CRITICAL**
**Reporter**: User (during systematic testing)

---

## 📋 **Bug Description**

### **What Happens**:
1. User on HomeView (video playing)
2. Navigate to DiscoverView (bottom nav)
3. Tap bell icon → ActivityView opens
4. Press back button from ActivityView
5. **BUG**: Returns to DiscoverView with HomeView audio playing in background

### **Expected Behavior**:
- Return to DiscoverView
- HomeView video should be PAUSED (not playing)
- No audio should be heard on DiscoverView

### **Actual Behavior**:
- Return to DiscoverView
- HomeView video audio is PLAYING (bleeding through)
- User hears video audio while on DiscoverView

---

## 🔍 **Root Cause Analysis**

### **The Problem**:
Our `WillPopScope` in ActivityView calls:
```dart
WillPopScope(
  onWillPop: () async {
    GlobalPlaybackManager.instance.unblock();
    Future.delayed(const Duration(milliseconds: 150), () {
      GlobalPlaybackManager.instance.resumeAfterTabSwitch(); // ❌ WRONG!
    });
    return true;
  },
)
```

This **ALWAYS resumes** video when popping, but ActivityView is accessed from **DiscoverView**, not HomeView!

### **The Flow**:
```
HomeView (video playing)
  ↓ [tap DiscoverView in bottom nav]
DiscoverView (video paused ✅)
  ↓ [tap bell icon]
ActivityView (video still paused ✅)
  ↓ [press back]
DiscoverView (video RESUMES ❌ BUG!)
```

### **Why It Happens**:
- ActivityView doesn't know WHERE it was opened from
- It blindly resumes video on back press
- Should only resume if returning to HomeView
- Should NOT resume if returning to DiscoverView

---

## 🛠️ **The Fix**

### **Solution**: Check which view we're returning to before resuming

### **Implementation**:

We need to track where ActivityView was opened from and only resume if returning to HomeView.

**Option 1**: Pass context in constructor (Simple)
**Option 2**: Check route stack (Complex)
**Option 3**: Only resume if HomeView is visible (Best)

Let's implement **Option 3**: Check if we're actually returning to HomeView

---

## 🔧 **Fix Implementation**

### **Update ActivityView WillPopScope**:

**File**: `lib/widgets/activity_view.dart`

**BEFORE** (Current - Buggy):
```dart
return WillPopScope(
  onWillPop: () async {
    debugPrint('🔄 ActivityView: Popped - resuming HomeView video');
    try {
      GlobalPlaybackManager.instance.unblock();
      Future.delayed(const Duration(milliseconds: 150), () {
        GlobalPlaybackManager.instance.resumeAfterTabSwitch();
      });
    } catch (e) {
      debugPrint('❌ ActivityView: Error resuming video: $e');
    }
    return true;
  },
  child: Scaffold(/* ... */),
);
```

**AFTER** (Fixed):
```dart
return WillPopScope(
  onWillPop: () async {
    debugPrint('🔄 ActivityView: Popped - checking previous route');
    try {
      // Get the route we're returning to
      final navigator = Navigator.of(context);
      final previousRoute = ModalRoute.of(context)?.settings.name;
      
      debugPrint('🔍 ActivityView: Previous route: $previousRoute');
      
      // Only resume video if returning to HomeView (root '/')
      // If returning to DiscoverView or other views, keep video paused
      if (previousRoute == '/' || previousRoute == null) {
        // Returning to HomeView - safe to resume
        debugPrint('✅ ActivityView: Returning to HomeView - resuming video');
        GlobalPlaybackManager.instance.unblock();
        Future.delayed(const Duration(milliseconds: 150), () {
          GlobalPlaybackManager.instance.resumeAfterTabSwitch();
        });
      } else {
        // Returning to another view (DiscoverView, etc.) - keep paused
        debugPrint('⏸️ ActivityView: Returning to $previousRoute - keeping video paused');
        // Do nothing - video stays paused
      }
    } catch (e) {
      debugPrint('❌ ActivityView: Error handling pop: $e');
    }
    return true;
  },
  child: Scaffold(/* ... */),
);
```

### **Problem with Above**: 
Route detection might not work reliably since ActivityView is pushed from DiscoverView.

---

## ✅ **Better Solution: Check Navigator Stack**

Actually, the issue is that ActivityView is pushed FROM DiscoverView, not HomeView. So when popping, we're always returning to DiscoverView, never HomeView.

**The Real Fix**: Don't resume video at all in ActivityView. Let the view that becomes active handle its own playback state.

### **CORRECT FIX**:

**Remove video resume from ActivityView entirely** - it's not ActivityView's responsibility!

```dart
return WillPopScope(
  onWillPop: () async {
    debugPrint('🔄 ActivityView: Popped - NOT resuming video');
    // ✅ Do nothing - let the view we're returning to handle playback
    // This prevents audio bleeding into DiscoverView
    return true;
  },
  child: Scaffold(/* ... */),
);
```

But wait... that breaks the NetworkView fix we did earlier!

---

## 🎯 **ACTUAL ROOT ISSUE**

The real problem is:
1. **NavigationObserver** should handle HomeView resume
2. **WillPopScope in pushed views** should NOT handle resume
3. We added WillPopScope to NetworkView and ActivityView, but they shouldn't resume videos!

The **NavigationObserver** was supposed to handle this, but it wasn't working.

---

## 🔧 **PROPER FIX**

### **Strategy**:
1. Remove video resume from ActivityView WillPopScope
2. Fix NavigationObserver to properly detect when returning to HomeView
3. NetworkView needs same fix

### **Implementation**:

#### **Step 1**: Update ActivityView to NOT resume video

```dart
return WillPopScope(
  onWillPop: () async {
    debugPrint('🔄 ActivityView: Popped');
    // ❌ REMOVED: Video resume - not our responsibility
    // Let NavigationObserver handle playback state
    return true;
  },
  child: Scaffold(/* ... */),
);
```

#### **Step 2**: Fix NavigationObserver to detect HomeView properly

The NavigationObserver should detect when HomeView becomes visible and only then resume.

**File**: `lib/services/navigation_observer.dart`

Need to check: Does the observer properly detect when we're on HomeView vs DiscoverView?

#### **Step 3**: Same fix for NetworkView

Remove video resume from NetworkView's WillPopScope too.

---

## 🎯 **SIMPLEST FIX** (Recommended)

Since ActivityView and NetworkView can be opened from multiple places (DiscoverView, ProfileView, etc.), they should **NEVER** resume videos.

Only **MainTabView** (bottom navigation) should control video playback based on which tab is active.

### **Implementation**:

**1. Remove resume from ActivityView**:
```dart
return WillPopScope(
  onWillPop: () async {
    debugPrint('🔄 ActivityView: Popped - closing without affecting playback');
    // Video playback will be controlled by the view we're returning to
    return true;
  },
  child: Scaffold(/* ... */),
);
```

**2. Remove resume from NetworkView** (same issue there):
```dart
return WillPopScope(
  onWillPop: () async {
    debugPrint('🔄 NetworkView: Popped - closing without affecting playback');
    return true;
  },
  child: Scaffold(/* ... */),
);
```

**3. MainTabView already handles playback** when switching tabs:
- When switching TO HomeView → resumes video ✅
- When switching FROM HomeView → pauses video ✅
- This is in `main_tab_view.dart` line 331-345 (already working)

---

## ✅ **FINAL SOLUTION**

The issue is we're being too aggressive with video resume. Let the parent views control playback, not the modal views.

### **Changes Needed**:

1. **ActivityView**: Remove video resume from WillPopScope
2. **NetworkView**: Remove video resume from WillPopScope  
3. **MainTabView**: Already handles tab switching correctly
4. **NavigationObserver**: Should only block/unblock, not resume

This way:
- Tap DiscoverView → HomeView pauses (MainTabView) ✅
- Open ActivityView → Video stays paused ✅
- Close ActivityView → Return to DiscoverView, video stays paused ✅
- Tap HomeView → Video resumes (MainTabView) ✅

---

## 📊 **Impact**

**Before Fix**:
- ❌ Audio bleeds to DiscoverView
- ❌ Confusing UX
- ❌ Videos play when they shouldn't

**After Fix**:
- ✅ Clean separation of concerns
- ✅ Only HomeView plays videos
- ✅ No audio bleeding
- ✅ Proper playback control

---

## 🔄 **Testing After Fix**

### **Test Scenario**:
```
1. HomeView (video playing)
2. Tap DiscoverView → Video pauses ✅
3. Tap bell icon → ActivityView opens, video stays paused ✅
4. Press back → Return to DiscoverView, video STAYS PAUSED ✅
5. Tap HomeView → Video resumes ✅
```

**Expected Result**: No audio bleeding, video only plays on HomeView

---

## 🎯 **Ready to Apply Fix?**

I'll update both ActivityView and NetworkView to remove the video resume logic, letting the parent views (MainTabView) handle playback control properly.

**Approve to proceed with fix?**
