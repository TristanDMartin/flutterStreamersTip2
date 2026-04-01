# Complete Deployment & Verification Guide

**Purpose:** Deploy video transcoding function and verify it's working in the app

---

## 📋 Overview

This guide covers:
1. Deploying the function via Firebase Console
2. Verifying the function is working
3. Testing in your Flutter app
4. Confirming the memory crash fix

---

## Part 1: Deploy Function via Firebase Console

### Step 1: Access Firebase Console
1. Go to: https://console.firebase.google.com/
2. Sign in with: streamerstip@gmail.com
3. Select project: **streamerstip-6cfdb**
4. Click **Functions** in left sidebar

### Step 2: Create New Function
1. Click **"Create function"** or **"Add function"**
2. Configure:
   - **Function name:** `transcodeVideo`
   - **Region:** `us-central1`
   - **Runtime:** `Node.js 20`
   - **Memory:** `2 GB`
   - **Timeout:** `540 seconds`
   - **Trigger:** `Cloud Storage`
   - **Event:** `Finalize/Create`
   - **Bucket:** `streamerstip-6cfdb.firebasestorage.app`
   - **Path:** `videos/{userId}/{videoId}.mp4`

### Step 3: Add Function Code

Copy this complete code (includes all dependencies and logic):

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {Storage} = require('@google-cloud/storage');
const ffmpeg = require('fluent-ffmpeg');
const ffmpegPath = require('@ffmpeg-installer/ffmpeg').path;
const fs = require('fs');
const path = require('path');
const os = require('os');

admin.initializeApp();
ffmpeg.setFfmpegPath(ffmpegPath);

const storage = new Storage();
const db = admin.firestore();

exports.transcodeVideo = functions
  .runWith({
    timeoutSeconds: 540,
    memory: '2GB',
  })
  .storage.object().onFinalize(async (object) => {
    const filePath = object.name;
    const contentType = object.contentType;
    const bucketName = object.bucket;

    if (!contentType || !contentType.startsWith('video/')) {
      console.log('Not a video file, skipping:', filePath);
      return null;
    }

    const pathParts = filePath.split('/');
    if (pathParts.length !== 3 || pathParts[0] !== 'videos') {
      console.log('Not in videos/{userId}/{videoId}.mp4 format, skipping:', filePath);
      return null;
    }

    const userId = pathParts[1];
    const fileName = pathParts[2];
    const videoId = fileName.replace('.mp4', '');
    
    console.log(`🎬 Processing video: ${videoId} for user: ${userId}`);

    const bucket = storage.bucket(bucketName);
    const file = bucket.file(filePath);
    
    const tempDir = os.tmpdir();
    const tempFilePath = path.join(tempDir, `${videoId}_original.mp4`);
    const temp720Path = path.join(tempDir, `${videoId}_720p.mp4`);
    const temp480Path = path.join(tempDir, `${videoId}_480p.mp4`);

    try {
      await db.collection('videos').doc(videoId).set({
        transcodingStatus: 'processing',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      console.log('📥 Downloading original video...');
      await file.download({destination: tempFilePath});

      console.log('🎞️ Generating 720p variant...');
      await new Promise((resolve, reject) => {
        ffmpeg(tempFilePath)
          .videoCodec('libx264')
          .audioCodec('aac')
          .size('720x?')
          .outputOptions([
            '-preset fast',
            '-crf 23',
            '-movflags +faststart',
            '-pix_fmt yuv420p',
          ])
          .on('end', resolve)
          .on('error', reject)
          .save(temp720Path);
      });

      console.log('🎞️ Generating 480p variant...');
      await new Promise((resolve, reject) => {
        ffmpeg(tempFilePath)
          .videoCodec('libx264')
          .audioCodec('aac')
          .size('480x?')
          .outputOptions([
            '-preset fast',
            '-crf 23',
            '-movflags +faststart',
            '-pix_fmt yuv420p',
          ])
          .on('end', resolve)
          .on('error', reject)
          .save(temp480Path);
      });

      console.log('📤 Uploading variants...');
      const [url720, url480, url1080] = await Promise.all([
        (async () => {
          const destPath = `videos/${userId}/${videoId}_720p.mp4`;
          await bucket.upload(temp720Path, {destination: destPath});
          return `https://storage.googleapis.com/${bucketName}/${destPath}`;
        })(),
        (async () => {
          const destPath = `videos/${userId}/${videoId}_480p.mp4`;
          await bucket.upload(temp480Path, {destination: destPath});
          return `https://storage.googleapis.com/${bucketName}/${destPath}`;
        })(),
        `https://storage.googleapis.com/${bucketName}/${filePath}`,
      ]);

      console.log('💾 Updating Firestore...');
      await db.collection('videos').doc(videoId).set({
        mp4_1080_url: url1080,
        mp4_720_url: url720,
        mp4_480_url: url480,
        videoUrl: url720,
        videoURL: url720,
        transcodingStatus: 'completed',
        transcodedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      console.log(`✅ Successfully transcoded video ${videoId}`);

      [tempFilePath, temp720Path, temp480Path].forEach(f => {
        if (fs.existsSync(f)) fs.unlinkSync(f);
      });

      return null;
    } catch (error) {
      console.error(`❌ Error:`, error);
      await db.collection('videos').doc(videoId).set({
        transcodingStatus: 'failed',
        transcodingError: error.message,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      [tempFilePath, temp720Path, temp480Path].forEach(f => {
        if (fs.existsSync(f)) fs.unlinkSync(f);
      });

      throw error;
    }
  });
```

### Step 4: Add Dependencies

If the console asks for dependencies, add:

```json
{
  "@ffmpeg-installer/ffmpeg": "^1.1.0",
  "@google-cloud/storage": "^7.7.0",
  "firebase-admin": "^11.8.0",
  "firebase-functions": "^4.3.1",
  "fluent-ffmpeg": "^2.1.2"
}
```

### Step 5: Deploy

1. Click **"Deploy"** or **"Save"**
2. Wait 5-10 minutes for deployment
3. Function should show **"Active"** status

---

## Part 2: Verify Function is Working

### Check 1: Function Status
- Firebase Console → Functions → `transcodeVideo`
- Status: **Active** ✅
- Runtime: **Node.js 20** ✅
- Memory: **2 GB** ✅

### Check 2: Upload Test Video
1. Open your Flutter app
2. Upload a new video (10-30 seconds)
3. Wait 2-5 minutes

### Check 3: Firestore Verification
1. Firebase Console → Firestore Database
2. Find the video document
3. Verify fields:
   - ✅ `mp4_720_url` exists
   - ✅ `mp4_480_url` exists
   - ✅ `transcodingStatus` = `"completed"`

### Check 4: Storage Verification
1. Firebase Console → Storage
2. Navigate to `videos/{userId}/`
3. Should see:
   - ✅ `{videoId}.mp4` (original)
   - ✅ `{videoId}_720p.mp4` (transcoded)
   - ✅ `{videoId}_480p.mp4` (transcoded)

---

## Part 3: Test in Flutter App

### Test on 256MB Device/Emulator

1. **Run the app:**
   ```bash
   flutter run
   ```

2. **Scroll to the newly uploaded video**

3. **Expected results:**
   - ✅ Video plays (no crash!)
   - ✅ No OutOfMemoryError
   - ✅ App is stable
   - ✅ Video loads successfully

### Check App Logs

Look for:
```
🎬 VideoPlayer: Using device-aware resolution: 720p
```

Or check logs:
```bash
flutter logs | grep -i "720\|resolution\|transcoding"
```

---

## ✅ Success Checklist

- [ ] Function deployed and Active
- [ ] New video uploaded
- [ ] Firestore has `mp4_720_url` field
- [ ] Firestore has `mp4_480_url` field
- [ ] `transcodingStatus` is `"completed"`
- [ ] Storage has transcoded files
- [ ] Video plays in app (no crash)
- [ ] No OutOfMemoryError in logs

**If all checked ✅, the fix is working!**

---

## 🎉 What This Fixes

**Before:**
- ❌ Only 1080p videos
- ❌ Crashes on 256MB devices
- ❌ OutOfMemoryError

**After:**
- ✅ 720p and 480p variants
- ✅ No crashes on 256MB devices
- ✅ Stable app performance

The app will automatically use 720p videos on low-memory devices, preventing crashes! 🚀

