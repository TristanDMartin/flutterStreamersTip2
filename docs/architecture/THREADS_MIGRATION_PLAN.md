# Creator Threads Migration Plan (v2)

Companion to [`THREADS_CONTRACT_V2.md`](THREADS_CONTRACT_V2.md) and [`THREADS_LEGACY_AUDIT.md`](THREADS_LEGACY_AUDIT.md).

## Goals

1. Introduce canonical `threads` SoT without breaking live forum UX.
2. Run **dual-read** (prefer `threads`, else project `forumPosts`) until backfill + parity.
3. New writes go to `threads` once Phase 1 repositories ship behind a feature flag.
4. Retire direct `forumPosts` client writes only after cutover criteria pass.

## Storage decision

| Collection | Role |
|------------|------|
| `threads/{id}` | Canonical Thread (schemaVersion 2) |
| `threads/{id}/replies/{id}` | Canonical replies (map from legacy comments) |
| `threads/{id}/reactions/{id}` | Typed reactions |
| `threads/{id}/participants/{uid}` | Join + lastViewedAt + notificationPreference |
| `threads/{id}/resolution` | Resolution singleton |
| `threadCategories/{id}` | Canonical categories (seed from contract) |
| `threadCategoryFollows/{uid}_{categoryId}` | Category follows |
| `threadInterestSignals/{id}` | Ranking signals |
| `forumPosts` | Legacy dual-read source until cutover |

**ID strategy:** Backfill keeps `threadId == forumPostId` so deep links `/threads/{id}` and Activity `threadId`/`postId` keep working.

## Dual-read algorithm

```
getThread(id):
  doc = threads/{id}
  if doc.exists && schemaVersion >= 2 && !deleted:
    return ThreadDto.fromV2(doc)
  legacy = forumPosts/{id}
  if legacy exists && visible:
    return ThreadDto.fromLegacyProjection(legacy)  // adapter
  return null

listFeed(filter, ...):
  Prefer indexed queries on threads when threads_v2_reads enabled
  Else query forumPosts + project each row through adapter
  Never invent For You / Live membership in the client — server/repo ranks when v2 reads on
```

## Legacy projection rules

| Legacy | Canonical |
|--------|-----------|
| missing type | `question` (`legacyDefaultType`) |
| `status: published` | `open` |
| `category` string | `categoryId` via `legacyCategoryAliases` or passthrough |
| `content` | `body` |
| `linkedVideoId` / `sourceVideoId` | `sourceVideoId` |
| `linkedCommentId` / `sourceCommentId` | `sourceCommentId` |
| `commentCount` | `replyCount` |
| `likes` / `likedBy` | `legacyLikeCount` / `legacyLikedBy` only |
| `bookmarkedBy` | `legacyBookmarkedBy`; `saveCount` = length |
| `followedBy` or `threadFollows` | `followCount` / participant follower role |
| momentum | Adapter may apply **threshold function from contract** for display during dual-read; production ranking owner remains server once CF/Worker job exists |

## Write ownership

| Phase | Creates | Reactions | Momentum | Counters |
|-------|---------|-----------|----------|----------|
| Dual-read (flag off) | Legacy `forumPosts` via existing ForumService | Legacy likes | N/A | Client/legacy |
| Dual-read (flag on) | `threads` via repository | `reactions` subcollection | Server job / callable | Server increments |
| Cutover | `threads` only | v2 only | Server only | Server only |

## Follow model unification

- Web today: `threadFollows/{postId}_{userId}` (authoritative for web toggles).
- Flutter today: unused `followedBy[]`.
- v2: `participants/{uid}` with role `follower` **and** optional mirror doc for notification fan-out.
- Adapter: `isFollowing = threadFollows exists OR followedBy contains uid OR participant.role==follower`.

## Notifications

- Prefer server-authored notifications after cutover (Flutter rules currently deny client create on `forumNotifications`).
- Map high-value types: answer, marked helpful, mention, follow-started, saved resolved, advice update — see product brief.
- Do not 1:1 notify every legacy like after cutover.

## Backfill script (Phase 5)

`scripts/migrate-forum-posts-to-threads.ts` (website repo) / equivalent Admin script:

1. Scan non-deleted `forumPosts`.
2. Upsert `threads/{id}` with projected fields + `schemaVersion: 2`, `migratedFrom: forumPosts`.
3. Copy comments → `replies` (preserve ids where possible).
4. Project `likedBy` → optional one-time `helpful` reactions **or** leave as legacyLikeCount only (prefer leave; no mass reaction spam).
5. Import `threadFollows` → participants.
6. Dry-run + batch resume + checksum counts.

## Feature flags

| Flag | Meaning |
|------|---------|
| `threads_v2_reads` | Clients use ThreadsRepository dual-read |
| `threads_v2_writes` | Creates/replies/reactions go to v2 |
| `threads_v2_ui` | New Creator Threads shells (else legacy UI) |
| `threads_v2_cutover` | Disable legacy ForumService writes |

## Parity checklist (sign before cutover)

- [ ] Create typed thread on web appears in Flutter with same id/counters
- [ ] Create typed thread on Flutter appears on web
- [ ] React helpful increments `helpfulCount` identically
- [ ] Resolve question sets status + resolution doc both sides
- [ ] Momentum matches for same activity window (server)
- [ ] Filters for_you/following/trending/unanswered/live return contract-shaped modules
- [ ] Comment→thread preserves sourceVideoId/sourceCommentId
- [ ] Video delete soft-deletes v2 thread + legacy projection
- [ ] Report thread works on both platforms
- [ ] Gamification `content.thread_created` emits once per create
- [ ] Activity deep links still open detail

## Rollback

1. Turn off `threads_v2_ui` / `threads_v2_writes`.
2. Keep `threads` docs (no destructive rollback).
3. Legacy ForumService paths remain until `threads_v2_cutover`.

## Phase mapping

| Plan phase | Migration work |
|------------|----------------|
| 0 | Audit + contract + this doc |
| 1 | Repositories + adapter + flags |
| 2 | Parallel shells behind `threads_v2_ui` |
| 3 | Typed create/detail + reactions/resolution |
| 4 | Modules/Tippy/gamification |
| 5 | Backfill + cutover + retire legacy writes |
