# Firebase Minimal + Cloudflare/Mux Architecture

Use Firebase only for auth and metadata. Offload all media (videos, thumbnails) to Mux and Cloudflare to avoid Storage costs and 402 errors.

---

## Target Architecture

| Layer | Provider | Purpose |
|-------|----------|---------|
| **Auth** | Firebase Auth | Sign-in, tokens, user identity |
| **Database** | Firestore | Users, video metadata, follows, comments, likes (lightweight docs) |
| **Videos** | Mux | Upload, transcode, HLS playback, thumbnails (`image.mux.com`) |
| **Other media** | Cloudflare R2 (optional) | Avatars, chat images, custom thumbnails if needed |
| **Backend** | Cloudflare Workers | Mux direct-upload, webhooks, backfill, presigned URLs |

**Firebase Storage**: Deprecate for new uploads. Keep only for legacy reads until migration complete.

---

## What Stays in Firebase

- **Firebase Auth** — Sign-in (email, Google, etc.), ID tokens
- **Firestore** — `users`, `videos` (metadata only), `follows`, `favorites`, `comments`, etc.
  - Video docs store: `muxPlaybackId`, `hlsUrl`, `thumbnailUrl` (from Mux), `userId`, `caption`, etc.
  - No video files or thumbnails stored in Firebase

---

## What Moves to Mux

- **Videos** — Already primary for new uploads via Worker
- **Thumbnails** — Mux auto-generates: `https://image.mux.com/{playbackId}/thumbnail.jpg?width=720&time=0`
  - Worker webhook sets `thumbnailUrl` and `thumbnails` in Firestore
  - No Firebase Storage thumbnail upload when using Mux

---

## What Moves to Cloudflare R2 (Optional)

If you need storage beyond Mux (e.g. avatars, chat media):

- **R2 bucket** — S3-compatible, no egress fees
- **Worker** — Presigned PUT/GET URLs for uploads
- **Custom domain** — `media.streamerstip.com` for public URLs

---

## Migration Steps

### 1. Mux as primary (done)

- New uploads → Worker → Mux direct upload
- Webhook → Firestore with `hlsUrl`, `thumbnailUrl`, `status: 'ready'` or `'draft'`
- Draft support: pass `isDraft: true` to Worker; webhook sets `status: 'draft'`

### 2. Firebase Storage removed for videos

- `video_upload_service.dart` — Mux only, no Storage fallback
- `background_upload_service.dart` — delegates to VideoUploadService (Mux)
- `unified_video_service.dart` — delegates to VideoUploadService (Mux)

### 3. R2 for avatars and chat (done)

- Worker `POST /media/upload` with `X-Upload-Type: avatar` or `chat`
- Flutter `R2MediaService` for avatar and chat GIF uploads
- Auth and chat providers use R2 instead of Firebase Storage

### 4. R2 setup (required for avatars and chat)

1. **Create bucket**: Cloudflare Dashboard → R2 → Create bucket → name `streamerstip-media`
2. **Enable public access**: Bucket → Settings → Public Development URL → Enable (or use Custom Domain for production)
3. **Copy public URL**: After enabling, copy the Public Bucket URL (e.g. `https://pub-xxx.r2.dev`)
4. **Set secret**: `cd cloudflare_workers/mux && wrangler secret put MEDIA_PUBLIC_BASE_URL` → paste the URL (no trailing slash)
5. **Deploy**: `npm run deploy`

Without `MEDIA_PUBLIC_BASE_URL`, avatar/chat uploads return 503 "Media upload not configured".

### 5. Firestore rules

- Keep read/write rules for `videos`, `users`, etc.
- No Storage rules needed for new Mux/R2 content

---

## Cost Comparison

| Service | Before | After |
|---------|--------|-------|
| Firebase Auth | ✓ | ✓ (unchanged) |
| Firestore | ✓ | ✓ (metadata only, low cost) |
| Firebase Storage | Videos + thumbnails (egress, 402 risk) | Deprecated for new uploads |
| Mux | New videos | All new videos + thumbnails |
| Cloudflare Workers | Mux API | Mux API + optional R2 |

---

## Code Changes Summary

1. **video_upload_service.dart** — Mux only, no Firebase Storage; `isDraft` support; `onProgress` callback
2. **video_url_resolver.dart** — Prefer `hlsUrl`, `mp4_720_url`, Mux thumbnail (done)
3. **background_upload_service.dart** — Delegates to VideoUploadService (Mux)
4. **unified_video_service.dart** — Delegates to VideoUploadService (Mux)
5. **R2** — `R2MediaService`, `POST /media/upload` for avatars and chat
