# Deploy Guide — Zero Downtime Order

## Deploy Order (Avoid Downtime)

### Step 1 — Firestore Rules First

So clients can't forge mux fields even if old endpoints exist.

```bash
firebase deploy --only firestore:rules
```

Merge `docs/FIRESTORE_RULES_WORKER_MIGRATION.md` into `firestore.rules` first.

---

### Step 2 — Deploy Worker (KV + Secrets Required)

Do **not** deploy without KV + webhook secret (code returns 503 if missing).

```bash
cd cloudflare_workers/mux
wrangler kv namespace create RATE_LIMIT_KV
# Add returned id to wrangler.toml kv_namespaces
wrangler secret put MUX_TOKEN_ID
wrangler secret put MUX_TOKEN_SECRET
wrangler secret put MUX_WEBHOOK_SECRET
wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON
wrangler deploy
```

---

### Step 3 — Update Mux Webhook URL

In Mux Dashboard:
- URL: `https://api.streamerstip.com/webhooks/mux`
- Event: `video.asset.ready`

---

### Step 4 — Flutter Already Uses Worker

`mux_upload_service.dart` points to `https://api.streamerstip.com`. No code change.

---

### Step 5 — Delete Cloud Functions (After Confirmed Working)

Only after end-to-end uploads work:

```bash
firebase functions:delete createMuxDirectUpload muxWebhook
```

---

## Verify It's Working

### A) Health Check

`https://api.streamerstip.com/health` → `{"worker":"ok","firestore":"ok"}`

If `firestore: "error"`: `FIREBASE_SERVICE_ACCOUNT_JSON` wrong/malformed/missing permissions.

### B) Upload Test (Flutter)

1. Upload short video
2. Firestore doc: `status: uploading` → within ~30–120s → `status: ready`
3. Doc has `muxPlaybackId`, `hlsUrl`, `thumbnailUrl`

### C) Playback Test

Player requests `stream.mux.com/{playbackId}/high.m3u8` and plays.

---

## Hard Fail Behavior (Correct)

| Condition | Status |
|-----------|--------|
| `RATE_LIMIT_KV` missing | 503 (service misconfigured) |
| Rate limit exceeded | **429** (back off) |
| Webhook secret missing | 503 |
| Invalid/missing webhook signature | 401 |
| Webhook body > 64 KB | 413 |

---

## Cost Gotchas

### Firestore Feed Listeners

- Paginate, limit queries
- Avoid realtime on huge collections unless necessary
- Share your For You query (collection + ordering) for read-optimized pattern

### Engagement Stats

- Do **not** write likes/views to `videos/{id}`
- Option: `video_stats/{videoId}` with `likeCount`, `viewCount`, `commentCount`
- Option: `videos/{id}/likes/{uid}` (one doc per user)
- Worker cron aggregates later

---

## Privacy Model

- **Day 1:** Public playback for all (simple)
- **Phase 2:** Signed URLs for private/followers-only videos (Worker generates signed Mux token)

---

## Legacy Firebase Storage Videos (12)

Until migration runs (or billing fixed):

- If `muxPlaybackId` exists → play via Mux
- Else → play via Firebase Storage URL

Avoid re-enabling Functions just to migrate.
