# Cloud Cost Guardrails – Verification & Prevention

**Purpose:** Document what runs client-side vs Cloud, and guardrails to prevent another ~$888/year Cloud Run bill.

**Last updated:** Feb 2025

---

## Executive Summary

| Area | Before | After | Cloud cost |
|------|--------|-------|------------|
| **Video views** | 5 functions per view, ~25k invocations/day | 0 functions per view; 1 scheduled job/day | ~92% reduction |
| **Video upload** | Client thumbnail + Storage + Firestore | Same; `transcodeVideo` runs 1× per upload | Bounded by uploads |
| **Milestone notifications** | Per-view trigger | DISABLED | $0 |
| **Creator field normalization** | Per-write trigger | DISABLED (client sends all fields) | $0 |

---

## 1. Client-Side Processing (No Cloud Run)

### Video playback / views
| Step | Where | Evidence |
|------|-------|----------|
| Thumbnail display | Client (cached_network_image) | `lib/widgets/` |
| Video playback | Client (video_player) | `lib/widgets/video_player_view_optimized.dart` |
| View count increment | Client → `video_analytics` only | `_incrementViewCount()` writes to `video_analytics/{videoId}` only |
| 7s minimum watch | Client | `_minWatchTimeForView = Duration(seconds: 7)` |
| View timer cancel on pause | Client | `_viewCountTimer?.cancel()` in pause handler |

**Code reference:**
```
lib/widgets/video_player_view_optimized.dart:2792
  analyticsRef.set({
    'views': FieldValue.increment(1),
    'lastViewedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
```
→ No write to `videos/{id}` → No Firestore triggers on views.

### Video upload (mobile)
| Step | Where | Evidence |
|------|-------|----------|
| Thumbnail generation | Client | `VideoProcessingService.generateThumbnailWithFallbacks()` |
| Moderation (pre-upload) | Client | `VideoModerationService.moderateVideo()` |
| Category detection | Client | `_detectCategoryFromContent()` |
| Duration extraction | Client | `VideoProcessingService.getVideoDuration()` |
| Upload to Storage | Client | `_uploadVideoFile()` |
| Firestore doc creation | Client | `_firestore.collection('videos').doc(videoId).set()` |

---

## 2. Cloud Functions – What Still Runs

### Triggered by Firestore writes

| Function | Trigger | When | Est. invocations |
|----------|---------|------|------------------|
| onVideoUpdate | `videos/{id}` onUpdate | Status/privacy change only (early exit on view-only) | Low |
| onVideoWrite | `videos/{id}` onWrite | Create, like, comment, **or** scheduled sync | Medium |
| onVideoCreate | `videos/{id}` onCreate | New video | = uploads |
| onLikeCreate | likes collection | User likes | = likes |
| onCommentCreate | comments | User comments | = comments |
| syncCreatorProfileToVideos | users onUpdate | Profile edit | Rare |

### Triggered by Storage

| Function | Trigger | When | Est. invocations |
|----------|---------|------|------------------|
| transcodeVideo | storage.onFinalize | **Every video upload** | = uploads |
| onRawUpload | storage.onFinalize | raw_uploads path | Rare |

### Scheduled (fixed cost)

| Function | Schedule | Purpose |
|----------|----------|---------|
| syncVideoAnalyticsToVideos | 3am daily | Copies `video_analytics.views` → `videos.views` |
| cleanupExpiredCalendarEvents | 24h | Calendar cleanup |

### Disabled (no invocations)

| Function | Status |
|----------|--------|
| onVideoMilestone | DISABLED |
| normalizeVideoCreatorFields | DISABLED |
| backfillVideoTranscoding | Returns 403 |

---

## 3. Cost-Bounded Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ CLIENT (Flutter / Web)                                           │
│ • View counting → video_analytics only (no videos/ write)        │
│ • Thumbnail generation (4-method fallback)                       │
│ • Category detection                                              │
│ • Moderation checks                                               │
│ • Duration extraction                                             │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ FIREBASE                                                         │
│ • Firestore: video_analytics (no triggers)                       │
│ • Storage: video file upload → 1× transcodeVideo per upload     │
│ • Firestore: videos doc create → 1× onVideoCreate per upload     │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ SCHEDULED (1×/day)                                               │
│ • syncVideoAnalyticsToVideos: video_analytics → videos.views     │
│   → Triggers onVideoWrite per video, but 1 batch vs thousands    │
└─────────────────────────────────────────────────────────────────┘
```

**Per video view:** 0 Cloud Function invocations (writes to `video_analytics` only).

**Per video upload:** 1× transcodeVideo + 1× onVideoCreate (+ onVideoWrite for initial doc).

---

## 4. Verification Checklist

Before any change, confirm:

- [ ] **View counting** – No direct writes to `videos/{id}` for views. Only `video_analytics/{id}`.
- [ ] **New Firestore triggers** – Adding `onWrite`/`onUpdate` to high-traffic collections (videos, follows) multiplies cost.
- [ ] **transcodeVideo** – Runs on every upload to `videos/` path. To reduce: add client format check before upload, or use a different Storage path that transcodeVideo ignores.
- [ ] **Scheduled jobs** – `syncVideoAnalyticsToVideos` must run so `videos.views` stays updated.

---

## 5. What Would Cause Costs to Spike Again

| Action | Risk |
|--------|------|
| Re-enable onVideoMilestone | ~20% more invocations per video update |
| Re-enable normalizeVideoCreatorFields | ~20% more invocations per video write |
| Write views to `videos/` on each view | Back to ~25k function invocations/day |
| Add new Firestore trigger on `videos/` | Scales with every video interaction |
| Re-enable backfillVideoTranscoding | $500+ if run |
| Remove 7s minimum watch | More view writes |
| Add server-side transcoding | High CPU per upload |

---

## 6. Files to Audit on Changes

| File | Purpose |
|------|---------|
| `lib/widgets/video_player_view_optimized.dart` | View counting – must write to video_analytics only |
| `lib/services/video_upload_service.dart` | Upload flow – client does thumbnail, duration, category |
| `lib/services/video_processing_service.dart` | Thumbnail cascade – all client-side |
| `cloud_functions/index.js` | All function exports – check for new triggers |
| `firestore.rules` | video_analytics write rules |

---

## 7. Monitoring

- **Firebase Console** → Functions → Usage: invocation count and CPU time.
- **Google Cloud** → Billing → Reports: filter by Cloud Run.
- **Alert:** Set a billing alert at $50–100/month to catch spikes early.

---

## 8. Summary

- **Video views:** No Cloud Run cost (client → `video_analytics`; scheduled job syncs daily).
- **Video uploads:** One `transcodeVideo` per upload; client does everything else.
- **Disabled functions:** onVideoMilestone, normalizeVideoCreatorFields.
- **Guardrails:** This doc + code references above.
