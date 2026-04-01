# Video Initialization Delays - Implementation Guide

**Date:** 2026-01-05  
**Status:** Implementation Ready  
**Priority:** 🔴 CRITICAL

This document provides the exact code changes needed to fix video initialization delays.

---

## Overview

This fix introduces:
1. **ControllerEntry state model** - Explicit lifecycle states
2. **Instrumentation** - Comprehensive logging
3. **Pin set** - Protect current + next 2 videos from disposal
4. **Two-stage eviction** - Cooldown period before disposal
5. **Generation tokens** - Prevent stale async completions
6. **Guards** - Prevent disposal during initialization

---

## Step 1: Add ControllerEntry State Model

✅ **DONE** - Created `lib/services/controller_entry.dart`

---

## Step 2: Update State Management Section

**File:** `lib/services/global_playback_manager.dart`  
**Location:** Lines 39-95

### Change 2.1: Replace _controllerPool Type

**BEFORE:**
```dart
/// Pool of video controllers keyed by video ID
final Map<String, VideoPlayerController> _controllerPool = {};
```

**AFTER:**
```dart
/// Pool of video controllers with lifecycle state tracking
final Map<String, ControllerEntry> _controllerPool = {};
```

### Change 2.2: Add Cooldown Configuration

**ADD AFTER line 94:**
```dart
/// Cooldown period before hard disposal (seconds)
static const int cooldownSeconds = 3;
```

### Change 2.3: Add Cleanup Timer

**ADD AFTER line 94:**
```dart
/// Cleanup timer for cooldown-based eviction
Timer? _cleanupTimer;
```

---

## Step 3: Add Instrumentation Methods

**File:** `lib/services/global_playback_manager.dart`  
**Location:** Add new section after line 1210 (after telemetry section)

### ADD NEW SECTION:

```dart
// ============================================
// CONTROLLER LIFECYCLE INSTRUMENTATION
// ============================================

/// Log controller lifecycle event
void _logControllerEvent(String event, String videoId, {
  int? controllerId,
  ControllerState? state,
  String? reason,
  int? generation,
}) {
  final entry = _controllerPool[videoId];
  final stateStr = state?.toString() ?? entry?.state.toString() ?? 'unknown';
  final controllerIdStr = controllerId?.toString() ?? entry?.controllerId.toString() ?? 'unknown';
  final genStr = generation?.toString() ?? entry?.generation.toString() ?? 'unknown';
  
  log('🎬 CONTROLLER_LIFECYCLE: event=$event videoId=$videoId '
      'controllerId=$controllerIdStr state=$stateStr '
      'generation=$genStr reason=${reason ?? "N/A"}');
  
  // Log pool snapshot after mutations
  if (event.contains('CREATE') || event.contains('DISPOSE') || 
      event.contains('ACQUIRE') || event.contains('RELEASE')) {
    _logPoolSnapshot(reason: event);
  }
}

/// Log current pool state snapshot
void _logPoolSnapshot({String? reason}) {
  final snapshot = _controllerPool.entries.map((e) {
    final entry = e.value;
    return '${e.key}:${entry.state.name}:pinned=${entry.isPinned}:gen=${entry.generation}';
  }).join(', ');
  log('📊 POOL_SNAPSHOT: size=${_controllerPool.length} reason=${reason ?? "periodic"} [$snapshot]');
}
```

---

## Step 4: Add Pin Set Management

**File:** `lib/services/global_playback_manager.dart`  
**Location:** Add after instrumentation section

### ADD NEW SECTION:

```dart
// ============================================
// PIN SET MANAGEMENT
// ============================================

/// Update pin set for current index (pins current + next 2 videos)
void _updatePinSet(int currentIndex) {
  // Unpin all
  for (final entry in _controllerPool.values) {
    entry.isPinned = false;
  }
  
  // Pin current + next 2
  for (int offset = 0; offset <= poolRadius; offset++) {
    final index = currentIndex + offset;
    final videoId = _indexToVideoId[index];
    if (videoId != null) {
      final entry = _controllerPool[videoId];
      if (entry != null) {
        entry.isPinned = true;
        entry.lastAccessedAt = DateTime.now();
        _logControllerEvent('PIN_SET', videoId, reason: 'index=$index');
      }
    }
  }
  
  _logPoolSnapshot(reason: 'pin_set_update');
}
```

---

## Step 5: Update registerController()

**File:** `lib/services/global_playback_manager.dart`  
**Location:** Lines 775-977

This is a major change. The method needs to:
1. Create ControllerEntry instead of directly storing controller
2. Log CREATE_CONTROLLER event
3. Handle old controller disposal with state tracking
4. Log PREPARED event when initialized

**KEY CHANGES:**

1. Replace controller storage:
```dart
// OLD:
_controllerPool[videoId] = controller;

// NEW:
final entry = ControllerEntry(
  controller: controller,
  videoId: videoId,
  controllerId: controller.hashCode,
  state: ControllerState.ready, // Assuming it's initialized when registered
  createdAt: DateTime.now(),
  initCompletedAt: DateTime.now(),
);
_controllerPool[videoId] = entry;
_logControllerEvent('CREATE_CONTROLLER', videoId, 
  controllerId: controller.hashCode, state: ControllerState.ready);
```

2. Handle old controller:
```dart
// OLD:
final oldController = _controllerPool[videoId];

// NEW:
final oldEntry = _controllerPool[videoId];
if (oldEntry != null && !identical(oldEntry.controller, controller)) {
  _logControllerEvent('DISPOSE_REQUESTED', videoId, 
    reason: 'replaced_by_new_controller');
  // Dispose old controller
  _disposeControllerEntry(oldEntry, reason: 'replaced');
}
```

---

## Step 6: Update ensureControllerReady()

**File:** `lib/services/global_playback_manager.dart`  
**Location:** Lines 1361-1489

**KEY CHANGES:**

1. Check for existing entry:
```dart
// OLD:
var controller = _controllerPool[videoId];

// NEW:
var entry = _controllerPool[videoId];
var controller = entry?.controller;
if (entry != null && entry.isReady && controller != null && _isControllerSafe(videoId, controller)) {
  // Controller ready, return early
  return;
}
```

2. Create entry with generation token:
```dart
// Create new entry with state 'creating'
entry = ControllerEntry(
  controller: controller,
  videoId: videoId,
  controllerId: controller.hashCode,
  state: ControllerState.creating,
  createdAt: DateTime.now(),
  generation: (entry?.generation ?? -1) + 1, // Increment generation
);
_controllerPool[videoId] = entry;
final localGen = entry.generation;
_logControllerEvent('CREATE_CONTROLLER', videoId, 
  controllerId: controller.hashCode, state: ControllerState.creating, generation: localGen);
```

3. Update state during initialization:
```dart
// Before initialize():
entry.state = ControllerState.preloading;
entry.initStartedAt = DateTime.now();
_logControllerEvent('START_PRELOAD', videoId, state: ControllerState.preloading, generation: localGen);

// After initialize():
entry.state = ControllerState.ready;
entry.initCompletedAt = DateTime.now();
// Check generation token
if (entry.generation == localGen) {
  _logControllerEvent('PREPARED', videoId, state: ControllerState.ready, generation: localGen);
} else {
  _logControllerEvent('PREPARED_STALE', videoId, 
    reason: 'generation_mismatch local=$localGen current=${entry.generation}');
  // Stale completion - dispose this controller
  _disposeControllerEntry(entry, reason: 'stale_init_completion');
  return;
}
```

---

## Step 7: Update disposeFarControllers() with Two-Stage Eviction

**File:** `lib/services/global_playback_manager.dart`  
**Location:** Lines 1613-1829

This is the most critical change. Replace the entire method with:

```dart
/// Two-stage eviction: cooldown (soft) then disposal (hard)
void disposeFarControllers(int currentIndex) {
  try {
    _updatePinSet(currentIndex);
    
    final now = DateTime.now();
    final toDispose = <String>[];
    final toCooldown = <String>[];
    
    // Clean up stale/disposed entries first
    final staleEntries = <String>[];
    for (final entry in _controllerPool.entries) {
      try {
        final videoId = entry.key;
        final controllerEntry = entry.value;
        if (!_isControllerSafe(videoId, controllerEntry.controller)) {
          staleEntries.add(videoId);
        }
      } catch (e) {
        log('⚠️ PlaybackManager: Error checking entry safety: $e');
      }
    }
    
    for (final videoId in staleEntries) {
      _logControllerEvent('DISPOSE_REQUESTED', videoId, reason: 'stale_controller');
      final entry = _controllerPool.remove(videoId);
      if (entry != null) {
        _disposeControllerEntry(entry, reason: 'stale');
      }
    }
    
    // Stage A: Mark controllers outside radius for cooldown
    for (final entry in _controllerPool.entries) {
      final videoId = entry.key;
      final controllerEntry = entry.value;
      final videoIndex = _videoIdToIndex[videoId];
      
      // Skip if pinned, in use, or initializing
      if (controllerEntry.isPinned || 
          controllerEntry.state == ControllerState.inUse ||
          controllerEntry.isInitializing ||
          videoId == _activeVideoId ||
          _isActiveVideo(videoId)) {
        continue;
      }
      
      // Check if outside radius
      if (videoIndex != null && (videoIndex - currentIndex).abs() > poolRadius) {
        if (controllerEntry.state == ControllerState.coolingDown) {
          // Already in cooldown - check if expired
          if (controllerEntry.coolingDownUntil != null &&
              now.isAfter(controllerEntry.coolingDownUntil!)) {
            // Cooldown expired - mark for disposal
            if (controllerEntry.canDispose) {
              toDispose.add(videoId);
            }
          }
        } else if (controllerEntry.isReady) {
          // Ready but outside radius - start cooldown
          controllerEntry.state = ControllerState.coolingDown;
          controllerEntry.coolingDownUntil = now.add(Duration(seconds: cooldownSeconds));
          toCooldown.add(videoId);
          _logControllerEvent('START_COOLDOWN', videoId, 
            state: ControllerState.coolingDown, 
            reason: 'outside_radius index=$videoIndex current=$currentIndex');
        }
      } else if (videoIndex == null && controllerEntry.isReady) {
        // No index mapping but ready - start cooldown
        controllerEntry.state = ControllerState.coolingDown;
        controllerEntry.coolingDownUntil = now.add(Duration(seconds: cooldownSeconds));
        toCooldown.add(videoId);
        _logControllerEvent('START_COOLDOWN', videoId, 
          state: ControllerState.coolingDown, reason: 'no_index_mapping');
      }
    }
    
    // Stage B: Hard eviction (rate limited - max 1 per cycle)
    if (toDispose.isNotEmpty && _controllerPool.length > maxControllerPoolSize) {
      // Sort by distance (furthest first)
      toDispose.sort((a, b) {
        final indexA = _videoIdToIndex[a];
        final indexB = _videoIdToIndex[b];
        if (indexA == null) return 1;
        if (indexB == null) return -1;
        final distA = (indexA - currentIndex).abs();
        final distB = (indexB - currentIndex).abs();
        return distB.compareTo(distA); // Furthest first
      });
      
      // Dispose only the furthest one (rate limit)
      final videoIdToDispose = toDispose.first;
      final entry = _controllerPool.remove(videoIdToDispose);
      if (entry != null) {
        _logControllerEvent('DISPOSE_REQUESTED', videoIdToDispose, 
          reason: 'cooldown_expired_furthest');
        _disposeControllerEntry(entry, reason: 'cooldown_expired');
      }
    }
    
    // If pool still too large after cooldown, mark more for cooldown
    if (_controllerPool.length > maxControllerPoolSize) {
      final readyEntries = _controllerPool.entries
          .where((e) => e.value.isReady && !e.value.isPinned && !e.value.isInitializing)
          .toList();
      readyEntries.sort((a, b) {
        final indexA = _videoIdToIndex[a.key];
        final indexB = _videoIdToIndex[b.key];
        if (indexA == null) return 1;
        if (indexB == null) return -1;
        final distA = (indexA - currentIndex).abs();
        final distB = (indexB - currentIndex).abs();
        return distB.compareTo(distA);
      });
      
      // Mark furthest ready entries for cooldown
      for (final entry in readyEntries.take(_controllerPool.length - maxControllerPoolSize)) {
        if (entry.value.state != ControllerState.coolingDown) {
          entry.value.state = ControllerState.coolingDown;
          entry.value.coolingDownUntil = now.add(Duration(seconds: cooldownSeconds));
          _logControllerEvent('START_COOLDOWN', entry.key, 
            state: ControllerState.coolingDown, reason: 'pool_size_limit');
        }
      }
    }
    
  } catch (e, stackTrace) {
    log('❌ PlaybackManager: Error in disposeFarControllers: $e');
    log('Stack trace: $stackTrace');
  }
}

/// Dispose a controller entry (idempotent)
void _disposeControllerEntry(ControllerEntry entry, {required String reason}) {
  if (entry.state == ControllerState.disposing || entry.state == ControllerState.disposed) {
    _logControllerEvent('DISPOSE_SKIPPED', entry.videoId, reason: 'already_disposing_or_disposed');
    return;
  }
  
  entry.state = ControllerState.disposing;
  entry.disposeAttempts++;
  
  _logControllerEvent('DISPOSING', entry.videoId, 
    state: ControllerState.disposing, reason: reason);
  
  try {
    // Clean up mappings
    final videoId = entry.videoId;
    _controllerOwners.remove(videoId);
    _muteStates.remove(videoId);
    final videoIndex = _videoIdToIndex[videoId];
    if (videoIndex != null) {
      _videoIdToIndex.remove(videoId);
      _indexToVideoId.remove(videoIndex);
      _lastKnownPositions.remove(videoIndex);
    }
    
    // Dispose controller
    if (_isControllerSafe(videoId, entry.controller)) {
      entry.controller.dispose();
    }
    
    entry.state = ControllerState.disposed;
    _logControllerEvent('DISPOSED', videoId, state: ControllerState.disposed, reason: reason);
  } catch (e) {
    log('❌ PlaybackManager: Error disposing controller entry: $e');
    entry.state = ControllerState.failed;
    entry.failureReason = e.toString();
  }
}
```

---

## Step 8: Update preloadAround() to Use Pin Set

**File:** `lib/services/global_playback_manager.dart`  
**Location:** Lines 1494-1608

**KEY CHANGE:**

Add pin set update at the beginning:
```dart
void preloadAround(int index, List<HomeVideo> videos) {
  // ... existing validation ...
  
  // Update pin set first
  _updatePinSet(index);
  
  // ... rest of preload logic ...
  
  // Start cleanup timer (debounced)
  _cleanupTimer?.cancel();
  _cleanupTimer = Timer(const Duration(milliseconds: 200), () {
    if (_controllerPool.length > maxControllerPoolSize) {
      disposeFarControllers(index);
    }
  });
}
```

---

## Step 9: Update Helper Methods

Several methods need updates to work with ControllerEntry:

1. `getController(String videoId)` - Return `entry?.controller`
2. `_isControllerSafe()` - Check `entry.controller`
3. All methods that access `_controllerPool[videoId]` directly

**Pattern:**
```dart
// OLD:
final controller = _controllerPool[videoId];
if (controller != null && _isControllerSafe(videoId, controller)) {
  // use controller
}

// NEW:
final entry = _controllerPool[videoId];
final controller = entry?.controller;
if (controller != null && _isControllerSafe(videoId, controller)) {
  // use controller
  entry.lastAccessedAt = DateTime.now(); // Update access time
}
```

---

## Step 10: Update onVisibleIndexChanged() for ACQUIRE Event

**File:** `lib/services/global_playback_manager.dart`  
**Location:** Lines 1246-1342

When a controller becomes current, log ACQUIRE event:
```dart
// When controller becomes ready and current:
final entry = _controllerPool[videoId];
if (entry != null) {
  entry.state = ControllerState.inUse;
  entry.lastPlayRequestedAt = DateTime.now();
  _logControllerEvent('ACQUIRE_FOR_CURRENT', videoId, state: ControllerState.inUse);
}
```

---

## Migration Notes

1. **Backward Compatibility:** The `getController()` method should return `VideoPlayerController?` to maintain API compatibility.

2. **Gradual Migration:** Consider keeping old methods as wrappers during transition:
```dart
VideoPlayerController? getController(String videoId) {
  return _controllerPool[videoId]?.controller;
}
```

3. **Testing:** Test thoroughly with:
   - Cold start
   - Rapid scrolling
   - Scroll back
   - Background/foreground
   - Memory pressure scenarios

---

## Next Steps

1. Implement Step 2-4 (infrastructure)
2. Implement Step 5-6 (core methods)
3. Implement Step 7 (cleanup)
4. Update helper methods (Step 9)
5. Test and verify
6. Monitor logs for instrumentation data

---

**End of Implementation Guide**

