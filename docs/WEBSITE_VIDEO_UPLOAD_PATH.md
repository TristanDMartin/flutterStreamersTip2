# Website Video Upload Path – For Web Developers

## Summary

**Preferred: Mux direct upload** (same as app). See **`docs/MUX_WEBSITE_IMPLEMENTATION.md`** for full flow.

**Alternative: Zero server transcoding.** Use client-side transcoding (FFmpeg.wasm) before upload, then upload to:

```
videos/{userId}/{videoId}.mp4
```

---

## Why This Changed

Server transcoding was causing $500+ Cloud Run charges. We now use:

1. **Client-side transcoding** – Website transcodes to 720p in browser before upload.
2. **Format check only** – Cloud Function validates H.264/AAC, ≤1080p. No server transcoding.
3. **Backfill disabled** – No batch transcoding.

---

## Recommended: Client-Side Transcoding (Zero Cost)

Use `website_upload/transcodeAndUpload.js`:

```bash
cd website_upload && npm install @ffmpeg/ffmpeg @ffmpeg/util firebase
```

```javascript
import { transcodeAndUploadVideo } from './transcodeAndUpload';

const result = await transcodeAndUploadVideo(
  videoFile,
  userId,
  videoId,
  firebaseApp,
  (percent, stage) => setProgress({ percent, stage })
);
```

Flow: Transcode to 720p in browser → upload to Storage → Cloud Function validates → sets `mp4_720_url`, `status: 'ready'`.

---

## Alternative: Direct Upload (If Format Is OK)

If the file is already H.264/AAC and ≤1080p, upload directly:

```javascript
const storageRef = ref(storage, `videos/${userId}/${videoId}.mp4`);
await uploadBytes(storageRef, videoFile, { contentType: 'video/mp4' });
```

The Cloud Function will validate and use the original as `mp4_720_url` if format is OK.

---

## Supported Paths

| Path | Status |
|------|--------|
| `videos/{userId}/{videoId}.mp4` | Preferred |
| `videos/{userId}/{videoId}/original.mp4` | Supported |

---

## Firestore Video Document

Create the doc **before** upload with `status: 'processing'`. The Cloud Function sets `mp4_720_url`, `status: 'ready'` when done.

```javascript
{
  id: videoId,
  userId: userId,
  status: 'processing',
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  // ... title, description, etc.
}
```

---

## Video Format (TikTok spec)

- **Resolution:** ≤1080×1920 (9:16 vertical)
- **Frame rate:** 30fps
- **Codec:** H.264 High Profile, AAC-LC
- For client-side transcode: 720p output

---

## Reference

- Client transcode: `website_upload/transcodeAndUpload.js`
- Cloud Function: `cloud_functions/index.js` – `transcodeVideo` (format check only)
- App upload: `lib/services/video_upload_service.dart`
