# Disable Cloud Run Completely

To ensure no Cloud Run costs from Firebase Cloud Functions:

## 1. Already Migrated / Disabled

| Function | Status |
|----------|--------|
| `createMuxDirectUpload` | **Cloudflare Worker** — app calls Worker, not this |
| `muxWebhook` | **Cloudflare Worker** — Mux posts to Worker, not this |
| `transcodeVideo` | **No-op** when Mux used — returns null immediately (app uploads to Mux, not Storage) |
| `backfillVideoTranscoding` | **Disabled** — returns 403 |
| `normalizeVideoCreatorFields` | **Disabled** — commented out |
| `onVideoMilestone` | **Disabled** — commented out |

## 2. Still Active (Cause Cloud Run Cost)

These Firestore/Storage triggers still run when the app writes data:

| Function | Trigger | Cost impact |
|----------|---------|-------------|
| `onVideoWrite` | Every video doc write | **Stubbed** — app syncs via CreatorStatsSyncService; function returns immediately |
| `syncCreatorProfileToVideos` | User profile update | Medium |
| `onVideoCreate`, `onVideoUpdate`, `onVideoDelete` | Video lifecycle | Medium |
| `onLikeCreate`, `onCommentCreate` | Engagement | Medium |
| `onFollowCreate`, `onFollowDelete` | Follows | Low |
| `onRawUpload` | Storage raw_uploads | Low (if unused) |
| `onBookmarkCreate`, `onBookmarkDelete` | Bookmarks | Low |
| + ~20 more (auth, chat, calendar, APIs) | Various | Varies |

## 3. To Stop Cloud Run

1. **Firebase Console** → Project → Functions
2. Delete or disable the functions above (start with `onVideoWrite` — highest volume)

**Option A: Undeploy functions**
```bash
# Deploy empty functions (removes all)
firebase deploy --only functions
# Then delete each function in Firebase Console
```

**Option B: Deploy stubbed functions**
Replace function bodies with immediate `return null` and redeploy. Triggers still fire but functions exit immediately (minimal CPU).

## 4. Verify

- **GCP Console** → Billing → Reports → filter by "Cloud Run"
- Should show $0 or near-zero after functions are disabled.
