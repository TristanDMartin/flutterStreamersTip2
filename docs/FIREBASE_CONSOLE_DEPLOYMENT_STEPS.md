# Firebase Console Deployment - Step-by-Step Guide

**Goal:** Deploy the video transcoding function via Firebase Console UI

---

## Step 1: Prepare the Function Code

The function code is already ready in:
- `cloud_functions/src/videoTranscoding.js`

You'll need to copy the code content for deployment.

---

## Step 2: Access Firebase Console

1. Go to: https://console.firebase.google.com/
2. Sign in with your Google account (streamerstip@gmail.com)
3. Select your project: **streamerstip-6cfdb**

---

## Step 3: Navigate to Functions

1. In the left sidebar, click **"Functions"**
2. If you see "Get started", click it
3. You should see your existing functions list

---

## Step 4: Create/Deploy New Function

### Option A: Deploy via Source Code (Recommended)

1. Click **"Create function"** or **"Add function"** button
2. Fill in the details:
   - **Function name:** `transcodeVideo`
   - **Region:** `us-central1` (or your preferred region)
   - **Runtime:** Select **Node.js 20**
   - **Memory:** `2 GB`
   - **Timeout:** `540 seconds` (9 minutes)
   - **Trigger type:** Select **Cloud Storage**
   - **Event type:** `Finalize/Create`
   - **Bucket:** `streamerstip-6cfdb.firebasestorage.app`
   - **Path:** `videos/{userId}/{videoId}.mp4`

3. **Source code:**
   - Copy the contents of `cloud_functions/src/videoTranscoding.js`
   - Paste into the function editor
   - **IMPORTANT:** Wrap it properly:

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
    // ... (paste the rest of the code from videoTranscoding.js)
  });
```

4. **Dependencies (package.json):**
   - The console might ask for dependencies
   - Add these:
     ```json
     {
       "@ffmpeg-installer/ffmpeg": "^1.1.0",
       "@google-cloud/storage": "^7.7.0",
       "firebase-admin": "^11.8.0",
       "firebase-functions": "^4.3.1",
       "fluent-ffmpeg": "^2.1.2"
     }
     ```

5. Click **"Deploy"** or **"Save"**

---

### Option B: Upload ZIP File (Alternative)

If the console allows file upload:

1. Create a ZIP file with:
   - `index.js` (with the function export)
   - `package.json` (with dependencies)
   - `src/videoTranscoding.js`

2. Upload the ZIP file
3. Deploy

---

## Step 5: Wait for Deployment

- Deployment takes 5-10 minutes
- Watch for "Deploying..." status
- Wait for "Active" status

---

## Step 6: Verify Deployment

1. Check function status: Should show **"Active"**
2. Check function logs: Click "Logs" tab
3. Verify runtime: Should show **Node.js 20**
4. Verify memory: Should show **2 GB**
5. Verify timeout: Should show **540 seconds**

---

## Step 7: Test the Function

### Test 1: Upload a Video

1. Upload a video through your Flutter app
2. Wait 2-5 minutes (transcoding time)
3. Check Cloud Functions logs for activity

### Test 2: Check Firestore

1. Go to Firestore Database in Firebase Console
2. Find the video document you just uploaded
3. Check for these fields:
   - `mp4_720_url` - Should have a URL
   - `mp4_480_url` - Should have a URL
   - `transcodingStatus` - Should be `"completed"`
   - `videoUrl` - Should point to 720p version

### Test 3: Check Storage

1. Go to Storage in Firebase Console
2. Navigate to `videos/{userId}/`
3. You should see:
   - `{videoId}.mp4` (original 1080p)
   - `{videoId}_720p.mp4` (transcoded)
   - `{videoId}_480p.mp4` (transcoded)

---

## Troubleshooting

### Function Not Triggering

- Check trigger path matches: `videos/{userId}/{videoId}.mp4`
- Check bucket name matches
- Check function logs for errors

### Transcoding Fails

- Check function logs for error messages
- Check Firestore: `transcodingStatus` = `"failed"`
- Check `transcodingError` field for details

### Function Timeout

- Videos longer than ~5-7 minutes may timeout
- Consider using Cloud Run for longer videos
- Or split into separate functions (720p, then 480p)

---

## Success Checklist

- [ ] Function deployed and shows "Active"
- [ ] Runtime is Node.js 20
- [ ] Memory is 2 GB
- [ ] Uploaded test video triggers function
- [ ] Firestore document has `mp4_720_url` and `mp4_480_url`
- [ ] `transcodingStatus` is `"completed"`
- [ ] Storage bucket has transcoded variants

---

**Once deployed, the function will automatically generate 720p/480p variants for all new video uploads!**

