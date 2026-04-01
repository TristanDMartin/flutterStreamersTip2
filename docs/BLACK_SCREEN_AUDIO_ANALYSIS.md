# Black Screen with Audio Playing - Root Cause Analysis

## Problem Statement

**Symptom:** User hears audio but sees black screen (no frames rendered)  
**Example:** videoId includes timestamp "1767552216174", audio plays, texture is black  
**Location:** `lib/widgets/video_player_view_optimized.dart:3226-3300`

## Current Implementation Analysis

### Current VideoPlayer Key (Line 3290-3291)
```dart
key: ValueKey('vp:${widget.video.id}:c${controller.hashCode}:v${_controllerVersion}:g${_playbackGeneration}:t${_textureRebuildTick}')
```

**Analysis:**
- ✅ Includes `controller.hashCode` - good
- ✅ Includes `_controllerVersion` - good
- ✅ Includes `_textureRebuildTick` - good
- ⚠️ **ISSUE**: Key includes many components, but the critical one (`controller.hashCode`) is embedded in a string
- ⚠️ **POTENTIAL ISSUE**: If controller instance changes but hashCode is same (unlikely but possible), widget might not remount

### Current Watchdog (Lines 869-873, 905-940)
```dart
void _startFirstFrameWatchdog() {
  _firstFrameWatchdog?.cancel();
  _firstFrameWatchdog = Timer(const Duration(milliseconds: 600), _handleFirstFrameTimeout);
}

void _handleFirstFrameTimeout() {
  // Checks if playing and position advancing but no first frame
  // Calls _forceRemountTexture() if detected
}
```

**Analysis:**
- ✅ Timer exists (600ms)
- ⚠️ **ISSUE**: Only checks `position > Duration.zero` as frame indicator - not deterministic
- ⚠️ **ISSUE**: No structured recovery tiering
- ⚠️ **ISSUE**: No attempt counting per videoId
- ⚠️ **ISSUE**: No analytics-style logging

### Current First Frame Detection (Lines 2130-2150)
```dart
void _videoStateListener() {
  // Detects first frame when:
  // - value.size.width > 0 OR
  // - value.position > Duration.zero
  if (value.isPlaying && !_hasSeenFirstFrame && widget.isCurrentVideo) {
    if (value.size.width > 0 || value.position > Duration.zero) {
      _hasSeenFirstFrame = true;
      _firstFrameWatchdog?.cancel();
    }
  }
}
```

**Analysis:**
- ⚠️ **ISSUE**: Using `position > Duration.zero` as frame indicator is unreliable
  - Audio can advance position without video frames
  - Position advancement doesn't guarantee frames rendered
- ✅ Uses `size.width > 0` - good indicator but may come late
- ⚠️ **ISSUE**: No explicit "frame rendered" callback from plugin

## Root Cause Hypotheses

### Hypothesis 1: Controller↔Widget Identity Mismatch (HIGH CONFIDENCE)
**Evidence:**
- MediaCodec "setOutputSurface BAD_INDEX" errors suggest surface reattachment issues
- Current key includes controller.hashCode but embedded in string
- If VideoPlayer widget State persists across controller changes, texture linkage may break

**Scenario:**
1. ControllerA created → VideoPlayer widget mounted with key containing ControllerA.hashCode
2. User swipes → ControllerB created
3. Widget key changes, but Flutter might reuse State if structure similar
4. Texture/surface still linked to ControllerA's surface
5. ControllerB audio plays, but frames render to ControllerA's (disposed) surface
6. Result: Audio plays, black screen

### Hypothesis 2: Surface Not Reattached on Controller Change (MEDIUM CONFIDENCE)
**Evidence:**
- "setOutputSurface failed... BAD_INDEX" logs
- Texture rebuild tick exists but may not trigger full surface reattachment
- ExoPlayer/MediaCodec requires explicit surface reattachment

**Scenario:**
1. Controller initialized with surface A
2. Controller instance changes but surface not explicitly reattached
3. Decoder continues using old surface (disposed)
4. New controller audio plays, but frames go to old surface
5. Result: Audio plays, black screen

### Hypothesis 3: Decoder Stalls But Audio Continues (LOW CONFIDENCE)
**Evidence:**
- Position advancing suggests decoder is working
- Size.width > 0 suggests decoder has frame dimensions
- But frames not appearing suggests rendering pipeline issue, not decoder

**More likely:** Surface/texture issue, not decoder

## What Needs to Be Fixed

### 1. Deterministic First Frame Detection
**Current:** Uses `position > Duration.zero` (unreliable)  
**Needed:** More reliable indicator or explicit callback

**Options:**
- Use `size.width > 0 && size.height > 0` as primary indicator (more reliable)
- Add position advancement check as secondary (but don't rely on it alone)
- Add timestamp tracking: when size becomes non-zero

### 2. Robust Widget Keying
**Current:** Key includes controller.hashCode but embedded in string  
**Needed:** Ensure widget remounts when controller instance changes

**Fix:**
- Key should explicitly include controller instance identity
- Consider: `ValueKey('${widget.video.id}_${controller.hashCode}')`
- Simpler key = more predictable remounting behavior

### 3. Structured Recovery Tiering
**Current:** Only texture remount (Tier 2)  
**Needed:** Tiered approach with attempt tracking

**Tiers:**
- Tier 1: Force widget rebuild (change key)
- Tier 2: Force texture remount (current implementation)
- Tier 3: Recreate controller (expensive, last resort)

### 4. Watchdog Improvements
**Current:** 600ms timeout, basic check  
**Needed:**
- Structured state (attempts per videoId, timestamps)
- Thresholds based on context (cold start vs warm)
- Analytics-style logging
- Proper cancellation conditions

### 5. Controller Instance Tracking
**Current:** `_currentControllerInstance` exists but may not be used effectively  
**Needed:** Ensure VideoPlayer key changes when controller instance changes

