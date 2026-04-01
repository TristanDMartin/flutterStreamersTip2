# StreamersTip Mux API — Cloudflare Worker

Replaces Firebase Cloud Functions `createMuxDirectUpload` and `muxWebhook` with a Cloudflare Worker. No Cloud Run, predictable pricing.

## Routes

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/mux/direct-upload` | Bearer (Firebase ID token) | Create Mux direct upload, init Firestore doc, return `uploadUrl` + `videoId` |
| POST | `/webhooks/mux` | Mux-Signature header | Handle `video.asset.ready`, update Firestore with `hlsUrl`, `status: ready` |
| POST | `/mux/backfill-assets` | X-Backfill-Secret header | Sync Mux assets to Firestore (for assets missed by webhook) |

## Setup

### 1. Install dependencies

```bash
cd cloudflare_workers/mux
npm install
```

### 2. Configure wrangler.toml

Edit `wrangler.toml` and set your routes. For a custom domain:

```toml
routes = [
  { pattern = "api.streamerstip.com/mux/*", zone_name = "streamerstip.com" },
  { pattern = "api.streamerstip.com/webhooks/*", zone_name = "streamerstip.com" }
]
```

For testing on workers.dev, uncomment `workers_dev = true`.

### 3. Set secrets

```bash
wrangler secret put MUX_TOKEN_ID
wrangler secret put MUX_TOKEN_SECRET
wrangler secret put MUX_WEBHOOK_SECRET
wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON
```

- **MUX_TOKEN_ID** / **MUX_TOKEN_SECRET**: From [Mux Dashboard](https://dashboard.mux.com) → Settings → Access Tokens
- **MUX_WEBHOOK_SECRET**: From Mux Dashboard → Webhooks → your endpoint → Signing Secret
- **FIREBASE_SERVICE_ACCOUNT_JSON**: Full JSON from Firebase Console → Project Settings → Service Accounts → Generate new private key. When prompted, paste the entire JSON (minified on one line works best).

### 4. Mux webhook

In Mux Dashboard → Webhooks → Add endpoint:

- **URL**: `https://api.streamerstip.com/webhooks/mux`
- **Events**: `video.asset.ready`
- Copy the **Signing Secret** and set it as `MUX_WEBHOOK_SECRET`

### 5. Deploy

```bash
npm run deploy
```

## API

### POST /mux/direct-upload

**Headers**
```
Authorization: Bearer <firebase_id_token>
Content-Type: application/json
```

**Body**
```json
{
  "contentType": "video/mp4",
  "filename": "myvideo.mp4",
  "visibility": "public",
  "caption": "Optional caption",
  "hashtags": ["tag1", "tag2"],
  "privacy": "public",
  "allowComments": true,
  "category": "general"
}
```

**Response**
```json
{
  "videoId": "vid_1234567890_abc123",
  "uploadUrl": "https://storage.googleapis.com/...",
  "uploadId": "upload_..."
}
```

Then PUT the video file to `uploadUrl` with `Content-Type: video/mp4`.

### POST /mux/backfill-assets

Use when Mux assets are "Ready" in the dashboard but don't appear in the feed (webhook missed them or passthrough was empty).

**Headers**
```
X-Backfill-Secret: <your MUX_BACKFILL_SECRET>
Content-Type: application/json
```

**Body**
```json
{
  "assetIds": [
    "lRPPk7kAapZrlBQTJ2G01KgKNd6mybpIIrJfh81YPUiE",
    "ILp4tBDIr00O02JRNBH9Q7IdzgnZRO00fMRV02J00x7ze6PQ"
  ]
}
```

**Response**
```json
{
  "results": [
    { "assetId": "...", "status": "patched", "videoId": "vid_123_abc" },
    { "assetId": "...", "status": "created", "videoId": "mux-asset-id" }
  ]
}
```

- If asset has `passthrough` → PATCH existing Firestore doc
- If no passthrough but has `meta.creator_id` → CREATE new doc with Mux asset ID

Set secret: `wrangler secret put MUX_BACKFILL_SECRET`

## CORS

Default `Access-Control-Allow-Origin: *`. For production, set in `index.js`:

```js
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': 'https://www.streamerstip.com',
  // ...
};
```

## Local dev

```bash
npm run dev
```

Use `wrangler dev` with a `.dev.vars` file for secrets (create from `.dev.vars.example`).
