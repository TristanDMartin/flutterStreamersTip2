# App ↔ Website Mux & R2 Alignment

Ensures Flutter app follows the same logic as the website per the [Technical Transition Guide](https://docs.streamerstip.com/mux-migration).

---

## ✅ Aligned Behavior

### 1. Upload Flow (Mux Direct Upload)
| Aspect | Website | App |
|--------|---------|-----|
| Endpoint | `/api/mux/upload` | `POST /mux/direct-upload` (Cloudflare Worker) |
| Flow | Get signed URL → PUT to Mux | Same via `MuxUploadService` |
| Bypass | No Firebase Storage | No Firebase Storage |

### 2. Firestore Schema (videos collection)
| Field | Type | Set By | Description |
|-------|------|--------|-------------|
| `isMux` | Boolean | Worker (create), App (update), Webhook | `true` for all Mux uploads |
| `muxPlaybackId` | String | Webhook | HLS stream ID |
| `muxStatus` | String | App (`processing`), Webhook (`ready`) | `processing`, `ready`, or `errored` |
| `muxUploadId` | String | Worker (create), App (update) | Mux upload session ID |
| `thumbnailUrl` | String | Webhook (image.mux.com) or R2 | Thumbnail URL |

### 3. Webhook Processing
- **Event**: `video.asset.ready`
- **Verification**: `MUX_WEBHOOK_SECRET` (cryptographic)
- **Updates**: `muxPlaybackId`, `hlsUrl`, `thumbnailUrl`, `status`, `isMux`, `muxStatus`, `processingStatus`

### 4. Playback Logic (Unified)
| Source | Priority | App |
|--------|----------|-----|
| Mux HLS | 1st | `muxPlaybackId` → `stream.mux.com/{id}/high.m3u8` |
| Legacy | Fallback | `hlsUrl`, `canonicalPlaybackUrl`, `mp4_720_url` |
| Firebase Storage | Rejected | Bypassed when no Mux (402 avoidance) |

### 5. Thumbnails
| Source | When | App |
|-------|------|-----|
| Mux | Asset ready | Webhook sets `image.mux.com/{playbackId}/thumbnail.jpg` |
| R2 | Pre-upload (website) | Optional; app uses Mux thumbnails when ready |

---

## Code Locations

| Concern | App | Worker |
|---------|-----|--------|
| Upload | `lib/services/video_upload_service.dart` | `cloudflare_workers/mux/src/index.js` |
| Mux API | `lib/services/mux_upload_service.dart` | `handleDirectUpload`, `createMuxUpload` |
| Playback URL | `lib/utils/video_health_gate.dart` | — |
| Webhook | — | `handleMuxWebhook` |
| Avatar/chat | `lib/services/r2_media_service.dart` | `handleMediaUpload` |

---

## Environment Variables

App uses Worker URL; Worker needs:

```env
MUX_TOKEN_ID=...
MUX_TOKEN_SECRET=...
MUX_WEBHOOK_SECRET=...
FIREBASE_WEB_API_KEY=...
FIREBASE_SERVICE_ACCOUNT_JSON=...
MEDIA_PUBLIC_BASE_URL=...  # R2 for avatars/chat
```
