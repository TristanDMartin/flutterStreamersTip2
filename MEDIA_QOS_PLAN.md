## Media QoS & Fallback Plan

- Playback fallback: ensure MP4 fallback path exists when HLS fails (desktop/web/mobile). Show a lightweight error UI and retry/backoff.
- Metrics to capture: play failure rate, stall rate, time-to-first-frame; bucket by region and network type. Surface in dashboards with alerts.
- CDN: verify edge coverage for key regions; set caching headers for HLS playlists/segments and MP4 fallback.
- Transcode QC: flag failed or missing renditions; normalize rotation and loudness; record QC status per asset.
- Prefetch: prefetch next segment/thumbnail; cache poster for first meaningful paint.
- Alerts: thresholds for stall/failure/TTFP; route to Slack/Discord.
