# TikTok-Style HomeView - Complete Implementation Guide

## Overview

This guide outlines exactly how to make HomeView work like TikTok's For You feed.

## Key TikTok Behaviors

### 1. ✅ Instant Playback (ALREADY IMPLEMENTED)
- Videos start playing immediately when scrolled into view
- No loading indicators/spinners
- Black screen only if video fails (not during loading)
- Background initialization

### 2. ✅ Smooth Vertical Scrolling (ALREADY IMPLEMENTED)
- `PageView` with `Axis.vertical`
- `ClampingScrollPhysics` for mobile feel
- Smooth page transitions

### 3. ✅ Auto-Play/Pause (ALREADY IMPLEMENTED)
- Current video plays automatically
- Previous/next videos pause automatically
- Managed by `GlobalPlaybackManager`

### 4. ✅ Single Active Video (ALREADY IMPLEMENTED)
- Only one video plays at a time
- Audio focus management
- No audio bleeding

### 5. ⚠️ Infinite Scroll (NEEDS VERIFICATION)
- Load more videos as user scrolls near the end
- Seamless pagination
- No loading indicators

### 6. ✅ Pull to Refresh (ALREADY IMPLEMENTED)
- Refresh from top (index 0)
- Preserves current position

### 7. ✅ Preloading (ALREADY IMPLEMENTED)
- Preload previous/current/next videos
- `preloadAround()` method
- Memory-efficient disposal of distant videos

## Current Implementation Status

### ✅ What's Working Well

1. **Video Playback**
   - Instant playback (no loading spinners)
   - TikTok-style "mount first, then refine" approach
   - Background initialization
   - Texture remount for stuck videos

2. **Scroll Management**
   - Vertical PageView
   - Smooth transitions
   - Index tracking
   - Position preservation

3. **Playback Management**
   - GlobalPlaybackManager handles single active video
   - Audio focus management
   - Controller pooling
   - Preloading strategy

4. **Feed Management**
   - Pull to refresh
   - Tab switching (For You / Following)
   - Video loading and caching

### ⚠️ Potential Improvements

1. **Infinite Scroll**
   - Verify `loadMoreVideosIfNeeded()` is called at the right time
   - Should trigger when user is ~3-5 videos from the end
   - Should load in background without blocking UI

2. **Smooth Transitions**
   - Ensure no frame drops during scroll
   - Optimize PageView physics if needed
   - Verify preloading prevents stutters

3. **Memory Management**
   - Verify distant videos are disposed properly
   - Check controller pool size limits
   - Monitor for memory leaks

4. **Performance**
   - Ensure 60fps scrolling
   - Optimize video widget rebuilds
   - Use const constructors where possible

## How TikTok Works (Technical Details)

### Scroll Behavior
```
User swipes up → PageView scrolls → onPageChanged fires → 
GlobalPlaybackManager.onVisibleIndexChanged() → 
New video plays, old video pauses → 
Preload next video in background
```

### Playback Flow
```
1. Video comes into view (index changes)
2. GlobalPlaybackManager.requestFocus(videoId, ownerKey)
3. VideoPlayerViewOptimized initializes (or reuses pooled controller)
4. Video starts playing automatically
5. Audio unmutes after brief delay (50-100ms)
6. Previous video pauses and mutes
```

### Preloading Strategy
```
Current video at index N:
- Keep controller for index N-1 (previous)
- Keep controller for index N (current) - ACTIVE
- Keep controller for index N+1 (next)
- Dispose controllers for index < N-1 or > N+1
```

### Infinite Scroll
```
User scrolls to index N (near end):
- Check if N >= videos.length - 5
- If yes, loadMoreVideosIfNeeded()
- Append new videos to list
- Continue scrolling seamlessly
```

## Verification Checklist

### ✅ Scroll Performance
- [ ] Scroll is smooth (60fps)
- [ ] No frame drops during transitions
- [ ] PageView physics feel natural
- [ ] No lag when swiping

### ✅ Playback Behavior
- [ ] Videos play instantly (no loading screens)
- [ ] Only one video plays at a time
- [ ] Previous video pauses immediately
- [ ] Next video starts playing smoothly
- [ ] No audio bleeding

### ✅ Preloading
- [ ] Next video is preloaded
- [ ] Previous video controller is kept
- [ ] Distant videos are disposed
- [ ] Memory usage is reasonable

### ✅ Infinite Scroll
- [ ] More videos load as user scrolls
- [ ] Loading happens in background
- [ ] No loading indicators shown
- [ ] Seamless pagination

### ✅ Pull to Refresh
- [ ] Pull down at top refreshes feed
- [ ] New videos appear at index 0
- [ ] Current position is preserved (if not at top)
- [ ] Refresh completes smoothly

### ✅ Error Handling
- [ ] Bad videos show neutral overlay (not red error)
- [ ] Bad videos auto-skip after delay
- [ ] No red error screens during scrolling
- [ ] App doesn't crash on video errors

## Code Locations

### Main Components

1. **HomeView** (`lib/pages/home_view.dart`)
   - Main orchestrator
   - Handles tab switching
   - Manages feed state
   - Coordinates playback

2. **VideoPageViewWidget** (`lib/widgets/home_view_components/video_page_view_widget.dart`)
   - Vertical PageView
   - Scroll handling
   - Page change callbacks

3. **VideoPlayerViewOptimized** (`lib/widgets/video_player_view_optimized.dart`)
   - Individual video player
   - Playback controls
   - Error handling

4. **GlobalPlaybackManager** (`lib/services/global_playback_manager.dart`)
   - Single active video management
   - Controller pooling
   - Preloading
   - Audio focus

5. **HomeProvider** (`lib/providers/home_provider.dart`)
   - Video data management
   - Feed loading
   - Infinite scroll

## Recommended Improvements (If Needed)

### 1. Enhance Infinite Scroll Trigger
```dart
// In _onPageChanged()
if (index >= videos.length - 5) {
  // Load more videos (background, non-blocking)
  homeNotifier.loadMoreVideosIfNeeded();
}
```

### 2. Optimize PageView Physics
```dart
PageView(
  physics: const ClampingScrollPhysics(),
  scrollDirection: Axis.vertical,
  // Consider: BouncingScrollPhysics for iOS-like feel
  // Or: Custom scroll physics for TikTok-like feel
)
```

### 3. Improve Preloading Window
```dart
// In GlobalPlaybackManager.preloadAround()
// Consider increasing poolRadius from 1 to 2 for even smoother transitions
preloadAround(index, videos, poolRadius: 2);
```

### 4. Add Scroll Performance Monitoring
```dart
// Monitor scroll performance
// Use Flutter DevTools Performance overlay
// Ensure 60fps during scrolling
```

## Testing TikTok Behavior

### Manual Test Checklist

1. **Open HomeView**
   - ✅ First video should play automatically
   - ✅ No loading indicator
   - ✅ Video starts immediately

2. **Swipe Up**
   - ✅ Next video plays immediately
   - ✅ Previous video pauses
   - ✅ Transition is smooth
   - ✅ No frame drops

3. **Swipe Down**
   - ✅ Previous video resumes from last position
   - ✅ Current video pauses
   - ✅ Transition is smooth

4. **Scroll to End**
   - ✅ More videos load automatically
   - ✅ No loading indicator
   - ✅ Seamless continuation

5. **Pull to Refresh**
   - ✅ Pull down at top refreshes feed
   - ✅ New videos appear
   - ✅ First video plays

6. **Error Handling**
   - ✅ Bad video shows neutral overlay (not red)
   - ✅ Auto-skips after delay
   - ✅ App doesn't crash

## Summary

Your HomeView implementation is already very close to TikTok's behavior! The main things to verify are:

1. **Infinite scroll** is triggering properly
2. **Performance** is smooth (60fps)
3. **Memory management** is efficient
4. **Error handling** is graceful

The architecture is solid - you have:
- ✅ GlobalPlaybackManager for single active video
- ✅ Instant playback implementation
- ✅ Preloading strategy
- ✅ Pull to refresh
- ✅ Smooth PageView scrolling

If everything is working smoothly, you're done! If not, use the checklists above to identify and fix any issues.

