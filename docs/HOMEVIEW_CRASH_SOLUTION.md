# ✅ Cursor Solution: HomeView Crash + TikTok-Style Playback Memory Management

## Objective

Stop HomeView crashes during upload + rapid swiping by enforcing TikTok-style controller lifecycle:

- Only 1 active controller playing
- Only 1 controller preloaded (next)
- Zero duplicate video loads
- Controllers never exceed pool limit
- Controllers cannot be disposed mid-initialization
- Feed list must be deduped by videoId to avoid double controllers + playback errors

---

## 1) Single Source of Truth: Load Videos Once (No Duplicate Boot)

### Rule
`loadAllVideos()` must be called from one place only.

### ✅ Correct:
- `HomeProvider.loadVideos()` (only)

### ❌ Remove:
- Any `HomeView._initializeVideoService()` that also loads videos
- Any post-frame load that duplicates provider initialization

### Implementation Requirement
- `HomeView` should request `provider.loadVideos()` once.
- `VideoService` should be a pure service: no auto-load from UI.

---

## 2) Feed Must Deduplicate Video IDs Before Rendering

Duplicate cards = duplicate controllers = playback errors + OOM spikes.

### Requirement
Before building the feed list, ensure:
- No duplicate `videoId` exists in the final `List<Video>`

### Rule
If merging multiple queries or applying fallback, run a final pass:
```dart
uniqueBy(videoId)
```

This prevents:
- "same video appears twice"
- player attaching twice to same resource
- memory spikes on init

---

## 3) Hard Controller Pool Policy (TikTok Model)

### Max Controllers Allowed: 2
- `activeIndex` controller (current)
- `activeIndex + 1` controller (next preload)

**No "+2", no "previous preload", no extras.**

### Required Behavior
When active index changes:
1. Pause old active controller
2. Ensure current controller exists + plays
3. Ensure next controller exists (preloaded, paused)
4. Dispose everything else immediately

### Non-Negotiable Invariant
`_controllerPool.length` must never exceed 2 after any operation completes.

---

## 4) Fix the Race Condition: Guard Async Initialization

### The Crash Path
Happens when:
1. Controller A is initializing async
2. User swipes
3. Disposal runs and kills A mid-init
4. Then init completes and tries to use disposed controller → fatal

### Required Mechanism
Maintain:
- `_initializingControllers: Set<videoId>`
- `_initTokenPerVideo: Map<videoId, int>` OR global generation

### Rules
- If a controller is initializing, it cannot be disposed.
- If `activeIndex` changes during `await`, abort remaining work.

### Acceptance Criteria
- No "controller used after disposed"
- No controllers disposed while in `_initializingControllers`

---

## 5) Enforce Pool Size Immediately (No Deferred Cleanup)

**Do not "cleanup later".**

### Requirement
Every function that can add a controller must also enforce limits:
- `registerController()`
- `preloadAround()`
- `ensureControllerReady()`

### Rule
If pool > 2:
1. Dispose oldest non-active immediately
2. Repeat until pool == 2

**Also:** Never dispose active video's controller.

---

## 6) Reduce Feed Load Limits for Mobile Reality

Loading 500–1000 is not mobile-safe and increases controller churn.

### Defaults
- Initial page: 25–50
- Pagination: 10–20
- Fallback: ≤100

### Also Required
Do not preload controllers based on list size — only based on active index.

---

## 7) Add Memory Pressure Cleanup Hooks (Android)

Android will warn before it kills you. Use it.

### When App Hits Memory Pressure
1. Dispose the "next preload" controller first
2. Keep only the active controller
3. Rebuild preload after idle

This gives a safety valve before OOM.

---

## 8) Layout Fix to Prevent Covered Top Row (Header Overlay)

Separate issue but contributes to broken taps / perception:

### Requirement
Feed grid must start below header stack:
- `AppHeader` + `FeedSelector` + `Stories` row

### Use:
- `SafeArea` + `paddingTop`
- OR `SliverAppBar` pinned + proper body start

**Do NOT** let feed render under `Following`/`Discover` tabs.

---

## ✅ Implementation Checklist (Cursor)

- [ ] Ensure videos load from `HomeProvider` only (remove duplicate init calls)
- [ ] Deduplicate feed list by `videoId` before rendering
- [ ] Limit controller pool to 2 (current + next only)
- [ ] Add `_initializingControllers` guard + index change abort logic
- [ ] Enforce pool size immediately in every controller-add path
- [ ] Reduce initial Firestore limits (50 max) and paginate
- [ ] Add memory pressure cleanup hook (dispose preload, keep active)
- [ ] Fix feed top padding so header doesn't cover first row

---

## ✅ Definition of Done

- [ ] Rapid swiping through 30+ videos does not crash
- [ ] Pool never exceeds 2 controllers
- [ ] No duplicate video tiles
- [ ] No "used after disposed" logs
- [ ] Memory stays comfortably below heap limit
- [ ] Feed content is never hidden under nav header

---

## 📝 Notes

This solution implements a strict TikTok-style memory management model where:
- Only the current video and the next video have controllers
- All other controllers are immediately disposed
- Initialization is protected from race conditions
- Video loading is centralized to prevent duplicates
- Feed lists are deduplicated before rendering

This approach minimizes memory usage while maintaining smooth playback during rapid swiping.

