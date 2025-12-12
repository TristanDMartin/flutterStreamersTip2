## Observability & Alerting (targeting 9/10 robustness)

- Firestore rule denials: centralize logs (e.g., Cloud Functions sink) and alert on spikes (follows, users, videos).
- Follow churn spikes: metric on follow/unfollow rate per user/IP/device; alert on anomalies.
- Feed/video load errors: log error rates and latencies for feed queries and video fetch; set alert thresholds.
- Media playback: track play failures, stall rate, and time-to-first-frame by region; alert on thresholds.
- Query cost/latency: log read counts/latency for heavy collections (follows, videos, users); investigate high-cost queries.
- Counter drift: nightly reconciliation; alert if |actual - recomputed| exceeds threshold.
- Migration monitoring: log processed/failed/retried counts; stop on high error rate; snapshot before/after.
- Alerts routing: wire to Slack/Discord (e.g., #infra-alerts) for all the above signals.
- Dashboards: minimal views for rule denials, follow churn, feed/video errors, media QoS, counter drift.
- Test gating: keep Firestore rules tests + flutter tests in CI; fail fast on red.
