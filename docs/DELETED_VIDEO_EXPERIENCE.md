# Deleted video experience (app + website parity)

When a video is deleted, both surfaces must stay in sync and show a clean unavailable state.

## Backend: delete side effects

Callable `deleteVideo` / `deleteVideos` (`cloud_functions/src/videos/delete_video_callable.js`) and Worker `POST /videos/delete` must:

1. Soft-delete `videos/{videoId}` (`status: deleted`, `deletedAt`, `deletedBy`, …)
2. Remove feed/index mirrors, bookmarks, favorites, scheduled posts
3. Soft-delete related **Threads** (`forumPosts` where `linkedVideoId` or `videoId` matches):
   - `status: "deleted"`
   - `deletedReason: "source_video_deleted"`
   - `deletedAt`, `deleted: true`

Implementation: `cloud_functions/src/videos/delete_video_side_effects.js`

## Feed / list filters

Use `isVideoVisibleInFeed` (Dart) / `isVideoVisibleInFeed` (TS) everywhere:

- Home, Discover, Profile, category feeds, bookmarks, “More from this creator”
- Threads list/detail: hide `status == deleted` or `deletedReason == source_video_deleted`

## Unavailable video page

**App route:** `/video-unavailable` → `VideoUnavailablePage`

**Layout (match website `/video/{id}` when deleted):**

- Simple back header only — **no profile dropdown** on this page
- Centered column: logo → “Video unavailable” → subtitle → Go back
- Side/below panel **About this video** (removed copy + safe metadata only)
- **More from this creator** — public `ready` videos only, excludes deleted
- Owner/admin: **Delete video** → `deleteVideo` callable → pop back

**Do not show:** share, likes/comments, broken URL, full caption for creator-deleted content.

## Achievement toast: First Steps

Firestore: `users/{uid}/achievements/first_steps`

```json
{ "unlocked": true, "seen": true, "seenAt": "<serverTimestamp>" }
```

Check `seen !== true` before showing **“Achievement Unlocked: First Steps”**. Mark `seen: true` immediately after first display.

App: `FirstStepsAchievementService` + one check on `MainTabView` mount.

## Website checklist (mirror app)

- [ ] Unavailable page uses centered logo + no header dropdown on delete actions
- [ ] `deleteVideo` callable (prefer over partial client delete)
- [ ] Thread posts soft-deleted when source video deleted
- [ ] `isVideoVisibleInFeed` on all video lists
- [ ] First Steps toast uses `achievements/first_steps.seen`

## Test plan

1. Delete video in app → gone on website feeds/profile
2. Delete on website → gone in app
3. Thread created from video → hidden after video delete
4. Open deleted video URL → unavailable page (centered UI, about panel, creator list)
5. Owner delete from unavailable page works; non-owner sees no delete button
6. First Steps toast shows once per user only
