# Website Video Feed Implementation - Display Mobile App Videos

## 🎯 Goal
Display videos uploaded from the mobile app on the website with real-time sync.

---

## 📋 Quick Overview

This implementation will:
- ✅ Display all videos from mobile app on website
- ✅ Show creator info (name, avatar) for each video
- ✅ Display real-time stats (views, likes, comments)
- ✅ Update automatically when new videos are uploaded from mobile
- ✅ Support liking/commenting from website
- ✅ Sync all interactions back to mobile app

---

## Step 1: Install Firebase SDK

```bash
npm install firebase
```

---

## Step 2: Create Firebase Configuration

Create file: `src/firebase/config.js`

```javascript
import { initializeApp } from 'firebase/app';
import { getFirestore, enableIndexedDbPersistence } from 'firebase/firestore';
import { getAuth } from 'firebase/auth';
import { getStorage } from 'firebase/storage';

// Your Firebase config from Firebase Console
// Go to: Firebase Console > Project Settings > General > Your apps
const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_PROJECT_ID.appspot.com",
  messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
  appId: "YOUR_APP_ID"
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

## Step 3: Create Video Feed Service

Create file: `src/services/videoFeedService.js`

```javascript
import { 
  collection, 
  query, 
  where, 
  orderBy, 
  limit, 
  onSnapshot,
  doc,
  getDoc,
  updateDoc,
  increment,
  serverTimestamp,
  writeBatch
} from 'firebase/firestore';
import { db } from '../firebase/config';

/**
 * Get creator ID from video data (supports all field variants)
 */
function getCreatorId(videoData) {
  return videoData.userId || videoData.creatorId || videoData.creator_id;
}

/**
 * Watch all published videos in real-time
 * Videos from mobile app will appear automatically
 */
export function watchAllVideos(callback, onError) {
  try {
    const videosQuery = query(
      collection(db, 'videos'),
      where('status', '==', 'published'),
      orderBy('createdAt', 'desc'),
      limit(50)
    );
    
    const unsubscribe = onSnapshot(
      videosQuery,
      async (snapshot) => {
        console.log(`📹 Loaded ${snapshot.docs.length} videos from Firestore`);
        const videos = [];
        
        // Process each video
        for (const docSnap of snapshot.docs) {
          const data = docSnap.data();
          
          // Get creator ID (supports mobile app field names)
          const creatorId = getCreatorId(data);
          
          if (!creatorId) {
            console.warn(`⚠️ Video ${docSnap.id} has no creator ID, skipping`);
            continue;
          }
          
          // Get creator info from users collection
          let creatorData = null;
          try {
            const creatorDoc = await getDoc(doc(db, 'users', creatorId));
            if (creatorDoc.exists()) {
              creatorData = creatorDoc.data();
            } else {
              console.warn(`⚠️ Creator ${creatorId} not found`);
            }
          } catch (err) {
            console.error(`Error fetching creator ${creatorId}:`, err);
          }
          
          // Build video object
          const video = {
            id: docSnap.id,
            // Video URLs (support both naming conventions)
            videoUrl: data.videoUrl || data.videoURL || '',
            thumbnailUrl: data.thumbnailUrl || data.thumbnailURL || '',
            
            // Video info
            caption: data.caption || data.title || 'Untitled',
            
            // Stats (sync in real-time from mobile)
            views: data.views || 0,
            likes: data.likes || 0,
            comments: data.comments || 0,
            shares: data.shares || 0,
            
            // Timestamps
            createdAt: data.createdAt?.toDate() || new Date(),
            updatedAt: data.updatedAt?.toDate() || new Date(),
            
            // Creator info
            creator: {
              id: creatorId,
              displayName: creatorData?.displayName || 'Unknown User',
              username: creatorData?.username || 'unknown',
              avatarURL: creatorData?.avatarURL || null,
              bio: creatorData?.bio || '',
            },
            
            // Additional metadata
            privacy: data.privacy || 'Everyone',
            status: data.status || 'published',
          };
          
          videos.push(video);
        }
        
        console.log(`✅ Processed ${videos.length} videos with creator info`);
        callback(videos);
      },
      (error) => {
        console.error('❌ Error watching videos:', error);
        if (onError) onError(error);
      }
    );
    
    return unsubscribe;
  } catch (error) {
    console.error('❌ Error setting up video watcher:', error);
    if (onError) onError(error);
    return () => {}; // Return empty unsubscribe function
  }
}

/**
 * Like a video (syncs to mobile app in real-time)
 */
export async function likeVideo(videoId, userId) {
  try {
    const batch = writeBatch(db);
    
    // 1. Increment video likes count
    const videoRef = doc(db, 'videos', videoId);
    batch.update(videoRef, {
      likes: increment(1),
      updatedAt: serverTimestamp()
    });
    
    // 2. Add to user's liked videos
    const likeRef = doc(db, 'users', userId, 'likedVideos', videoId);
    batch.set(likeRef, {
      likedAt: serverTimestamp(),
      videoId: videoId
    });
    
    // 3. Add to likes subcollection (for notifications)
    const likesRef = doc(db, 'likes', videoId, 'byUser', userId);
    batch.set(likesRef, {
      userId: userId,
      videoId: videoId,
      likedAt: serverTimestamp()
    });
    
    await batch.commit();
    console.log(`✅ Liked video ${videoId}`);
    
    return true;
  } catch (error) {
    console.error(`❌ Error liking video ${videoId}:`, error);
    throw error;
  }
}

/**
 * Unlike a video (syncs to mobile app in real-time)
 */
export async function unlikeVideo(videoId, userId) {
  try {
    const batch = writeBatch(db);
    
    // 1. Decrement video likes count
    const videoRef = doc(db, 'videos', videoId);
    batch.update(videoRef, {
      likes: increment(-1),
      updatedAt: serverTimestamp()
    });
    
    // 2. Remove from user's liked videos
    const likeRef = doc(db, 'users', userId, 'likedVideos', videoId);
    batch.delete(likeRef);
    
    // 3. Remove from likes subcollection
    const likesRef = doc(db, 'likes', videoId, 'byUser', userId);
    batch.delete(likesRef);
    
    await batch.commit();
    console.log(`✅ Unliked video ${videoId}`);
    
    return true;
  } catch (error) {
    console.error(`❌ Error unliking video ${videoId}:`, error);
    throw error;
  }
}

/**
 * Check if user has liked a video
 */
export async function hasLikedVideo(videoId, userId) {
  try {
    const likeDoc = await getDoc(doc(db, 'users', userId, 'likedVideos', videoId));
    return likeDoc.exists();
  } catch (error) {
    console.error(`❌ Error checking like status:`, error);
    return false;
  }
}

/**
 * Increment view count (call when video starts playing)
 */
export async function incrementViewCount(videoId) {
  try {
    await updateDoc(doc(db, 'videos', videoId), {
      views: increment(1),
      updatedAt: serverTimestamp()
    });
    console.log(`✅ View count incremented for ${videoId}`);
  } catch (error) {
    console.error(`❌ Error incrementing view count:`, error);
  }
}
```

---

## Step 4: Create React Component

Create file: `src/components/VideoFeed.jsx`

```jsx
import React, { useState, useEffect } from 'react';
import { watchAllVideos, likeVideo, unlikeVideo, hasLikedVideo, incrementViewCount } from '../services/videoFeedService';
import { auth } from '../firebase/config';
import './VideoFeed.css';

export function VideoFeed() {
  const [videos, setVideos] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [likedVideos, setLikedVideos] = useState(new Set());
  const currentUser = auth.currentUser;
  
  // Load videos in real-time
  useEffect(() => {
    console.log('🎬 Setting up real-time video feed...');
    
    const unsubscribe = watchAllVideos(
      (newVideos) => {
        console.log(`📹 Received ${newVideos.length} videos`);
        setVideos(newVideos);
        setLoading(false);
        
        // Check which videos current user has liked
        if (currentUser) {
          checkLikedVideos(newVideos);
        }
      },
      (err) => {
        console.error('❌ Error loading videos:', err);
        setError(err.message);
        setLoading(false);
      }
    );
    
    // Cleanup listener on unmount
    return () => {
      console.log('🧹 Cleaning up video feed listener');
      unsubscribe();
    };
  }, [currentUser]);
  
  // Check which videos user has liked
  const checkLikedVideos = async (videosToCheck) => {
    if (!currentUser) return;
    
    const liked = new Set();
    for (const video of videosToCheck) {
      const isLiked = await hasLikedVideo(video.id, currentUser.uid);
      if (isLiked) {
        liked.add(video.id);
      }
    }
    setLikedVideos(liked);
  };
  
  // Handle like button click
  const handleLike = async (videoId) => {
    if (!currentUser) {
      alert('Please sign in to like videos');
      return;
    }
    
    const isLiked = likedVideos.has(videoId);
    
    try {
      if (isLiked) {
        await unlikeVideo(videoId, currentUser.uid);
        setLikedVideos(prev => {
          const newSet = new Set(prev);
          newSet.delete(videoId);
          return newSet;
        });
      } else {
        await likeVideo(videoId, currentUser.uid);
        setLikedVideos(prev => new Set(prev).add(videoId));
      }
    } catch (err) {
      console.error('Error toggling like:', err);
      alert('Failed to like video. Please try again.');
    }
  };
  
  // Handle video play (increment view count)
  const handleVideoPlay = (videoId) => {
    incrementViewCount(videoId);
  };
  
  // Format number for display
  const formatCount = (count) => {
    if (count >= 1000000) {
      return `${(count / 1000000).toFixed(1)}M`;
    }
    if (count >= 1000) {
      return `${(count / 1000).toFixed(1)}K`;
    }
    return count.toString();
  };
  
  // Format date
  const formatDate = (date) => {
    const now = new Date();
    const diff = now - date;
    const seconds = Math.floor(diff / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);
    
    if (days > 0) return `${days}d ago`;
    if (hours > 0) return `${hours}h ago`;
    if (minutes > 0) return `${minutes}m ago`;
    return 'Just now';
  };
  
  if (loading) {
    return (
      <div className="video-feed-loading">
        <div className="spinner"></div>
        <p>Loading videos from mobile app...</p>
      </div>
    );
  }
  
  if (error) {
    return (
      <div className="video-feed-error">
        <h3>Error Loading Videos</h3>
        <p>{error}</p>
        <button onClick={() => window.location.reload()}>Retry</button>
      </div>
    );
  }
  
  if (videos.length === 0) {
    return (
      <div className="video-feed-empty">
        <h3>No Videos Yet</h3>
        <p>Videos uploaded from the mobile app will appear here automatically.</p>
      </div>
    );
  }
  
  return (
    <div className="video-feed">
      <div className="video-feed-header">
        <h1>Video Feed</h1>
        <p>{videos.length} videos • Real-time sync enabled ✨</p>
      </div>
      
      <div className="video-grid">
        {videos.map((video) => (
          <div key={video.id} className="video-card">
            {/* Video Player */}
            <div className="video-player">
              <video
                src={video.videoUrl}
                poster={video.thumbnailUrl}
                controls
                onPlay={() => handleVideoPlay(video.id)}
                className="video-element"
              />
            </div>
            
            {/* Video Info */}
            <div className="video-info">
              {/* Creator */}
              <div className="video-creator">
                <img 
                  src={video.creator.avatarURL || '/default-avatar.png'} 
                  alt={video.creator.displayName}
                  className="creator-avatar"
                />
                <div className="creator-details">
                  <div className="creator-name">{video.creator.displayName}</div>
                  <div className="creator-username">@{video.creator.username}</div>
                </div>
              </div>
              
              {/* Caption */}
              <p className="video-caption">{video.caption}</p>
              
              {/* Stats */}
              <div className="video-stats">
                <button 
                  className={`stat-button like-button ${likedVideos.has(video.id) ? 'liked' : ''}`}
                  onClick={() => handleLike(video.id)}
                  title={likedVideos.has(video.id) ? 'Unlike' : 'Like'}
                >
                  <span className="stat-icon">❤️</span>
                  <span className="stat-count">{formatCount(video.likes)}</span>
                </button>
                
                <div className="stat-item">
                  <span className="stat-icon">👁️</span>
                  <span className="stat-count">{formatCount(video.views)}</span>
                </div>
                
                <div className="stat-item">
                  <span className="stat-icon">💬</span>
                  <span className="stat-count">{formatCount(video.comments)}</span>
                </div>
                
                <div className="stat-item">
                  <span className="stat-icon">🔄</span>
                  <span className="stat-count">{formatCount(video.shares)}</span>
                </div>
              </div>
              
              {/* Timestamp */}
              <div className="video-timestamp">
                {formatDate(video.createdAt)}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
```

---

## Step 5: Create CSS Styles

Create file: `src/components/VideoFeed.css`

```css
/* Video Feed Container */
.video-feed {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

.video-feed-header {
  text-align: center;
  margin-bottom: 30px;
}

.video-feed-header h1 {
  font-size: 2rem;
  margin-bottom: 10px;
}

.video-feed-header p {
  color: #666;
  font-size: 0.9rem;
}

/* Video Grid */
.video-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 20px;
}

/* Video Card */
.video-card {
  background: white;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  transition: transform 0.2s, box-shadow 0.2s;
}

.video-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
}

/* Video Player */
.video-player {
  position: relative;
  width: 100%;
  aspect-ratio: 9/16;
  background: #000;
}

.video-element {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

/* Video Info */
.video-info {
  padding: 15px;
}

/* Creator */
.video-creator {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 12px;
}

.creator-avatar {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  object-fit: cover;
  background: #e0e0e0;
}

.creator-details {
  flex: 1;
}

.creator-name {
  font-weight: 600;
  font-size: 0.95rem;
  color: #333;
}

.creator-username {
  font-size: 0.85rem;
  color: #666;
}

/* Caption */
.video-caption {
  margin: 0 0 12px 0;
  font-size: 0.9rem;
  color: #333;
  line-height: 1.4;
}

/* Stats */
.video-stats {
  display: flex;
  gap: 15px;
  margin-bottom: 10px;
  padding-top: 10px;
  border-top: 1px solid #eee;
}

.stat-button,
.stat-item {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 0.9rem;
  color: #666;
}

.stat-button {
  background: none;
  border: none;
  cursor: pointer;
  padding: 5px 10px;
  border-radius: 6px;
  transition: all 0.2s;
}

.stat-button:hover {
  background: #f5f5f5;
}

.stat-button.liked {
  color: #ff4444;
}

.stat-button.liked .stat-icon {
  animation: heartBeat 0.3s ease;
}

.stat-icon {
  font-size: 1.1rem;
}

.stat-count {
  font-weight: 500;
}

/* Timestamp */
.video-timestamp {
  font-size: 0.8rem;
  color: #999;
}

/* Loading State */
.video-feed-loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 400px;
  gap: 15px;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 4px solid #f3f3f3;
  border-top: 4px solid #3498db;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

@keyframes heartBeat {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.2); }
}

/* Error State */
.video-feed-error {
  text-align: center;
  padding: 40px;
  color: #d32f2f;
}

.video-feed-error button {
  margin-top: 20px;
  padding: 10px 20px;
  background: #3498db;
  color: white;
  border: none;
  border-radius: 6px;
  cursor: pointer;
}

/* Empty State */
.video-feed-empty {
  text-align: center;
  padding: 60px 20px;
  color: #666;
}

/* Responsive */
@media (max-width: 768px) {
  .video-grid {
    grid-template-columns: 1fr;
  }
  
  .video-feed {
    padding: 10px;
  }
}
```

---

## Step 6: Add to Your App

```jsx
// src/App.js
import React from 'react';
import { VideoFeed } from './components/VideoFeed';
import './App.css';

function App() {
  return (
    <div className="App">
      <VideoFeed />
    </div>
  );
}

export default App;
```

---

## Step 7: Test It!

### 1. Start Your Website
```bash
npm start
```

### 2. Upload a Video from Mobile App
- Open your mobile app
- Upload any video
- Make sure it's set to "Published" and "Everyone" privacy

### 3. Watch the Magic ✨
- The video should appear on your website **within 100ms**
- No page refresh needed!
- Creator name and avatar should display correctly

### 4. Test Real-Time Sync
- Like the video from the website
- Open the same video on mobile
- Like count should update on mobile **instantly**

### 5. Test Reverse Sync
- Like a video from mobile
- Watch the website - like count should update **instantly**

---

## 🎯 Expected Results

### ✅ When Working Correctly:

1. **Video Feed Loads**
   - Shows all videos from Firestore
   - Includes videos uploaded from mobile app
   - Displays creator info correctly

2. **Real-Time Updates**
   - New videos from mobile appear automatically (< 100ms)
   - Like counts update without refresh
   - Stats sync between mobile and web

3. **Creator Fields**
   - No "undefined" errors
   - Creator names display correctly
   - Avatars load properly

4. **Interactions Work**
   - Can like videos from website
   - Likes sync to mobile app
   - View counts increment

---

## 🐛 Troubleshooting

### Videos Don't Appear

**Check:**
1. Firebase config is correct (check `firebaseConfig` in config.js)
2. Videos are marked as `status: 'published'`
3. Videos have `privacy: 'Everyone'`
4. Browser console for errors (F12 > Console)

**Fix:**
```javascript
// Check Firestore in browser console
import { collection, getDocs } from 'firebase/firestore';
const snapshot = await getDocs(collection(db, 'videos'));
console.log(`Found ${snapshot.docs.length} videos`);
```

### Creator Info Shows "Unknown User"

**Check:**
1. Did you run the migration script?
2. Do videos have creator fields in Firestore?

**Fix:**
```bash
# Run migration
node scripts/migrate_video_creator_fields.js
```

### Real-Time Updates Don't Work

**Check:**
1. Using `onSnapshot` (not `getDocs`)
2. Not blocking Firestore with browser extensions
3. Network connection active

**Fix:**
```javascript
// Make sure you're using onSnapshot, not getDocs
onSnapshot(query, (snapshot) => {
  // This runs automatically when data changes
});
```

### Permission Denied Errors

**Check Firestore Security Rules:**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /videos/{videoId} {
      allow read: if resource.data.status == 'published';
    }
    match /users/{userId} {
      allow read: if true;
    }
  }
}
```

---

## Step 8: User Avatar & Profile Sync

### Create User Profile Service

Create file: `src/services/userProfileService.js`

```javascript
import { doc, getDoc, onSnapshot, updateDoc } from 'firebase/firestore';
import { db } from '../firebase/config';

/**
 * Watch user profile in real-time
 * When user updates avatar on mobile app, website updates automatically
 */
export function watchUserProfile(userId, callback, onError) {
  try {
    const userRef = doc(db, 'users', userId);
    
    const unsubscribe = onSnapshot(
      userRef,
      (snapshot) => {
        if (snapshot.exists()) {
          const userData = snapshot.data();
          
          const profile = {
            id: snapshot.id,
            displayName: userData.displayName || 'Unknown User',
            username: userData.username || 'unknown',
            avatarURL: userData.avatarURL || null,
            bio: userData.bio || '',
            followerCount: userData.followerCount || 0,
            followingCount: userData.followingCount || 0,
            postCount: userData.postCount || 0,
            totalViews: userData.totalViews || 0,
            totalLikes: userData.totalLikes || 0,
            onlineStatus: userData.onlineStatus || 'offline',
          };
          
          console.log(`✅ User profile updated: ${profile.displayName}`);
          callback(profile);
        } else {
          console.warn(`⚠️ User ${userId} not found`);
          if (onError) onError(new Error('User not found'));
        }
      },
      (error) => {
        console.error(`❌ Error watching user profile ${userId}:`, error);
        if (onError) onError(error);
      }
    );
    
    return unsubscribe;
  } catch (error) {
    console.error('❌ Error setting up user profile watcher:', error);
    if (onError) onError(error);
    return () => {};
  }
}

/**
 * Get current user profile (one-time read)
 */
export async function getUserProfile(userId) {
  try {
    const userDoc = await getDoc(doc(db, 'users', userId));
    
    if (!userDoc.exists()) {
      console.warn(`⚠️ User ${userId} not found`);
      return null;
    }
    
    const userData = userDoc.data();
    return {
      id: userDoc.id,
      displayName: userData.displayName || 'Unknown User',
      username: userData.username || 'unknown',
      avatarURL: userData.avatarURL || null,
      bio: userData.bio || '',
      followerCount: userData.followerCount || 0,
      followingCount: userData.followingCount || 0,
      postCount: userData.postCount || 0,
    };
  } catch (error) {
    console.error(`❌ Error fetching user profile ${userId}:`, error);
    return null;
  }
}

/**
 * Get current authenticated user's profile
 */
export async function getCurrentUserProfile(currentUser) {
  if (!currentUser) return null;
  return getUserProfile(currentUser.uid);
}
```

### Create User Avatar Component

Create file: `src/components/UserAvatar.jsx`

```jsx
import React, { useState, useEffect } from 'react';
import { watchUserProfile } from '../services/userProfileService';
import './UserAvatar.css';

/**
 * User Avatar Component - Syncs in real-time with mobile app
 * When user updates avatar on mobile, website updates automatically
 */
export function UserAvatar({ userId, size = 40, showOnlineStatus = false }) {
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  
  useEffect(() => {
    if (!userId) {
      setLoading(false);
      setError(true);
      return;
    }
    
    console.log(`👤 Watching profile for user ${userId}`);
    
    // Real-time listener - updates when mobile app changes avatar
    const unsubscribe = watchUserProfile(
      userId,
      (userProfile) => {
        console.log(`✅ Avatar updated for ${userProfile.displayName}`);
        setProfile(userProfile);
        setLoading(false);
        setError(false);
      },
      (err) => {
        console.error('Error loading profile:', err);
        setError(true);
        setLoading(false);
      }
    );
    
    return () => unsubscribe();
  }, [userId]);
  
  if (loading) {
    return (
      <div 
        className="user-avatar loading" 
        style={{ width: size, height: size }}
      >
        <div className="avatar-skeleton"></div>
      </div>
    );
  }
  
  if (error || !profile) {
    return (
      <div 
        className="user-avatar error" 
        style={{ width: size, height: size }}
      >
        <span className="avatar-placeholder">?</span>
      </div>
    );
  }
  
  return (
    <div className="user-avatar-container">
      <div 
        className="user-avatar" 
        style={{ width: size, height: size }}
      >
        {profile.avatarURL ? (
          <img 
            src={profile.avatarURL} 
            alt={profile.displayName}
            className="avatar-image"
            onError={(e) => {
              e.target.style.display = 'none';
              e.target.nextSibling.style.display = 'flex';
            }}
          />
        ) : null}
        
        <div 
          className="avatar-fallback"
          style={{ display: profile.avatarURL ? 'none' : 'flex' }}
        >
          {profile.displayName.charAt(0).toUpperCase()}
        </div>
        
        {showOnlineStatus && (
          <div className={`online-indicator ${profile.onlineStatus}`}></div>
        )}
      </div>
    </div>
  );
}

/**
 * User Profile Card - Shows avatar + info, updates in real-time
 */
export function UserProfileCard({ userId, showStats = true }) {
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    if (!userId) return;
    
    // Real-time listener
    const unsubscribe = watchUserProfile(userId, (userProfile) => {
      setProfile(userProfile);
      setLoading(false);
    });
    
    return () => unsubscribe();
  }, [userId]);
  
  if (loading) {
    return <div className="profile-card-loading">Loading...</div>;
  }
  
  if (!profile) {
    return <div className="profile-card-error">User not found</div>;
  }
  
  return (
    <div className="user-profile-card">
      <UserAvatar userId={userId} size={60} showOnlineStatus={true} />
      
      <div className="profile-info">
        <h3 className="profile-name">{profile.displayName}</h3>
        <p className="profile-username">@{profile.username}</p>
        {profile.bio && <p className="profile-bio">{profile.bio}</p>}
        
        {showStats && (
          <div className="profile-stats">
            <div className="stat">
              <span className="stat-value">{profile.postCount}</span>
              <span className="stat-label">Posts</span>
            </div>
            <div className="stat">
              <span className="stat-value">{profile.followerCount}</span>
              <span className="stat-label">Followers</span>
            </div>
            <div className="stat">
              <span className="stat-value">{profile.followingCount}</span>
              <span className="stat-label">Following</span>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
```

### Create Avatar CSS

Create file: `src/components/UserAvatar.css`

```css
/* User Avatar */
.user-avatar-container {
  position: relative;
  display: inline-block;
}

.user-avatar {
  position: relative;
  border-radius: 50%;
  overflow: hidden;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  flex-shrink: 0;
}

.avatar-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.avatar-fallback {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-weight: 600;
  font-size: 0.6em;
}

.avatar-skeleton {
  width: 100%;
  height: 100%;
  background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
}

@keyframes shimmer {
  0% { background-position: -200% 0; }
  100% { background-position: 200% 0; }
}

.user-avatar.error {
  background: #ccc;
}

.avatar-placeholder {
  color: white;
  font-size: 0.6em;
  font-weight: 600;
}

/* Online Status Indicator */
.online-indicator {
  position: absolute;
  bottom: 2px;
  right: 2px;
  width: 25%;
  height: 25%;
  border-radius: 50%;
  border: 2px solid white;
  background: #ccc;
}

.online-indicator.online {
  background: #44b700;
  box-shadow: 0 0 8px rgba(68, 183, 0, 0.6);
}

.online-indicator.away {
  background: #ffa000;
}

.online-indicator.offline {
  background: #999;
}

/* User Profile Card */
.user-profile-card {
  display: flex;
  gap: 15px;
  align-items: center;
  padding: 15px;
  background: white;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.profile-info {
  flex: 1;
}

.profile-name {
  margin: 0 0 4px 0;
  font-size: 1.1rem;
  font-weight: 600;
  color: #333;
}

.profile-username {
  margin: 0 0 8px 0;
  font-size: 0.9rem;
  color: #666;
}

.profile-bio {
  margin: 0 0 12px 0;
  font-size: 0.85rem;
  color: #555;
  line-height: 1.4;
}

.profile-stats {
  display: flex;
  gap: 20px;
}

.stat {
  display: flex;
  flex-direction: column;
  align-items: center;
}

.stat-value {
  font-size: 1rem;
  font-weight: 600;
  color: #333;
}

.stat-label {
  font-size: 0.75rem;
  color: #666;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.profile-card-loading,
.profile-card-error {
  padding: 20px;
  text-align: center;
  color: #666;
}
```

### Update VideoFeed Component to Use UserAvatar

Update `src/components/VideoFeed.jsx`:

```jsx
// At the top, add import
import { UserAvatar } from './UserAvatar';

// Replace the creator avatar section in the video card:
// OLD CODE:
/*
<div className="video-creator">
  <img 
    src={video.creator.avatarURL || '/default-avatar.png'} 
    alt={video.creator.displayName}
    className="creator-avatar"
  />
  ...
</div>
*/

// NEW CODE:
<div className="video-creator">
  <UserAvatar 
    userId={video.creator.id} 
    size={40} 
    showOnlineStatus={true} 
  />
  <div className="creator-details">
    <div className="creator-name">{video.creator.displayName}</div>
    <div className="creator-username">@{video.creator.username}</div>
  </div>
</div>
```

---

## 🎨 Avatar Sync Behavior

### How It Works:

1. **User updates avatar on mobile app** 📱
   ```
   Mobile App → Updates Firestore user.avatarURL
   ```

2. **Cloud Function triggers** ☁️
   ```
   syncCreatorProfileToVideos() function
   → Updates all user's videos with new avatar
   ```

3. **Website real-time listener detects change** 🌐
   ```
   onSnapshot() on user profile
   → Website re-renders with new avatar
   → Updates in < 100ms
   ```

4. **Avatar updates everywhere on website** ✨
   - Video cards
   - Profile pages
   - Comment sections
   - Navigation bar
   - Anywhere avatar is shown

### Example Flow:

```
Mobile App                 Firestore                Website
    |                         |                        |
    | Update avatar           |                        |
    |------------------------>|                        |
    |                         |                        |
    |            Cloud Function triggers               |
    |            Updates all videos                    |
    |                         |                        |
    |                         | Real-time listener     |
    |                         | detects change         |
    |                         |----------------------->|
    |                         |                        |
    |                         |        Avatar updates  |
    |                         |        everywhere! ✨  |
```

---

## ✅ Avatar Sync Testing Checklist

After implementing avatar sync:

### Test 1: Profile Avatar Update
1. [ ] Open your profile on **mobile app**
2. [ ] Change your profile picture
3. [ ] Wait 2-3 seconds
4. [ ] **Check website** - your avatar should update everywhere
5. [ ] **No page refresh needed**

**Expected:** Avatar updates in < 100ms on website

### Test 2: Video Creator Avatars
1. [ ] Upload a video from **mobile app**
2. [ ] Video appears on **website** with your avatar
3. [ ] Change avatar on **mobile app**
4. [ ] **Check website** - avatar on video card should update
5. [ ] All your videos should show new avatar

**Expected:** All videos show updated avatar automatically

### Test 3: Real-Time Avatar Display
1. [ ] Open profile page on **website**
2. [ ] Open mobile app profile
3. [ ] Change avatar on **mobile**
4. [ ] **Watch website** - should update without refresh

**Expected:** Avatar changes instantly on website

### Test 4: Multiple Locations
After changing avatar, verify it updates in ALL these places:
- [ ] Video cards (creator avatar)
- [ ] Profile page
- [ ] Comment sections
- [ ] Navigation/header
- [ ] Anywhere else avatar appears

**Expected:** Avatar updates everywhere consistently

---

## 📊 Verification Checklist

After implementation, verify:

- [ ] Website displays videos uploaded from mobile app
- [ ] Creator names and avatars display correctly
- [ ] **Avatars sync in real-time when changed on mobile app** ⭐
- [ ] **Avatar updates everywhere on website automatically** ⭐
- [ ] View counts increment when playing videos
- [ ] Can like videos from website
- [ ] Likes sync to mobile app in real-time
- [ ] New mobile uploads appear on website automatically
- [ ] No console errors
- [ ] No "undefined" creator errors
- [ ] **No broken avatar images** ⭐
- [ ] **Fallback avatars show when no image uploaded** ⭐

---

## 🎉 Success!

If you can:
1. ✅ See mobile app videos on website with creator names and avatars
2. ✅ Change avatar on mobile → See it update everywhere on website instantly
3. ✅ Upload from mobile → Video appears on website instantly
4. ✅ Like from website → Mobile app sees the update
5. ✅ Like from mobile → Website sees the update
6. ✅ All avatars display correctly (no broken images)
7. ✅ Fallback avatars show when user has no profile picture
8. ✅ No console errors
9. ✅ No "undefined" or "unknown user" errors

**Then congratulations! Your mobile app and website are fully synchronized with real-time avatar sync!** 🚀

### Example Test Flow:

```
1. Mobile App: Upload a video with your avatar
   ✅ Website: Video appears with your avatar within 100ms

2. Mobile App: Change your profile picture
   ✅ Website: Avatar updates everywhere (video cards, profile, etc.)
   ✅ No page refresh needed

3. Website: Like the video
   ✅ Mobile App: Like count updates instantly

4. Mobile App: Unlike the video
   ✅ Website: Like count updates instantly

All working? You're done! 🎊
```

---

## 📞 Next Steps

1. **Test with real users**
   - Have someone upload from mobile
   - Verify it appears on website
   - Test concurrent likes

2. **Add more features**
   - Comments section
   - Share functionality
   - User profiles
   - Search/filtering

3. **Monitor performance**
   - Check Firebase usage
   - Monitor real-time listener costs
   - Optimize if needed

---

## 💡 Instructions for Cursor.ai

When implementing this, tell cursor.ai:

```
"Please implement a video feed on my website that displays videos from my mobile app with real-time avatar synchronization.

The videos are stored in Firestore in the 'videos' collection.
Creator info is in the 'users' collection.

Videos have these field name variants for creator ID:
- userId
- creatorId  
- creator_id

Please use the code from WEBSITE_VIDEO_FEED_IMPLEMENTATION.md and implement:

1. Video Feed Service (Step 3)
   - Real-time sync using onSnapshot
   - Support for all creator field variants
   - Atomic operations for likes

2. Video Feed Component (Step 4)
   - Display all videos with stats
   - Interactive like buttons
   - Real-time updates

3. User Profile Service (Step 8)
   - Watch user profiles in real-time
   - Detect avatar changes from mobile app
   
4. User Avatar Component (Step 8)
   - Real-time avatar sync
   - Fallback avatars when no image
   - Online status indicators
   - Update VideoFeed to use UserAvatar component

Key Requirements:
✅ When I upload a video from mobile app → appears on website instantly
✅ When I change my avatar on mobile app → updates on website everywhere
✅ When I like a video on website → mobile app sees it
✅ All avatars sync in real-time (< 100ms)
✅ No page refresh needed for any updates

Test by:
1. Uploading a video from mobile app → verify it appears on website
2. Changing avatar on mobile app → verify it updates everywhere on website
3. Liking from website → verify mobile app sees the update"
```

---

**Implementation Time:** ~30-60 minutes  
**Difficulty:** Medium  
**Dependencies:** Firebase SDK  
**Result:** Full mobile ↔ website sync ✨

