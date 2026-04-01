# HomeView + Upload Spec — Gap Analysis

Comparison of the **StreamersTip HomeView Feed + Unified Upload System** engineering spec against the current codebase.

---

## 1. Video Document Schema

| Spec Field | Spec Type | Current State | Gap |
|------------|-----------|---------------|-----|
| `isReadyForFeed` | boolean (system-only) | **Not used** | Worker never sets it. App never queries it. |
| `processingState` | enum: uploading \| processing \| ready \| failed | **Not used** | Worker uses `status` instead. No `processingState` field. |
| `playbackUrl` | string (Mux HLS) | **Not used** | Worker writes `hlsUrl`, `videoUrl`, `canonicalPlaybackUrl` — no `playbackUrl`. |
| `publishedAt` | Timestamp | **Not set** | Worker does not set `publishedAt` on webhook completion. |
| `status` | enum: active \| flagged \| removed \| shadow_banned | **Different** | App uses `status` with values: `published`, `ready`, `processing`, `uploading`, `draft`. Spec expects `active`. |
| `visibility` | enum: public \| followers_only \| private | **Different** | App uses `privacy`: `Everyone`, `Public`, `Connections`, `Private`. Spec expects `visibility`. |
| `engagementScore` | number | **Partial** | Exists in `engagement` subcollection and some services; not on video doc for feed ordering. |
| `skipCount` | number | **Missing** | Not present in video schema. |

---

## 2. Feed Eligibility & Query

### Spec

```
.where("isReadyForFeed", "==", true)
.where("status", "==", "active")
.where("visibility", "==", "public")
.orderBy("engagementScore", descending: true)
.orderBy("publishedAt", descending: true)
.limit(20)
```

### Current

**VideoService** (`lib/services/video_service.dart`):

- `where('status', whereIn: ['published', 'ready', 'processing'])` — includes processing
- `orderBy('createdAt', descending: true)` or `orderBy('updatedAt', descending: true)`
- No `isReadyForFeed` filter
- No `visibility` filter (uses `privacy` with relaxed logic)
- No `engagementScore` ordering
- No `publishedAt` ordering

**VideoHealthGate** (client-side):

- Filters out `status == 'processing'` when `muxPlaybackId` is null
- Does not use `isReadyForFeed`; uses `status`, `muxPlaybackId`, `playbackReady`, etc.

| Gap | Severity |
|-----|----------|
| No `isReadyForFeed` in query | **Critical** — spec says this is the single gate for feed entry |
| `status` values differ (`published`/`ready` vs `active`) | **Critical** |
| `visibility` vs `privacy` | **High** — different field and values |
| Processing videos can be fetched | **Critical** — spec: never show processing |
| No `engagementScore` ordering | **High** |
| No `publishedAt` ordering | **High** |
| No `publishedAt` on documents | **High** |

---

## 3. Cloudflare Worker (Mux Webhook)

### Spec

Worker should:

1. Validate all gates (duration, thumbnail, status)
2. Set `isReadyForFeed: true` only when all pass
3. Set `processingState: "ready"`
4. Set `playbackUrl` (Mux HLS)
5. Set `publishedAt: now`
6. On failure: set `processingState: "failed"`, leave `isReadyForFeed` false

### Current (`cloudflare_workers/mux/src/index.js`)

- Sets `status: 'ready'` (or `'draft'` if `isDraft`)
- Sets `hlsUrl`, `videoUrl`, `canonicalPlaybackUrl`, `muxPlaybackId`, `thumbnailUrl`
- Does **not** set: `isReadyForFeed`, `processingState`, `playbackUrl`, `publishedAt`
- Does **not** validate duration range (1–300s)
- Does **not** validate thumbnail
- Does **not** set `processingState: "failed"` on failure

| Gap | Severity |
|-----|----------|
| `isReadyForFeed` never set | **Critical** |
| `processingState` never set | **Critical** |
| `playbackUrl` not set (uses `hlsUrl`/`videoUrl`) | **Medium** — naming only if app uses `hlsUrl` |
| `publishedAt` not set | **High** |
| No gate validation (duration, thumbnail) | **High** |
| No failure path (`processingState: "failed"`) | **High** |

---

## 4. Feed Query — Pagination

### Spec

- Cursor-based via `startAfterDocument`
- Initial: 20 videos
- Load more: 10 at a time

### Current

- **VideoService**: `loadAllVideos()` fetches up to 100, no cursor
- **HomeProvider**: Uses `nextCursor` / `lastDocument` but `fetchForYouVideos` returns `lastDocument: null` — pagination not implemented
- **FollowingFeedService**, **DiscoverView**: Use `startAfterDocument` correctly

| Gap | Severity |
|-----|----------|
| For You feed has no cursor pagination | **High** |
| Limit 100 vs spec 20 initial | **Medium** |

---

## 5. Flutter HomeView — Playback & Preloading

### Spec

- **VideoControllerPool**: max 5 controllers (current, ±1, +2)
- **Preload**: current playing; +1 initialized and preloading; -1 initialized; +2 metadata only; >+2 lazy; <-2 disposed

### Current (`lib/services/global_playback_manager.dart`)

- `maxControllerPoolSize = 3`
- `poolRadius = 1` (current ±1 only)
- No +2 metadata preload
- No explicit “dispose when <-2” rule

| Gap | Severity |
|-----|----------|
| Pool size 3 vs spec 5 | **Medium** |
| No +2 preload tier | **Medium** |

---

## 6. Error Handling & Auto-Skip

### Spec

- Auto-skip after **8 seconds** on load failure
- Log to telemetry
- After **3 consecutive** failures: show non-blocking toast
- Log to `feedSkipLogs/{logId}`

### Current

- **VideoPlayerViewOptimized**: Auto-skip after **250ms** (not 8s)
- No 3-consecutive-failures toast
- No `feedSkipLogs` writes
- `onVideoUnplayable` exists and triggers skip

| Gap | Severity |
|-----|----------|
| Auto-skip 250ms vs 8s | **High** |
| No 3-failures toast | **Medium** |
| No `feedSkipLogs` telemetry | **High** |

---

## 7. Playback Telemetry

### Spec Events

- `video_impression`
- `video_play_start`
- `video_watch_duration`
- `video_skip` (< 2s watch)
- `video_load_error`
- `video_auto_skipped`
- `feed_tab_switch`

### Current

- **EngagementAnalyticsService**: Tracks some engagement
- No `feedSkipLogs` collection
- No `video_impression`, `video_skip`, `video_load_error`, `video_auto_skipped` as specified

| Gap | Severity |
|-----|----------|
| Spec telemetry events not implemented | **High** |

---

## 8. Firestore Indexes

### Spec

```
videos: isReadyForFeed ASC, status ASC, visibility ASC, engagementScore DESC, publishedAt DESC
videos: isReadyForFeed ASC, status ASC, visibility ASC, ownerId ASC, publishedAt DESC (Following)
videos: ownerId ASC, isReadyForFeed ASC, publishedAt DESC (Profile)
feedSkipLogs: videoId ASC, timestamp DESC
```

### Current (`firestore.indexes.json`)

- No index on `isReadyForFeed`
- No index on `visibility`
- No index on `engagementScore` + `publishedAt` for videos
- No `feedSkipLogs` collection or index

| Gap | Severity |
|-----|----------|
| Spec indexes missing | **Critical** for spec-compliant queries |

---

## 9. Upload Pipeline

### Spec

- Client validation: mp4/mov/webm, max 500MB, 1–300s, caption 1–500 chars, category required, min 480p
- State machine: idle → validating → uploading → processing → ready | failed
- Worker creates doc with `isReadyForFeed: false`, `processingState: "uploading"`

### Current

- **VideoUploadService**: Validates file, duration, moderation
- **VideoPublishingScreen**: Caption max 500, category required
- **Worker** (`handleDirectUpload`): Creates doc with `status: 'uploading'`, `hasMuxPlaybackId: false` — no `processingState`, no `isReadyForFeed`
- Privacy uses `privacy` (Everyone/Public/Connections/Private), not `visibility`

| Gap | Severity |
|-----|----------|
| Worker init doc missing `isReadyForFeed`, `processingState` | **High** |
| `visibility` vs `privacy` | **Medium** |

---

## 10. Following Feed

### Spec

- `.where("ownerId", "in", followingIds)` (max 30 per query, batch if needed)
- Sort by `publishedAt` descending

### Current

- **FollowingFeedService**: Fetches by following IDs
- **VideoService.fetchFollowingVideos**: Filters in-memory from `state`, no Firestore `ownerId in` query
- No `publishedAt` ordering

| Gap | Severity |
|-----|----------|
| Following feed not using spec query | **Medium** |

---

## 11. Blocked / Muted Creators

### Spec

- Filter `ownerId` in blocked list **client-side** after fetch
- Do not use Firestore `not-in` (10-item limit)

### Current

- No blocked-creator filtering in VideoService or feed logic

| Gap | Severity |
|-----|----------|
| Blocked creators not filtered from feed | **High** |

---

## 12. Summary — Priority Order

| Priority | Area | Main Gaps |
|----------|------|-----------|
| P0 | Feed eligibility | Add `isReadyForFeed`, Worker sets it, query uses it |
| P0 | Worker webhook | Set `isReadyForFeed`, `processingState`, `publishedAt`, validate gates |
| P0 | Status/visibility | Align `status` (active) and `visibility` (public) with spec or map correctly |
| P1 | Feed query | Add `engagementScore`, `publishedAt` ordering; add indexes |
| P1 | Telemetry | Implement `feedSkipLogs`, `video_skip`, `video_load_error`, etc. |
| P1 | Auto-skip | Change 250ms → 8s; add 3-failures toast |
| P1 | Blocked creators | Filter blocked `ownerId` client-side |
| P2 | Pagination | Cursor pagination for For You (20 initial, 10 load more) |
| P2 | Preload pool | Consider 5 controllers, +2 preload tier |
| P2 | Upload init | Worker sets `isReadyForFeed: false`, `processingState: "uploading"` |

---

## 13. Recommended Implementation Order

1. **Worker**: Add `isReadyForFeed`, `processingState`, `playbackUrl`, `publishedAt`; validate duration (1–300s) and thumbnail; set `processingState: "failed"` on failure.
2. **Worker init**: Set `isReadyForFeed: false`, `processingState: "uploading"` on create.
3. **VideoService**: Query by `isReadyForFeed == true`; add `status == "active"` (or map `published`/`ready` → active); add `visibility == "public"` (or map `privacy`); order by `engagementScore` DESC, `publishedAt` DESC.
4. **Firestore indexes**: Add composite indexes for the new query.
5. **Schema migration**: Add `playbackUrl`, `publishedAt`, `engagementScore`, `skipCount` to video docs; backfill via Worker/script.
6. **Telemetry**: Create `feedSkipLogs`; log `video_skip`, `video_load_error`, `video_auto_skipped`.
7. **Auto-skip**: Change delay to 8s; add 3-consecutive-failures toast.
8. **Blocked filter**: Apply blocked-list filter client-side after fetch.
9. **Pagination**: Implement cursor pagination for For You (20/10).
10. **Preload**: Consider expanding pool to 5 and adding +2 preload.
