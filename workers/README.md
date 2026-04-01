# StreamersTip Mux API — Cloudflare Workers

Replaces Firebase Cloud Functions (`createMuxDirectUpload`, `muxWebhook`) with Cloudflare Workers. **No Cloud Run = no cost surprises.**

## Routes

| Route | Method | Auth | Purpose |
|-------|--------|------|---------|
| `/mux/direct-upload` | POST | Bearer (Firebase ID token) | Create Mux upload URL, optionally create Firestore doc |
| `/webhooks/mux` | POST | Mux signature | Handle `video.asset.ready`, update Firestore |

## Setup

### 1. Install Wrangler

```bash
cd workers
npm install
```

### 2. Configure Secrets

```bash
wrangler secret put MUX_TOKEN_ID
wrangler secret put MUX_TOKEN_SECRET
wrangler secret put MUX_WEBHOOK_SECRET    # From Mux Dashboard → Webhooks
wrangler secret put FIREBASE_PROJECT_ID   # e.g. streamerstip-6cfdb
wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON  # Minified JSON of service account key
```

For `FIREBASE_SERVICE_ACCOUNT_JSON`, paste the entire JSON (minified, no newlines) from your Firebase service account key file.

### 3. Update Mux Webhook URL

In [Mux Dashboard → Webhooks](https://dashboard.mux.com/settings/webhooks):

- URL: `https://api.streamerstip.com/webhooks/mux`
- Event: `video.asset.ready`
- Copy the signing secret → `wrangler secret put MUX_WEBHOOK_SECRET`

### 4. Deploy

```bash
wrangler deploy
```

### 5. CORS (Optional)

Edit `CORS_HEADERS` in `src/index.js` to match your website origin:

```javascript
'Access-Control-Allow-Origin': 'https://www.streamerstip.com',
```

## Client Usage

### Flutter

```dart
// Replace Firebase callable with HTTP
final idToken = await user.getIdToken();
final response = await http.post(
  Uri.parse('https://api.streamerstip.com/mux/direct-upload'),
  headers: {
    'Authorization': 'Bearer $idToken',
    'Content-Type': 'application/json',
  },
  body: jsonEncode({'contentType': 'video/mp4', 'filename': 'video.mp4'}),
);
final data = jsonDecode(response.body);
final videoId = data['videoId'];
final uploadUrl = data['uploadUrl'];
// PUT video file to uploadUrl
```

### Website (JavaScript)

```javascript
const idToken = await auth.currentUser.getIdToken();
const res = await fetch('https://api.streamerstip.com/mux/direct-upload', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${idToken}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({ contentType: 'video/mp4', filename: 'video.mp4' }),
});
const { videoId, uploadUrl } = await res.json();
// XHR or fetch PUT to uploadUrl with video file
```

## Migration

1. Deploy Worker, configure secrets
2. Update Flutter to call Worker instead of `createMuxDirectUpload`
3. Update website to call Worker
4. Point Mux webhook to Worker URL
5. Disable Firebase Functions: `createMuxDirectUpload`, `muxWebhook`

See `docs/MUX_CLOUDFLARE_WORKER_SPEC.md` for full spec.
