const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const firestore = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const dryRun = process.env.DRY_RUN !== 'false';
const limit = Number.parseInt(process.env.VIDEO_LIMIT || '500', 10);

const DEFAULT_PRIVACY = 'Public';
const DEFAULT_VISIBILITY = 'public';

const OWNER_KEYS = [
  'ownerId',
  'userId',
  'user_id',
  'authorId',
  'uid',
  'creatorId',
  'creator_id',
  'videoOwnerId',
];

function readOwnerId(data) {
  for (const key of OWNER_KEYS) {
    const value = data[key];
    if (typeof value === 'string' && value.trim()) {
      return value.trim();
    }
  }
  const meta = data.meta;
  if (meta && typeof meta === 'object') {
    for (const key of ['creator_id', 'creatorId', 'userId']) {
      const value = meta[key];
      if (typeof value === 'string' && value.trim()) {
        return value.trim();
      }
    }
  }
  return null;
}

function looksLikeFirebaseAuthUid(value) {
  if (typeof value !== 'string') return false;
  const trimmed = value.trim();
  if (trimmed.length < 20 || trimmed.length > 40) return false;
  return /^[A-Za-z0-9]+$/.test(trimmed);
}

function inferOwnerIdFromVideoDocumentId(videoId) {
  const underscoreIndex = videoId.indexOf('_');
  if (underscoreIndex <= 0) return null;
  const candidate = videoId.substring(0, underscoreIndex).trim();
  return looksLikeFirebaseAuthUid(candidate) ? candidate : null;
}

function resolveCaption(data) {
  const candidates = [
    data.caption,
    data.description,
    data.title,
    data.metadata?.preview_manual_caption,
  ];
  for (const value of candidates) {
    if (typeof value === 'string' && value.trim()) {
      return value.trim();
    }
  }
  return '';
}

function resolveVisibility(data, privacy) {
  if (typeof data.visibility === 'string' && data.visibility.trim()) {
    return data.visibility.trim();
  }
  const normalized = String(privacy || '').toLowerCase();
  if (normalized === 'followers' || normalized === 'followers_only') {
    return 'followers_only';
  }
  if (normalized === 'private') {
    return 'private';
  }
  return DEFAULT_VISIBILITY;
}

function buildBackfillUpdate(data, videoId) {
  const update = {};
  let ownerId = readOwnerId(data);
  if (!ownerId) {
    ownerId = inferOwnerIdFromVideoDocumentId(videoId);
  }
  if (ownerId) {
    if (!data.ownerId) update.ownerId = ownerId;
    if (!data.userId) update.userId = ownerId;
    if (!data.creatorId) update.creatorId = ownerId;
    if (!data.creator_id) update.creator_id = ownerId;
  }
  const privacy =
    typeof data.privacy === 'string' && data.privacy.trim()
      ? data.privacy.trim()
      : DEFAULT_PRIVACY;
  if (!data.privacy) {
    update.privacy = privacy;
  }
  if (!data.visibility) {
    update.visibility = resolveVisibility(data, privacy);
  }
  if (data.caption == null && resolveCaption(data) === '') {
    update.caption = '';
  }
  if (Object.keys(update).length === 0) {
    return null;
  }
  update.updatedAt = FieldValue.serverTimestamp();
  update.metadataBackfilledAt = FieldValue.serverTimestamp();
  return update;
}

async function run() {
  console.log(
    `[backfill-video-metadata] starting dryRun=${dryRun} limit=${limit}`,
  );

  const snapshot = await firestore
    .collection('videos')
    .orderBy('createdAt', 'desc')
    .limit(limit)
    .get();

  let scanned = 0;
  let candidates = 0;
  let updated = 0;
  let skippedNoOwner = 0;

  for (const doc of snapshot.docs) {
    scanned += 1;
    const data = doc.data();
    const update = buildBackfillUpdate(data, doc.id);
    if (!update) {
      continue;
    }
    if (!update.ownerId && !update.userId) {
      skippedNoOwner += 1;
      console.log(
        `[backfill-video-metadata] skip ${doc.id} (no owner resolvable)`,
      );
      continue;
    }
    candidates += 1;
    console.log(
      `[backfill-video-metadata] candidate ${doc.id} fields=${Object.keys(update).join(', ')}`,
    );
    if (!dryRun) {
      await doc.ref.set(update, {merge: true});
      updated += 1;
    }
  }

  console.log(
    `[backfill-video-metadata] complete scanned=${scanned} candidates=${candidates} updated=${updated} skippedNoOwner=${skippedNoOwner} dryRun=${dryRun}`,
  );
}

run().catch((error) => {
  console.error('[backfill-video-metadata] failed', error);
  process.exitCode = 1;
});
