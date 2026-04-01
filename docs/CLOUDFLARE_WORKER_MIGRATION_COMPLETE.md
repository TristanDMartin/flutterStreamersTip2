# Cloudflare Worker Migration — Implementation Complete

## Summary

Firebase Cloud Functions (`createMuxDirectUpload`, `muxWebhook`) have been replaced with Cloudflare Workers. **No Cloud Run costs for video upload.**

---

## What Was Implemented

### A) Cloudflare Worker (`cloudflare_workers/mux/`)

**Routes:**
- `POST /mux/direct-upload` — Auth via Firebase ID token, creates Mux upload URL + Firestore doc
- `POST /webhooks/mux` — Mux webhook handler, updates Firestore on `video.asset.ready`
- `OPTIONS *` — CORS preflight

**Features:**
- Accepts `videoId` + `userId` from client body (Flutter compatibility)
- Creates Firestore `videos/{videoId}` with `status: 'uploading'`
- Webhook sets `hlsUrl`, `muxPlaybackId`, `thumbnailUrl` (image.mux.com), `status: 'ready'`
- **Rate limiting mandatory:** 10/hr per UID, 30/hr per IP (requires `RATE_LIMIT_KV`)
- CORS for `www.streamerstip.com`, `streamerstip.com`, localhost
- **Webhook signature mandatory** (rejects missing/invalid)
- `GET /health` — basic health check (optionally tests Firestore)

### B) Flutter Client

**`lib/services/mux_upload_service.dart`**
- `createDirectUpload({ videoId, userId, idToken })` — calls Worker `POST /mux/direct-upload`
- `uploadToMux({ videoFile, uploadUrl, onProgress })` — PUT to Mux signed URL
- `waitForReady({ videoId })` — Firestore realtime listener until `status === 'ready'` (5 min timeout)

**`lib/services/video_upload_service.dart`**
- Uses `MuxUploadService` for full flow
- Generates `videoId`, gets upload URL from Worker, uploads to Mux
- Updates Firestore with caption, hashtags, privacy, etc.
- Waits for ready, returns `VideoUploadResult` with HLS + thumbnail URLs

### C) Firestore Rules

See `docs/FIRESTORE_RULES_WORKER_MIGRATION.md` for the `videos` rule change. Merge into existing `firestore.rules` so clients cannot set `muxPlaybackId`, `hlsUrl`, `status: 'ready'`.

---

## Deployment Checklist

### 1. Cloudflare Worker

```bash
cd cloudflare_workers/mux
npm install
wrangler secret put MUX_TOKEN_ID
wrangler secret put MUX_TOKEN_SECRET
wrangler secret put MUX_WEBHOOK_SECRET
wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON   # minified JSON string
wrangler deploy
```

**Required rate limit:** Create KV namespace:
```bash
wrangler kv namespace create RATE_LIMIT_KV
# Add returned id to wrangler.toml kv_namespaces, then deploy
```

**Custom domain** (api.streamerstip.com):
1. Ensure `streamerstip.com` is a Cloudflare zone (DNS proxied)
2. DNS: add CNAME `api` → `streamerstip.com` (or root `@`), proxy **ON**
3. Deploy: `wrangler deploy` (routes in wrangler.toml already point api.streamerstip.com/* → Worker)
4. Verify: `curl https://api.streamerstip.com/health`

### 2. Mux Dashboard

- Webhooks → Add endpoint: `https://api.streamerstip.com/webhooks/mux`
- Events: `video.asset.ready`
- Set signing secret, add to Worker as `MUX_WEBHOOK_SECRET`

### 3. Firestore Rules

Merge `docs/FIRESTORE_RULES_WORKER_MIGRATION.md` into `firestore.rules`, then:

```bash
firebase deploy --only firestore:rules
```

### 4. Disable Cloud Functions (Stop Cloud Run Billing)

In Firebase Console or GCP:
- Disable/delete `createMuxDirectUpload`, `muxWebhook`, and any other callable/HTTP functions
- Or: `firebase functions:delete createMuxDirectUpload muxWebhook`

---

## Website Upload (When Implemented)

When adding video upload to the website (e.g. publish modal):

1. Get Firebase ID token: `await auth.currentUser.getIdToken()`
2. Call `POST https://api.streamerstip.com/mux/direct-upload` with:
   ```json
   { "videoId": "<uuid>", "userId": "<uid>" }
   ```
   Headers: `Authorization: Bearer <idToken>`, `Content-Type: application/json`
3. PUT video file to `uploadUrl` (from response)
4. Update Firestore `videos/{videoId}` with caption, hashtags, etc.
5. Listen to Firestore for `status === 'ready'`
6. Playback: `https://stream.mux.com/{playbackId}/high.m3u8`
7. Thumbnail: `https://image.mux.com/{playbackId}/thumbnail.jpg?width=720&time=0`

---

## Cost Hardening (Implemented)

| Item | Status |
|------|--------|
| Rate limit /mux/direct-upload | **Required** — 10/hr per UID, 30/hr per IP (KV) |
| Mux webhook signature | **Required** — rejects missing/invalid |
| Webhook body size limit | 64 KB max (reject oversized fast) |
| CORS | Configured for production + localhost |
| Firestore rules | No non-owner writes to videos |
| waitForReady | Realtime listener (not polling) |

---

## Required: FIREBASE_WEB_API_KEY

The Worker uses Firebase Auth REST API to verify ID tokens (avoids tokeninfo URL encoding issues). Add the secret:

```bash
wrangler secret put FIREBASE_WEB_API_KEY
# Paste your Firebase Web API Key from: Firebase Console > Project Settings > General > Web API Key
# Or from google-services.json: api_key[0].current_key
```

---

## Troubleshooting 401/400 on /mux/direct-upload

If the Worker returns 401 or 400:

1. **FIREBASE_WEB_API_KEY:** Ensure this secret is set and matches your Firebase project.
2. **Check logs:** The app logs `🔐 Worker 400/401: <error>` with the Worker’s message (e.g. “Invalid or expired token”, Google’s `error_description`).
2. **Firebase project:** Ensure the app’s Firebase config (`google-services.json` / `GoogleService-Info.plist`) uses project `streamerstip-6cfdb` so the ID token’s `aud` matches.
3. **Emulator:** Tokens from the Firebase Auth emulator won’t validate with Google’s tokeninfo. Use production auth.
4. **Token freshness:** `getIdToken(true)` forces refresh; if 401 persists, inspect the token (e.g. length ~1100) and verify it’s sent as `Authorization: Bearer <token>` with no extra encoding.

---

## Files Changed / Created

| File | Action |
|------|--------|
| `cloudflare_workers/mux/src/index.js` | Enhanced (CORS, videoId/userId from body, thumbnailUrl, rate limit) |
| `cloudflare_workers/mux/wrangler.toml` | KV namespace comment added |
| `lib/services/mux_upload_service.dart` | Created (Worker API client) |
| `lib/services/video_upload_service.dart` | Implemented (Mux upload flow) |
| `docs/CLOUDFLARE_MIGRATION_DISCOVERY.md` | Created |
| `docs/FIRESTORE_RULES_WORKER_MIGRATION.md` | Created |
| `docs/CLOUDFLARE_WORKER_MIGRATION_COMPLETE.md` | This file |
