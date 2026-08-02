# Threads Legacy Audit — forumPosts Read/Write Paths

**Phase 0A deliverable.** Exhaustive inventory of current Threads/forum paths on Flutter and website. Use this as the migration input for Threads v2.

**Date:** 2026-08-02  
**Stores today:** `forumPosts`, `forumPosts/{id}/comments`, `forumCategories`, web-only `threadFollows`, `forumNotifications`, `bookmarks` (web), `reports` (Flutter).

---

## 1. Flutter — ForumService (`lib/services/forum_service.dart`)

| Op | Method | Collection / fields | Callers | Side effects |
|----|--------|---------------------|---------|--------------|
| Read | `getPosts` | `forumPosts` (`deleted==false`, optional `category`; orderBy `createdAt`/`likes`/`updatedAt`) | `ThreadsListView` | May side-write `commentCount` via `_attachLiveCommentCounts` |
| Read | `getPost` | `forumPosts/{id}` | `ThreadDetailScreen` | Same live-count side write |
| Write | `createPost` | Add `forumPosts`: title, content, category, tags, authorId, author, visibility, likes, commentCount, likedBy, bookmarkedBy, followedBy, linkedVideoId?, contentType, timestamps, deleted | `CreateThreadScreen`, share sheet | Attempts `forumCategories.postCount+1`. No gamification |
| Write | `createThreadFromComment` | Same + linkedVideoId, linkedCommentId, sourceComment, tag `from-video-comment` | `CreateThreadFromCommentScreen` | Category postCount; then `CommentsService.linkCommentToThread` |
| Write | `togglePostLike` | likedBy, likes | `ThreadDetailScreen` | None |
| Write | `togglePostBookmark` | bookmarkedBy | **Dead (no UI)** | None |
| Write | `toggleThreadFollow` | followedBy[] on post | **Dead (no UI)** | No forumNotifications writer in Flutter |
| Write | `deletePost` | Soft deleted=true | **Dead (no UI)** | Does not decrement category |
| Read | `getCategories` | `forumCategories` | List + create screens | None |
| Stream | `watchComments` / `watchCommentReplies` | `forumPosts/{id}/comments` | Detail + `ThreadCommentItem` | Avatar enrich |
| Write | `addComment` | comments subdoc + commentCount/replyCount | Detail | Progression `firstCommentMade` only |
| Write | `toggleCommentLike` / `toggleCommentDislike` | likedBy/dislikedBy on comment | Detail / comment item | None |
| Write | `deleteComment` | Soft delete comment + counters | Detail / comment item | None |
| Read | `getVideoDetails` | `videos/{id}` | **Dead** | Embed skipped in detail |

### Flutter ReportService

| Op | Method | Fields | Callers |
|----|--------|--------|---------|
| Write | `reportThread` | `reports` + forumPosts.reportCount/lastReportedAt + user reportCount | `ThreadDetailScreen` |
| Write | `reportThreadComment` | `reports` + commentReportCount | `ThreadCommentItem` |
| Read | `hasUserReportedThread*` | `reports` query | Before report |

### Flutter video-comment bridge

| Op | Method | Fields | Callers |
|----|--------|--------|---------|
| Write | `CommentsService.linkCommentToThread` | `videos/.../comments.linkedThreadId` | After create-from-comment |
| Read | linkedThreadId on video comments | Same | `CommentsView2` open linked thread |

### Flutter activity

| Op | Path | Notes |
|----|------|-------|
| Read/mark-read | `activity_provider` → `forumNotifications` | Client **cannot create** (rules create:false). No Flutter writer for create. |
| Navigate | `ActivityView._openThread` | Opens `ThreadDetailScreen` |

### Flutter Cloud Functions / Workers

| Op | Path | Fields |
|----|------|--------|
| Soft-delete linked posts | `cloud_functions/.../delete_video_side_effects.js` | Query linkedVideoId or videoId → deleted, status=deleted, deletedReason=source_video_deleted |
| Soft-delete linked posts | `cloudflare_workers/mux/src/index.js` | Same soft patch |

---

## 2. Website — forumService (`streamerstipReact/services/forumService.ts`)

| Op | Method | Collection / fields | Callers | Side effects |
|----|--------|---------------------|---------|--------------|
| Write | `initializeDefaultCategories` | `forumCategories` seed | `ThreadsPageContent` | Idempotent |
| Read | `getCategories` | `forumCategories` | Threads, forum embeds, comments, detail | None |
| Write | `createCategory` | `forumCategories` | **Dead** | — |
| Write | `createPost` | `forumPosts` + status published, isDemo false | `ForumPostForm` | Category postCount; **no** gamification emit |
| Write | `createThreadFromComment` | + linkedVideoId, sourceType, sourceVideoId, sourceCommentId, media meta | `CommentsView` | Then `linkCommentToThread` |
| Read | `getPosts` / `getPost` | forumPosts + demo filter | Threads list, embeds, detail | Visibility/follows filter |
| Read | `getUserPosts` | author.uid | My Posts tab | Demo filter |
| Read | `getUserCommentedPosts` | Top-level `forumComments` then getPost | Commented tab | **Likely stale** — live comments are subcollection |
| Read | `getUserLikedBookmarkedPosts` / `getUserBookmarks` | bookmarkedBy / likedBy | **Mostly dead** | — |
| Write | `updatePost` | merge | Detail (source video remount) | — |
| Write | `deletePost` → util | Soft + cascade API | Cards, detail | See §3 |
| Write | `togglePostLike` | likedBy, likes | Cards, detail | Writes `forumNotifications` type like |
| Write | `togglePostBookmark` | bookmarkedBy + `bookmarks` collection | Cards, detail | Mirror bookmarks |
| Write | `toggleThreadFollow` | **`threadFollows/{postId}_{userId}`** | Cards, detail | Does **not** update `followedBy` (desync with UI init) |
| Write | `addComment` | subcollection + counters | Detail | forumNotifications comment/reply |
| Stream | `watchComments` | tree build | Detail | User enrich |
| Write | `toggleCommentLike/Dislike` | comment arrays | Detail | forumNotifications |
| Write | `deleteComment` | soft + counters | Detail | — |
| Write | lock/pin/quote helpers | locked, pinnedCommentIds | **Dead** | — |

### Website delete cascade

| Path | Behavior |
|------|----------|
| `utils/deleteForumPost.ts` → `POST /api/forum/delete` | Soft-tombstone post; hard-delete comments; bookmarks; threadFollows; forumNotifications; decrement category |
| `lib/forum/deleteForumPost.server.ts` | Admin/server cascade |
| CF `deleteForumPost` / `apiForumDelete` | Hosting rewrite parity |

### Website video → thread cascade

| Path | Behavior |
|------|----------|
| `lib/video/deleteVideo.server.ts` + CF `deleteVideo.js` | Soft-delete + full cascade by linkedVideoId / videoId / sourceVideoId |
| CF Worker `appWorker.js` | Soft patch only; **incomplete** cascade |

### Website gaps vs Flutter

| Topic | Website | Flutter |
|-------|---------|---------|
| Follow storage | `threadFollows` docs | `followedBy[]` on post (unused UI) |
| Notifications create | Client writes `forumNotifications` | Rules deny create; no writer |
| Report thread | None | `ReportService` → `reports` |
| Demo filter | `isDemo` / environment / id prefixes | Soft visibility via deleted/status |
| Gamification emit | Not on create | Not on create |

---

## 3. Shared field map (legacy → migration)

| Legacy field | Notes |
|--------------|-------|
| `category` | Category doc id (not display name) |
| `likedBy` / `likes` | Primary engagement today; not v2 reaction model |
| `bookmarkedBy` | Array on post; web also mirrors `bookmarks` |
| `followedBy` | Flutter-only writes (dead); web uses `threadFollows` |
| `linkedVideoId` / `linkedCommentId` | Video-comment bridge |
| `sourceComment` | Snapshot on create-from-comment |
| `sourceType` / `sourceVideoId` | Website richer source fields |
| `commentCount` | Often recalculated client-side (Flutter) |
| `status` | published / deleted (inconsistent) |
| `deleted` / `isDeleted` / `deletedReason` | Soft-delete variants |
| `contentType` | Usually `text` |

---

## 4. Dead / inconsistent surfaces (fix in v2)

1. Flutter bookmark/follow/deletePost/getVideoDetails — implemented, no UI.
2. Web `followedBy` vs `threadFollows` desync.
3. Web `getUserCommentedPosts` queries wrong collection.
4. Category `postCount` client increments may fail rules (`createdBy`-only update).
5. `content.thread_created` defined but not emitted from create paths.
6. Incomplete Worker cascade on video delete vs full CF/server cascade.
7. No shared contract — Dart and TS models drift (web has attachments, locked, pinnedCommentIds, sourceType).

---

## 5. UI entry map

### Flutter

| Surface | File | Ops |
|---------|------|-----|
| Home Threads | `threads_list_view.dart` | getPosts, getCategories, navigate create/detail |
| Detail | `thread_detail_screen.dart` | getPost, comments, like, report |
| Create | `create_thread_screen.dart` | createPost |
| From comment | `create_thread_from_comment_screen.dart` | createThreadFromComment + link |
| Comments | `comments_view2.dart` | bridge + onboarding to Threads |
| Activity | `activity_view.dart` | open thread |

### Website

| Surface | File | Ops |
|---------|------|-----|
| `/threads` | `ThreadsPageContent.tsx` | list, filters, create form |
| `/threads/[id]` | `ThreadDetailClient.tsx` | full engagement |
| Cards | `ForumPostCard.tsx`, `CompactForumPostCard.tsx` | like/bookmark/follow/delete |
| Comments | `CommentsView.tsx` | create from comment |
| Embeds | `ForumSection.tsx`, `CompactForumSection.tsx` | profile/streamer lists |
| Activity | `ActivityPageContent.tsx` | forumNotifications merge |

---

## 6. Rules & indexes (reference)

- Flutter repo: `firestore.rules` forumPosts/comments/categories; `forumNotifications` create denied for clients.
- Web: `threadFollows` own-doc rules; forumNotifications create allowed when `fromUserId==auth`.
- Indexes: composites on deleted + createdAt/likes/updatedAt/category; web also sourceVideoId, author.uid.

---

## Audit complete

Next: `contracts/threads.v2.json`, `THREADS_CONTRACT_V2.md`, `THREADS_MIGRATION_PLAN.md`.
