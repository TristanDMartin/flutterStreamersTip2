const admin = require('firebase-admin');

const firestore = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

async function syncCreatorGoalProgress(uid) {
  const goalsSnap = await firestore
    .collection('users')
    .doc(uid)
    .collection('creatorGoals')
    .where('status', 'in', ['active', 'in_progress'])
    .limit(10)
    .get()
    .catch(() => null);
  if (!goalsSnap || goalsSnap.empty) {
    return {updated: 0};
  }
  const batch = firestore.batch();
  goalsSnap.docs.forEach((doc) => {
    batch.set(
      doc.ref,
      {
        progressSyncedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  });
  await batch.commit();
  return {updated: goalsSnap.size};
}

module.exports = {
  syncCreatorGoalProgress,
};
