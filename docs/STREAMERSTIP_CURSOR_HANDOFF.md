flutt# STREAMERSTIP – Video Feed Documentation

TikTok-style vertical video feed: architecture, shared contract, feed visibility, and playback behavior.

**Platforms:** Web (Next.js on Firebase Hosting), Mobile (Flutter iOS/Android), Backend (Firebase).

---

## Goal

- Exactly one video plays at a time
- Smooth swipe next / previous
- No audio bleed, no freezes
- Every video plays when it becomes current (not just the first)

---

## 0. Platform Rules

- **Upload once, render everywhere** – Website uploads originals; background processing generates mobile-safe renditions.
- **Mobile never plays original uploads** – App only plays `mp4_720` (or HLS later).
- **Feed order is driven by `updatedAt`** – Not `createdAt`.
- **Playback is centralized** – One global authority (GlobalPlaybackManager) controls play / pause / mute.

---

## 1. Canonical Video Document (Shared Contract)

**Firestore:** `videos/{videoId}`

```json
{
  "videoId": "string",
  "ownerId": "string",
  "status": "processing | ready | published | error",
  "originalUrl": "string",
  "thumbnailUrl": "string",
  "renditions": {
    "mp4_720": { "url": "string", "width": 720, "height": 1280, "bitrate": "number" },
    "mp4_1080": { "url": "string", "width": 1080, "height": 1920, "bitrate": "number" }
  },
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

- **ownerId** – Canonical creator id.
- **status** – `processing` | `ready` | `published` | `error`.
- **originalUrl** – Web-only fallback; mobile never uses it.
- **updatedAt** – REQUIRED for feed ordering.

**Rule:** Whenever status changes to `ready` or `published`, backend MUST set `updatedAt = serverTimestamp()`.

---

## 2. Feed Visibility (Fixed)

**Issue:** The app was not showing the latest videos uploaded onto the website. New uploads were missing from the feed; older videos appeared instead.

**Why it happened:**

1. **Status filter** – The feed only queried `status == 'published'`. New videos from the pipeline use `status == 'ready'` when rendering finishes, so they were excluded.
2. **Order** – The feed used `orderBy('createdAt')`. Videos “new” on the website are often created earlier (e.g. as drafts) and only get `updatedAt` when they become ready or published, so “newest” should be by `updatedAt`, not `createdAt`.
3. **Limit** – Only 50 videos were loaded, so fewer recent items were visible.

**Fix (current behavior):**

- Accept both `ready` and `published`.
- Order by `updatedAt`; fallback to `createdAt`.
- Limit 100.
- In-memory sort by `updatedAt ?? createdAt` descending.

**VideoService (`loadAllVideos`):** `whereIn('status', ['ready', 'published'])`, `orderBy('updatedAt', descending: true)`, `limit(100)`.

**Firestore composite index (required):** Collection `videos`, fields: `status` (ASC), `updatedAt` (DESC). Defined in `firestore.indexes.json`. Deploy with: `firebase deploy --only firestore:indexes`. If the index is missing, the app falls back to `orderBy('createdAt')` and order can be wrong.

**Pull-to-refresh:** Feed supports pull-to-refresh from any video; refresh triggers `refreshFeedByTab(FeedTab.forYou)` so newest videos load from Firestore.

**Background refresh:** `_fetchFreshVideosInBackground` calls `VideoService.refresh()` so new uploads appear without pull-to-refresh.

**Query order:** Primary query uses `orderBy('createdAt', desc)`; in-memory sort uses `updatedAt ?? createdAt`. Feed always shows newest first, then oldest.

**Algorithm:** Set `FeedConfig.usePersonalizationAlgorithm = true` when ready for TikTok-style personalized feed. When false, feed shows raw newest-first order (all videos, no filtering).

**Backend (Cloud Function):** When transcoding completes, the function sets `status: 'ready'` and `updatedAt: serverTimestamp()` on the video doc so the app feed includes the video and sorts it newest first.

---

## 3. Playback Architecture (Flutter)

**Single source of truth: GlobalPlaybackManager**

- Which video is active
- Which controller is unmuted
- Pool lifecycle
- Focus arbitration

No widget may control playback independently; all playback goes through the manager.

---

## 4. Controller Pool Rules

- **maxControllerPoolSize = 3** (previous | current | next).

**Eviction:** A controller may be evicted only if it is not active, not initializing, not attached to a visible widget, and past TTL. Never evict attached controllers or the current index. Fallback eviction bug is fixed.

---

## 5. Current Playback State

**Working:** First video autoplays; controller pooling, focus queuing, epoch cancellation, and eviction safety are in place; feed data is correct.

**Broken:** Second and later videos do not start playback. This is not a data issue.

---

## 6. Root Cause (Likely)

Gap in flow: video becomes current → pool has no controller yet → focus is queued → view creates controller → controller registers → pending focus is not reliably applied or is aborted by epoch. This is a timing/ownership problem, not a codec issue.

---

## 7. Level-2 Fix (Design)

**Principle:** GlobalPlaybackManager should own controller creation for the current video.

**Current issue:** Preload creates controller A; view may create controller B; pool swaps and focus/epoch races occur.

**Intended fix:** Manager exposes something like `ensureControllerForVideo(index, video, owner)` that creates the controller if missing, registers it, applies pending focus, and returns the same instance. The view does not create controllers; it only uses `mgr.getController(videoId)` or a placeholder until the manager provides one. That removes pool/view mismatches, double controllers, lost focus, and epoch races.

---

## 8. Android Stability Notes

Observed: MediaCodec BAD_INDEX, buffer pool pressure, GC blocking, codec surface churn. These are symptoms; root cause is playback ownership/timing.

**Guardrails:** Use `mp4_720` only on Android; one active controller at a time; pool size 3; pause and mute before unmute. Do not optimize codecs further until playback logic is fixed.

---

## 9. Web (Next.js) Responsibilities

**Upload:** Original upload → status `processing`; background FFmpeg renders renditions; on completion set `status = ready` and `updatedAt = serverTimestamp()`.

**Playback:** Web may fall back to `originalUrl`; mobile never does.

**Storage path:** For `transcodeVideo` Cloud Function to run automatically, upload to either:
- `videos/{userId}/{videoId}.mp4` (3 parts) – app uploads
- `videos/{userId}/{videoId}/original.mp4` (4 parts) – website uploads

---

## 10a. Videos Not Showing (Only `original.mp4`, No Transcoding)

**Symptom:** 14+ videos skipped with `no playable URL. raw=YES, isOriginal=true`. Newest uploads from app/website missing from feed.

**Cause:** Video has `videoUrl` pointing to `original.mp4`; mobile rejects it. No `mp4_720_url` because transcoding never ran.

**Fix – existing videos:** Run backfill manually:
```
https://{region}-{project}.cloudfunctions.net/backfillVideoTranscoding?batchSize=14&limit=30
```
Example: `us-central1-streamerstip-6cfdb.cloudfunctions.net/backfillVideoTranscoding?batchSize=14&limit=30`

**Fix – new uploads:** Ensure upload path matches `transcodeVideo` (see §9). If website uses `original.mp4` subfolder, the Cloud Function now supports it.

---

## 10. Success Criteria

- First video autoplays; swiping plays every next video.
- Only one video has audio; no freezes, no black frames.
- No "disposed controller" crashes.
- Feed shows newest uploads immediately (status + `updatedAt` behavior above).
