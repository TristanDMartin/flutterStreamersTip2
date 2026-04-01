# Video Initialization Delays - Production-Grade Fix

**Date:** 2026-01-05  
**Status:** Implementation Plan  
**Priority:** 🔴 CRITICAL

---

## Root Cause Summary

Based on code analysis and terminal logs, the root cause of video initialization delays is:

1. **Aggressive Cleanup During Initialization**: Controllers are being disposed while still in the `preloading` state, causing ExoPlayer create → prepare → dispose → recreate loops.

2. **No State Tracking**: Current implementation uses boolean flags (`_initializingControllers` Set) but lacks explicit lifecycle states, making it impossible to distinguish between "creating", "preloading", "ready", "coolingDown" states.

3. **Immediate Disposal Outside Radius**: `disposeFarControllers()` disposes controllers immediately when they're outside `poolRadius`, even if they're still initializing or recently became ready.

4. **No Cooldown Period**: There's no grace period for controllers that just left the preload window, causing immediate disposal on scroll.

5. **Race Conditions in Async Init**: When `ensureControllerReady()` completes asynchronously, there's no generation token to prevent stale completion callbacks from overwriting newer controller states.

6. **No Pin Set**: Controllers for current + next 2 videos aren't explicitly "pinned" to prevent disposal, relying only on distance checks.

**Evidence from Code:**
- Line 1593-1607: Cleanup deferred 500ms but still triggers during rapid scrolling
- Line 1677: Checks `!_initializingControllers.contains(videoId)` but this is a Set lookup, not state-based
- Line 1683: Checks `controller.value.isInitialized` but doesn't track if initialization just started
- No cooldown mechanism - controllers outside radius are disposed immediately

**Evidence from Logs:**
- Terminal logs show repeated ExoPlayer "Release" messages (lines 189, 214)
- Surface connection/disconnection churn (lines 195-241)
- Buffer pool destruction indicates rapid create/dispose cycles

---

## Implementation Plan

### Phase 1: State Model & Instrumentation
1. Create `ControllerEntry` class with explicit lifecycle states
2. Replace `Map<String, VideoPlayerController>` with `Map<String, ControllerEntry>`
3. Add comprehensive logging for all lifecycle events

### Phase 2: Pin Set & Guards
1. Implement pin set for current + next 2 videos
2. Add guards preventing disposal during initialization
3. Add generation tokens for async init

### Phase 3: Two-Stage Eviction
1. Implement cooldown mechanism (soft eviction)
2. Implement hard eviction after cooldown expires
3. Rate limit disposal (max 1 per cleanup cycle)

### Phase 4: Integration
1. Update `ensureControllerReady()` to use state model
2. Update `registerController()` to use state model
3. Update `disposeFarControllers()` with new eviction policy
4. Update `preloadAround()` with pin set

---

## Code Changes

See implementation below.

---

## Test Plan

### Acceptance Criteria

1. **Time-to-First-Frame:**
   - Cold start: First video first frame visible < 800ms
   - Warm start (after initial load): Next video first frame visible < 300ms
   - Rapid scroll: Videos play instantly (< 300ms) when preloaded

2. **ExoPlayer Churn:**
   - No repeated create/dispose loops for same videoId
   - Max 1 controller creation per videoId per scroll session
   - Logs show CREATE → PRELOAD → PREPARED → (ACQUIRE or DISPOSE) pattern

3. **Memory Stability:**
   - Pool size stays at ≤ maxControllerPoolSize (3)
   - No memory leaks (pool doesn't grow unbounded)
   - Controllers properly disposed after cooldown

4. **Background/Foreground:**
   - App backgrounding doesn't cause stuck states
   - Controllers recover properly on foreground
   - No "used after disposed" errors

### Test Scenarios

1. **Cold Start:**
   - Kill app completely
   - Launch app
   - First video should play automatically
   - Measure time from app launch to first frame

2. **Rapid Scroll:**
   - Scroll through 30+ videos quickly
   - Check logs for controller lifecycle events
   - Verify no duplicate controllers for same videoId
   - Verify pool size stays ≤ 3

3. **Scroll Back:**
   - Scroll forward 10 videos
   - Scroll back 5 videos
   - Verify controllers are reused (not recreated)
   - Verify cooldown cancels when scrolling back

4. **Background/Foreground:**
   - Play video
   - Background app
   - Wait 5 seconds
   - Foreground app
   - Verify video resumes or recovers gracefully

---

## Metrics to Monitor

- Controller creation/disposal frequency (should decrease significantly)
- Time-to-first-frame (should decrease and stabilize)
- Pool size (should stay ≤ 3)
- Cooldown cancellation rate (how often cooldown is cancelled by scroll back)
- Stale async completion rate (generation token mismatches)

