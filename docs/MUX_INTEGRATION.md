# Mux Video Integration

Video upload uses Mux for transcoding and HLS streaming. When configured, the app uploads directly to Mux instead of Firebase Storage; no Cloud Run transcoding.

## Architecture

```
┌─────────────┐    createMuxDirectUpload     ┌─────────────┐
│   Flutter   │ ───────────────────────────►│ Cloud Func  │
│     App     │    (callable, auth required)  │  (Mux API)  │
└─────────────┘                              └──────┬──────┘
       │                                             │
       │ PUT video to signed URL                     │ Returns uploadUrl
       ▼                                             │
┌─────────────┐                                      │
│ Mux Storage │◄────────────────────────────────────┘
└──────┬──────┘
       │ transcodes
       │ video.asset.ready webhook
       ▼
┌─────────────┐    POST webhook               ┌─────────────┐
│ Mux Servers │ ───────────────────────────►│ muxWebhook  │
└─────────────┘                              │  (Cloud Fn) │
                                            └──────┬──────┘
                                                   │
                                                   │ Updates Firestore
                                                   ▼
                                            ┌─────────────┐
                                            │  Firestore  │
                                            │  videos/doc │
                                            └─────────────┘
```

## Environment Variables

Use a `.env` file in `cloud_functions/`. No billing or Secret Manager required.

| Variable | Description | Required |
|----------|-------------|----------|
| `MUX_TOKEN_ID` | Mux API token ID (from Mux Dashboard) | Yes |
| `MUX_TOKEN_SECRET` | Mux API token secret | Yes |

### Setup (recommended – no billing)

1. Copy the example file:
   ```bash
   cp cloud_functions/.env.example cloud_functions/.env
   ```

2. Edit `cloud_functions/.env` and add your Mux credentials:
   ```
   MUX_TOKEN_ID=your_token_id_here
   MUX_TOKEN_SECRET=your_token_secret_here
   ```

3. Deploy:
   ```bash
   firebase deploy --only functions
   ```

Firebase loads `.env` on deploy and makes these available as `process.env.MUX_TOKEN_ID` and `process.env.MUX_TOKEN_SECRET`.

**Note:** `.env` is in `.gitignore`. Do not commit it.

## Mux Dashboard Setup

1. **Create account**: [dashboard.mux.com](https://dashboard.mux.com)
2. **API tokens**: Settings → Access Tokens → Create token
   - Copy Token ID and Token Secret
3. **Webhooks**: Settings → Webhooks → Add endpoint
   - URL: `https://us-central1-YOUR_PROJECT.cloudfunctions.net/muxWebhook`
   - Events: `video.asset.ready`, optionally `video.upload.asset_created`

## Behavior

| When Mux configured | When Mux NOT configured |
|--------------------|-------------------------|
| App calls `createMuxDirectUpload` | App would fail; fallback to Storage |
| Client uploads to Mux signed URL | Client uploads to `videos/{userId}/{videoId}.mp4` |
| `transcodeVideo` no-op (MUX_TOKEN_ID set) | `transcodeVideo` runs format check |
| Webhook updates Firestore with `hlsUrl` | transcodeVideo sets `mp4_720_url` |

## Fallback

If `createMuxDirectUpload` fails (e.g. no env), `VideoUploadService` falls back to Firebase Storage upload. `transcodeVideo` then:
- If `MUX_TOKEN_ID` is set: returns immediately (no-op)
- Else: runs format check, sets `mp4_720_url`/`status: ready`

## Firestore Fields (Mux)

After webhook, video doc has:

- `hlsUrl`, `hls_url`: `https://stream.mux.com/{playbackId}/high.m3u8`
- `mp4_720_url`, `videoUrl`, `videoURL`, `canonicalPlaybackUrl`: same HLS URL
- `status`: `ready`
- `muxAssetId`, `muxPlaybackId`
- `transcodingStatus`: `completed`
- `metadata.duration`: from Mux (if available)

## Playback

- `video_url_resolver` prefers `hlsUrl` / `hls_url` over MP4
- `video_health_gate` checks HLS URLs first
- ExoPlayer and `video_player` support HLS

## Cost

- Mux: per-minute transcoding + storage
- No Cloud Run for `transcodeVideo` when Mux used
- `createMuxDirectUpload` and `muxWebhook` are lightweight (minimal CPU)

## Website Parity

See **`docs/MUX_WEBSITE_IMPLEMENTATION.md`** for step-by-step instructions so the website follows the same logic as the app.
