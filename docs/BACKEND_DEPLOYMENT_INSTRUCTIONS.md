# Backend Video Transcoding - Deployment Instructions

**Date:** 2026-01-03  
**Goal:** Deploy video transcoding Cloud Function to generate 720p/480p variants

---

## 🚀 Quick Start

### Prerequisites

1. Firebase CLI installed: `npm install -g firebase-tools`
2. Node.js 18+ installed
3. Firebase project configured: `firebase login` and `firebase use <project-id>`

### Step 1: Install Dependencies

```bash
cd cloud_functions
npm install
```

This will install:
- `@ffmpeg-installer/ffmpeg` - FFmpeg binary for video transcoding
- `fluent-ffmpeg` - Node.js wrapper for FFmpeg
- `@google-cloud/storage` - Google Cloud Storage SDK

### Step 2: Verify Setup

Check that the new function is exported:
```bash
grep -n "transcodeVideo" cloud_functions/index.js
```

Should show the export line.

### Step 3: Deploy Cloud Function

**Option A: Deploy only the new function (Recommended for testing):**
```bash
cd cloud_functions
firebase deploy --only functions:transcodeVideo
```

**Option B: Deploy all functions:**
```bash
cd cloud_functions
firebase deploy --only functions
```

### Step 4: Monitor Deployment

Watch the deployment logs:
```bash
firebase functions:log --only transcodeVideo
```

---

## 🔍 Testing

### Test with New Video Upload

1. Upload a video through your Flutter app
2. Check Cloud Functions logs:
   ```bash
   firebase functions:log --only transcodeVideo
   ```
3. Wait 1-5 minutes (depends on video length)
4. Check Firestore document for the video:
   - Should have `mp4_720_url` field
   - Should have `mp4_480_url` field
   - `transcodingStatus` should be `"completed"`

### Verify Firestore Schema

Query a video document in Firestore console:
```javascript
// Should see:
{
  videoUrl: "https://storage.googleapis.com/.../video123_720p.mp4",
  mp4_1080_url: "https://storage.googleapis.com/.../video123.mp4",
  mp4_720_url: "https://storage.googleapis.com/.../video123_720p.mp4",
  mp4_480_url: "https://storage.googleapis.com/.../video123_480p.mp4",
  transcodingStatus: "completed",
  transcodedAt: Timestamp
}
```

---

## ⚙️ Configuration

### Memory & Timeout Settings

The function is configured with:
- **Memory:** 2GB (needed for video processing)
- **Timeout:** 540 seconds (9 minutes - Cloud Functions max)

For longer videos, consider:
1. Using Cloud Run instead (60-minute timeout)
2. Splitting videos into chunks
3. Using a queue system (Pub/Sub)

### Storage Bucket Permissions

Ensure the Cloud Function has permissions to:
- Read from Storage bucket (download videos)
- Write to Storage bucket (upload transcoded variants)
- Update Firestore documents

These permissions are usually automatic with default Firebase setup.

---

## 🐛 Troubleshooting

### Error: "FFmpeg not found"

**Solution:** The `@ffmpeg-installer/ffmpeg` package should handle this. If not:
1. Check that the package is installed: `npm list @ffmpeg-installer/ffmpeg`
2. Try using a Docker layer with FFmpeg pre-installed
3. Consider using Cloud Run with a custom Docker image

### Error: "Timeout"

**Solution:** 
- Videos longer than ~5-7 minutes may timeout
- Consider using Cloud Run for longer videos
- Or split transcoding into separate functions (720p, then 480p)

### Error: "Out of memory"

**Solution:**
- Increase memory allocation (currently 2GB)
- Maximum is 8GB for Cloud Functions
- Or use Cloud Run for more control

### Function Not Triggering

**Solution:**
1. Check Storage bucket path matches: `videos/{userId}/{videoId}.mp4`
2. Verify function is deployed: `firebase functions:list`
3. Check logs for errors: `firebase functions:log`

### Transcoding Fails Silently

**Solution:**
1. Check Cloud Functions logs: `firebase functions:log --only transcodeVideo`
2. Check Firestore document: `transcodingStatus` should show error message
3. Check Storage bucket permissions

---

## 📊 Monitoring

### View Logs

```bash
# All logs
firebase functions:log

# Specific function
firebase functions:log --only transcodeVideo

# Real-time logs
firebase functions:log --only transcodeVideo --follow
```

### Check Function Status

```bash
# List all functions
firebase functions:list

# Function details (in Firebase Console)
# https://console.firebase.google.com/project/<project-id>/functions
```

### Monitor Costs

Check Firebase Console:
- **Functions:** Usage & Billing
- **Storage:** Usage (transcoded videos use 2-3x storage)
- **Compute:** Function execution time

---

## 💰 Cost Considerations

### Estimated Costs (per 1000 videos/month)

- **Function Invocations:** ~$0.40
- **Compute Time:** ~$5-10 (depends on video length)
- **Storage:** ~$2-5 (additional 2-3x storage for variants)

**Total:** ~$7-15/month for 1000 videos

### Cost Optimization

1. **Delete originals after transcoding** (if not needed)
2. **Use lifecycle policies** to delete old videos
3. **Compress variants more** (higher CRF value = smaller files)
4. **Only transcode on-demand** (lazy transcoding)

---

## 🔄 Migration Strategy for Existing Videos

### Option 1: Gradual Migration (Recommended)

Let existing videos transcode gradually as users interact with them, or run a batch script.

### Option 2: Batch Migration Script

Create an HTTP-triggered Cloud Function to transcode existing videos:

```javascript
exports.transcodeExistingVideos = functions.https.onRequest(async (req, res) => {
  const batchSize = 10; // Process 10 at a time
  const videosSnapshot = await db.collection('videos')
    .where('transcodingStatus', '==', null)
    .limit(batchSize)
    .get();

  // Trigger transcoding by re-uploading or calling transcode function
  // Implementation depends on your setup
  
  res.json({processed: videosSnapshot.size});
});
```

### Option 3: Manual Migration

Use Firebase Console to manually trigger transcoding for high-priority videos.

---

## ✅ Success Checklist

After deployment, verify:

- [ ] Function deploys without errors
- [ ] New video uploads trigger transcoding
- [ ] Firestore documents get `mp4_720_url` and `mp4_480_url` fields
- [ ] `transcodingStatus` is set to `"completed"`
- [ ] Storage bucket contains transcoded variants
- [ ] Flutter app can access 720p videos
- [ ] No crashes on 256MB devices (when using 720p)

---

## 🚨 Important Notes

1. **First deployment may take 5-10 minutes** (installing dependencies)
2. **Transcoding takes time:** 30-second video ≈ 1-2 minutes to transcode
3. **Storage costs increase:** Expect 2-3x storage usage
4. **Backward compatibility:** Existing videos still use `videoUrl` (1080p) until transcoded
5. **Frontend ready:** The Flutter app already has device-aware resolution selection implemented

---

## 📝 Next Steps

1. ✅ Deploy the Cloud Function
2. ✅ Test with a new video upload
3. ✅ Verify Firestore documents are updated
4. ✅ Test Flutter app with new videos (should use 720p on low-memory devices)
5. ⚠️ Monitor costs and performance
6. ⚠️ Consider migration strategy for existing videos
7. ⚠️ Set up alerts for failed transcodings

---

## 🆘 Need Help?

- Check Cloud Functions logs: `firebase functions:log`
- Check Firebase Console for function status
- Review error messages in Firestore `transcodingError` field
- Check Storage bucket permissions

