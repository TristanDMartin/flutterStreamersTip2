# Quick Start: Deploy & Verify Video Transcoding Fix

**Goal:** Deploy the function and verify it's working in your app (15 minutes)

---

## 🚀 Part 1: Deploy Function (5 minutes)

### Step 1: Open Firebase Console
1. Go to: https://console.firebase.google.com/
2. Select: **streamerstip-6cfdb**
3. Click: **Functions** (left sidebar)

### Step 2: Create Function
1. Click **"Create function"**
2. Fill in:
   - **Name:** `transcodeVideo`
   - **Runtime:** `Node.js 20`
   - **Memory:** `2 GB`
   - **Timeout:** `540 seconds`
   - **Trigger:** `Cloud Storage` → `Finalize` → Bucket: `streamerstip-6cfdb.firebasestorage.app`
   - **Path:** `videos/{userId}/{videoId}.mp4`

### Step 3: Paste Code
Copy the code from: `cloud_functions/src/videoTranscoding.js`

Or use the simplified version from: `docs/COMPLETE_DEPLOYMENT_GUIDE.md` (Step 3)

### Step 4: Add Dependencies
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
- Click **"Deploy"**
- Wait 5-10 minutes
- Status should be **"Active"**

---

## ✅ Part 2: Verify It's Working (10 minutes)

### Test 1: Upload Video & Check Firestore (5 min)

1. **Upload a video** through your Flutter app
2. **Wait 2-5 minutes**
3. **Check Firestore:**
   - Firebase Console → Firestore Database
   - Find the video document
   - ✅ Look for: `mp4_720_url` field (should have URL)
   - ✅ Look for: `transcodingStatus` = `"completed"`

**If you see these fields → Function is working! ✅**

### Test 2: Test in App (5 min)

1. **Run your app:**
   ```bash
   flutter run
   ```

2. **Scroll to the video you just uploaded**

3. **Expected:**
   - ✅ Video plays (no crash!)
   - ✅ App is stable
   - ✅ No errors in logs

**If video plays without crashing → Fix is working! ✅**

---

## 📊 Quick Verification Checklist

After deployment and testing, verify:

- [ ] Function is Active in Firebase Console
- [ ] Uploaded a new video
- [ ] Firestore has `mp4_720_url` field
- [ ] `transcodingStatus` is `"completed"`
- [ ] Video plays in app (no crash)
- [ ] No OutOfMemoryError in logs

**All checked ✅ = Fix is working! 🎉**

---

## 🎯 What You Should See

### In Firestore:
```javascript
{
  mp4_720_url: "https://storage.googleapis.com/.../video123_720p.mp4", ✅
  mp4_480_url: "https://storage.googleapis.com/.../video123_480p.mp4", ✅
  transcodingStatus: "completed", ✅
  // ...
}
```

### In App:
- Video plays smoothly ✅
- No crashes ✅
- No memory errors ✅
- Stable performance ✅

---

## 📝 Full Guides Available

- **Detailed deployment:** `docs/FIREBASE_CONSOLE_DEPLOYMENT_STEPS.md`
- **Complete guide:** `docs/COMPLETE_DEPLOYMENT_GUIDE.md`
- **Verification details:** `docs/VERIFY_TRANSCODING_FIX.md`

---

**Once deployed and verified, new videos will automatically get 720p variants, and the app will use them on low-memory devices - no more crashes! 🚀**

