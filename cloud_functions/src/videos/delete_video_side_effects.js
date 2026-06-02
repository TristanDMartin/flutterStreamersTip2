const admin = require('firebase-admin');

const FieldValue = admin.firestore.FieldValue;
const firestore = admin.firestore();

const FORUM_POST_DELETE_FIELDS = {
  deleted: true,
  status: 'deleted',
  deletedAt: FieldValue.serverTimestamp(),
  deletedReason: 'source_video_deleted',
  updatedAt: FieldValue.serverTimestamp(),
  visible: false,
};

async function queryForumPostsByField(field, videoId) {
  const snap = await firestore
    .collection('forumPosts')
    .where(field, '==', videoId)
    .get();
  return snap.docs;
}

async function softDeleteForumPostsForVideo(videoId, batch, affectedIndexes) {
  const docMap = new Map();
  for (const field of ['linkedVideoId', 'videoId']) {
    const docs = await queryForumPostsByField(field, videoId);
    for (const doc of docs) {
      docMap.set(doc.id, doc);
    }
  }

  for (const doc of docMap.values()) {
    const data = doc.data() || {};
    if (data.status === 'deleted' && data.deletedReason === 'source_video_deleted') {
      continue;
    }
    batch.set(doc.ref, FORUM_POST_DELETE_FIELDS, {merge: true});
    affectedIndexes.push(doc.ref.path);
  }

  return docMap.size;
}

module.exports = {
  softDeleteForumPostsForVideo,
  FORUM_POST_DELETE_FIELDS,
};
