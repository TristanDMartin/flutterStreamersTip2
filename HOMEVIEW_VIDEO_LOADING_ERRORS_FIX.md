# HomeView Video Loading Errors Fix Guide

## 🔴 **Error Summary**

Your Flutter app's HomeView is experiencing:
1. **MIME Type Errors**: Resources served as `text/plain` instead of proper types
2. **404 Errors**: Video resources not found
3. **Videos Not Appearing**: Videos fail to load in HomeView

---

## 🔍 **Root Causes**

### **1. Invalid or Missing Video URLs**
- Video URLs in Firestore are empty or invalid
- Video URLs pointing to wrong server (e.g., `localhost:3000` instead of Firebase Storage)
- Video URLs using wrong format

### **2. Firebase Storage CORS Issues**
- Firebase Storage not configured for CORS
- Video URLs not accessible from Flutter app

### **3. Video Upload Issues**
- Videos not properly uploaded to Firebase Storage
- Video URLs not saved correctly in Firestore

---

## ✅ **Diagnostic Steps**

### **Step 1: Check Video URLs in Firestore**

Run this diagnostic script to check your videos:

```dart
// Create file: check_video_urls.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> checkVideoUrls() async {
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  
  // Wait for auth
  await auth.signInAnonymously();
  
  final snapshot = await firestore
      .collection('videos')
      .where('status', isEqualTo: 'published')
      .limit(10)
      .get();
  
  print('📊 Found ${snapshot.docs.length} published videos\n');
  
  for (final doc in snapshot.docs) {
    final data = doc.data();
    final videoUrl = data['videoUrl'] as String? ?? '';
    final videoURL = data['videoURL'] as String? ?? '';
    final url = videoUrl.isNotEmpty ? videoUrl : videoURL;
    
    print('Video ID: ${doc.id}');
    print('  URL Field: ${url.isEmpty ? "❌ MISSING" : "✅ EXISTS"}');
    print('  URL: ${url.isEmpty ? "N/A" : url.substring(0, url.length > 50 ? 50 : url.length)}...');
    print('  Valid: ${url.startsWith("http") ? "✅" : "❌"}');
    print('  Firebase Storage: ${url.contains("firebasestorage") ? "✅" : "❌"}');
    print('');
  }
}
```

### **Step 2: Check VideoService Logs**

Look for these debug messages in your console:

```
🎬 VideoService: ✅ Video URL check passed for {videoId} - URL length: {length}
🎬 VideoService: ⚠️ SKIPPING video {videoId} - no videoUrl field
```

**If you see "SKIPPING" messages:**
- Videos in Firestore are missing `videoUrl` field
- Need to re-upload videos or fix Firestore data

### **Step 3: Check Video Player Errors**

Look for these error messages:

```
❌ VideoPlayer: Error initializing video: {videoId}
🎥 Video Error (Handled): {error}
```

**Common errors:**
- `404 Not Found` → Video URL doesn't exist
- `Network error` → Connection issue or CORS problem
- `Invalid URL` → URL format is wrong

---

## 🔧 **Solutions**

### **Solution 1: Fix Missing Video URLs**

If videos are missing URLs in Firestore:

**Option A: Re-upload Videos**
1. Go to your video upload flow
2. Re-upload videos that are missing URLs
3. Ensure `videoUrl` is saved to Firestore after upload

**Option B: Fix Firestore Data Manually**
```dart
// Fix script - run once
Future<void> fixVideoUrls() async {
  final firestore = FirebaseFirestore.instance;
  final snapshot = await firestore.collection('videos').get();
  
  for (final doc in snapshot.docs) {
    final data = doc.data();
    final videoUrl = data['videoUrl'] as String? ?? '';
    
    if (videoUrl.isEmpty) {
      // If video exists in Storage but URL missing, reconstruct it
      final storagePath = 'videos/${doc.id}.mp4';
      final storageUrl = 'https://firebasestorage.googleapis.com/v0/b/YOUR_PROJECT_ID.appspot.com/o/${Uri.encodeComponent(storagePath)}?alt=media';
      
      await doc.reference.update({'videoUrl': storageUrl});
      print('✅ Fixed video ${doc.id}');
    }
  }
}
```

### **Solution 2: Fix Invalid Video URLs**

If URLs point to wrong server (e.g., `localhost:3000`):

```dart
// Fix script - update URLs to Firebase Storage
Future<void> fixInvalidUrls() async {
  final firestore = FirebaseFirestore.instance;
  final snapshot = await firestore
      .collection('videos')
      .where('status', isEqualTo: 'published')
      .get();
  
  for (final doc in snapshot.docs) {
    final data = doc.data();
    final videoUrl = data['videoUrl'] as String? ?? '';
    
    // Check if URL is invalid
    if (videoUrl.contains('localhost') || 
        videoUrl.contains('127.0.0.1') ||
        !videoUrl.startsWith('http')) {
      
      // Reconstruct Firebase Storage URL
      final storagePath = 'videos/${doc.id}.mp4';
      final projectId = 'YOUR_PROJECT_ID'; // Replace with your project ID
      final storageUrl = 'https://firebasestorage.googleapis.com/v0/b/$projectId.appspot.com/o/${Uri.encodeComponent(storagePath)}?alt=media';
      
      await doc.reference.update({'videoUrl': storageUrl});
      print('✅ Fixed invalid URL for video ${doc.id}');
    }
  }
}
```

### **Solution 3: Verify Firebase Storage CORS**

Ensure Firebase Storage allows requests from your app:

1. Go to Firebase Console → Storage → Rules
2. Ensure rules allow read access:
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /videos/{videoId} {
      allow read: if true; // Allow public read for videos
      allow write: if request.auth != null;
    }
  }
}
```

3. Check CORS configuration (if using custom domain):
   - Go to Firebase Console → Storage → Settings
   - Ensure CORS is configured for your app's origin

### **Solution 4: Add Better Error Handling**

Update `VideoService` to skip videos with invalid URLs:

```dart
// In lib/services/video_service.dart, around line 127
final videoUrl = data['videoUrl'] as String? ?? '';
if (videoUrl.isEmpty || !videoUrl.startsWith('http')) {
  debugPrint('🎬 VideoService: ⚠️ SKIPPING video ${doc.id} - invalid URL: "$videoUrl"');
  continue;
}
```

### **Solution 5: Add Video URL Validation**

Add validation in `VideoPlayerViewOptimized`:

```dart
// In lib/widgets/video_player_view_optimized.dart, around line 937
Future<void> _initializeVideo({bool isRetry = false}) async {
  // Validate video URL first
  if (widget.video.videoURL.isEmpty) {
    _handleVideoError('Video URL is empty');
    return;
  }
  
  if (!widget.video.videoURL.startsWith('http')) {
    _handleVideoError('Invalid video URL format');
    return;
  }
  
  // Continue with initialization...
  _videoPlayerController = VideoPlayerController.networkUrl(
    Uri.parse(widget.video.videoURL),
    // ...
  );
}
```

---

## 🎯 **Quick Fix Checklist**

- [ ] Check Firestore for videos with missing `videoUrl` field
- [ ] Verify video URLs point to Firebase Storage (not localhost)
- [ ] Check Firebase Storage rules allow read access
- [ ] Verify videos exist in Firebase Storage
- [ ] Check browser/device console for specific error messages
- [ ] Test video URL in browser to verify it's accessible
- [ ] Re-upload videos if URLs are missing
- [ ] Clear app cache and restart

---

## 📝 **Debugging Commands**

### **Check Video Count**
```dart
final snapshot = await FirebaseFirestore.instance
    .collection('videos')
    .where('status', isEqualTo: 'published')
    .get();
print('Published videos: ${snapshot.docs.length}');
```

### **Check Videos with URLs**
```dart
final snapshot = await FirebaseFirestore.instance
    .collection('videos')
    .where('status', isEqualTo: 'published')
    .get();

int withUrls = 0;
for (final doc in snapshot.docs) {
  final url = doc.data()['videoUrl'] as String? ?? '';
  if (url.isNotEmpty && url.startsWith('http')) {
    withUrls++;
  }
}
print('Videos with valid URLs: $withUrls/${snapshot.docs.length}');
```

---

## 🆘 **If Still Not Working**

Share:
1. **Firestore video document** (anonymized) showing `videoUrl` field
2. **Console logs** from `VideoService` and `VideoPlayerViewOptimized`
3. **Error messages** from browser/device console
4. **Video URL example** (first 50 characters)

This will help diagnose the specific issue.

