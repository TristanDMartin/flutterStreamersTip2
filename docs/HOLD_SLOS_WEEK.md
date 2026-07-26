# Hold SLOs week (Phase 3 gate)

After Phase 0–2 code is on a release candidate, hold these for **7 consecutive days** before calling the app 10/10.

Use with [LAUNCH_SLOS.md](./LAUNCH_SLOS.md) and [RELEASE_TRACKER.md](./RELEASE_TRACKER.md) §8.

## Targets

| Metric | Pass |
|---|---|
| Crash-free sessions (Android) | ≥ 99.5% rolling 7-day |
| Crash-free sessions (iOS) | ≥ 99.5% rolling 7-day |
| Feed error rate proxy | No upward spike in `slo_feed_error` vs prior week |
| Cold first-frame | `slo_cold_first_frame` median monitored; warm Home < 600 ms on matrix |
| BAD_INDEX | Matrix counters within gate; no rise in `slo_bad_index_proxy` |

## Daily checklist (7 days)

Copy this table into release notes / tracker Open Issues:

| Day | Date | Crash-free A/I | Feed errors | Notes / triage | Owner |
|---|---|---|---|---|---|
| 1 |  |  |  |  |  |
| 2 |  |  |  |  |  |
| 3 |  |  |  |  |  |
| 4 |  |  |  |  |  |
| 5 |  |  |  |  |  |
| 6 |  |  |  |  |  |
| 7 |  |  |  |  |  |

## Rules

1. New fatal Crashlytics issue in browse/publish → day counter resets after fix ships.
2. Device matrix should run at least twice in the hold week (start + end).
3. Do not ship public launch mid-week if crash-free dips below target.
4. Re-score `docs/PRODUCTION_READINESS_SCORECARD.md` on day 7.

## Go / no-go

- [ ] 7 green days logged
- [ ] RELEASE_TRACKER beta gate complete
- [ ] Insights + billing polish verified on device (restore, grace messaging, empty insights)
- [ ] Approver: ____________________ Date: ____________________
