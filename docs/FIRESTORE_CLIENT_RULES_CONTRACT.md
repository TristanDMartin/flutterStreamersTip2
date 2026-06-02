# Firestore Client Rules Contract

**Last updated:** 2026-05-19

This is the production contract between mobile/web clients and Firestore rules.
Anything not listed here should be treated as server-only until it is added with
tests.

## Home Feed Happy Path

| Path | Client access | Current purpose | Notes |
|---|---|---|---|
| `videos/{videoId}` | read/list when allowed by published/privacy rules | Feed, profile grids, player | Client may update only allowed counters/owner fields per rules. |
| `videos/{videoId}/comments/{commentId}` | read/list, create/update/delete by author rules | Comments sheet and comment counts | Keep top-level `comments` collection behavior aligned. |
| `videos/{videoId}/bookmarks/{uid}` | own-user read/write | Saved-video state | Collection-group rules also allow user-scoped bookmark reads. |
| `users/{uid}` | read public profile fields; own-user update subset | Profile, auth session, liked video cache | `liked_videos` array is the canonical fast like lookup. |
| `users/{uid}/likedVideos/{videoId}` | own-user read/write | Legacy/cross-device like validation | Keep until old clients are retired. |
| `users/{uid}/deviceTokens/{token}` | own-user write/delete | FCM registration | Token document id should match the token being written/deleted. |
| `user_interactions/{interactionId}` | authenticated create | ML recommendation signals | Client should swallow/log-low permission failures; server aggregation owns analytics rollups. |
| `tags/{tagId}` | authenticated read/list; tagger write | Tagged-user overlay in feed/player | Query shape: `where(videoId == ...)`. Requires deployed index support. |
| `video_analytics/{videoId}` | authenticated counter update where allowed | Lightweight view counter | Production aggregation should move to server-owned events/rollups. |
| `notifications/{uid}/items/{id}` | owner read/write allowed paths | Activity/notification surfaces | Prefer server-created notifications for social actions. |

## Server-Only Or Admin-Only

| Path | Reason |
|---|---|
| `tippy_rate_limits/{id}` | Rate limiting must not be client mutable. |
| `tippy_usage_events/{id}` | Usage/credits must be written by trusted functions. |
| Billing entitlement and purchase verification documents | Store verification must be server-owned. |
| Moderation/admin report status fields | Admin or function updates only. |
| Analytics aggregation rollups beyond simple counters | Prevent client-forged insights. |

## Required Regression Checks

- `firebase emulators:exec --only firestore` rules tests for likes, FCM tokens,
  interactions, tags, and bookmarks.
- `scripts/mobile_feed_playback_matrix.sh` must report
  `permission_denied_count=0` during normal Home browsing.
- Any new client query must add one of:
  - a rules test proving it is allowed for the intended user, or
  - client gating so unauthorized users never issue it.

## Open Items

- Add/confirm the Firestore index for `tags where videoId == <id>` used by
  `VideoPlayerViewOptimized._fetchTaggedUsers`.
- Move `video_analytics` writes to a server-owned event pipeline before wide
  launch, or keep the allowed client counter fields narrowly constrained.
- Audit old `likedVideos` legacy reads after the minimum supported app version
  no longer needs them.
