# Video upload & delete lifecycle (app + website)

Single backend-owned flow. Clients must not create `videos/{id}` before Mux upload init.

## Upload (Mux direct upload)

**Endpoint:** `POST https://streamerstip-mux-api.streamerstip.workers.dev/mux/direct-upload`

**Headers:** `Authorization: Bearer <Firebase ID token>`

**Body (optional):**

```json
{
  "videoId": "client-hint-id",
  "userId": "<uid>",
  "isDraft": false
}
```

**Server steps:**

1. `allocateVideoIdForNewUpload` — never reuse deleted, active, or in-progress IDs; generate new ID when needed.
2. Create Firestore `videos/{videoId}` with `status: uploading`, `visible: false`.
3. Create Mux direct upload; patch `muxUploadId`.
4. On Mux failure: `status: failed`, `errorCode: MUX_UPLOAD_CREATE_FAILED`.
5. On Firestore 409: allocate a new `videoId` and retry doc create (no Mux call with stale ID).

**Response:**

```json
{
  "videoId": "video_<ts>_<rand>",
  "uploadUrl": "...",
  "uploadId": "...",
  "replacedClientId": true
}
```

**App:** `OptimisticVideoService.createOptimisticVideo(..., persistToFirestore: false)` then bind `bindServerVideoId` after Worker returns canonical `videoId`.

## Delete (global soft delete)

Both surfaces must call one of:

| Surface | API |
|---------|-----|
| Flutter app | Firebase callable `deleteVideo` / `deleteVideos` |
| Website | Same callables **or** `POST /videos/delete` on Mux Worker (same fields) |

**Firestore fields:**

- `status: "deleted"`
- `deletedAt: serverTimestamp()`
- `deletedBy: <uid>`
- `visible: false`, `isReadyForFeed: false`

Feed/index mirrors under `users/{uid}/videos`, `feeds/*` are removed.

## Visibility filters (app + website)

Exclude when any of:

- `status === "deleted"` (or `removed`)
- `isDeleted === true`
- `deletedAt` is set

Public feed eligibility: `isVideoEligibleForPublicFeed` in `lib/utils/video_document_rules.dart` (Dart) and `video_lifecycle.js` (Worker).

## Mux webhook

Worker skips promoting `videos/{id}` to active when the doc is already soft-deleted.

## Stuck uploads

Scheduled Cloud Function `cleanupStuckUploads` (hourly): marks `uploading` / `pending` / `processing` older than 2 hours as `failed` with `errorCode: UPLOAD_STUCK_TIMEOUT`.

Deploy:

```bash
firebase deploy --only functions:deleteVideo,functions:deleteVideos,functions:cleanupStuckUploads
cd cloudflare_workers/mux && npx wrangler deploy
```
