# StreamersTip Gamification Alignment

## Goal

Gamification must work the same everywhere:

- Mobile app → Website → Desktop later → Admin → Tippy AI

When a user earns XP, levels up, completes missions, unlocks badges, or improves their creator status, it should update globally and instantly across both the app and website.

## 1. Core Rule

**Do not calculate rank separately on the app or website.**

The app and website should only **display** gamification data.

The backend is responsible for:

- XP changes
- Level calculation
- Rank upgrades
- Badge unlocks
- Mission completion
- Streak updates
- Consistency score updates
- Creator status updates

This prevents bugs where the app says Level 4 but the website says Level 2.

## 2. Firestore Source of Truth

Use one shared user gamification document:

`users/{uid}/gamification/state`

Recommended structure:

```json
{
  "uid": "string",
  "xp": 1240,
  "level": 7,
  "rank": "Rising Creator",
  "currentLevelXp": 1000,
  "nextLevelXp": 1500,
  "progressPercent": 48,
  "streakCount": 5,
  "longestStreak": 12,
  "lastActivityAt": "timestamp",
  "consistencyScore": 78,
  "badges": [
    {
      "id": "first_upload",
      "name": "First Upload",
      "unlockedAt": "timestamp"
    }
  ],
  "completedMissions": {
    "upload_first_clip": true,
    "complete_profile": true
  },
  "activeMissions": ["post_3_clips", "connect_twitch", "comment_on_thread"],
  "previousLevel": 6,
  "showLevelUpModal": true,
  "leveledUpAt": "timestamp",
  "updatedAt": "timestamp"
}
```

Legacy fields on `users/{uid}.gamification` remain during migration; clients prefer `gamification/state` when present.

## 3. Rank System (canonical)

Defined in `cloud_functions/src/gamification/level_table.js` and used by all backend writers.

## 4. XP Events

Collection: `gamification_events/{eventId}`

```json
{
  "uid": "user123",
  "type": "content.published",
  "source": "ios_app",
  "createdAt": "timestamp",
  "processed": false
}
```

Clients emit events via `createGamificationEvent()` (Flutter) or the same HTTP contract (website). See `docs/gamification-web.md`.

## 5. Backend Processing Flow

1. User action (upload, profile complete, etc.)
2. Client writes `gamification_events/{eventId}` (create-only) or POST `/gamification/events`
3. Backend validates, dedupes, applies XP/missions
4. Backend updates `users/{uid}` legacy maps + **`users/{uid}/gamification/state`**
5. App and website subscribe to `gamification/state` → instant UI sync

## 6. App and Website Display

Subscribe to:

`users/{uid}/gamification/state`

Display level, XP bar, rank, streak, badges, missions, consistency — **never** compute level-up locally.

## 7. Level-Up Detection

Backend sets `previousLevel`, `level`, `showLevelUpModal`, `leveledUpAt` on state doc. Clients clear `showLevelUpModal` via `progressionSync` action `dismissLevelUpModal` (not client-writable on `gamification/*`).

**Phase B (onboarding):** Retire `users.xp` client writes in `OnboardingService.completeMission`; use `createGamificationEvent` + server `totalXp` only. Phase A already displays level/XP from `gamification/state` in Level 1 checklist UI.

## 8. Mission System

Catalog: `gamification/missions/catalog` (future). User progress: `users/{uid}/gamification/missions/{missionId}` or embedded in state.

## 9. Firestore Security

- `users/{uid}/gamification/*` — owner read; **no client writes**
- `gamification_events/{eventId}` — authenticated create where `uid == auth.uid`; no read/update/delete from clients

## 10. Shared Event API

```dart
await createGamificationEvent(
  type: GamificationEventTypes.contentPublished,
  source: GamificationEventSource.iosApp,
  metadata: {'videoId': id},
);
```

Sources: `ios_app`, `android_app`, `website`, `desktop`, `admin`, `tippy_ai`.

## 11. UI Surfaces (must use same data)

Website and app: profile, creator card, dashboard, planner, progression tab, upload success, onboarding missions.

## 12. Production Checklist

- [ ] Upload on app → XP on website
- [ ] Upload on website → XP on app
- [ ] Profile complete on website → badge on app
- [ ] Connect Twitch on app → mission on website
- [ ] Level up syncs both ways
- [ ] Streak once per day
- [ ] No client XP writes
- [ ] Duplicate events do not double-count
- [ ] Admin can repair state

## Implementation map (this repo)

| Piece | Location |
|-------|----------|
| Canonical levels | `cloud_functions/src/gamification/level_table.js` |
| State sync | `cloud_functions/src/gamification/gamification_state.js` |
| HTTP events | Worker + `gamification_events_http.js` |
| Onboarding tasks | `progression_callable.js` (also syncs state) |
| Flutter read | `GamificationRepository` → `gamification/state` |
| Flutter emit | `create_gamification_event.dart` |
| Web guide | `docs/gamification-web.md` |
