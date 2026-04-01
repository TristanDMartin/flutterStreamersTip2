# Cloudflare Migration — Discovery & Implementation Reference

## 1. Current Flutter Implementation

### Where createMuxDirectUpload is called
- **File:** `lib/services/mux_upload_service.dart`
- **Method:** `MuxUploadService.createDirectUpload({ videoId, userId })`
- **Implementation:** Calls Firebase callable `createMuxDirectUpload` via `FirebaseFunctions.instance.httpsCallable('createMuxDirectUpload')`
- **Called from:** `lib/services/video_upload_service.dart` → `_uploadViaMux()` path
- **Flow:** App generates `videoId`, gets `uploadUrl` + `uploadId` from Cloud Function, then PUTs file to `uploadUrl`

### Mux webhook fields expected in Firestore
- `hlsUrl`, `hls_url`, `mp4_720_url`, `videoUrl`, `videoURL`, `canonicalPlaybackUrl`
- `muxAssetId`, `muxPlaybackId`
- `thumbnailUrl`, `thumbnailURL`, `thumbnails` (map with urls)
- `status`: `'ready'`
- `transcodingStatus`: `'completed'`
- `metadata.duration` (optional)

### Firestore video document schema (videos/{videoId})
```
id, userId, creatorId, creator_id
status: 'uploading' | 'processing' | 'ready' | 'published'
videoUrl, videoURL, hlsUrl, hls_url, mp4_720_url, canonicalPlaybackUrl
thumbnailUrl, thumbnailURL, thumbnails
muxAssetId, muxPlaybackId
transcodingStatus, transcodedAt
caption, hashtags, privacy, allowComments, category
views, likes, comments
createdAt, updatedAt
metadata: { duration, ... }
```

### Current PUT to Mux implementation
- **File:** `lib/services/mux_upload_service.dart` → `uploadToMux({ videoFile, uploadUrl, onProgress })`
- **Implementation:** Uses Dio to PUT file to Mux signed URL with `Content-Type: video/mp4`

---

## 2. Current Website Implementation
- **Status:** Website upload may exist in separate repo or `web/` folder
- **Where to plug Worker:** Replace any `createMuxDirectUpload` callable with `POST https://api.streamerstip.com/mux/direct-upload`
- **Publish modal:** Call Worker with Bearer token, then PUT to `uploadUrl`, create/update Firestore doc with caption/metadata, listen for `status === 'ready'`

---

## 3. Current Cloudflare Assets
- **api.streamerstip.com:** Configured in wrangler (routes commented out; workers_dev = true for *.workers.dev)
- **DNS:** Add CNAME `api` → Worker if using custom domain
- **workers/:** StreamersTip Mux API Worker (JS)
- **cloudflare_workers/mux/:** More complete Worker with Firestore REST, proper webhook

---

## 4. Playback URLs (unchanged)
- HLS: `https://stream.mux.com/{playbackId}/high.m3u8`
- Thumbnail: `https://image.mux.com/{playbackId}/thumbnail.jpg?width=720&time=0`
