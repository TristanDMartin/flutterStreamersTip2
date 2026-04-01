# Video Quality Solution: Multi-Resolution System

**Date:** 2026-01-03  
**Problem:** 1080p videos cause MediaCodec crashes on 256MB devices  
**Solution:** Multi-resolution video system with device-aware quality selection

---

## 🎯 Solution Overview

Build a **multi-resolution video system** similar to how thumbnails work - store videos in multiple resolutions (1080p, 720p) and automatically select the best quality based on device capabilities.

### Key Benefits:
- ✅ Works with existing 1080p videos (backward compatible)
- ✅ No breaking changes to current architecture
- ✅ Automatic quality selection based on device
- ✅ Enables 2-controller preloading on better devices
- ✅ Matches TikTok's approach (multiple resolutions)

---

## 📋 Implementation Plan

### Phase 1: Backend - Video Transcoding Pipeline (REQUIRED)

**Goal:** Automatically generate 720p versions when videos are uploaded

#### 1.1 Video Upload Service Enhancement

**Location:** Backend/Cloud Functions or video processing service

**Process:**
1. When video is uploaded (1080p original):
   - Store original 1080p video in Firebase Storage: `videos/{videoId}/original.mp4`
   - Trigger transcoding job (Cloud Function / Cloud Run)
   - Generate 720p version: `videos/{videoId}/720p.mp4`
   - Store both URLs in Firestore

**Firestore Structure:**
```javascript
{
  videoUrl: "gs://bucket/videos/video123/original.mp4", // Legacy field (1080p)
  videoUrls: {  // New multi-resolution field
    "1080": "gs://bucket/videos/video123/original.mp4",
    "720": "gs://bucket/videos/video123/720p.mp4"
  },
  metadata: {
    resolution: "1080x1920",
    availableResolutions: ["1080", "720"], // Which resolutions exist
    transcodingStatus: "completed" // processing, completed, failed
  }
}
```

#### 1.2 Existing Videos Retroactive Transcoding

- Background job to transcode existing 1080p videos to 720p
- Updates Firestore with new `videoUrls` field
- Doesn't break existing clients (they still use `videoUrl`)

---

### Phase 2: Frontend - Video Resolution Selector Service (NEW COMPONENT)

**Goal:** Detect device capabilities and select appropriate video resolution

#### 2.1 Create Device Capability Detector

**New File:** `lib/services/device_capability_service.dart`

```dart
class DeviceCapabilityService {
  static DeviceCapabilityService? _instance;
  static DeviceCapabilityService get instance => 
      _instance ??= DeviceCapabilityService._();
  
  DeviceCapabilityService._();
  
  // Detect device heap size (256MB, 512MB, etc.)
  Future<int> getDeviceHeapSizeMB() async {
    // Use platform channel or estimate based on device model
    // For now, use conservative default
    return 256; // Will detect actual size
  }
  
  // Determine best video resolution for device
  Future<String> getRecommendedResolution() async {
    final heapSize = await getDeviceHeapSizeMB();
    
    if (heapSize <= 256) {
      return '720'; // Low memory devices
    } else if (heapSize <= 512) {
      return '720'; // Medium memory (safe default)
    } else {
      return '1080'; // High memory devices
    }
  }
}
```

#### 2.2 Create Video URL Resolver Service

**New File:** `lib/services/video_url_resolver_service.dart`

```dart
class VideoUrlResolverService {
  final DeviceCapabilityService _capabilityService = 
      DeviceCapabilityService.instance;
  
  /// Resolve the best video URL for a video based on device capabilities
  Future<String> resolveVideoUrl(HomeVideo video) async {
    // Check if video has multi-resolution URLs
    if (video.videoUrls != null && video.videoUrls!.isNotEmpty) {
      final recommendedResolution = 
          await _capabilityService.getRecommendedResolution();
      
      // Try recommended resolution first
      if (video.videoUrls!.containsKey(recommendedResolution)) {
        return video.videoUrls![recommendedResolution]!;
      }
      
      // Fallback to 720p if available
      if (video.videoUrls!.containsKey('720')) {
        return video.videoUrls!['720']!;
      }
      
      // Fallback to 1080p if available
      if (video.videoUrls!.containsKey('1080')) {
        return video.videoUrls!['1080']!;
      }
      
      // Fallback to any available resolution
      return video.videoUrls!.values.first;
    }
    
    // Legacy: Use single videoURL field (backward compatibility)
    return video.videoURL;
  }
}
```

#### 2.3 Update HomeVideo Model

**File:** `lib/models/home_video.dart`

```dart
@freezed
class HomeVideo with _$HomeVideo {
  const factory HomeVideo({
    required String id,
    required User creator,
    required String videoURL, // Legacy field (backward compatible)
    Map<String, String>? videoUrls, // NEW: Multi-resolution support
    // ... existing fields ...
  }) = _HomeVideo;
}
```

#### 2.4 Update VideoService to Parse videoUrls

**File:** `lib/services/video_service.dart`

In the video parsing logic, add:

```dart
// Parse multi-resolution video URLs
Map<String, String>? videoUrls;
if (data['videoUrls'] != null) {
  final urlsData = data['videoUrls'] as Map<String, dynamic>;
  videoUrls = urlsData.map((key, value) => 
    MapEntry(key, value.toString()));
}

final video = HomeVideo(
  id: doc.id,
  creator: creator,
  videoURL: videoUrl, // Legacy field
  videoUrls: videoUrls, // NEW: Multi-resolution
  // ... rest of fields ...
);
```

#### 2.5 Update VideoPlayerViewOptimized to Use Resolver

**File:** `lib/widgets/video_player_view_optimized.dart`

In `_initializeVideo()`:

```dart
// Use VideoUrlResolverService to get best URL
final videoUrlResolver = VideoUrlResolverService();
final resolvedUrl = await videoUrlResolver.resolveVideoUrl(widget.video);

// Use resolvedUrl instead of widget.video.videoURL
final uri = Uri.parse(resolvedUrl);
```

---

### Phase 3: Gradual Rollout Strategy

#### 3.1 Backward Compatibility
- ✅ Existing videos continue using `videoUrl` field
- ✅ New videos get `videoUrls` field
- ✅ Client automatically falls back to `videoURL` if `videoUrls` not available

#### 3.2 Migration Path
1. **Week 1:** Deploy backend transcoding (new uploads get 720p)
2. **Week 2:** Deploy frontend resolution selector (uses 720p when available)
3. **Week 3:** Retroactive transcoding of existing videos (background job)
4. **Week 4:** Monitor and optimize

---

## 🎯 Expected Outcomes

### Before (Current):
- ✅ 1 controller max (no preloading)
- ✅ 1080p videos only
- ✅ Crashes on 256MB devices
- ✅ Memory at 255MB/256MB (99.6% full)

### After (With 720p):
- ✅ 2 controllers (TikTok-style preloading) on 512MB+ devices
- ✅ 1 controller with 720p on 256MB devices (safe)
- ✅ No crashes (720p uses ~50% less memory)
- ✅ Memory at ~180-200MB/256MB (safe margin)
- ✅ Better UX (smoother playback, preloading)

---

## 📊 Implementation Priority

### Priority 1 (Immediate - Backend):
1. **Video Transcoding Service** - Generate 720p versions on upload
2. **Firestore Schema Update** - Add `videoUrls` field

### Priority 2 (Frontend - Next):
3. **Device Capability Service** - Detect device heap size
4. **Video URL Resolver Service** - Select best resolution
5. **Model Updates** - Add `videoUrls` to HomeVideo

### Priority 3 (Optimization):
6. **Retroactive Transcoding** - Convert existing videos
7. **Caching Strategy** - Cache resolution selection
8. **Analytics** - Track resolution usage

---

## 🔧 Technical Details

### Video Storage Structure
```
Firebase Storage:
  videos/
    {videoId}/
      original.mp4 (1080p)
      720p.mp4 (720p)
      thumbnail.jpg
```

### Firestore Document Structure
```javascript
{
  id: "video123",
  videoUrl: "gs://bucket/videos/video123/original.mp4", // Legacy
  videoUrls: {
    "1080": "gs://bucket/videos/video123/original.mp4",
    "720": "gs://bucket/videos/video123/720p.mp4"
  },
  metadata: {
    resolution: "1080x1920",
    availableResolutions: ["1080", "720"],
    transcodingStatus: "completed"
  }
}
```

### Resolution Selection Logic
```
Device Heap Size → Recommended Resolution
≤ 256MB → 720p (safe)
257-512MB → 720p (recommended)
> 512MB → 1080p (full quality)
```

---

## ✅ Why This Is The Best Solution

1. **Backward Compatible** - Works with existing videos
2. **Future-Proof** - Easy to add 480p, 360p later
3. **Device-Aware** - Automatically adapts to device capabilities
4. **TikTok-Aligned** - Industry standard approach
5. **No Breaking Changes** - Existing clients continue working
6. **Gradual Rollout** - Can deploy incrementally
7. **Performance** - Enables 2-controller preloading on capable devices

---

## 🚀 Next Steps

1. **Backend Team:** Implement video transcoding pipeline
2. **Frontend Team:** Build resolution selector service (this document)
3. **QA:** Test on various device types
4. **Monitor:** Track resolution usage and memory metrics

This solution provides a sustainable path forward that works with your existing infrastructure while solving the memory constraints.

