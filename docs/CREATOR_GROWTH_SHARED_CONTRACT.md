# Creator Growth Shared Contract (Flutter ↔ Website ↔ Tippy)

Identical copy lives in `flutterST/docs/CREATOR_GROWTH_SHARED_CONTRACT.md`.

**Firebase project:** `streamerstip-6cfdb`  
**Contract id:** `creator-growth.v1`  
**schemaVersion:** `1`

Clients **display** Creator Score, XP, Level, Streak, mission status, referral rewards, challenge completion, and weekly-report metrics. They **must not** independently calculate those values.

---

## Audit result (do not duplicate)

The example top-level tree (`creatorProfiles/{uid}`, `creatorGrowth/{uid}`, `creatorScores/{uid}`, …) is **rejected**. Those domains already exist under `users/{uid}` and related server collections.

| Domain | Canonical path | Writer |
|--------|----------------|--------|
| Creator profile | `users/{uid}` (+ `publicUsers/{uid}`) | Profile APIs / allowed owner fields |
| Onboarding state | `users/{uid}.onboarding` | Attach / provision / identity ledger |
| Growth plan | `users/{uid}/contentPlans/{planId}` | Tippy / content-planning APIs |
| Creator Score | `users/{uid}/creatorScore/current` | Cloudflare Worker only |
| Score categories | `creatorScore/current.categories` | Same Worker write |
| Missions | `users/{uid}/gamificationMissions/{missionId}` | Worker `/gamification/events` |
| XP / Level / Streak | `users/{uid}/gamification/state` | Worker |
| Achievements | `users/{uid}/gamificationAchievements/{key}` | Worker |
| Referrals | `users/{uid}/creatorReferrals/current` | Reserved, server-only (not built) |
| Challenges | `user_daily_challenges/{userId}_{dateKey}` | Retention APIs |
| Tippy recommendations | `users/{uid}/tippyRecommendations/{id}` | Tippy APIs |
| Weekly report | `GET /api/reports/weekly` | `weeklyReport.server.ts` |
| Growth events | `productEvents/{eventId}` | `POST /api/track` `bus: product` |
| Entitlements | `GET /api/user/entitlements` | Billing resolver |
| Share artifacts | `users/{uid}/growthShareArtifacts/{id}` | Reserved, server-only |

**Forbidden new collections:** `creatorProfiles`, `creatorGrowth`, `creatorScores`, `creatorMissions`, `creatorAchievements`, `creatorReferrals` (top-level), `growthReports` (top-level), `creatorActivity`.

Legacy satellites (read-only / migrate, do not write new): `users/{uid}/missions`, `users/{uid}/achievements`, `users/{uid}.gamification` map, `onboarding/starterMissions`.

---

## Authoritative computers

| Value | Service |
|-------|---------|
| Creator Score + categories | Worker `gamification/creatorScore.js` |
| XP, Level, Streak, mission completion | Worker `POST /gamification/events` |
| Challenge completion | `services/retention/dailyChallengeService.ts` |
| Weekly report metrics | `lib/reports/weeklyReport.server.ts` |
| Entitlements + growth levels | `lib/billing/entitlements.ts` + `growthLevels.ts` (prod: `apiUserEntitlements`) |
| Referral rewards | Reserved Admin API — not implemented |

Flutter / website may cache the last snapshot for UI, then replace it from Firestore or the entitlements/report APIs.

---

## Visibility

| Surface | Rule |
|---------|------|
| Public profile / score badge | `creatorScore/current` is publicly readable; XP/missions/streak are owner-only |
| Weekly report / missions / referrals | Owner (Bearer) |
| Share artifacts | `visibility: public \| private` on server-created docs |
| Entitlements | Owner only |

---

## Product events

Ingest: `POST /api/track` with `bus: 'product'` (or a product event name). Auth: Bearer. Collection: `productEvents`.

Canonical names:

- `onboarding_started`, `onboarding_completed`, `creator_profile_completed`
- `tippy_checkup_started`, `tippy_checkup_completed`
- `growth_plan_created`
- `mission_started`, `mission_completed`
- `creator_score_viewed`, `creator_score_shared`, `profile_shared`
- `referral_sent`, `referral_accepted`
- `weekly_report_opened`
- `paywall_viewed`, `upgrade_started`, `subscription_started`

Aliases stored as the canonical name:

| Incoming | Stored |
|----------|--------|
| `tippy_onboarding_started` | `onboarding_started` |
| `tippy_onboarding_completed` | `onboarding_completed` |
| `content_plan_created` | `growth_plan_created` |
| `growth_report_viewed` | `weekly_report_opened` |
| `upgrade_modal_viewed` | `paywall_viewed` |

Retention lifecycle events stay on `retentionEvents`. Do not mix buses.

---

## Account deletion

Deleted accounts **cannot recover** prior growth state.

1. Recursive wipe `users/{uid}/**` (score, XP, missions, memory, plans, referrals, share artifacts).
2. Wipe `productEvents`, `retentionEvents`, `userRetentionProfiles/{uid}`, `user_daily_challenges`, `notifications/{uid}`.
3. Identity ledger may inherit **only** anti-abuse flags (`hasUsedTrial`, starter quota, Stripe customer). It must **never** copy Score / XP / Level / Streak / missions / achievements / referrals / completed onboarding.

---

## Local vs production

Same contracts in both environments:

- Entitlements payload includes nested `entitlements`, `aiCreditCosts`, and `levels` (`dailyBriefLevel`, `creatorMemoryLevel`, `creatorScoreLevel`, `weeklyReportLevel`, `academyAccessLevel`).
- Score/XP writes are Worker/Admin only (Firestore rules deny client writes).
- Event ingest is `/api/track` (Hosting → `apiRetentionTrack` in production).

---

## Achievements

Catalog: `contracts/achievements.v1.json` (22 launch keys). Worker is the only unlock writer.

| Field | Path / API |
|--------|------------|
| Unlock docs | `users/{uid}/gamificationAchievements/{key}` |
| Celebration queue | `users/{uid}/gamification/state.pendingAchievements` |
| Acknowledge one key | `PATCH /gamification/achievements/{key}/acknowledge` (Worker) and `PATCH /api/gamification/achievements/{key}/acknowledge` (website) |

Clients are read-only against unlocks. Continue acknowledges **one** pending key. Do not write `users/{uid}/achievements/{key}` (`first_steps` is a read alias for `onboarding_done` only).

`first_follower` Worker event, `onFollowCreate` emit, and `GAMIFICATION_INTERNAL_SECRET` are deployed. Confirm with a real follow during the launch smoke test.
