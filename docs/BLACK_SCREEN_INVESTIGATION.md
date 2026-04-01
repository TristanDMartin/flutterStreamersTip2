# Black Screen Investigation - Why Some Videos Still Show Black

## Problem
User reports: **"why are some videos still showing black screens"**

## Evidence from Logs

### 1. BAD_INDEX Errors Still Occurring ⚠️
```
D/Codec2Client(29473): setOutputSurface -- failed to set consumer usage (6/BAD_INDEX)
```
- Lines 109, 122, 511, 688, 714, 741, 768
- Multiple surface recreation events
- Surface generation changing rapidly: 30180390 → 30180391 → 30180392 → 30180393 → 30180394 → 30180395 → 30180396

### 2. Rapid ExoPlayer Release/Creation ⚠️
```
I/ExoPlayerImpl(29473): Release cf733ba
I/ExoPlayerImpl(29473): Release 2da47cc
I/ExoPlayerImpl(29473): Release 3a7857a
I/ExoPlayerImpl(29473): Release 3b6b039
```
- Controllers being created and disposed rapidly
- Suggests controllers aren't being reused from pool

### 3. Surface Disconnection/Reconnection Churn ⚠️
```
D/SurfaceUtils(29473): disconnecting from surface ... reason connectToSurface(reconnect)
D/SurfaceUtils(29473): connecting to surface ... reason connectToSurface(reconnect-with-listener)
```
- Happening multiple times per video
- Indicates VideoPlayer widget is being recreated too often

## Root Causes

### Issue 1: Preloading is Async but Video Becomes Current Immediately ⚠️ **PRIMARY**

**Location:** `lib/services/global_playback_manager.dart:1619-1625`

**Problem:**
```dart
ensureControllerReady(n, video).catchError((e, stackTrace) {
  // Fire-and-forget - no await
});
```

- `preloadAround()` is **void** (not async)
- `ensureControllerReady()` is async and takes 500ms-8 seconds
- Preload starts, but video becomes current BEFORE controller is ready
- Result: `controller == null` → **BLACK SCREEN**

**Flow:**
```
User swipes → _onPageChanged(index) → preloadAround(index) [async, fire-and-forget]
                                      → Video widget renders → controller == null → BLACK SCREEN
                                      → [500ms-8s later] → Controller ready (too late)
```

### Issue 2: Controller Pool Not Being Used Correctly ⚠️

**Location:** `lib/widgets/video_player_view_optimized.dart:389-408`

**Problem:**
- `_tryAdoptFromPool()` only runs in `initState()` 
- If preload hasn't completed, pool is empty
- Widget falls back to `_initializeVideo()` (slow, async)
- During initialization: `controller == null` → **BLACK SCREEN**

### Issue 3: Preload Window Increased But Not Waited For ⚠️

**Location:** `lib/services/global_playback_manager.dart:1593-1596`

**Problem:**
- We increased preload window to 4 videos
- But we're not waiting for preloads to complete
- Videos can become current while their controllers are still initializing
- Result: Black screen until initialization completes

### Issue 4: BAD_INDEX Errors Cause Surface Recreation ⚠️

**Location:** Native layer (ExoPlayer/MediaCodec)

**Problem:**
- BAD_INDEX errors trigger surface recreation
- Surface recreation causes VideoPlayer widget remount
- During remount: controller might be null → **BLACK SCREEN**

## Solutions

### Solution 1: Make preloadAround Wait for Current Video (Critical) ✅

**Change:**
```dart
Future<void> preloadAround(int index, List<HomeVideo> videos) async {
  // ... validation ...
  
  for (final n in preloadIndices) {
    if (n == index) {
      // Current video - MUST be ready before returning
      await ensureControllerReady(n, video).timeout(
        Duration(seconds: 3),
        onTimeout: () {
          log('⚠️ Preload timeout for current video, continuing anyway');
        },
      );
    } else {
      // Next videos - fire-and-forget
      ensureControllerReady(n, video).catchError(...);
    }
  }
}
```

**Impact:**
- Current video is guaranteed to be ready (or timeout after 3s)
- Next videos still preload in background
- Eliminates black screen for current video

### Solution 2: Block Video Widget Rendering Until Controller Ready (Alternative)

**Change:**
- Don't render VideoPlayerViewOptimized until controller exists in pool
- Show placeholder/previous video while waiting
- Complex - would require PageView changes

### Solution 3: Reduce Initialization Time (Optimization)

**Location:** `lib/services/global_playback_manager.dart:1502-1509`

**Problem:** 8 second timeout is too long for instant playback

**Change:**
- Reduce timeout to 3 seconds
- Faster failure detection
- Videos that take longer fail fast, skip to next

### Solution 4: Fix BAD_INDEX Errors (Task #6 - Already Started)

**Status:** Phase 1 & 2.1 complete, but errors still occurring
**Next:** Complete Phase 2.3 (disposal guards) to prevent surface recreation

## Recommended Fix Priority

1. **🔥 CRITICAL: Make preloadAround wait for current video**
   - Change to `Future<void>` 
   - `await ensureControllerReady()` for current video only
   - This will eliminate black screens for videos that become current

2. **HIGH: Reduce initialization timeout**
   - 8s → 3s for faster failure
   - Skip slow videos faster

3. **MEDIUM: Complete Phase 2.3 (disposal guards)**
   - Prevent premature disposal
   - Reduce BAD_INDEX errors
   - Reduce surface recreation

## Testing

After fix:
1. **First video**: Should start playing immediately (preloaded + waited)
2. **Swipe to next**: Should play instantly (preloaded + waited before becoming current)
3. **Rapid swiping**: Should have minimal/no black screens
4. **Slow videos**: Should timeout after 3s, skip to next

