# Activity View – Web Implementation Guide

## 📋 Overview

Complete web implementation for Activity View that mirrors the Flutter mobile app functionality. Real-time notifications, unread counts, and seamless navigation to related content.

---

## 📁 File Structure

```
your-website/
├── src/
│   ├── hooks/
│   │   └── useActivityNotifications.js      # Real-time notification hook
│   ├── components/
│   │   ├── ActivityView.jsx                 # Main activity page
│   │   ├── ActivityView.css                 # Activity page styles
│   │   ├── ActivityRow.jsx                  # Individual notification row
│   │   └── ActivityRow.css                  # Notification row styles
│   ├── services/
│   │   └── activityService.js               # Mark as read operations
│   └── firebase/
│       └── config.js                         # Firebase configuration
```

---

## 🔧 Step 1: Firebase Configuration

Ensure your Firebase config is set up:

```javascript
// src/firebase/config.js
import { initializeApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';
import { getAuth } from 'firebase/auth';

const firebaseConfig = {
  apiKey: "your-api-key",
  authDomain: "streamerstip-6cfdb.firebaseapp.com",
  projectId: "streamerstip-6cfdb",
  storageBucket: "streamerstip-6cfdb.appspot.com",
  messagingSenderId: "your-sender-id",
  appId: "your-app-id"
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const auth = getAuth(app);
```

---

## 🔧 Step 2: Activity Service

Create `src/services/activityService.js`:

```javascript
import { 
  collection, 
  query, 
  orderBy, 
  limit, 
  updateDoc, 
  doc, 
  writeBatch,
  getDocs,
  where
} from 'firebase/firestore';
import { db } from '../firebase/config';

/**
 * Mark a single notification as read
 */
export const markNotificationAsRead = async (userId, notificationId) => {
  try {
    const notificationRef = doc(
      db, 
      'activity', 
      userId, 
      'notifications', 
      notificationId
    );
    await updateDoc(notificationRef, { isRead: true });
    return { success: true };
  } catch (error) {
    console.error('Error marking notification as read:', error);
    return { success: false, error: error.message };
  }
};

/**
 * Mark all currently loaded notifications as read
 */
export const markAllNotificationsAsRead = async (userId, notificationIds) => {
  try {
    if (!notificationIds || notificationIds.length === 0) {
      return { success: true, count: 0 };
    }

    const batch = writeBatch(db);
    let count = 0;

    for (const notificationId of notificationIds) {
      const notificationRef = doc(
        db,
        'activity',
        userId,
        'notifications',
        notificationId
      );
      batch.update(notificationRef, { isRead: true });
      count++;
    }

    await batch.commit();
    return { success: true, count };
  } catch (error) {
    console.error('Error marking all notifications as read:', error);
    return { success: false, error: error.message };
  }
};

/**
 * Mark all unread notifications as read (server-side approach)
 * Fetches all unread notifications and marks them
 */
export const markAllUnreadAsRead = async (userId) => {
  try {
    const notificationsRef = collection(
      db,
      'activity',
      userId,
      'notifications'
    );
    
    const unreadQuery = query(
      notificationsRef,
      where('isRead', '==', false),
      limit(100) // Limit to prevent excessive writes
    );

    const snapshot = await getDocs(unreadQuery);
    if (snapshot.empty) {
      return { success: true, count: 0 };
    }

    const batch = writeBatch(db);
    let count = 0;

    snapshot.docs.forEach((docSnapshot) => {
      batch.update(docSnapshot.ref, { isRead: true });
      count++;
    });

    await batch.commit();
    return { success: true, count };
  } catch (error) {
    console.error('Error marking all unread as read:', error);
    return { success: false, error: error.message };
  }
};
```

---

## 🔧 Step 3: Activity Notifications Hook

Create `src/hooks/useActivityNotifications.js`:

```javascript
import { useState, useEffect } from 'react';
import {
  collection,
  query,
  orderBy,
  limit,
  onSnapshot,
  Timestamp
} from 'firebase/firestore';
import { db } from '../firebase/config';
import { useAuth } from './useAuth'; // Your auth hook

/**
 * Hook for real-time activity notifications
 * Mirrors mobile app behavior with real-time updates
 */
export const useActivityNotifications = (maxNotifications = 50) => {
  const { currentUser } = useAuth();
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!currentUser?.uid) {
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    const notificationsRef = collection(
      db,
      'activity',
      currentUser.uid,
      'notifications'
    );

    const notificationsQuery = query(
      notificationsRef,
      orderBy('createdAt', 'desc'),
      limit(maxNotifications)
    );

    const unsubscribe = onSnapshot(
      notificationsQuery,
      (snapshot) => {
        try {
          const notificationList = [];
          
          snapshot.forEach((doc) => {
            const data = doc.data();
            
            // Handle createdAt - ensure it's a valid date
            let createdAt = data.createdAt;
            if (!createdAt) {
              createdAt = Timestamp.now();
            } else if (createdAt.toDate) {
              createdAt = createdAt.toDate();
            } else if (createdAt instanceof Date) {
              // Already a Date
            } else {
              createdAt = new Date(createdAt);
            }

            notificationList.push({
              id: doc.id,
              type: data.type || 'like',
              actorId: data.actorId || '',
              actorUsername: data.actorUsername || '',
              actorDisplayName: data.actorDisplayName || '',
              actorAvatarUrl: data.actorAvatarUrl || null,
              targetId: data.targetId || '',
              targetType: data.targetType || 'video',
              message: data.message || '',
              createdAt,
              isRead: data.isRead ?? false,
            });
          });

          // Sort by createdAt desc (safety net)
          notificationList.sort((a, b) => {
            return b.createdAt.getTime() - a.createdAt.getTime();
          });

          setNotifications(notificationList);
          
          // Calculate unread count
          const unread = notificationList.filter(n => !n.isRead).length;
          setUnreadCount(unread);
          
          setLoading(false);
        } catch (err) {
          console.error('Error processing notifications:', err);
          setError(err.message);
          setLoading(false);
        }
      },
      (err) => {
        console.error('Error in notifications listener:', err);
        setError(err.message);
        setLoading(false);
      }
    );

    return () => unsubscribe();
  }, [currentUser?.uid, maxNotifications]);

  return {
    notifications,
    unreadCount,
    loading,
    error,
  };
};
```

---

## 🔧 Step 4: Activity Row Component

Create `src/components/ActivityRow.jsx`:

```javascript
import React from 'react';
import { formatDistanceToNow } from 'date-fns';
import './ActivityRow.css';

const ActivityRow = ({ notification, onTap, isRead }) => {
  const handleClick = () => {
    if (onTap) {
      onTap(notification);
    }
  };

  const getTypeIcon = (type) => {
    switch (type) {
      case 'follow':
        return '👤';
      case 'like':
        return '❤️';
      case 'comment':
        return '💬';
      case 'thread_reply':
        return '↩️';
      case 'system':
        return '🔔';
      default:
        return '📌';
    }
  };

  const relativeTime = formatDistanceToNow(notification.createdAt, {
    addSuffix: true,
  });

  return (
    <div
      className={`activity-row ${!isRead ? 'activity-row-unread' : ''}`}
      onClick={handleClick}
    >
      <div className="activity-row-avatar">
        {notification.actorAvatarUrl ? (
          <img
            src={notification.actorAvatarUrl}
            alt={notification.actorDisplayName || notification.actorUsername}
            onError={(e) => {
              e.target.src = '/default-avatar.png';
            }}
          />
        ) : (
          <div className="activity-row-avatar-placeholder">
            {notification.actorDisplayName?.[0] || notification.actorUsername?.[0] || '?'}
          </div>
        )}
      </div>

      <div className="activity-row-content">
        <div className="activity-row-header">
          <span className="activity-row-type-icon">
            {getTypeIcon(notification.type)}
          </span>
          <span className="activity-row-name">
            {notification.actorDisplayName || notification.actorUsername || 'Someone'}
          </span>
          <span className="activity-row-time">{relativeTime}</span>
        </div>
        <div className="activity-row-message">{notification.message}</div>
      </div>

      {notification.postThumbnailUrl && (
        <div className="activity-row-thumbnail">
          <img
            src={notification.postThumbnailUrl}
            alt="Post thumbnail"
            onError={(e) => {
              e.target.style.display = 'none';
            }}
          />
        </div>
      )}
    </div>
  );
};

export default ActivityRow;
```

Create `src/components/ActivityRow.css`:

```css
.activity-row {
  display: flex;
  align-items: center;
  padding: 12px 16px;
  cursor: pointer;
  transition: background-color 0.2s;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.activity-row:hover {
  background-color: rgba(255, 255, 255, 0.05);
}

.activity-row-unread {
  background-color: rgba(146, 72, 210, 0.1);
  font-weight: 500;
}

.activity-row-avatar {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  overflow: hidden;
  margin-right: 12px;
  flex-shrink: 0;
}

.activity-row-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.activity-row-avatar-placeholder {
  width: 100%;
  height: 100%;
  background: linear-gradient(135deg, #9248d2 0%, #e91e63 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-weight: bold;
  font-size: 20px;
}

.activity-row-content {
  flex: 1;
  min-width: 0;
}

.activity-row-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 4px;
}

.activity-row-type-icon {
  font-size: 16px;
}

.activity-row-name {
  font-weight: 600;
  color: white;
}

.activity-row-time {
  margin-left: auto;
  font-size: 12px;
  color: rgba(255, 255, 255, 0.6);
}

.activity-row-message {
  font-size: 14px;
  color: rgba(255, 255, 255, 0.8);
  line-height: 1.4;
}

.activity-row-thumbnail {
  width: 64px;
  height: 64px;
  border-radius: 8px;
  overflow: hidden;
  margin-left: 12px;
  flex-shrink: 0;
}

.activity-row-thumbnail img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
```

---

## 🔧 Step 5: Activity View Component

Create `src/components/ActivityView.jsx`:

```javascript
import React, { useState, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { useActivityNotifications } from '../hooks/useActivityNotifications';
import { markAllUnreadAsRead, markNotificationAsRead } from '../services/activityService';
import { useAuth } from '../hooks/useAuth';
import ActivityRow from './ActivityRow';
import './ActivityView.css';

const ActivityView = () => {
  const { currentUser } = useAuth();
  const navigate = useNavigate();
  const { notifications, unreadCount, loading, error } = useActivityNotifications(50);
  const [markingAll, setMarkingAll] = useState(false);

  const handleMarkAllAsRead = async () => {
    if (!currentUser?.uid || markingAll) return;

    setMarkingAll(true);
    try {
      const result = await markAllUnreadAsRead(currentUser.uid);
      if (result.success) {
        console.log(`Marked ${result.count} notifications as read`);
      } else {
        console.error('Failed to mark all as read:', result.error);
      }
    } catch (err) {
      console.error('Error marking all as read:', err);
    } finally {
      setMarkingAll(false);
    }
  };

  const handleNotificationTap = async (notification) => {
    // Mark as read when tapped
    if (!notification.isRead && currentUser?.uid) {
      await markNotificationAsRead(currentUser.uid, notification.id);
    }

    // Navigate based on targetType
    switch (notification.targetType) {
      case 'video':
        navigate(`/video/${notification.targetId}`);
        break;
      case 'post':
        navigate(`/post/${notification.targetId}`);
        break;
      case 'thread':
        navigate(`/thread/${notification.targetId}`);
        break;
      case 'user':
        navigate(`/profile/${notification.actorId}`);
        break;
      default:
        // System notifications might not have a target
        break;
    }
  };

  const handleRetry = () => {
    window.location.reload();
  };

  if (loading) {
    return (
      <div className="activity-view activity-view-loading">
        <div className="activity-view-spinner">Loading notifications...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="activity-view activity-view-error">
        <div className="activity-view-error-content">
          <h2>Unable to load notifications</h2>
          <p>{error}</p>
          <button onClick={handleRetry} className="activity-view-retry-button">
            Retry
          </button>
        </div>
      </div>
    );
  }

  if (notifications.length === 0) {
    return (
      <div className="activity-view activity-view-empty">
        <div className="activity-view-empty-content">
          <div className="activity-view-empty-icon">🔔</div>
          <h2>No notifications yet</h2>
          <p>When you get notifications, they'll appear here</p>
        </div>
      </div>
    );
  }

  return (
    <div className="activity-view">
      <div className="activity-view-header">
        <h1 className="activity-view-title">Activity</h1>
        {unreadCount > 0 && (
          <button
            onClick={handleMarkAllAsRead}
            disabled={markingAll}
            className="activity-view-mark-all-button"
          >
            {markingAll ? 'Marking...' : 'Mark all as read'}
          </button>
        )}
      </div>

      <div className="activity-view-list">
        {notifications.map((notification) => (
          <ActivityRow
            key={notification.id}
            notification={notification}
            isRead={notification.isRead}
            onTap={handleNotificationTap}
          />
        ))}
      </div>
    </div>
  );
};

export default ActivityView;
```

Create `src/components/ActivityView.css`:

```css
.activity-view {
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
  min-height: 100vh;
  background: linear-gradient(180deg, #0f172a 0%, #1e293b 100%);
  color: white;
}

.activity-view-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
  padding-bottom: 16px;
  border-bottom: 2px solid rgba(146, 72, 210, 0.3);
}

.activity-view-title {
  font-size: 28px;
  font-weight: bold;
  margin: 0;
  background: linear-gradient(135deg, #9248d2 0%, #e91e63 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.activity-view-mark-all-button {
  padding: 8px 16px;
  background: rgba(146, 72, 210, 0.2);
  border: 1px solid rgba(146, 72, 210, 0.5);
  border-radius: 8px;
  color: white;
  cursor: pointer;
  font-size: 14px;
  transition: all 0.2s;
}

.activity-view-mark-all-button:hover:not(:disabled) {
  background: rgba(146, 72, 210, 0.3);
  border-color: rgba(146, 72, 210, 0.7);
}

.activity-view-mark-all-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.activity-view-list {
  display: flex;
  flex-direction: column;
}

.activity-view-loading,
.activity-view-error,
.activity-view-empty {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 400px;
}

.activity-view-spinner {
  font-size: 18px;
  color: rgba(255, 255, 255, 0.6);
}

.activity-view-error-content,
.activity-view-empty-content {
  text-align: center;
  max-width: 400px;
}

.activity-view-error-content h2,
.activity-view-empty-content h2 {
  font-size: 24px;
  margin-bottom: 12px;
}

.activity-view-error-content p,
.activity-view-empty-content p {
  color: rgba(255, 255, 255, 0.6);
  margin-bottom: 24px;
}

.activity-view-retry-button {
  padding: 12px 24px;
  background: linear-gradient(135deg, #9248d2 0%, #e91e63 100%);
  border: none;
  border-radius: 8px;
  color: white;
  font-size: 16px;
  font-weight: 600;
  cursor: pointer;
  transition: transform 0.2s;
}

.activity-view-retry-button:hover {
  transform: scale(1.05);
}

.activity-view-empty-icon {
  font-size: 64px;
  margin-bottom: 16px;
}
```

---

## 🔧 Step 6: Header Badge Hook

Create `src/hooks/useActivityBadge.js`:

```javascript
import { useActivityNotifications } from './useActivityNotifications';

/**
 * Hook for header badge unread count
 * Returns formatted badge count (99+ cap, hide at 0)
 */
export const useActivityBadge = () => {
  const { unreadCount } = useActivityNotifications();

  const badgeCount = useMemo(() => {
    if (unreadCount === 0) return null;
    if (unreadCount > 99) return '99+';
    return unreadCount.toString();
  }, [unreadCount]);

  return {
    badgeCount,
    hasUnread: unreadCount > 0,
  };
};
```

Usage in header component:

```javascript
import { useActivityBadge } from '../hooks/useActivityBadge';

const Header = () => {
  const { badgeCount, hasUnread } = useActivityBadge();

  return (
    <header>
      <Link to="/activity">
        <BellIcon />
        {hasUnread && (
          <span className="badge">{badgeCount}</span>
        )}
      </Link>
    </header>
  );
};
```

---

## 🔧 Step 7: Firestore Rules Update

Update `firestore.rules` to include activity collection:

```javascript
match /activity/{userId}/notifications/{notificationId} {
  // Users can only read their own notifications
  allow read: if request.auth != null && request.auth.uid == userId;
  
  // Users can update their own notifications (mark as read)
  allow update: if request.auth != null && request.auth.uid == userId;
  
  // Server/cloud functions can create notifications
  allow create: if request.auth != null;
  
  // Allow listing for querying
  allow list: if request.auth != null && request.auth.uid == userId;
}
```

---

## 🔧 Step 8: Required Index

Create composite index in Firebase Console:

**Collection:** `activity/{userId}/notifications`
**Fields:** `createdAt` (Descending)

Or use Firebase CLI:

```bash
firebase firestore:indexes
```

Add to `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "notifications",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    }
  ]
}
```

---

## ✅ Mobile Parity Checklist

- [x] Real-time listener via `onSnapshot`
- [x] Unread count calculation (`isRead === false`)
- [x] Mark all as read (bulk update)
- [x] Mark single as read (on tap)
- [x] Badge in header (99+ cap, hide at 0)
- [x] Navigation to target content (video/post/thread/user)
- [x] Error handling with retry
- [x] Empty state
- [x] Loading state
- [x] Relative time display
- [x] Unread styling (highlighted)
- [x] Actor avatar/name display
- [x] Type icons
- [x] Thumbnail display (if available)

---

## 🚀 Integration Steps

1. **Install dependencies:**
   ```bash
   npm install firebase date-fns
   ```

2. **Create all files** listed above in your website project

3. **Add route** in your router:
   ```javascript
   import ActivityView from './components/ActivityView';
   
   <Route path="/activity" element={<ActivityView />} />
   ```

4. **Add badge to header** using `useActivityBadge` hook

5. **Update Firestore rules** as shown in Step 7

6. **Create Firestore index** as shown in Step 8

7. **Test** by creating test notifications in Firestore

---

## 📝 Notes

- **Data Model**: Uses `activity/{userId}/notifications/{notificationId}` structure as specified
- **Real-time**: Updates instantly via Firestore `onSnapshot`
- **Performance**: Limits to 50 notifications, pagination can be added later
- **Error Handling**: Graceful fallbacks for missing data
- **Mobile Sync**: Same Firestore structure ensures instant sync with mobile app

---

## 🔍 Testing

1. Create test notification in Firestore:
   ```javascript
   {
     type: 'like',
     actorId: 'user123',
     actorUsername: 'testuser',
     actorDisplayName: 'Test User',
     targetId: 'video456',
     targetType: 'video',
     message: 'Test User liked your video',
     createdAt: Timestamp.now(),
     isRead: false
   }
   ```

2. Verify real-time update appears in web UI

3. Tap notification → should navigate and mark as read

4. Click "Mark all as read" → all should become read

5. Check header badge updates in real-time

---

## 🎯 Summary

Complete web implementation matching mobile app behavior:
- ✅ Real-time notifications
- ✅ Unread count badge
- ✅ Mark as read functionality
- ✅ Navigation to content
- ✅ Error handling
- ✅ Mobile parity
