# 🧪 ActivityView Testing & Enhancement Guide

## 📋 **Immediate Testing Checklist**

### **Test 1: Video Resume Functionality** ✅

**Objective**: Verify videos auto-resume when returning from ActivityView

**Steps**:
1. Open the app
2. Navigate to HomeView (ensure video is playing)
3. Tap on DiscoverView (bottom nav)
4. Tap the bell icon (top right) → Opens ActivityView
5. Verify video paused in background
6. Press **back button** (or swipe back on iOS)
7. **Expected Result**: Video should **auto-resume** within ~150ms

**What to Look For**:
- ✅ Video plays automatically (no manual tap needed)
- ✅ Audio unmuted
- ✅ Smooth transition (no lag)

**Debug Logs to Check**:
```
🔄 ActivityView: Popped - resuming HomeView video
▶️ PlaybackManager: Resuming after tab switch
▶️ PlaybackManager: Resumed active video [videoId]
```

**If It Fails**:
- Check if `WillPopScope` is properly wrapping the Scaffold
- Verify `GlobalPlaybackManager` is imported
- Look for errors in console

---

### **Test 2: Memory Leak & Listener Cleanup** ✅

**Objective**: Verify Firestore listeners are properly cancelled

**Steps**:
1. Open ActivityView
2. Check console logs for:
   ```
   🔍 ActivityNotifier: Setting up Firestore listener for user: [userId]
   ```
3. Wait 2-3 seconds (let data load)
4. Press **back** to close ActivityView
5. **Expected Result**: Console should show:
   ```
   🧹 ActivityNotifier: Disposing and cancelling listeners
   ```

**Advanced Test** (Multiple Opens):
1. Open ActivityView → Close → Open → Close (repeat 5 times)
2. Check for EXACTLY **1 setup + 1 dispose** per cycle
3. No "listener already exists" errors
4. No Firestore queries after closing

**What to Look For**:
- ✅ Clean disposal logs every time
- ✅ No memory warnings in console
- ✅ No Firestore queries after close
- ✅ App remains responsive

**Memory Test** (iOS/Android):
- iOS: Instruments → Allocations
- Android: Android Studio → Profiler → Memory
- Open/close ActivityView 10 times
- Memory should return to baseline

---

### **Test 3: Single Initialization (No Duplicates)** ✅

**Objective**: Verify only ONE initialization per view open

**Steps**:
1. Open ActivityView
2. Count init logs:
   ```
   🔄 ActivityNotifier.init called for user: [userId]
   ```
3. Should see EXACTLY **1** init log
4. While ActivityView is open, rotate device (trigger rebuild)
5. **Expected Result**: NO additional init logs
6. Close and reopen ActivityView
7. Should see exactly 1 NEW init log

**What to Look For**:
- ✅ Single init per open
- ✅ No duplicate listeners
- ✅ Rebuilds don't trigger re-init
- ✅ Re-opening creates fresh init

**Debug Logs Pattern**:
```
Open #1:
🔄 ActivityNotifier.init called for user: abc123
🔍 ActivityNotifier: Setting up Firestore listener

[Rotate device - no new logs]

Close #1:
🧹 ActivityNotifier: Disposing and cancelling listeners

Open #2:
🔄 ActivityNotifier.init called for user: abc123  ← Only 1 new init
🔍 ActivityNotifier: Setting up Firestore listener
```

---

### **Test 4: Error Display (No SnackBars)** ✅

**Objective**: Verify errors shown in UI, not SnackBars

**Steps to Trigger Error**:
1. Enable Airplane Mode (disconnect network)
2. Open ActivityView
3. **Expected Result**: 
   - Error shown in center of screen
   - Red error icon
   - Error text: "Something went wrong"
   - "Try Again" button visible
   - **NO SnackBar** appearing

**Alternative Error Test**:
1. Temporarily modify Firestore rules to deny read
2. Open ActivityView
3. Should see error state (not SnackBar)

**What to Look For**:
- ✅ Error displayed in center (_buildErrorState)
- ✅ Red error icon (Icons.error_outline)
- ✅ Selectable error text
- ✅ "Try Again" button works
- ❌ NO SnackBars

---

## 🔍 **Advanced Testing Scenarios**

### **Test 5: Rapid Navigation Stress Test**

**Steps**:
1. Rapidly open/close ActivityView 10 times in a row
2. Check for any crashes or errors
3. Verify memory remains stable
4. Confirm no duplicate listeners

**Expected Result**: 
- App remains responsive
- No crashes
- Clean disposal every time

---

### **Test 6: Background/Foreground Handling**

**Steps**:
1. Open ActivityView
2. Press home button (app goes to background)
3. Wait 5 seconds
4. Return to app
5. **Expected Result**: 
   - Listeners still active
   - Data refreshes properly
   - No crashes

---

### **Test 7: Low Memory Conditions**

**Steps** (Android):
1. Enable "Don't keep activities" in Developer Options
2. Open ActivityView
3. Press home button
4. Open another app
5. Return to your app
6. **Expected Result**: 
   - ActivityView rebuilds properly
   - No duplicate listeners
   - Data loads correctly

---

## 🚀 **Optional Future Enhancements**

Now that all critical issues are fixed, here are enhancements we can implement:

### **Enhancement #1: Pagination** 📄

**Current State**: All notifications loaded at once (fine for <100 notifications)
**Improvement**: Load 20 at a time, fetch more on scroll

**Implementation Plan**:

**Step 1**: Update ActivityNotifier to support pagination

```dart
class ActivityState with _$ActivityState {
  const factory ActivityState({
    @Default({}) Map<String, List<ActivityNotification>> grouped,
    @Default(false) bool isLoading,
    @Default(false) bool isLoadingMore, // New field
    @Default(false) bool hasMoreData,   // New field
    DocumentSnapshot? lastDocument,      // New field for cursor
    // ... existing fields
  }) = _ActivityState;
}
```

**Step 2**: Implement `loadMore()` method

```dart
Future<void> loadMore(String userId) async {
  if (state.isLoadingMore || !state.hasMoreData) return;
  
  state = state.copyWith(isLoadingMore: true);
  
  try {
    Query query = _db
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .orderBy('timestamp', descending: true)
        .limit(20);
    
    // Use cursor if we have it
    if (state.lastDocument != null) {
      query = query.startAfterDocument(state.lastDocument!);
    }
    
    final snapshot = await query.get();
    
    if (snapshot.docs.isEmpty) {
      state = state.copyWith(
        isLoadingMore: false,
        hasMoreData: false,
      );
      return;
    }
    
    // Process new items and merge with existing
    final newItems = snapshot.docs.map((d) {
      final data = d.data();
      return ActivityNotification(
        id: d.id,
        type: _typeFromString((data['type'] ?? 'like').toString()),
        user: const UserConverter().fromJson(
          Map<String, dynamic>.from(data['user'] ?? {}),
        ),
        timestamp: const TimestampConverter().fromJson(data['timestamp']),
        postThumbnailUrl: data['postThumbnailUrl'] as String?,
        commentText: data['commentText'] as String?,
        status: (data['status'] ?? 'pending').toString(),
        videoId: data['videoId'] as String?,
      );
    }).toList();
    
    // Merge with existing grouped data
    final updatedGrouped = Map<String, List<ActivityNotification>>.from(state.grouped);
    for (final n in newItems) {
      final key = _groupKey(n.timestamp);
      updatedGrouped.putIfAbsent(key, () => []).add(n);
    }
    
    state = state.copyWith(
      grouped: updatedGrouped,
      isLoadingMore: false,
      hasMoreData: snapshot.docs.length >= 20,
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
    );
  } catch (e) {
    debugPrint('❌ Error loading more notifications: $e');
    state = state.copyWith(isLoadingMore: false);
  }
}
```

**Step 3**: Update ActivityView's `_loadMoreNotifications()`

```dart
Future<void> _loadMoreNotifications() async {
  if (_isLoadingMore) return;
  
  setState(() {
    _isLoadingMore = true;
  });
  
  try {
    final notifier = ref.read(activityProvider.notifier);
    final auth = ref.read(authServiceProvider);
    final userId = auth.currentUser?.id;
    
    if (userId != null) {
      await notifier.loadMore(userId);
    }
  } catch (e) {
    debugPrint('Error loading more notifications: $e');
  } finally {
    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }
}
```

**Benefit**: Better performance with large notification lists, reduced Firestore reads

---

### **Enhancement #2: Add More Notification Types** 🔔

**Current Types**:
- Like
- Follow
- Comment
- Tag
- Mention

**New Types to Add**:
- **Bookmark**: "User saved your video"
- **Share**: "User shared your video"
- **Reply**: "User replied to your comment"
- **Live**: "User started a live stream"
- **Milestone**: "Your video hit 1K views!"

**Implementation**:

**Step 1**: Update enum in activity_notification.dart

```dart
enum ActivityNotificationType {
  like,
  follow,
  comment,
  tag,
  mention,
  bookmark,    // New
  share,       // New
  reply,       // New
  live,        // New
  milestone,   // New
}
```

**Step 2**: Update filter chips

```dart
final List<String> _filters = [
  'All',
  'Likes',
  'Follows',
  'Comments',
  'Tags',
  'Mentions',
  'Bookmarks',  // New
  'Shares',     // New
  'Replies',    // New
];
```

**Step 3**: Update ActivityRowView to handle new types

```dart
IconData _getNotificationIcon() {
  switch (notification.type) {
    case ActivityNotificationType.bookmark:
      return Icons.bookmark;
    case ActivityNotificationType.share:
      return Icons.share;
    case ActivityNotificationType.reply:
      return Icons.reply;
    case ActivityNotificationType.live:
      return Icons.videocam;
    case ActivityNotificationType.milestone:
      return Icons.celebration;
    // ... existing cases
  }
}
```

**Benefit**: Richer notification system, better user engagement

---

### **Enhancement #3: Enhanced Animations** ✨

**Current Animations**:
- Badge pulse (good)
- Fade in (good)
- Refresh rotate (good)

**New Animations to Add**:

#### **A. Notification Entry Animation**

```dart
class _AnimatedNotificationRow extends StatefulWidget {
  final ActivityNotification notification;
  final int index;
  // ... other params
  
  @override
  State<_AnimatedNotificationRow> createState() => _AnimatedNotificationRowState();
}

class _AnimatedNotificationRowState extends State<_AnimatedNotificationRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 300 + (widget.index * 50)), // Stagger
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));
    
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ActivityRowView(
          notification: widget.notification,
          // ... other params
        ),
      ),
    );
  }
}
```

#### **B. Pull-to-Refresh Indicator Enhancement**

```dart
// Replace standard RefreshIndicator with custom animation
RefreshIndicator(
  onRefresh: _handleRefresh,
  color: Colors.white,
  backgroundColor: const Color(0xFF9248D2),
  strokeWidth: 3.0,
  displacement: 60.0, // More space
  edgeOffset: 0.0,
  // Add custom indicator builder
  child: CustomScrollView(
    physics: const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    ),
    slivers: [
      // ... existing list
    ],
  ),
);
```

#### **C. Mark All Read Animation**

```dart
void _handleMarkAllAsRead() {
  HapticFeedback.lightImpact();
  
  // Animate out all unread notifications
  setState(() {
    _fadeController.reverse().then((_) {
      final notifier = ref.read(activityProvider.notifier);
      final auth = ref.read(authServiceProvider);
      final userId = auth.currentUser?.id;
      
      if (userId != null) {
        notifier.markAllDelivered(userId);
        _fadeController.forward();
      }
    });
  });
  
  // Success feedback
  Future.delayed(const Duration(milliseconds: 300), () {
    HapticFeedback.mediumImpact();
  });
}
```

#### **D. Swipe to Dismiss Notifications**

```dart
Widget _buildActivityList(/* ... */) {
  return ListView.builder(
    // ... existing config
    itemBuilder: (context, index) {
      final notification = items[index];
      
      return Dismissible(
        key: Key(notification.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.red.withOpacity(0.8),
              ],
            ),
          ),
          child: const Icon(
            Icons.delete,
            color: Colors.white,
            size: 24,
          ),
        ),
        confirmDismiss: (direction) async {
          HapticFeedback.mediumImpact();
          return true;
        },
        onDismissed: (direction) {
          _deleteNotification(notification);
        },
        child: ActivityRowView(
          notification: notification,
          // ... params
        ),
      );
    },
  );
}
```

**Benefit**: More polished UI, better user feedback, modern feel

---

## 📊 **Priority Recommendation**

### **High Priority** (Implement Soon):
1. ✅ **Pagination** - Important for scalability
   - Implement when users have 50+ notifications
   - Better performance, reduced costs

### **Medium Priority** (Nice to Have):
2. ⚠️ **New Notification Types** - Adds value
   - Implement as features are built
   - Better engagement

### **Low Priority** (Polish):
3. ℹ️ **Enhanced Animations** - UX polish
   - Implement after core features stable
   - Can be added incrementally

---

## 🎯 **Implementation Order**

### **Phase 1**: Testing (Now)
- ✅ Test all 7 scenarios above
- ✅ Verify all fixes work
- ✅ Confirm no regressions

### **Phase 2**: Pagination (Next)
- Implement cursor-based pagination
- Add "Loading more..." indicator
- Test with large data sets

### **Phase 3**: New Notification Types (Later)
- Add bookmark notifications
- Add share notifications
- Update UI for new types

### **Phase 4**: Animations (Polish)
- Add staggered entry animations
- Implement swipe-to-dismiss
- Enhanced pull-to-refresh

---

## ✅ **Ready to Proceed?**

**Choose your path**:

**Option A**: Test current fixes first (recommended)
- Run through all 7 test scenarios
- Verify everything works
- Document any issues

**Option B**: Implement enhancements now
- Start with pagination
- Add new notification types
- Enhance animations

**Option C**: Both
- Quick smoke test of fixes
- Then implement enhancements
- Full test at the end

**Which would you like to do?** 🚀
