# Mux Video Upload — Website Implementation Guide

This document describes how the **Flutter app** and **website** implement Mux video uploads with the same logic. Both can use either **Cloudflare Workers** (recommended) or **Firebase Cloud Functions**.

---

## Preferred: Cloudflare Worker (No Cloud Run)

**Use the Worker when:** You want to avoid Cloud Run costs and have Flutter + Website call the same API.

| Endpoint | Purpose |
|----------|---------|
| `POST https://api.streamerstip.com/mux/direct-upload` | Get `videoId`, `uploadUrl` (Bearer token required) |
| `POST https://api.streamerstip.com/webhooks/mux` | Mux webhook (called by Mux, not clients) |

**Flow:**
1. Client gets Firebase ID token
2. `POST /mux/direct-upload` with `Authorization: Bearer <token>` → receive `videoId`, `uploadUrl`
3. Worker creates Firestore `videos/{videoId}` with `status: 'uploading'`
4. Client **PUT**s video file to `uploadUrl`
5. Client updates Firestore with caption, thumbnail, etc. (safe fields only)
6. Mux webhook → Worker updates Firestore with `status: 'ready'`, `hlsUrl`, `muxPlaybackId`
7. Client listens for `status === 'ready'` → playback via `https://stream.mux.com/{playbackId}/high.m3u8`

**Full spec:** `docs/MUX_CLOUDFLARE_WORKER_SPEC.md`  
**Worker code:** `workers/`

---

## Alternative: Firebase Cloud Functions

When Mux is configured with Cloud Functions, both app and website should:

1. Generate a unique video ID (or receive from Worker)
2. Upload thumbnail to Firebase Storage first
3. Call Cloud Function `createMuxDirectUpload` to get a signed URL
4. **PUT** the video file to the Mux signed URL
5. Create the Firestore video document with `status: 'processing'`
6. Let the Mux webhook update the document when transcoding is done

---

## Flow (Matches App)

```
┌─────────────┐                    ┌──────────────────┐
│   Website   │  1. createMuxDirectUpload (callable)  │
│   Client    │ ──────────────────────────────────────►│  Cloud Functions
└──────┬──────┘     { videoId, userId }                └────────┬─────────┘
       │                            │                           │
       │    2. Returns { uploadUrl, uploadId }                  │ Mux API
       │◄───────────────────────────┘                           │
       │                                                         │
       │  3. PUT video file to uploadUrl                         │
       │     Headers: Content-Type: video/mp4                    │
       │              Content-Length: <bytes>                     │
       ▼                                                         │
┌─────────────┐                                                  │
│ Mux Storage │◄─────────────────────────────────────────────────┘
└──────┬──────┘
       │
       │  4. Create Firestore videos/{videoId} with status: 'processing'
       │     (thumbnail, caption, metadata, etc.)
       │
       │  5. Mux transcodes → webhook POST to muxWebhook
       │     → Cloud Function updates video with hlsUrl, status: 'ready'
       ▼
┌─────────────┐
│  Firestore  │  videos/{videoId} ready for playback
└─────────────┘
```

---

## 1. Cloud Function: `createMuxDirectUpload`

**Type:** Firebase Callable (HTTPS)

**Auth:** Required (user must be logged in)

**Request:**
```json
{
  "videoId": "<string>",
  "userId": "<string>"
}
```

- `videoId`: Unique ID for the video (generate before calling)
- `userId`: Must match `request.auth.uid` (Cloud Function enforces)

**Response:**
```json
{
  "uploadUrl": "https://storage.googleapis.com/...",
  "uploadId": "mux-upload-id"
}
```

**JavaScript (Cloudflare Worker):**
```javascript
const idToken = await auth.currentUser.getIdToken();
const res = await fetch('https://api.streamerstip.com/mux/direct-upload', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${idToken}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({ contentType: 'video/mp4', filename: 'video.mp4' }),
});
const { videoId, uploadUrl, uploadId } = await res.json();
```

**JavaScript (Firebase callable — legacy):**
```javascript
import { getFunctions, httpsCallable } from 'firebase/functions';
const createMuxDirectUpload = httpsCallable(getFunctions(), 'createMuxDirectUpload');
const { data } = await createMuxDirectUpload({ videoId, userId });
const { uploadUrl, uploadId } = data;
```

---

## 2. PUT Video to Mux Signed URL

**Method:** `PUT`  
**URL:** `uploadUrl` from step 1

**Headers:**
| Header           | Value                |
|------------------|----------------------|
| Content-Type     | `video/mp4`          |
| Content-Length   | File size in bytes   |

**Body:** Raw video file bytes (binary)

**App implementation (Dio):**
```dart
await dio.put(
  uploadUrl,
  data: await videoFile.openRead(),
  options: Options(
    headers: {
      'Content-Type': 'video/mp4',
      'Content-Length': fileLength.toString(),
    },
    contentType: 'video/mp4',
  ),
  onSendProgress: (sent, total) => { /* progress */ },
);
```

**Website equivalent (fetch):**
```javascript
const response = await fetch(uploadUrl, {
  method: 'PUT',
  headers: {
    'Content-Type': 'video/mp4',
    'Content-Length': videoFile.size.toString(),
  },
  body: videoFile,
});

if (!response.ok) {
  throw new Error(`Mux upload failed: ${response.status}`);
}
```

**With progress (ReadableStream):**
```javascript
const uploadWithProgress = async (uploadUrl, file, onProgress) => {
  const xhr = new XMLHttpRequest();
  return new Promise((resolve, reject) => {
    xhr.upload.addEventListener('progress', (e) => {
      if (e.lengthComputable && onProgress) {
        onProgress(e.loaded / e.total);
      }
    });
    xhr.addEventListener('load', () =>
      xhr.status >= 200 && xhr.status < 300 ? resolve() : reject(new Error(xhr.statusText)));
    xhr.addEventListener('error', () => reject(new Error('Upload failed')));
    xhr.open('PUT', uploadUrl);
    xhr.setRequestHeader('Content-Type', 'video/mp4');
    xhr.setRequestHeader('Content-Length', file.size.toString());
    xhr.send(file);
  });
};
```

---

## 3. Firestore Video Document (Before Webhook)

Create the video document **after** Mux upload succeeds, **before** or **concurrently** with the webhook. Use `status: 'processing'` when Mux is used so the UI can show "Processing..." until the webhook sets `status: 'ready'`.

**Required fields:**
```javascript
{
  id: videoId,
  userId: userId,
  creatorId: userId,
  creator_id: userId,
  status: 'processing',          // Mux: webhook will set to 'ready'
  videoUrl: '',                  // Empty; webhook fills hlsUrl
  thumbnailUrl: canonicalThumbnailUrl,
  thumbnails: {
    urls: { '360': url, '540': url, '720': url },
    generatedAt: serverTimestamp(),
  },
  caption: caption,
  hashtags: hashtags,
  privacy: privacy,
  allowComments: allowComments,
  category: category,
  categoryId: category,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  views: 0,
  likes: 0,
  comments: 0,
  shares: 0,
  metadata: {
    fileSize: fileSize,
    duration: durationSeconds,
    format: 'mp4',
    uploadedAt: serverTimestamp(),
  },
}
```

**App order of operations:**
1. Moderation (website may implement differently)
2. Generate unique `videoId` (UUID or similar)
3. Generate thumbnail → upload to Storage → get `thumbnailUrl`
4. Call `createMuxDirectUpload(videoId, userId)`
5. PUT video to `uploadUrl`
6. Create Firestore doc with `status: 'processing'`
7. Post-upload: update user count, post counter, tags, feeds (if applicable)

---

## 4. Mux Webhook → Firestore Updates

The `muxWebhook` Cloud Function receives `video.asset.ready` from Mux and updates the video doc.

**Webhook payload (Mux sends):**
```json
{
  "type": "video.asset.ready",
  "data": {
    "id": "mux-asset-id",
    "passthrough": "<videoId>",
    "playback_ids": [{ "id": "...", "policy": "public" }],
    "duration": 123.45
  }
}
```

**Cloud Function updates (`cloud_functions/src/mux.js`):**
```javascript
{
  hlsUrl: `https://stream.mux.com/${playbackId}/high.m3u8`,
  hls_url: same,
  mp4_720_url: same,
  videoUrl: same,
  videoURL: same,
  canonicalPlaybackUrl: same,
  status: 'ready',
  transcodingStatus: 'completed',
  muxAssetId: data.id,
  muxPlaybackId: publicPlayback.id,
  transcodedAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  'metadata.duration': duration  // if provided
}
```

The website does **not** call the webhook; Mux does. Just create the doc and listen/poll for `status === 'ready'`.

---

## 5. Playback (Video URL Resolution)

**App logic (`video_url_resolver.dart`):**
1. Prefer HLS: `hlsUrl`, `hls_url`, any URL containing `stream.mux.com` or `.m3u8`
2. Fallback: MP4 URLs (`mp4_720_url`, `videoUrl`, `videoURL`, etc.)

**Website:** Use the same order. HLS works in browser via hls.js or native `<video>` (Safari). Mux URLs:
```
https://stream.mux.com/{playbackId}/high.m3u8
```

---

## 6. Fallback When Mux Fails

If `createMuxDirectUpload` fails (e.g. no `MUX_TOKEN_ID` in Cloud Functions), the app falls back to:

1. Upload video to Firebase Storage: `videos/{userId}/{videoId}.mp4`
2. Create Firestore doc with `status: 'published'` and `videoUrl` = Storage download URL
3. `transcodeVideo` Storage trigger runs (format check only when Mux is configured; no-op)

**Website fallback:** Same as `WEBSITE_VIDEO_UPLOAD_PATH.md` — upload to Storage, create doc with `status: 'processing'`, let `transcodeVideo` validate format and set `mp4_720_url` / `status: 'ready'`.

---

## 7. Full Website Upload Function (Pseudocode)

```javascript
async function uploadVideoWithMux({
  videoFile,
  caption,
  hashtags,
  privacy,
  allowComments,
  thumbnailUrl,
  category,
  onProgress,
}) {
  const user = auth.currentUser;
  if (!user) throw new Error('Not authenticated');
  const userId = user.uid;
  const videoId = crypto.randomUUID?.() ?? generateUUID();

  // 1. Get Mux signed URL
  const { data } = await createMuxDirectUpload({ videoId, userId });
  const { uploadUrl } = data;

  // 2. PUT video to Mux
  await uploadWithProgress(uploadUrl, videoFile, onProgress);

  // 3. Create Firestore video document
  await setDoc(doc(firestore, 'videos', videoId), {
    id: videoId,
    userId,
    creatorId: userId,
    status: 'processing',
    videoUrl: '',
    thumbnailUrl,
    caption,
    hashtags,
    privacy,
    allowComments,
    category,
    views: 0,
    likes: 0,
    comments: 0,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    metadata: {
      fileSize: videoFile.size,
      format: 'mp4',
      uploadedAt: serverTimestamp(),
    },
  });

  return { videoId, status: 'processing' };
}
```

---

## 8. Listening for Ready Status

**Option A: Firestore listener**
```javascript
onSnapshot(doc(firestore, 'videos', videoId), (snap) => {
  const data = snap.data();
  if (data?.status === 'ready') {
    // Show video, enable playback
  }
});
```

**Option B: Polling**
```javascript
const checkReady = async () => {
  const doc = await getDoc(doc(firestore, 'videos', videoId));
  return doc.data()?.status === 'ready';
};
```

---

## 9. Mux Dashboard Setup (Shared)

1. [dashboard.mux.com](https://dashboard.mux.com) → Settings → Access Tokens
2. Create token → copy `MUX_TOKEN_ID` and `MUX_TOKEN_SECRET` to `cloud_functions/.env`
3. Settings → Webhooks → Add endpoint:
   - URL: `https://us-central1-<PROJECT_ID>.cloudfunctions.net/muxWebhook`
   - Events: `video.asset.rea

---

## 10. Summary Checklist for Website

| Step | App | Website |
|------|-----|---------|
| 1. Generate videoId | `_generateVideoId()` | `crypto.randomUUID()` or UUID lib |
| 2. Thumbnail | Upload to Storage first | Same |
| 3. Call createMuxDirectUpload | `MuxUploadService.createDirectUpload()` | `httpsCallable('createMuxDirectUpload')` |
| 4. PUT to uploadUrl | Dio PUT, Content-Type: video/mp4 | fetch/xhr PUT, same headers |
| 5. Create Firestore doc | status: 'processing' | Same |
| 6. Webhook | Mux → muxWebhook → Firestore | Same (no website action) |
| 7. Playback URL | hlsUrl / hls_url preferred | Same |
| 8. Fallback | Storage upload if Mux fails | Same |

---

## References

- **Worker (preferred):** `workers/`, `docs/MUX_CLOUDFLARE_WORKER_SPEC.md`
- App: `lib/services/mux_upload_service.dart`
- App: `lib/services/video_upload_service.dart` (lines 168–270)
- Cloud Function (legacy): `cloud_functions/src/mux.js`
- Existing doc: `docs/MUX_INTEGRATION.md`
