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
  "canonicalVideoId": "video_<ts>_<rand>",
  "clientVideoId": "client-hint-id",
  "uploadUrl": "...",
  "uploadId": "...",
  "replacedClientId": true
}
```

**App:** `OptimisticVideoService.createOptimisticVideo(..., persistToFirestore: false)` then bind `bindServerVideoId` after Worker returns canonical `videoId`.

**Website:** after `POST /mux/direct-upload`, discard any locally generated/client-hint ID for display and persistence. Use `canonicalVideoId || videoId` returned by the Worker for profile links, upload state, optimistic cards, and Firestore reads.

## Website profile videos

Website profile sections must read canonical uploaded videos through:

```http
GET /api/profile-videos?userId=<profileUserId>
Authorization: Bearer <Firebase ID token> # optional, required to see owner-only processing/failed/private state
```

The endpoint reads only `videos`, applies the same owner/public rules as the app, and returns:

- owner: non-deleted `processing`, `ready`, `failed`, `published`, `active`
- other viewers: non-deleted public `processing`, `ready`, `published`, `active`

Do not render profile uploads from upload-session caches, local optimistic IDs, `users/{uid}/videos`, or `user_videos/{uid}/posts` unless the item resolves back to an existing canonical `videos/{videoId}` doc.

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
