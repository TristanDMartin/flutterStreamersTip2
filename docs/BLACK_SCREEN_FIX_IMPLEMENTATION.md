# Black Screen with Audio Playing - Production-Grade Fix Implementation

## Summary

Production-grade fix for "black screen with audio playing" issue. Implements deterministic first frame detection, tiered recovery strategy, improved watchdog, and comprehensive logging.

## Root Cause Analysis

### Primary Hypothesis: Controller↔Widget Identity Mismatch
**Evidence:**
- MediaCodec "setOutputSurface BAD_INDEX" errors suggest surface reattachment issues
- Current key includes controller.hashCode but embedded in complex string
- VideoPlayer widget State may persist across controller changes, breaking texture linkage

**Scenario:**
1. ControllerA created → VideoPlayer widget mounted with key containing ControllerA.hashCode
2. User swipes → ControllerB created
3. Widget key changes, but Flutter might reuse State if structure similar
4. Texture/surface still linked to ControllerA's surface (disposed)
5. ControllerB audio plays, but frames render to ControllerA's (disposed) surface
6. Result: Audio plays, black screen

### Secondary Issues
- First frame detection uses unreliable `position > Duration.zero` indicator
- No structured recovery tiering (only texture remount)
- Watchdog lacks attempt tracking and analytics logging

## Fixes Implemented

### 1. ✅ Improved VideoPlayer Widget Key (Line 3307-3308)

**Before:**
```dart
key: ValueKey('vp:${widget.video.id}:c${controller.hashCode}:v${_controllerVersion}:g${_playbackGeneration}:t${_textureRebuildTick}'),
```

**After:**
```dart
// 🔥 PRODUCTION-GRADE: Simplified key ensures widget remount on controller change
// Key must change when controller instance changes to force texture/surface reattachment
// Using simple format: videoId_controllerHashCode ensures predictable remounting
key: ValueKey('${widget.video.id}_${controller.hashCode}'),
```

**Why:**
- Simpler key format = more predictable remounting behavior
- Ensures VideoPlayer widget State is recreated when controller instance changes
- Forces texture/surface reattachment on controller swap

### 2. ✅ Deterministic First Frame Detection (Lines 2240-2265)

**Before:**
```dart
if (value.size.width > 0 || value.position > Duration.zero) {
  _hasSeenFirstFrame = true;
}
```

**After:**
```dart
// 🔥 PRODUCTION-GRADE: Deterministic first frame detection
// Use size.width > 0 && size.height > 0 as primary indicator (more reliable than position)
// Position can advance with audio-only, but size indicates decoder has frame dimensions
final hasValidSize = value.size.width > 0 && value.size.height > 0;
// Secondary indicator: Position advancing (but less reliable - audio can advance without frames)
final positionAdvancing = value.position > Duration.zero;

if (hasValidSize) {
  _hasSeenFirstFrame = true;
  _firstFrameRenderedAt = DateTime.now();
  _firstFrameWatchdog?.cancel();
  _firstFrameWatchdog = null;
  
  // Log first frame rendered for analytics
  final timeToFirstFrame = _playbackStartTime != null 
      ? _firstFrameRenderedAt!.difference(_playbackStartTime!).inMilliseconds
      : null;
  log('✅ VideoPlayer: First frame rendered for ${widget.video.id} (controller: ${controller.hashCode}, size: ${value.size.width}x${value.size.height}${timeToFirstFrame != null ? ', timeToFirstFrame: ${timeToFirstFrame}ms' : ''})');
}
```

**Why:**
- `size.width > 0 && size.height > 0` is more reliable than `position > Duration.zero`
- Position can advance with audio-only, but size indicates decoder has frame dimensions
- Adds timestamp tracking for analytics

### 3. ✅ Improved Watchdog with Dynamic Thresholds (Lines 886-905)

**Before:**
```dart
void _startFirstFrameWatchdog() {
  _firstFrameWatchdog?.cancel();
  _firstFrameWatchdog = Timer(const Duration(milliseconds: 600), _handleFirstFrameTimeout);
}
```

**After:**
```dart
/// 🔥 PRODUCTION-GRADE: Start watchdog for first frame detection
/// 
/// **Purpose:**
/// Detects "black screen with audio" - audio is playing but video frames are not rendered.
/// 
/// **Threshold:**
/// - Cold start (first video): 1200ms (more time for decoder initialization)
/// - Warm start (subsequent videos): 800ms (faster detection)
/// 
/// **Cancellation:**
/// Watchdog is cancelled when:
/// - First frame is detected (_hasSeenFirstFrame becomes true)
/// - Video changes (controller changes)
/// - Widget disposed
/// - Tab switches (isCurrentVideo becomes false)
void _startFirstFrameWatchdog() {
  _firstFrameWatchdog?.cancel();
  
  // 🔥 PRODUCTION-GRADE: Dynamic threshold based on context
  // First video on home load (cold start) gets more time, subsequent videos get less
  final isColdStart = _playbackStartTime == null || _blackScreenRecoveryAttempts == 0;
  final threshold = isColdStart ? const Duration(milliseconds: 1200) : const Duration(milliseconds: 800);
  
  log('🔍 VideoPlayer: Starting first frame watchdog for ${widget.video.id} (controller: ${_videoPlayerController?.hashCode}, threshold: ${threshold.inMilliseconds}ms, coldStart: $isColdStart)');
  
  _firstFrameWatchdog = Timer(threshold, _handleFirstFrameTimeout);
}
```

**Why:**
- Dynamic thresholds: cold start (1200ms) vs warm start (800ms)
- Better detection timing based on context
- Comprehensive logging

### 4. ✅ Tiered Recovery Strategy (Lines 922-1108)

**Three-Tier Recovery:**

**Tier 1 (Attempt 1):** Force widget rebuild by changing key
- Increments `_textureRebuildTick` to force VideoPlayer remount
- Seeks to current position to kick decoder
- Cheap, immediate recovery

**Tier 2 (Attempt 2):** Force texture remount + pause/resume
- Increments `_textureRebuildTick`
- Pauses and resumes playback to force decoder reinitialization
- Medium cost recovery

**Tier 3 (Attempt 3+):** Recreate controller
- Fully disposes and recreates controller
- Expensive, last resort
- Guards: max 2 attempts per session, cooldown (1500ms)

**Implementation:**
- `_handleFirstFrameTimeout()`: Detects black screen and routes to appropriate tier
- `_recoverBlackScreenTier1()`: Tier 1 recovery
- `_recoverBlackScreenTier2()`: Tier 2 recovery
- `_recoverBlackScreenTier3()`: Tier 3 recovery

### 5. ✅ Comprehensive Logging

**Analytics-Style Logs:**
- `BLACKSCREEN_DETECTED`: When black screen is detected (with controller hash, position, size, time since start)
- `RECOVERY_ATTEMPT_1_REBUILD_WIDGET`: Tier 1 recovery triggered
- `RECOVERY_ATTEMPT_2_REMOUNT_TEXTURE`: Tier 2 recovery triggered
- `RECOVERY_ATTEMPT_3_RECREATE_CONTROLLER`: Tier 3 recovery triggered
- `RECOVERY_GIVE_UP`: Max attempts reached
- `First frame rendered`: When first frame is detected (with timeToFirstFrame)

### 6. ✅ State Management

**New Fields:**
- `_firstFrameRenderedAt`: Timestamp when first frame rendered
- `_blackScreenRecoveryAttempts`: Recovery attempts per video session
- `_lastBlackScreenRecoveryAt`: Timestamp of last recovery attempt
- `_recoveryAttemptsPerVideo`: Static map tracking attempts per videoId across sessions
- `_blackScreenRecoveryCooldown`: Cooldown between recovery attempts (1500ms)
- `_maxRecoveryAttempts`: Max recovery attempts per video session (2)

**State Reset:**
- Reset on controller change (`_adoptController`)
- Reset on widget dispose
- Reset on video change

## Testing Plan

### Manual Regression Tests

1. **Cold Start + Autoplay**
   - Start app from cold state
   - Verify first video autoplays
   - Verify no black screen
   - Check logs for first frame detection

2. **Rapid Swipe**
   - Swipe through 20+ videos rapidly
   - Verify no black screens
   - Verify no "used after disposed" errors
   - Check logs for recovery attempts (should be minimal)

3. **Background/Foreground**
   - Start video playback
   - Background app mid-play
   - Foreground app
   - Verify playback resumes correctly
   - Verify no black screen

4. **Known Problematic Videos**
   - Test with videoId "1767552216174" (reported problematic)
   - Verify recovery attempts trigger if needed
   - Verify no infinite recovery loops

5. **Low Bandwidth**
   - Simulate slow network
   - Verify watchdog triggers appropriately
   - Verify recovery attempts work
   - Verify no false positives

6. **Device-Specific**
   - Test on devices with known MediaCodec quirks
   - Verify recovery strategies work across devices

## Expected Outcomes

1. **Black Screen Elimination**
   - Videos should render frames as soon as audio plays
   - No black screens with audio playing

2. **Recovery Success Rate**
   - Tier 1 recovery should resolve most cases
   - Tier 2 recovery for edge cases
   - Tier 3 recovery only as last resort

3. **Performance**
   - No performance regressions
   - Recovery attempts should be minimal (< 5% of videos)
   - No infinite recovery loops

4. **Logging**
   - Comprehensive analytics logs for debugging
   - Clear indication of recovery paths taken
   - Time-to-first-frame metrics

## Files Modified

- `lib/widgets/video_player_view_optimized.dart`:
  - Lines 147-157: New state fields for recovery tracking
  - Lines 322-331: State reset in `_adoptController`
  - Lines 436-442: State reset in `_markControllerDisposed`
  - Lines 886-905: Improved `_startFirstFrameWatchdog`
  - Lines 922-1108: New `_handleFirstFrameTimeout` with tiered recovery
  - Lines 2240-2265: Deterministic first frame detection
  - Lines 3307-3308: Simplified VideoPlayer key

## Next Steps

1. Test manually using regression test plan
2. Monitor logs for recovery patterns
3. Analyze time-to-first-frame metrics
4. Adjust thresholds if needed based on real-world data
5. Consider server-side analytics for recovery patterns

