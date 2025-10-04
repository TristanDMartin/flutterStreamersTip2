const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Cloud Function to schedule notifications when a bookmark is created
exports.onBookmarkCreate = functions.firestore
  .document('users/{uid}/bookmarks/{eventId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    
    // Only schedule if notifications are enabled
    if (!data.notify) return null;

    const { uid, eventId } = context.params;
    const notifyAt = data.notifyAt.toDate();
    
    // Schedule the notification task
    const taskId = await scheduleNotificationTask({
      uid,
      eventId,
      runAt: notifyAt,
      title: data.title,
      creatorId: data.creatorId,
    });

    // Update the bookmark with the scheduled task ID
    await snap.ref.update({ scheduledTaskId: taskId });
    
    console.log(`Scheduled notification for event ${eventId} at ${notifyAt}`);
    return null;
  });

// Cloud Function to cancel notifications when a bookmark is deleted
exports.onBookmarkDelete = functions.firestore
  .document('users/{uid}/bookmarks/{eventId}')
  .onDelete(async (snap, context) => {
    const data = snap.data();
    const taskId = data.scheduledTaskId;
    
    if (taskId) {
      await cancelNotificationTask(taskId);
      console.log(`Cancelled notification task ${taskId}`);
    }
    
    return null;
  });

// Cloud Function to send the actual notification
exports.sendEventNotification = functions.https.onCall(async (data, context) => {
  const { uid, eventId, title, creatorId } = data;
  
  // Verify the bookmark still exists and notifications are enabled
  const bookmarkDoc = await admin.firestore()
    .collection('users')
    .doc(uid)
    .collection('bookmarks')
    .doc(eventId)
    .get();
    
  if (!bookmarkDoc.exists) {
    console.log(`Bookmark ${eventId} no longer exists for user ${uid}`);
    return { success: false, reason: 'Bookmark not found' };
  }
  
  const bookmarkData = bookmarkDoc.data();
  if (!bookmarkData.notify) {
    console.log(`Notifications disabled for bookmark ${eventId}`);
    return { success: false, reason: 'Notifications disabled' };
  }
  
  // Get user's FCM tokens
  const tokensSnapshot = await admin.firestore()
    .collection('users')
    .doc(uid)
    .collection('deviceTokens')
    .get();
    
  const tokens = tokensSnapshot.docs.map(doc => doc.id);
  
  if (tokens.length === 0) {
    console.log(`No FCM tokens found for user ${uid}`);
    return { success: false, reason: 'No FCM tokens' };
  }
  
  // Send notification
  const message = {
    notification: {
      title: 'Event is live now',
      body: `@${creatorId} — ${title}`,
    },
    data: {
      eventId,
      creatorId,
      deeplink: `streamerstip://event/${eventId}`,
    },
    tokens,
  };
  
  try {
    const response = await admin.messaging().sendMulticast(message);
    console.log(`Sent notification to ${response.successCount} devices`);
    
    // Mark as notified
    await bookmarkDoc.ref.update({ 
      notifiedAt: admin.firestore.FieldValue.serverTimestamp() 
    });
    
    return { success: true, sentCount: response.successCount };
  } catch (error) {
    console.error('Error sending notification:', error);
    return { success: false, error: error.message };
  }
});

// Helper function to schedule a notification task
async function scheduleNotificationTask({ uid, eventId, runAt, title, creatorId }) {
  // This would integrate with Cloud Tasks or a similar scheduling service
  // For now, we'll use a simple setTimeout approach (not recommended for production)
  
  const delay = runAt.getTime() - Date.now();
  
  if (delay <= 0) {
    // Event is in the past, send immediately
    return await sendEventNotification({ uid, eventId, title, creatorId });
  }
  
  // Schedule for later
  setTimeout(async () => {
    try {
      await sendEventNotification({ uid, eventId, title, creatorId });
    } catch (error) {
      console.error('Error in scheduled notification:', error);
    }
  }, delay);
  
  return `task_${Date.now()}_${eventId}`;
}

// Helper function to cancel a notification task
async function cancelNotificationTask(taskId) {
  // This would integrate with Cloud Tasks to cancel the scheduled task
  console.log(`Would cancel task: ${taskId}`);
  return true;
}

// ============================================================================
// POST COUNTER TRIGGERS - Single source of truth for post counts
// ============================================================================

// Post counting rules
const COUNTABLE_STATUSES = ['published', 'public'];
const EXCLUDED_STATUSES = ['draft', 'scheduled', 'archived', 'deleted', 'hidden', 'moderation', 'private'];
const COUNTABLE_PRIVACY_LEVELS = ['public', 'followers'];

function shouldCountPost(status, privacy) {
  const statusLower = status ? status.toLowerCase() : 'draft';
  const privacyLower = privacy ? privacy.toLowerCase() : 'private';
  
  return COUNTABLE_STATUSES.includes(statusLower) && 
         !EXCLUDED_STATUSES.includes(statusLower) &&
         COUNTABLE_PRIVACY_LEVELS.includes(privacyLower);
}

// Trigger: When a video is created
exports.onVideoCreate = functions.firestore
  .document('videos/{videoId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const userId = data.userId;
    const status = data.status || 'draft';
    const privacy = data.privacy || 'private';
    
    console.log(`📊 Video created: ${context.params.videoId}, User: ${userId}, Status: ${status}, Privacy: ${privacy}`);
    
    // Only increment if the post should be counted
    if (shouldCountPost(status, privacy)) {
      try {
        await admin.firestore().collection('users').doc(userId).update({
          postCount: admin.firestore.FieldValue.increment(1),
          lastPostCountUpdate: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`✅ Post count incremented for user: ${userId}`);
      } catch (error) {
        console.error(`❌ Failed to increment post count for user ${userId}:`, error);
      }
    }
    
    return null;
  });

// Trigger: When a video is updated
exports.onVideoUpdate = functions.firestore
  .document('videos/{videoId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const userId = afterData.userId;
    
    const beforeStatus = beforeData.status || 'draft';
    const beforePrivacy = beforeData.privacy || 'private';
    const afterStatus = afterData.status || 'draft';
    const afterPrivacy = afterData.privacy || 'private';
    
    const beforeCounts = shouldCountPost(beforeStatus, beforePrivacy);
    const afterCounts = shouldCountPost(afterStatus, afterPrivacy);
    
    console.log(`📊 Video updated: ${context.params.videoId}, User: ${userId}`);
    console.log(`   Before: status=${beforeStatus}, privacy=${beforePrivacy}, counts=${beforeCounts}`);
    console.log(`   After: status=${afterStatus}, privacy=${afterPrivacy}, counts=${afterCounts}`);
    
    try {
      if (beforeCounts && !afterCounts) {
        // Post was countable, now it's not - decrement
        await admin.firestore().collection('users').doc(userId).update({
          postCount: admin.firestore.FieldValue.increment(-1),
          lastPostCountUpdate: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`✅ Post count decremented for user: ${userId}`);
      } else if (!beforeCounts && afterCounts) {
        // Post wasn't countable, now it is - increment
        await admin.firestore().collection('users').doc(userId).update({
          postCount: admin.firestore.FieldValue.increment(1),
          lastPostCountUpdate: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`✅ Post count incremented for user: ${userId}`);
      }
      
      // Ensure count doesn't go below 0
      await ensureNonNegativeCount(userId);
      
    } catch (error) {
      console.error(`❌ Failed to update post count for user ${userId}:`, error);
    }
    
    return null;
  });

// Trigger: When a video is deleted
exports.onVideoDelete = functions.firestore
  .document('videos/{videoId}')
  .onDelete(async (snap, context) => {
    const data = snap.data();
    const userId = data.userId;
    const status = data.status || 'draft';
    const privacy = data.privacy || 'private';
    
    console.log(`📊 Video deleted: ${context.params.videoId}, User: ${userId}, Status: ${status}, Privacy: ${privacy}`);
    
    // Only decrement if the post was being counted
    if (shouldCountPost(status, privacy)) {
      try {
        await admin.firestore().collection('users').doc(userId).update({
          postCount: admin.firestore.FieldValue.increment(-1),
          lastPostCountUpdate: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`✅ Post count decremented for user: ${userId}`);
        
        // Ensure count doesn't go below 0
        await ensureNonNegativeCount(userId);
      } catch (error) {
        console.error(`❌ Failed to decrement post count for user ${userId}:`, error);
      }
    }
    
    return null;
  });

// Helper function to ensure post count doesn't go below 0
async function ensureNonNegativeCount(userId) {
  try {
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (userDoc.exists) {
      const currentCount = userDoc.data().postCount || 0;
      if (currentCount < 0) {
        await admin.firestore().collection('users').doc(userId).update({
          postCount: 0,
          postCountCorrected: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`🔧 Corrected negative post count for user: ${userId}`);
      }
    }
  } catch (error) {
    console.error(`❌ Failed to ensure non-negative count for user ${userId}:`, error);
  }
}

// Cloud Function to reconcile post counts (admin function)
exports.reconcilePostCounts = functions.https.onCall(async (data, context) => {
  // Verify admin access (implement your own admin check)
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }
  
  const { userIds } = data;
  const results = {};
  
  for (const userId of userIds) {
    try {
      const count = await reconcileUserPostCount(userId);
      results[userId] = count;
    } catch (error) {
      console.error(`❌ Failed to reconcile post count for user ${userId}:`, error);
      results[userId] = 0;
    }
  }
  
  return { results };
});

// Helper function to reconcile a single user's post count
async function reconcileUserPostCount(userId) {
  console.log(`🔧 Reconciling post count for user: ${userId}`);
  
  // Count actual countable posts
  const videosSnapshot = await admin.firestore()
    .collection('videos')
    .where('userId', '==', userId)
    .get();
  
  let actualCount = 0;
  videosSnapshot.docs.forEach(doc => {
    const data = doc.data();
    const status = data.status || 'draft';
    const privacy = data.privacy || 'private';
    
    if (shouldCountPost(status, privacy)) {
      actualCount++;
    }
  });
  
  // Update the counter with the actual count
  await admin.firestore().collection('users').doc(userId).update({
    postCount: actualCount,
    lastPostCountReconciliation: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  console.log(`✅ Reconciled post count for user ${userId}: ${actualCount} posts`);
  return actualCount;
}
