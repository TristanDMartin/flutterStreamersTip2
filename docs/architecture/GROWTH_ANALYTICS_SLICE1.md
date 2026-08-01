# Growth Analytics — Slice 1 ship notes

## Root cause

Clients called `https://streamerstip.com/api/growth/data` (and `/refresh`),
but Hosting rewrote those paths to `apiNotFound`. Worker growth modules
existed but were not mounted.

## Fix

1. **Worker** mounts:
   - `GET /api/growth/data`
   - `GET /api/growth/platforms`
   - `POST /api/growth/refresh`
2. **Hosting** rewrites (before `/api/**` catch-all):
   - `/api/growth/data` → `apiGrowthData`
   - `/api/growth/refresh` → `apiGrowthRefresh`
   - `/api/growth/platforms` → `apiGrowthPlatforms`
3. Cloud Functions proxy to
   `https://streamerstip-mux-api.streamerstip.workers.dev`
4. Flutter keeps `SITE_API_BASE=https://streamerstip.com` and shows a soft
   unavailable message + Retry (no raw `404` string).

## Deploy order

```bash
# 1) Worker first (so proxy has a live upstream)
cd cloudflare-workers && npx wrangler deploy

# 2) Functions + Hosting rewrites
firebase deploy --only functions:apiGrowthData,functions:apiGrowthRefresh,functions:apiGrowthPlatforms,hosting
```

## Smoke

1. Open Growth Analytics in Flutter and website while signed in.
2. Expect `200` (empty charts OK if no snapshots / platforms).
3. Confirm logs no longer show `Growth analytics request failed (404)`.
