# Google Cloud / Firebase Billing Analysis

## Root cause (Feb 2025–2026: $888, ~$711 from Cloud Run CPU)

Billing is dominated by **Cloud Run / Cloud Functions**, not Firestore or Storage.

---

## Main cost driver (fixed): video view writes → function cascade

**Before (now fixed):** Each video view wrote to `videos/{id}`, triggering 4 functions per view.

**After:** Client writes only to `video_analytics/{videoId}`. A daily scheduled job (`syncVideoAnalyticsToVideos`, 3am) reads `video_analytics`, updates `videos.views`, and skips deleted videos. `onVideoWrite` then syncs view deltas to `users/{creatorId}.totalViews`.

---

## Implemented fixes (Feb 2025)

- **onVideoUpdate**: Early exit when status/privacy unchanged → skips CPU for view-only updates
- **onVideoMilestone**: Early exit when no milestone crossed → skips CPU for most view updates
- **Client**: 7s minimum watch time (was 5s), cancel view timer on pause → fewer writes

---

## Cloud Functions cost reduction

**Implemented**

1. **5s minimum watch time** – Only count view after 5s playback (~40–50% fewer writes)
2. **Views only in video_analytics** – No per-view writes to `videos/` (no per-view function triggers)
3. **Daily sync** – `syncVideoAnalyticsToVideos` at 3am copies `video_analytics.views` → `videos.views` (~500 writes/day vs 5000)
4. **Result** – ~25k → ~2k function invocations/day (~92% reduction)

**Note:** View aggregation via video_analytics + daily sync is implemented.
   - Don’t write on every view; batch or sample (e.g. 1 write per 10 views, or client-side debounce)
   - Or move views to a separate `video_analytics/{id}` collection aggregated by a scheduled function
**Medium impact**

3. **transcodeVideo**
   - Runs on upload, downloads full file for FFmpeg check (256MB, 60s). Consider lighter validation or run only when needed.
4. **syncCreatorProfileToVideos**
   - On profile change, updates all videos for that creator (100+ writes). Batch or debounce.

---

## Where to Check

1. **Firebase Console** → Project Settings → Usage and billing
2. **Google Cloud Console** → Billing → Reports (break down by product)
3. Filter by: Firestore, Cloud Storage, Cloud Functions

---

## Likely Cost Drivers (from codebase)

### 1. Firestore reads (often the biggest)

| Source | Pattern | Risk |
|--------|---------|------|
| **NetworkView** | `collection('follows').snapshots()` – listens to **entire** follows collection | **High** – Every follow doc = 1 read on connect + 1 per update. 500 follows ≈ 500+ reads per user opening Network tab |
| **StreamerCardView** | 5–6 snapshot listeners **per card** (user doc, follows, followers, etc.) | **High** – 20 cards visible ≈ 100+ listeners |
| **VideoPlayerView** | 1 snapshot listener **per video** for comment count | **Medium** – ~5–10 videos preloaded ≈ 10 doc reads |
| **DiscoverView** | Category feeds + multiple snapshots | **Medium** |
| **ActivityProvider** | Notifications listener | **Medium** |
| **InboxService** | Chats, drafts, unread counts | **Medium** |
| **VideoService.refresh()** | Full videos query (limit 100) on refresh + background | **Low–Medium** – Called on pull-to-refresh and background |
| **syncLikeStates, syncFavoriteStates, syncCommentCounts** | Batched reads | **Low** |

### 2. Firebase Storage

| Source | Pattern | Risk |
|--------|---------|------|
| Video playback | 1 download per video view | **Medium** – Depends on views |
| Thumbnails | 1 download per thumbnail in feed | **Low–Medium** |
| Avatars | Cached, but initial loads | **Low** |

### 3. Cloud Functions (main billing driver)

| Function | Trigger | Risk |
|----------|---------|------|
| **onVideoUpdate, onVideoWrite, onVideoMilestone, normalizeVideoCreatorFields** | `videos/{id}` document write/update | **High** – 4 functions per video view |
| **transcodeVideo** | `storage.object().onFinalize` – every video upload | **Medium** – Downloads file, runs format check |
| **syncCreatorProfileToVideos** | User profile update | **Medium** – Updates 100+ video docs |
| **onRawUpload** | `storage.object().onFinalize` | **Low** |
| **cleanupExpiredCalendarEvents** | Scheduled daily | **Low** |

---

## Top recommendations

### 1. Scope the follows listener (biggest impact)

**Current:** `collection('follows').snapshots()` – listens to all follow documents.

**Change:** Listen only to follows for the current user:

```dart
// Instead of entire collection
_firestore.collection('follows')
  .where('followerId', isEqualTo: currentUserId)  // or your field
  .snapshots()
```

You may need a composite index in `firestore.indexes.json`.

### 2. Reduce per-card listeners in StreamerCardView

- Use one-time `.get()` instead of `.snapshots()` where real-time isn’t needed
- Or cache follow state and refresh only on explicit actions
- Dispose listeners when the card scrolls off screen

### 3. Use one-time reads for comment count

- Replace per-video `videos/{id}.snapshots()` with `.get()` or a single batch read when loading the feed
- Or keep a listener only for the **currently playing** video

### 4. Limit video preloading

- Reduce how many videos are preloaded; each one can mean extra Firestore and Storage usage

### 5. Confirm in Firebase / Cloud Console

Check **Usage and billing**:

- **Firestore** – Reads/writes per day
- **Storage** – Download bandwidth and storage size
- **Functions** – Invocations and compute time

---

## Quick checks

1. **Firestore read usage** – Compare to 50K reads/day free tier
2. **Storage egress** – Check download GB vs 1 GB/day free
3. **Function invocations** – Check counts and duration

---

## Next steps

1. In Firebase Console, note which product (Firestore, Storage, Functions) is growing fastest
2. Implement the follows collection scoping change
3. Review StreamerCardView and VideoPlayerView for unnecessary listeners or reads
