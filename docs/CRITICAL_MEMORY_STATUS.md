# Critical Memory Status - 256MB Device Limitation

**Date:** 2026-01-03  
**Status:** 🔴 CRITICAL - App still crashing on 256MB devices  
**Root Cause:** 1080p videos exceed 256MB heap limit even with 1 controller

---

## 📊 Current Status

### Memory Usage
- **Heap Limit:** 256MB
- **Current Usage:** 255MB/256MB (99.6% full)
- **Available:** <1MB free
- **Result:** Even tiny allocations (16-104 bytes) fail

### Crash Details
- **Error:** `OutOfMemoryError` in `android.media.ImageReader` (MediaCodec layer)
- **Location:** Native Android video decoding
- **Trigger:** 1080p video playback on 256MB heap device
- **Frequency:** Consistent on video playback

### Current Optimizations (Already Applied)
- ✅ Controller pool size: **1** (no preloading)
- ✅ Preload radius: **0** (disabled)
- ✅ Video load limit: **15** (reduced from 20)
- ✅ OOM error handling: **Enabled**
- ✅ Graceful degradation: **Implemented**

---

## 🚨 Critical Finding

**Even with all optimizations, 1080p videos are too large for 256MB heap devices.**

The device cannot allocate memory for video frame buffers even with:
- Only 1 video controller active
- No preloading
- Reduced video list (15 videos)
- Aggressive memory management

---

## ✅ Solution: Backend Video Quality Reduction (REQUIRED)

**The ONLY solution that will work is reducing video resolution on the backend.**

### Required Backend Changes

1. **Generate 720p versions** when videos are uploaded
2. **Populate `mp4_720_url` field** in Firestore
3. **Frontend will automatically use 720p** on low-memory devices

### Expected Impact

**720p videos use ~50% less memory than 1080p:**
- 1080p: ~150MB per video buffer
- 720p: ~75MB per video buffer
- **Result:** 256MB devices can play 720p videos safely

---

## 🔧 Frontend Status

### Device-Aware Quality Selection (✅ COMPLETE)

The frontend is **ready** for multi-resolution videos:

1. ✅ **DeviceCapabilityService** - Detects heap size, recommends resolution
2. ✅ **Enhanced video_url_resolver** - Selects 720p on low-memory devices
3. ✅ **VideoPlayerViewOptimized** - Uses device-aware resolution selection

### How It Works

```dart
// DeviceCapabilityService detects 256MB heap
// Recommends: '720'

// video_url_resolver tries mp4_720_url first
final url = await resolveVideoUrlWithQuality(data);
// Returns: mp4_720_url if available, falls back to videoUrl

// VideoPlayerViewOptimized uses the selected URL
```

### Current Behavior

- **With `mp4_720_url` field:** Uses 720p on 256MB devices ✅
- **Without `mp4_720_url` field:** Falls back to 1080p (`videoUrl`) ❌

---

## 📋 Backend Action Items

### Priority 1: Video Transcoding Pipeline

1. **On Upload:**
   - Accept 1080p original video
   - Generate 720p version (transcoding)
   - Store both in Firebase Storage
   - Update Firestore with both URLs:
     ```javascript
     {
       videoUrl: "gs://bucket/video_1080p.mp4", // Legacy (1080p)
       mp4_1080_url: "gs://bucket/video_1080p.mp4", // Optional
       mp4_720_url: "gs://bucket/video_720p.mp4", // REQUIRED
       mp4_480_url: "gs://bucket/video_480p.mp4", // Optional (future)
     }
     ```

2. **Transcoding Options:**
   - **Cloud Functions:** Trigger on video upload
   - **FFmpeg:** Standard video transcoding
   - **Firebase Extensions:** Video transcoding extensions
   - **External Service:** Mux, Cloudflare Stream, etc.

### Priority 2: Retroactive Transcoding (Optional)

- Transcode existing videos to 720p
- Update Firestore documents with `mp4_720_url`
- Batch processing for large catalogs

---

## 🎯 Expected Outcomes

### Before Backend Changes:
- ❌ App crashes on 256MB devices
- ❌ Heap usage: 255MB/256MB (99.6%)
- ❌ Even tiny allocations fail

### After Backend Changes:
- ✅ App runs smoothly on 256MB devices
- ✅ Heap usage: ~150MB/256MB (58%)
- ✅ 720p videos use 50% less memory
- ✅ 2-controller preloading becomes possible
- ✅ Better performance overall

---

## 📝 Testing Checklist

Once backend provides `mp4_720_url`:

- [ ] Verify device-aware selection on 256MB device
- [ ] Confirm 720p URL is selected
- [ ] Test video playback (should not crash)
- [ ] Monitor heap usage (should be ~150MB)
- [ ] Test on 512MB+ devices (should use 1080p)
- [ ] Verify fallback to `videoUrl` still works

---

## ⚠️ Current Limitations

Until backend provides 720p videos:

1. **App will continue crashing** on 256MB devices
2. **No frontend-only fix possible** - video resolution is the bottleneck
3. **All optimizations applied** - controller pool, preloading, load limits
4. **Backend change required** - transcoding pipeline is the only solution

---

## 🔗 Related Documents

- `docs/BEST_SOLUTION_VIDEO_QUALITY.md` - Implementation guide
- `docs/MEMORY_OPTIMIZATION_RECOMMENDATIONS.md` - Optimization strategies
- `docs/HOMEVIEW_CRASH_ANALYSIS.md` - Historical crash analysis

---

**Status:** Waiting on backend video transcoding pipeline implementation.

