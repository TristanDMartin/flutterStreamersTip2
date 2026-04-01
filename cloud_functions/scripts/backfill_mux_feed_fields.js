const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const firestore = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const dryRun = process.env.DRY_RUN !== 'false';
const limit = Number.parseInt(process.env.VIDEO_LIMIT || '200', 10);

function isPublicVideo(data) {
  const visibility = data.visibility;
  const privacy = data.privacy;
  return (
    visibility === 'public' ||
    privacy === 'Everyone' ||
    privacy === 'Public' ||
    (visibility == null && privacy == null)
  );
}

function resolvePlayableUrl(data) {
  return (
    data.canonicalPlaybackUrl ||
    data.hlsUrl ||
    data.hls_url ||
    data.videoUrl ||
    data.videoURL ||
    null
  );
}

function buildBackfillUpdate(data) {
  const muxPlaybackId =
    typeof data.muxPlaybackId === 'string' && data.muxPlaybackId.trim()
      ? data.muxPlaybackId.trim()
      : null;
  const playableUrl = resolvePlayableUrl(data);

  if (!muxPlaybackId && !playableUrl) {
    return null;
  }

  if (!isPublicVideo(data)) {
    return null;
  }

  const update = {
    status: 'active',
    isReadyForFeed: true,
    playbackReady: true,
    engagementScore:
      typeof data.engagementScore === 'number' ? data.engagementScore : 0,
    updatedAt: FieldValue.serverTimestamp(),
    migratedToCanonicalFeedAt: FieldValue.serverTimestamp(),
  };

  if (!data.publishedAt) {
    update.publishedAt = data.createdAt || FieldValue.serverTimestamp();
  }

  if (!data.visibility) {
    update.visibility = 'public';
  }

  if (!data.videoUrl && playableUrl) {
    update.videoUrl = playableUrl;
  }

  if (!data.videoURL && playableUrl) {
    update.videoURL = playableUrl;
  }

  if (!data.canonicalPlaybackUrl && playableUrl) {
    update.canonicalPlaybackUrl = playableUrl;
  }

  return update;
}

async function run() {
  console.log(
    `[backfill-mux-feed-fields] starting dryRun=${dryRun} limit=${limit}`
  );

  const snapshot = await firestore
    .collection('videos')
    .orderBy('createdAt', 'desc')
    .limit(limit)
    .get();

  let scanned = 0;
  let candidates = 0;
  let updated = 0;

  for (const doc of snapshot.docs) {
    scanned += 1;
    const data = doc.data();
    const update = buildBackfillUpdate(data);
    if (!update) {
      continue;
    }

    candidates += 1;
    console.log(
      `[backfill-mux-feed-fields] candidate ${doc.id} status=${data.status || 'null'} mux=${!!data.muxPlaybackId} ready=${data.isReadyForFeed === true}`
    );

    if (!dryRun) {
      await doc.ref.set(update, {merge: true});
      updated += 1;
    }
  }

  console.log(
    `[backfill-mux-feed-fields] complete scanned=${scanned} candidates=${candidates} updated=${updated} dryRun=${dryRun}`
  );
}

run().catch((error) => {
  console.error('[backfill-mux-feed-fields] failed', error);
  process.exitCode = 1;
});
