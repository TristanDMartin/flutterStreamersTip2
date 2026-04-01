# Video Error Screen Issue

## Problem Summary

Users are experiencing red error screens appearing during video playback initialization and when swiping between videos. The error screen shows "Playback error: Video format not supported" or similar messages, disrupting the user experience.

## Symptoms

1. **Before Video Plays**: Red error screen appears immediately when a video starts initializing
2. **During Swipe Transitions**: Red error screen flashes briefly when swiping between videos
3. **Specific Video (OSAfmoAii1)**: One particular video consistently triggers the error
4. **Format Not Supported**: Error message indicates video format/codec issues

## Root Causes (Identified)

### 1. Missing Quality Variants
- Some videos don't have transcoded 720p/480p variants in Firestore
- App falls back to 1080p which causes format/decoding issues on low-memory devices
- Videos may have incomplete transcoding status

### 2. URL Resolution Failures
- `resolveVideoUrlWithQuality()` returns empty for videos without quality variants
- Fallback to `widget.video.videoURL` may point to invalid/missing files
- Firestore fetch timeout (3 seconds) may cause fallback to stale URLs

### 3. Race Conditions During Transitions
- Error state is set before widget disposal check
- Errors display even when video is no longer current
- Initialization errors propagate to UI before retry attempts complete

### 4. Video Format Compatibility
- Some videos may use unsupported codecs/containers
- Native MediaCodec errors on Android when video can't be decoded
- HLS vs MP4 format mismatch

## Attempted Fixes

### Fix 1: Delayed Error Display ✅
- **Implemented**: Added `_showErrorAfterDelay` flag to prevent immediate error display
- **Result**: Partially effective - delays error but still appears

### Fix 2: Pre-Error URL Refresh ✅
- **Implemented**: Attempts to refresh URL from Firestore before showing error
- **Result**: Helps for videos with quality variants, but fails for videos without them

### Fix 3: Conditional Error Display ✅
- **Implemented**: Only show errors if video is current and not initializing
- **Result**: Reduces errors during transitions, but still appears for problematic videos

### Fix 4: Improved URL Resolution ✅
- **Implemented**: Always fetch from Firestore to get latest quality variants
- **Result**: Works when variants exist, but empty fallback chain causes errors

### Fix 5: Format Error Detection ✅
- **Implemented**: Detect format errors and attempt URL refresh before showing error
- **Result**: Helps with some cases, but doesn't solve root cause of missing variants

## Current Code Flow

```
1. Widget initializes → _initializeVideo()
2. Fetch from Firestore (3s timeout)
3. Try resolveVideoUrlWithQuality() → May return empty
4. Try resolveVideoUrl() → May return empty  
5. Fallback to widget.video.videoURL → May be invalid
6. If empty/invalid → Set error after delay (500-800ms)
7. Error displays if video still current
```

## Why Fixes Haven't Fully Resolved

1. **Missing Backend Data**: Videos without transcoded variants can't be fixed on frontend alone
2. **No Graceful Degradation**: When all URL resolution fails, we have no fallback
3. **Error Display Timing**: Even with delays, errors appear if video becomes current during initialization
4. **Race Conditions**: Multiple initialization attempts may conflict

## Proposed Solutions

### Solution 1: Skip Videos Without Valid URLs (Immediate) 🔴
**Priority: HIGH**

- Check if video has valid URL before attempting initialization
- If no valid URL after all fallbacks, skip video silently (don't show in feed)
- Log skipped videos for backend processing
- **Pros**: Prevents error screens entirely
- **Cons**: Videos temporarily unavailable to users

**Implementation**:
```dart
// In VideoService or HomeView
Future<List<HomeVideo>> filterVideosWithValidUrls(List<HomeVideo> videos) async {
  final validVideos = <HomeVideo>[];
  for (final video in videos) {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('videos')
          .doc(video.id)
          .get();
      if (snapshot.exists) {
        final url = await resolveVideoUrlWithQuality(snapshot.data()!);
        if (url.isEmpty) {
          final fallback = resolveVideoUrl(snapshot.data()!);
          if (fallback.isNotEmpty) {
            validVideos.add(video);
          }
        } else {
          validVideos.add(video);
        }
      }
    } catch (e) {
      log('Skipping video ${video.id}: No valid URL');
    }
  }
  return validVideos;
}
```

### Solution 2: Backend Transcoding Completion (Required) 🟡
**Priority: CRITICAL**

- Ensure all published videos have 720p and 480p variants
- Complete backfill transcoding for existing videos
- Mark videos as "ready" only after all variants are available
- **Status**: Backfill function exists but may not have processed all videos

**Action Items**:
1. Check backfill transcoding status
2. Re-run backfill for videos missing variants
3. Update video service to filter out videos without variants

### Solution 3: Loading State Instead of Error (UX Improvement) 🟢
**Priority: MEDIUM**

- Show loading spinner indefinitely instead of error screen
- Allow user to swipe past problematic videos
- **Pros**: Better UX, no jarring error screens
- **Cons**: Videos may never load if truly broken

**Implementation**:
```dart
// Show loading instead of error for format issues
if (isFormatError && !hasValidUrl) {
  return _buildLoadingState(); // Instead of error
}
```

### Solution 4: Client-Side Video Validation (Preventive) 🟢
**Priority: MEDIUM**

- Validate video URL accessibility before initialization
- HEAD request to check if URL is reachable
- Cache validation results to avoid repeated checks
- **Pros**: Prevents initialization of broken URLs
- **Cons**: Adds network overhead

### Solution 5: Error Recovery with Retry (Current Enhancement) 🟢
**Priority: LOW**

- Increase retry attempts for format errors
- Exponential backoff with longer delays
- Only show error after all retries exhausted
- **Pros**: Handles transient network issues
- **Cons**: Doesn't solve missing variant issue

## Testing Recommendations

1. **Test with Problem Video**: Verify OSAfmoAii1 specifically
2. **Rapid Swiping**: Test quick transitions between videos
3. **Low Memory Devices**: Test on 256MB heap devices
4. **Network Conditions**: Test with slow/unstable connections
5. **Video Variants**: Verify Firestore has quality variants for test videos

## Next Steps

### Immediate (This Week)
1. ✅ Document the problem (this file)
2. ⏳ Implement Solution 1: Skip videos without valid URLs
3. ⏳ Check backfill transcoding status
4. ⏳ Implement Solution 3: Loading state instead of error

### Short Term (Next Week)
1. ⏳ Complete backfill transcoding for all videos
2. ⏳ Implement Solution 4: Client-side validation
3. ⏳ Add video health checks to backend

### Long Term (Next Month)
1. ⏳ Real-time transcoding status updates
2. ⏳ Video quality monitoring dashboard
3. ⏳ Automatic retry for failed transcodings

## Related Files

- `lib/widgets/video_player_view_optimized.dart` - Main video player widget
- `lib/utils/video_url_resolver.dart` - URL resolution logic
- `lib/services/video_service.dart` - Video loading service
- `lib/services/device_capability_service.dart` - Device capability detection
- `cloud_functions/index.js` - Backend transcoding functions

## Error Log Patterns to Monitor

```
⚠️ VideoPlayer: Device-aware resolution returned empty
⚠️ VideoPlayer: Using widget URL as final fallback
❌ VideoPlayer: Controller initialization failed
🔄 VideoPlayer: Format error detected, trying to refresh URL
```

## Metrics to Track

1. **Error Rate**: % of videos showing error screen
2. **Format Error Rate**: % of format-specific errors
3. **Missing Variant Rate**: % of videos without quality variants
4. **Skip Rate**: % of videos skipped due to invalid URLs
5. **Recovery Rate**: % of errors that recover after retry

## Notes

- The issue is more prevalent on low-memory devices (256MB heap)
- Specific video OSAfmoAii1 consistently fails (investigate why)
- Error screens are most jarring during rapid swiping
- Users can't recover from error without manual retry

---

**Last Updated**: 2025-01-XX
**Status**: 🔴 Active Issue - Partial Fixes Applied
**Assigned**: Backend + Frontend Teams

