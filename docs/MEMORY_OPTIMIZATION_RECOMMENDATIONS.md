# Memory Optimization Recommendations (TikTok-Aligned)

**Date:** 2026-01-03  
**Status:** App progresses further but crashes during playback due to 256MB heap limit  
**Current Memory Usage:** 255MB/256MB (99.6% full) before playback starts

**Note:** This document aligns recommendations with TikTok's actual memory optimization strategies, adjusted for 256MB heap constraints.

---

## 📱 How TikTok Actually Handles Memory (Reference)

### TikTok's Standard Approach:
1. **Controller Pool:** 2 controllers (current + next preload)
2. **Preloading:** Next video preloaded and ready
3. **Video Resolution:** Adaptive quality (720p for most, 1080p for high-end)
4. **Lazy Loading:** Load metadata in batches (20-30 videos)
5. **Image Optimization:** Compressed thumbnails, cached intelligently

### Our Current Constraints:
- **256MB heap limit** (TikTok typically targets 512MB+ devices)
- **1080p videos** (TikTok uses 720p as standard)
- **Current:** 1 controller (reduced from TikTok's 2 due to memory)

### Goal:
Once memory is optimized, return to TikTok's standard 2-controller approach.

---

## 🎯 Priority 1: Immediate Actions (TikTok-Aligned Quick Wins)

### 1.1 Reduce Initial Video Load Limit ⭐ **HIGHEST IMPACT** (TikTok-Aligned)

**TikTok Approach:** Loads 20-30 videos initially, lazy-loads more on scroll  
**Current:** 50 videos loaded on startup  
**Recommendation:** Reduce to **20-30 videos** (matches TikTok)

**Location:** `lib/services/video_service.dart:80`

**Impact:**
- Reduces memory by ~15-20MB (metadata only)
- Faster initial load (TikTok-style instant feed)
- Matches TikTok's initial batch size

**Implementation:**
```dart
.limit(20); // TikTok-style: 20 videos initial load (matches TikTok's approach)
```

**Note:** This aligns with TikTok's strategy, not a compromise

---

### 1.2 Test on Device with Larger Heap ⭐ **VALIDATION**

**Action:** Test on a device with 512MB+ heap limit

**Why:** Confirms if 256MB is the root cause or if there are other issues

**Command to check heap size:**
```bash
adb shell getprop dalvik.vm.heapsize
```

**Expected:** If app works on larger heap, confirms device limitation

---

### 1.3 Add Graceful OOM Handling ⭐ **USER EXPERIENCE**

**Action:** Catch OutOfMemoryError and show user-friendly message instead of crashing

**Impact:** 
- Prevents app crash
- Shows error: "Device memory too low for video playback"
- Allows user to retry or close app gracefully

**Location:** `lib/widgets/video_player_view_optimized.dart` error handling

---

## 🔧 Priority 2: Medium-term Solutions (1-2 weeks)

### 2.1 Implement True Pagination/Lazy Loading ⭐ **MEMORY EFFICIENCY**

**Current:** Load 50 videos at once  
**Recommendation:** Load 10 videos initially, load more on scroll

**Benefits:**
- Memory usage stays low
- Better user experience (faster initial load)
- Scales to thousands of videos

**Implementation:**
- Use `PageView` with `onPageChanged` callback
- Load next batch when user scrolls near end
- Unload videos far from current position

---

### 2.2 Optimize Image/Thumbnail Loading ⭐ **MEMORY REDUCTION**

**Current:** Full-resolution thumbnails loaded  
**Recommendation:** 
- Use cached_network_image with low-res placeholders
- Limit concurrent image loads (max 5-10 at once)
- Dispose image cache when videos are unloaded

**Impact:** Reduces memory by ~10-20MB

---

### 2.3 Reduce Firestore Listener Overhead

**Action:** Review and optimize active Firestore listeners

**Current Issues:**
- Multiple real-time listeners active simultaneously
- Some listeners might not be properly canceled

**Recommendation:**
- Use one-time reads instead of streams where real-time updates aren't critical
- Implement listener pooling/sharing
- Cancel listeners when not visible

---

## 🚀 Priority 3: Long-term Solutions (TikTok's Primary Strategy)

### 3.1 Lower Video Resolution ⭐ **BIGGEST IMPACT** (TikTok's Standard)

**TikTok's Approach:** 
- **720p (1280x720) is TikTok's standard resolution** for most videos
- 1080p only for high-end devices or specific content
- Adaptive quality based on device capabilities

**Current:** 1080x1920 (Full HD) - **Higher than TikTok's standard!**  
**Recommendation:** 
- **Use 720p as default** (matches TikTok)
- Detect device heap size and request appropriate resolution
- Backend transcodes videos to multiple resolutions (TikTok-style adaptive quality)

**Impact:**
- **720p uses ~50% less memory than 1080p**
- MediaCodec buffers: ~50MB vs ~100MB
- Frame buffers: ~25MB vs ~50MB
- **Total savings: ~75MB per video**
- **Enables TikTok's standard 2-controller approach**

**Implementation:**
- Backend: Transcode to 720p (primary), 480p (fallback), 1080p (premium)
- Client: Detect heap size, request 720p for <512MB devices
- Result: Can return to 2-controller pool (TikTok standard)

**Why This is Priority 3:** Requires backend changes, but is TikTok's PRIMARY memory optimization strategy

---

### 3.2 Video Streaming Instead of Full Download

**Current:** Full video downloaded before playback  
**Recommendation:** Progressive streaming (ExoPlayer supports this natively)

**Impact:**
- Smaller buffer sizes
- Lower peak memory usage
- Better for network conditions

---

### 3.3 Video Compression/Transcoding

**Backend Action:** Re-encode videos with better compression (H.265/HEVC)

**Impact:**
- Smaller file sizes
- Lower memory requirements
- Better quality at same bitrate

---

## 📊 Expected Memory Savings

### Current State:
- App base: ~50MB
- 50 video metadata: ~5MB
- 1 video controller (1080p): ~100MB
- Images/UI: ~50MB
- **Total: ~205MB** (before playback buffers)
- **During playback: ~250-255MB** → **OOM at 256MB**

### With Priority 1 Changes:
- App base: ~50MB
- 20 video metadata: ~2MB
- 1 video controller (1080p): ~100MB
- Images/UI: ~40MB (optimized)
- **Total: ~192MB** (before playback buffers)
- **During playback: ~240-245MB** → **Still risky, but better**

### With Priority 3 Changes (720p - TikTok Standard):
- App base: ~50MB
- 20 video metadata: ~2MB
- **2 video controllers (720p): ~100MB** ⭐ (TikTok's standard 2-controller approach)
- Images/UI: ~40MB
- **Total: ~192MB** (before playback buffers)
- **During playback: ~220-230MB** → **Safe margin below 256MB**
- **Bonus:** Can use TikTok's standard 2-controller preloading for smoother UX

---

## ✅ Recommended Implementation Order (TikTok-Aligned)

1. **Week 1:**
   - ✅ Reduce video limit to 20-30 (TikTok standard)
   - ✅ Add graceful OOM handling
   - ✅ Test on larger-heap device
   - ✅ **Priority:** Start backend 720p transcoding (TikTok's primary strategy)

2. **Week 2:**
   - ✅ Implement pagination/lazy loading (TikTok-style)
   - ✅ Optimize image loading (TikTok-style compression)
   - ✅ Review Firestore listeners
   - ✅ **Priority:** Complete 720p transcoding backend

3. **Week 3-4:**
   - ✅ Client: Detect heap size, request 720p (TikTok-style adaptive quality)
   - ✅ **Restore TikTok's 2-controller pool** (current + next preload)
   - ✅ Test on 256MB devices with 720p
   - ✅ Verify smooth TikTok-like scrolling experience

---

## 🎯 Success Criteria

**Short-term (Priority 1):**
- [ ] App doesn't crash on 256MB devices (with graceful error handling)
- [ ] Memory usage stays below 240MB before playback
- [ ] Users can scroll through 10+ videos without crash

**Medium-term (Priority 2):**
- [ ] Memory usage stays below 200MB
- [ ] Smooth scrolling with lazy loading
- [ ] No memory leaks over extended use

**Long-term (Priority 3):**
- [ ] 720p videos play smoothly on 256MB devices
- [ ] Memory usage stays below 190MB during playback
- [ ] 90%+ of users can use app without memory issues

---

## 🔍 Monitoring

**Add memory monitoring:**
```dart
// In GlobalPlaybackManager
void logMemoryStats() {
  final runtime = Runtime();
  final used = runtime.totalMemory - runtime.freeMemory;
  final max = runtime.maxMemory;
  final percent = (used / max) * 100;
  log('📊 Memory: ${(used / 1024 / 1024).toStringAsFixed(0)}MB / ${(max / 1024 / 1024).toStringAsFixed(0)}MB (${percent.toStringAsFixed(1)}%)');
}
```

**Warning thresholds:**
- ⚠️ Warning at 200MB (78% of 256MB)
- 🔴 Critical at 240MB (94% of 256MB)
- 🚨 OOM risk at 250MB (98% of 256MB)

---

## 📝 Notes

### TikTok Comparison:
- **TikTok's standard:** 720p videos, 2 controllers, 20-30 initial videos
- **Our current:** 1080p videos, 1 controller, 50 initial videos
- **256MB heap is restrictive** - TikTok typically targets 512MB+ devices
- **720p resolution is TikTok's PRIMARY memory optimization** (not a compromise)
- **2-controller pool is TikTok's standard** - we can restore this with 720p

### Key Insight:
**Priority 3 (720p) is not just "a good idea" - it's TikTok's standard approach.** 
- TikTok uses 720p as default, not 1080p
- This enables their 2-controller preloading strategy
- Our 1080p videos are actually **higher quality than TikTok's standard**

### Path Forward:
1. **Short-term:** Reduce to 1 controller + 20 videos (survival mode)
2. **Medium-term:** Implement 720p videos (TikTok standard)
3. **Long-term:** Restore 2-controller pool (TikTok's full approach)

**Bottom Line:** Once we use 720p (TikTok's standard), we can use TikTok's full memory optimization strategy, including 2-controller preloading.

