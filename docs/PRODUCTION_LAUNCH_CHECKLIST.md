# Production Launch Checklist

**Last updated:** 2026-06-01

This checklist tracks the practical production bar for StreamersTip based on the production readiness scorecard, Pixel 6 playback testing, and the recent Home feed hardening work.

## Current Position

Recent improvements moved Home from roughly **5/10 cold / 7-8/10 warm**, but it is not production-ready until the playback and rules gates below pass repeatedly on real devices.

Improved recently:

- Warm-start feed path: cache, memory, pre-warm before `runApp`.
- Overlay pause coverage: feed dropdown, command center, streamer card.
- HUD sync, loop timer, Android unmute probes, dock-aligned overlays.
- Cold-start empty-feed flash reduced, but not fully eliminated.
- Home feed mobile E2E target added: open, swipe 10, overlay, dismiss, resume.
- GPM/player playback logic split into coordinators + `VideoCell*` modules; CI runs `test/unit/services/playback_*_test.dart` and `test/unit/features/video_player/`.
- `scripts/mobile_feed_playback_matrix.sh` gates on user-visible playback symptoms (first-frame failures, video errors, permission denied, test failures) plus a 10m test timeout — not raw Codec2 `BAD_INDEX` noise by default.
- `scripts/mobile_feed_playback_matrix.sh` still reports `bad_index_count`, `codec_bad_index_count`, and `surface_bad_index_count` as informational telemetry; use `STRICT_CODEC_GATE=1` to fail on codec counters.
- `scripts/mobile_feed_playback_matrix.sh` writes a timeout summary instead of leaving incomplete artifacts.
- Android Impeller A/B script added for `BAD_INDEX` / `setOutputSurface` capture.
- Firestore emulator regressions added for likes and interaction/FCM rules.
- Visible-owner guard added so tab changes cannot leave Home as the active playback owner while Network is visible.
- Android Media3 / Option B prototype added behind `STREAMERSTIP_ANDROID_MEDIA3_HOME`; it compiles and passes the Home matrix, but currently has more `BAD_INDEX` noise than the texture path.

## P0 Ship Blockers

### 1. Playback Reliability

Playback remains the highest launch risk on Android and iOS. The matrix gate fails on user-visible symptoms (black screen, first-frame watchdog exhaustion, video errors), not isolated `BAD_INDEX` log lines. Codec counters remain telemetry for regression tracking.

Must pass:

| Scenario | Target |
|---|---|
| First frame on warm start | <= 600 ms |
| Swipe 10 videos | No black screen; swap <= 300-600 ms |
| Audio | Exactly one source; no bleed on tab/route change |
| Return from overlay/route | Correct video resumes |
| Background 30s -> foreground | Correct video resumes |

Open work:

- ✅ Pixel 6 verified swipe 10, overlay dismiss, tab to Network, and return to Home (`status=0`, `test_failures=0`).
- ✅ Pixel 6 happy path has no normal browsing `PERMISSION_DENIED`.
- ✅ Android Impeller A/B completed with clean app/test counters.
- ✅ Android Media3 / Option B foothold compiles and passes the same Pixel 6 Home flow when feature-flagged.
- ⚠️ `BAD_INDEX` persists in logcat with Impeller on and off (informational only for the production gate). The current Media3 prototype is noisier than the texture path, so it should not replace Home yet.
- ✅ **iOS playback (manual QA):** Home feed scenarios verified on device (open, swipe, overlay pause/resume, tab away/back, single audio). Treats iOS as functionally ready for the playback gate.
- ⚠️ **iOS playback (automated matrix):** Scripted run still pending — build/install completed, but Dart VM service was not discovered after launch, so `integration_test` never executed. CI/regression gate only; does not contradict manual verification.

Latest Pixel artifacts:

- Texture matrix: `build/mobile_feed_matrix/20260519_093613/summary.txt`
- Texture matrix with split counters: `build/mobile_feed_matrix/20260519_133852/summary.txt`
- Impeller A/B: `build/bad_index_ab/20260519_053322/summary.txt`
- Media3 matrix: `build/mobile_feed_matrix/20260519_094132/summary.txt`
- iPhone launch artifact: `build/mobile_feed_matrix/20260519_132331/summary.txt`

- Finish final focus-path consolidation across `HomeView`, `HomeViewController`, `VideoPlayerViewOptimized`, and `GlobalPlaybackManager`.
- Keep tab away -> back and overlay dismiss in the matrix as a regression gate for exactly one active video.

### 2. Firestore Rules And Client Query Contract

Normal app browsing must not spam `PERMISSION_DENIED`.

Known risk areas:

- Liked videos canonical query.
- FCM token save.
- User interaction tracking.
- Tags by `videoId`.

Open work:

- ✅ Add rules contract doc: `docs/FIRESTORE_CLIENT_RULES_CONTRACT.md`.
- ✅ `tags` collection: rules allow authed read; client handles permission-denied gracefully.
- Ensure no permission-denied logs appear on the happy path (ongoing matrix gate).
- Deploy indexes with rule changes when rules change.

### 3. Consistent Error UX

Production error UI should be deterministic and in-screen.

Open work:

- Replace SnackBar-only failures with screen-level `SelectableText.rich` plus retry.
- Prioritize Bookmarks, Manage Account, settings subpages, Network, Inbox, and Publish.
- Keep playback failures as inline overlays with retry/skip behavior.

### 4. Crash-Free Sessions

Target:

- Android crash-free sessions >= 99.5%.
- iOS crash-free sessions >= 99.5%.
- No routine used-after-disposed video controller failures.
- No platform-specific AVPlayer / ExoPlayer crash path during normal browsing.

Open work:

- Pixel 6, Samsung, and iPhone device matrix QA.
- Crashlytics triage after each matrix run.
- Treat playback controller lifecycle exceptions as launch blockers.

## P1 Before Wide Launch

| Area | Gap |
|---|---|
| Testing | Home E2E: Android automated matrix green; iOS manually verified; fix iOS VM attach for CI |
| Performance | Trim hot-path logs; reduce setState/listener storms in Network, Discover, Inbox, Streamer Card |
| Pull-to-refresh | Disabled on Home for stability; reintroduce safely or intentionally drop for v1 |
| Video pipeline | Some feed items fail from missing owner, bad URLs, or transcoding gaps; filter/skip and align backend |
| App Check | Configure production Firebase App Check; placeholder tokens are not launch-ready |
| CI | Rules tests and dependency audit must be green on every PR |

## P2 Flow Hardening

| Flow | Approx score | Main gaps |
|---|---:|---|
| Home | 7-8 warm / 5 cold | Android `BAD_INDEX`, iOS automated matrix (VM attach), final focus-path simplification, cold-first-install UX |
| Player | 7 | Same decoder stack; listener weight on swipe |
| Network / Discover | 6 | Heavy realtime listeners, permission noise, rebuild churn |
| Streamer Card | 5 | Large widget, many queries, lifecycle |
| Inbox | 6 | Per-chat listeners; batch/aggregate |
| Camera / Edit / Publish | 6 | Lifecycle, resumable upload, publish retry UX |
| Insights | 5 | Mock fallback in non-prod paths; real aggregation and rules |
| Billing / IAP | TBD | Store verification, entitlements, edge cases |
| Onboarding / tour | TBD | Must not fight playback ownership during tour |

## Operational Release Hygiene

- Secrets: Giphy, billing, Anthropic/Tippy through `--dart-define` or CI secrets.
- Firestore indexes deployed with rule changes.
- Cloud Functions deployed to match client contracts.
- Store assets ready: icons, privacy policy, data safety, review notes for video/social app.
- Monitoring ready: Crashlytics, first-frame timing, feed error rate, Android `BAD_INDEX` rate.

## Home Feed Production Gate

Home feed is production-ready when this passes on Pixel 6 (automated matrix) and one iPhone (manual QA or automated matrix) without failures:

**iOS note:** Manual device QA satisfies the functional bar when it covers the scenarios below. The automated matrix remains open for CI repeatability (fix VM service discovery / device runner).

1. Cold install -> feed loads.
2. Warm open -> first video visible and audible in < 600 ms.
3. Swipe 10 videos -> no black screen and no double audio.
4. Open feed menu, command center, and streamer card -> video pauses.
5. Dismiss overlay -> correct video resumes.
6. Tab to Network -> back to Home -> correct video resumes.
7. Background 30 seconds -> foreground -> correct video resumes.
8. Normal browsing emits no `PERMISSION_DENIED`.

Until this passes reliably, playback and Firestore rules remain P0.

Run the matrix locally:

Copy `.env.qa.local.example` to `.env.qa.local` (gitignored), or export
`QA_EMAIL_OR_USERNAME` and `QA_PASSWORD`. If the device already has a
signed-in session, set `QA_SKIP_CREDENTIAL_PREFLIGHT=1`.

```bash
DEVICES="PIXEL_ID IPHONE_ID" ./scripts/mobile_feed_playback_matrix.sh
```

Gate env (defaults are strict for playback symptoms):

- `MAX_FIRST_FRAME_FAILURES=0`
- `MAX_VIDEO_ERRORS=0`
- `MAX_PERMISSION_DENIED=0`
- `MAX_UNRECOVERED_SURFACE_PLAYBACK_FAILURES=0` — `setOutputSurface` errors only when flutter log shows recovery/first-frame exhaustion
- `FLUTTER_TEST_TIMEOUT=10m`
- `STREAMERSTIP_ANDROID_MEDIA3_HOME=false` (default; Media3 stays off unless explicitly enabled)

Informational (reported in summary, not gated by default):

- `bad_index_count`, `codec_bad_index_count`, `surface_bad_index_count`

Optional strict codec gate (CI experiments / regression hunts):

- `STRICT_CODEC_GATE=1` with `MAX_BAD_INDEX=0` and `MAX_SURFACE_BAD_INDEX=0`

Artifacts: `build/mobile_feed_matrix/<timestamp>/`.

## Suggested Order

1. Playback matrix test on Android and iOS.
2. Keep the current texture path unless a deeper Media3/native pooling experiment beats it on `BAD_INDEX`.
3. Firestore rules contract and denied-query cleanup.
4. Home integration test in CI.
5. Error UX pass on the top five screens users hit after Home.
6. Network, Inbox, and Publish hardening for creator flows.
