# Content Planning — Flutter Phases 0–5 Ship Notes

Companion to
[`CONTENT_PLANNING_CONTRACT_V1.md`](./CONTENT_PLANNING_CONTRACT_V1.md) and
[`contracts/content-planning.v1.json`](../../contracts/content-planning.v1.json).

## Ship with the app

| Area | Files |
|------|--------|
| Vocabulary + Phase 3 ids | `content_planning_contract.dart`, `contracts/content-planning.v1.json` |
| Merge workspace items | `content_planning_repository.dart` |
| Worker client | `content_planning_api_client.dart` |
| Link stamps | `firestore_scheduled_post_service.dart` |
| Calendar projections | `user_profile_firestore.dart`, `profile_back_view.dart`, `streamer_card_view.dart` |

## Flutter must keep doing

1. Write `scheduled_posts` as usual (until cutover).
2. After save/update/delete → Worker:
   - `POST/DELETE /api/content-planning/sync-scheduled-post`
3. Calendar CRUD only via Worker:
   - `/api/content-planning/profile-calendar-item`
4. Read calendars from user-doc projections:
   - `contentPlanProfileCalendarEvents`
   - `contentPlanStreamerCalendarEvents`
5. Filter active/upcoming with `calendar_visibility_contract.dart`
   (`isActiveUpcomingCalendarEvent` / `filterActiveUpcomingCalendarEvents`)
6. Never client-write `contentItems`, `publishJobs`, or calendar mirror fields.

## Stable link ids

| Field | Value |
|-------|--------|
| `contentItemId` | `sp_{scheduledPostId}` |
| `publishJobId` | `pj_{scheduledPostId}` |
| `idempotencyKey` | `publish:{uid}:{scheduledPostId}` |

Helpers: `contentItemIdForScheduledPost`, `publishJobIdForScheduledPost`,
`publishIdempotencyKey`.

## New API behavior

- Item PATCH may send `expectedVersion`; `409 VERSION_CONFLICT` → refresh and
  retry (`ContentPlanningVersionConflictException` /
  `ContentPlanningApiClient.patchPlanItem`).
- Planner deletes cascade-cancel linked `scheduled_posts` / publish jobs
  (Flutter may see `status: canceled` on posts).

## Before smoke

1. Redeploy Mux Worker (Phase 3–5 Worker changes).
2. Confirm Flutter API base:
   `https://streamerstip-mux-api.streamerstip.workers.dev`
   (override: `--dart-define=CONTENT_PLANNING_API_BASE=...`).
3. Optional backfill for other accounts (from website repo):

```bash
npx tsx scripts/migrate-content-items-to-workspace.ts --uid=<uid>
npx tsx scripts/migrate-scheduled-posts-to-workspace.ts --uid=<uid>
```

## Smoke checklist

- [ ] Schedule a video → planner + profile calendar; `scheduled_posts` has
      `contentItemId` / `publishJobId` / `idempotencyKey`
- [ ] Add/delete profile calendar event in app → matches website projections
- [ ] No client writes to `workspaces/.../contentItems` or calendar mirror fields
- [ ] Cascade delete on website cancels linked scheduled post in app
- [ ] Past scheduled events leave upcoming calendars (web + Flutter) without
      deleting contentItems; overdue posts become `missed` after grace on sync
