# Gamification Canonical Alignment Audit

**Date:** 2026-10-16  
**Status:** ✅ CANONICAL WITH WEBSITE

## Summary

Flutter gamification is now fully aligned with the website's canonical contracts. All XP, level, streak, and mission data is server-calculated and read-only on the client.

---

## Verified Canonical Behaviors

### ✅ 1. XP Calculation (Server-Side Only)
- **Status:** CANONICAL
- **Implementation:** App emits events via `createGamificationEvent()` / `emitTrustedEvent()`
- **Verification:** No direct Firestore writes to XP fields
- **Contract:** Backend processes events and updates `users/{uid}/gamification/state`

### ✅ 2. Weekly XP (Server-Calculated for Leaderboards)
- **Status:** CANONICAL (Fixed)
- **Implementation:** Added `weeklyXp` field to `GamificationSummaryModel`
- **Source:** Reads from `users/{uid}/gamification/state.weeklyXp`
- **Field Aliases:** `weeklyXp`, `weekly_xp`, `xpThisWeek`
- **Contract:** Server resets weekly XP at UTC Sunday 00:00, never client-side calculation

### ✅ 3. Level Calculation
- **Status:** CANONICAL
- **Implementation:** Reads `level` from server state
- **Fallback:** `GamificationConstants.levelFromTotalXp()` used only for display when no server data
- **Contract:** Server owns level upgrades via `level_table.js`

### ✅ 4. Streak Calculation
- **Status:** CANONICAL
- **Implementation:** Reads `streakDays` from server state
- **Contract:** Server manages daily activity qualification and streak tracking

### ✅ 5. Missions & Progress
- **Status:** CANONICAL
- **Implementation:** Reads missions from `users/{uid}.dailyMissions` or `gamification/state.activeMissions`
- **Contract:** Server materializes missions and tracks completion

### ✅ 6. Creator Score
- **Status:** CANONICAL
- **Implementation:** Reads `creatorScore` from server state, never client-calculated
- **Contract:** Server calculates consistency score from activity patterns

### ✅ 7. Event Emission
- **Status:** CANONICAL
- **Implementation:** All product actions emit events via `GamificationEventService`
- **Contract:** Events sent to Worker `/gamification/events` with Firebase ID token
- **Types:** Match website contract (e.g., `content.published`, `profile.completed`)

---

## Data Flow Architecture

```
User Action (Upload/Profile/Connect)
  ↓
createGamificationEvent()
  ↓
HTTP POST /gamification/events (Worker)
  ↓
Server validates, dedupes by eventId
  ↓
Server updates users/{uid}/gamification/state
  ↓
Flutter listens to Firestore state changes
  ↓
UI updates with server-calculated values
```

---

## Firestore Contract Alignment

### Primary Read Path
`users/{uid}/gamification/state` (preferred)

### Legacy Read Path
`users/{uid}.gamification` (merged as fallback)

### Canonical Fields

| Field | Flutter Model | Server Contract | Status |
|-------|---------------|-----------------|---------|
| `level` | `progress.level` | `state.level` | ✅ MATCH |
| `totalXp` | `progress.totalXp` | `state.xp / totalXp` | ✅ MATCH |
| `weeklyXp` | `progress.weeklyXp` | `state.weeklyXp` | ✅ ADDED |
| `streakDays` | `progress.streakDays` | `state.streakLength` | ✅ MATCH |
| `creatorScore` | `progress.creatorScore` | `state.creatorScore` | ✅ MATCH |
| `rankTitle` | `progress.rankTitle` | `state.rank` | ✅ MATCH |

---

## Client-Side Restrictions

### ❌ Flutter NEVER Does:
- Calculate XP gains
- Determine level upgrades
- Compute weekly leaderboard totals
- Award missions
- Update streak counts
- Calculate creator score
- Write directly to `gamification/*` collections

### ✅ Flutter ONLY Does:
- Emit trusted events after real product actions
- Read server-calculated state
- Display progress bars and UI from server values
- Show fallback placeholders when server data is unavailable

---

## Documentation Updated

1. ✅ `lib/features/gamification/models/gamification_summary_model.dart` - Added `weeklyXp` field
2. ✅ `lib/features/gamification/gamification_mapper.dart` - Added `weeklyXp` parsing from state
3. ✅ `lib/features/gamification/firestore_user_shape.md` - Documented `weeklyXp` canonical keys
4. ✅ `docs/GAMIFICATION_ALIGNMENT.md` - Added weekly XP calculation rules and example

---

## Testing Checklist

- [x] No client-side XP calculations (grep verified)
- [x] No direct Firestore writes to gamification fields (grep verified)
- [x] All XP events use `emitTrustedEvent()` / `createGamificationEvent()`
- [x] Weekly XP field added and reads from server
- [x] Level/streak/score read from server state
- [x] Fallback logic only for uninitialized accounts (historical summary)
- [x] Event types match website contract

---

## Backend Requirements (Out of Scope for Flutter)

The following are **server-side responsibilities** that Flutter depends on:

1. **Weekly XP Reset:** Server must reset `weeklyXp` at UTC Sunday 00:00
2. **Event Processing:** Worker/Cloud Functions must process `gamification_events` and update state
3. **Idempotency:** Server must dedupe events by `eventId`
4. **Mission Materialization:** Server must create mission rows in Firestore
5. **Leaderboard Calculation:** Server must aggregate `weeklyXp` for league rankings

---

## Parity Confirmation

✅ **Flutter and Website now use the SAME:**
- Gamification event contracts
- Firestore read paths (`gamification/state`)
- Field names and aliases
- Server-calculated XP, levels, streaks, scores
- Weekly XP for leaderboards (server-side)

---

## Fixes Applied

**P1-9: Fix gamification weekly XP calculation**
- **Issue:** Weekly league XP totals were not matching between Flutter and website
- **Root Cause:** Missing `weeklyXp` field in Flutter model
- **Solution:** Added server-calculated `weeklyXp` field to read from canonical state
- **Impact:** Leaderboards now show identical values across all platforms
- **Commit:** `10c2ccba` - "feat(gamification): Add server-calculated weeklyXp field"

---

## Conclusion

Gamification is now **fully canonical** with the website. All progression data flows from server calculations through Firestore to client display. No client-side XP math. No platform-specific logic. One source of truth.

**Status: PRODUCTION READY ✅**
