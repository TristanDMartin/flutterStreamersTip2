# Storage Migration: Firebase → Cloudflare / Mux

Migrate videos and thumbnails from Firebase Storage to Cloudflare or Mux to avoid Firebase billing/402 issues.

---

## Current State

| Asset | Location | Notes |
|-------|----------|-------|
| **Videos (new)** | Mux (primary) or Firebase Storage (fallback) | Mux used when `createDirectUpload` succeeds |
| **Videos (existing)** | Firebase Storage | `videos/{userId}/{videoId}_720p.mp4` |
| **Thumbnails** | Firebase Storage | `thumbnails/{videoId}.jpg` or `videos/{userId}/{videoId}/thumbnail.jpg` |

---

## Option 1: Mux for All (Recommended)

**Videos**: Already primary for new uploads. Mux provides HLS + poster thumbnails.

**Thumbnails for Mux videos**: Mux generates them automatically:
```
https://image.mux.com/{playbackId}/thumbnail.jpg?width=720&time=0
```

### Changes Required

1. **Stop uploading thumbnails when using Mux**  
   In `video_upload_service.dart`, when `usedMux == true`, don't call `_generateAndUploadThumbnail` for Storage. Either:
   - Upload a custom frame to Mux (passthrough), or
   - Let the Mux webhook set `thumbnailUrl` from `image.mux.com` when asset is ready.

2. **Webhook**: Update `muxWebhook` (Worker or Cloud Function) to set:
   ```js
   thumbnailUrl: `https://image.mux.com/${playbackId}/thumbnail.jpg?width=720`,
   thumbnails: { urls: { 360: url, 540: url, 720: url }, generatedAt: ... }
   ```

3. **Existing videos**: Run a backfill script that:
   - Re-uploads Firebase Storage videos to Mux via direct upload API
   - Updates Firestore with `hlsUrl`, `muxPlaybackId`, `thumbnailUrl` from Mux
   - Or: leave legacy videos on Firebase until 402 is resolved; new uploads use Mux

---

## Option 2: Cloudflare R2 for Thumbnails + Videos

**R2** = S3-compatible object storage, no egress fees.

### Setup

1. Create R2 bucket: `streamerstip-media`
2. Cloudflare Worker for uploads: presigned PUT URLs
3. Public access: R2 public bucket or custom domain `media.streamerstip.com`

### Thumbnail Upload Flow

- App calls `POST /api/upload-url` with Firebase auth token
- Worker returns presigned PUT URL for `thumbnails/{videoId}.jpg`
- App uploads thumbnail, gets final URL: `https://media.streamerstip.com/thumbnails/{videoId}.jpg`

### Video Upload Flow

- Either keep Mux for videos (recommended: transcoding, HLS)
- Or use R2 for raw MP4: `https://media.streamerstip.com/videos/{userId}/{videoId}.mp4`
  - No transcoding; larger files; you'd need your own transcoding or Cloudflare Stream

### Code Changes

- New `R2UploadService` or extend upload to use Worker endpoint
- Replace `_generateAndUploadThumbnail` Storage call with R2 presigned upload
- Replace `_uploadVideoFile` with R2 when not using Mux

---

## Option 3: Cloudflare Stream (Alternative to Mux)

Similar to Mux: upload → transcode → HLS + thumbnails.

- Thumbnail: `https://customer-{code}.cloudflarestream.com/{videoId}/thumbnails/thumbnail.jpg`
- Would require migrating from Mux to Stream (new upload pipeline, webhooks, etc.)

---

## Recommended Path

1. **Short term**: Fix Firebase 402 (billing) so existing content works.
2. **New uploads**: Ensure Mux is primary; use Mux thumbnails (`image.mux.com`) when Mux succeeds.
3. **Thumbnails**: For Mux videos, stop uploading to Firebase; use Mux thumbnail URL from webhook.
4. **Optional**: Add Cloudflare R2 as fallback for thumbnails when Mux fails, or for custom frames.

---

## Implementation Order

| Step | Action | Files | Status |
|------|--------|-------|--------|
| 1 | Webhook sets `thumbnailUrl` from `image.mux.com` when Mux ready | `cloud_functions/src/mux.js` | Done |
| 2 | Run migration script to re-upload Storage videos to Mux | `cloud_functions/scripts/migrate_to_mux.js` | Done |
| 3 | App: skip thumbnail Storage upload when Mux used | `video_upload_service.dart`, `video_processing_service.dart` | Pending |
| 4 | (Optional) App: use Mux thumbnail in UI when `muxPlaybackId` present | Thumbnail resolution | Optional |

---

## Running the Migration Script

1. **Deploy webhook changes** (so Mux thumbnails are written):
   ```bash
   cd cloud_functions && npm run deploy
   ```

2. **Set credentials**:
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
   # MUX_TOKEN_ID and MUX_TOKEN_SECRET in cloud_functions/.env
   ```

3. **Dry run** (list videos to migrate):
   ```bash
   cd cloud_functions && node scripts/migrate_to_mux.js --dry-run
   ```

4. **Migrate in batches**:
   ```bash
   node scripts/migrate_to_mux.js --limit 5
   node scripts/migrate_to_mux.js --limit 20 --offset 5
   ```

5. **Optional**: `--skip-status` to avoid writing `status: 'processing'` (useful for re-runs).

The script downloads from Firebase Storage via Admin SDK (avoids HTTP 402), uploads to Mux, then the webhook updates Firestore when Mux transcoding completes.

---

## Thumbnail URL Resolution (App)

Add logic to prefer Mux thumbnail when available:

```dart
String? resolveThumbnailUrl(Map<String, dynamic> data) {
  final playbackId = data['muxPlaybackId'] as String?;
  if (playbackId != null && playbackId.isNotEmpty) {
    return 'https://image.mux.com/$playbackId/thumbnail.jpg?width=720&time=0';
  }
  return data['thumbnailUrl'] ?? data['thumbnailURL'] as String?;
}
```

Use this in `RealUserDataService`, `VideoService`, `ThumbnailTile` instead of raw `thumbnailUrl`.
