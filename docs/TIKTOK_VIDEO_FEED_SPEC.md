# TikTok-Style Video Feed – Technical Spec for AI Assistants

**Goal:** A vertical, full-screen video feed that behaves like TikTok: exactly one video plays at a time, smooth swipe to next/previous, no audio bleed, no freeze, and all videos (not just the first) play when they become the current item.

**Related:** For upload, rendering, playback URL resolution, and status rules (ready/published, never play original), see `docs/STREAMERSTIP_CURSOR_HANDOFF.md` (Section 15: Mobile Flutter alignment).

---

## Update (fixed): Not seeing all uploaded videos

**Problem:** The app feed was not showing all videos uploaded on the website; newer uploads were missing and older videos appeared instead.

**Cause:** Feed queried only `status == 'published'`, ordered by `createdAt`, and limited to 50. New pipeline videos use `status == 'ready'` and are “new” by `updatedAt` when they become ready, so they were excluded or sorted incorrectly.

**Fix:** Feed now includes both `published` and `ready`, orders by `updatedAt` (with in-memory sort by `updatedAt ?? createdAt`), and uses limit 100. See **Section 9** for details. Backend must set `updatedAt` when a video goes ready/published.

---

## On-track summary (at a glance)

| Area | Status | Notes |
|------|--------|--------|
| **Feed playback** | 🟡 Phase 1 applied | Controller creation unified (getOrCreateController only, mixWithOthers: false). onVisibleIndexChanged pre-creates controller. Concurrent init guard added. |
| **Data / profile videos** | ✅ Aligned | Canonical owner via **getOwnerId**; VideoService and RealUserDataService use same resolution. Profile “0 then 2” fixed. Optional: backfill **ownerId** (and **videoUrl** / **thumbnailUrl**) in Firestore. |
| **Feed visibility** | ✅ Fixed | Newer uploaded videos were missing: query only had `status == 'published'` and `orderBy('createdAt')`. Now **status** includes `ready`, **orderBy** uses `updatedAt` (then fallbacks), **in-memory sort** by `updatedAt ?? createdAt`, **limit** 100. See section 9. |
| **Architecture** | ✅ Documented | GlobalPlaybackManager, VideoPlayerViewOptimized, HomeView, VideoPageViewWidget; invariants and flows in sections 1–4. |

**Current symptom:** **Only the first video plays.** Second and later videos do not start playback when the user scrolls to them. This persists after the “Level 1” fixes below.

**Fixed (feed visibility):** We were not seeing all the videos uploaded on the website; newer uploads were missing. Fixed by including status `ready`, ordering by `updatedAt`, in-memory sort, and limit 100—see **Section 9** and the "Update (fixed)" block above.

---

## What Was Fixed (Level 1) and Why It May Still Fail

### Changes made

1. **`_tryAdoptFromPool` (VideoPlayerViewOptimized)**  
   - **Before:** Only adopted if `identical(existing, _currentControllerInstance)`, so with null instance adoption never ran; each view always created its own controller.  
   - **After:** Adopts whenever the pool has a safe controller for this `videoId`. If the view had a different or null controller, it now replaces with the pooled one, attaches listeners, and calls `markControllerAttached`.  
   - **Intent:** So video 2+ can use the preloaded controller and stay in sync with the pool; focus is requested for the same instance the manager has.

2. **`_attemptRequestFocus` (VideoPlayerViewOptimized)**  
   - **Before:** Required `getController(videoId)` to be identical to `_currentControllerInstance`; otherwise it bailed and never requested focus.  
   - **After:** If the pool has no controller → `setDesiredFocus(videoId, _ownerKey)` (queue focus). If the view has no controller or a different one than the pool → `_tryAdoptFromPool(reason: 'attemptRequestFocus')`. Then request focus with existing throttles.  
   - **Intent:** So when video 2 becomes current we always either adopt then request focus, or queue focus for when the controller registers.

3. **`requestFocus` (GlobalPlaybackManager)**  
   - **Before:** If controller was null/unsafe, it logged and returned; nothing guaranteed a retry.  
   - **After:** If controller is null or unsafe → `_pendingFocusRequests[videoId] = owner` and return. Focus is applied later when the controller is registered via `_applyPendingFocusIfExists`.  
   - **Intent:** So “controller not ready yet” does not drop focus forever.

4. **`switchActiveTo` (GlobalPlaybackManager)**  
   - **Epoch:** Uses `myEpoch = ++_activationEpoch`. After `_muteAllExcept`, after the 80 ms delay, and in the “already active” path, it aborts if `myEpoch != _activationEpoch` and logs `GPM switch abort ... (stale after ...)`.  
   - **Missing controller at entry:** If controller is null/unsafe → `_pendingFocusRequests[newVideoId] = owner` and return.  
   - **Intent:** So a newer swipe cannot be overridden by an older switch completing after the 80 ms delay.

5. **Pool size**  
   - `maxControllerPoolSize` changed from 2 to 3 (prev/current/next).

6. **Diagnostic logs**  
   - **VVIEW:** `current=TRUE id=... controller=null|pool|local`, `adopt id=... pooledHash=...`, `init-start id=...`, `register id=... hash=...`, `focus id=... reason=...`.  
   - **GPM:** `focus id=...`, `focus-queued id=...`, `focus-apply id=... owner=...`, `switch start/end/abort id=... epoch=...`.

7. **Eviction fallback in registerController (GlobalPlaybackManager)**  
   - **Before:** When the pool was full and the main eviction loop found no eligible victims, a fallback used `_controllerPool.keys.first` as the victim. That ignored **attached** and **TTL** (`disposalEligibilityTtlSeconds`), so the current page’s controller (e.g. video 2) could be unregistered and removed from the pool right after the view adopted or registered it.  
   - **After:** The fallback now picks a victim using the same rules as the main loop: not active, not initializing, **not attached** (`_attachedControllers[id] == entry.value.hashCode`), and past TTL. At most one such victim is added; eviction behavior is unchanged for controllers that are actually eligible.  
   - **Intent:** Avoid evicting the controller for the video that just became current (which would leave the second video without a pool entry and prevent focus/playback).

### Why the problem may still occur

- **Adoption runs but pool is empty for video 2**  
  When video 2 becomes current, `_tryAdoptFromPool` runs first. If `preloadAround` has not yet created or registered a controller for video 2 (or it was evicted), `getController(widget.video.id)` is null, adoption returns false, and the view calls `_initializeVideo()`. That creates a new controller asynchronously. Meanwhile `_attemptRequestFocus` may run with pool still null → it queues focus and returns. When the view’s controller finally registers, `_applyPendingFocusIfExists` should run — but if registration replaces a preloaded controller or triggers eviction, the timing/order of “register → apply pending → switchActiveTo” might still leave the second video without focus or with the wrong controller.

- **View creates its own controller and replaces the pool’s**  
  Preload may register controller A for video 2. The view for video 2 might not adopt (e.g. it builds before preload finishes, or adoption fails due to `hasError`). The view then creates controller B and calls `registerController(video2, B)`. The manager replaces A with B (or unregisters A if “attached”). So the pool has B. Pending focus, if any, is applied to B. So far so good — but if `_applyPendingFocusIfExists` runs before the view has called `markControllerAttached(B)`, or if eviction logic runs in between and removes B (e.g. pool size and “attached” checks), focus could be applied to a controller that is then removed or never rendered.

- **Epoch abort**  
  If two focus requests run close together (e.g. setDesiredFocus for video 2 and then something triggers another switch or pauseAll), the first `switchActiveTo` may pass the 80 ms delay but then the second increments `_activationEpoch`, so the first completes and sets `_activeVideoId` and `_currentlyPlayingController`, but the second aborts. Depending on order, we might end up with the wrong video “active” or with no unmute for the second video.

- **didUpdateWidget order / initState vs didUpdateWidget**  
  For video 2, the widget may get `isCurrentVideo: true` in `didUpdateWidget` and run `_tryAdoptFromPool` then `_initializeVideo`. If adoption succeeds, we have a controller and then `_attemptRequestFocus`. But `_attemptRequestFocus` is also called from the “isCurrentVideo became true” block later in `didUpdateWidget`. If the first call queues focus (pool was null at that moment) and the second call runs after adoption and actually requests focus, we could have duplicate or out-of-order focus. Throttling (`_hasRequestedFocus` / `_lastRequestedVideoId`) may prevent duplicate requestFocus, but if the first attempt only queued (returned false), the second attempt might then adopt and request — so the flow may depend on exact order of “adoption completes” vs “attemptRequestFocus runs again”.

- **Eviction removes video 2’s controller before focus**  
  With pool size 3, when we have controllers for indices 0, 1, 2 and the user is on index 1, we might evict index 0. When the user swipes to index 2, the controller for index 2 might already be in the pool. The **fallback eviction** in `registerController` was fixed (Level 1 item 7): it no longer picks `keys.first` regardless of attached/TTL; it now uses the same eligibility rules as the main loop. If eviction still incorrectly removes the current index’s controller, the cause would be elsewhere (e.g. wrong “attached” or “active” checks in the main loop).

- **First video works because** its controller is created and registered in the same flow (HomeView preload + setDesiredFocus, then view initState → init or adopt → register → apply pending or requestFocus). For video 2, the same flow is spread across scroll, didUpdateWidget, and async init; any gap (pool empty, replace during register, epoch abort, eviction) can leave the second video without a successful `switchActiveTo` + `_ensurePlayingUnmuted`.

**Next steps for an AI:** Use the VVIEW/GPM logs from a single run (open feed, swipe to second video) to see exactly where the flow stops: e.g. “VVIEW current=TRUE … controller=null” then “VVIEW init-start” then “VVIEW register” then “GPM focus-apply” then “GPM switch start” then “GPM switch abort” or “GPM switch end”. That will show whether the failure is: no adoption (pool empty), no register, no focus-apply, or switch aborted / controller missing after delay.

---

## 1. Architecture Overview

### 1.1 Components

| Component | File | Role |
|-----------|------|------|
| **GlobalPlaybackManager** | `lib/services/global_playback_manager.dart` | Singleton. Single source of truth: which video is “active”, pool of controllers, mute/pause all others, request focus for one video. |
| **VideoPlayerViewOptimized** | `lib/widgets/video_player_view_optimized.dart` | Per-video widget. Creates or adopts a `VideoPlayerController`, registers it with the manager, requests focus when `isCurrentVideo` becomes true. |
| **HomeView** | `lib/pages/home_view.dart` | Feed container. Loads videos, calls `preloadAround(0, videos)` and `setDesiredFocus(firstVideo.id, ownerId)`. |
| **VideoPageViewWidget** | `lib/widgets/home_view_components/video_page_view_widget.dart` | PageView of videos. Passes `isCurrentVideo: index == widget.currentIndex` and notifies `onPageChanged` / `onVisibleIndexChanged`. |

### 1.2 Invariants (Target Behavior)

1. **Exactly one video plays at a time** – only `_activeVideoId`’s controller should have volume > 0 and be playing.
2. **Only the “current” page has focus** – `isCurrentVideo == true` for exactly one index; that widget should call `requestFocus(videoId, owner)` and the manager should run `switchActiveTo(videoId, owner)`.
3. **Pool and view stay in sync** – the controller that the manager considers “active” for a given `videoId` must be the same instance the corresponding `VideoPlayerViewOptimized` is using to render.
4. **No audio bleed** – before unmuting the new active video, all other controllers (especially the previous “currently playing” one) must be muted and paused, with a small delay so native audio actually stops.
5. **No freeze** – the widget must never end up with a disposed controller, and the manager must not dispose a controller that is still attached to a visible view.

---

## 2. Critical Data Structures (GlobalPlaybackManager)

- **`_controllerPool`** – `Map<String, VideoPlayerController>` (videoId → controller).
- **`_activeVideoId`** – which video is “active” (the one that should be playing and unmuted).
- **`_currentlyPlayingController`** – reference to the controller that was last unmuted/played (used to mute it explicitly before unmuting the next).
- **`_attachedControllers`** – `Map<String, int>` (videoId → controller hashCode). Marks controllers that a `VideoPlayerViewOptimized` is using so the manager does not dispose them.
- **`_pendingFocusRequests`** – `Map<String, String>` (videoId → owner). When `setDesiredFocus(videoId, owner)` is called before the controller exists, focus is applied when the controller is registered via `_applyPendingFocusIfExists`.
- **`maxControllerPoolSize = 3`** – max controllers in the pool (prev/current/next). When adding a fourth, non-active (and non-attached) controllers are unregistered/disposed.

---

## 3. End-to-End Flows

### 3.1 First Video (Working)

1. HomeView loads → `preloadAround(0, videos)` and `setDesiredFocus(firstVideo.id, ownerId)`.
2. Manager’s `ensureControllerReady(0, video)` creates controller for video 0, then `registerController(videoId, controller, owner)`.
3. VideoPlayerViewOptimized for index 0 builds with `isCurrentVideo: true`. It has no controller yet → `_tryAdoptFromPool(reason: 'initState')` then, if still null, `_initializeVideo()`.
4. **Adoption (Level 1):** `_tryAdoptFromPool` now adopts whenever the pool has a safe controller. If preload registered first, the view adopts that controller; otherwise adoption returns false and the view creates its own in `_initializeVideo()`.
5. When the view has a controller (adopted or created), it calls `markControllerAttached` (created path also calls `registerController`). Pool has the controller for video 0.
6. If `widget.isCurrentVideo` → `_attemptRequestFocus(...)` → `requestFocus(videoId, owner)` → `switchActiveTo(videoId, owner)` → `_ensurePlayingUnmuted(controller)`. First video plays.

### 3.2 Second Video (Current Code After Level 1 – Still Not Playing)

1. User scrolls to index 1. `VideoPageViewWidget` sets `currentIndex = 1` → child at index 1 gets `isCurrentVideo: true`.
2. HomeView (or feed) calls `onVisibleIndexChanged(1, video)` → manager’s `onVisibleIndexChanged(1, video)` → `_muteAllExcept(targetVideoId)` and `setDesiredFocus(targetVideoId, PlaybackOwners.home)`.
3. **setDesiredFocus:** If controller for video 1 is in the pool and ready → `requestFocus(videoId, owner)` immediately. Otherwise → `_pendingFocusRequests[videoId] = owner`; focus is applied when the controller is registered via `_applyPendingFocusIfExists`.
4. VideoPlayerViewOptimized for index 1: `didUpdateWidget` runs with `isCurrentVideo: true`. Log: `VVIEW current=TRUE id=... controller=null|pool|local`. If `_videoPlayerController == null` or disposed → `_tryAdoptFromPool(reason: 'didUpdateWidget: null or disposed')` then, if still null, `_initializeVideo()`.
5. **Adoption (Level 1):** `_tryAdoptFromPool` now adopts whenever the pool has a safe controller for this videoId (no identity gate). If the pool has a controller, the view adopts it, attaches listeners, calls `markControllerAttached`, and returns true. If the pool is empty, adoption returns false and the view creates its own controller in `_initializeVideo()`.
6. **Focus attempt:** When `isCurrentVideo` becomes true, `_attemptRequestFocus('didUpdateWidget: isCurrentVideo false -> true')` runs. If pool has no controller → `setDesiredFocus` (queue) and return. If view has no controller or different from pool → `_tryAdoptFromPool(reason: 'attemptRequestFocus')`. Then, if not throttled, `requestFocus(widget.video.id, _ownerKey)`.
7. **requestFocus (Level 1):** If controller is null/unsafe → `_pendingFocusRequests[videoId] = owner` and return (no longer a dead end). Otherwise → `_muteAllExcept(videoId)` and `switchActiveTo(videoId, owner)`.
8. **switchActiveTo (Level 1):** Uses `myEpoch = ++_activationEpoch`. If controller null/unsafe at entry → queue pending and return. After `_muteAllExcept`, after 80 ms delay, and in “already active” path, aborts if `myEpoch != _activationEpoch`. Then sets `_activeVideoId`, `_currentlyPlayingController`, and `_ensurePlayingUnmuted(controller)`.

Despite the above, the second video still does not play. See “Why the problem may still occur” in the Level 1 section above for hypotheses (adoption vs empty pool, view creating and replacing pool controller, epoch abort, didUpdateWidget order, eviction).

---

## 4. Key Code Paths (Exact Locations)

### 4.1 GlobalPlaybackManager (after Level 1)

- **switchActiveTo:**  
  - `myEpoch = ++_activationEpoch`; log `GPM switch start id=... epoch=...`.  
  - Early return if `!canPlay(owner)`.  
  - If controller null/unsafe → `_pendingFocusRequests[newVideoId] = owner`, return.  
  - `_muteAllExcept`, then mute `_currentlyPlayingController`, then **80 ms delay**.  
  - If `myEpoch != _activationEpoch` → log `GPM switch abort` and return.  
  - Set `_activeVideoId`, `_controllerOwners`, stream; then `_ensurePlayingUnmuted(controller)`; log `GPM switch end`.

- **requestFocus:**  
  - If controller null/unsafe → `_pendingFocusRequests[videoId] = owner`, return (log `GPM focus-queued`).  
  - Else log `GPM focus id=...`, then `_muteAllExcept(videoId)` and `switchActiveTo(videoId, owner)`.

- **registerController** (lines ~805–920):  
  - If pool already has a different controller for same videoId:  
    - If old is “attached” → `unregisterController(videoId)` (remove old from pool, do not dispose), then add the new controller.  
    - Else → pause/dispose old, then add new.  
  - If `_controllerPool.length >= maxControllerPoolSize` and videoId not in pool → evict victims: (1) Main loop: collect IDs that are not active, not initializing, not attached, and past TTL (`disposalEligibilityTtlSeconds`). (2) **Fallback:** if the main loop found none, pick a single victim using the **same** rules (not active, not initializing, not attached, past TTL)—do **not** use “first key” regardless of attached/TTL. Then call `unregisterController(id)` for each collected ID.

- **unregisterController** (lines ~1046–1082):  
  - Mute and pause the controller, remove from pool and related maps.  
  - If controller is not “attached” (`_attachedControllers[videoId] == controller.hashCode`), dispose it; otherwise skip dispose (view will dispose).

### 4.2 VideoPlayerViewOptimized (after Level 1)

- **_tryAdoptFromPool(reason)** (returns bool):  
  - If pool has no safe controller for this videoId → return false.  
  - If already have same instance → `markControllerAttached`, return true.  
  - If have different controller or null → `_adoptController(pooled)`, attach error/state/position listeners, `markControllerAttached`, return true.  
  - Log: `VVIEW adopt id=... pooledHash=... reason=...`.

- **_attemptRequestFocus(reason)** (returns bool):  
  - Guards: mounted, `isCurrentVideo`, !blocked, `canPlay(_ownerKey)`.  
  - If pool has no controller → `setDesiredFocus(widget.video.id, _ownerKey)`, return false (log `VVIEW focus id=... controller=null (queuing)`).  
  - If view has no controller or different from pool → `_tryAdoptFromPool(reason: 'attemptRequestFocus')`.  
  - Throttle: if already requested for this video → return false.  
  - Then `requestFocus(widget.video.id, _ownerKey)`; log `VVIEW focus id=... reason=...`.

- **didUpdateWidget:**  
  - When `isCurrentVideo` becomes true: log `VVIEW current=TRUE id=... controller=null|pool|local`; reset `_hasRequestedFocus` / `_lastRequestedVideoId`; then `_attemptRequestFocus('didUpdateWidget: isCurrentVideo false -> true')`.  
  - When `_videoPlayerController == null` (or disposed) and `isCurrentVideo`: `_tryAdoptFromPool(reason: 'didUpdateWidget: null or disposed')` then, if still null, `_initializeVideo()` (log `VVIEW init-start id=... (no pool, creating)`).

- **_initializeVideo:**  
  - Log `VVIEW init-start id=...`. Creates `VideoPlayerController.networkUrl(...)`, initializes, then log `VVIEW register id=... hash=...`, `registerController(...)`, `markControllerAttached(...)`.  
  - `_applyPendingFocusIfExists(videoId)` runs inside manager’s `registerController` (log `GPM focus-apply id=... owner=...`).  
  - If `widget.isCurrentVideo` → `_attemptRequestFocus(...)`.

---

## 5. What to Try Next (After Level 1)

1. **Use the logs to find the exact stop**  
   - Run the app, open the feed, swipe to the second video. Capture VVIEW and GPM logs.  
   - Expected sequence for video 2: `VVIEW current=TRUE id=<video2> controller=...` → then either `VVIEW adopt id=...` or `VVIEW init-start id=...` → then `VVIEW register id=...` and/or `GPM focus-apply id=...` → `GPM focus id=...` or `GPM focus-queued id=...` → `GPM switch start id=... epoch=...` → either `GPM switch abort ...` or `GPM switch end id=...`.  
   - Where it stops (e.g. no adopt, no register, no focus-apply, switch abort, or switch end but no play) tells you what to fix.

2. **If pool is empty when video 2 becomes current**  
   - Ensure `preloadAround(1, videos)` (or equivalent for index 1) runs early enough when the user is still on video 0, so the pool has a controller for video 1 before the user swipes.  
   - Or: in `didUpdateWidget` when `isCurrentVideo` becomes true, explicitly call the manager to “ensure controller ready” for this index/video before calling `_tryAdoptFromPool` / `_attemptRequestFocus`, so the pool is populated before adoption and focus.

3. **If focus is queued but never applied**  
   - Confirm `_applyPendingFocusIfExists` is called from `registerController` and that it finds the controller safe and initialized. If it re-queues (controller not ready), add a short delayed retry or a listener on controller initialization to apply pending focus when the controller becomes ready.

4. **If switch aborts (epoch)**  
   - Something is incrementing `_activationEpoch` during the 80 ms delay (e.g. another `requestFocus` or `switchActiveTo`). Reduce the delay (e.g. 30–40 ms) or ensure only one “active” switch runs per user swipe (e.g. debounce or cancel previous switch when a new one starts).

5. **Level 2 (longer-term)**  
   - Manager owns controller creation; the widget never calls `VideoPlayerController.networkUrl(...)`. Widget calls `mgr.getController(videoId)` or `mgr.ensureControllerForIndex(index, video)` and only renders. That removes view-vs-pool identity mismatches and most disposal races.

---

## 6. Files to Edit

| Priority | File | Focus |
|----------|------|--------|
| 1 | `lib/services/global_playback_manager.dart` | `requestFocus`, `switchActiveTo`, `registerController`, pool size, 80 ms delay, `_applyPendingFocusIfExists` |
| 2 | `lib/widgets/video_player_view_optimized.dart` | `_tryAdoptFromPool`, `_attemptRequestFocus`, `didUpdateWidget`, `_initializeVideo` (when to create vs adopt), `markControllerAttached` |
| 3 | `lib/pages/home_view.dart` | `setDesiredFocus` / `onVisibleIndexChanged` wiring (likely already correct) |
| 4 | `lib/widgets/home_view_components/video_page_view_widget.dart` | `currentIndex` and `onPageChanged` / `onVisibleIndexChanged` (likely already correct) |
| (data) | `lib/utils/video_url_resolver.dart` | **`getOwnerId`** – canonical owner for video docs (done) |
| (data) | `lib/services/video_service.dart` | Use **getOwnerId** when building; filter by creator.id (done) |
| (data) | `lib/services/real_user_data_service.dart` | Query **userId** + **user_id**, build with **getOwnerId** (done) |

---

## 7. Success Criteria (TikTok-Like)

- [ ] First video autoplays with sound when the feed opens.  
- [ ] Swiping up to the second video: that video starts playing with sound; the first stops and is muted.  
- [ ] Swiping to the third, fourth, etc.: same behavior; no freeze, no black screen.  
- [ ] Swiping back to a previous video: it resumes from the same position (or last known position); no double audio.  
- [ ] Only one video has volume > 0 at any time (no audio bleed).  
- [ ] No “Controller was disposed” or similar crashes; no permanent stuck loading on any item.

---

## 8. Data Layer: Canonical Owner (Profile vs Feed Alignment)

**Problem:** Profile showed “Loaded 2 videos directly from Firestore” but “Found 0 user videos” from VideoService because video docs used mixed owner fields (`userId`, `user_id`, `creatorId`, `creator_id`, `authorId`, `uid`) and the two code paths filtered on different keys.

**Fix (unified canonical owner):**

| Item | Location | What it does |
|------|----------|--------------|
| **getOwnerId(data)** | `lib/utils/video_url_resolver.dart` | Returns first non-empty of: `ownerId`, `userId`, `user_id`, `authorId`, `uid`, `creatorId`, `creator_id`. Single source of truth for “who owns this video.” |
| **VideoService** | `lib/services/video_service.dart` | When loading from Firestore, uses **getOwnerId(data)** to set `creator.id`. **getUserVideos(userId)** filters in-memory by `video.creator.id == userId`. |
| **RealUserDataService.getUserVideos** | `lib/services/real_user_data_service.dart` | Queries Firestore by **userId** and **user_id** (merged), builds each video with **getOwnerId(data)** for creator lookup. Matches VideoService filtering. |

**Track:** Both “feed” (VideoService state) and “profile direct load” (RealUserDataService) now use the same owner resolution. Profile no longer flips 0 → 2 due to field mismatch. Optional next step: backfill Firestore docs with a single **ownerId** (and **videoUrl** / **thumbnailUrl**) and query only **ownerId** in RealUserDataService.

---

## 9. Feed Visibility (Not Seeing All Uploaded Videos)

**Problem:** Not all newly uploaded videos showed up in the feed; older videos appeared instead of the latest ones.

**Causes:**

1. **Status filter** – Feed only queried `status == 'published'`. Newer pipeline videos use `status == 'ready'` when rendering completes, so they were excluded.
2. **Order** – Feed used `orderBy('createdAt', descending: true)`. Videos “added” on the website are often created earlier (e.g. as drafts) and only get **`updatedAt`** when published or made ready, so newest-by-website = newest by **updatedAt**, not `createdAt`.
3. **Limit** – Only 50 videos were loaded; increasing gives more coverage.

**Fix (VideoService `loadAllVideos`):**

| Change | What |
|--------|------|
| **Status** | Query and in-memory filter accept both **`published`** and **`ready`** (`whereIn: ['published', 'ready']`; skip only when status is neither). |
| **Order** | Primary query: **`orderBy('updatedAt', descending: true)`** with same status filter and **limit 100**. Fallbacks: `orderBy('createdAt', ...)` then `orderBy('updatedAt', ...)` without status filter, then simple `limit(100)`. |
| **In-memory sort** | After reading the snapshot, sort docs by **`updatedAt ?? createdAt`** descending so feed order is “newest first” even when the query had no order. Process and dedupe in that order; do not re-sort the final list by `createdAt` only. |
| **Limit** | Increased to **100** so more videos (including newer ones) are loaded. |

**Backend / website requirement:** When a video becomes ready or published, the Firestore doc must have **`updatedAt: serverTimestamp()`** (or equivalent) so the app’s `orderBy('updatedAt', descending: true)` puts newly added/published videos at the top.

**File:** `lib/services/video_service.dart` (`loadAllVideos`).

---

## 10. Document Status

- **Scope:** This spec covers feed UI, GlobalPlaybackManager, controller pool, eviction, and focus/switch flows. For Firestore schema, upload flow, backend rendering, and playback URL rules (renditions, status, never play original), see `docs/STREAMERSTIP_CURSOR_HANDOFF.md`.
- **Code state:** Level 1 fixes are implemented (adoption, pending focus, epoch, pool size 3, VVIEW/GPM logs, **eviction fallback** in `registerController`). **Data layer:** canonical owner via getOwnerId; VideoService and RealUserDataService aligned. **Feed visibility:** status ready + published, orderBy updatedAt, in-memory sort by updatedAt ?? createdAt, limit 100 (section 9).
- **Eviction:** Fallback in `registerController` no longer disposes aggressively: it uses the same eligibility rules as the main loop (not attached, past TTL), so the current page’s controller is not evicted when the pool is full.
- **Feed playback:** Only the first video plays; second and later do not. See “What Was Fixed” and “Why the problem may still occur” for hypotheses.
- **Feed visibility:** “Not seeing all uploaded videos” fixed by including status `ready`, ordering by `updatedAt`, in-memory sort, and limit 100. Backend must set `updatedAt` when a video goes ready/published (section 9).
- **Profile videos:** 0 vs 2 mismatch fixed by unifying owner resolution (getOwnerId) and querying both userId and user_id in RealUserDataService.
- **Next:** Use VVIEW/GPM logs (open feed → swipe to second video) to find where playback stops, then apply section 5 (“What to Try Next”). Optionally backfill ownerId/videoUrl/thumbnailUrl and simplify queries.
