# `users/{uid}` — Firestore shape the UI reads

Backend owns writes; the app reads via `GamificationMapper` / `DailyMissionModel` (camelCase or snake_case aliases per model).

## `gamification` (map)

`GamificationSummaryModel` accepts **preferred or alias** keys per concept:

| Concept | Preferred keys (any one works per concept) |
|--------|---------------------------------------------|
| Level | `level`, `creatorLevel` |
| Total XP | `totalXp`, `total_xp`, `xp` |
| Streak | `streakDays`, `streak_days` |
| Score | `creatorScore`, `creator_score` |
| Rank label | `rankTitle`, `rank_title` |
| Hint | `nextAction`, `next_action`, `nextSuggestedAction` |
| Last activity | `lastQualifiedActivityAt`, `last_qualified_activity_at` (Timestamp) |
| Updated (server) | `updatedAt` (Timestamp) — optional; worker may set |

Example (logical):

```json
{
  "gamification": {
    "level": 3,
    "totalXp": 450,
    "streakDays": 5,
    "creatorScore": 72.5,
    "rankTitle": "Creator",
    "nextAction": "Publish another video",
    "lastQualifiedActivityAt": "<Firestore Timestamp>"
  }
}
```

## `dailyMissions` and/or `missions` (arrays of maps)

Each item maps per `DailyMissionModel`:

| Field | Aliases |
|-------|---------|
| id | `missionId`, `id` |
| template | `templateId`, `template_id` |
| category | `missionCategory`, `mission_category` |
| window | `type` (e.g. daily, weekly) |
| state | `status` (active, completed, claimed, …) |
| copy | `title`, `description` |
| objective | `objectiveType`, `objective_type` |
| numbers | `target`, `progress`, `rewardXp` / `reward_xp` |
| times | `startsAt`, `expiresAt`, `completedAt` (Timestamp or ISO) |
| claim | `rewardClaimed`, `reward_claimed` |

Example mission object:

```json
{
  "missionId": "m_daily_post_20260401",
  "templateId": "daily_post_one",
  "type": "daily",
  "status": "active",
  "title": "Post 1 piece of content",
  "description": "Publish to your audience",
  "objectiveType": "content.published",
  "target": 1,
  "progress": 0,
  "rewardXp": 25,
  "startsAt": "<start>",
  "expiresAt": "<end of UTC day>",
  "rewardClaimed": false
}
```

When these arrays are **missing or empty**, the app may show template placeholders from `MissionEngine`; **real progress** must be persisted on the server (e.g. Worker + Firestore).

## Part C — Firebase HTTPS (optional fallback)

**Prefer the Cloudflare Worker** for gamification to avoid extra Cloud Functions usage and cost. This path exists only if you need it.

Same HTTP contract as the Worker: **POST** `/gamification/events`, **Authorization: Bearer** Firebase ID token, same JSON body. Implemented as `gamificationEvents` in `cloud_functions` (`admin.auth().verifyIdToken`, idempotent `gamification_events/{eventId}` create, mission + XP via Admin SDK).

The app posts to **`…/gamification/events`** on the Worker; for Firebase use the **full** `…/gamificationEvents` URL via **`kGamificationEventsBaseUrl`** / `--dart-define=GAMIFICATION_EVENTS_BASE_URL=...` (`GamificationEventService` detects `cloudfunctions.net` and does not append a path). Override `gamificationEventServiceProvider` if you inject `baseUrl` manually.

## Part D — End-to-end checklist (do in order)

**Prefer the Cloudflare Worker** (`cloudflare_workers/mux`). Use the optional Firebase HTTPS function only if you intentionally need it.

1. **Implement (or verify)** the handler: auth + validation + **idempotent** create on `gamification_events/{eventId}` + Firestore updates to `users/{uid}` (and `gamification_audit/{eventId}`). See Worker `handleGamificationEvent` + `applyGamificationMissions`, or `cloud_functions` `gamification_events_http.js`.

2. **Deploy** Worker: `cd cloudflare_workers/mux && npm run deploy`. If using Firebase: `firebase deploy --only functions:gamificationEvents` (optional).

3. **Secrets / env** (Worker — see `cloudflare_workers/mux/README.md` and `wrangler.toml`):
   - `wrangler secret put FIREBASE_WEB_API_KEY`
   - `wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON`
   - `[vars]` `FIREBASE_PROJECT_ID` aligned with production
   - `RATE_LIMIT_KV` is for `/mux/direct-upload` only, not gamification idempotency.

4. **`curl` smoke test** — real Firebase **ID token** (from a signed-in debug build, or `curl` to your auth flow). Expect **2xx** and `{"ok":true}`:

   ```bash
   export TOKEN='paste_id_token_here'
   export BASE='https://streamerstip-mux-api.streamerstip.workers.dev'  # or your Worker URL
   curl -sS -X POST "$BASE/gamification/events" \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"eventId":"test-manual-uuid","uid":"<SAME_UID_AS_TOKEN>","type":"content.published","source":"curl"}'
   ```

   Use a **new UUID** for `eventId` each time when testing “first write”; reuse the **same** `eventId` for the idempotency check (step 8).

5. **App** — Sign in, open **Progression**. Summary / missions should match Firestore (`users/{uid}`) if mission rows exist; empty arrays may show placeholders until missions are materialized server- or client-side.

6. **Trigger `content.published`** — e.g. publish a draft or use scheduled **publish now** so the app calls `emitTrustedEvent` with `content.published` after a real publish succeeds.

7. **Firestore console** — Confirm:
   - `gamification_events/{eventId}` document exists for new events
   - `users/{uid}.gamification` / `dailyMissions` / `missions` updated when templates match
   - `users/{uid}/gamification_audit/{eventId}` after processing

8. **Idempotency** — Send the **same** request again (same `eventId`, same `uid`, same `type`). Expect **200** `{ "ok": true }` and **no second XP** (e.g. `totalXp` unchanged, audit row already present). If you only repeat `curl` with a new `eventId`, you are not testing duplicate protection.
