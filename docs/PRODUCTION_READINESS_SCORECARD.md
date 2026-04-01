# Production Readiness Scorecard

**Last updated:** 2026-02-03

## On-track summary (at a glance)

| Area | Status | Notes |
|------|--------|--------|
| **Feed playback** | 🔴 Not there | Only first video plays; second+ do not. See `TIKTOK_VIDEO_FEED_SPEC.md` and Phase 2.3 / Option B. |
| **Profile / data alignment** | ✅ Done | Canonical owner (**getOwnerId**); VideoService + RealUserDataService aligned; profile 0→2 mismatch fixed. Optional: backfill **ownerId** in Firestore. |
| **Home (For You)** | 🟡 Alpha (5/10) | BAD_INDEX / disposal guards; focus/owner consolidated; key strategy stabilized. |
| **Full-screen Player** | 🟢 Beta (7/10) | Shares decoder stack; focus aligned with Home. |
| **Profile** | 🟢 Beta (7/10) | Stable; canonical owner in place. |
| **Firestore / rules** | 🟡 In progress | Permission-denied cleanup; rules contract doc pending. |

---

## Rubric (1–10)
- **9–10**: production-ready (stable, performant, good UX, errors handled)
- **7–8**: beta-ready (minor issues, no blockers)
- **5–6**: alpha-ready (known issues, needs hardening)
- **1–4**: not ready (crashes, broken flows, severe jank)

## Page / Flow Scores

| Page / Flow | Score | Status | Primary blockers |
|---|---:|---|---|
| **Home (For You / Following)** (`HomeView`) | **5/10** | Alpha | Android **MediaCodec/Surface `BAD_INDEX`** (Phase 2.3 disposal guards pending); permission-denied noise; some videos show error screen (missing quality variants). Fixed: focus/auto-play, key strategy, first-video autoplay, swipe-to-next |
| **Full-screen Player** (`PlayerScreen`) | **7/10** | Beta | Shares same decoder stack; needs reduced Firestore listener noise. Focus/owner aligned with Home fixes |
| **Network** (`NetworkView`) | **6/10** | Alpha | Large stateful widget, many realtime listeners, potential permission-denied + paging edge cases; good: blocks playback immediately |
| **Discover** (`DiscoverView`) | **6/10** | Alpha | Heavy real-time subscriptions/timers; mixes feed video playback inside discover; needs standardized error UI + permission rules alignment |
| **Profile** (`ProfileViewOptimized`) | **7/10** | Beta | Generally stable; **canonical owner (getOwnerId)** unifies VideoService + RealUserDataService so profile video count no longer flips 0→2; relies on PlayerScreen for playback |
| **Streamer Card** (`StreamerCardView`) | **5/10** | Alpha | Very large surface area + many listeners; frequent queries; needs clearer state model + stricter lifecycle and permission-gated reads |
| **Inbox** (`InboxViewOptimized`) | **6/10** | Alpha | Many per-chat listeners (unread counts, profiles) + setState churn; needs batching and clear failure UI |
| **Search** (`SearchScreen`) | **7/10** | Beta | Good debounce; needs consistent error UI patterns + result typing/empty states polish |
| **Bookmarks** (`BookmarkView`) | **6/10** | Alpha | Works but uses SnackBars for errors; stream subscription lifecycle could be managed more explicitly |
| **Settings** (`SettingsView`) | **8/10** | Beta+ | Mostly static UI; needs wiring validation + navigation coverage and consistent error handling patterns |
| **Manage Account** (`ManageAccountView`) | **6/10** | Alpha | Account switching flows are complex; heavy dialog/SnackBar-based error UX; needs stronger state isolation |
| **Privacy Settings** (`PrivacySettingsView`) | **7/10** | Beta | Straightforward settings; still SnackBar-based error UX; needs rules validation |
| **Notifications Settings** (`NotificationsView`) | **7/10** | Beta | Straightforward settings; still SnackBar-based error UX; needs rules validation |
| **Content Preferences** (`ContentPreferencesView`) | **7/10** | Beta | Straightforward settings; still SnackBar-based error UX; needs rules validation |
| **Blocked Accounts** (`BlockedAccountsView`) | **7/10** | Beta | Functional; sequential per-user fetching can be slow; still SnackBar-based error UX |
| **Contact Support** (`ContactSupportView`) | **7/10** | Beta | Functional; needs spam protection + better failure UI + rules validation |
| **Camera** (`TikTokCameraView`) | **6/10** | Alpha | Device-specific camera reliability + lifecycle; good: blocks playback + locks orientation |
| **Video Edit** (`VideoEditView`) | **6/10** | Alpha | Complex editor surface area; needs perf/memory hardening + better crash-proofing |
| **Video Publish** (`VideoPublishingScreen`) | **6/10** | Alpha | Very complex; needs rigorous validation, retry/resume, and better error surfaces |
| **Insights** (`InsightsView`) | **5/10** | Alpha | Uses mock fallback; analytics pipeline needs production verification and permission rules alignment |
| **Activity** (`ActivityView`) | **6/10** | Alpha | Uses providers + better error state; needs full navigation coverage + performance pass |

## TikTok Parity (HomeView) — Current Gaps (Highest priority)
- **Playback reliability**: eliminate `BAD_INDEX` / surface churn (Phase 2.3 disposal guards pending) and guarantee “first frame within ~300–600ms” for current video.
- **Single active owner**: ownership/focus consolidated via `_attemptRequestFocus()` and pending-focus; multiple request paths still exist and can be further unified.
- **Preload policy**: “current + next 2” with non-blocking preload and pin set; key strategy stabilized to reduce surface reattach.
- **Gesture policy**: custom pull-to-refresh removed (stability first); avoid competing gesture detectors over vertical `PageView`.
- **Error UX**: inline selectable red error text for failed playback; some videos still show error due to missing quality variants / URL resolution (backend + client filtering needed).

## Data / profile alignment (track)
- **Canonical owner**: ✅ **getOwnerId** in `lib/utils/video_url_resolver.dart`; VideoService and RealUserDataService both use it. Profile “Found 0 / Loaded 2” mismatch resolved.
- **Optional next**: backfill Firestore video docs with single **ownerId** (and **videoUrl** / **thumbnailUrl**); then RealUserDataService can query only `ownerId`. See `docs/TIKTOK_VIDEO_FEED_SPEC.md` section 8.

## How we get to 8–9/10 (what to build)

### Target platforms (non-negotiable)
- **Android** and **iOS (Apple)** must both run without crash issues; all workstreams and acceptance criteria apply to both.
- Verify on representative devices: Android (e.g. Pixel 6, Samsung); iOS (e.g. iPhone, iPad). No platform-specific crashes in normal usage.

### Global workstreams (apply across the app)
- **Playback platform reliability (P0)** (Android + iOS):
  - **Option A (keep `video_player`)**: make surface attachment deterministic and rare on **both platforms**.
    - ✅ Only remount `VideoPlayer` on *controller instance change* or *explicit recovery event* (key format stabilized).
    - ✅ **Phase 2.3 disposal guards** attached state + TTL in GlobalPlaybackManager; disposal gated on not-attached or TTL expired; view disposes old controller on swap; _controllerCreatedAt set on register (prevents “used after disposed” and surface churn on Android and iOS).
    - Add **measurable recovery policy** (Phase 2.4, optional): detect “audio/position advancing but no frames” → try key remount once → recreate controller once → mark video unplayable and auto-skip.
    - ✅ **Single owner/focus contract**: consolidated `_attemptRequestFocus()` and pending-focus; non-active owners stay muted/paused.
  - **Android**: eliminate MediaCodec/Surface `BAD_INDEX` and texture reattach instability (Phase 2.3; if still present after Phase 2.3 → Option B on Android).
  - **iOS**: ensure AVPlayer/texture lifecycle does not cause black screens or crashes on iPhone/iPad; same disposal and focus rules apply.
  - **Option B (if Option A insufficient on a platform)**: replace playback stack on that platform with a controllable implementation (e.g. Media3 on Android; platform-native surface lifecycle). Must not regress the other platform.
- **Firestore rules + client query alignment (P0)**:
  - Remove `PERMISSION_DENIED` ("Missing or insufficient permissions") spam on both Android and iOS by either:
    - adjusting rules for read-only collections the client needs, or
    - gating listeners behind auth + feature flags and using server aggregation where appropriate.
  - ✅ **Rules**: user_retention_profiles restricted to own doc. **Client**: tags/engagement/creator_stats/scheduled_posts gated behind auth; permission-denied caught, no log spam. **Known failing query** (if still seen): `tags` collection (e.g. `tags where videoId == <id> order by __name__`) — client listens for tags by videoId; rules currently deny. Fix rules or stop querying from client.
  - Add a “rules contract” doc: which collections are readable/writable by client, which are server-only.
- **Consistent error UX (P0)**:
  - Standardize: **screen-level errors in `SelectableText.rich` (red)** with a retry button, not SnackBars (same behavior on Android and iOS).
  - Standardize empty states inside the screen (not silent failures).
- **Performance & rebuild control (P1)**:
  - Remove high-frequency debug logs in build paths and listeners (both platforms).
  - Reduce setState churn (batch updates; avoid per-item subscriptions where possible).
  - Add a lightweight performance harness: first-frame timing + scroll jank checks (run on Android and iOS).
- **Testing gates (P1)**:
  - Widget tests for navigation + empty/error states (platform-agnostic).
  - Integration tests for Home feed on **Android and iOS**: “open → first video plays → swipe 10 times → no audio bleed → return from overlay resumes” with no crashes on either platform.

### Acceptance criteria (what “8–9/10” means)
- **Crash-free sessions (Android and iOS)**: ≥ 99.5% on both platforms (debug noise doesn’t count; real exceptions do). No platform-specific crashes (e.g. no Android BAD_INDEX/used-after-disposed; no iOS AVPlayer/texture crashes).
- **Home feed** (on both Android and Apple devices):
  - First video: first frame visible within **600ms** on warm start (target), **<1500ms** worst-case.
  - Swipe: no black screens; playback swaps within **300–600ms**.
  - Audio: exactly one active audio source at all times.
- **No PERMISSION_DENIED in normal usage** on either platform (unless a user is truly unauthorized).
- **All screens** have a deterministic empty state + error state on both Android and iOS.

## Page-by-page solutions (to reach 8–9/10)

### Home (For You / Following) — from 4/10 → 8–9/10
- **Fix `BAD_INDEX` root cause**:
  - Treat surface recreation as a last resort and make it **event-driven**, not rebuild-driven.
  - Ensure key strategy is stable and does not change during routine state updates.
  - If Pixel 6 still reproduces after tightening remount rules: move to **Option B** (playback stack replacement).
- **Simplify owner/focus**:
  - One place sets active owner (navigation observer / tab switch).
  - One place requests focus (Home controller) using a strict rule: request focus only for current index and current feed.
- **Gesture cleanup**:
  - Replace custom pull-to-refresh pan logic with a safer approach (or remove until stable).
  - Ensure horizontal swipes don’t conflict with vertical PageView.
- **Error handling**:
  - On video load failure: show inline error overlay and auto-skip after \(N\) failures.

#### Verification status (Pixel 6)
- **Key/remount strategy**:
  - ✅ Key no longer changes on normal controller initialization (remount reserved for recovery events).
  - ⚠️ `setOutputSurface ... (6/BAD_INDEX)` still present in logs (not “perfect” yet).
  - Next checks: `--no-enable-impeller` A/B run; if still present → Option B.
- **Owner/focus**:
  - ✅ Moved “active owner” responsibility toward centralized routing (removed local `setActiveOwner` from `HomeView`, `DiscoverView`, `ProfileViewOptimized`).
  - ⚠️ Still multiple focus/request paths exist (`HomeViewController`, `HomeView` desired focus, `VideoPlayerViewOptimized` focus logic). Needs consolidation.
- **Gestures**:
  - ✅ Removed custom `onPan*` handler in `VideoPageViewWidget` (reduced gesture arena conflicts).
  - ⚠️ Pull-to-refresh temporarily disabled (stability first).
- **Error handling**:
  - ✅ Unplayable videos auto-skip (existing).
  - ✅ Failed playback now uses inline selectable red error text (no SnackBar dependency).

### Full-screen Player — from 7/10 → 8–9/10
- Share the **same owner/focus contract** as Home.
- Use the same recovery policy (first-frame watchdog + skip).
- Reduce background listeners (likes/bookmarks) to avoid frame drops during swipe.

### Network / Discover / Streamer Card — from 5–6/10 → 8/10
- Move heavy listener orchestration into providers/controllers (fewer `setState` rebuild storms).
- Gate real-time listeners behind auth and tear them down aggressively when off-screen.
- Fix rules so “expected reads” succeed; anything server-only should not be queried from client.

### Inbox — from 6/10 → 8/10
- Collapse per-chat unread listeners into a single aggregated stream (or batch queries).
- Add deterministic error/empty state UI and remove SnackBar-based error flows.

### Settings + subpages — from 7–8/10 → 8–9/10
- Replace SnackBars with screen-level error text.
- Add “save pending / save failed” UI states.
- Ensure all settings reads/writes match rules and are covered by basic tests.

### Camera / Edit / Publish — from 6/10 → 8/10
- Add robust lifecycle guards (pause/resume, cancellation, permissions).
- Add resumable uploads and explicit retry UI for publish.
- Add memory/perf caps for editing pipeline.

### Insights — from 5/10 → 8/10
- Remove mock fallback for production builds.
- Make analytics pipeline deterministic:
  - server aggregation job → client reads from one document/collection with proper indexes/rules.
  - show “not enough data yet” state instead of mock numbers.

## Notes
- This scorecard is based on current code, Pixel 6 logs, and `docs/COMPREHENSIVE_APP_AUDIT.md`.
- Related fix docs: `PRODUCTION_FOCUS_FIX_IMPLEMENTATION.md`, `SURFACE_BAD_INDEX_FIX.md`, `TIKTOK_HOMEVIEW_FIXES_APPLIED.md`, `VIDEO_ERROR_SCREEN_ISSUE.md`, `BLACK_SCREEN_CRITICAL_FIX.md`.
- **Data alignment:** `TIKTOK_VIDEO_FEED_SPEC.md` section 8 documents canonical owner (getOwnerId) and profile/feed alignment.
- **Next:** complete Phase 2.3 (disposal guards); re-test BAD_INDEX and consider Option B if needed; address video error screens (URL filtering + transcoding). Optionally backfill ownerId/videoUrl/thumbnailUrl.

