const admin = require('firebase-admin');
const {HttpsError} = require('firebase-functions/v2/https');

const FieldValue = admin.firestore.FieldValue;
const firestore = admin.firestore();

const MAX_BULK_DELETE = 50;

function resolveOwnerId(data) {
  if (!data || typeof data !== 'object') {
    return null;
  }
  return (
    data.userId ||
    data.creatorId ||
    data.creator_id ||
    null
  );
}

function resolveCategory(data) {
  if (!data || typeof data !== 'object') {
    return '';
  }
  return String(
    data.category ||
      data.category_id ||
      data.categoryId ||
      '',
  ).trim();
}

async function requestIsAdmin(auth) {
  if (auth?.token?.admin === true) {
    return true;
  }
  if (!auth?.uid) {
    return false;
  }
  const userDoc = await firestore.collection('users').doc(auth.uid).get();
  const data = userDoc.data() || {};
  return (
    data.isAdmin === true ||
    data.role === 'admin' ||
    (data.admin && data.admin.isAdmin === true)
  );
}

function canDeleteVideo(data, authUid, isAdmin) {
  if (isAdmin) {
    return true;
  }
  const ownerId = resolveOwnerId(data);
  return ownerId != null && ownerId === authUid;
}

const {
  softDeleteForumPostsForVideo,
} = require('./delete_video_side_effects');

async function deleteFeedIndexDoc(path, batch, affectedIndexes) {
  const ref = firestore.doc(path);
  const snap = await ref.get();
  if (!snap.exists) {
    return;
  }
  batch.delete(ref);
  affectedIndexes.push(path);
}

async function deleteBookmarksForVideo(videoId, batch, affectedIndexes) {
  const bookmarksSnap = await firestore
    .collection('videos')
    .doc(videoId)
    .collection('bookmarks')
    .get();
  for (const doc of bookmarksSnap.docs) {
    batch.delete(doc.ref);
    affectedIndexes.push(doc.ref.path);
  }
}

async function deleteFavoritesForVideo(videoId, batch, affectedIndexes) {
  const userFavoritesSnap = await firestore
    .collectionGroup('favorites')
    .where(admin.firestore.FieldPath.documentId(), '==', videoId)
    .get();
  for (const doc of userFavoritesSnap.docs) {
    const parts = doc.ref.path.split('/');
    if (parts.length !== 4 || parts[0] !== 'users' || parts[2] !== 'favorites') {
      continue;
    }
    batch.delete(doc.ref);
    affectedIndexes.push(doc.ref.path);
  }

  const favoritesSnap = await firestore
    .collectionGroup('videos')
    .where(admin.firestore.FieldPath.documentId(), '==', videoId)
    .get();
  for (const doc of favoritesSnap.docs) {
    const path = doc.ref.path;
    if (!path.includes('/user_favorites/')) {
      continue;
    }
    batch.delete(doc.ref);
    affectedIndexes.push(path);
  }
}

async function cancelScheduledPostsForVideo(videoId, ownerId, batch, affectedIndexes) {
  const scheduledSnap = await firestore
    .collection('scheduled_posts')
    .where('videoId', '==', videoId)
    .get();
  for (const doc of scheduledSnap.docs) {
    const data = doc.data() || {};
    const postOwner = data.userId || data.ownerId || data.creatorId;
    if (postOwner && postOwner !== ownerId) {
      continue;
    }
    batch.set(
      doc.ref,
      {
        status: 'cancelled',
        cancelledReason: 'video_deleted',
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    affectedIndexes.push(doc.ref.path);
  }
}

async function softDeleteOneVideo({
  videoId,
  authUid,
  isAdmin,
  source,
  bulkDelete,
}) {
  const videoRef = firestore.collection('videos').doc(videoId);
  const videoSnap = await videoRef.get();
  if (!videoSnap.exists) {
    return {videoId, ok: false, reason: 'not_found'};
  }
  const data = videoSnap.data() || {};
  const ownerId = resolveOwnerId(data);
  if (!ownerId) {
    return {videoId, ok: false, reason: 'missing_owner'};
  }
  if (!canDeleteVideo(data, authUid, isAdmin)) {
    throw new HttpsError(
      'permission-denied',
      'You can only delete your own videos.',
    );
  }
  const status = String(data.status || '').toLowerCase();
  if (status === 'deleted' || data.isDeleted === true) {
    return {videoId, ok: true, skipped: true, reason: 'already_deleted'};
  }

  const category = resolveCategory(data);
  const affectedIndexes = [];

  await videoRef.set(
    {
      isDeleted: true,
      deleted: true,
      deletedAt: FieldValue.serverTimestamp(),
      deletedBy: authUid,
      status: 'deleted',
      visibility: 'private',
      visible: false,
      isReadyForFeed: false,
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  const batch = firestore.batch();
  const indexPaths = [
    `users/${ownerId}/videos/${videoId}`,
    `feeds/for_you/videos/${videoId}`,
    `feeds/following/videos/${videoId}`,
    `user_videos/${ownerId}/posts/${videoId}`,
  ];
  if (category) {
    indexPaths.push(`feeds/categories/${category}/videos/${videoId}`);
  }
  for (const path of indexPaths) {
    await deleteFeedIndexDoc(path, batch, affectedIndexes);
  }
  await deleteBookmarksForVideo(videoId, batch, affectedIndexes);
  await deleteFavoritesForVideo(videoId, batch, affectedIndexes);
  await cancelScheduledPostsForVideo(videoId, ownerId, batch, affectedIndexes);
  await softDeleteForumPostsForVideo(videoId, batch, affectedIndexes);

  const pinnedRef = firestore.collection('users').doc(ownerId);
  const pinnedSnap = await pinnedRef.get();
  const pinnedIds = Array.isArray(pinnedSnap.data()?.pinnedVideoIds)
    ? pinnedSnap.data().pinnedVideoIds
    : [];
  if (pinnedIds.includes(videoId)) {
    batch.update(pinnedRef, {
      pinnedVideoIds: pinnedIds.filter((id) => id !== videoId),
    });
    affectedIndexes.push(`${pinnedRef.path}.pinnedVideoIds`);
  }

  if (affectedIndexes.length > 0) {
    await batch.commit();
  }

  await firestore.collection('videoDeletionLogs').add({
    videoId,
    uid: authUid,
    ownerId,
    deletedAt: FieldValue.serverTimestamp(),
    source: source || 'app',
    bulkDelete: bulkDelete === true,
    affectedIndexes,
  });

  return {
    videoId,
    ok: true,
    ownerId,
    affectedIndexes,
  };
}

async function handleDeleteVideo(request) {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Sign in to delete videos.');
  }
  const videoId = String(request.data?.videoId || '').trim();
  if (!videoId) {
    throw new HttpsError('invalid-argument', 'videoId is required.');
  }
  const isAdmin = await requestIsAdmin(request.auth);
  const result = await softDeleteOneVideo({
    videoId,
    authUid: request.auth.uid,
    isAdmin,
    source: request.data?.source || 'app',
    bulkDelete: false,
  });
  return {success: true, results: [result]};
}

async function handleDeleteVideos(request) {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Sign in to delete videos.');
  }
  const rawIds = request.data?.videoIds;
  if (!Array.isArray(rawIds) || rawIds.length === 0) {
    throw new HttpsError('invalid-argument', 'videoIds must be a non-empty array.');
  }
  const videoIds = [...new Set(
    rawIds.map((id) => String(id || '').trim()).filter(Boolean),
  )];
  if (videoIds.length > MAX_BULK_DELETE) {
    throw new HttpsError(
      'invalid-argument',
      `Cannot delete more than ${MAX_BULK_DELETE} videos at once.`,
    );
  }
  const isAdmin = await requestIsAdmin(request.auth);
  const results = [];
  for (const videoId of videoIds) {
    try {
      const result = await softDeleteOneVideo({
        videoId,
        authUid: request.auth.uid,
        isAdmin,
        source: request.data?.source || 'app',
        bulkDelete: true,
      });
      results.push(result);
    } catch (err) {
      if (err instanceof HttpsError) {
        results.push({videoId, ok: false, reason: err.message});
      } else {
        throw err;
      }
    }
  }
  const deletedCount = results.filter((r) => r.ok && !r.skipped).length;
  return {success: deletedCount > 0, results, deletedCount};
}

module.exports = {
  handleDeleteVideo,
  handleDeleteVideos,
  MAX_BULK_DELETE,
};
