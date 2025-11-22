# Audio Bleeding Deep Dive Analysis

## Problem Statement
Audio from HomeView videos continues playing when navigating to NetworkView, despite blocking mechanisms.

## Root Cause Analysis

### 1. **VideoPlayerViewOptimized Auto-Play on Initialization**
**Location**: `lib/widgets/video_player_view_optimized.dart:1006-1013`

**Issue**: When a video initializes and `isCurrentVideo == true`, it immediately calls:
```dart
playbackManager.activate(widget.video.id, owner: widget.tabId);
```

**Problem**: This happens even if playback is blocked. While `activate()` checks `_blockLevel > 0` and mutes, the video might have already started playing before the block check.

**Fix Needed**: Check block state BEFORE calling `activate()`.

---

### 2. **didUpdateWidget Requesting Focus**
**Location**: `lib/widgets/video_player_view_optimized.dart:912-920`

**Issue**: When `isCurrentVideo` is true, it requests focus:
```dart
if (widget.isCurrentVideo) {
  playbackManager.requestFocus(widget.video.id, widget.tabId);
}
```

**Problem**: `requestFocus()` calls `activate()` if the controller is safe, which might play the video even if blocked.

**Fix Needed**: Check block state before requesting focus.

---

### 3. **_handleVideoEnter() Resuming Playback**
**Location**: `lib/widgets/video_player_view_optimized.dart:556-667`

**Issue**: When a video becomes current, `_handleVideoEnter()` is called, which:
- Checks resume position
- Calls `_safeSetVolume(1.0)` 
- Might resume playback

**Problem**: This bypasses the block check and might unmute/play videos.

**Fix Needed**: Check block state before handling video enter.

---

### 4. **NavigationObserver Timing**
**Location**: `lib/services/navigation_observer.dart:102-113`

**Issue**: NavigationObserver blocks for non-home routes, but:
- NetworkView might not be detected as a non-home route
- There's a race condition where videos play before the block is applied
- The route detection logic might miss NetworkView

**Problem**: If NetworkView isn't detected correctly, videos won't be blocked.

**Fix Needed**: Ensure NetworkView is properly detected, or rely on NetworkView's own blocking.

---

### 5. **HomeView Timers Resuming Playback**
**Location**: `lib/pages/home_view.dart:132-145`

**Issue**: There's a `_resumeTimer` that calls `resumeCurrentVideo()` after 300ms.

**Problem**: If this timer fires after navigating to NetworkView, it might resume playback.

**Fix Needed**: Cancel timer when navigating away, or check if we're still on HomeView.

---

### 6. **Race Condition: Block vs Play**
**Timeline Issue**:
1. User navigates to NetworkView
2. HomeView calls `onLeaveHomeView()` → blocks + pauses
3. NetworkView `initState()` → blocks + pauses
4. BUT: VideoPlayerViewOptimized widgets might rebuild and call `activate()`/`requestFocus()` before the block is fully applied
5. Result: Video plays briefly before being muted

**Fix Needed**: Ensure blocking happens synchronously and is checked before any play operations.

---

### 7. **Controller Volume Restoration**
**Location**: `lib/widgets/video_player_view_optimized.dart:494-509`

**Issue**: In `_safePlay()`, if `_audioUnmuted` is true, it checks volume and restores to 1.0:
```dart
if (value.volume == 0.0) {
  await controller.setVolume(1.0);
}
```

**Problem**: This might unmute videos even when blocked.

**Fix Needed**: Check block state before restoring volume.

---

## Critical Fixes Required

### Fix 1: Check Block State Before activate() in VideoPlayerViewOptimized
**Priority**: CRITICAL
**Location**: `lib/widgets/video_player_view_optimized.dart:1006-1013`

**Change**: Check if playback is blocked before calling `activate()`.

---

### Fix 2: Check Block State Before requestFocus() in didUpdateWidget
**Priority**: CRITICAL
**Location**: `lib/widgets/video_player_view_optimized.dart:912-920`

**Change**: Check if playback is blocked before requesting focus.

---

### Fix 3: Check Block State in _handleVideoEnter()
**Priority**: HIGH
**Location**: `lib/widgets/video_player_view_optimized.dart:556`

**Change**: Check if playback is blocked before handling video enter.

---

### Fix 4: Cancel HomeView Timers on Navigation
**Priority**: HIGH
**Location**: `lib/pages/home_view.dart:132-145`

**Change**: Cancel `_resumeTimer` when navigating away.

---

### Fix 5: Check Block State Before Volume Restoration
**Priority**: MEDIUM
**Location**: `lib/widgets/video_player_view_optimized.dart:494-509`

**Change**: Check block state before restoring volume to 1.0.

---

### Fix 6: Ensure NetworkView Route Detection
**Priority**: MEDIUM
**Location**: `lib/services/navigation_observer.dart:96-100`

**Change**: Ensure NetworkView is properly detected as a non-home route.

---

## Testing Checklist

- [ ] Navigate HomeView → NetworkView: No audio bleeding
- [ ] Navigate NetworkView → HomeView: Videos resume correctly
- [ ] Rapid navigation: No audio bleeding during fast transitions
- [ ] Background/foreground: No audio bleeding on app lifecycle changes
- [ ] Multiple videos in feed: Only one plays at a time
- [ ] Block/unblock: Videos respect block state immediately

---

## ✅ FIXES IMPLEMENTED

### Fix 1: ✅ Check Block State Before activate() in Initialization
**Status**: IMPLEMENTED
**Location**: `lib/widgets/video_player_view_optimized.dart:1006-1013`
- Added `isPlaybackBlocked` check before calling `activate()`
- Returns early and mutes video if blocked

### Fix 2: ✅ Check Block State Before requestFocus() in didUpdateWidget
**Status**: IMPLEMENTED
**Location**: `lib/widgets/video_player_view_optimized.dart:912-920`
- Added `isPlaybackBlocked` check before requesting focus
- Returns early and mutes video if blocked

### Fix 3: ✅ Check Block State in _handleVideoEnter()
**Status**: IMPLEMENTED
**Location**: `lib/widgets/video_player_view_optimized.dart:556`
- Added `isPlaybackBlocked` check at start of `_handleVideoEnter()`
- Returns early and mutes video if blocked

### Fix 4: ✅ Cancel HomeView Timers on Navigation
**Status**: IMPLEMENTED
**Location**: `lib/pages/home_view.dart:606-616`
- Added timer cancellation in `_navigateToNetwork()`
- Prevents timers from resuming playback after navigation

### Fix 5: ✅ Check Block State Before Volume Restoration
**Status**: IMPLEMENTED
**Location**: `lib/widgets/video_player_view_optimized.dart:494-513`
- Added `isPlaybackBlocked` check before restoring volume to 1.0
- Returns false (prevents play) if blocked

### Fix 6: ✅ NetworkView Route Detection in NavigationObserver
**Status**: IMPLEMENTED
**Location**: `lib/services/navigation_observer.dart:96-113`
- Added explicit NetworkView detection
- Extra safety: calls `pauseAll()` when NetworkView is detected

### Fix 7: ✅ Check Block State in _togglePlayPause()
**Status**: IMPLEMENTED
**Location**: `lib/widgets/video_player_view_optimized.dart:1273-1283`
- Added `isPlaybackBlocked` check before unmuting/playing in user tap handler
- Prevents audio bleeding when user taps video while on NetworkView
- Returns early and mutes video if blocked

---

## Additional Safeguards

### 1. **NetworkView Synchronous Blocking**
**Location**: `lib/views/network_view.dart:67-80`
**Implementation**: Blocking happens immediately in `initState()` (not in postFrameCallback)
- **Why Critical**: Prevents any widget rebuilds from triggering video playback before block is applied
- **Execution Order**: 
  1. `block(reason: 'networkViewOpened')` - Increments blockLevel, prevents new videos
  2. `pauseAll()` - Aggressively mutes and pauses ALL existing videos
- **Result**: Zero audio bleeding window - videos are blocked before any widgets can respond

### 2. **Pre-Navigation Blocking**
**Location**: `lib/pages/home_view.dart:529-533`
**Implementation**: HomeView blocks before navigation to NetworkView
- **Why Critical**: Prevents race condition where videos might resume during route transition
- **Execution Order**:
  1. `block(reason: 'navigatingToNetworkView')` - Blocks before Navigator.push()
  2. `pauseAll()` - Ensures all videos are paused
  3. `Navigator.push()` - Then navigates (block is already active)
- **Result**: Block is active before NetworkView even starts building

### 3. **Nested Blocking**
**Location**: `lib/services/global_playback_manager.dart:418-429`
**Implementation**: Multiple blocks ensure playback stays blocked even if one is unblocked
- **How It Works**:
  - Each `block()` call increments `_blockLevel` (1, 2, 3, ...)
  - Each `unblock()` call decrements `_blockLevel`
  - Playback only resumes when `blockLevel == 0`
- **Example Scenario**:
  - HomeView blocks (level 1) → NetworkView blocks (level 2)
  - If HomeView unblocks (level 1), NetworkView still has control (level 2)
  - Only when NetworkView unblocks (level 0) does playback resume
- **Result**: Multiple layers of protection prevent accidental unblocking

### 4. **Controller Safety Checks**
**Implementation**: All controller operations check `isPlaybackBlocked` before playing/unmuting
- **Checked Locations**:
  1. `_initializeVideo()` - Before `activate()` (line 1038)
  2. `didUpdateWidget()` - Before `requestFocus()` (line 933)
  3. `_handleVideoEnter()` - Before handling enter (line 567)
  4. `_safePlay()` - Before volume restoration (line 503)
  5. `_togglePlayPause()` - Before unmuting/playing (line 1273)
- **Pattern**: Every play/unmute operation checks `GlobalPlaybackManager.instance.isPlaybackBlocked` first
- **Result**: Even if a video controller tries to play, it's immediately blocked and muted

### 5. **Timer Cancellation**
**Location**: `lib/pages/home_view.dart:611-613`
**Implementation**: HomeView timers are cancelled when navigating away
- **Why Critical**: Prevents delayed resume operations from firing after navigation
- **Cancelled Timers**:
  - `_resumeTimer` - Would call `resumeCurrentVideo()` after 300ms
  - `_focusTimer` - Would call `_ensureFirstVideoFocus()` after 500ms
- **Result**: No delayed operations can resume playback after leaving HomeView

### 6. **NavigationObserver Route Detection**
**Location**: `lib/services/navigation_observer.dart:96-113`
**Implementation**: Explicit NetworkView detection with extra safety
- **Detection Logic**: Checks route name and owner for NetworkView patterns
- **Extra Safety**: Calls `pauseAll()` when NetworkView is detected
- **Result**: Backup blocking mechanism if NetworkView's own blocking fails

---

## Implementation Priority

1. **IMMEDIATE**: Fix 1, 2 (Check block state before activate/requestFocus) ✅ DONE
2. **HIGH**: Fix 3, 4 (Handle video enter, cancel timers) ✅ DONE
3. **MEDIUM**: Fix 5, 6 (Volume restoration, route detection) ✅ DONE

