# Video System Shared Contract (Flutter ↔ Website)

Both clients must follow this contract. Identical copy lives in `flutterST/docs/VIDEO_SYSTEM_SHARED_CONTRACT.md`.

**Eligibility, account deletion, and onboarding meanings:** `docs/CANONICAL_CONTRACTS.md` (identical in both repos). If this file disagrees, that file wins.

**Firebase project:** `streamerstip-6cfdb`  
**Canonical collection:** `videos/{videoId}`  
**schemaVersion:** `1`

Do **not** use `source` / `sourcePlatform` to decide visibility. Both platforms have equal visibility rules.

---

## 1. Canonical schema

### Required fields (every create / save)

| Field | Type | Rule |
|-------|------|------|
| `ownerId` | string | Uploader Firebase Auth UID (primary ownership key) |
| `userId` | string | Same UID (compat) |
| `creatorId` | string | Same UID (compat) |
| `isDeleted` | boolean | Always `false` on create |
| `status` | string | Lifecycle status (see below) |
| `createdAt` | timestamp | Server timestamp on create |
| `updatedAt` | timestamp | Server timestamp on every write |
| `schemaVersion` | number | `1` |

### Recommended / Mux fields

| Field | Type | Notes |
|-------|------|-------|
| `creator_id`, `uid`, `authorId`, `user_id` | string | Same UID aliases for legacy readers |
| `isMux` | boolean | `true` for Mux pipeline |
| `muxUploadId` | string | Set at bootstrap |
| `muxAssetId` | string | Set by webhook |
| `muxPlaybackId` | string | Set by webhook |
| `muxStatus` | string | `waiting` → `ready` / `errored` |
| `hlsUrl` / `canonicalPlaybackUrl` / `videoUrl` | string | Mux HLS URL |
| `thumbnailUrl` | string | R2 or Mux image URL |
| `caption`, `title`, `description` | string | |
| `hashtags` | string[] | |
| `category` / `categoryId` | string | |
| `privacy` | string | `Everyone` / `Connections` / `Private` (or lowercase) |
| `visibility` | string | `public` / `followers_only` / `private` |
| `isPublic` | boolean | Derived from privacy |
| `allowComments` | boolean | |
| `visible` | boolean | Feed gate; `false` until publishable |
| `isReadyForFeed` | boolean | Feed gate; `false` until publishable |
| `publishedAt` | timestamp | When exposed to public feeds |
| `deletedAt` | timestamp \| null | Soft delete |
| `source` / `sourcePlatform` | string | Diagnostics only (`flutter` / `web` / `app`) |

### Ownership resolution order (all clients)

```
ownerId → userId → user_id → creatorId → creator_id → uid → authorId → uploadedBy
```

Never use username/displayName as the ownership key.

---

## 2. Status values

| `status` | Meaning |
|----------|---------|
| `uploading` | Worker bootstrap / bytes in flight |
| `pending` | Queued |
| `processing` | Mux ingest / metadata save |
| `ready` | Playable (preferred terminal success) |
| `published` | Legacy success synonym |
| `active` | Legacy success synonym |
| `draft` | Owner-only draft |
| `failed` | Owner-visible failure |
| `deleted` / `removed` | Soft-deleted |

---

## 3. Visibility values

| Field | Public | Connections | Private |
|-------|--------|-------------|---------|
| `privacy` | `Everyone` / `public` | `Connections` / `connections` | `Private` / `private` |
| `visibility` | `public` | `followers_only` | `private` |
| `isPublic` | `true` | `false` | `false` |

---

## 4. Profile / streamer grid query

```text
videos
  where ownerId == profileUserUid
  where isDeleted == false
  orderBy createdAt desc
```

- Newest first.
- Do not use `users/{uid}/videos` for display order.
- Legacy fallback (migration only): `userId == uid` + `isDeleted == false` when the entire `ownerId` page is empty.
- Owner may see: `uploading`, `pending`, `processing`, `ready`, `published`, `active`, `failed`, `draft`.
- Public viewers: public privacy + status in `uploading|pending|processing|ready|published|active` (not `failed`/`draft`/`deleted`).
- Mux rows without `muxPlaybackId` and without thumbnail: show to **owner** as processing; hide from **public** until playback or thumbnail exists.
- Do not filter by `source` / `sourcePlatform`.

---

## 5. Public feed eligibility

A video is feed-eligible when **all** of these are true (Flutter and web identical):

1. Not deleted (`isDeleted` / `status` / `deletedAt`)
2. `status` ∈ `{ready, published, active}`
3. Public privacy
4. `visible !== false`
5. `isReadyForFeed !== false` (explicit `false` excludes; **missing allowed** for legacy playable docs **only if the owner is resolved**)
6. A resolvable owner id (`ownerId` | `userId` | `uid` | `creatorId` | `authorId`). Missing owner id = **not** feed eligible
7. Owner record exists and is renderable: `ownerActive !== false`, `feedEligible !== false`, and the owner `users`/`publicUsers` doc exists. Missing owner record = **not** feed eligible. Missing `ownerActive` / `feedEligible` is **not** assumed true unless ownership is resolved. Explicit `accountStatus` in `{deactivated, deleting, deleted, banned, suspended, disabled}` hides. Missing/empty `accountStatus` on an existing non-deleted owner is legacy-active.
8. **Playable media** via `hasPlayableVideo` — any of:
   - non-empty `muxPlaybackId` / `mux_playback_id`
   - OR valid HTTP(S) `canonicalPlaybackUrl`
   - OR valid HTTP(S) `hlsUrl` / `hls_url`
   - OR valid HTTP(S) `playbackUrl` / `videoUrl` / `videoURL`

Do **not** require only the newest Mux field shape. HLS-only legacy docs must stay visible.
`isReadyForFeed=true` with **no** playable URL remains excluded.

Clients must **not** independently invent READY. Mux webhook / backend finalization sets
`status`, `isReadyForFeed`, and playback URLs for **new** uploads.

Canonical lifecycle (preferred vocabulary):

`DRAFT` → `UPLOADING` → `PROCESSING` → `READY`  
Failure: `FAILED` / `UPLOAD_FAILED` / `PROCESSING_FAILED`  
Tombstone: `DELETED`

Firestore stores lowercase: `draft`, `uploading`, `processing`, `ready`, `failed`, `deleted`
(plus legacy `published` / `active` as READY synonyms).

---

## 6. Edit permissions

- Only owner (resolved via ownership order above) or authorized admin/team.
- Editable: caption, description, hashtags, thumbnail, visibility/privacy, allowComments, category, tags, schedule metadata.
- Every successful edit sets `updatedAt` server timestamp.
- Validate server-side; do not trust client-only checks.

---

## 7. Delete behavior

Centralized only:

| Surface | Entry |
|---------|--------|
| Web | `POST /api/video/delete` → `lib/video/deleteVideo.server.ts` |
| Flutter / CF | Callable `deleteVideo` + `apiVideoDelete` → `cloud_functions/functions/video/deleteVideo.js` |

**Immediate public contract** (synchronous tombstone before cascade finishes):

```json
{
  "status": "deleted",
  "isDeleted": true,
  "visible": false,
  "isReadyForFeed": false,
  "feedEligible": false,
  "ownerActive": false,
  "deletedAt": "<serverTimestamp>",
  "deletedBy": "<uid>"
}
```

After this write, Flutter and web must treat the video as gone from feeds, profiles,
StreamerCard Video tab, and public pages. Physical cleanup (Mux, R2, Storage, indexes)
may be asynchronous and retriable, but **public access disappears immediately**.

Then cascade: profile mirrors, likes/bookmarks, comments, forum threads, notifications,
feed indexes, Mux asset, storage objects, counters. See `docs/VIDEO_DELETE_GLOBAL.md`.

All normal queries must exclude deleted videos.

---

## 8. Cascade deletion rules

Deleting a video must remove or archive:

- Comments / replies
- Threads created from the video
- Notifications linking to the video
- Saved / favorites / tags
- Feed index entries
- Search index entries (when present)
- Scheduled publish jobs

No permanently broken deep links to active video pages.

---

## 9. Cache invalidation

| Client | Expectation |
|--------|-------------|
| Website | Profile cache TTL ≤ 2 minutes; invalidate on delete/edit/upload; refetch on window focus |
| Flutter | Invalidate Riverpod/in-memory feed + profile providers on upload/edit/delete |

Edited/deleted/new videos must appear without logout or reinstall.

---

## 10. API / Cloud Function contracts

| Operation | Endpoint |
|-----------|----------|
| Mux bootstrap | `POST {MUX_WORKER}/api/mux/direct-upload` |
| Thumbnail | `POST {MUX_WORKER}/api/media/upload` |
| Metadata save | `POST /api/video/save` |
| Delete | `POST /api/video/delete` or callable `deleteVideo` |
| Profile grid | `GET /api/profile-videos?userId=` |

**Mux Worker source of truth:** website repo `cloudflare-workers/` (`streamerstip-mux-api`). Do not deploy Flutter’s `cloudflare_workers/mux` to production.

---

## 11. Schema versioning

- Current: `schemaVersion: 1`
- Writers set `schemaVersion` on create/save.
- Migrations backfill missing required fields without deleting legacy data until validated.
- Future breaking changes increment `schemaVersion` and ship dual-read until backfill completes.

---

## 12. Account visibility invariant

A deactivated, deleting, or deleted UID must become globally non-renderable
immediately across web and Flutter. Clients must not reconstruct a creator from
denormalized video fields when `users/{uid}` / `publicUsers/{uid}` is missing or
tombstoned. StreamersTip does not support orphaned creator videos.

A Firebase Auth deletion — StreamersTip, Admin SDK, or Firebase Console — must
run the same cascade. `onAuthUserDeleted` reconciles leftover owner docs and
owned videos when Auth is removed outside `POST /api/account/delete`.

Auth gone + leftover `users/{uid}` (even with missing or `active` accountStatus)
is not a live account. Tombstone it.

Production invariant: `ORPHAN_PUBLIC_VIDEO_COUNT` must equal `0`. An orphan
public video is `status == ready`, `isDeleted != true`, and either has no owner
identifier, the owner record cannot be resolved, the owner is not renderable,
or Firebase Auth for that owner no longer exists.
Check with `npm run check:orphan-public-videos`.

Deactivate (`POST /api/account/deactivate`): `accountStatus = deactivated`.
Hide profile and videos immediately. Retain data and Auth. Do not set
`isDeleted` or delete Mux.

Delete (`POST /api/account/delete`):

`ACCOUNT_DELETE_BEGIN` → `ACCOUNT_TOMBSTONED` → `VIDEOS_HIDDEN` → cascade →
`AUTH_DELETE_COMPLETE` → `ACCOUNT_DELETE_COMPLETE`

On start: `users.accountStatus = deleting`, owned videos stamped
`ownerActive: false`, `feedEligible: false`, `isDeleted: true`.
Physical cleanup may finish later; public visibility stops on the stamp.
Never delete Mux/HLS before the Firestore hide stamp.
