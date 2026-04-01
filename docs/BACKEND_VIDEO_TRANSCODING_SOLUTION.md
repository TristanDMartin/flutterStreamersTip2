# Backend Video Transcoding Solution - 720p Support

**Date:** 2026-01-03  
**Problem:** 1080p videos cause OutOfMemoryError on 256MB heap Android devices  
**Solution:** Generate 720p (and 480p) video variants on upload

---

## 🎯 Goal

Generate multiple video resolutions (1080p, 720p, 480p) when videos are uploaded, so the frontend can select the appropriate resolution based on device capabilities.

---

## 📋 Implementation Options

### **Option 1: Firebase Cloud Functions with FFmpeg (Recommended)**

**Pros:**
- Serverless, automatic scaling
- Integrated with Firebase ecosystem
- Cost-effective for moderate traffic
- No infrastructure to manage

**Cons:**
- 540s timeout limit (may need to handle long videos differently)
- Requires FFmpeg layer (adds complexity)
- Cold starts can add latency

**Implementation Steps:**

1. **Update Cloud Functions dependencies:**
```bash
cd cloud_functions
npm install @ffmpeg-installer/ffmpeg fluent-ffmpeg
```

2. **Create video transcoding Cloud Function:**
   - Trigger: Storage bucket `videos/{userId}/{videoId}.mp4` finalize
   - Download video from Storage to `/tmp`
   - Use FFmpeg to generate 720p and 480p versions
   - Upload variants back to Storage
   - Update Firestore with `mp4_720_url` and `mp4_480_url` fields

3. **Update Firestore documents:**
   - Add `mp4_1080_url` (original)
   - Add `mp4_720_url` (transcoded)
   - Add `mp4_480_url` (transcoded)
   - Keep `videoUrl` for backward compatibility (point to 720p for new videos)

---

### **Option 2: Cloud Run with FFmpeg (Best for Production)**

**Pros:**
- No timeout limits (up to 60 minutes)
- Better performance for long videos
- More control over resources
- Can handle batch processing

**Cons:**
- Requires Cloud Run setup
- More infrastructure to manage
- Higher cost for low traffic

**Implementation:**
- Create Docker container with FFmpeg
- Deploy to Cloud Run
- Trigger via HTTP from Cloud Function or Pub/Sub

---

### **Option 3: Third-Party Service (Easiest but Expensive)**

**Services:**
- AWS MediaConvert
- Google Cloud Video Intelligence API
- Mux
- Cloudflare Stream

**Pros:**
- No infrastructure management
- Automatic scaling
- Professional encoding quality
- Built-in CDN

**Cons:**
- Cost per video (can be expensive at scale)
- Vendor lock-in
- Additional API integrations

---

## 🚀 Recommended Implementation: Option 1 (Cloud Functions)

Since you're already using Firebase, let's implement Option 1.

### Step-by-Step Implementation

#### 1. Update `cloud_functions/package.json`

Add dependencies:
```json
{
  "dependencies": {
    "@ffmpeg-installer/ffmpeg": "^1.1.0",
    "fluent-ffmpeg": "^2.1.2"
  }
}
```

#### 2. Create `cloud_functions/src/videoTranscoding.js`

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {Storage} = require('@google-cloud/storage');
const ffmpeg = require('fluent-ffmpeg');
const ffmpegPath = require('@ffmpeg-installer/ffmpeg').path;
const fs = require('fs');
const path = require('path');
const os = require('os');

ffmpeg.setFfmpegPath(ffmpegPath);

const storage = new Storage();
const db = admin.firestore();

/**
 * Cloud Function triggered when a video is uploaded to Storage
 * Generates 720p and 480p variants and updates Firestore
 */
exports.transcodeVideo = functions.storage.object().onFinalize(async (object) => {
  const filePath = object.name;
  const contentType = object.contentType;

  // Only process video files
  if (!contentType || !contentType.startsWith('video/')) {
    console.log('Not a video file, skipping:', filePath);
    return null;
  }

  // Only process files in videos/{userId}/{videoId}.mp4 path
  const pathParts = filePath.split('/');
  if (pathParts.length !== 3 || pathParts[0] !== 'videos') {
    console.log('Not in videos/{userId}/{videoId}.mp4 format, skipping:', filePath);
    return null;
  }

  const userId = pathParts[1];
  const fileName = pathParts[2];
  
  // Extract videoId from filename (remove .mp4 extension)
  const videoId = fileName.replace('.mp4', '');
  
  console.log(`Processing video: ${videoId} for user: ${userId}`);

  const bucket = storage.bucket(object.bucket);
  const file = bucket.file(filePath);
  const tempFilePath = path.join(os.tmpdir(), fileName);
  const temp720Path = path.join(os.tmpdir(), `${videoId}_720p.mp4`);
  const temp480Path = path.join(os.tmpdir(), `${videoId}_480p.mp4`);

  try {
    // 1. Download original video
    console.log('Downloading original video...');
    await file.download({destination: tempFilePath});

    // 2. Generate 720p variant
    console.log('Generating 720p variant...');
    await transcodeVideo(tempFilePath, temp720Path, 720);
    
    // 3. Generate 480p variant
    console.log('Generating 480p variant...');
    await transcodeVideo(tempFilePath, temp480Path, 480);

    // 4. Upload variants to Storage
    console.log('Uploading variants to Storage...');
    const [url720, url480, url1080] = await Promise.all([
      uploadVariant(bucket, userId, videoId, temp720Path, '720p'),
      uploadVariant(bucket, userId, videoId, temp480Path, '480p'),
      file.getSignedUrl({action: 'read', expires: '03-09-2491'}), // Get original URL
    ]);

    // 5. Update Firestore with video URLs
    console.log('Updating Firestore...');
    const videoRef = db.collection('videos').doc(videoId);
    
    await videoRef.set({
      mp4_1080_url: url1080[0],
      mp4_720_url: url720,
      mp4_480_url: url480,
      videoUrl: url720, // Default to 720p for backward compatibility
      videoURL: url720, // Alternative field name
      transcodingStatus: 'completed',
      transcodedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    console.log(`✅ Successfully transcoded video ${videoId}`);

    // Cleanup temp files
    [tempFilePath, temp720Path, temp480Path].forEach(file => {
      if (fs.existsSync(file)) {
        fs.unlinkSync(file);
      }
    });

    return null;
  } catch (error) {
    console.error(`❌ Error transcoding video ${videoId}:`, error);
    
    // Update Firestore with error status
    await db.collection('videos').doc(videoId).set({
      transcodingStatus: 'failed',
      transcodingError: error.message,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    // Cleanup temp files
    [tempFilePath, temp720Path, temp480Path].forEach(file => {
      if (fs.existsSync(file)) {
        fs.unlinkSync(file);
      }
    });

    throw error;
  }
});

/**
 * Transcode video to target resolution
 */
function transcodeVideo(inputPath, outputPath, resolution) {
  return new Promise((resolve, reject) => {
    ffmpeg(inputPath)
      .videoCodec('libx264')
      .audioCodec('aac')
      .size(`${resolution}x?`) // Maintain aspect ratio
      .outputOptions([
        '-preset fast',
        '-crf 23', // Good quality/size balance
        '-movflags +faststart', // Enable streaming
        '-pix_fmt yuv420p', // Ensure compatibility
      ])
      .on('end', () => {
        console.log(`Transcoding completed: ${outputPath}`);
        resolve();
      })
      .on('error', (err) => {
        console.error(`Transcoding error: ${err.message}`);
        reject(err);
      })
      .save(outputPath);
  });
}

/**
 * Upload transcoded variant to Storage
 */
async function uploadVariant(bucket, userId, videoId, filePath, resolution) {
  const destinationPath = `videos/${userId}/${videoId}_${resolution}.mp4`;
  const destinationFile = bucket.file(destinationPath);
  
  await bucket.upload(filePath, {
    destination: destinationPath,
    metadata: {
      contentType: 'video/mp4',
      metadata: {
        resolution: resolution,
        videoId: videoId,
        transcodedAt: new Date().toISOString(),
      },
    },
  });

  // Get public URL
  const [url] = await destinationFile.getSignedUrl({
    action: 'read',
    expires: '03-09-2491', // Far future date
  });

  return url;
}
```

#### 3. Update `cloud_functions/index.js`

Add the new function export:
```javascript
const {transcodeVideo} = require('./src/videoTranscoding');

exports.transcodeVideo = transcodeVideo;
```

#### 4. Update Cloud Functions configuration

In `cloud_functions/package.json`, ensure Node.js version supports FFmpeg:
```json
{
  "engines": {
    "node": "18"
  }
}
```

#### 5. Deploy Cloud Function

```bash
cd cloud_functions
npm install
firebase deploy --only functions:transcodeVideo
```

---

## 📊 Firestore Schema Update

After transcoding, video documents will have:
```javascript
{
  id: "video123",
  userId: "user456",
  videoUrl: "https://storage.googleapis.com/.../video123_720p.mp4", // Default 720p
  videoURL: "https://storage.googleapis.com/.../video123_720p.mp4", // Alternative
  mp4_1080_url: "https://storage.googleapis.com/.../video123.mp4", // Original
  mp4_720_url: "https://storage.googleapis.com/.../video123_720p.mp4", // 720p variant
  mp4_480_url: "https://storage.googleapis.com/.../video123_480p.mp4", // 480p variant
  transcodingStatus: "completed",
  transcodedAt: Timestamp,
  // ... other fields
}
```

---

## 🔄 Backward Compatibility

### Existing Videos

For existing videos in your database:
1. **Option A:** Run a migration script to transcode existing videos
2. **Option B:** Let them transcode gradually as users interact with them
3. **Option C:** Keep using 1080p for existing videos (frontend will fall back)

### Migration Script (Optional)

Create a Cloud Function HTTP endpoint to trigger transcoding for existing videos:

```javascript
exports.transcodeExistingVideos = functions.https.onRequest(async (req, res) => {
  const videosSnapshot = await db.collection('videos')
    .where('transcodingStatus', '==', null)
    .limit(10) // Process in batches
    .get();

  const promises = videosSnapshot.docs.map(async (doc) => {
    const video = doc.data();
    if (video.videoUrl) {
      // Trigger transcoding by re-uploading or calling transcode function
      // Implementation depends on your setup
    }
  });

  await Promise.all(promises);
  res.json({processed: videosSnapshot.size});
});
```

---

## 💰 Cost Estimation

**Cloud Functions:**
- Invocations: $0.40 per 1M invocations
- Compute time: $0.0000025 per GB-second
- Storage: $0.026 per GB/month

**Example:**
- 1000 videos/month
- Average video: 30 seconds, 50MB
- Transcoding time: ~2 minutes per video
- Estimated cost: ~$5-10/month (very rough estimate)

---

## ✅ Testing

1. Upload a test video through your app
2. Check Cloud Functions logs: `firebase functions:log`
3. Verify Firestore document has `mp4_720_url` and `mp4_480_url` fields
4. Test video playback in app - should use 720p on low-memory devices

---

## 🚨 Important Notes

1. **Timeout:** Cloud Functions have a 540s timeout. For very long videos, consider Option 2 (Cloud Run).

2. **FFmpeg Layer:** You may need to use a Docker layer or pre-compiled FFmpeg binary. Consider using `@ffmpeg-installer/ffmpeg` or a custom layer.

3. **Storage Costs:** Generating multiple variants increases storage costs by ~2-3x. Consider lifecycle policies to delete old videos.

4. **Processing Queue:** For high-volume uploads, consider using Pub/Sub to queue transcoding jobs.

---

## 📝 Next Steps

1. ✅ Implement Cloud Function (Option 1)
2. ✅ Test with new video uploads
3. ✅ Verify frontend uses device-aware resolution selection
4. ⚠️ Monitor Cloud Function logs and errors
5. ⚠️ Set up monitoring/alerts for failed transcodings
6. ⚠️ Consider migration strategy for existing videos

