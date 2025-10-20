# ActivityView Follow Notifications Implementation 🔔

## 🚨 Current Issue

**Follow notifications are NOT appearing** because:
1. `EventTriggerService` is not initialized in `FollowsService`
2. Website follow actions don't trigger mobile app notifications
3. Missing real-time sync between website and mobile notifications

---

## 🔧 Mobile App Fix (Required)

### Step 1: Initialize EventTriggerService

**File:** `lib/services/follows_service.dart`

The `EventTriggerService` needs to be set. Add this to your app initialization:

```dart
// In your main.dart or app initialization
void initializeServices() {
  final followsService = FollowsService();
  final eventTriggerService = EventTriggerService();
  final notificationService = NotificationService();
  
  // Set up the chain
  eventTriggerService.setNotificationService(notificationService);
  followsService.setEventTriggerService(eventTriggerService);
  
  debugPrint('✅ EventTriggerService initialized for follow notifications');
}
```

### Step 2: Update FollowsService Provider

**File:** `lib/providers/follows_provider.dart` (create if doesn't exist)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/follows_service.dart';
import '../services/event_trigger_service.dart';
import '../services/notification_service.dart';

final followsServiceProvider = Provider<FollowsService>((ref) {
  final service = FollowsService();
  final eventTriggerService = EventTriggerService();
  final notificationService = NotificationService();
  
  // Initialize the notification chain
  eventTriggerService.setNotificationService(notificationService);
  service.setEventTriggerService(eventTriggerService);
  
  return service;
});
```

### Step 3: Use Provider in StreamerCardView

**File:** `lib/widgets/streamer_card_view.dart`

```dart
// Replace the current FollowsService() instantiation with:
final followsService = ref.read(followsServiceProvider);

// Then use it:
final success = await followsService.followUser(widget.userId);
```

---

## 🌐 Website Implementation (Required)

### Step 1: Create Follow Notification Service

**File:** `website/src/services/followNotificationService.js`

```javascript
import { db } from './firebase';
import { collection, addDoc, serverTimestamp, doc, getDoc } from 'firebase/firestore';

export class FollowNotificationService {
  /**
   * Create a follow notification when someone follows a user
   * This ensures notifications appear in both mobile app and website
   */
  static async createFollowNotification(followerId, followingId) {
    try {
      console.log(`🔔 Creating follow notification: ${followerId} -> ${followingId}`);
      
      // Get follower user data
      const followerDoc = await getDoc(doc(db, 'users', followerId));
      if (!followerDoc.exists()) {
        console.error('❌ Follower user not found:', followerId);
        return;
      }
      
      const followerData = followerDoc.data();
      
      // Create notification in the same format as mobile app
      const notificationData = {
        type: 'follow',
        user: {
          id: followerId,
          username: followerData.username || 'Unknown',
          displayName: followerData.displayName || 'Unknown',
          avatarURL: followerData.avatarURL || followerData.avatarUrl || null,
        },
        timestamp: serverTimestamp(),
        isRead: false,
        status: 'pending',
      };
      
      // Add to notifications/{followingId}/items collection
      await addDoc(
        collection(db, 'notifications', followingId, 'items'),
        notificationData
      );
      
      console.log('✅ Follow notification created successfully');
      
      // Also send push notification if user has device tokens
      await this.sendPushNotification(followingId, followerData);
      
    } catch (error) {
      console.error('❌ Error creating follow notification:', error);
    }
  }
  
  /**
   * Send push notification for follow events
   */
  static async sendPushNotification(targetUserId, followerData) {
    try {
      // Get user's device tokens
      const userDoc = await getDoc(doc(db, 'users', targetUserId));
      if (!userDoc.exists()) return;
      
      const userData = userDoc.data();
      const deviceTokens = userData.deviceTokens || [];
      
      if (deviceTokens.length === 0) {
        console.log('ℹ️ No device tokens found for user:', targetUserId);
        return;
      }
      
      // Send push notification via your push service
      // This would integrate with FCM or your push notification service
      console.log(`📱 Would send push notification to ${deviceTokens.length} devices`);
      
    } catch (error) {
      console.error('❌ Error sending push notification:', error);
    }
  }
}
```

### Step 2: Update Website Follow Function

**File:** `website/src/services/followService.js`

```javascript
import { db } from './firebase';
import { doc, setDoc, updateDoc, increment, serverTimestamp } from 'firebase/firestore';
import { FollowNotificationService } from './followNotificationService';

export class FollowService {
  /**
   * Follow a user from the website
   * This creates the follow relationship AND the notification
   */
  static async followUser(currentUserId, targetUserId) {
    try {
      console.log(`🔄 Website: Following user ${targetUserId}`);
      
      // Create follow relationship
      const followDocId = `${currentUserId}_${targetUserId}`;
      const followRef = doc(db, 'follows', followDocId);
      
      await setDoc(followRef, {
        followerId: currentUserId,
        followedId: targetUserId,
        createdAt: serverTimestamp(),
      });
      
      // Update follower/following counts
      await updateDoc(doc(db, 'users', currentUserId), {
        followingCount: increment(1),
      });
      
      await updateDoc(doc(db, 'users', targetUserId), {
        followersCount: increment(1),
      });
      
      // ✅ CRITICAL: Create follow notification
      await FollowNotificationService.createFollowNotification(
        currentUserId,
        targetUserId
      );
      
      console.log('✅ Website: Follow successful with notification');
      return true;
      
    } catch (error) {
      console.error('❌ Website: Follow failed:', error);
      return false;
    }
  }
  
  /**
   * Unfollow a user from the website
   */
  static async unfollowUser(currentUserId, targetUserId) {
    try {
      console.log(`🔄 Website: Unfollowing user ${targetUserId}`);
      
      // Remove follow relationship
      const followDocId = `${currentUserId}_${targetUserId}`;
      const followRef = doc(db, 'follows', followDocId);
      
      await deleteDoc(followRef);
      
      // Update follower/following counts
      await updateDoc(doc(db, 'users', currentUserId), {
        followingCount: increment(-1),
      });
      
      await updateDoc(doc(db, 'users', targetUserId), {
        followersCount: increment(-1),
      });
      
      console.log('✅ Website: Unfollow successful');
      return true;
      
    } catch (error) {
      console.error('❌ Website: Unfollow failed:', error);
      return false;
    }
  }
}
```

### Step 3: Update Website Follow Button Component

**File:** `website/src/components/FollowButton.jsx`

```javascript
import React, { useState } from 'react';
import { FollowService } from '../services/followService';
import { useAuth } from '../hooks/useAuth';

export const FollowButton = ({ targetUserId, isFollowing, onFollowChange }) => {
  const [loading, setLoading] = useState(false);
  const { currentUser } = useAuth();
  
  const handleFollow = async () => {
    if (!currentUser || loading) return;
    
    setLoading(true);
    try {
      if (isFollowing) {
        const success = await FollowService.unfollowUser(currentUser.uid, targetUserId);
        if (success) {
          onFollowChange(false);
          console.log('✅ Unfollowed successfully');
        }
      } else {
        const success = await FollowService.followUser(currentUser.uid, targetUserId);
        if (success) {
          onFollowChange(true);
          console.log('✅ Followed successfully - notification sent!');
        }
      }
    } catch (error) {
      console.error('❌ Follow action failed:', error);
    } finally {
      setLoading(false);
    }
  };
  
  return (
    <button
      onClick={handleFollow}
      disabled={loading}
      className={`follow-button ${isFollowing ? 'following' : 'not-following'}`}
    >
      {loading ? '...' : (isFollowing ? 'Following' : 'Follow')}
    </button>
  );
};
```

---

## 🔄 Real-Time Sync Implementation

### Mobile App: ActivityView Real-Time Listener

**File:** `lib/providers/activity_provider.dart`

The ActivityView already has real-time listeners, but let's ensure they're working:

```dart
// This should already be working, but verify the path:
_notifSub = _db
    .collection('notifications')
    .doc(userId)
    .collection('items')  // ← This is the correct path
    .orderBy('timestamp', descending: true)
    .snapshots()
    .listen((snap) {
      // Process notifications...
    });
```

### Website: Real-Time Activity Feed

**File:** `website/src/components/ActivityFeed.jsx`

```javascript
import React, { useState, useEffect } from 'react';
import { collection, query, orderBy, onSnapshot } from 'firebase/firestore';
import { db } from '../services/firebase';
import { useAuth } from '../hooks/useAuth';

export const ActivityFeed = () => {
  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(true);
  const { currentUser } = useAuth();
  
  useEffect(() => {
    if (!currentUser) return;
    
    console.log('🔔 Setting up real-time notifications listener');
    
    // Listen to notifications in real-time
    const notificationsQuery = query(
      collection(db, 'notifications', currentUser.uid, 'items'),
      orderBy('timestamp', 'desc')
    );
    
    const unsubscribe = onSnapshot(notificationsQuery, (snapshot) => {
      const newNotifications = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      
      setNotifications(newNotifications);
      setLoading(false);
      
      console.log(`📱 Received ${newNotifications.length} notifications`);
    }, (error) => {
      console.error('❌ Notifications listener error:', error);
      setLoading(false);
    });
    
    return () => unsubscribe();
  }, [currentUser]);
  
  if (loading) {
    return <div>Loading notifications...</div>;
  }
  
  return (
    <div className="activity-feed">
      <h2>Activity</h2>
      {notifications.length === 0 ? (
        <p>No notifications yet</p>
      ) : (
        notifications.map(notification => (
          <div key={notification.id} className="notification-item">
            {notification.type === 'follow' && (
              <p>
                <strong>{notification.user.displayName}</strong> started following you
              </p>
            )}
            {/* Add other notification types */}
          </div>
        ))
      )}
    </div>
  );
};
```

---

## 🧪 Testing the Implementation

### Test 1: Mobile App Follow

1. **Open mobile app**
2. **Go to a user's profile**
3. **Tap Follow button**
4. **Check ActivityView** → Should show follow notification
5. **Check website** → Should also show the notification

### Test 2: Website Follow

1. **Open website**
2. **Go to a user's profile**
3. **Click Follow button**
4. **Check mobile app ActivityView** → Should show follow notification
5. **Check website ActivityFeed** → Should also show the notification

### Test 3: Real-Time Sync

1. **Have two devices/browsers open**
2. **Follow someone from one device**
3. **Watch the other device** → Should update instantly

---

## 🔍 Debugging

### Check Console Logs

**Mobile App:**
```
🔔 FollowsService: Triggering follow event notification
✅ Follow notification created: followerId -> followingId
```

**Website:**
```
🔔 Creating follow notification: followerId -> followingId
✅ Follow notification created successfully
```

### Check Firestore

1. **Go to Firebase Console**
2. **Navigate to:** `notifications/{targetUserId}/items`
3. **Should see new follow notification document**

### Check ActivityView

1. **Open ActivityView in mobile app**
2. **Should show follow notification**
3. **If empty, check console for errors**

---

## 📋 Implementation Checklist

### Mobile App:
- [ ] Initialize EventTriggerService in FollowsService
- [ ] Create followsServiceProvider with proper initialization
- [ ] Update StreamerCardView to use provider
- [ ] Test follow notifications appear in ActivityView

### Website:
- [ ] Create FollowNotificationService
- [ ] Update FollowService to create notifications
- [ ] Update FollowButton component
- [ ] Create ActivityFeed component with real-time listener
- [ ] Test follow notifications appear on website

### Testing:
- [ ] Mobile follow → Website shows notification
- [ ] Website follow → Mobile shows notification
- [ ] Real-time sync works both ways
- [ ] Push notifications work (optional)

---

## 🚀 Quick Start

**For immediate testing:**

1. **Add this to your mobile app initialization:**
```dart
// In main.dart or app startup
final followsService = FollowsService();
final eventTriggerService = EventTriggerService();
final notificationService = NotificationService();

eventTriggerService.setNotificationService(notificationService);
followsService.setEventTriggerService(eventTriggerService);
```

2. **Add this to your website follow function:**
```javascript
// After creating follow relationship
await FollowNotificationService.createFollowNotification(
  currentUserId,
  targetUserId
);
```

3. **Test follow someone** → Should see notification in ActivityView! ✅

---

**This will make follow notifications work instantly between website and mobile app!** 🔔
