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
