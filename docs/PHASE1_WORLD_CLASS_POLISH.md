# Phase 1 — Make It Feel World-Class

**Status:** Active engineering charter (supersedes celebratory “all phases complete” notes for prioritization)  
**Rule:** Do **not** add major new systems. Harden what exists until users say: *“Wow, this feels polished.”*  
**Last updated:** 2026-07-27

---

## North star

Every engineering hour goes into making these feel incredible:

1. Feed loads instantly  
2. Video playback is flawless  
3. Uploads never fail  
4. Website and app stay perfectly synced  
5. Search always finds creators  
6. Notifications stay in sync  
7. DMs feel instant  
8. Tippy responds naturally  
9. Academy is polished  
10. Scheduling always works  
11. Analytics are accurate  
12. Billing is reliable  
13. Zero crashes  

If a task is a new product surface, a redesign, or a greenfield subsystem — **defer it**. Prefer reliability, latency, sync, empty/error polish, and crash elimination.

---

## How we decide what to work on

| Priority | Meaning | Examples |
|----------|---------|----------|
| **P0** | Breaks trust in the first 30 seconds | Feed blank/slow, black screens, crashes, upload failures, wrong billing/entitlements |
| **P1** | Breaks daily creator workflow | Sync drift, bad search, stale notifications, DM lag, schedule misses, Tippy errors |
| **P2** | Quality polish that elevates “good” → “wow” | Academy UX, Tippy tone, analytics empty states, micro-interactions |

**Default order of hours (until P0 is green on both Android + iOS):**

```
Playback + crashes → Feed cold/warm speed → Uploads → Billing correctness
→ App↔web sync → Search → Notifications → DMs → Scheduling
→ Tippy feel → Analytics accuracy → Academy polish
```

Playback reliability is still the highest launch risk per `PRODUCTION_READINESS_SCORECARD.md`. Do not skip it for polish elsewhere.

---

## Pillar cards (definition of done)

### 1. Feed loads instantly

**Done when:** Warm Home first frame &lt; **600ms**; cold path feels immediate (skeleton → video without dead silence); pull/refresh never strand empty; For You never flashes zero then jumps after a long wait.

**Work in existing systems only:**
- Warm cache / prefetch path (`home_for_you_feed`, GPM pool)
- Non-blocking preload (current + next 2)
- Eliminate blocking ranking / network waterfalls on first paint
- Stable empty + error + retry UI on Home

**SLOs:** `docs/LAUNCH_SLOS.md` (`slo_first_frame`, `slo_cold_first_frame`)

---

### 2. Video playback is flawless

**Done when:** Swipe 10 videos with no black screen, no double audio, swap in **300–600ms**, exactly one active owner; recovery from surface/decode failure without crash; same bar on **Android and iOS**.

**Work in existing systems only:**
- GlobalPlaybackManager + video player disposal / focus / ownership
- Surface remount only on controller change or explicit recovery
- Watchdog → remount once → recreate once → skip unplayable
- Device matrix + feed E2E (`RUN_MOBILE_FEED_E2E`)

**Known risk:** Android `BAD_INDEX` / surface churn telemetry; iOS AVPlayer lifecycle. Scorecard target: Home **8–9/10**.

---

### 3. Uploads never fail

**Done when:** Publish either succeeds or recovers (retry/resume) with a clear state; no silent failures; optimistic profile tiles can retry; background/network loss does not lose the draft.

**Work in existing systems only:**
- `MuxUploadService` / `VideoUploadService` / `UploadStatusManager` / finalize path
- Idempotent finalize; resume incomplete Mux uploads
- User-visible states: uploading → processing → live / failed+retry
- Camera / publish lifecycle: no crash if user leaves mid-upload

---

### 4. Website and app stay perfectly synced

**Done when:** Like, comment, follow, profile fields, plans, Tippy credits, gamification, and scheduled posts match across app and web within real-time expectations (typically &lt;1s for Firestore-backed fields).

**Work in existing systems only:**
- Shared Firestore fields + entitlements API
- `WebsiteSyncService` / creator field normalization (`ownerId` / creator ids)
- Content plans, scheduler queue, Tippy credits, XP state
- Re-run / maintain `SYNC_VERIFICATION_CHECKLIST.md` as a release gate

**Do not:** invent a second source of truth.

---

### 5. Search always finds creators

**Done when:** Typing a known username/display name reliably returns that creator; empty states and errors are clear; debounce feels snappy; no permission-denied dead ends for authed users.

**Work in existing systems only:**
- `SearchApiService` + `SearchScreen`
- Index / query alignment with Firestore rules
- Ranking: exact username → prefix → fuzzy; recent searches that work

---

### 6. Notifications stay in sync

**Done when:** Activity (likes, follows, comments, tags, mentions) and push deep-links match reality; unread badges clear when read; no phantom or missing events after app↔web actions.

**Work in existing systems only:**
- Activity providers / inbox unread
- Notification navigation service
- Preference settings actually gate delivery
- Cross-check write paths (like/comment/follow) emit the same activity docs the UI reads

---

### 7. DMs feel instant

**Done when:** Open Inbox → chat list is fast; send shows optimistic bubble immediately; delivery/read state is trustworthy; no listener storm / setState jank; mute/block/report never break the thread.

**Work in existing systems only:**
- `InboxViewOptimized`, chat services, `UnreadMessagesProvider`, offline inbox cache
- Batch profile/unread listeners (scorecard: Inbox still ~6/10)
- Optimistic send + failure rollback UX

---

### 8. Tippy responds naturally

**Done when:** First token / reply feels responsive; errors are human and recoverable; credit exhaustion is clear with upgrade path; tone matches Tippy identity; no blank hangs; plans/captions land in the right place when Tippy creates them.

**Work in existing systems only:**
- `TippyChatPage` / `TippyChatService` latency and error handling
- Streaming / loading UX (if already supported — polish, don’t rebuild)
- Credit + entitlement messaging aligned with web
- Personality / identity copy consistency (`tippy_identity`)

---

### 9. Academy is polished

**Done when:** Catalog loads reliably; progress/saved sync with web; lessons open cleanly; empty/error/retry states are intentional; navigation feels finished (home → path → guide → lesson).

**Work in existing systems only:**
- Academy views + providers + website sync script/runtime merge
- Progress/`isSaved` consistency
- Visual/interaction polish — no new LMS architecture

---

### 10. Scheduling always works

**Done when:** Schedule from publish → appears in Manage Posts + Content Scheduler + web queue; fires or shows failed/retry; timezone clarity; no ghost jobs or double posts.

**Work in existing systems only:**
- Publish schedule UI + Firestore scheduled post services
- Content Scheduler views (app + `/dashboard/content-scheduler`)
- Worker / finalize path reliability (targeted function fixes only — no new scheduler product)

---

### 11. Analytics are accurate

**Done when:** Insights match real engagement (no mock fill); windows respect entitlements (7/90/365); empty early videos say “not enough data” instead of fake charts; app and web agree on counts for the same video/window.

**Work in existing systems only:**
- Insights + Creator Intelligence + weekly report services
- Aggregation correctness; entitlement window caps
- Empty / loading / error polish

---

### 12. Billing is reliable

**Done when:** Entitlements from API match what Tippy/planner/analytics allow; IAP restore / grace / past_due messaging is correct; upgrade/downgrade doesn’t strand features; app and web show the same tier.

**Work in existing systems only:**
- `SubscriptionSnapshot` / entitlements providers / feature gates
- IAP verification path + Upgrade UI banners
- No hardcoded tier tables for runtime gates (catalog copy only)

---

### 13. Zero crashes

**Done when:** Crash-free sessions ≥ **99.5%** on Android and iOS for a 7-day hold (`HOLD_SLOS_WEEK.md`); no disposed-controller / BuildContext-after-async / null snapshot crashes in browse or publish paths.

**Work in existing systems only:**
- Crashlytics triage → fix top fatals first
- Controller disposal races, mounted checks, Firestore null safety
- Hold week gate before calling launch “done”

---

## Execution waves

### Wave A — Trust (P0) — ship before anything shiny
1. Playback flawless (pillar 2) + crash triage (13)  
2. Feed instant warm/cold (1)  
3. Upload never-fail path (3)  
4. Billing entitlement truth (12)

**Exit:** Device matrix pass + no new browse/publish fatals for 48h.

### Wave B — Daily loop (P1)
5. App↔web sync verification + fixes (4)  
6. Search creator hit-rate (5)  
7. Notifications / Activity sync (6)  
8. DM latency & optimistic UX (7)  
9. Scheduling end-to-end (10)

**Exit:** Sync checklist green; schedule round-trip app↔web green.

### Wave C — Feel (P2)
10. Tippy natural responsiveness & copy (8)  
11. Analytics accuracy & empty states (11)  
12. Academy polish (9)

**Exit:** Users can say “polished” on Tippy + Academy + Insights without caveats.

---

## Engineering rules of engagement

1. **No major new systems** — deepen existing services, providers, and UIs.  
2. **Both platforms** — every P0 fix verified on Android and iOS.  
3. **Measure** — use Launch SLOs / Crashlytics keys; don’t guess.  
4. **User-visible errors** — selectable error + retry; never silent fail.  
5. **One source of truth** — Firestore/API fields shared with web; don’t fork models.  
6. **Fix forward** — if a “complete” doc conflicts with scorecard/SLOs, scorecard wins.  
7. **Small PRs** — one pillar (or one crash class) per PR when possible.

---

## Reference docs (existing — use them)

| Doc | Use for |
|-----|---------|
| `docs/PRODUCTION_READINESS_SCORECARD.md` | Current page scores & gaps |
| `docs/LAUNCH_SLOS.md` | Feed / crash / BAD_INDEX metrics |
| `docs/HOLD_SLOS_WEEK.md` | 7-day go/no-go |
| `docs/PRODUCTION_LAUNCH_CHECKLIST.md` | Device matrix gates |
| `SYNC_VERIFICATION_CHECKLIST.md` | App↔web sync tests |
| `docs/APP_AND_FEATURES_DOCUMENTATION.md` | What the product is (not what to build next) |

---

## Recommended next action

Start **Wave A / Pillar 2 + 13**: playback reliability and top Crashlytics fatals on Home browse + publish. That is the shortest path to “feels world-class” because every other pillar sits on a feed that must not glitch.

When picking a task, ask: *Does this make one of the 13 pillars more true for a real user on a real device?* If not, it waits.

---

## Progress log

### 2026-07-27 — Wave A slice 2 (feed warm-first + swipe sync)

- **Warm-first Home load:** `loadVideos` restores disk/memory feed before network; paints playback window immediately and defers network refresh until after first frame.
- **No blanking warm feed:** empty network startup results keep the visible warm feed instead of clearing For You.
- **Swipe hardening:** defer non-critical PageView jumps while the user is scrolling; still force sync when the visible index is out of bounds after a shrink; clamp `onPageChanged` indices.
- **Helpers + tests:** `shouldKeepWarmFeedOverEmptyNetwork`, `shouldForceFeedIndexSyncDuringScroll`.

**Next Wave A slice:** uploads never-fail (retry/resume + clear failed UI).

