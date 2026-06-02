# Video deletion API (app + website)

## Callable functions

- `deleteVideo` — `{ videoId, source?: 'app' | 'web' | 'admin' }`
- `deleteVideos` — `{ videoIds: string[], source?: string }` (max 50)

Auth: Firebase ID token. Caller must own the video (`userId` / `creatorId`) or have admin claims.

## Canonical document (`videos/{videoId}`)

Soft delete sets:

- `isDeleted: true`
- `deletedAt` (server timestamp)
- `deletedBy` (uid)
- `status: 'deleted'`
- `visibility: 'private'`
- `visible: false`
- `isReadyForFeed: false`

Media (Mux / Storage) is **not** removed immediately.

## Feed queries

Exclude deleted content:

```text
isDeleted != true
status not in ['deleted', 'removed']
```

## Indexes cleaned (server)

- `users/{uid}/videos/{videoId}`
- `feeds/for_you/videos/{videoId}`
- `feeds/following/videos/{videoId}`
- `feeds/categories/{category}/videos/{videoId}`
- `user_videos/{uid}/posts/{videoId}`
- `videos/{videoId}/bookmarks/*`
- `user_favorites/*/videos/{videoId}` (collection group)
- `scheduled_posts` with matching `videoId` → `status: cancelled`

## Audit

`videoDeletionLogs/{autoId}` — `videoId`, `uid`, `ownerId`, `deletedAt`, `source`, `bulkDelete`, `affectedIndexes`.

## Deploy

```bash
cd cloud_functions && npm test
firebase deploy --only functions:deleteVideo,functions:deleteVideos
```
