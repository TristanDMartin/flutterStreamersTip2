# Architecture: Firebase, Cloudflare & Mux — How They Work Together

This doc explains how Firebase, Cloudflare, and Mux fit together in StreamersTip and how to keep Cloud Run costs under control.

---

## 1. Current Architecture (What Runs Today)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         FLUTTER APP / WEBSITE                           │
├─────────────────────────────────────────────────────────────────────────┤
│  • Firebase Auth (sign-in, tokens)                                       │
│  • Firestore (videos, users, follows, notifications, etc.)               │
│  • Firebase Storage (thumbnails; video only when Mux fallback)            │
│  • Cloud Functions (createMuxDirectUpload callable)                      │
└────┬────────────────────────────┬──────────────────────────────────────┘
     │                             │
     │ Video upload (Mux path)     │ Video playback
     ▼                             ▼
┌─────────────────┐         ┌─────────────────────────────────────────────┐
│ Mux             │         │ Mux CDN (stream.mux.com)                     │
│ • Direct upload │         │ • HLS streams: stream.mux.com/{id}/high.m3u8│
│ • Transcoding   │         │ • Or Firebase Storage (fallback MP4)        │
│ • Webhook       │         └─────────────────────────────────────────────┘
└────────┬────────┘
         │ video.asset.ready
         ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ CLOUD FUNCTIONS (run on Cloud Run under the hood)                        │
│ • createMuxDirectUpload (callable) — get signed URL                      │
│ • muxWebhook (HTTP) — Mux POSTs here when transcoding done               │
│ • transcodeVideo (Storage trigger) — NO-OP when Mux configured           │
│ • onVideoCreate, onVideoWrite, onLikeCreate, etc. — Firestore triggers   │
│ • syncVideoAnalyticsToVideos (scheduled 3am) — batch view sync           │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. What Each Service Does

### Firebase

| Service | Role | Cost driver |
|---------|------|-------------|
| **Auth** | Sign-in, tokens, `request.auth` in Functions | Free tier generous |
| **Firestore** | Data layer (videos, users, follows, etc.) | Reads/writes; scoped queries matter |
| **Storage** | Thumbnails, fallback video when Mux fails | Bandwidth + storage |
| **Cloud Functions** | Runs on **Cloud Run** (Gen 1) or Cloud Run (Gen 2) | **Invocations + CPU time** — main cost risk |

### Mux

| Role | When |
|------|------|
| **Direct upload** | App calls `createMuxDirectUpload` → gets signed URL → PUTs video file |
| **Transcoding** | Mux converts upload to HLS; no Cloud Run CPU |
| **Webhook** | Mux POSTs `video.asset.ready` → `muxWebhook` updates Firestore |
| **Playback** | `stream.mux.com/{playbackId}/high.m3u8` — Mux’s own CDN |

**Important:** When Mux is configured (`MUX_TOKEN_ID` in Cloud Functions), `transcodeVideo` is a **no-op**. Video never hits Storage, so no Storage trigger, no Cloud Run transcoding.

### Cloudflare (Not in App Today)

Your app code does **not** use Cloudflare. Firebase SDK has `isCloudflareWorker()` for Workers environments only.

Cloudflare can still be used for:

| Use case | What it does |
|----------|--------------|
| **DNS** | Point `streamerstip.com` to Firebase Hosting, API, etc. |
| **CDN / proxy** | Cache static assets, speed up website, DDoS protection |
| **Website hosting** | Serve website from Cloudflare Pages (alternative to Firebase Hosting) |

---

## 3. The Cloud Run Cost Problem (And How to Avoid It)

Firebase Cloud Functions run on **Cloud Run**. Billing is mainly:

- **Invocations** — each trigger = 1 invocation
- **CPU time** — duration × memory

### What Used to Cause ~$888/Year

1. **Per-view triggers** — Each view wrote to `videos/{id}` → 4 functions per view
2. **`transcodeVideo`** — Ran on every Storage upload: download file, FFmpeg check
3. **`syncCreatorProfileToVideos`** — One profile edit → update 100+ videos → 100+ `onVideoWrite` calls

### What’s Fixed (Keep It This Way)

| Area | Fix | Effect |
|------|-----|--------|
| **Video views** | Client writes to `video_analytics` only; daily sync to `videos` | ~0 functions per view |
| **Video upload** | Mux path: upload to Mux → `transcodeVideo` is no-op | No Storage trigger for Mux uploads |
| **transcodeVideo** | Runs only when Mux NOT used; `useMux` → early return | No Cloud Run when Mux configured |
| **Milestone / normalize** | Disabled | No extra Firestore triggers |
| **Backfill** | Returns 403 | No batch transcoding runs |

### Golden Rules (So Cloud Run Can’t “Ruin” It)

1. **Use Mux for all new video uploads** — `createMuxDirectUpload` + PUT; no Storage upload, no `transcodeVideo`
2. **Never write views to `videos/{id}`** — Only to `video_analytics/{videoId}`
3. **Don’t add Firestore triggers on high-volume collections** — e.g. `videos` on every write
4. **Scope Firestore listeners** — e.g. `follows.where('followerId', '==', userId)` instead of `follows.snapshots()`
5. **Keep `syncCreatorProfileToVideos` light** — Or debounce; avoid updating all videos on every profile change
6. **Monitor** — Firebase Console → Functions usage; GCP Billing → filter by Cloud Run

---

## 4. How to Get Everything Working Together

### Checklist: Firebase

- [ ] **Auth** — App & website use same Firebase project; `request.auth` works in Functions
- [ ] **Firestore** — Rules allow client writes to `video_analytics`, `videos` (create/update as designed)
- [ ] **Storage** — Thumbnails upload; video upload only for Mux fallback
- [ ] **Functions** — Deploy with `.env` containing `MUX_TOKEN_ID` and `MUX_TOKEN_SECRET`

### Checklist: Mux

- [ ] **Credentials** — `MUX_TOKEN_ID` and `MUX_TOKEN_SECRET` in `cloud_functions/.env`
- [ ] **Webhook** — Mux Dashboard → Webhooks → endpoint `https://us-central1-<PROJECT>.cloudfunctions.net/muxWebhook`
- [ ] **Event** — Subscribe to `video.asset.ready`
- [ ] **App flow** — `createMuxDirectUpload` → PUT to URL → create Firestore doc with `status: 'processing'`
- [ ] **Webhook flow** — Mux POSTs → `muxWebhook` updates Firestore with `hlsUrl`, `status: 'ready'`

### Checklist: Cloudflare (Optional)

- [ ] **DNS** — Point your domain to Firebase Hosting or Cloudflare Pages
- [ ] **CORS** — If website domain differs from app, ensure Mux `cors_origin` and Firebase Auth allow it
- [ ] **Webhook** — Mux must reach `muxWebhook`; if Cloudflare is a proxy, ensure POSTs to Cloud Functions URL are not blocked

### Checklist: Cloud Run Safety

- [ ] **Mux configured** — So `transcodeVideo` is a no-op for normal uploads
- [ ] **View counting** — Writes only to `video_analytics`, never to `videos` for views
- [ ] **No per-view triggers** — No `onWrite`/`onUpdate` on `videos` for view-only changes
- [ ] **Billing alert** — Set at $50–100/month in GCP Billing
- [ ] **Usage** — Check Functions usage weekly in Firebase Console

---

## 5. Data Flow Summary

| Action | Client | Firebase | Mux | Cloud Run |
|--------|--------|----------|-----|-----------|
| **Video upload (Mux)** | PUT to Mux URL, create Firestore doc | Firestore write | Transcode, webhook | createMuxDirectUpload (1×), muxWebhook (1×) |
| **Video upload (fallback)** | Upload to Storage, create Firestore doc | Storage + Firestore | — | transcodeVideo (1×) |
| **Video view** | Write to `video_analytics` | Firestore write (no triggers) | — | 0 |
| **Daily sync** | — | Firestore batch update | — | syncVideoAnalyticsToVideos (1×), then onVideoWrite per video |
| **Like / comment** | Firestore write | Firestore | — | onLikeCreate / onCommentCreate (1× each) |

---

## 6. Where Cloudflare Fits (If You Add It)

```
                    ┌─────────────────┐
                    │   Cloudflare    │
                    │  (DNS / CDN)    │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌───────────────┐ ┌─────────────────────┐
│ Firebase        │ │ Mux           │ │ Your Website         │
│ Hosting /       │ │ stream.mux.com│ │ (or Firebase Hosting)│
│ Auth / Firestore│ │ (video CDN)    │ │                     │
└─────────────────┘ └───────────────┘ └─────────────────────┘
```

- **DNS** — Cloudflare manages DNS; CNAME to Firebase Hosting or your host
- **CDN** — Cache static assets; video streams are usually from Mux, not Cloudflare
- **DDoS / WAF** — Protect API and webhook endpoints; ensure `muxWebhook` stays reachable by Mux’s IPs

---

## 7. Summary

| Component | Role | Cloud Run impact |
|-----------|------|------------------|
| **Firebase** | Auth, Firestore, Storage, Functions | Functions = Cloud Run; keep invocation/CPU low |
| **Mux** | Upload, transcoding, playback | Offloads transcoding from Cloud Run; `transcodeVideo` = no-op |
| **Cloudflare** | DNS, CDN (optional) | No direct Cloud Run impact; must not block Mux webhook |

**Main rule:** Use Mux for uploads, keep views in `video_analytics`, scope Firestore listeners, and avoid new high-volume triggers. Then Cloud Run stays predictable and cheap.
