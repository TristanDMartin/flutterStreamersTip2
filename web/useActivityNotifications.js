/**
 * useActivityNotifications Hook - Web Implementation
 * Real-time activity notifications hook matching mobile app behavior
 * 
 * Supports both data structures:
 * - New: activity/{userId}/notifications/{notificationId} (with isRead field)
 * - Legacy: notifications/{userId}/items/{itemId} (with status field)
 */

import { useState, useEffect, useMemo } from 'react';
import {
  collection,
  query,
  orderBy,
  limit,
  onSnapshot,
  Timestamp
} from 'firebase/firestore';
import { db } from './firebase-config'; // Adjust import path as needed
import { useAuth } from './useAuth'; // Your auth hook - adjust path

/**
 * Hook for real-time activity notifications
 * Mirrors mobile app behavior with real-time updates
 * 
 * @param {number} maxNotifications - Maximum number of notifications to load (default: 50)
 * @param {boolean} useLegacyStructure - Use legacy notifications/ structure (default: false)
 */
export const useActivityNotifications = (maxNotifications = 50, useLegacyStructure = false) => {
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

    let notificationsRef;
    let notificationsQuery;

    if (useLegacyStructure) {
      // Legacy: notifications/{userId}/items
      notificationsRef = collection(db, 'notifications', currentUser.uid, 'items');
      notificationsQuery = query(
        notificationsRef,
        orderBy('timestamp', 'desc'),
        limit(maxNotifications)
      );
    } else {
      // New: activity/{userId}/notifications
      notificationsRef = collection(db, 'activity', currentUser.uid, 'notifications');
      notificationsQuery = query(
        notificationsRef,
        orderBy('createdAt', 'desc'),
        limit(maxNotifications)
      );
    }

    const unsubscribe = onSnapshot(
      notificationsQuery,
      (snapshot) => {
        try {
          const notificationList = [];
          
          snapshot.forEach((doc) => {
            const data = doc.data();
            
            // Handle timestamp/createdAt - ensure it's a valid date
            let createdAt;
            if (useLegacyStructure) {
              createdAt = data.timestamp;
            } else {
              createdAt = data.createdAt;
            }
            
            if (!createdAt) {
              createdAt = Timestamp.now();
            } else if (createdAt.toDate) {
              createdAt = createdAt.toDate();
            } else if (createdAt instanceof Date) {
              // Already a Date
            } else {
              createdAt = new Date(createdAt);
            }

            // Determine read status
            let isRead;
            if (useLegacyStructure) {
              // Legacy: status === 'delivered' means read
              isRead = data.status === 'delivered';
            } else {
              // New: explicit isRead field
              isRead = data.isRead ?? false;
            }

            // Map legacy data structure to new structure
            const notification = {
              id: doc.id,
              type: data.type || 'like',
              actorId: data.actorId || (data.user?.id) || '',
              actorUsername: data.actorUsername || (data.user?.username) || '',
              actorDisplayName: data.actorDisplayName || (data.user?.displayName) || '',
              actorAvatarUrl: data.actorAvatarUrl || (data.user?.avatarURL) || null,
              targetId: data.targetId || data.videoId || '',
              targetType: data.targetType || (data.videoId ? 'video' : 'post'),
              message: data.message || _generateMessage(data.type, data.user),
              createdAt,
              isRead,
              // Legacy fields (for compatibility)
              postThumbnailUrl: data.postThumbnailUrl || null,
              commentText: data.commentText || null,
              videoId: data.videoId || null,
            };

            notificationList.push(notification);
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
        
        // Handle permission-denied gracefully
        if (err.code === 'permission-denied') {
          setError('Permission denied. Please check Firestore rules.');
        } else {
          setError(err.message);
        }
        
        setLoading(false);
      }
    );

    return () => unsubscribe();
  }, [currentUser?.uid, maxNotifications, useLegacyStructure]);

  return {
    notifications,
    unreadCount,
    loading,
    error,
  };
};

/**
 * Generate message from notification type and user
 */
function _generateMessage(type, user) {
  const userName = user?.displayName || user?.username || 'Someone';
  const normalized = String(type || '').trim().toLowerCase();
  
  switch (normalized) {
    case 'follow':
    case 'follows':
      return `${userName} started following you`;
    case 'like':
    case 'likes':
    case 'like_video':
      return `${userName} liked your video`;
    case 'comment':
    case 'comments':
      return `${userName} commented on your video`;
    case 'thread_reply':
      return `${userName} replied to your comment`;
    case 'message':
    case 'new_message':
    case 'newmessage':
    case 'dm':
    case 'direct_message':
      return `${userName} sent you a message`;
    case 'system':
      return 'You have a new notification';
    default:
      return `${userName} sent an update`;
  }
}

/**
 * Hook for header badge unread count
 * Returns formatted badge count (99+ cap, hide at 0)
 */
export const useActivityBadge = (useLegacyStructure = false) => {
  const { unreadCount } = useActivityNotifications(50, useLegacyStructure);

  const badgeCount = useMemo(() => {
    if (unreadCount === 0) return null;
    if (unreadCount > 99) return '99+';
    return unreadCount.toString();
  }, [unreadCount]);

  return {
    badgeCount,
    hasUnread: unreadCount > 0,
    unreadCount,
  };
};
