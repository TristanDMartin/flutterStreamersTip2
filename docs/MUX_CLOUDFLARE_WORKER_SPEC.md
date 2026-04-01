# Mux Cloudflare Worker — Spec & Implementation

**Goal:** Replace Firebase Cloud Functions with Cloudflare Workers for Mux direct upload + webhook. No Cloud Run = no cost surprises. Flutter and Website call the same endpoints.

---

## Architecture

```
┌─────────────────┐     POST /mux/direct-upload      ┌─────────────────────┐
│ Flutter / Web   │ ───────────────────────────────►│ Cloudflare Worker   │
│ (Bearer token)  │     Returns: videoId, uploadUrl  │ api.streamerstip.com │
└────────┬────────┘                                  └──────────┬──────────┘
         │                                                      │
         │ PUT file to uploadUrl                                │ Creates videos/{id}
         │                                                      │ Calls Mux API
         ▼                                                      ▼
┌─────────────────┐                                  ┌─────────────────────┐
│ Mux Storage     │     POST /webhooks/mux           │ Firestore           │
│ (direct upload)│ ───────────────────────────────►│ (Worker updates     │
└────────┬────────┘     video.asset.ready            │  status: ready)     │
         │                                             └─────────────────────┘
         │ transcodes
         ▼
┌─────────────────┐
│ stream.mux.com   │  Playback: HLS
└─────────────────┘
```

---

## Endpoint 1: Create Direct Upload

**URL:** `POST https://api.streamerstip.com/mux/direct-upload`

**Headers:**
| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes | `Bearer <firebase_id_token>` |
| `Content-Type` | Yes | `application/json` |

**Request body:**
```json
{
  "contentType": "video/mp4",
  "filename": "myvideo.mp4",
  "visibility": "public"
}
```

**Response (200):**
```json
{
  "videoId": "abc123",
  "uploadUrl": "https://storage.mux.com/...",
  "uploadId": "uploader_..."
}
```

**Worker logic:**
1. Verify Firebase ID token → extract `uid`
2. Generate `videoId` (UUID)
3. Create Firestore `videos/{videoId}` with:
   - `id`, `userId`, `creatorId`, `creator_id` = uid
   - `status`: `"uploading"`
   - `createdAt`, `updatedAt`: serverTimestamp
4. Call Mux API `POST /video/v1/uploads` with `passthrough: videoId`, `meta.creator_id: uid`
5. Return `{ videoId, uploadUrl, uploadId }`

**CORS:** Must return `Access-Control-Allow-Origin`, `Access-Control-Allow-Headers`, `Access-Control-Allow-Methods` for browser requests.

---

## Endpoint 2: Mux Webhook

**URL:** `POST https://api.streamerstip.com/webhooks/mux`

**Headers:** Mux sends `Mux-Signature` for verification.

**Worker logic:**
1. Verify `Mux-Signature` (HMAC-SHA256, 5‑minute tolerance)
2. Parse body for `type === 'video.asset.ready'`
3. Extract `videoId` from `data.passthrough`
4. Extract `playback_id` (policy: public) from `data.playback_ids`
5. Update Firestore `videos/{videoId}`:
   - `status`: `"ready"`
   - `hlsUrl`, `hls_url`, `mp4_720_url`, `videoUrl`, `videoURL`, `canonicalPlaybackUrl`
   - `muxAssetId`, `muxPlaybackId`
   - `transcodingStatus`: `"completed"`
   - `transcodedAt`, `updatedAt`
   - `metadata.duration` (if provided)

---

## Client Flow (Same for Flutter + Website)

| Step | Action |
|------|--------|
| 1 | Get Firebase ID token |
| 2 | `POST /mux/direct-upload` with token → get `videoId`, `uploadUrl` |
| 3 | `PUT` video file to `uploadUrl` (Content-Type: video/mp4) |
| 4 | Update Firestore `videos/{videoId}` with safe fields: caption, thumbnailUrl, hashtags, privacy, etc. |
| 5 | Listen to Firestore doc until `status === 'ready'` |
| 6 | Playback: `https://stream.mux.com/{playbackId}/high.m3u8` |

---

## Firestore Rules: Server-Only Fields

Clients must **not** be able to set `status` to `"ready"` or write `muxAssetId`, `muxPlaybackId`, `hlsUrl`, etc. Only the Worker (service account) can do that.

**Replace the current `videos` update rule** with one that blocks server-only fields:

```javascript
// In firestore.rules, match /videos/{videoId}:
allow update: if request.auth != null && (
  // Owner can update safe fields only (not playback/status from webhook)
  (request.auth.uid == resource.data.userId
    && !request.resource.data.diff(resource.data).affectedKeys().hasAny([
      'status', 'muxAssetId', 'muxPlaybackId', 'hlsUrl', 'hls_url',
      'mp4_720_url', 'videoUrl', 'videoURL', 'canonicalPlaybackUrl',
      'transcodingStatus', 'transcodedAt'
    ]))
  // Others can still update stats (views, likes, etc.)
  || request.resource.data.diff(resource.data).affectedKeys()
      .hasOnly(['views', 'likes', 'likeCount', 'comments', 'commentCount', 'shares', 
                'isLiked', 'lastViewedAt', 'lastLikedAt', 'lastUnlikedAt', 'isFavorited'])
);
```

The Worker uses Firestore REST API with service account → bypasses rules.

---

## CORS (Website Only)

Worker must handle `OPTIONS` preflight and return:

```
Access-Control-Allow-Origin: https://www.streamerstip.com
Access-Control-Allow-Headers: Authorization, Content-Type
Access-Control-Allow-Methods: POST, OPTIONS
```

---

## Mux Dashboard

1. Webhooks → Add endpoint: `https://api.streamerstip.com/webhooks/mux`
2. Event: `video.asset.ready`
3. Copy signing secret → Store as Worker secret `MUX_WEBHOOK_SECRET`

---

## Migration Path

| Phase | Flutter | Website | Firebase Functions |
|-------|---------|---------|--------------------|
| 1 | Call Worker | Call Worker | Keep as fallback |
| 2 | Worker only | Worker only | Disable createMuxDirectUpload, muxWebhook |
| 3 | — | — | Remove from deploy |

---

## Secrets (Wrangler)

```
MUX_TOKEN_ID
MUX_TOKEN_SECRET
MUX_WEBHOOK_SECRET
FIREBASE_PROJECT_ID
FIREBASE_SERVICE_ACCOUNT_JSON   # or split into key + project
```
