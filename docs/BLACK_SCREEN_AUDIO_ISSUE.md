# Black Screen with Audio Playing - Critical Issue

## Problem
User reports: **"black screen for 2 mins now its a blackscreen playing the audio"**

Audio is playing but video frames are not rendering - this is the classic "audio but no frames" issue.

## Potential Root Causes

### 1. VideoPlayer Widget Size Issue (Most Likely) ⚠️

**Location:** `lib/widgets/video_player_view_optimized.dart:3504-3506`

```dart
width: v.size.width > 0 ? v.size.width : 1,
height: v.size.height > 0 ? v.size.height : 1,
```

**Problem:**
- If `v.size.width` or `v.size.height` is 0, VideoPlayer is rendered at 1×1 pixels
- FittedBox with BoxFit.cover might not expand a 1×1 widget correctly
- VideoPlayer widget exists but is essentially invisible

**Fix:** Use `SizedBox.expand()` when size is unknown, not 1×1 fallback

### 2. Pool Controller Mismatch Check (Secondary)

**Location:** `lib/widgets/video_player_view_optimized.dart:3467-3476`

**Problem:**
- Check compares pool controller with local controller
- If mismatch, returns black screen
- But controller might still be valid and playing audio

**Fix:** Remove or make this check less strict - if controller exists and is safe, render it

### 3. Surface/MediaCodec BAD_INDEX (From Previous Logs)

**Problem:**
- Surface texture not attaching correctly
- VideoPlayer widget renders but no frames appear
- Audio plays because it's separate from video rendering

**Fix:** Already addressed in Task #6, but may need surface recreation watchdog

## Immediate Fix

**Change VideoPlayer size handling:**

```dart
// OLD (WRONG):
child: SizedBox(
  width: v.size.width > 0 ? v.size.width : 1,
  height: v.size.height > 0 ? v.size.height : 1,
  child: VideoPlayer(controller, ...),
),

// NEW (CORRECT):
child: v.size.width > 0 && v.size.height > 0
  ? SizedBox(
      width: v.size.width,
      height: v.size.height,
      child: VideoPlayer(controller, ...),
    )
  : SizedBox.expand(
      child: VideoPlayer(controller, ...),
    ),
```

**Why:**
- `SizedBox.expand()` fills available space when size is unknown
- Prevents 1×1 invisible VideoPlayer
- VideoPlayer can render frames even if size isn't known yet

