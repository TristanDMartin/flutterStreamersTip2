const admin = require('firebase-admin');

const firestore = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

function firstNonEmpty(data, keys) {
  for (const key of keys) {
    const value = data && data[key];
    if (typeof value === 'string' && value.trim().length > 0) {
      return value.trim();
    }
  }
  return '';
}

async function countRecentVideos(uid) {
  const snap = await firestore
    .collection('videos')
    .where('ownerId', '==', uid)
    .limit(20)
    .get()
    .catch(() => null);
  return snap ? snap.size : 0;
}

async function refreshTippyMemory(uid) {
  const userDoc = await firestore.collection('users').doc(uid).get();
  const userData = userDoc.exists ? userDoc.data() || {} : {};
  const nicheLabel = firstNonEmpty(userData, [
    'primaryNiche',
    'niche',
    'category',
    'creatorCategory',
  ]);
  const videoCount = await countRecentVideos(uid);
  const memory = {
    memoryReady: true,
    niche: {
      labels: nicheLabel ? [nicheLabel] : [],
      primaryCategoryId: nicheLabel || '',
    },
    videoCount,
    updatedAt: FieldValue.serverTimestamp(),
  };
  await firestore
    .collection('users')
    .doc(uid)
    .collection('tippyMemory')
    .doc('summary')
    .set(memory, {merge: true})
    .catch((err) => {
      console.warn('refreshTippyMemory write failed:', err.message || err);
    });
  return memory;
}

module.exports = {
  refreshTippyMemory,
};
