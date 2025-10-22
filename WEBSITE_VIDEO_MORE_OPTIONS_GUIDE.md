# Website Video More Options - Implementation Guide

## 🎯 Overview

Implement TikTok-style "More Options" (⋯) menu for ProfileView video feeds on the website, with context-aware actions based on ownership and user role.

---

## ✅ What's Already Done (Backend)

### 1. Firebase Security Rules - ✅ DEPLOYED
All security rules are already deployed and working:
- Video updates (owner can change privacy, pins, captions)
- User favorites management
- Reports collection
- Pin limit enforcement (max 3)

### 2. Firestore Collections - ✅ READY
Collections are set up and secured:
- `/videos/{videoId}` - Now has: `allowSave`, `allowRemix`, `visibility`, `status`, `isPinned`, `tags`
- `/users/{userId}` - Now has: `pinnedVideoIds` (max 3), `role`
- `/user_favorites/{userId}/videos/{videoId}` - For favorites
- `/reports/{reportId}` - For content reports

---

## 🔧 What the Website Needs to Build

### 1. UI Component: More Options Button

Add a More Options button (⋯) to the video player HUD (right side action rail).

**Location**: ProfileView video player → right side action buttons

**Example (React/Next.js)**:
```jsx
// VideoPlayer.jsx or similar
import { useState } from 'react';
import { MoreHoriz } from '@mui/icons-material'; // or your icon library

function VideoPlayerHUD({ video, currentUser }) {
  const [showOptions, setShowOptions] = useState(false);

  return (
    <div className="video-hud">
      {/* Existing buttons: like, comment, bookmark, share */}
      
      {/* More Options Button - NEW */}
      <button 
        className="action-button"
        onClick={() => setShowOptions(true)}
        aria-label="More options"
      >
        <MoreHoriz />
      </button>

      {/* Bottom Sheet Modal */}
      {showOptions && (
        <VideoOptionsSheet 
          video={video}
          currentUser={currentUser}
          onClose={() => setShowOptions(false)}
          onVideoDeleted={() => handleVideoDeleted()}
          onVideoUpdated={() => handleVideoUpdated()}
        />
      )}
    </div>
  );
}
```

---

### 2. Bottom Sheet Component: VideoOptionsSheet

**Context-Aware Menu** that shows different options based on:
- **Ownership**: Is current user the video owner?
- **Role**: Is user a `creator`, `moderator`, or regular `user`?
- **Video Settings**: `allowSave`, `allowRemix`, `visibility`, `status`

**Example**:
```jsx
// VideoOptionsSheet.jsx
import { useState } from 'react';
import { 
  Download, Lock, Edit, PushPin, Analytics, 
  Link, Share, Delete, Campaign, Favorite, 
  Flag, NotInterested, MovieCreation 
} from '@mui/icons-material';

function VideoOptionsSheet({ video, currentUser, onClose, onVideoDeleted, onVideoUpdated }) {
  const [isProcessing, setIsProcessing] = useState(false);
  
  const isOwner = currentUser.id === video.creator.id;
  const menuItems = buildMenuItems(video, currentUser, isOwner);

  return (
    <div className="bottom-sheet">
      <div className="sheet-handle" />
      
      <div className="menu-items">
        {menuItems.map(item => (
          <button
            key={item.id}
            className={`menu-item ${item.destructive ? 'destructive' : ''}`}
            onClick={() => handleAction(item.action)}
            disabled={isProcessing}
          >
            <item.icon />
            <span>{item.label}</span>
          </button>
        ))}
      </div>
    </div>
  );
}

function buildMenuItems(video, currentUser, isOwner) {
  const items = [];
  
  if (isOwner) {
    // OWNER MENU
    items.push(
      { id: 'save', label: 'Save video', icon: Download, action: 'save' },
      { id: 'privacy', label: 'Privacy', icon: Lock, action: 'privacy' },
      { id: 'edit', label: 'Edit caption & tags', icon: Edit, action: 'editCaption' },
      { id: 'pin', label: video.isPinned ? 'Unpin from profile' : 'Pin to profile', icon: PushPin, action: 'togglePin' },
      { id: 'analytics', label: 'Analytics', icon: Analytics, action: 'analytics' },
      { id: 'copy', label: 'Copy link', icon: Link, action: 'copyLink' },
      { id: 'share', label: 'Share', icon: Share, action: 'share' },
      { id: 'delete', label: 'Delete', icon: Delete, action: 'delete', destructive: true }
    );
    
    if (currentUser.role === 'creator') {
      items.push({ id: 'promote', label: 'Promote', icon: Campaign, action: 'promote' });
    }
  } else {
    // VIEWER MENU
    if (video.allowSave) {
      items.push({ id: 'save', label: 'Save video', icon: Download, action: 'save' });
    }
    
    items.push(
      { 
        id: 'favorite', 
        label: video.isFavorited ? 'Remove from Favorites' : 'Add to Favorites', 
        icon: Favorite, 
        action: 'toggleFavorite' 
      },
      { id: 'notInterested', label: 'Not interested', icon: NotInterested, action: 'notInterested' },
      { id: 'report', label: 'Report', icon: Flag, action: 'report' },
      { id: 'copy', label: 'Copy link', icon: Link, action: 'copyLink' },
      { id: 'share', label: 'Share', icon: Share, action: 'share' }
    );
    
    if (video.allowRemix) {
      items.push({ id: 'remix', label: 'Remix / Stitch', icon: MovieCreation, action: 'remix' });
    }
  }
  
  if (currentUser.role === 'moderator') {
    items.push({ id: 'moderator', label: 'Moderator tools', icon: AdminPanelSettings, action: 'moderator' });
  }
  
  return items;
}
```

---

### 3. Action Handlers: Firebase Operations

**File**: `videoActions.js` or similar

```javascript
import { db } from './firebase';
import { 
  doc, 
  updateDoc, 
  deleteDoc, 
  setDoc, 
  getDoc, 
  increment 
} from 'firebase/firestore';

// 1. Change Privacy
export async function setVideoPrivacy(videoId, visibility) {
  const videoRef = doc(db, 'videos', videoId);
  await updateDoc(videoRef, {
    visibility: visibility, // 'public', 'followers', or 'private'
    updatedAt: new Date()
  });
}

// 2. Update Caption
export async function updateVideoCaption(videoId, caption) {
  const videoRef = doc(db, 'videos', videoId);
  await updateDoc(videoRef, {
    caption: caption,
    updatedAt: new Date()
  });
}

// 3. Pin Video
export async function pinVideo(videoId, userId) {
  const userRef = doc(db, 'users', userId);
  const videoRef = doc(db, 'videos', videoId);
  
  // Get current pins
  const userDoc = await getDoc(userRef);
  const pinnedVideoIds = userDoc.data()?.pinnedVideoIds || [];
  
  // Check limit
  if (pinnedVideoIds.length >= 3) {
    throw new Error('Maximum 3 videos can be pinned. Unpin one first.');
  }
  
  // Check if already pinned
  if (pinnedVideoIds.includes(videoId)) {
    return; // Already pinned
  }
  
  // Add to pins
  pinnedVideoIds.push(videoId);
  
  // Update both documents
  await Promise.all([
    updateDoc(userRef, { pinnedVideoIds }),
    updateDoc(videoRef, { isPinned: true, updatedAt: new Date() })
  ]);
}

// 4. Unpin Video
export async function unpinVideo(videoId, userId) {
  const userRef = doc(db, 'users', userId);
  const videoRef = doc(db, 'videos', videoId);
  
  // Get current pins
  const userDoc = await getDoc(userRef);
  const pinnedVideoIds = userDoc.data()?.pinnedVideoIds || [];
  
  // Remove from pins
  const updatedPins = pinnedVideoIds.filter(id => id !== videoId);
  
  // Update both documents
  await Promise.all([
    updateDoc(userRef, { pinnedVideoIds: updatedPins }),
    updateDoc(videoRef, { isPinned: false, updatedAt: new Date() })
  ]);
}

// 5. Delete Video (Soft Delete)
export async function deleteVideo(videoId, userId) {
  const videoRef = doc(db, 'videos', videoId);
  const userRef = doc(db, 'users', userId);
  
  // Soft delete
  await updateDoc(videoRef, {
    status: 'deleted',
    deletedAt: new Date()
  });
  
  // Decrement post count
  await updateDoc(userRef, {
    postCount: increment(-1)
  });
  
  // Remove from user_videos collection
  const userVideoRef = doc(db, 'user_videos', userId, 'posts', videoId);
  await deleteDoc(userVideoRef);
  
  // Remove from pins if pinned
  const userDoc = await getDoc(userRef);
  const pinnedVideoIds = userDoc.data()?.pinnedVideoIds || [];
  if (pinnedVideoIds.includes(videoId)) {
    const updatedPins = pinnedVideoIds.filter(id => id !== videoId);
    await updateDoc(userRef, { pinnedVideoIds: updatedPins });
  }
}

// 6. Add to Favorites
export async function addToFavorites(videoId, userId) {
  const favoriteRef = doc(db, 'user_favorites', userId, 'videos', videoId);
  await setDoc(favoriteRef, {
    videoId: videoId,
    createdAt: new Date()
  });
  
  // Update video
  const videoRef = doc(db, 'videos', videoId);
  await updateDoc(videoRef, {
    isFavorited: true
  });
}

// 7. Remove from Favorites
export async function removeFromFavorites(videoId, userId) {
  const favoriteRef = doc(db, 'user_favorites', userId, 'videos', videoId);
  await deleteDoc(favoriteRef);
  
  // Update video
  const videoRef = doc(db, 'videos', videoId);
  await updateDoc(videoRef, {
    isFavorited: false
  });
}

// 8. Report Video
export async function reportVideo(videoId, userId, reason) {
  const reportRef = doc(db, 'reports', `${videoId}_${userId}_${Date.now()}`);
  await setDoc(reportRef, {
    videoId: videoId,
    reporterId: userId,
    reason: reason,
    createdAt: new Date(),
    status: 'pending'
  });
}

// 9. Copy Link
export function copyVideoLink(videoId) {
  const link = `https://streamerstip.com/video/${videoId}`;
  navigator.clipboard.writeText(link);
}

// 10. Share Video
export async function shareVideo(videoId) {
  const link = `https://streamerstip.com/video/${videoId}`;
  
  if (navigator.share) {
    // Use native share if available
    await navigator.share({
      title: 'Check out this video on StreamersTip',
      url: link
    });
  } else {
    // Fallback: copy to clipboard
    copyVideoLink(videoId);
    alert('Link copied to clipboard!');
  }
}
```

---

### 4. Confirmation Dialogs

**Privacy Dialog**:
```jsx
// PrivacyDialog.jsx
import { useState } from 'react';

function PrivacyDialog({ currentPrivacy, onSave, onCancel }) {
  const [selected, setSelected] = useState(currentPrivacy);

  return (
    <div className="dialog">
      <h3>Privacy</h3>
      
      <label>
        <input 
          type="radio" 
          value="public" 
          checked={selected === 'public'}
          onChange={(e) => setSelected(e.target.value)}
        />
        <div>
          <strong>Public</strong>
          <p>Anyone can see this video</p>
        </div>
      </label>

      <label>
        <input 
          type="radio" 
          value="followers" 
          checked={selected === 'followers'}
          onChange={(e) => setSelected(e.target.value)}
        />
        <div>
          <strong>Followers</strong>
          <p>Only your followers can see this video</p>
        </div>
      </label>

      <label>
        <input 
          type="radio" 
          value="private" 
          checked={selected === 'private'}
          onChange={(e) => setSelected(e.target.value)}
        />
        <div>
          <strong>Private</strong>
          <p>Only you can see this video</p>
        </div>
      </label>

      <div className="dialog-actions">
        <button onClick={onCancel}>Cancel</button>
        <button onClick={() => onSave(selected)}>Save</button>
      </div>
    </div>
  );
}
```

**Delete Confirmation**:
```jsx
// DeleteConfirmDialog.jsx
function DeleteConfirmDialog({ onConfirm, onCancel }) {
  return (
    <div className="dialog">
      <h3>Delete Video</h3>
      <p>Are you sure you want to delete this video? This action cannot be undone.</p>
      
      <div className="dialog-actions">
        <button onClick={onCancel}>Cancel</button>
        <button className="destructive" onClick={onConfirm}>Delete</button>
      </div>
    </div>
  );
}
```

**Report Dialog**:
```jsx
// ReportDialog.jsx
import { useState } from 'react';

function ReportDialog({ onSubmit, onCancel }) {
  const [reason, setReason] = useState('');

  const reasons = [
    'Spam or misleading',
    'Hate speech or harassment',
    'Violence or harmful content',
    'Adult content',
    'Copyright infringement',
    'Other'
  ];

  return (
    <div className="dialog">
      <h3>Report Video</h3>
      
      {reasons.map(r => (
        <label key={r}>
          <input 
            type="radio" 
            value={r} 
            checked={reason === r}
            onChange={(e) => setReason(e.target.value)}
          />
          {r}
        </label>
      ))}

      <div className="dialog-actions">
        <button onClick={onCancel}>Cancel</button>
        <button 
          onClick={() => onSubmit(reason)}
          disabled={!reason}
        >
          Submit
        </button>
      </div>
    </div>
  );
}
```

---

## 🎨 UI/UX Guidelines

### Bottom Sheet Styling
```css
/* VideoOptionsSheet.css */
.bottom-sheet {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: white;
  border-radius: 20px 20px 0 0;
  padding: 20px;
  max-height: 70vh;
  overflow-y: auto;
  z-index: 1000;
  animation: slideUp 0.3s ease-out;
}

.sheet-handle {
  width: 40px;
  height: 4px;
  background: #ccc;
  border-radius: 2px;
  margin: 0 auto 16px;
}

.menu-items {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.menu-item {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 16px;
  border: none;
  background: transparent;
  cursor: pointer;
  transition: background 0.2s;
}

.menu-item:hover {
  background: #f5f5f5;
}

.menu-item.destructive {
  color: #f44336;
}

.menu-item:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

@keyframes slideUp {
  from {
    transform: translateY(100%);
  }
  to {
    transform: translateY(0);
  }
}
```

### Action Button Styling
```css
/* VideoPlayerHUD.css */
.action-button {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  background: transparent;
  border: none;
  color: white;
  cursor: pointer;
  padding: 8px;
  transition: transform 0.2s;
}

.action-button:hover {
  transform: scale(1.1);
}

.action-button svg {
  font-size: 32px;
  filter: drop-shadow(0 2px 4px rgba(0,0,0,0.3));
}
```

---

## 📊 Optimistic UI Updates

For better UX, update the UI immediately and rollback on failure:

```javascript
// Example: Toggle Pin
async function handleTogglePin(video, userId) {
  // 1. Optimistic update
  const previousState = video.isPinned;
  video.isPinned = !video.isPinned;
  updateUI(video); // Update local state/display
  
  try {
    // 2. Server update
    if (video.isPinned) {
      await pinVideo(video.id, userId);
    } else {
      await unpinVideo(video.id, userId);
    }
    
    // 3. Show success
    showToast(video.isPinned ? 'Video pinned' : 'Video unpinned');
  } catch (error) {
    // 4. Rollback on failure
    video.isPinned = previousState;
    updateUI(video);
    showToast(`Failed: ${error.message}`, 'error');
  }
}
```

---

## 🔒 Security Notes

### All security is handled server-side via Firestore rules:
- ✅ Only owners can change privacy, pins, captions
- ✅ Only owners can delete videos
- ✅ Pin limit (max 3) enforced at database level
- ✅ Favorites restricted to authenticated users
- ✅ Reports are immutable after creation

**You don't need to validate these on the website** - Firebase will reject invalid operations.

---

## 🧪 Testing Checklist

Test these scenarios:

### Owner (Your Videos):
- [ ] More Options button appears
- [ ] Can change privacy (Public/Followers/Private)
- [ ] Can edit caption
- [ ] Can pin video (enforces max 3)
- [ ] Can unpin video
- [ ] Can copy link
- [ ] Can share
- [ ] Can delete (shows confirmation)
- [ ] Deleted video removes from grid
- [ ] Creator role shows "Promote" option

### Viewer (Others' Videos):
- [ ] More Options button appears
- [ ] Can add to favorites
- [ ] Can remove from favorites
- [ ] Can report (submits to Firebase)
- [ ] Can copy link
- [ ] Can share
- [ ] "Save video" only shows if allowed
- [ ] "Not interested" shows toast

### Edge Cases:
- [ ] Pin limit error message (max 3)
- [ ] Delete last video navigates back
- [ ] Offline actions show error
- [ ] Permission denied shows error

---

## 📝 Implementation Checklist

1. **UI Components**:
   - [ ] Add More Options button to video player HUD
   - [ ] Create VideoOptionsSheet component
   - [ ] Create PrivacyDialog component
   - [ ] Create DeleteConfirmDialog component
   - [ ] Create ReportDialog component

2. **Action Handlers**:
   - [ ] Implement `setVideoPrivacy()`
   - [ ] Implement `updateVideoCaption()`
   - [ ] Implement `pinVideo()` / `unpinVideo()`
   - [ ] Implement `deleteVideo()`
   - [ ] Implement `addToFavorites()` / `removeFromFavorites()`
   - [ ] Implement `reportVideo()`
   - [ ] Implement `copyVideoLink()`
   - [ ] Implement `shareVideo()`

3. **State Management**:
   - [ ] Handle video updates locally
   - [ ] Handle video deletion (remove from grid)
   - [ ] Optimistic UI for pin/favorites
   - [ ] Error handling with rollback

4. **Styling**:
   - [ ] Bottom sheet animation
   - [ ] Menu item hover states
   - [ ] Destructive action styling (red for delete)
   - [ ] Loading states (spinner/disabled)

---

## 🚀 Quick Start Example

Minimal working example:

```jsx
// pages/profile/[userId].jsx
import { useState } from 'react';
import { useAuth } from '@/hooks/useAuth';
import VideoOptionsSheet from '@/components/VideoOptionsSheet';
import * as videoActions from '@/lib/videoActions';

export default function ProfilePage() {
  const { currentUser } = useAuth();
  const [videos, setVideos] = useState([...]);
  const [selectedVideo, setSelectedVideo] = useState(null);

  const handleVideoDeleted = (videoId) => {
    setVideos(videos.filter(v => v.id !== videoId));
    setSelectedVideo(null);
  };

  const handleVideoUpdated = () => {
    // Refresh video data
    fetchVideos();
  };

  return (
    <div className="profile-page">
      <VideoGrid 
        videos={videos}
        onVideoClick={(video) => setSelectedVideo(video)}
      />

      {selectedVideo && (
        <VideoOptionsSheet
          video={selectedVideo}
          currentUser={currentUser}
          onClose={() => setSelectedVideo(null)}
          onVideoDeleted={handleVideoDeleted}
          onVideoUpdated={handleVideoUpdated}
          actions={videoActions}
        />
      )}
    </div>
  );
}
```

---

## 💡 Key Differences from Mobile App

| Feature | Mobile App | Website |
|---------|-----------|---------|
| **UI** | Native Flutter widgets | React/Next.js components |
| **State** | Riverpod providers | React state/context |
| **Firebase** | FlutterFire | Firebase JS SDK |
| **Dialogs** | Material dialogs | Custom modal components |
| **Share** | System share sheet | Web Share API or clipboard |
| **Backend** | ✅ Same (Firebase) | ✅ Same (Firebase) |
| **Security** | ✅ Same (Firestore rules) | ✅ Same (Firestore rules) |

---

## 📚 Related Documentation

- See `VIDEO_MORE_OPTIONS_IMPLEMENTATION.md` for full architecture details
- See `WEBSITE_MESSAGE_NOTIFICATIONS_GUIDE.md` for similar website integration example
- Firebase docs: https://firebase.google.com/docs/firestore

---

## ✅ Summary

**What you need to build**:
1. More Options button (⋯) on video player
2. Bottom sheet menu component
3. Confirmation dialogs (Privacy, Delete, Report)
4. Action handlers using Firebase SDK
5. Optimistic UI updates

**What's already done**:
- ✅ Backend (Firebase rules & collections)
- ✅ Security enforcement
- ✅ Data model updates

**Estimated Time**: 4-6 hours for a skilled web developer

Good luck! 🚀

