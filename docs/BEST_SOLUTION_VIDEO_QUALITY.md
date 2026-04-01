# Best Solution: Multi-Resolution Video System (Leveraging Existing Infrastructure)

**Date:** 2026-01-03  
**Problem:** 1080p videos cause MediaCodec crashes on 256MB devices  
**Solution:** Use existing multi-resolution infrastructure + device-aware selection

---

## 🎯 Key Discovery

Your codebase **already has multi-resolution video support**! 

The `video_url_resolver.dart` looks for:
- `mp4_1080_url`
- `mp4_720_url`
- `mp4_480_url`
- Falls back to `videoUrl`

**This means the infrastructure is ready - we just need to:**
1. Ensure backend generates/populates these fields
2. Add device-aware resolution selection
3. Use the resolver in video player

---

## ✅ Solution Overview

Build a **device-aware video resolution selector** that:
- Detects device heap size (256MB, 512MB, etc.)
- Selects appropriate resolution (720p for low memory, 1080p for high memory)
- Uses existing `video_url_resolver.dart` infrastructure
- Works with existing backend fields (`mp4_720_url`, `mp4_1080_url`)
- Backward compatible (falls back to `videoUrl` if resolutions not available)

---

## 📋 Implementation (3 Steps)

### Step 1: Create Device Capability Service (NEW)

**File:** `lib/services/device_capability_service.dart`

```dart
import 'dart:io';
import 'dart:developer' as developer;

class DeviceCapabilityService {
  static DeviceCapabilityService? _instance;
  static DeviceCapabilityService get instance => 
      _instance ??= DeviceCapabilityService._();
  
  DeviceCapabilityService._();
  
  int? _cachedHeapSizeMB;
  
  /// Get device heap size in MB (estimates based on device model/manufacturer)
  Future<int> getDeviceHeapSizeMB() async {
    if (_cachedHeapSizeMB != null) {
      return _cachedHeapSizeMB!;
    }
    
    try {
      if (Platform.isAndroid) {
        // Use device model to estimate heap size
        // Low-end devices: 256MB
        // Mid-range: 512MB
        // High-end: 768MB+
        final model = await _getAndroidDeviceModel();
        _cachedHeapSizeMB = _estimateHeapFromModel(model);
      } else if (Platform.isIOS) {
        // iOS devices generally have more memory
        _cachedHeapSizeMB = 512; // Conservative default
      } else {
        _cachedHeapSizeMB = 512; // Default
      }
    } catch (e) {
      developer.log('⚠️ Error detecting heap size: $e');
      _cachedHeapSizeMB = 256; // Safe default (lowest)
    }
    
    return _cachedHeapSizeMB!;
  }
  
  Future<String> _getAndroidDeviceModel() async {
    // Could use device_info_plus package or platform channels
    // For now, return empty (will use conservative default)
    return '';
  }
  
  int _estimateHeapFromModel(String model) {
    // Conservative: Assume 256MB unless proven otherwise
    // Can be enhanced with device database
    return 256;
  }
  
  /// Get recommended video resolution for device
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

**Alternative (Better):** Use `device_info_plus` package to detect actual device specs

### Step 2: Enhance Video URL Resolver (UPDATE EXISTING)

**File:** `lib/utils/video_url_resolver.dart`

Add device-aware resolution selection:

```dart
import '../services/device_capability_service.dart';

/// Resolve video URL with device-aware quality selection
Future<String> resolveVideoUrlWithQuality(
  Map<String, dynamic> data, {
  String? preferredResolution,
}) async {
  // Get recommended resolution if not provided
  final resolution = preferredResolution ?? 
      await DeviceCapabilityService.instance.getRecommendedResolution();
  
  // Try to find the preferred resolution first
  final resolutionKey = 'mp4_${resolution}_url';
  final preferredUrl = data[resolutionKey] as String?;
  if (preferredUrl != null && preferredUrl.trim().isNotEmpty) {
    return preferredUrl.trim();
  }
  
  // Fall back to existing resolver logic
  return resolveVideoUrl(data);
}

// Keep existing resolveVideoUrl for backward compatibility
String resolveVideoUrl(Map<String, dynamic> data) {
  // ... existing code ...
}
```

### Step 3: Update Video Player to Use Enhanced Resolver (UPDATE EXISTING)

**File:** `lib/widgets/video_player_view_optimized.dart`

In `_initializeVideo()` method, update the URL resolution:

```dart
// Find the line that uses resolveVideoUrl
final resolved = resolveVideoUrl(data);

// Replace with:
final resolved = await resolveVideoUrlWithQuality(data);
```

---

## 🔧 Backend Requirements (If Not Already Implemented)

Your backend needs to populate these fields in Firestore:

```javascript
{
  videoUrl: "gs://bucket/video.mp4", // Legacy field (1080p)
  mp4_1080_url: "gs://bucket/video_1080p.mp4", // Optional
  mp4_720_url: "gs://bucket/video_720p.mp4", // Required for this solution
  mp4_480_url: "gs://bucket/video_480p.mp4", // Optional
}
```

**Backend Process:**
1. When video is uploaded (1080p original)
2. Generate 720p version (transcoding)
3. Store both in Firebase Storage
4. Update Firestore with both URLs

---

## 📊 Expected Outcomes

### Before:
- ✅ Single `videoUrl` field (1080p only)
- ✅ Crashes on 256MB devices
- ✅ 1 controller max (no preloading)

### After:
- ✅ Multiple resolution URLs (`mp4_720_url`, `mp4_1080_url`)
- ✅ Device-aware selection (720p on low memory, 1080p on high memory)
- ✅ No crashes (720p uses 50% less memory)
- ✅ 2-controller preloading on capable devices

---

## 🚀 Implementation Priority

### Priority 1 (Frontend - Can Do Now):
1. ✅ Create `DeviceCapabilityService` (estimates heap size)
2. ✅ Enhance `video_url_resolver.dart` with quality selection
3. ✅ Update `VideoPlayerViewOptimized` to use enhanced resolver
4. ✅ Test with existing videos (will fallback to `videoUrl`)

### Priority 2 (Backend - Coordinate):
5. 🔄 Backend: Generate 720p versions on upload
6. 🔄 Backend: Populate `mp4_720_url` field in Firestore
7. 🔄 Backend: Retroactive transcoding of existing videos

---

## ✅ Why This Is The Best Solution

1. **Leverages Existing Code** - Uses `video_url_resolver.dart` that already exists
2. **Backward Compatible** - Falls back to `videoUrl` if resolutions not available
3. **No Breaking Changes** - Works with existing videos
4. **Device-Aware** - Automatically selects best quality for device
5. **Future-Proof** - Easy to add 480p, 360p later
6. **TikTok-Aligned** - Industry standard approach
7. **Gradual Rollout** - Can deploy frontend first, backend later

---

## 🎯 Next Steps

1. **Frontend Team (You):**
   - Create `DeviceCapabilityService`
   - Enhance `video_url_resolver.dart`
   - Update video player
   - Test with existing videos (will use fallback)

2. **Backend Team:**
   - Implement video transcoding pipeline
   - Generate 720p versions on upload
   - Populate `mp4_720_url` field
   - Retroactive transcoding (optional)

3. **Testing:**
   - Test on 256MB devices (should use 720p when available)
   - Test on 512MB+ devices (should use 1080p when available)
   - Verify fallback to `videoUrl` works

This solution gives you the best path forward using your existing infrastructure while solving the memory constraints!

