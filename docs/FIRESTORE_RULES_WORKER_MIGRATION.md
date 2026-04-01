# Firestore Rules for Worker Migration

**Critical:** Only the Worker (Admin SDK) sets Mux fields and `status: 'ready'`. Clients cannot forge these. **Non-owners must NEVER write to `/videos/{videoId}`** — engagement (views, likes, comments) must move to a separate collection (e.g. `video_stats`, `video_analytics`) to avoid write storms and cost spikes.

## Recommended `videos` Rules (Safe + Cheap)

```javascript
match /videos/{videoId} {
  allow read: if request.auth != null;

  allow create: if request.auth != null
    && request.resource.data.userId == request.auth.uid;

  // Owner can only update safe metadata fields (no engagement, no mux/status)
  allow update: if request.auth != null
    && request.auth.uid == resource.data.userId
    && request.resource.data.diff(resource.data).affectedKeys()
      .hasOnly(['caption','hashtags','privacy','allowComments','category','updatedAt']);

  allow delete: if request.auth != null && request.auth.uid == resource.data.userId;
}
```

**Why no non-owner writes:**
- Every view/like/comment would become a write to `videos/{id}` → Firestore cost grenade
- Feed scrolling could trigger many writes
- Race conditions and doc contention

**Engagement:** Store in `video_stats/{videoId}` or `video_analytics` (written by Worker or scheduled job). Client writes to those collections only.

## Merge Instructions

Merge the `videos` match block above into your existing `firestore.rules`. Do not remove rules for other collections.

Deploy:

```bash
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

## Required Firestore Index (user_id + status + createdAt)

Profile/user videos query uses `user_id` + `status whereIn [published, ready]` + `orderBy createdAt`. The composite index was added to `firestore.indexes.json`. Deploy indexes after rules.

## Mux Videos Not Showing in Feed

If Mux assets are "Ready" in the Mux dashboard but don't appear in the feed:

1. **Webhook** — Mux Dashboard → Webhooks must point to `https://api.streamerstip.com/webhooks/mux` with `video.asset.ready` enabled. Signing secret must match `MUX_WEBHOOK_SECRET`.

2. **Backfill** — Run the Worker backfill to sync missed assets to Firestore:
   ```bash
   wrangler secret put MUX_BACKFILL_SECRET   # set a random string once
   curl -X POST https://api.streamerstip.com/mux/backfill-assets \
     -H "X-Backfill-Secret: YOUR_SECRET" \
     -H "Content-Type: application/json" \
     -d '{"assetIds":["lRPPk7kAapZrlBQTJ2G01KgKNd6mybpIIrJfh81YPUiE","ILp4tBDIr00O02JRNBH9Q7IdzgnZRO00fMRV02J00x7ze6PQ"]}'
   ```
   Use the asset IDs from Mux Dashboard → Video → Assets. See `cloudflare_workers/mux/README.md` for full API.

## Video 402 "Unavailable" (ExoPlayer)

If videos show "unavailable" with `HttpDataSource$InvalidResponseCodeException: Response code: 402`:

- **402 = Payment Required** – often Firebase Storage on Spark/free plan when egress exceeds free tier, or Blaze plan quota.
- Check Firebase Console → Usage and billing. Upgrade to Blaze if needed.
- Ensure video URLs resolve to playable sources: Mux uses `hlsUrl`/`mp4_720_url`; legacy uses Firebase Storage `videoUrl`/`videoURL`.
