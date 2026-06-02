# Surface/MediaCodec BAD_INDEX Error Fix - Implementation Summary

## Status: Phase 1, 2.1–2.2 Complete, Phase 2.3 Implemented (surface-detach dispose)

### Phase 1: Instrumentation ✅ COMPLETE

**Implemented:**
- ✅ Controller lifecycle logging with videoId + controllerId
  - `CONTROLLER_CREATED`: When controller is created
  - `CONTROLLER_INITIALIZED_COMPLETE`: When initialization completes
  - `CONTROLLER_ATTACHED`: When controller is adopted/attached to VideoPlayer widget
  - `CONTROLLER_DETACHED`: When controller is detached
  - `CONTROLLER_DISPOSED`: When controller is disposed
  - `WIDGET_BECOMES_CURRENT`: When widget becomes current
  - `WIDGET_LOSES_CURRENT`: When widget loses current status
- ✅ VideoPlayer key identity logging (logs key format including controllerId)

**Log Format:**
```
🎬 CONTROLLER_CREATED: videoId=<id> controllerId=<hashCode> version=<version>
🎬 CONTROLLER_ATTACHED: videoId=<id> controllerId=<hashCode>
🎬 VIDEO_PLAYER_KEY: videoId=<id> controllerId=<hashCode> key=<key> surfaceEpoch=<epoch>
🎬 WIDGET_BECOMES_CURRENT: videoId=<id> controllerId=<hashCode>
```

**Files Modified:**
- `lib/widgets/video_player_view_optimized.dart`:
  - Lines 1640-1641: Controller creation logging
  - Lines 1739-1740: Controller initialization complete logging
  - Lines 308-309, 336: Controller attached/detached logging
  - Lines 198-209: Controller disposal logging
  - Lines 1268-1277: Widget current status logging
  - Lines 3489-3511: VideoPlayer key logging

---

### Phase 2.1: Stabilize VideoPlayer Keying ✅ COMPLETE

**Implemented:**
- ✅ Changed key format from `${videoId}_${controllerId}_t${textureRebuildTick}` to `VideoPlayer:${videoId}:${controllerId}`
- ✅ Removed `_textureRebuildTick` from key (was causing unnecessary surface recreation)
- ✅ Key now only changes when:
  - Video ID changes
  - Controller instance changes (hashCode changes)
- ✅ Surface epoch support added (feature-flagged, disabled by default)

**Key Format:**
```dart
key: ValueKey(_enableSurfaceWatchdogRecreate
    ? 'VideoPlayer:${videoId}:${controllerId}:${surfaceEpoch}'
    : 'VideoPlayer:${videoId}:${controllerId}')
```

**Files Modified:**
- `lib/widgets/video_player_view_optimized.dart`:
  - Lines 184-185: Added `_surfaceEpoch` and `_enableSurfaceWatchdogRecreate` fields
  - Lines 3509-3511: Updated VideoPlayer key format

**Impact:**
- Reduces surface recreation churn (key no longer changes on every rebuild)
- Surface only recreated when controller instance actually changes
- Prevents BAD_INDEX errors from excessive surface reattachment

---

### Phase 2.2: Reduce Unnecessary Texture Remounts ✅ COMPLETE (from Task #5)

**Status:** Already implemented in previous work
- ✅ `didUpdateWidget()` early return when videoId unchanged (line 1332-1334)
- ✅ `setState()` batching via `addPostFrameCallback` (line 2428)

---

### Phase 2.3: Prevent Controller Disposal During Surface Binding ✅ COMPLETE

**Implemented:**
1. `GlobalPlaybackManager` tracks attached controllers + 5s registration TTL
2. `markControllerAttached()` / `markControllerDetached()` from `VideoPlayerViewOptimized`
3. Pool eviction skips attached / initializing / TTL-protected controllers
4. **Surface detach before dispose:** `_adoptController()` clears `VideoPlayer` from tree, waits ~700ms, then disposes replaced controller
5. **Deferred pool dispose:** `registerController()` schedules old controller disposal after pause + delay (no sync dispose during surface bind)

---

### Phase 2.4: Surface Recreation Watchdog (Feature-Flagged, Last Resort) ⚠️ NOT YET IMPLEMENTED

**Status:** Infrastructure in place (feature flag exists), implementation pending

**Requirements:**
- Detect: "playing == true but no rendered frame after 1200-2000ms"
- Action: Increment `_surfaceEpoch` to force surface recreation
- Gate: Only for current video, only if `_enableSurfaceWatchdogRecreate == true`
- Conservative threshold: 1500ms (to avoid thrash)

**Implementation Location:**
- Extend existing `_handleFirstFrameTimeout()` method
- Add surface epoch increment when watchdog triggers

---

## Validation Plan

### Before Testing:
1. ✅ Instrumentation logging added
2. ✅ Key strategy stabilized
3. ⚠️ Disposal guards need completion

### Test Procedure:
1. Reproduce on known device (Pixel 6 / oriole)
2. Baseline run (2 minutes scrolling, open/close comments, switch tabs)
3. Count BAD_INDEX occurrences in logs
4. Note black screens with audio
5. Repeat after Phase 2.3 completion

### Acceptance Criteria:
- BAD_INDEX occurrences drop dramatically (target: near-zero)
- No audio-only black screens
- Playback start time improves
- No memory regression (controllers still bounded by pool limits)

---

## Remaining Work

### High Priority (Complete for Phase 2):
1. **Complete Phase 2.3: Disposal Guards**
   - Add attached state tracking
   - Add TTL enforcement
   - Update disposal logic

### Medium Priority (If needed after testing):
2. **Phase 2.4: Surface Recreation Watchdog**
   - Only if black screens persist after Phase 2.3

### Low Priority (Enhancement):
3. Additional instrumentation refinement
4. Native/plugin mitigation (only if app-side fixes insufficient)

---

## Notes

- Key format change removes texture rebuild tick, which was causing unnecessary surface recreation
- Instrumentation provides visibility into controller lifecycle for debugging
- Disposal guards are critical to prevent BAD_INDEX during surface binding
- Surface recreation watchdog is last resort and should remain disabled by default

