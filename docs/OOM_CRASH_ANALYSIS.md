# OutOfMemoryError Crash Analysis

## Crash Details

**Error:** `OutOfMemoryError: Failed to allocate a 40 byte allocation with 77552 free bytes and 75KB until OOM`

**Thread:** `MediaCodec_loop` (tid: 794)

**Location:** Native MediaCodec layer (`/system/lib64/libmedia_jni.so`)

**Heap Status:** `<1% of heap free after GC` - heap is completely exhausted (268MB limit reached)

## Root Cause

**Memory Exhaustion from Too Many Video Controllers**

Recent changes increased memory pressure:
1. **`poolRadius` increased from 2 → 4** (preload 4 videos ahead)
2. **`maxControllerPoolSize` increased from 3 → 5** (allow 5 controllers)
3. **`preloadAround()` now waits for current video** (more controllers initialized simultaneously)

**Problem:** Video controllers are memory-intensive:
- Each controller holds decoded video buffers
- MediaCodec surfaces consume significant memory
- 5 controllers × ~50-80MB each = 250-400MB (exceeds 268MB heap limit)

## Why TikTok Doesn't Crash

TikTok's memory strategy:
1. **Very aggressive disposal** - Dispose controllers immediately when off-screen
2. **Smaller pool** - Only keep 2-3 controllers max
3. **Lazy initialization** - Don't initialize until video is actually visible
4. **Immediate cleanup** - Dispose controllers when user swipes away

## Fix Strategy

### Option 1: Reduce Pool Size (Immediate Fix) ✅ RECOMMENDED

**Change:**
- `poolRadius`: 4 → **2** (preload 2 videos ahead, not 4)
- `maxControllerPoolSize`: 5 → **3** (keep 3 controllers max)

**Rationale:**
- 3 controllers × 60MB = ~180MB (within 268MB limit)
- 2 videos ahead is still enough for smooth playback
- TikTok-style apps typically use 2-3 controllers max

### Option 2: More Aggressive Disposal (Complementary Fix)

**Change:**
- Dispose controllers immediately when they're more than 1 position away
- Reduce cooldown period from 3s → 1s
- Dispose controllers even if they're in cooldown if memory is tight

### Option 3: Reduce Preload Window (Trade-off)

**Change:**
- `poolRadius`: 4 → **1** (only preload next video)
- `maxControllerPoolSize`: 5 → **2** (only current + next)

**Trade-off:**
- Less memory usage (safe)
- Slightly more black screens when swiping rapidly
- Still better than current crash

## Recommended Fix

**Immediate:** Reduce pool size to prevent crashes
- `poolRadius: 2`
- `maxControllerPoolSize: 3`

**Next:** Optimize disposal to be more aggressive
- Reduce cooldown period
- Dispose controllers more quickly when off-screen

