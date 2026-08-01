# Content Planning — Phase 0 Contract (Flutter)

Locked for Flutter ↔ Mux Worker. Content planning does **not** use
`streamerstip.com` Hosting.

Phases 0–5 ship notes:
[`docs/architecture/CONTENT_PLANNING_FLUTTER_PHASES_0_5.md`](architecture/CONTENT_PLANNING_FLUTTER_PHASES_0_5.md)

Shared field vocabulary:
[`contracts/content-planning.v1.json`](../contracts/content-planning.v1.json)
and `lib/features/content_planning/content_planning_contract.dart`.

## API base (required)

```
https://streamerstip-mux-api.streamerstip.workers.dev
```

Optional override:

```
--dart-define=CONTENT_PLANNING_API_BASE=...
```

Implemented in `ContentPlanningApiClient` /
`kContentPlanningWorkerBase`.

## Auth on every call

- `Authorization: Bearer <Firebase ID token>`
- `Content-Type: application/json`
- App Check header when the build already sends it
  (`X-Firebase-AppCheck` via `buildAuthenticatedHttpHeaders`)

## Endpoints

### 1. Sync scheduled video → planner

**POST** `/api/content-planning/sync-scheduled-post` — returns
`planId` / `itemId` / `publishJobId` / `idempotencyKey`; Flutter stamps
those on `scheduled_posts`.

**DELETE** `/api/content-planning/sync-scheduled-post`

### 2. Profile calendar

- **POST/PATCH/DELETE** `/api/content-planning/profile-calendar-item`
- **POST** `/api/content-planning/migrate-legacy-calendar`
- **POST** `/api/content-planning/sync-profile-calendar`

Reads: `contentPlanProfileCalendarEvents` /
`contentPlanStreamerCalendarEvents` (not re-derived from plans).

## Freeze rules

- Never client-write `contentItems`, `publishJobs`, or calendar mirrors
- Keep writing `scheduled_posts` until cutover
- After save/update/delete scheduled post → Worker sync/delete
- Plan container edits only on `users/{uid}/contentPlans/{planId}`

## Ops dependency

Redeploy Mux Worker (Phase 3–5) before smoke.
