# Content Planning Contract v1

Shared vocabulary for **website** + **Flutter**.

**Storage (Cutover PR1 — workspace-first writes):**
- **SoT writes:** `workspaces/{workspaceId}/contentItems/{itemId}` and `publishJobs/{jobId}` first (fail closed)
- **Mirrors:** then update `users/{uid}/contentPlans/{planId}.items[]` and keep Flutter `scheduled_posts` for publish queue
- Plan containers: `users/{uid}/contentPlans/{planId}`
- Reads merge workspace contentItems over embedded `items[]`; soft-deleted contentItems are excluded
- Calendar mirrors remain read-only projections from contentItems
- **Active calendar visibility:** projections + clients only show events where `endsAt` (or `scheduledAt` + default duration) is still upcoming; cancelled/archived/missed/failed/published are excluded
- Past scheduled items may be marked `missed` after grace during calendar sync — records are retained for history/analytics
- Clients must not edit calendar mirror fields; mutate content items / profile-calendar-item API instead
- Flutter still writes `scheduled_posts` first for the publisher, then syncs SoT via Worker
- Drop embedded `items[]` / `scheduled_posts` only in a later cutover PR

## Calendar visibility contract

Shared helpers: `lib/calendar/calendarVisibility.ts` (web/Worker) and Flutter `calendar_visibility_contract.dart`.

| Rule | Behavior |
|------|----------|
| Upcoming default | `endsAt >= now` (fallback: `scheduledAt` + type default duration) |
| Livestream default duration | 3 hours after start when `endsAt` missing |
| Content post | Leaves upcoming when `scheduledAt` passes |
| Missed grace (content post) | 2 hours after end → status `missed` (not deleted) |
| Cancelled / deleted | Leave active calendar immediately |
| Historical retention | Keep contentItems / publishJobs / analytics refs |
## Files

| Artifact | Path |
|----------|------|
| JSON schema | `contracts/content-planning.v1.json` |
| TypeScript | `types/contentPlanningContract.ts` |
| Workspace item type | `types/workspaceContentItem.ts` |
| Flutter | `lib/features/content_planning/content_planning_contract.dart` |

## Status (canonical)

`idea` → `draft` → `in_progress` → `ready_for_review` → `approved` → `scheduled` → `publishing` → `completed` → `published`

Branches: `changes_requested`, `failed`, `archived`, `cancelled`, `missed`

`completed` means the creator marked the work done. It is **not** publication evidence. `published` is a separate stored status.

### Legacy aliases (normalize on read and write)

| Legacy | Canonical |
|--------|-----------|
| planned, todo, pending | draft |
| recording, editing | in_progress |
| needsReview, needs_review | ready_for_review |
| posted | published |
| done | completed |
| repurpose | archived |
| canceled | cancelled |

Do not alias `completed` to `published`. Existing Firestore rows stored as `published` stay `published` (no backfill).

## Visibility

Product: `private` | `team` | `public`

Storage (unchanged for Phase 1): `profileCalendar` + `streamerCalendar`. Use helpers in the TS/Dart contract modules to map.

## Writes

Always persist **canonical** status strings. Never write `posted`, `needsReview`, or `planned` from new clients.

Item mutations dual-write: update embedded `items[]` **and** upsert/soft-delete `workspaces/{ws}/contentItems/{id}`.

Scheduled-post sync also upserts `workspaces/{ws}/publishJobs/pj_{scheduledPostId}` and stamps link fields on `scheduled_posts`.

**Phase 5 hardening**
- Optimistic concurrency: PATCH with `expectedVersion`; mismatch → `409 VERSION_CONFLICT`
- Soft-delete cascade: item/plan delete soft-deletes contentItem + publishJob, cancels `scheduled_posts`, invalidates open approvals, then calendar rebuild
- Drag-drop: plan-detail kanban/calendar already persist status/date via PATCH (pass `expectedVersion` when known)

Backfill items: `npx tsx scripts/migrate-content-items-to-workspace.ts --uid=<uid>`

Backfill schedules: `npx tsx scripts/migrate-scheduled-posts-to-workspace.ts --uid=<uid>`
