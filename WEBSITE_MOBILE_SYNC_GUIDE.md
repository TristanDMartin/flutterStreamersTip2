# Website & Mobile App Synchronization Guide

## 🎯 Goal
Keep video stats, creator info, and all data synchronized between mobile app and website in real-time.

---

## 1. 🔥 Firestore Real-Time Listeners (Recommended)

### Mobile App Side (Already Implemented)
Your Flutter app already uses Firestore listeners. Ensure consistency:

```dart
// lib/services/video_stats_sync_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoStatsSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Listen to real-time video stats updates
  Stream<Map<String, dynamic>> watchVideoStats(String videoId) {
    return _firestore
        .collection('videos')
        .doc(videoId)
        .snapshots()
        .map((snapshot) => snapshot.data() ?? {});
  }
  
  /// Update video stats (works from mobile OR web)
  Future<void> updateVideoStats({
    required String videoId,
    int? views,
    int? likes,
    int? comments,
    int? shares,
  }) async {
    final updates = <String, dynamic>{};
    
    if (views != null) updates['views'] = views;
    if (likes != null) updates['likes'] = likes;
    if (comments != null) updates['comments'] = comments;
    if (shares != null) updates['shares'] = shares;
    
    updates['updatedAt'] = FieldValue.serverTimestamp();
    
    await _firestore
        .collection('videos')
        .doc(videoId)
        .update(updates);
  }
  
  /// Increment stats atomically (prevents race conditions)
  Future<void> incrementVideoStat({
    required String videoId,
    required String stat, // 'views', 'likes', 'comments', 'shares'
    int amount = 1,
  }) async {
    await _firestore
        .collection('videos')
        .doc(videoId)
        .update({
          stat: FieldValue.increment(amount),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }
}
```

### Website Side (JavaScript/React)

```javascript
// website/src/services/videoStatsService.js
import { doc, onSnapshot, updateDoc, increment, serverTimestamp } from 'firebase/firestore';
import { db } from '../firebase/config';

/**
 * Listen to real-time video stats updates
 */
export function watchVideoStats(videoId, callback) {
  const videoRef = doc(db, 'videos', videoId);
  
  // Real-time listener
  const unsubscribe = onSnapshot(videoRef, (snapshot) => {
    if (snapshot.exists()) {
      const data = snapshot.data();
      
      // Normalize field names for website
      const normalizedData = {
        id: snapshot.id,
        userId: data.userId || data.creatorId || data.creator_id,
        creatorId: data.userId || data.creatorId || data.creator_id,
        creator_id: data.userId || data.creatorId || data.creator_id,
        views: data.views || 0,
        likes: data.likes || 0,
        comments: data.comments || 0,
        shares: data.shares || 0,
        videoUrl: data.videoUrl || data.videoURL,
        thumbnailUrl: data.thumbnailUrl || data.thumbnailURL,
        caption: data.caption || data.title,
        createdAt: data.createdAt,
        updatedAt: data.updatedAt,
        ...data
      };
      
      callback(normalizedData);
    }
  });
  
  // Return unsubscribe function for cleanup
  return unsubscribe;
}

/**
 * Update video stats from website
 */
export async function updateVideoStats(videoId, stats) {
  const videoRef = doc(db, 'videos', videoId);
  
  const updates = {
    ...stats,
    updatedAt: serverTimestamp()
  };
  
  await updateDoc(videoRef, updates);
}

/**
 * Increment stats atomically (prevents race conditions)
 */
export async function incrementVideoStat(videoId, stat, amount = 1) {
  const videoRef = doc(db, 'videos', videoId);
  
  await updateDoc(videoRef, {
    [stat]: increment(amount),
    updatedAt: serverTimestamp()
  });
}

/**
 * Example React Hook for real-time video data
 */
export function useVideoStats(videoId) {
  const [stats, setStats] = React.useState(null);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState(null);
  
  React.useEffect(() => {
    if (!videoId) return;
    
    setLoading(true);
    
    const unsubscribe = watchVideoStats(videoId, (data) => {
      setStats(data);
      setLoading(false);
    }, (err) => {
      setError(err);
      setLoading(false);
    });
    
    // Cleanup on unmount
    return () => unsubscribe();
  }, [videoId]);
  
  return { stats, loading, error };
}
```

---

## 2. ☁️ Cloud Functions for Data Consistency

Create Cloud Functions to ensure data stays synchronized across all platforms:

```javascript
// cloud_functions/functions/videoSync.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * Sync video stats to user profile when video is updated
 */
exports.syncVideoStatsToProfile = functions.firestore
  .document('videos/{videoId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const videoId = context.params.videoId;
    
    // Get creator ID (support all field variants)
    const creatorId = after.userId || after.creatorId || after.creator_id;
    if (!creatorId) {
      console.error(`Video ${videoId} has no creator ID`);
      return null;
    }
    
    // Check if stats changed
    const statsChanged = 
      before.views !== after.views ||
      before.likes !== after.likes ||
      before.comments !== after.comments ||
      before.shares !== after.shares;
    
    if (!statsChanged) {
      return null; // No stats update needed
    }
    
    // Update user's total stats
    const userRef = admin.firestore().collection('users').doc(creatorId);
    
    try {
      await admin.firestore().runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          console.error(`User ${creatorId} not found`);
          return;
        }
        
        const userData = userDoc.data();
        
        // Calculate deltas
        const viewsDelta = (after.views || 0) - (before.views || 0);
        const likesDelta = (after.likes || 0) - (before.likes || 0);
        const commentsDelta = (after.comments || 0) - (before.comments || 0);
        const sharesDelta = (after.shares || 0) - (before.shares || 0);
        
        // Update user's total stats
        transaction.update(userRef, {
          totalViews: (userData.totalViews || 0) + viewsDelta,
          totalLikes: (userData.totalLikes || 0) + likesDelta,
          totalComments: (userData.totalComments || 0) + commentsDelta,
          totalShares: (userData.totalShares || 0) + sharesDelta,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      });
      
      console.log(`✅ Synced stats for user ${creatorId} from video ${videoId}`);
    } catch (error) {
      console.error(`Error syncing stats: ${error}`);
    }
    
    return null;
  });

/**
 * Ensure creator fields are consistent when video is created/updated
 */
exports.normalizeVideoCreatorFields = functions.firestore
  .document('videos/{videoId}')
  .onWrite(async (change, context) => {
    const data = change.after.exists ? change.after.data() : null;
    if (!data) return null; // Document deleted
    
    const videoId = context.params.videoId;
    
    // Get creator ID from any field variant
    const creatorId = data.userId || data.creatorId || data.creator_id;
    
    if (!creatorId) {
      console.error(`Video ${videoId} has no creator ID in any field`);
      return null;
    }
    
    // Check if all three fields exist and match
    const needsUpdate = 
      data.userId !== creatorId ||
      data.creatorId !== creatorId ||
      data.creator_id !== creatorId;
    
    if (needsUpdate) {
      console.log(`🔄 Normalizing creator fields for video ${videoId}`);
      
      await change.after.ref.update({
        userId: creatorId,
        creatorId: creatorId,
        creator_id: creatorId
      });
      
      console.log(`✅ Creator fields normalized for video ${videoId}`);
    }
    
    return null;
  });

/**
 * Sync creator profile data to video document for faster reads
 */
exports.syncCreatorProfileToVideos = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const userId = context.params.userId;
    
    // Check if profile data changed
    const profileChanged = 
      before.displayName !== after.displayName ||
      before.username !== after.username ||
      before.avatarURL !== after.avatarURL;
    
    if (!profileChanged) {
      return null;
    }
    
    console.log(`🔄 User ${userId} profile changed, updating videos...`);
    
    // Update all videos by this creator
    const videosRef = admin.firestore()
      .collection('videos')
      .where('userId', '==', userId);
    
    const snapshot = await videosRef.get();
    
    if (snapshot.empty) {
      console.log(`No videos found for user ${userId}`);
      return null;
    }
    
    // Batch update all videos
    const batch = admin.firestore().batch();
    let count = 0;
    
    snapshot.docs.forEach((doc) => {
      batch.update(doc.ref, {
        creatorName: after.displayName,
        creatorUsername: after.username,
        creatorAvatar: after.avatarURL,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      count++;
    });
    
    await batch.commit();
    console.log(`✅ Updated ${count} videos for user ${userId}`);
    
    return null;
  });
```

Deploy these functions:
```bash
cd cloud_functions
firebase deploy --only functions
```

---

## 3. 🌐 Website Implementation (Full Example)

### React Component with Real-Time Sync

```jsx
// website/src/components/VideoPlayer.jsx
import React, { useState, useEffect } from 'react';
import { useVideoStats, incrementVideoStat } from '../services/videoStatsService';
import { watchUserProfile } from '../services/userService';

export function VideoPlayer({ videoId }) {
  const { stats, loading, error } = useVideoStats(videoId);
  const [creator, setCreator] = useState(null);
  const [hasIncrementedView, setHasIncrementedView] = useState(false);
  
  // Watch creator profile in real-time
  useEffect(() => {
    if (!stats?.creator_id) return;
    
    const unsubscribe = watchUserProfile(stats.creator_id, (profile) => {
      setCreator(profile);
    });
    
    return () => unsubscribe();
  }, [stats?.creator_id]);
  
  // Increment view count when video loads
  useEffect(() => {
    if (videoId && !hasIncrementedView) {
      incrementVideoStat(videoId, 'views');
      setHasIncrementedView(true);
    }
  }, [videoId, hasIncrementedView]);
  
  // Handle like button
  const handleLike = async () => {
    try {
      await incrementVideoStat(videoId, 'likes');
      // Stats will update automatically via real-time listener
    } catch (err) {
      console.error('Error liking video:', err);
    }
  };
  
  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;
  if (!stats) return <div>Video not found</div>;
  
  return (
    <div className="video-player">
      <video src={stats.videoUrl} controls />
      
      <div className="video-info">
        <h2>{stats.caption}</h2>
        
        {/* Creator info - updates in real-time */}
        {creator && (
          <div className="creator">
            <img src={creator.avatarURL} alt={creator.displayName} />
            <span>@{creator.username}</span>
          </div>
        )}
        
        {/* Stats - update in real-time */}
        <div className="stats">
          <span>👁 {stats.views?.toLocaleString()}</span>
          <button onClick={handleLike}>
            ❤️ {stats.likes?.toLocaleString()}
          </button>
          <span>💬 {stats.comments?.toLocaleString()}</span>
          <span>🔄 {stats.shares?.toLocaleString()}</span>
        </div>
      </div>
    </div>
  );
}
```

### User Service for Profile Data

```javascript
// website/src/services/userService.js
import { doc, onSnapshot } from 'firebase/firestore';
import { db } from '../firebase/config';

/**
 * Watch user profile in real-time
 */
export function watchUserProfile(userId, callback) {
  const userRef = doc(db, 'users', userId);
  
  const unsubscribe = onSnapshot(userRef, (snapshot) => {
    if (snapshot.exists()) {
      callback({
        id: snapshot.id,
        ...snapshot.data()
      });
    }
  });
  
  return unsubscribe;
}
```

---

## 4. 📊 Standardized Field Naming Schema

Create a shared schema document for both platforms:

```javascript
// shared/fieldNamingSchema.js
export const VIDEO_FIELDS = {
  // Creator fields (all three for compatibility)
  CREATOR_ID_MOBILE: 'userId',
  CREATOR_ID_CAMEL: 'creatorId', 
  CREATOR_ID_SNAKE: 'creator_id',
  
  // Video URLs
  VIDEO_URL: 'videoUrl',
  THUMBNAIL_URL: 'thumbnailUrl',
  
  // Stats
  VIEWS: 'views',
  LIKES: 'likes',
  COMMENTS: 'comments',
  SHARES: 'shares',
  
  // Metadata
  CAPTION: 'caption',
  CREATED_AT: 'createdAt',
  UPDATED_AT: 'updatedAt',
  STATUS: 'status',
  PRIVACY: 'privacy',
  
  // Denormalized creator data (for fast reads)
  CREATOR_NAME: 'creatorName',
  CREATOR_USERNAME: 'creatorUsername',
  CREATOR_AVATAR: 'creatorAvatar',
};

/**
 * Get creator ID from any field variant
 */
export function getCreatorId(videoData) {
  return videoData[VIDEO_FIELDS.CREATOR_ID_MOBILE] ||
         videoData[VIDEO_FIELDS.CREATOR_ID_CAMEL] ||
         videoData[VIDEO_FIELDS.CREATOR_ID_SNAKE];
}

/**
 * Normalize video data for consistent reading across platforms
 */
export function normalizeVideoData(data) {
  const creatorId = getCreatorId(data);
  
  return {
    ...data,
    // Ensure all creator ID variants exist
    [VIDEO_FIELDS.CREATOR_ID_MOBILE]: creatorId,
    [VIDEO_FIELDS.CREATOR_ID_CAMEL]: creatorId,
    [VIDEO_FIELDS.CREATOR_ID_SNAKE]: creatorId,
    
    // Normalize other fields
    videoUrl: data.videoUrl || data.videoURL,
    thumbnailUrl: data.thumbnailUrl || data.thumbnailURL,
    caption: data.caption || data.title,
  };
}
```

Use this in your website:

```javascript
// website/src/services/videoStatsService.js
import { normalizeVideoData } from '../shared/fieldNamingSchema';

export function watchVideoStats(videoId, callback) {
  const videoRef = doc(db, 'videos', videoId);
  
  const unsubscribe = onSnapshot(videoRef, (snapshot) => {
    if (snapshot.exists()) {
      const normalizedData = normalizeVideoData({
        id: snapshot.id,
        ...snapshot.data()
      });
      callback(normalizedData);
    }
  });
  
  return unsubscribe;
}
```

---

## 5. 🔄 Atomic Operations for Race Condition Prevention

### Mobile (Dart)
```dart
// lib/services/atomic_stats_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AtomicStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Like video atomically
  Future<void> likeVideo(String videoId, String userId) async {
    final batch = _firestore.batch();
    
    // 1. Increment video likes
    batch.update(
      _firestore.collection('videos').doc(videoId),
      {
        'likes': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    
    // 2. Add to user's liked videos
    batch.set(
      _firestore
          .collection('users')
          .doc(userId)
          .collection('likedVideos')
          .doc(videoId),
      {
        'likedAt': FieldValue.serverTimestamp(),
      },
    );
    
    await batch.commit();
  }
  
  /// Unlike video atomically
  Future<void> unlikeVideo(String videoId, String userId) async {
    final batch = _firestore.batch();
    
    // 1. Decrement video likes
    batch.update(
      _firestore.collection('videos').doc(videoId),
      {
        'likes': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    
    // 2. Remove from user's liked videos
    batch.delete(
      _firestore
          .collection('users')
          .doc(userId)
          .collection('likedVideos')
          .doc(videoId),
    );
    
    await batch.commit();
  }
}
```

### Website (JavaScript)
```javascript
// website/src/services/atomicStatsService.js
import { doc, writeBatch, increment, serverTimestamp } from 'firebase/firestore';
import { db } from '../firebase/config';

/**
 * Like video atomically
 */
export async function likeVideo(videoId, userId) {
  const batch = writeBatch(db);
  
  // 1. Increment video likes
  const videoRef = doc(db, 'videos', videoId);
  batch.update(videoRef, {
    likes: increment(1),
    updatedAt: serverTimestamp()
  });
  
  // 2. Add to user's liked videos
  const likeRef = doc(db, 'users', userId, 'likedVideos', videoId);
  batch.set(likeRef, {
    likedAt: serverTimestamp()
  });
  
  await batch.commit();
}

/**
 * Unlike video atomically
 */
export async function unlikeVideo(videoId, userId) {
  const batch = writeBatch(db);
  
  // 1. Decrement video likes
  const videoRef = doc(db, 'videos', videoId);
  batch.update(videoRef, {
    likes: increment(-1),
    updatedAt: serverTimestamp()
  });
  
  // 2. Remove from user's liked videos
  const likeRef = doc(db, 'users', userId, 'likedVideos', videoId);
  batch.delete(likeRef);
  
  await batch.commit();
}
```

---

## 6. 🎨 Website Firebase Configuration

```javascript
// website/src/firebase/config.js
import { initializeApp } from 'firebase/app';
import { getFirestore, enableIndexedDbPersistence } from 'firebase/firestore';
import { getAuth } from 'firebase/auth';
import { getStorage } from 'firebase/storage';

const firebaseConfig = {
  apiKey: process.env.REACT_APP_FIREBASE_API_KEY,
  authDomain: process.env.REACT_APP_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.REACT_APP_FIREBASE_PROJECT_ID,
  storageBucket: process.env.REACT_APP_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.REACT_APP_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.REACT_APP_FIREBASE_APP_ID,
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize services
export const db = getFirestore(app);
export const auth = getAuth(app);
export const storage = getStorage(app);

// Enable offline persistence (optional but recommended)
enableIndexedDbPersistence(db).catch((err) => {
  if (err.code === 'failed-precondition') {
    console.warn('Multiple tabs open, persistence enabled in first tab only');
  } else if (err.code === 'unimplemented') {
    console.warn('Browser doesn\'t support persistence');
  }
});

export default app;
```

---

## 7. 📱 Testing Sync Between Platforms

### Test Script for Mobile

```dart
// test/sync_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('Cross-Platform Sync Tests', () {
    test('Video stats update propagates', () async {
      final firestore = FirebaseFirestore.instance;
      final videoId = 'test_video_123';
      
      // 1. Create test video
      await firestore.collection('videos').doc(videoId).set({
        'userId': 'test_user',
        'creatorId': 'test_user',
        'creator_id': 'test_user',
        'views': 0,
        'likes': 0,
      });
      
      // 2. Increment likes
      await firestore.collection('videos').doc(videoId).update({
        'likes': FieldValue.increment(1),
      });
      
      // 3. Verify update
      final snapshot = await firestore.collection('videos').doc(videoId).get();
      expect(snapshot.data()?['likes'], equals(1));
      
      // Cleanup
      await firestore.collection('videos').doc(videoId).delete();
    });
  });
}
```

### Test Script for Website

```javascript
// website/src/tests/sync.test.js
import { doc, setDoc, updateDoc, getDoc, increment, deleteDoc } from 'firebase/firestore';
import { db } from '../firebase/config';

describe('Cross-Platform Sync Tests', () => {
  test('Video stats update propagates', async () => {
    const videoId = 'test_video_123';
    const videoRef = doc(db, 'videos', videoId);
    
    // 1. Create test video
    await setDoc(videoRef, {
      userId: 'test_user',
      creatorId: 'test_user',
      creator_id: 'test_user',
      views: 0,
      likes: 0,
    });
    
    // 2. Increment likes
    await updateDoc(videoRef, {
      likes: increment(1)
    });
    
    // 3. Verify update
    const snapshot = await getDoc(videoRef);
    expect(snapshot.data().likes).toBe(1);
    
    // Cleanup
    await deleteDoc(videoRef);
  });
});
```

---

## 8. 📋 Implementation Checklist

### Phase 1: Setup (Day 1)
- [ ] Run the migration script to fix existing videos
- [ ] Deploy Cloud Functions for data consistency
- [ ] Update website Firebase configuration
- [ ] Test Firestore security rules

### Phase 2: Website Implementation (Days 2-3)
- [ ] Install Firebase SDK on website: `npm install firebase`
- [ ] Create video stats service with real-time listeners
- [ ] Create user profile service with real-time listeners
- [ ] Implement atomic operations for likes/comments
- [ ] Add field normalization utilities

### Phase 3: Testing (Day 4)
- [ ] Test video upload from mobile → verify on website
- [ ] Test like from mobile → verify count updates on website
- [ ] Test like from website → verify count updates on mobile
- [ ] Test profile update → verify propagates to videos
- [ ] Test with multiple browsers/devices simultaneously

### Phase 4: Monitoring (Ongoing)
- [ ] Set up Firebase Analytics
- [ ] Monitor Cloud Function logs
- [ ] Track sync latency
- [ ] Monitor for field inconsistencies

---

## 9. 🚀 Quick Start Commands

```bash
# 1. Run migration to fix existing data
node scripts/migrate_video_creator_fields.js

# 2. Deploy Cloud Functions
cd cloud_functions
npm install
firebase deploy --only functions

# 3. Setup website (if using React)
cd website
npm install firebase
npm install

# 4. Test locally
npm start

# 5. Deploy website
npm run build
firebase deploy --only hosting
```

---

## 10. 🎯 Expected Results

### After Implementation:

✅ **Mobile uploads video** → Website sees it instantly  
✅ **Website likes video** → Mobile sees updated count in real-time  
✅ **User updates profile** → All their videos show new info everywhere  
✅ **Any platform updates stats** → All platforms sync automatically  
✅ **Offline changes** → Sync when back online  

### Performance:
- **Real-time updates:** < 100ms latency
- **Atomic operations:** No race conditions
- **Offline support:** Changes queue and sync automatically
- **Bandwidth efficient:** Only changed fields transmitted

---

## 📞 Support & Troubleshooting

### Common Issues:

**Issue:** Stats don't update in real-time  
**Fix:** Ensure you're using `onSnapshot` listeners, not one-time reads

**Issue:** Race conditions with likes/comments  
**Fix:** Use `FieldValue.increment()` instead of reading then writing

**Issue:** Website can't find creator_id  
**Fix:** Ensure migration script ran successfully

**Issue:** Data inconsistencies  
**Fix:** Cloud Functions should auto-fix, or run normalization script

---

## 📚 Additional Resources

- [Firestore Real-Time Updates](https://firebase.google.com/docs/firestore/query-data/listen)
- [Firestore Atomic Operations](https://firebase.google.com/docs/firestore/manage-data/transactions)
- [Cloud Functions for Firestore](https://firebase.google.com/docs/functions/firestore-events)
- [Firebase Security Rules](https://firebase.google.com/docs/firestore/security/get-started)

---

**Next Step:** Start with Phase 1 (run migration + deploy Cloud Functions), then implement website real-time listeners in Phase 2.

