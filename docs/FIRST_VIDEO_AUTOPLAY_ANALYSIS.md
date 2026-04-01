# First Video Auto-Play Root Cause Analysis

## Problem Statement

**Symptom:** First video on HomeView does not autoplay reliably on initial load  
**Location:** `lib/pages/home_view.dart:513-540`  
**Impact:** Poor UX - users expect TikTok-style instant playback

## Current Flow (Broken)

### HomeView Timeline:
1. `initState()` → `addPostFrameCallback` → `_loadVideos()` (async)
2. `_loadVideos()` completes → `_applyAlgorithmRanking()` (async)
3. `_applyAlgorithmRanking()` completes → `_scheduleFocusFirstVideo()`
4. `_scheduleFocusFirstVideo()` → 500ms Timer → `_ensureFirstVideoFocus()`
5. `_ensureFirstVideoFocus()` → `GlobalPlaybackManager.requestFocus(firstVideo.id, ownerId)`

### VideoPlayerViewOptimized Timeline:
1. First video widget built → `initState()`
2. `initState()` → `_tryAdoptFromPool()` (usually null for first video)
3. `_initializeVideo()` (async) starts:
   - Health gate resolution
   - Controller creation (`VideoPlayerController.networkUrl`)
   - `await controller.initialize()` (5-10 seconds on slow network)
   - `registerController(videoId, controller, owner: owner)`
   - `_attemptRequestFocus()` if `isCurrentVideo == true`

### GlobalPlaybackManager.requestFocus():
```dart
Future<void> requestFocus(String videoId, String owner) async {
  final controller = _controllerPool[videoId];
  if (controller == null || !_isControllerSafe(videoId, controller)) {
    log('⚠️ PlaybackManager: Controller not found or unsafe for $videoId');
    // Returns early - no queueing!
    return;
  }
  // ... activate ...
}
```

## Root Cause

### Issue 1: Timing Race Condition
**HomeView calls `requestFocus()` after 500ms delay, but controller initialization takes 5-10+ seconds:**
- Slow network: Controller initialization can take 10+ seconds
- Slow device: Decoder initialization adds delay
- First frame: Additional time for first frame to render
- Result: `requestFocus()` called when `controller == null` → silently fails

### Issue 2: No Queueing/Pending System
**GlobalPlaybackManager.requestFocus() returns immediately if controller doesn't exist:**
- No mechanism to "remember" that focus was requested
- No callback/notification when controller becomes ready
- Result: Focus request is lost, video never autoplays

### Issue 3: Fragile Delay-Based Coordination
**500ms delay is unreliable:**
- Too short: Controller not ready (fails silently)
- Too long: Unnecessary delay even when controller is ready early
- Doesn't account for network speed, device performance, or controller state
- Result: Unreliable autoplay

### Issue 4: Double Request Attempts
**Both HomeView and VideoPlayerViewOptimized try to request focus:**
- HomeView: Calls `requestFocus()` after 500ms (might fail if controller not ready)
- VideoPlayerViewOptimized: Calls `_attemptRequestFocus()` when controller registered (only if `isCurrentVideo`)
- Result: Race condition, potential double requests, or missed requests

## Evidence from Code

### home_view.dart:427-441
```dart
void _scheduleFocusFirstVideo() {
  _focusTimer?.cancel();
  _focusTimer = Timer(const Duration(milliseconds: 500), () {
    // ... route checks ...
    _ensureFirstVideoFocus(); // Calls requestFocus() - controller might not exist!
  });
}
```

### home_view.dart:513-538
```dart
void _ensureFirstVideoFocus() {
  // ...
  GlobalPlaybackManager.instance.requestFocus(firstVideo.id, ownerId);
  // No check if controller exists - just calls and hopes it works
}
```

### global_playback_manager.dart:527-561
```dart
Future<void> requestFocus(String videoId, String owner) async {
  final controller = _controllerPool[videoId];
  if (controller == null || !_isControllerSafe(videoId, controller)) {
    log('⚠️ PlaybackManager: Controller not found or unsafe for $videoId');
    // Returns early - focus request is LOST
    return;
  }
  // ... only executes if controller exists ...
}
```

### video_player_view_optimized.dart:1650-1690
```dart
GlobalPlaybackManager.instance.registerController(videoId, controller, owner: owner);
// ... later ...
if (widget.isCurrentVideo && mounted && !_isDisposed) {
  _attemptRequestFocus('_initializeVideo: controller ready');
  // Only requests if isCurrentVideo is true - but HomeView might have already tried
}
```

## Single Source of Truth Analysis

**Current State:**
- **HomeView**: Thinks it controls first video focus (via timer)
- **VideoPlayerViewOptimized**: Thinks it controls focus when controller ready
- **GlobalPlaybackManager**: Just executes requests, doesn't coordinate

**Problem:** No single source of truth for "first video should autoplay"

**Solution:** GlobalPlaybackManager should be the single source of truth:
- HomeView: Sets "desired focus" immediately (no delay)
- GlobalPlaybackManager: Queues desired focus, applies when controller ready
- VideoPlayerViewOptimized: Just registers controller, PlaybackManager handles focus

## Readiness Definition

**Controller is "ready to autoplay" when:**
1. ✅ Controller exists in pool (`_controllerPool[videoId] != null`)
2. ✅ Controller is safe (`_isControllerSafe(videoId, controller)`)
3. ✅ Controller is initialized (`controller.value.isInitialized == true`)
4. ✅ Widget is mounted and visible (`isCurrentVideo == true`)
5. ✅ Playback not blocked (`isPlaybackBlocked == false`)
6. ✅ Owner can play (`canPlay(owner) == true`)

**Must NOT autoplay if:**
- ❌ User switched tabs (different `activeOwner`)
- ❌ User scrolled away (`isCurrentVideo == false`)
- ❌ HomeView disposed (`mounted == false`)
- ❌ Different video is now current (`activeVideoId != videoId`)
- ❌ Playback blocked (modals, backgrounding, etc.)

