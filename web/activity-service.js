/**
 * Activity Service - Web Implementation
 * Handles marking notifications as read
 * 
 * Note: Supports both data structures:
 * - New: activity/{userId}/notifications/{notificationId}
 * - Legacy: notifications/{userId}/items/{itemId}
 */

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
import { db } from './firebase-config'; // Adjust import path as needed

/**
 * Mark a single notification as read
 * Supports both activity/ and notifications/ structures
 */
export const markNotificationAsRead = async (userId, notificationId, useLegacyStructure = false) => {
  try {
    let notificationRef;
    
    if (useLegacyStructure) {
      // Legacy: notifications/{userId}/items/{notificationId}
      notificationRef = doc(db, 'notifications', userId, 'items', notificationId);
      await updateDoc(notificationRef, { status: 'delivered' });
    } else {
      // New: activity/{userId}/notifications/{notificationId}
      notificationRef = doc(db, 'activity', userId, 'notifications', notificationId);
      await updateDoc(notificationRef, { isRead: true });
    }
    
    return { success: true };
  } catch (error) {
    console.error('Error marking notification as read:', error);
    return { success: false, error: error.message };
  }
};

/**
 * Mark all currently loaded notifications as read
 */
export const markAllNotificationsAsRead = async (userId, notificationIds, useLegacyStructure = false) => {
  try {
    if (!notificationIds || notificationIds.length === 0) {
      return { success: true, count: 0 };
    }

    const batch = writeBatch(db);
    let count = 0;

    for (const notificationId of notificationIds) {
      let notificationRef;
      
      if (useLegacyStructure) {
        notificationRef = doc(db, 'notifications', userId, 'items', notificationId);
        batch.update(notificationRef, { status: 'delivered' });
      } else {
        notificationRef = doc(db, 'activity', userId, 'notifications', notificationId);
        batch.update(notificationRef, { isRead: true });
      }
      
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
export const markAllUnreadAsRead = async (userId, useLegacyStructure = false) => {
  try {
    let notificationsRef;
    let unreadQuery;
    
    if (useLegacyStructure) {
      // Legacy: notifications/{userId}/items where status != 'delivered'
      notificationsRef = collection(db, 'notifications', userId, 'items');
      unreadQuery = query(
        notificationsRef,
        where('status', '!=', 'delivered'),
        limit(100)
      );
    } else {
      // New: activity/{userId}/notifications where isRead == false
      notificationsRef = collection(db, 'activity', userId, 'notifications');
      unreadQuery = query(
        notificationsRef,
        where('isRead', '==', false),
        limit(100)
      );
    }

    const snapshot = await getDocs(unreadQuery);
    if (snapshot.empty) {
      return { success: true, count: 0 };
    }

    const batch = writeBatch(db);
    let count = 0;

    snapshot.docs.forEach((docSnapshot) => {
      if (useLegacyStructure) {
        batch.update(docSnapshot.ref, { status: 'delivered' });
      } else {
        batch.update(docSnapshot.ref, { isRead: true });
      }
      count++;
    });

    await batch.commit();
    return { success: true, count };
  } catch (error) {
    console.error('Error marking all unread as read:', error);
    return { success: false, error: error.message };
  }
};
