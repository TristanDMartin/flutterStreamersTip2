# Launch SLOs (Phase 2)

Targets from `docs/PRODUCTION_LAUNCH_CHECKLIST.md` and the path-to-10 plan.

| SLO | Target | Source |
|---|---|---|
| Crash-free sessions | ≥ 99.5% Android and iOS (7-day) | Firebase Crashlytics |
| Feed error rate | Track `slo_feed_error` / impressions | Analytics + Crashlytics breadcrumbs |
| First-frame timing | Warm Home < 600 ms; cold tracked | `slo_first_frame` / `slo_cold_first_frame` |
| BAD_INDEX | Device matrix counters; app proxy via watchdog | Matrix logcat + `slo_bad_index_proxy` |

## App instrumentation (already wired)

`ProductionMonitoringService` emits:

- Crashlytics custom keys: `slo_first_frame_count`, `slo_last_first_frame_ms`, `slo_feed_error_count`, `slo_bad_index_proxy_count`, `slo_last_feed_error`, release config keys
- Crashlytics logs: `slo_first_frame …`, `slo_feed_error …`, `slo_bad_index_proxy …`
- Analytics events: `slo_first_frame`, `slo_cold_first_frame`, `slo_feed_error`, `slo_bad_index_proxy`

Call sites:

- First frame → `GlobalPlaybackManager` + cold mark from `HomeFirstFrameGate`
- Feed errors → `FeedTelemetryService.logVideoLoadError` / `logVideoAutoSkipped`
- Release defines → startup `ReleaseConfigHealth.evaluate()`

Raw Android `setOutputSurface … BAD_INDEX` remains logcat-only; treat matrix `bad_index_count` as the ship gate and `slo_bad_index_proxy` as the in-app proxy (watchdog / surface recovery).

## Dashboard setup (Firebase console)

1. **Crashlytics → Dashboard**  
   Confirm crash-free users/sessions ≥ 99.5% for Android and iOS (last 7 days).

2. **Crashlytics → Logs / breadcrumbs**  
   Filter `slo_feed_error` and `slo_bad_index_proxy` after each matrix run.

3. **Analytics → Events**  
   Mark as key events (or build Explorations):
   - `slo_first_frame` (param `activation_to_first_frame_ms`)
   - `slo_cold_first_frame`
   - `slo_feed_error`
   - `slo_bad_index_proxy`

4. **Suggested Exploration**  
   Event count `slo_feed_error` / `slo_first_frame` over 7 days ≈ feed error rate proxy.

## After each device matrix

```bash
DEVICES="PIXEL_ID IPHONE_ID" ./scripts/mobile_feed_playback_matrix.sh
```

Then:

1. Paste matrix summary into `docs/RELEASE_TRACKER.md` Open Issues / QA notes
2. Triage new Crashlytics issues the same day
3. Confirm no rise in `slo_feed_error` / `slo_bad_index_proxy`

## Weekly cadence

- Monday: `bash scripts/release_preflight.sh`
- After release candidate: Crashlytics 7-day crash-free check
- Before public launch: hold SLOs green for 7 days (Phase 3)
