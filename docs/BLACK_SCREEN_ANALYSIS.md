# Black Screen Before Videos Play - Root Cause Analysis

## Problem
User reports: **"WHY ARE we still seeing black before all our videos play"**

## Root Causes Identified

### 1. Controller Not Preloaded When Video Becomes Current ⚠️ **PRIMARY**

**Location:** `lib/widgets/video_player_view_optimized.dart:3449-3451`

```dart
if (controller == null) {
  // TikTok-style: Videos should be preloaded - show black while waiting
  return const ColoredBox(color: Colors.black);
}
```

**Problem:**
- When a video becomes current, `_videoPlayerController` is `null`
- Preloading happens **AFTER** `_onPageChanged()` is called
- `preloadAround()` is async and fire-and-forget
- Video widget shows black screen while controller initializes

**Flow:**
1. User swipes to video → `_onPageChanged(index)` called
2. Video becomes `isCurrentVideo: true`
3. `preloadAround(index, videos)` called (async, fire-and-forget)
4. Video widget renders → `controller == null` → **BLACK SCREEN**
5. `_tryAdoptFromPool()` in `initState()` → no controller in pool yet
6. `_initializeVideo()` called → async initialization → **STILL BLACK**
7. Controller initialized → video finally plays

### 2. Controller Exists But Not Initialized Yet ⚠️ **SECONDARY**

**Location:** `lib/widgets/video_player_view_optimized.dart:3519-3521`

```dart
// Black overlay while not ready (videos should be preloaded for instant playback)
if (!v.isInitialized || v.hasError)
  const ColoredBox(color: Colors.black),
```

**Problem:**
- Controller exists but `isInitialized == false`
- Black overlay covers VideoPlayer widget
- Initialization takes 500ms-5 seconds (network latency, codec initialization)

### 3. First Video Not Preloaded on HomeView Load ⚠️ **CRITICAL**

**Location:** `lib/pages/home_view.dart:415-458`

**Problem:**
- `_setDesiredFocusForFirstVideo()` is called after `loadVideos()` completes
- BUT: `preloadAround()` is only called in `_onPageChanged()`
- First video (index 0) is not preloaded until user actually swipes
- When HomeView first renders, first video has no controller → **BLACK SCREEN**

**Current Flow:**
1. HomeView loads → `initState()` → `_loadVideos()` (async)
2. Videos loaded → `_setDesiredFocusForFirstVideo()` called
3. Video widget renders → `controller == null` → **BLACK SCREEN**
4. User sees black screen while first video initializes

**Missing Step:**
- No `preloadAround(0, videos)` call when videos first load
- Preloading only happens on page changes, not initial load

### 4. Preloading is Reactive, Not Proactive ⚠️

**Location:** `lib/services/global_playback_manager.dart:1595-1624`

**Problem:**
- `preloadAround()` only preloads when `_onPageChanged()` is called
- This is **reactive** - happens AFTER page change
- For TikTok-style, we need **proactive** preloading - videos ready BEFORE they're needed

**Current Behavior:**
```
User swipes → _onPageChanged(index) → preloadAround(index) → [async delay] → controller ready
                                                                  ↑
                                                           BLACK SCREEN HERE
```

**Needed Behavior:**
```
preloadAround(index-1) → controller ready → User swipes → video plays instantly
                                              ↑
                                         NO BLACK SCREEN
```

## Solutions

### Solution 1: Preload First Video Immediately When Videos Load ✅ **HIGH PRIORITY**

**Location:** `lib/pages/home_view.dart`

**Change:**
```dart
Future<void> _loadVideos() async {
  try {
    final homeVM = ref.read(hp.homeProvider.notifier);
    await homeVM.loadVideos();
    await _applyAlgorithmRanking();
    
    // 🔥 FIX BLACK SCREEN: Preload first video IMMEDIATELY
    final homeState = ref.read(hp.homeProvider);
    final activeFeed = ref.read(activeFeedProvider);
    final videos = activeFeed == FeedTab.forYou
        ? homeState.forYouVideos
        : homeState.followingVideos;
    
    if (videos.isNotEmpty) {
      // Preload first video BEFORE setting focus
      GlobalPlaybackManager.instance.preloadAround(0, videos);
      
      // Wait for first video to be ready (with timeout)
      await Future.delayed(Duration(milliseconds: 300)); // Give preload head start
      
      _setDesiredFocusForFirstVideo();
    }
  } catch (e) {
    // ...
  }
}
```

### Solution 2: Ensure Preload Completes Before Video Becomes Current ✅ **MEDIUM PRIORITY**

**Location:** `lib/services/global_playback_manager.dart`

**Change:**
- Make `preloadAround()` wait for current video to be ready before returning
- Or: Ensure `ensureControllerReady()` is called and awaited for current video

**Current:**
```dart
ensureControllerReady(n, video).catchError((e, stackTrace) {
  // Fire-and-forget
});
```

**Needed:**
```dart
// For current video (n == index), wait for it
if (n == index) {
  await ensureControllerReady(n, video);
} else {
  ensureControllerReady(n, video).catchError(...);
}
```

### Solution 3: Preload More Aggressively (Current + Next 3) ✅ **LOW PRIORITY**

**Location:** `lib/services/global_playback_manager.dart:1596`

**Change:**
- Increase preload window from 2 to 3-4 videos
- Preload videos 2-3 pages ahead, not just 1-2

### Solution 4: Don't Show VideoWidget Until Controller Ready ⚠️ **NOT RECOMMENDED**

**Problem:** This would cause layout shifts and delay video visibility
**Better:** Ensure controller is ready before video becomes current

## Recommended Fix Priority

1. **🔥 CRITICAL: Fix first video preload on HomeView load**
   - Preload first video immediately when videos load
   - Don't show video until controller is at least initializing

2. **🔥 HIGH: Ensure current video preload completes**
   - Make `preloadAround()` wait for current video to be ready
   - Or: Call `ensureControllerReady()` synchronously for current video

3. **MEDIUM: Increase preload window**
   - Preload 3-4 videos ahead instead of 1-2

4. **LOW: Optimize initialization speed**
   - Reduce initialization timeout
   - Use lower quality for faster initialization

## Implementation Notes

- TikTok shows videos INSTANTLY because they preload aggressively and videos are ready BEFORE user sees them
- Our current approach is reactive (preload after user action)
- Need proactive preloading (preload before user needs it)

