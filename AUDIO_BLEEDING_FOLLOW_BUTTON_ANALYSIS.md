# Audio Bleeding & Following Button Issues - Detailed Analysis

## 🎵 Audio Bleeding Problem

### Root Cause Analysis

The audio bleeding issue occurs because the **GlobalPlaybackManager** and **NavigationObserver** are not properly coordinating to pause videos when navigating away from HomeView. Here are the specific problems:

#### 1. **NavigationObserver Logic Issues**
```dart
// lib/services/navigation_observer.dart:80-91
final shouldKeepVideoPlaying =
    owner?.contains('modalbottomsheetroute') == true ||
        owner?.contains('comments') == true ||
        owner?.contains('share') == true ||
        route.runtimeType.toString().contains('ModalBottomSheetRoute');

if (shouldKeepVideoPlaying) {
  // Don't call onRouteChange for these modals - let video keep playing
  return;
}
```

**Problem**: This logic is **too permissive** and allows videos to keep playing when they shouldn't.

#### 2. **GlobalPlaybackManager Blocking Issues**
```dart
// lib/services/global_playback_manager.dart:213-224
void block({String? reason}) {
  _blockLevel++;
  _blockReason = reason ?? 'manual_block';
  
  log('🚫 PlaybackManager: BLOCKED (level: $_blockLevel) - reason: $_blockReason');
  
  // Pause all videos when blocking
  pauseAll();
  
  // Notify listeners
  _playbackBlockedController.add(true);
}
```

**Problem**: The blocking system works, but **unblocking** doesn't properly restore the correct video state.

#### 3. **VideoPlayerViewOptimized State Management**
```dart
// lib/widgets/video_player_view_optimized.dart:387-401
final homeState = ref.read(homeProvider);
if (homeState.shouldPauseAllVideos) {
  // IMMEDIATE pause - stops audio instantly
  _safePause().then((_) {
    log('⏸️ Video paused due to HomeView navigation: ${widget.video.id}');
    // Update UI state after build completes (prevents setState error)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });
  });
  return;
}
```

**Problem**: The `shouldPauseAllVideos` flag is not being set consistently across all navigation scenarios.

### Specific Scenarios Where Audio Bleeds:

1. **Navigating to NetworkView** - Audio continues playing
2. **Opening Settings** - Audio continues playing  
3. **Opening Profile View** - Audio continues playing
4. **Opening Chat/Inbox** - Audio continues playing
5. **Opening Share Sheets** - Audio continues playing (intended, but sometimes bleeds)

## 👥 Following Button Problem

### Root Cause Analysis

The following button has **multiple conflicting services** trying to handle the same functionality:

#### 1. **Multiple Follow Services Conflict**
- `FollowsService` - Uses `follows/{followerId}_{followedId}` collection
- `FollowButtonService` - Uses `users/{userId}/connections/{targetId}` collection  
- `RealUserDataService` - Uses `follows` collection with different structure

#### 2. **Inconsistent Data Models**
```dart
// FollowsService uses:
follows/{followerId}_{followedId} = {
  followerId: string,
  followedId: string,
  createdAt: timestamp
}

// FollowButtonService uses:
users/{userId}/connections/{targetId} = {
  followState: 'following' | 'mutual',
  canDM: boolean,
  updatedAt: timestamp
}
```

#### 3. **State Management Issues**
The follow button state is not properly synchronized between:
- UI state (what the button shows)
- Firestore state (what's actually stored)
- Real-time updates (when other users follow/unfollow)

## 🔧 Required Fixes

### Audio Bleeding Fixes

#### 1. **Fix NavigationObserver Logic**
```dart
// lib/services/navigation_observer.dart
void _handleRouteChange(Route<dynamic>? route, {required bool isForeground}) {
  // Determine the owner based on route name or settings
  String? owner = _determineRouteOwner(route);
  
  // 🔊 AUDIO FIX: Always block playback when leaving home
  final isHomeRoute = owner == 'home' || owner == '/';
  
  if (!isHomeRoute && isForeground) {
    _manager.block(reason: 'route_change_$owner');
    debugPrint('🚫 NavigationObserver: Blocking playback for non-home route: $owner');
  } else if (isHomeRoute && isForeground) {
    _manager.unblock();
    // Only resume if we're actually on the home tab
    Future.delayed(const Duration(milliseconds: 100), () {
      _manager.resumeAfterTabSwitch();
    });
    debugPrint('✅ NavigationObserver: Unblocking playback for home route: $owner');
  }
}
```

#### 2. **Fix GlobalPlaybackManager Unblocking**
```dart
// lib/services/global_playback_manager.dart
void unblock() {
  if (_blockLevel > 0) {
    _blockLevel--;
    
    if (_blockLevel == 0) {
      _blockReason = null;
      log('✅ PlaybackManager: UNBLOCKED - resuming playback');
      
      // 🔥 FIX: Only resume if we have an active video and owner
      if (_activeVideoId != null && _activeOwner != null) {
        _resumeActiveVideo();
      }
      
      // Notify listeners
      _playbackBlockedController.add(false);
    } else {
      log('🔒 PlaybackManager: Still blocked (level: $_blockLevel)');
    }
  }
}
```

#### 3. **Fix HomeProvider State Management**
```dart
// lib/providers/home_provider.dart
class HomeNotifier extends StateNotifier<HomeState> {
  void pauseAllVideos() {
    state = state.copyWith(shouldPauseAllVideos: true);
    
    // 🔥 FIX: Use GlobalPlaybackManager to ensure all videos are paused
    GlobalPlaybackManager.instance.block(reason: 'home_navigation');
  }
  
  void resumeVideos() {
    state = state.copyWith(shouldPauseAllVideos: false);
    
    // 🔥 FIX: Unblock and resume active video
    GlobalPlaybackManager.instance.unblock();
  }
}
```

### Following Button Fixes

#### 1. **Consolidate Follow Services**
```dart
// lib/services/unified_follow_service.dart
class UnifiedFollowService {
  static final UnifiedFollowService _instance = UnifiedFollowService._internal();
  factory UnifiedFollowService() => _instance;
  UnifiedFollowService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Follow a user using the correct data model
  Future<bool> followUser(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;
    
    try {
      final currentUserId = currentUser.uid;
      
      // Use the correct follows collection structure
      final followDocId = '${currentUserId}_$targetUserId';
      final followRef = _firestore.collection('follows').doc(followDocId);
      
      await followRef.set({
        'followerId': currentUserId,
        'followedId': targetUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Update counters
      await _updateFollowCounters(currentUserId, targetUserId, increment: 1);
      
      return true;
    } catch (e) {
      debugPrint('❌ UnifiedFollowService: Error following user: $e');
      return false;
    }
  }
  
  /// Check if current user follows target user
  Future<bool> isFollowing(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;
    
    try {
      final followDocId = '${currentUser.uid}_$targetUserId';
      final followDoc = await _firestore.collection('follows').doc(followDocId).get();
      return followDoc.exists;
    } catch (e) {
      debugPrint('❌ UnifiedFollowService: Error checking follow status: $e');
      return false;
    }
  }
}
```

#### 2. **Fix Follow Button Widget**
```dart
// lib/widgets/follow_button_widget.dart
class FollowButtonWidget extends ConsumerStatefulWidget {
  final String targetUserId;
  final String targetDisplayName;
  
  const FollowButtonWidget({
    Key? key,
    required this.targetUserId,
    required this.targetDisplayName,
  }) : super(key: key);
  
  @override
  ConsumerState<FollowButtonWidget> createState() => _FollowButtonWidgetState();
}

class _FollowButtonWidgetState extends ConsumerState<FollowButtonWidget> {
  bool _isFollowing = false;
  bool _isLoading = false;
  late StreamSubscription<DocumentSnapshot> _followSubscription;
  
  @override
  void initState() {
    super.initState();
    _setupFollowListener();
  }
  
  void _setupFollowListener() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final followDocId = '${currentUser.uid}_${widget.targetUserId}';
    _followSubscription = FirebaseFirestore.instance
        .collection('follows')
        .doc(followDocId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _isFollowing = snapshot.exists;
        });
      }
    });
  }
  
  Future<void> _handleFollowToggle() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      final followService = UnifiedFollowService();
      bool success;
      
      if (_isFollowing) {
        success = await followService.unfollowUser(widget.targetUserId);
      } else {
        success = await followService.followUser(widget.targetUserId);
      }
      
      if (success) {
        // State will be updated by the listener
        HapticFeedback.lightImpact();
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${_isFollowing ? 'unfollow' : 'follow'} ${widget.targetDisplayName}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ FollowButton: Error toggling follow: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleFollowToggle,
      style: ElevatedButton.styleFrom(
        backgroundColor: _isFollowing ? Colors.grey : Colors.blue,
        foregroundColor: Colors.white,
      ),
      child: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(_isFollowing ? 'Following' : 'Follow'),
    );
  }
  
  @override
  void dispose() {
    _followSubscription.cancel();
    super.dispose();
  }
}
```

## 🎯 Implementation Priority

### High Priority (Audio Bleeding)
1. **Fix NavigationObserver** - Ensure all non-home routes block playback
2. **Fix GlobalPlaybackManager** - Proper unblocking and state restoration
3. **Fix HomeProvider** - Consistent state management

### Medium Priority (Following Button)
1. **Create UnifiedFollowService** - Single source of truth for follow operations
2. **Update FollowButtonWidget** - Use unified service and real-time updates
3. **Remove conflicting services** - Clean up old follow services

### Low Priority (Testing & Verification)
1. **Add comprehensive tests** for both audio and follow functionality
2. **Add debug logging** to track state changes
3. **Add error handling** for edge cases

## 🧪 Testing Checklist

### Audio Bleeding Tests
- [ ] Navigate to NetworkView - Audio should stop
- [ ] Navigate to Settings - Audio should stop
- [ ] Navigate to Profile - Audio should stop
- [ ] Navigate to Chat/Inbox - Audio should stop
- [ ] Open Share Sheet - Audio should continue (intended)
- [ ] Open Comments - Audio should continue (intended)
- [ ] Return to HomeView - Audio should resume correctly

### Following Button Tests
- [ ] Follow button shows correct state
- [ ] Follow button responds to taps
- [ ] Follow state updates in real-time
- [ ] Follow state persists across app restarts
- [ ] Follow counters update correctly
- [ ] NetworkView shows correct follow relationships

## 📁 Files to Modify

### Audio Bleeding Fixes
- `lib/services/navigation_observer.dart`
- `lib/services/global_playback_manager.dart`
- `lib/providers/home_provider.dart`
- `lib/widgets/video_player_view_optimized.dart`

### Following Button Fixes
- `lib/services/unified_follow_service.dart` (new file)
- `lib/widgets/follow_button_widget.dart` (new file)
- `lib/widgets/streamer_card_view.dart` (update follow button)
- `lib/views/network_view.dart` (update follow button)

### Cleanup
- Remove `lib/services/follow_button_service.dart`
- Remove conflicting follow methods from `RealUserDataService`
- Update all follow button usages to use `UnifiedFollowService`
