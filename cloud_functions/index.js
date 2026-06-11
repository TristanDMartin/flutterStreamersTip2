const functions = require('firebase-functions');
const {onRequest, onCall, HttpsError} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
const {emitTelemetry} = require('./telemetry_emitter');
const {Storage} = require('@google-cloud/storage');
const fs = require('fs');
const path = require('path');
const os = require('os');

admin.initializeApp();
const firestore = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const storage = admin.storage();

// Video transcoding helpers (format check only - no server transcoding)
const {transcodeVideo: transcodeVideoHelper, uploadVariant, getPublicUrl, cleanupFiles} = require('./src/videoTranscoding');
const {checkFormat} = require('./src/videoFormatCheck');
const {
  isPublicFeedEligible,
  scoreVideoForFeed,
  feedMirrorPayload,
} = require('./src/feed_ranking');

function safeEmitTelemetry(eventType, payload) {
  try {
    emitTelemetry(eventType, payload);
  } catch (err) {
    console.error('telemetry emit failed', err);
  }
}

// Storage trigger stub: normalize uploads under raw_uploads/{videoId}/source.*
// In production, run FFmpeg (or Cloud Run) to create a canonical MP4/HLS and
// write canonicalPlaybackUrl + status=ready on the video doc.
exports.onRawUpload = functions.storage.object().onFinalize(async (object) => {
  const rawPath = object.name;
  if (!rawPath || !rawPath.startsWith('raw_uploads/')) return null;

  const parts = rawPath.split('/');
  if (parts.length < 3) return null;
  const videoId = parts[1];

  const videoRef = firestore.collection('videos').doc(videoId);

  // Mark processing
  await videoRef.set(
    {
      status: 'processing',
      rawPath,
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  // TODO: download raw to /tmp, transcode to MP4/H.264/AAC,
  // upload to videos/{videoId}/processed_1080.mp4, then set canonicalPlaybackUrl.
  // For now, just mark failed to avoid dangling "processing".
  await videoRef.set(
    {
      status: 'failed',
      error: 'Transcode step not implemented in this stub.',
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  return null;
});

// DISABLED when Mux configured (Mux handles transcoding). Else: format check.
const useMux = !!process.env.MUX_TOKEN_ID;
exports.transcodeVideo = functions
  .runWith({ timeoutSeconds: 60, memory: '256MB' })
  .storage.object().onFinalize(async (object) => {
    if (useMux) return null;
    const storageClient = new Storage();
    const db = admin.firestore();
    const filePath = object.name;
    const contentType = object.contentType;
    const bucketName = object.bucket;

    if (!contentType || !contentType.startsWith('video/')) {
      console.log('Not a video file, skipping:', filePath);
      return null;
    }

    const pathParts = filePath.split('/');
    if (pathParts[0] !== 'videos' || (pathParts.length !== 3 && pathParts.length !== 4)) {
      console.log('Not in videos/{userId}/{videoId}.mp4, skipping:', filePath);
      return null;
    }

    let videoId;
    if (pathParts.length === 3) {
      videoId = pathParts[2].replace('.mp4', '');
    } else {
      videoId = pathParts[2];
      if (pathParts[3] !== 'original.mp4') return null;
    }

    const bucket = storageClient.bucket(bucketName);
    const file = bucket.file(filePath);
    const videoRef = db.collection('videos').doc(videoId);
    const tempFilePath = path.join(os.tmpdir(), `${videoId}_check.mp4`);

    try {
      await videoRef.set({
        transcodingStatus: 'processing',
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

      await file.download({destination: tempFilePath});
      const result = await checkFormat(tempFilePath);
      cleanupFiles([tempFilePath]);

      if (result.ok) {
        const url720 = await getPublicUrl(file);
        await videoRef.set({
          mp4_720_url: url720,
          videoUrl: url720,
          videoURL: url720,
          canonicalPlaybackUrl: url720,
          transcodingStatus: 'completed',
          transcodedAt: FieldValue.serverTimestamp(),
          status: 'ready',
          isReadyForFeed: true,
          isDeleted: false,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        console.log(`✅ Format OK: ${videoId} - using original as mp4_720_url`);
      } else {
        await videoRef.set({
          transcodingStatus: 'failed',
          transcodingError: result.reason || 'Format not supported',
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        console.log(`❌ Format rejected: ${videoId} - ${result.reason}`);
      }
      return null;
    } catch (error) {
      console.error(`❌ Error processing ${videoId}:`, error);
      cleanupFiles([tempFilePath]);
      try {
        await videoRef.set({
          transcodingStatus: 'failed',
          transcodingError: error.message,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      } catch (updateError) {
        console.error('Failed to mark video transcoding failure:', updateError);
      }
      return null;
    }
  });

// DISABLED: Backfill transcoding - was causing $500+ Cloud Run charges.
exports.backfillVideoTranscoding = functions
  .runWith({timeoutSeconds: 10, memory: '128MB'})
  .https.onRequest((req, res) => {
    res.status(403).json({
      error: 'Backfill disabled to prevent Cloud Run charges.',
      message: 'Use client-side transcoding (FFmpeg.wasm) on website. See website_upload/README.md',
    });
  });

/**
 * Process a single video for backfill transcoding
 */
async function _processVideoForBackfill(storageClient, db, videoId, userId, originalVideoUrl) {
  // Get bucket name from the original video URL or use default
  // Get actual project ID from admin
  const projectId = admin.app().options.projectId || 'streamerstip-6cfdb';
  let bucketName = projectId + '.firebasestorage.app';
  
  // Try to extract bucket name from URL
  if (originalVideoUrl.startsWith('gs://')) {
    const match = originalVideoUrl.match(/gs:\/\/([^/]+)/);
    if (match && match[1].length >= 3) bucketName = match[1];
  } else if (originalVideoUrl.includes('storage.googleapis.com')) {
    const match = originalVideoUrl.match(/storage\.googleapis\.com\/([^/]+)/);
    if (match && match[1].length >= 3) bucketName = match[1];
  } else if (originalVideoUrl.includes('firebasestorage.googleapis.com')) {
    // Firebase Storage URL format: https://firebasestorage.googleapis.com/v0/b/BUCKET_NAME/o/path
    // Match: /v0/b/BUCKET_NAME/ (not /v0/b/v0/)
    const match = originalVideoUrl.match(/\/v0\/b\/([^/?]+)/);
    if (match && match[1] && match[1].length >= 3 && match[1] !== 'v0') {
      bucketName = match[1];
    }
  }
  
  console.log(`📦 Using bucket: ${bucketName}`);
  const bucket = storageClient.bucket(bucketName);
  
  // Temp file paths
  const tempDir = os.tmpdir();
  const tempFilePath = path.join(tempDir, `${videoId}_original.mp4`);
  const temp720Path = path.join(tempDir, `${videoId}_720p.mp4`);
  const temp480Path = path.join(tempDir, `${videoId}_480p.mp4`);
  
  try {
    // Update Firestore: mark as processing
    const videoRef = db.collection('videos').doc(videoId);
    await videoRef.set({
      transcodingStatus: 'processing',
      backfillProcessedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    
    // Download original video directly from URL
    console.log(`📥 Downloading original video from URL: ${originalVideoUrl.substring(0, 100)}...`);
    
    // Use node-fetch to download from the URL
    const fetch = (await import('node-fetch')).default;
    const response = await fetch(originalVideoUrl);
    if (!response.ok) {
      throw new Error(`Failed to download video: HTTP ${response.status} ${response.statusText}`);
    }
    
    // Write to file
    const stream = fs.createWriteStream(tempFilePath);
    await new Promise((resolve, reject) => {
      response.body.pipe(stream);
      response.body.on('error', reject);
      stream.on('finish', resolve);
    });
    
    const downloadStats = fs.statSync(tempFilePath);
    console.log(`📦 Downloaded ${(downloadStats.size / 1024 / 1024).toFixed(2)} MB`);
    
    // Generate 720p variant
    console.log('🎞️ Generating 720p variant...');
    await transcodeVideoHelper(tempFilePath, temp720Path, 720);
    const stats720 = fs.statSync(temp720Path);
    console.log(`✅ 720p generated: ${(stats720.size / 1024 / 1024).toFixed(2)} MB`);
    
    // Generate 480p variant
    console.log('🎞️ Generating 480p variant...');
    await transcodeVideoHelper(tempFilePath, temp480Path, 480);
    const stats480 = fs.statSync(temp480Path);
    console.log(`✅ 480p generated: ${(stats480.size / 1024 / 1024).toFixed(2)} MB`);
    
    // Upload variants to Storage
    console.log('📤 Uploading variants to Storage...');
    
    // Get original file path from URL or construct it
    let originalFilePath = originalVideoUrl;
    if (originalVideoUrl.includes('/o/')) {
      // Extract path from Firebase Storage URL
      const match = originalVideoUrl.match(/\/o\/(.+?)(?:\?|$)/);
      if (match) {
        originalFilePath = decodeURIComponent(match[1]);
      }
    }
    
    // Try to get the original file from Storage, or use the URL directly
    let url1080 = originalVideoUrl;
    try {
      const originalFile = bucket.file(originalFilePath);
      const exists = await originalFile.exists();
      if (exists[0]) {
        url1080 = await getPublicUrl(originalFile);
      }
    } catch (err) {
      console.log('⚠️ Could not get original file from Storage, using provided URL');
    }
    
    const [url720, url480] = await Promise.all([
      uploadVariant(bucket, userId, videoId, temp720Path, '720p'),
      uploadVariant(bucket, userId, videoId, temp480Path, '480p'),
    ]);
    
    console.log(`✅ Uploads complete. URLs: 1080p=${!!url1080}, 720p=${!!url720}, 480p=${!!url480}`);
    
    // Update Firestore with video URLs and status=ready (app feed queries status in ['published','ready'])
    console.log('💾 Updating Firestore...');
    await videoRef.set({
      mp4_1080_url: url1080,
      mp4_720_url: url720,
      mp4_480_url: url480,
      videoUrl: url720, // Default to 720p for backward compatibility
      videoURL: url720, // Alternative field name
      transcodingStatus: 'completed',
      transcodedAt: FieldValue.serverTimestamp(),
      backfillCompletedAt: FieldValue.serverTimestamp(),
      status: 'ready', // So app feed (whereIn status ready/published) shows video
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    
    console.log(`✅ Successfully backfilled video ${videoId}`);
    
    // Cleanup temp files
    cleanupFiles([tempFilePath, temp720Path, temp480Path]);
  } catch (error) {
    console.error(`❌ Error backfilling video ${videoId}:`, error);
    console.error('Stack trace:', error.stack);
    
    // Update Firestore with error status
    try {
      await db.collection('videos').doc(videoId).set({
        transcodingStatus: 'failed',
        transcodingError: error.message,
        backfillErrorAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    } catch (firestoreError) {
      console.error('Failed to update Firestore with error:', firestoreError);
    }
    
    // Cleanup temp files
    cleanupFiles([tempFilePath, temp720Path, temp480Path]);
    
    // Re-throw error so caller can track it
    throw error;
  }
}

    // Make existing transcoded video files public
    exports.makeVideoFilesPublic = functions
      .runWith({
        timeoutSeconds: 540,
        memory: '1GB',
      })
      .https.onRequest(async (req, res) => {
        const storageClient = new Storage();
        const bucket = storageClient.bucket('streamerstip-6cfdb.firebasestorage.app');
        
        try {
          console.log('🔍 Finding all 720p and 480p video files...');
          
          const [files720] = await bucket.getFiles({
            prefix: 'videos/',
            matchGlob: '**/*_720p.mp4',
          });
          
          const [files480] = await bucket.getFiles({
            prefix: 'videos/',
            matchGlob: '**/*_480p.mp4',
          });
          
          const allFiles = [...files720, ...files480];
          console.log(`📊 Found ${allFiles.length} files to make public (720p: ${files720.length}, 480p: ${files480.length})`);
          
          let succeeded = 0;
          let failed = 0;
          const errors = [];
          
          // Process files in batches to avoid overwhelming the system
          const batchSize = 10;
          for (let i = 0; i < allFiles.length; i += batchSize) {
            const batch = allFiles.slice(i, i + batchSize);
            await Promise.all(batch.map(async (file) => {
              try {
                await file.makePublic();
                succeeded++;
                if (succeeded % 10 === 0) {
                  console.log(`✅ Made ${succeeded} files public...`);
                }
              } catch (error) {
                failed++;
                errors.push({
                  file: file.name,
                  error: error.message,
                });
                console.error(`❌ Failed to make ${file.name} public:`, error.message);
              }
            }));
          }
          
          console.log(`✅ Completed! Made ${succeeded} files public, ${failed} failed`);
          
          return res.status(200).json({
            success: true,
            summary: {
              total: allFiles.length,
              succeeded: succeeded,
              failed: failed,
            },
            errors: errors.slice(0, 50), // Limit errors in response
            message: `Made ${succeeded} out of ${allFiles.length} files public.`,
          });
        } catch (error) {
          console.error('❌ Error making files public:', error);
          return res.status(500).json({
            success: false,
            error: error.message,
            message: 'Failed to make files public.',
          });
        }
      });

    // ============================================================================
    // USER PROFILE HELPERS
    // ============================================================================

/**
 * Generate a unique username by checking the usernames collection.
 * Falls back to the user's uid prefix if display name/email are missing.
 */
async function generateUniqueUsername(base, uid) {
  let sanitizedBase = (base || '')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '')
    .substring(0, 20);

  if (!sanitizedBase) {
    sanitizedBase = `user${uid.substring(0, 6)}`;
  }

  let username = sanitizedBase;
  let counter = 1;

  for (;;) {
    const usernameDoc = await firestore.collection('usernames').doc(username).get();
    if (!usernameDoc.exists) {
      return username;
    }
    username = `${sanitizedBase}${counter}`;
    counter += 1;
  }
}

/**
 * Ensure a Firestore user profile exists for the given auth user.
 */
async function ensureUserProfile(userRecord) {
  const uid = userRecord.uid;
  const userRef = firestore.collection('users').doc(uid);
  const existingUser = await userRef.get();

  if (existingUser.exists) {
    console.log(`ℹ️ User document already exists for ${uid}`);
    return;
  }

  const baseName =
    userRecord.displayName ||
    (userRecord.email ? userRecord.email.split('@')[0] : '') ||
    `user${uid.substring(0, 6)}`;

  const username = await generateUniqueUsername(baseName, uid);
  const displayName = userRecord.displayName || baseName || 'Streamer';

  const profileData = {
    id: uid,
    uid,
    email: userRecord.email || null,
    displayName,
    username,
    avatarURL: userRecord.photoURL || null,
    bio: '',
    hashtags: [],
    onlineStatus: 'offline',
    postCount: 0,
    followerCount: 0,
    followingCount: 0,
    isActive: true,
    isVerified: false,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };

  await userRef.set(profileData);

  await firestore
    .collection('usernames')
    .doc(username)
    .set({
      uid,
      username,
      displayName,
      createdAt: FieldValue.serverTimestamp(),
    });

  console.log(`✅ Created Firestore user profile for ${uid}`);
}

// ============================================================================
// AUTH TRIGGERS
// ============================================================================

exports.onAuthUserCreate = functions.auth.user().onCreate(async (user) => {
  try {
    console.log(`👤 Auth user created: ${user.uid}`);
    await ensureUserProfile(user);
  } catch (error) {
    console.error(`❌ Failed to create Firestore profile for ${user.uid}:`, error);
  }
});

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
  .onDelete(async (snap, _context) => {
    const data = snap.data();
    const taskId = data.scheduledTaskId;
    
    if (taskId) {
      await cancelNotificationTask(taskId);
      console.log(`Cancelled notification task ${taskId}`);
    }
    
    return null;
  });

// Cloud Function to send the actual notification
async function sendEventNotificationData(data) {
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
}

exports.sendEventNotification = functions.https.onCall(
  async (data, _context) => sendEventNotificationData(data),
);

// Helper function to schedule a notification task
async function scheduleNotificationTask({ uid, eventId, runAt, title, creatorId }) {
  // This would integrate with Cloud Tasks or a similar scheduling service
  // For now, we'll use a simple setTimeout approach (not recommended for production)
  
  const delay = runAt.getTime() - Date.now();
  
  if (delay <= 0) {
    // Event is in the past, send immediately
    return await sendEventNotificationData({ uid, eventId, title, creatorId });
  }
  
  // Schedule for later
  setTimeout(async () => {
    try {
      await sendEventNotificationData({ uid, eventId, title, creatorId });
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
const COUNTABLE_STATUSES = ['ready', 'published', 'active'];
const EXCLUDED_STATUSES = ['draft', 'scheduled', 'processing', 'failed', 'archived', 'deleted', 'hidden', 'moderation', 'private'];
const COUNTABLE_PRIVACY_LEVELS = ['everyone', 'connections', 'public', 'followers'];

function shouldCountPost(status, privacy, data = {}) {
  if (data.deleted === true || data.isDeleted === true || data.visible === false) {
    return false;
  }
  const statusLower = status ? String(status).toLowerCase() : 'draft';
  const privacyLower = privacy ? String(privacy).toLowerCase() : 'private';
  
  return COUNTABLE_STATUSES.includes(statusLower) && 
         !EXCLUDED_STATUSES.includes(statusLower) &&
         COUNTABLE_PRIVACY_LEVELS.includes(privacyLower);
}

function postCountUpdate(delta) {
  return {
    postCount: admin.firestore.FieldValue.increment(delta),
    'stats.postCount': admin.firestore.FieldValue.increment(delta),
    lastPostCountUpdate: admin.firestore.FieldValue.serverTimestamp(),
  };
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
    if (shouldCountPost(status, privacy, data)) {
      try {
        await admin.firestore().collection('users').doc(userId).set(
          postCountUpdate(1),
          {merge: true},
        );
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
  .onUpdate(async (change, _context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const beforeStatus = beforeData.status || 'draft';
    const beforePrivacy = beforeData.privacy || 'private';
    const afterStatus = afterData.status || 'draft';
    const afterPrivacy = afterData.privacy || 'private';
    const beforeVisible = beforeData.visible !== false && beforeData.deleted !== true && beforeData.isDeleted !== true;
    const afterVisible = afterData.visible !== false && afterData.deleted !== true && afterData.isDeleted !== true;
    if (beforeStatus === afterStatus && beforePrivacy === afterPrivacy && beforeVisible === afterVisible) {
      return null;
    }
    const userId = afterData.userId;
    const beforeCounts = shouldCountPost(beforeStatus, beforePrivacy, beforeData);
    const afterCounts = shouldCountPost(afterStatus, afterPrivacy, afterData);
    try {
      if (beforeCounts && !afterCounts) {
        // Post was countable, now it's not - decrement
        await admin.firestore().collection('users').doc(userId).set(
          postCountUpdate(-1),
          {merge: true},
        );
        console.log(`✅ Post count decremented for user: ${userId}`);
      } else if (!beforeCounts && afterCounts) {
        // Post wasn't countable, now it is - increment
        await admin.firestore().collection('users').doc(userId).set(
          postCountUpdate(1),
          {merge: true},
        );
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
    if (shouldCountPost(status, privacy, data)) {
      try {
        await admin.firestore().collection('users').doc(userId).set(
          postCountUpdate(-1),
          {merge: true},
        );
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
          'stats.postCount': 0,
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
    
    if (shouldCountPost(status, privacy, data)) {
      actualCount++;
    }
  });
  
  // Update the counter with the actual count
  await admin.firestore().collection('users').doc(userId).update({
    postCount: actualCount,
    'stats.postCount': actualCount,
    lastPostCountReconciliation: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  console.log(`✅ Reconciled post count for user ${userId}: ${actualCount} posts`);
  return actualCount;
}

// ============================================================================
// NOTIFICATION TRIGGERS - Create notifications for likes, comments, follows
// ============================================================================

// Trigger: When a video is liked
exports.onLikeCreate = functions.firestore
  .document('likes/{videoId}/byUser/{userId}')
  .onCreate(async (snap, context) => {
    const { videoId, userId } = context.params;
    const likerId = userId;

    console.log(`👍 Like created: Video ${videoId} by user ${likerId}`);

    try {
      // Get video data to find the owner
      const videoDoc = await admin.firestore().collection('videos').doc(videoId).get();
      if (!videoDoc.exists) {
        console.log(`❌ Video ${videoId} not found`);
        return null;
      }

      const videoData = videoDoc.data();
      const videoOwnerId = videoData.userId;

      // Don't notify if user likes their own video
      if (likerId === videoOwnerId) {
        console.log(`ℹ️ User liked their own video, skipping notification`);
        return null;
      }

      // Get liker's user data
      const likerDoc = await admin.firestore().collection('users').doc(likerId).get();
      if (!likerDoc.exists) {
        console.log(`❌ Liker user ${likerId} not found`);
        return null;
      }

      const likerData = likerDoc.data();

      // Create notification
      await admin.firestore()
        .collection('notifications')
        .doc(videoOwnerId)
        .collection('items')
        .add({
          type: 'like',
          videoId: videoId,
          user: {
            id: likerId,
            displayName: likerData.displayName || 'Unknown',
            username: likerData.username || 'unknown',
            avatarUrl: likerData.avatarURL || null,
          },
          postThumbnailUrl: videoData.thumbnailUrl || null,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          status: 'delivered',
        });

      console.log(`✅ Like notification created for user ${videoOwnerId}`);
      return null;
    } catch (error) {
      console.error(`❌ Error creating like notification:`, error);
      return null;
    }
  });

// Trigger: When a comment is created
exports.onCommentCreate = functions.firestore
  .document('videos/{videoId}/comments/{commentId}')
  .onCreate(async (snap, context) => {
    const { videoId, commentId } = context.params;
    const commentData = snap.data();
    const commenterId = commentData.userId;

    console.log(`💬 Comment created: Video ${videoId} by user ${commenterId}`);

    try {
      // Get video data to find the owner
      const videoDoc = await admin.firestore().collection('videos').doc(videoId).get();
      if (!videoDoc.exists) {
        console.log(`❌ Video ${videoId} not found`);
        return null;
      }

      const videoData = videoDoc.data();
      const videoOwnerId = videoData.userId;

      // Don't notify if user comments on their own video
      if (commenterId === videoOwnerId) {
        console.log(`ℹ️ User commented on their own video, skipping notification`);
        return null;
      }

      // Get commenter's user data
      const commenterDoc = await admin.firestore().collection('users').doc(commenterId).get();
      if (!commenterDoc.exists) {
        console.log(`❌ Commenter user ${commenterId} not found`);
        return null;
      }

      const commenterData = commenterDoc.data();

      // Create notification
      await admin.firestore()
        .collection('notifications')
        .doc(videoOwnerId)
        .collection('items')
        .add({
          type: 'comment',
          videoId: videoId,
          commentId: commentId,
          commentText: commentData.text || '',
          user: {
            id: commenterId,
            displayName: commenterData.displayName || 'Unknown',
            username: commenterData.username || 'unknown',
            avatarUrl: commenterData.avatarURL || null,
          },
          postThumbnailUrl: videoData.thumbnailUrl || null,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          status: 'delivered',
        });

      console.log(`✅ Comment notification created for user ${videoOwnerId}`);
      return null;
    } catch (error) {
      console.error(`❌ Error creating comment notification:`, error);
      return null;
    }
  });

// Trigger: When a user follows another user
exports.onFollowCreate = functions.firestore
  .document('follows/{followId}')
  .onCreate(async (snap, _context) => {
    const followData = snap.data();
    const followerId = followData.followerId;
    const followedId = followData.followedId;

    console.log(`👥 Follow created: ${followerId} -> ${followedId}`);

    try {
      // Don't notify if user somehow follows themselves
      if (followerId === followedId) {
        console.log(`ℹ️ User tried to follow themselves, skipping notification`);
        return null;
      }

      // Get follower's user data
      const followerDoc = await admin.firestore().collection('users').doc(followerId).get();
      if (!followerDoc.exists) {
        console.log(`❌ Follower user ${followerId} not found`);
        return null;
      }

      const followerData = followerDoc.data();

      // Create notification
      await admin.firestore()
        .collection('notifications')
        .doc(followedId)
        .collection('items')
        .add({
          type: 'follow',
          user: {
            id: followerId,
            displayName: followerData.displayName || 'Unknown',
            username: followerData.username || 'unknown',
            avatarUrl: followerData.avatarURL || null,
          },
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          status: 'delivered',
        });

      console.log(`✅ Follow notification created for user ${followedId}`);
      safeEmitTelemetry('follow_create', {
        followerId,
        followedId,
      });
      return null;
    } catch (error) {
      console.error(`❌ Error creating follow notification:`, error);
      safeEmitTelemetry('follow_error', {
        followerId,
        followedId,
        error: error.message,
      });
      return null;
    }
  });

// ============================================================================
// CROSS-PLATFORM SYNC - Keep mobile app and website in sync
// ============================================================================

// DISABLED: normalizeVideoCreatorFields - client sends userId, creatorId, creator_id
// Saves Cloud Run invocations on every video write.
// exports.normalizeVideoCreatorFields = ...

/**
 * Sync creator profile data to video documents for faster reads
 * Updates all videos when a user's profile changes
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
    
    // Update all videos by this creator (support all field variants)
    const videosQuery = admin.firestore()
      .collection('videos')
      .where('userId', '==', userId);
    
    const snapshot = await videosQuery.get();
    
    if (snapshot.empty) {
      console.log(`ℹ️ No videos found for user ${userId}`);
      return null;
    }
    
    // Batch update all videos (max 500 per batch)
    const batches = [];
    let currentBatch = admin.firestore().batch();
    let operationsInBatch = 0;
    const MAX_BATCH_SIZE = 500;
    
    snapshot.docs.forEach((doc) => {
      currentBatch.update(doc.ref, {
        creatorName: after.displayName,
        creatorUsername: after.username,
        creatorAvatar: after.avatarURL,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      operationsInBatch++;
      
      if (operationsInBatch >= MAX_BATCH_SIZE) {
        batches.push(currentBatch);
        currentBatch = admin.firestore().batch();
        operationsInBatch = 0;
      }
    });
    
    // Add remaining operations
    if (operationsInBatch > 0) {
      batches.push(currentBatch);
    }
    
    // Commit all batches
    try {
      await Promise.all(batches.map(batch => batch.commit()));
      console.log(`✅ Updated ${snapshot.docs.length} videos for user ${userId} in ${batches.length} batch(es)`);
    } catch (error) {
      console.error(`❌ Error updating videos: ${error}`);
    }
    
    return null;
  });

// ============================================================================
// CHAT MESSAGE NOTIFICATIONS - Unread counts and push notifications
// ============================================================================

/**
 * Automatically increment unread counts when messages are created
 * Works for both Flutter app and website
 */
exports.onMessageCreate = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    try {
      const messageData = snap.data();
      const chatId = context.params.chatId;
      const messageId = context.params.messageId;
      
      // Support both 'from' and 'senderId' fields
      const senderId = messageData.from || messageData.senderId;
      
      if (!senderId) {
        console.error(`❌ Message ${messageId} has no sender ID`);
        return null;
      }
      
      console.log(`📱 New message created: ${messageId} in chat: ${chatId} from ${senderId}`);
      
      // Get the chat document to find participants
      const chatRef = admin.firestore().doc(`chats/${chatId}`);
      const chatDoc = await chatRef.get();
      
      if (!chatDoc.exists) {
        console.error(`❌ Chat document ${chatId} does not exist`);
        return null;
      }
      
      const chatData = chatDoc.data();
      const participants = chatData.participants || [];
      
      // Find the recipient (the other participant)
      const recipientId = participants.find(id => id !== senderId);
      
      if (!recipientId) {
        console.error(`❌ No recipient found for message from ${senderId}`);
        return null;
      }
      
      console.log(`📱 Incrementing unread count for recipient: ${recipientId}`);
      
      // Update chat document with incremented unread count and last message info
      const updateData = {
        [`unreadCount_${recipientId}`]: admin.firestore.FieldValue.increment(1),
        lastMessage: messageData.text || messageData.gifUrl || 'New message',
        lastTimestamp: admin.firestore.FieldValue.serverTimestamp()
      };
      
      await chatRef.update(updateData);
      
      console.log(`✅ Unread count incremented for ${recipientId} in chat ${chatId}`);
      
      // Send push notification to the recipient
      await sendMessagePushNotification(recipientId, senderId, messageData, chatId);
      
      return null;
    } catch (error) {
      console.error('❌ Error in onMessageCreate:', error);
      return null;
    }
  });

/**
 * Send push notification for new message
 */
async function sendMessagePushNotification(recipientId, senderId, messageData, chatId) {
  try {
    // Get recipient's FCM tokens from deviceTokens subcollection
    const tokensSnapshot = await admin.firestore()
      .collection('users')
      .doc(recipientId)
      .collection('deviceTokens')
      .get();
    
    if (tokensSnapshot.empty) {
      console.log(`📱 No FCM tokens found for user ${recipientId}`);
      return;
    }
    
    const tokens = tokensSnapshot.docs.map(doc => doc.id);
    
    // Get sender's display name
    const senderDoc = await admin.firestore().doc(`users/${senderId}`).get();
    const senderData = senderDoc.exists ? senderDoc.data() : {};
    const senderName = senderData.displayName || senderData.username || 'Someone';
    
    // Get message text
    const messageText = messageData.text || (messageData.gifUrl ? 'Sent a GIF' : 'Sent a message');
    const truncatedText = messageText.length > 100 ? messageText.substring(0, 100) + '...' : messageText;
    
    // Create notification payload
    const message = {
      notification: {
        title: `New message from ${senderName}`,
        body: truncatedText,
      },
      data: {
        type: 'chat',
        chatId: chatId,
        senderId: senderId,
        recipientId: recipientId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      tokens: tokens,
    };
    
    // Send push notification to each token individually
    try {
      let successCount = 0;
      const failedTokens = [];
      
      for (const token of tokens) {
        try {
          await admin.messaging().send({
            notification: message.notification,
            data: message.data,
            token: token,
            android: {
              priority: 'high',
            },
            apns: {
              payload: {
                aps: {
                  badge: 1,
                  sound: 'default',
                }
              }
            }
          });
          successCount++;
        } catch (tokenError) {
          console.log(`❌ Failed to send to token (will remove): ${tokenError.code}`);
          failedTokens.push(token);
        }
      }
      
      console.log(`✅ Push notification sent to ${successCount}/${tokens.length} devices for user ${recipientId}`);
      
      // Remove invalid tokens
      if (failedTokens.length > 0) {
        const batch = admin.firestore().batch();
        failedTokens.forEach(token => {
          batch.delete(admin.firestore()
            .collection('users')
            .doc(recipientId)
            .collection('deviceTokens')
            .doc(token));
        });
        await batch.commit();
        
        console.log(`🧹 Removed ${failedTokens.length} invalid tokens`);
      }
    } catch (error) {
      console.error('❌ Error sending push notification:', error);
    }
  } catch (error) {
    console.error('❌ Error in sendMessagePushNotification:', error);
  }
}

/**
 * Send notification when someone replies to a comment
 */
exports.onCommentReply = functions.firestore
  .document('videos/{videoId}/comments/{commentId}')
  .onCreate(async (snap, context) => {
    try {
      const commentData = snap.data();
      const { videoId, commentId } = context.params;
      const parentCommentId = commentData.parentCommentId;
      
      // Only proceed if this is a reply (has parentCommentId)
      if (!parentCommentId) {
        console.log(`📝 New comment (not a reply), skipping reply notification`);
        return null;
      }
      
      console.log(`📝 Comment reply detected: ${commentId} replying to ${parentCommentId}`);
      
      // Get parent comment to find the original commenter
      const parentCommentRef = admin.firestore()
        .doc(`videos/${videoId}/comments/${parentCommentId}`);
      const parentComment = await parentCommentRef.get();
      
      if (!parentComment.exists) {
        console.log(`❌ Parent comment not found: ${parentCommentId}`);
        return null;
      }
      
      const parentCommentData = parentComment.data();
      const parentAuthorId = parentCommentData.user?.id;
      const replierId = commentData.user?.id;
      
      // Don't notify if replying to own comment
      if (parentAuthorId === replierId) {
        console.log(`📝 User replying to own comment, skipping notification`);
        return null;
      }
      
      // Get replier user data
      const replierDoc = await admin.firestore()
        .collection('users')
        .doc(replierId)
        .get();
      
      if (!replierDoc.exists) {
        console.log(`❌ Replier user not found: ${replierId}`);
        return null;
      }
      
      const replierData = replierDoc.data();
      
      // Get video data for thumbnail
      const videoDoc = await admin.firestore()
        .collection('videos')
        .doc(videoId)
        .get();
      
      const videoData = videoDoc.exists ? videoDoc.data() : {};
      
      // Create notification for parent comment author
      await admin.firestore()
        .collection('notifications')
        .doc(parentAuthorId)
        .collection('items')
        .add({
          type: 'commentReply',
          user: {
            id: replierId,
            username: replierData.username || 'Unknown',
            displayName: replierData.displayName || 'Unknown',
            avatarURL: replierData.avatarURL || replierData.avatarUrl || ''
          },
          videoId: videoId,
          commentText: commentData.text || '',
          parentCommentId: parentCommentId,
          postThumbnailUrl: videoData.thumbnailURL || videoData.thumbnailUrl || '',
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
          status: 'delivered'
        });
      
      console.log(`✅ Comment reply notification created: ${replierId} -> ${parentAuthorId}`);
      
      // Send push notification
      const tokens = await getDeviceTokens(parentAuthorId);
      if (tokens.length > 0) {
        const message = {
          notification: {
            title: 'New Reply',
            body: `${replierData.displayName || 'Someone'} replied to your comment`
          },
          data: {
            type: 'commentReply',
            replierId: replierId,
            videoId: videoId,
            commentId: commentId,
            parentCommentId: parentCommentId
          }
        };
        
        await sendToTokens(tokens, message, parentAuthorId);
      }
      
      return null;
    } catch (error) {
      console.error('❌ Error in onCommentReply:', error);
      return null;
    }
  });

async function getDeviceTokens(uid) {
  const tokensSnapshot = await admin.firestore()
    .collection('users')
    .doc(uid)
    .collection('deviceTokens')
    .get();
  return tokensSnapshot.docs.map((doc) => doc.id).filter(Boolean);
}

async function sendToTokens(tokens, message, uid) {
  if (!tokens || tokens.length === 0) {
    return {successCount: 0, failureCount: 0};
  }
  const response = await admin.messaging().sendMulticast({
    ...message,
    tokens,
  });
  if (response.failureCount > 0) {
    console.warn(
      `Push notification had ${response.failureCount} failures for ${uid}`,
    );
  }
  return response;
}

/**
 * Send notifications to followers when a new video is published
 */
exports.onVideoPublish = functions.firestore
  .document('videos/{videoId}')
  .onCreate(async (snap, context) => {
    let videoId = context.params.videoId;
    let creatorId = null;
    try {
      const videoData = snap.data();
      creatorId = videoData.userId || videoData.creatorId;
      
      console.log(`📹 New video published: ${videoId} by ${creatorId}`);
      
      // Only notify for published videos, not drafts
      if (videoData.status === 'draft' || videoData.isDraft === true) {
        console.log(`📹 Video is a draft, skipping follower notifications`);
      safeEmitTelemetry('video_publish_skipped', {
        videoId,
        creatorId,
        reason: 'draft',
      });
        return null;
      }
      
      // Get creator data
      const creatorDoc = await admin.firestore()
        .collection('users')
        .doc(creatorId)
        .get();
      
      if (!creatorDoc.exists) {
        console.log(`❌ Creator not found: ${creatorId}`);
        return null;
      }
      
      const creatorData = creatorDoc.data();
      
      // Get all followers
      const followersSnapshot = await admin.firestore()
        .collection('relationships')
        .where('followingId', '==', creatorId)
        .get();
      
      if (followersSnapshot.empty) {
        console.log(`📹 No followers to notify for ${creatorId}`);
      safeEmitTelemetry('video_publish_no_followers', {videoId, creatorId});
        return null;
      }
      
      console.log(`📹 Notifying ${followersSnapshot.size} followers`);
      
      // Create notifications in batches
      const batch = admin.firestore().batch();
      let notificationCount = 0;
      
      for (const doc of followersSnapshot.docs) {
        const followerId = doc.data().followerId;
        
        // Create notification
        const notifRef = admin.firestore()
          .collection('notifications')
          .doc(followerId)
          .collection('items')
          .doc();
        
        batch.set(notifRef, {
          type: 'newVideo',
          user: {
            id: creatorId,
            username: creatorData.username || 'Unknown',
            displayName: creatorData.displayName || 'Unknown',
            avatarURL: creatorData.avatarURL || creatorData.avatarUrl || ''
          },
          videoId: videoId,
          postThumbnailUrl: videoData.thumbnailURL || videoData.thumbnailUrl || '',
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
          status: 'delivered'
        });
        
        notificationCount++;
        
        // Commit batch every 500 writes (Firestore limit)
        if (notificationCount % 500 === 0) {
          await batch.commit();
        }
      }
      
      // Commit remaining writes
      if (notificationCount % 500 !== 0) {
        await batch.commit();
      }
      
      console.log(`✅ Created ${notificationCount} new video notifications`);
    safeEmitTelemetry('video_publish', {
      videoId,
      creatorId,
      followerCount: followersSnapshot.size,
      notified: notificationCount,
    });
      
      return null;
    } catch (error) {
      console.error('❌ Error in onVideoPublish:', error);
    safeEmitTelemetry('video_publish_error', {
      videoId,
      creatorId,
      error: error.message,
    });
      return null;
    }
  });

// DISABLED: onVideoMilestone - saves Cloud Run invocations on every video update.
// Milestone push notifications (100/1K/10K views) no longer sent.
// exports.onVideoMilestone = ...

/**
 * Send notifications when a calendar event (live stream) starts
 */
exports.onCalendarEventStart = functions.firestore
  .document('users/{userId}/bookmarks/{eventId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      const { userId, eventId } = context.params;
      
      // Check if event just started (status changed to 'live')
      if (before.status !== 'live' && after.status === 'live') {
        console.log(`🔴 Live stream started: ${eventId} by ${userId}`);
        
        // Get streamer data
        const streamerDoc = await admin.firestore()
          .collection('users')
          .doc(userId)
          .get();
        
        if (!streamerDoc.exists) {
          console.log(`❌ Streamer not found: ${userId}`);
          return null;
        }
        
        const streamerData = streamerDoc.data();
        
        // Get all followers
        const followersSnapshot = await admin.firestore()
          .collection('relationships')
          .where('followingId', '==', userId)
          .get();
        
        if (followersSnapshot.empty) {
          console.log(`🔴 No followers to notify for ${userId}`);
          return null;
        }
        
        console.log(`🔴 Notifying ${followersSnapshot.size} followers about live stream`);
        
        // Create notifications in batches
        const batch = admin.firestore().batch();
        let notificationCount = 0;
        
        for (const doc of followersSnapshot.docs) {
          const followerId = doc.data().followerId;
          
          // Create notification
          const notifRef = admin.firestore()
            .collection('notifications')
            .doc(followerId)
            .collection('items')
            .doc();
          
          batch.set(notifRef, {
            type: 'liveStream',
            user: {
              id: userId,
              username: streamerData.username || 'Unknown',
              displayName: streamerData.displayName || 'Unknown',
              avatarURL: streamerData.avatarURL || streamerData.avatarUrl || ''
            },
            commentText: after.title || 'is live now!',
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            isRead: false,
            status: 'delivered'
          });
          
          notificationCount++;
          
          // Commit batch every 500 writes
          if (notificationCount % 500 === 0) {
            await batch.commit();
          }
        }
        
        // Commit remaining writes
        if (notificationCount % 500 !== 0) {
          await batch.commit();
        }
        
        console.log(`✅ Created ${notificationCount} live stream notifications`);
      }
      
      return null;
    } catch (error) {
      console.error('❌ Error in onCalendarEventStart:', error);
      return null;
    }
  });

// Helper function to format numbers
function _formatNumber(num) {
  if (num >= 1000000) {
    return `${(num / 1000000).toFixed(1)}M`;
  } else if (num >= 1000) {
    return `${(num / 1000).toFixed(1)}K`;
  }
  return num.toString();
}

// =============================================================================
// Re-implemented functions (were deployed from another codebase)
// =============================================================================

const region = 'us-central1';
const crypto = require('crypto');
const { createDirectUpload, handleMuxWebhook } = require('./src/mux');
const {handleGamificationEvents} = require('./src/gamification/gamification_events_http');
const {handleProgressionCallable} = require('./src/gamification/progression_callable');
const {
  handleDeleteVideo,
  handleDeleteVideos,
} = require('./src/videos/delete_video_callable');
const {cleanupStuckUploads} = require('./src/videos/cleanup_stuck_uploads');
const {runProgressionNotificationSweep} = require('./src/gamification/progression_notifications');
const {handleVerifyMobilePurchase} = require('./src/billing/verify_mobile_purchase');
const {
  handleTippyRequest,
  handleTippyUsageReport,
} = require('./src/tippy/tippy_http');

/** Bind in prod: `firebase functions:secrets:set ANTHROPIC_API_KEY` */
const tippyAnthropicSecret = defineSecret('ANTHROPIC_API_KEY');
const {handleMeEntitlements} = require('./src/me/me_entitlements_http');

/** Optional fallback only — prefer Cloudflare Worker `POST /gamification/events` (same contract). */
exports.gamificationEvents = onRequest({region, cors: true}, handleGamificationEvents);

/** Admin SDK-owned progression sync. Clients can request, but cannot write XP/rank/task state. */
exports.progressionSync = onCall({region}, handleProgressionCallable);

/** Soft-delete videos + purge feed/index mirrors (owner or admin). */
exports.deleteVideo = onCall({region}, handleDeleteVideo);
exports.deleteVideos = onCall({region}, handleDeleteVideos);

/** Mark uploading/pending/processing videos stuck >2h as failed. */
exports.cleanupStuckUploads = cleanupStuckUploads;

exports.progressionNotificationSweep = onSchedule(
  {region, schedule: 'every 60 minutes', timeZone: 'UTC'},
  async () => runProgressionNotificationSweep(),
);

/** Mobile IAP: Flutter posts receipt/token; verifies Apple / Play; writes Firestore. */
exports.verifyMobilePurchase = onRequest(
    {region, cors: true},
    handleVerifyMobilePurchase,
);

exports.tippyApi = onRequest(
    {region, cors: true, secrets: [tippyAnthropicSecret]},
    handleTippyRequest,
);

exports.meEntitlements = onRequest(
    {region, cors: true},
    handleMeEntitlements,
);

exports.tippyUsageReport = onRequest(
    {region, cors: true},
    handleTippyUsageReport,
);

exports.createMuxDirectUpload = onCall({ region }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Must be logged in');
  const { videoId, userId } = request.data || {};
  if (!videoId || !userId) throw new HttpsError('invalid-argument', 'videoId and userId required');
  if (request.auth.uid !== userId) throw new HttpsError('permission-denied', 'userId mismatch');
  const result = await createDirectUpload(videoId, userId);
  return result;
});

exports.muxWebhook = onRequest({ region }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return;
  }
  try {
    const payload = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : (req.body || {});
    await handleMuxWebhook(payload);
    res.status(200).send('OK');
  } catch (e) {
    console.error('Mux webhook error:', e);
    res.status(500).send('Webhook processing failed');
  }
});

exports.apiCsrfToken = onRequest({region}, (req, res) => {
  if (req.method !== 'GET' && req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }
  const token = crypto.randomBytes(32).toString('hex');
  const expiresIn = 3600;
  res.set('Cache-Control', 'no-store');
  res.status(200).json({ token, expiresIn });
});

exports.apiReports = onRequest({region}, async (req, res) => {
  try {
    if (req.method === 'GET') {
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }
      const idToken = authHeader.split('Bearer ')[1];
      await admin.auth().verifyIdToken(idToken);
      const snapshot = await firestore.collection('reports').orderBy('timestamp', 'desc').limit(50).get();
      const reports = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      res.status(200).json({ reports });
      return;
    }
    if (req.method === 'POST') {
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }
      const idToken = authHeader.split('Bearer ')[1];
      const decoded = await admin.auth().verifyIdToken(idToken);
      const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : (req.body || {});
      const { videoId, userId: reportedUserId, reason, type } = body;
      const collection = type === 'user_report' ? 'user_reports' : 'reports';
      const doc = type === 'user_report'
        ? { reporterId: decoded.uid, reportedUserId, reason, timestamp: FieldValue.serverTimestamp(), status: 'pending' }
        : { videoId, reporterId: decoded.uid, reason, timestamp: FieldValue.serverTimestamp(), status: 'pending' };
      const ref = await firestore.collection(collection).add(doc);
      res.status(200).json({ ok: true, id: ref.id });
      return;
    }
    res.status(405).json({ error: 'Method not allowed' });
  } catch (e) {
    console.error('apiReports error:', e);
    res.status(500).json({ error: e.message || 'Internal error' });
  }
});

exports.apiVideoUpload = onRequest({region}, async (req, res) => {
  try {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const decoded = await admin.auth().verifyIdToken(authHeader.split('Bearer ')[1]);
    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : (req.body || {});
    const { videoId, contentType } = body;
    if (!videoId) {
      res.status(400).json({ error: 'videoId required' });
      return;
    }
    const bucket = storage.bucket();
    const path = `videos/${decoded.uid}/${videoId}.mp4`;
    const file = bucket.file(path);
    const [url] = await file.getSignedUrl({
      action: 'write',
      expires: Date.now() + 60 * 60 * 1000,
      contentType: contentType || 'video/mp4',
    });
    res.status(200).json({ uploadUrl: url, path });
  } catch (e) {
    console.error('apiVideoUpload error:', e);
    res.status(500).json({ error: e.message || 'Internal error' });
  }
});

exports.apiGoogleSecurityEvents = functions.region(region).https.onRequest(async (req, res) => {
  try {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }
    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : (req.body || {});
    await firestore.collection('security_events').add({
      ...body,
      receivedAt: FieldValue.serverTimestamp(),
    });
    res.status(200).json({ ok: true });
  } catch (e) {
    console.error('apiGoogleSecurityEvents error:', e);
    res.status(500).json({ error: e.message || 'Internal error' });
  }
});

function buildOAuthRedirect(provider, baseUrl) {
  const config = process.env[`${provider.toUpperCase()}_CLIENT_ID`] || functions.config()[provider]?.client_id;
  if (!config) return null;
  const scopes = provider === 'kick' ? 'user:read' : provider === 'twitch' ? 'user:read:email' : 'https://www.googleapis.com/auth/youtube.readonly';
  const authUrl = provider === 'kick' ? `https://kick.com/oauth/authorize` : provider === 'twitch' ? 'https://id.twitch.tv/oauth2/authorize' : 'https://accounts.google.com/o/oauth2/v2/auth';
  const params = new URLSearchParams({
    client_id: config,
    redirect_uri: `${baseUrl}/api${provider.charAt(0).toUpperCase() + provider.slice(1)}AuthCallback`,
    response_type: 'code',
    scope: scopes,
  });
  return `${authUrl}?${params.toString()}`;
}

function encodeOAuthState(payload) {
  return Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
}

function decodeOAuthState(rawState) {
  try {
    if (!rawState) return {};
    return JSON.parse(Buffer.from(String(rawState), 'base64url').toString('utf8'));
  } catch (_) {
    return {};
  }
}

function resolveBaseUrl(req) {
  return req.headers.origin || req.protocol + '://' + req.get('host') || '';
}

function sanitizeReturnUrl(returnUrl, baseUrl) {
  if (typeof returnUrl !== 'string' || returnUrl.trim() === '') {
    return baseUrl;
  }
  try {
    const candidate = new URL(returnUrl, baseUrl);
    const allowed = new URL(baseUrl);
    if (candidate.origin !== allowed.origin) {
      return baseUrl;
    }
    return candidate.toString();
  } catch (_) {
    return baseUrl;
  }
}

async function fetchYoutubeChannelProfile(accessToken) {
  const fetch = (await import('node-fetch')).default;
  const res = await fetch(
    'https://www.googleapis.com/youtube/v3/channels?part=snippet,statistics&mine=true',
    {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    }
  );
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(data.error?.message || 'Failed to fetch YouTube channel');
  }
  return data.items?.[0] || null;
}

async function persistYoutubeConnection({uid, tokenData, channel}) {
  if (!uid) return;

  const channelId = channel?.id || '';
  const snippet = channel?.snippet || {};
  const stats = channel?.statistics || {};
  const displayName = snippet.title || 'YouTube';
  const username =
    snippet.customUrl ||
    channelId ||
    'connected';
  const url = channelId ? `https://www.youtube.com/channel/${channelId}` : null;
  const expiresAt = tokenData.expires_in
    ? new Date(Date.now() + Number(tokenData.expires_in) * 1000)
    : null;

  await firestore
    .collection('users')
    .doc(uid)
    .collection('platform_auth')
    .doc('youtube')
    .set({
      provider: 'youtube',
      channelId,
      channelTitle: displayName,
      accessToken: tokenData.access_token || null,
      refreshToken: tokenData.refresh_token || null,
      scope: tokenData.scope || null,
      tokenType: tokenData.token_type || 'Bearer',
      expiresAt: expiresAt || null,
      updatedAt: FieldValue.serverTimestamp(),
      connectedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

  const userRef = firestore.collection('users').doc(uid);
  const userSnap = await userRef.get();
  const currentPlatforms = Array.isArray(userSnap.data()?.platforms)
    ? [...userSnap.data().platforms]
    : [];
  const nextPlatforms = currentPlatforms.filter((platform) => {
    const type = String(platform?.type || '').toLowerCase();
    return type !== 'youtube';
  });
  nextPlatforms.push({
    id: channelId || 'youtube_connected',
    type: 'youtube',
    username,
    followers: Number(stats.subscriberCount || 0),
    url,
  });
  await userRef.set({
    platforms: nextPlatforms,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
}

exports.apiKickAuthStart = functions.region(region).https.onRequest((req, res) => {
  const baseUrl = req.headers.origin || req.protocol + '://' + req.get('host') || '';
  const url = buildOAuthRedirect('kick', baseUrl);
  if (!url) {
    res.status(503).json({ error: 'Kick OAuth not configured' });
    return;
  }
  res.redirect(url);
});

exports.apiKickAuthCallback = functions.region(region).https.onRequest(async (req, res) => {
  const code = req.query.code;
  if (!code) {
    res.status(400).send('Missing code');
    return;
  }
  const baseUrl = req.headers.origin || req.protocol + '://' + req.get('host') || '';
  const redirectUri = `${baseUrl}/apiKickAuthCallback`;
  const clientId = process.env.KICK_CLIENT_ID || functions.config().kick?.client_id;
  const clientSecret = process.env.KICK_CLIENT_SECRET || functions.config().kick?.client_secret;
  if (!clientId || !clientSecret) {
    res.status(503).send('Kick OAuth not configured');
    return;
  }
  try {
    const fetch = (await import('node-fetch')).default;
    const tokenRes = await fetch('https://kick.com/api/v2/oauth/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ client_id: clientId, client_secret: clientSecret, code, grant_type: 'authorization_code', redirect_uri: redirectUri }),
    });
    const tokenData = await tokenRes.json();
    res.redirect(`${baseUrl}?kick_connected=1&access_token=${encodeURIComponent(tokenData.access_token || '')}`);
  } catch (e) {
    console.error('Kick callback error:', e);
    res.status(500).send('OAuth failed');
  }
});

exports.apiKickValidate = functions.region(region).https.onRequest(async (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    res.status(401).json({ valid: false });
    return;
  }
  try {
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : authHeader;
    const fetch = (await import('node-fetch')).default;
    const r = await fetch('https://kick.com/api/v2/user', { headers: { Authorization: `Bearer ${token}` } });
    res.status(200).json({ valid: r.ok });
  } catch (e) {
    res.status(200).json({ valid: false });
  }
});

exports.apiTwitchAuthStart = functions.region(region).https.onRequest((req, res) => {
  const baseUrl = req.headers.origin || req.protocol + '://' + req.get('host') || '';
  const clientId = process.env.TWITCH_CLIENT_ID || functions.config().twitch?.client_id;
  if (!clientId) {
    res.status(503).json({ error: 'Twitch OAuth not configured' });
    return;
  }
  const url = `https://id.twitch.tv/oauth2/authorize?client_id=${clientId}&redirect_uri=${encodeURIComponent(baseUrl + '/apiTwitchAuthCallback')}&response_type=code&scope=user:read:email`;
  res.redirect(url);
});

exports.apiTwitchAuthCallback = functions.region(region).https.onRequest(async (req, res) => {
  const code = req.query.code;
  if (!code) {
    res.status(400).send('Missing code');
    return;
  }
  const baseUrl = req.headers.origin || req.protocol + '://' + req.get('host') || '';
  const redirectUri = baseUrl + '/apiTwitchAuthCallback';
  const clientId = process.env.TWITCH_CLIENT_ID || functions.config().twitch?.client_id;
  const clientSecret = process.env.TWITCH_CLIENT_SECRET || functions.config().twitch?.client_secret;
  if (!clientId || !clientSecret) {
    res.status(503).send('Twitch OAuth not configured');
    return;
  }
  try {
    const fetch = (await import('node-fetch')).default;
    const tokenRes = await fetch('https://id.twitch.tv/oauth2/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ client_id: clientId, client_secret: clientSecret, code, grant_type: 'authorization_code', redirect_uri: redirectUri }),
    });
    const tokenData = await tokenRes.json();
    res.redirect(`${baseUrl}?twitch_connected=1&access_token=${encodeURIComponent(tokenData.access_token || '')}`);
  } catch (e) {
    console.error('Twitch callback error:', e);
    res.status(500).send('OAuth failed');
  }
});

exports.apiYoutubeAuthStart = functions.region(region).https.onRequest((req, res) => {
  const baseUrl = resolveBaseUrl(req);
  const clientId = process.env.YOUTUBE_CLIENT_ID || functions.config().youtube?.client_id;
  if (!clientId) {
    res.status(503).json({ error: 'YouTube OAuth not configured' });
    return;
  }
  const state = encodeOAuthState({
    uid: typeof req.query.uid === 'string' ? req.query.uid : '',
    returnUrl: sanitizeReturnUrl(
      typeof req.query.returnUrl === 'string' ? req.query.returnUrl : '',
      baseUrl
    ),
  });
  const params = new URLSearchParams({
    client_id: clientId,
    redirect_uri: `${baseUrl}/apiYoutubeAuthCallback`,
    response_type: 'code',
    scope: 'https://www.googleapis.com/auth/youtube.upload',
    access_type: 'offline',
    prompt: 'consent',
    include_granted_scopes: 'true',
    state,
  });
  const url = `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`;
  res.redirect(url);
});

exports.apiYoutubeAuthCallback = functions.region(region).https.onRequest(async (req, res) => {
  const code = req.query.code;
  if (!code) {
    res.status(400).send('Missing code');
    return;
  }
  const baseUrl = resolveBaseUrl(req);
  const redirectUri = baseUrl + '/apiYoutubeAuthCallback';
  const clientId = process.env.YOUTUBE_CLIENT_ID || functions.config().youtube?.client_id;
  const clientSecret = process.env.YOUTUBE_CLIENT_SECRET || functions.config().youtube?.client_secret;
  if (!clientId || !clientSecret) {
    res.status(503).send('YouTube OAuth not configured');
    return;
  }
  try {
    const state = decodeOAuthState(
      typeof req.query.state === 'string' ? req.query.state : ''
    );
    const returnUrl = sanitizeReturnUrl(state.returnUrl, baseUrl);
    const fetch = (await import('node-fetch')).default;
    const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ client_id: clientId, client_secret: clientSecret, code, grant_type: 'authorization_code', redirect_uri: redirectUri }),
    });
    const tokenData = await tokenRes.json();
    if (!tokenRes.ok) {
      res.status(500).send(tokenData.error_description || tokenData.error || 'OAuth failed');
      return;
    }
    const channel = tokenData.access_token
      ? await fetchYoutubeChannelProfile(tokenData.access_token).catch((error) => {
          console.warn('YouTube profile fetch failed:', error.message);
          return null;
        })
      : null;
    if (state.uid) {
      await persistYoutubeConnection({
        uid: state.uid,
        tokenData,
        channel,
      });
    }

    const redirectTarget = new URL(returnUrl);
    redirectTarget.searchParams.set('youtube_connected', '1');
    if (channel?.snippet?.title) {
      redirectTarget.searchParams.set(
        'youtube_channel',
        channel.snippet.title
      );
    }
    if (!state.uid && tokenData.access_token) {
      redirectTarget.searchParams.set(
        'access_token',
        tokenData.access_token
      );
    }
    res.redirect(redirectTarget.toString());
  } catch (e) {
    console.error('YouTube callback error:', e);
    res.status(500).send('OAuth failed');
  }
});

exports.healthCheck = functions.region(region).https.onRequest((req, res) => {
  res.status(200).json({ ok: true });
});

exports.markChatAsRead = functions.region(region).https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  const { chatId } = data || {};
  if (!chatId) throw new functions.https.HttpsError('invalid-argument', 'chatId required');
  const uid = context.auth.uid;
  const chatRef = firestore.doc(`chats/${chatId}`);
  const chatDoc = await chatRef.get();
  if (!chatDoc.exists) throw new functions.https.HttpsError('not-found', 'Chat not found');
  const participants = chatDoc.data().participants || [];
  if (!participants.includes(uid)) throw new functions.https.HttpsError('permission-denied', 'Not a participant');
  await chatRef.update({
    unreadCount: 0,
    [`unreadCount_${uid}`]: 0,
    lastReadTimestamp: FieldValue.serverTimestamp(),
  });
  return { ok: true };
});

exports.onCommentDelete = functions.region(region).firestore
  .document('videos/{videoId}/comments/{commentId}')
  .onDelete(async (snap, context) => {
    const { videoId } = context.params;
    try {
      const videoRef = firestore.doc(`videos/${videoId}`);
      await videoRef.update({ commentCount: FieldValue.increment(-1) });
      console.log('Comment deleted, decremented count for video', videoId);
    } catch (e) {
      console.error('onCommentDelete error:', e);
    }
  });

exports.onFollowDelete = functions.region(region).firestore
  .document('follows/{followId}')
  .onDelete(async (snap, _context) => {
    const data = snap.data();
    const followerId = data.followerId;
    const followedId = data.followedId;
    try {
      await firestore.doc(`users/${followedId}`).update({ followerCount: FieldValue.increment(-1) });
      await firestore.doc(`users/${followerId}`).update({ followingCount: FieldValue.increment(-1) });
      console.log('Follow deleted, updated counts for', followerId, followedId);
    } catch (e) {
      console.error('onFollowDelete error:', e);
    }
  });

exports.onVideoWrite = functions.region(region).firestore
  .document('videos/{videoId}')
  .onWrite(async (change, context) => {
    const videoId = context.params.videoId;
    const globalFeedRef = firestore
      .collection('feeds')
      .doc('for_you')
      .collection('videos')
      .doc(videoId);

    if (!change.after.exists) {
      await globalFeedRef.delete().catch(() => null);
      return null;
    }

    const data = change.after.data() || {};
    if (!isPublicFeedEligible(data)) {
      await globalFeedRef.delete().catch(() => null);
      return null;
    }

    const rank = scoreVideoForFeed(data);
    const previousScore = Number(data.feedScore || 0);
    const scoreChanged = Math.abs(previousScore - rank.finalScore) >= 0.0001;
    const writes = [
      globalFeedRef.set(feedMirrorPayload(videoId, data, admin), {merge: true}),
    ];
    if (scoreChanged || !data.feedRank) {
      writes.push(change.after.ref.set({
        feedRank: rank,
        feedScore: rank.finalScore,
        rankedAt: FieldValue.serverTimestamp(),
      }, {merge: true}));
    }
    await Promise.all(writes);
    return null;
  });

exports.apiFeedForYou = onRequest({region, cors: true}, async (req, res) => {
  try {
    if (req.method !== 'GET') {
      res.status(405).json({error: 'Method not allowed'});
      return;
    }
    const limit = Math.min(Math.max(Number(req.query.limit || 30), 1), 50);
    const rankedSnapshot = await firestore
      .collection('feeds')
      .doc('for_you')
      .collection('videos')
      .orderBy('finalScore', 'desc')
      .limit(limit)
      .get();

    const itemsById = new Map();
    rankedSnapshot.docs.forEach((doc) => {
      const data = doc.data() || {};
      if (
        typeof data.finalScore === 'number' &&
        typeof data.canonicalPlaybackUrl === 'string' &&
        data.canonicalPlaybackUrl.trim()
      ) {
        itemsById.set(doc.id, {id: doc.id, ...data});
      }
    });

    const videoSnapshots = await Promise.all([
      firestore
        .collection('videos')
        .where('visibility', '==', 'public')
        .orderBy('createdAt', 'desc')
        .limit(limit * 2)
        .get()
        .catch(() => ({docs: []})),
      firestore
        .collection('videos')
        .where('status', 'in', ['ready', 'active', 'published'])
        .orderBy('createdAt', 'desc')
        .limit(limit * 2)
        .get()
        .catch(() => ({docs: []})),
    ]);

    const mirrorWrites = [];
    for (const snapshot of videoSnapshots) {
      for (const doc of snapshot.docs) {
        if (itemsById.has(doc.id)) continue;
        const data = doc.data() || {};
        if (!isPublicFeedEligible(data)) continue;
        const payload = feedMirrorPayload(doc.id, data, admin);
        itemsById.set(doc.id, {id: doc.id, ...payload});
        mirrorWrites.push(
          firestore
            .collection('feeds')
            .doc('for_you')
            .collection('videos')
            .doc(doc.id)
            .set(payload, {merge: true}),
        );
      }
    }

    await Promise.all(mirrorWrites.slice(0, 100));
    const items = Array.from(itemsById.values())
      .sort((a, b) => Number(b.finalScore || 0) - Number(a.finalScore || 0))
      .slice(0, limit);

    res.status(200).json({
      items,
    });
  } catch (error) {
    console.error('apiFeedForYou error:', error);
    res.status(500).json({error: error.message || 'Internal error'});
  }
});

exports.sendWelcomeEmail = functions.region(region).auth.user().onCreate(async (user) => {
  const email = user.email;
  if (!email) {
    console.log('sendWelcomeEmail: no email for', user.uid);
    return null;
  }
  const resendKey = process.env.RESEND_KEY || functions.config().resend?.key;
  if (!resendKey) {
    console.log('sendWelcomeEmail: Resend not configured, skipping for', user.uid);
    return null;
  }
  try {
    const fetch = (await import('node-fetch')).default;
    const from = process.env.RESEND_FROM || functions.config().resend?.from || 'StreamersTip <onboarding@resend.dev>';
    const r = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${resendKey}` },
      body: JSON.stringify({
        from,
        to: [email],
        subject: 'Welcome to StreamersTip',
        html: '<p>Thanks for signing up. We\'re glad to have you!</p>',
      }),
    });
    if (!r.ok) throw new Error(await r.text());
    console.log('Welcome email sent to', email);
  } catch (e) {
    console.error('sendWelcomeEmail error:', e);
  }
  return null;
});

exports.syncVideoAnalyticsToVideos = onSchedule(
  {schedule: '0 3 * * *', region},
  async () => {
    const db = admin.firestore();
    const snapshot = await db.collection('video_analytics').get();
    if (snapshot.empty) {
      console.log('syncVideoAnalyticsToVideos: no analytics docs');
      return null;
    }
    const updates = [];
    for (const doc of snapshot.docs) {
      const views = doc.data().views;
      if (views == null || views < 1) continue;
      updates.push({id: doc.id, views});
    }
    const getLimit = 100;
    const batchSize = 500;
    let synced = 0;
    for (let i = 0; i < updates.length; i += batchSize) {
      const chunk = updates.slice(i, i + batchSize);
      const refs = chunk.map(({id}) => db.collection('videos').doc(id));
      const existing = [];
      for (let j = 0; j < refs.length; j += getLimit) {
        const sub = refs.slice(j, j + getLimit);
        const snaps = await db.getAll(...sub);
        for (let k = 0; k < snaps.length; k++) {
          if (snaps[k].exists) existing.push(chunk[j + k]);
        }
      }
      if (existing.length === 0) continue;
      const batch = db.batch();
      for (const {id, views} of existing) {
        batch.update(db.collection('videos').doc(id), {
          views,
          lastViewedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      synced += existing.length;
    }
    console.log('syncVideoAnalyticsToVideos: synced', synced, 'videos');
    return null;
  },
);

async function addPublishedVideoToFeedIndexes({videoId, userId, privacy, category}) {
  const batch = firestore.batch();
  batch.set(
    firestore.collection('users').doc(userId).collection('videos').doc(videoId),
    {
      videoId,
      status: 'published',
      visible: true,
      addedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  const isPublic = ['Everyone', 'Public', 'public'].includes(privacy);
  if (isPublic) {
    for (const feedId of ['for_you', 'following']) {
      batch.set(
        firestore.collection('feeds').doc(feedId).collection('videos').doc(videoId),
        {
          videoId,
          userId,
          privacy,
          status: 'published',
          addedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    }
    if (category) {
      batch.set(
        firestore.collection('feeds').doc('categories').collection(String(category)).doc(videoId),
        {
          videoId,
          userId,
          category,
          privacy,
          status: 'published',
          addedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    }
  }

  await batch.commit();
}

exports.publishDueScheduledPosts = onSchedule(
  {schedule: 'every 1 minutes', region},
  async () => {
    const now = admin.firestore.Timestamp.now();
    const snapshot = await firestore
      .collection('scheduled_posts')
      .where('status', '==', 'scheduled')
      .limit(100)
      .get();

    const due = snapshot.docs.filter(doc => {
      const data = doc.data();
      const at = data.schedule?.scheduledAtUtc || data.scheduledAtUtc || data.scheduledAt;
      return at && (at.toMillis ? at.toMillis() <= now.toMillis() : at <= now);
    });

    if (due.length === 0) {
      console.log('publishDueScheduledPosts: none due');
      return null;
    }

    let published = 0;
    let failed = 0;
    for (const doc of due) {
      const data = doc.data();
      const videoId = data.videoId;
      const userId = data.authorId || data.userId;
      if (!videoId || !userId) {
        failed++;
        await doc.ref.set({
          status: 'failed',
          error: 'Missing videoId or userId for scheduled publish.',
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        continue;
      }

      try {
        const videoRef = firestore.collection('videos').doc(videoId);
        const videoSnap = await videoRef.get();
        const videoData = videoSnap.exists ? videoSnap.data() || {} : {};
        const privacy = videoData.privacy || data.privacy || 'Everyone';
        const category = videoData.category || data.category || videoData.metadata?.categoryCanonical;

        await videoRef.set({
          status: 'published',
          visible: true,
          isReadyForFeed: true,
          userId,
          creatorId: userId,
          creator_id: userId,
          privacy,
          visibility: privacy === 'Private' || privacy === 'private'
            ? 'private'
            : privacy === 'Followers' || privacy === 'followers_only'
              ? 'followers_only'
              : 'public',
          publishedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          scheduledAt: FieldValue.delete(),
          scheduledAtUtc: FieldValue.delete(),
        }, {merge: true});

        await addPublishedVideoToFeedIndexes({videoId, userId, privacy, category});

        await doc.ref.set({
          status: 'published',
          publishedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          history: FieldValue.arrayUnion({
            status: 'published',
            message: 'Backend published scheduled post.',
            timestamp: admin.firestore.Timestamp.now(),
          }),
        }, {merge: true});

        published++;
      } catch (error) {
        failed++;
        console.error('publishDueScheduledPosts failed for', doc.id, error);
        await doc.ref.set({
          status: 'failed',
          error: error.message || String(error),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
    }

    console.log('publishDueScheduledPosts:', {published, failed});
    return null;
  },
);

exports.cleanupExpiredCalendarEvents = onSchedule(
  {schedule: 'every 24 hours', region},
  async () => {
    const now = admin.firestore.Timestamp.now();
    const snapshot = await firestore.collection('scheduled_posts').where('status', '==', 'pending').limit(200).get();
    const toExpire = snapshot.docs.filter(doc => {
      const schedule = doc.data().schedule;
      const at = schedule?.scheduledAtUtc;
      return at && (at.toMillis ? at.toMillis() < now.toMillis() : at < now);
    });
    if (toExpire.length === 0) {
      console.log('cleanupExpiredCalendarEvents: none expired');
      return null;
    }
    const batch = firestore.batch();
    toExpire.forEach(doc => batch.update(doc.ref, { status: 'expired', updatedAt: FieldValue.serverTimestamp() }));
    await batch.commit();
    console.log('cleanupExpiredCalendarEvents: marked', toExpire.length, 'expired');
    return null;
  },
);

exports.manualCleanupCalendarEvents = onCall({region}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Must be logged in');
  const decoded = await admin.auth().getUser(request.auth.uid);
  const isAdmin = decoded.customClaims?.admin === true;
  if (!isAdmin) throw new HttpsError('permission-denied', 'Admin only');
  const now = admin.firestore.Timestamp.now();
  const snapshot = await firestore.collection('scheduled_posts').where('status', '==', 'pending').limit(200).get();
  const toExpire = snapshot.docs.filter(doc => {
    const schedule = doc.data().schedule;
    const at = schedule?.scheduledAtUtc;
    return at && (at.toMillis ? at.toMillis() < now.toMillis() : at < now);
  });
  const batch = firestore.batch();
  toExpire.forEach(doc => batch.update(doc.ref, { status: 'expired', updatedAt: FieldValue.serverTimestamp() }));
  if (toExpire.length) await batch.commit();
  return { ok: true, expired: toExpire.length };
});

const {adminExecute, adminDashboardStats} = require('./src/admin/admin_execute');
exports.adminExecute = adminExecute(region);
exports.adminDashboardStats = adminDashboardStats(region);

const {aggregateAnalyticsProfile} = require('./src/analytics/aggregate_analytics_profile');
const {onDocumentCreated} = require('firebase-functions/v2/firestore');
exports.onAnalyticsEventCreated = onDocumentCreated(
    {document: 'analytics_events/{eventId}', region},
    async (event) => {
      const data = event.data?.data();
      if (!data || !data.uid) {
        return;
      }
      try {
        await aggregateAnalyticsProfile(String(data.uid), data);
      } catch (e) {
        console.error('onAnalyticsEventCreated failed', e);
      }
    },
);
