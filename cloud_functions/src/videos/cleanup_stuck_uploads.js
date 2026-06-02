const admin = require('firebase-admin');
const {onSchedule} = require('firebase-functions/v2/scheduler');

const FieldValue = admin.firestore.FieldValue;
const firestore = admin.firestore();

const STUCK_MS = 2 * 60 * 60 * 1000;
const STUCK_STATUSES = new Set(['uploading', 'pending', 'processing']);
const BATCH_SIZE = 200;

function toMillis(value) {
  if (!value) {
    return null;
  }
  if (value instanceof admin.firestore.Timestamp) {
    return value.toMillis();
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  if (typeof value === 'string') {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? null : parsed;
  }
  return null;
}

function isStuckUpload(data) {
  const status = String(data.status || data.processingState || '').toLowerCase();
  if (!STUCK_STATUSES.has(status)) {
    return false;
  }
  const updatedMs =
    toMillis(data.updatedAt) || toMillis(data.createdAt) || null;
  if (updatedMs == null) {
    return true;
  }
  return Date.now() - updatedMs > STUCK_MS;
}

async function markStuckAsFailed() {
  let marked = 0;

  for (const status of ['uploading', 'pending', 'processing']) {
    const snap = await firestore
      .collection('videos')
      .where('status', '==', status)
      .limit(BATCH_SIZE)
      .get();

    const batch = firestore.batch();
    let batchCount = 0;
    for (const doc of snap.docs) {
      const data = doc.data() || {};
      if (!isStuckUpload(data)) {
        continue;
      }
      batch.set(
        doc.ref,
        {
          status: 'failed',
          processingState: 'failed',
          isReadyForFeed: false,
          visible: false,
          muxStatus: 'failed',
          errorCode: 'UPLOAD_STUCK_TIMEOUT',
          errorMessage: 'Upload did not complete within 2 hours',
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      batchCount += 1;
      marked += 1;
    }
    if (batchCount > 0) {
      await batch.commit();
    }
  }

  console.log(`cleanupStuckUploads: marked ${marked} videos as failed`);
  return {marked};
}

exports.cleanupStuckUploads = onSchedule(
  {
    schedule: 'every 60 minutes',
    timeZone: 'UTC',
    region: 'us-central1',
  },
  async () => {
    await markStuckAsFailed();
  },
);

exports.markStuckUploadsAsFailed = markStuckAsFailed;
