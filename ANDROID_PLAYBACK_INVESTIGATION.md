# Android Playback Investigation Guide

**Priority:** 🔴 **CRITICAL** - Blocks Android store submission  
**Status:** 📋 **Ready to Execute**  
**Estimated Time:** 1-2 days for investigation + decision

---

## Background

**Current Issue:**
- MediaCodec `BAD_INDEX` errors on some Android devices
- Documented in `docs/PRODUCTION_READINESS_SCORECARD.md:9-12,58-63`
- First-frame timing issues
- Surface management churn

**Impact:**
- Blocks Android Play Store submission quality requirements
- May affect user experience on specific device/OS combinations
- Critical for production launch

---

## Investigation Goals

1. **Identify affected devices** - Which models/OS versions have issues?
2. **Document specific errors** - Exact error messages and stack traces
3. **Measure severity** - How many users affected? Crash or degraded UX?
4. **Evaluate fixes** - Can we fix existing code or need Media3 migration?
5. **Make decision** - Fix vs migrate with timeline estimate

---

## Step 1: Build Release APK with R8

### Build Command
```bash
cd /workspace

# Build release APK with all production optimizations
./scripts/build_store_release.sh

# Or manual build:
flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/app/outputs/symbols \
  --dart-define=SITE_API_BASE=https://streamerstip.com

# Output location:
# build/app/outputs/flutter-apk/app-release.apk
```

### Verify Build Success
```bash
# Check APK was created
ls -lh build/app/outputs/flutter-apk/app-release.apk

# Check R8 was enabled
cat scripts/build_store_release.sh | grep -i r8
# Should show: R8_STATUS=ENABLED

# Check ProGuard rules applied
cat android/app/build.gradle.kts | grep -i minify
# Should show: isMinifyEnabled = true
```

---

## Step 2: Test Device Matrix

### Required Test Devices

| Priority | Device | OS Version | Notes |
|---|---|---|---|
| **HIGH** | Samsung Galaxy S21/S22 | Android 12+ | Popular, known issues |
| **HIGH** | Google Pixel 6/7 | Android 13+ | Reference device |
| **HIGH** | OnePlus 9/10 | Android 12+ | Common user base |
| **MEDIUM** | Xiaomi Mi 11 | Android 11+ | Large market |
| **MEDIUM** | Samsung Galaxy A52 | Android 11+ | Mid-range popular |
| **MEDIUM** | Older device | Android 10 | Minimum support check |

### If You Don't Have Physical Devices

**Option A: Firebase Test Lab**
```bash
# Upload APK to Firebase Test Lab
gcloud firebase test android run \
  --type robo \
  --app build/app/outputs/flutter-apk/app-release.apk \
  --device model=Pixel6,version=33,locale=en,orientation=portrait \
  --device model=Galaxy21,version=31,locale=en,orientation=portrait \
  --timeout 10m
```

**Option B: BrowserStack / Sauce Labs**
- Upload APK to cloud testing service
- Run on multiple devices
- Record sessions for analysis

**Option C: Emulators (Less reliable)**
```bash
# Create AVDs with different configs
flutter emulators --launch <emulator-id>

# Note: Emulators may not reproduce hardware-specific issues
```

---

## Step 3: Test Scenarios

For **each device**, test these scenarios:

### Scenario A: Feed Scrolling
```
1. Open app
2. Navigate to home feed
3. Let video autoplay
4. Scroll through 10+ videos
5. Note:
   - First frame timing (immediate or delayed?)
   - Audio bleeding between videos?
   - Crashes or errors?
   - Frame drops or stuttering?
```

### Scenario B: Video Player
```
1. Open specific video
2. Play, pause, seek
3. Navigate away, come back
4. Test 5+ different videos
5. Note:
   - Seek accuracy
   - Pause/resume behavior
   - Memory usage over time
   - Audio sync issues?
```

### Scenario C: Background/Foreground
```
1. Play video
2. Switch to another app (home button)
3. Return to app
4. Note:
   - Does playback resume?
   - Audio state correct?
   - Crashes on resume?
```

### Scenario D: Network Interruption
```
1. Play video
2. Toggle airplane mode
3. Restore connection
4. Note:
   - Error handling
   - Recovery behavior
   - User messaging
```

### Scenario E: Long Session
```
1. Use app for 15+ minutes
2. Watch multiple videos
3. Navigate between screens
4. Note:
   - Memory leaks?
   - Progressive degradation?
   - Eventual crashes?
```

---

## Step 4: Capture Error Data

### Use ADB to Capture Logs

```bash
# Connect device via USB with debugging enabled
adb devices

# Clear logcat
adb logcat -c

# Start capturing logs
adb logcat | grep -E "MediaCodec|ExoPlayer|VideoPlayer|BAD_INDEX|ERROR" > android_playback_errors.log

# Run test scenarios (leave this terminal running)
# Errors will be written to android_playback_errors.log

# After testing, stop capture (Ctrl+C)
```

### Key Error Patterns to Look For

**MediaCodec BAD_INDEX:**
```
E/MediaCodec: codec_process: Codec returned bad status: -1
E/MediaCodec: android.media.MediaCodec$CodecException: BAD_INDEX
```

**Surface Issues:**
```
E/Surface: getSlotFromBufferLocked: unknown buffer
E/BufferQueue: dequeueBuffer: no available buffers
```

**ExoPlayer Errors:**
```
E/ExoPlayerImpl: Playback error
  com.google.android.exoplayer2.ExoPlaybackException
```

**Frame Timing:**
```
I/Choreographer: Skipped X frames! Application may be doing too much work
```

### Collect Device Information

For each error, capture:
```bash
# Device info
adb shell getprop ro.product.model
adb shell getprop ro.build.version.release
adb shell getprop ro.product.manufacturer

# Memory info
adb shell dumpsys meminfo com.streamerstip.app

# CPU info
adb shell top -n 1 | grep streamerstip
```

---

## Step 5: Organize Findings

### Create Investigation Report

Use this template:

```markdown
# Android Playback Investigation Results

**Date:** [Today's date]
**Build:** 1.0.1+2026100401
**R8 Enabled:** Yes
**Tested Devices:** [Count]

## Summary
- Devices Tested: X
- Devices with Issues: Y
- Severity: [Critical/Major/Minor]
- Recommendation: [Fix existing/Migrate to Media3]

## Device Results

### Device 1: [Model]
- **OS Version:** Android X
- **Issues Found:** [Yes/No]
- **Error Type:** [MediaCodec BAD_INDEX / Surface issues / etc]
- **Frequency:** [Always/Sometimes/Rare]
- **User Impact:** [Crash/Degraded/Cosmetic]
- **Logs:** See android_playback_errors_device1.log

### Device 2: [Model]
[Repeat for each device]

## Error Analysis

### Most Common Error
[Describe most frequent issue]
- Frequency: X% of devices
- Severity: [Scale 1-10]
- User Impact: [Description]

### Code Location
[Point to relevant files]
- lib/widgets/video_player_view_optimized.dart
- lib/coordinators/[specific coordinator]
- Related: [other files]

## Root Cause Hypothesis
[Your analysis of why this is happening]

## Recommended Solution

### Option A: Fix Existing Code
- **Pros:** Faster, focused changes
- **Cons:** May not fix all edge cases
- **Estimated Time:** X days
- **Approach:** [Specific fixes to implement]

### Option B: Migrate to Media3
- **Pros:** Modern API, better support, future-proof
- **Cons:** More work, testing required
- **Estimated Time:** Y weeks
- **Approach:** [Migration plan]

### Recommendation
[Your choice with justification]

## Next Steps
1. [Action item 1]
2. [Action item 2]
3. [Action item 3]
```

---

## Step 6: Decision Matrix

Use this to decide between Fix vs Migrate:

| Factor | Fix Existing | Migrate to Media3 | Winner |
|---|---|---|---|
| **Time to Complete** | 3-5 days | 2-3 weeks | Fix |
| **Future Maintenance** | Ongoing issues | Better support | Media3 |
| **Risk of Regression** | Medium | High (big change) | Fix |
| **Device Coverage** | May have gaps | Better coverage | Media3 |
| **Code Quality** | Incremental | Clean slate | Media3 |
| **Testing Effort** | Focused | Comprehensive | Fix |
| **API Stability** | Deprecated APIs | Modern | Media3 |

### Decision Guidelines

**Choose Fix Existing if:**
- ✅ Errors affect <20% of devices
- ✅ Errors are fixable with targeted changes
- ✅ Need to launch quickly (within 2 weeks)
- ✅ Team is small / limited bandwidth

**Choose Media3 Migration if:**
- ✅ Errors affect >30% of devices
- ✅ Root cause is fundamental architecture issue
- ✅ Can allocate 2-3 weeks for migration
- ✅ Want long-term stability and support

**Need More Investigation if:**
- ⚠️ Error patterns unclear
- ⚠️ Can't reproduce consistently
- ⚠️ Multiple unrelated issues
- ⚠️ Performance acceptable but not optimal

---

## Step 7: Implementation Plan (After Decision)

### If Fixing Existing Code

```markdown
## Fix Plan

### Priority 1 - Critical Fixes
- [ ] Fix MediaCodec BAD_INDEX in [specific location]
- [ ] Fix surface management in [specific location]
- [ ] Add error recovery in [specific location]

### Priority 2 - Improvements
- [ ] Better error handling
- [ ] Improved first-frame timing
- [ ] Memory leak prevention

### Testing
- [ ] Test on all devices that previously failed
- [ ] Regression test on working devices
- [ ] Performance benchmarks

### Timeline
- Day 1: Implement fixes
- Day 2: Test on device matrix
- Day 3: Refinements + QA
- Day 4: Release candidate testing
```

### If Migrating to Media3

```markdown
## Migration Plan

### Phase 1 - Preparation (3 days)
- [ ] Add Media3 dependencies to pubspec.yaml
- [ ] Research Media3 API and examples
- [ ] Create migration strategy document
- [ ] Set up parallel implementation (keep old code)

### Phase 2 - Core Migration (5 days)
- [ ] Implement Media3 ExoPlayer wrapper
- [ ] Migrate video_player_view_optimized.dart
- [ ] Migrate playback coordinators
- [ ] Update video service integration

### Phase 3 - Testing (4 days)
- [ ] Unit tests for new implementation
- [ ] Integration tests
- [ ] Device matrix testing
- [ ] Performance benchmarks

### Phase 4 - Rollout (2 days)
- [ ] Feature flag implementation
- [ ] Gradual rollout (10% → 50% → 100%)
- [ ] Monitor Crashlytics
- [ ] Remove old implementation

### Timeline
- Week 1: Preparation + Core Migration (8 days)
- Week 2: Testing + Rollout (6 days)
- Total: ~2-3 weeks
```

---

## Resources

### Documentation
- `docs/PRODUCTION_READINESS_SCORECARD.md` - Current known issues
- `docs/CODE_REFACTORING_PLAN.md` - Video player refactoring plan
- `lib/widgets/video_player_view_optimized.dart` - Current implementation

### Testing
- Firebase Test Lab: https://console.firebase.google.com/project/streamerstip-6cfdb/testlab
- Android Logs: `adb logcat`
- Performance Profiling: `flutter run --profile`

### Media3 Migration (if chosen)
- Media3 Overview: https://developer.android.com/guide/topics/media/media3
- ExoPlayer Migration: https://developer.android.com/guide/topics/media/media3/getting-started/migration-guide
- Flutter Media3 Plugin: https://pub.dev/packages/video_player (check for Media3 support)

---

## Deliverables

After investigation, you should have:

1. ✅ **Investigation Report** (markdown file with findings)
2. ✅ **Error Logs** (from each device)
3. ✅ **Device Matrix Results** (which work, which fail)
4. ✅ **Decision Document** (fix vs migrate with justification)
5. ✅ **Implementation Plan** (detailed timeline and tasks)

---

## Success Criteria

Investigation is complete when:

- ✅ Tested on 5+ device models
- ✅ Documented all errors with logs
- ✅ Clear recommendation made (fix vs migrate)
- ✅ Implementation plan created with timeline
- ✅ Stakeholders informed of approach

---

**Start Investigation:**
```bash
# 1. Build release APK
./scripts/build_store_release.sh

# 2. Install on test devices
adb install build/app/outputs/flutter-apk/app-release.apk

# 3. Start log capture
adb logcat | grep -E "MediaCodec|ExoPlayer|ERROR" > playback_errors.log

# 4. Run test scenarios
# (Use app normally, note issues)

# 5. Analyze logs and document findings
```

---

**Next:** After investigation, create `ANDROID_PLAYBACK_DECISION.md` with your recommendation.
