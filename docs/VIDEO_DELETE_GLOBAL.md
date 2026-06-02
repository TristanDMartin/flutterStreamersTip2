# Global video delete & feed visibility (app + website)

## Delete (required)

Call Firebase callable **`deleteVideo`** in region **`us-central1`**:

```dart
FirebaseFunctions.instanceFor(region: 'us-central1')
    .httpsCallable('deleteVideo')
    .call({'videoId': videoId, 'source': 'app'});
```

Bulk: `deleteVideos` with `{ videoIds: [...] }`.

**Website:** same callables, or `POST /videos/delete` on the Mux Worker (identical soft-delete fields).

### Flutter must NOT

- Hard-delete `videos/{id}` from the client (except draft cleanup in `DraftsService`).
- Local-only deletes without the callable.
- App-only index deletes without updating `videos/{id}`.
- Cached “deleted id” lists that never sync to Firestore.

After delete, optimistic UI removal is fine; the server doc is already soft-deleted.

**Implementation:** `lib/services/video_deletion_service.dart`, `lib/services/video_actions_service.dart`  
**Callable:** `cloud_functions/src/videos/delete_video_callable.js`

## Feed visibility

Hide in **ProfileView, HomeView, Discover, category feeds, StreamerCard, saved/bookmark video lists** when any of:

- `deletedAt != null`
- `isDeleted == true`
- `status == 'deleted'`

Show only when `deletedAt == null` and `status` is one of: `ready`, `published`, `active`.

**Dart:** `lib/utils/video_document_rules.dart` → `isVideoVisibleInFeed` / `isHomeVideoVisibleInFeed`

**Web mirror:** `lib/video/videoVisibility.ts` (website repo)

## Quick test checklist

1. Delete in app → gone on website profile + feeds.
2. Delete on website → gone in app.
3. Deep link to deleted video → “no longer available”.
4. Saved/bookmark video list does not show deleted video.

## Related docs

- `docs/VIDEO_UPLOAD_LIFECYCLE.md` — upload id allocation
- `docs/VIDEO_DELETION_API.md` — callable request/response (if present)
