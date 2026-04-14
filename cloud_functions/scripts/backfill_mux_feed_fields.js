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

function normalizeMuxHlsUrl(url) {
  if (typeof url !== 'string' || !url.trim()) return null;
  const trimmed = url.trim();
  if (!trimmed.includes('stream.mux.com')) return trimmed;

  try {
    const parsed = new URL(trimmed);
    const segments = parsed.pathname.split('/').filter(Boolean);
    if (segments.length === 0) return trimmed;

    const first = segments[0]
      .replace('.m3u8', '')
      .replace('/high', '')
      .replace('/medium', '')
      .replace('/low', '');

    if (!first) return trimmed;
    return `https://stream.mux.com/${first}.m3u8`;
  } catch (_) {
    return trimmed;
  }
}

function buildMuxThumbnail(playbackId, width) {
  return `https://image.mux.com/${playbackId}/thumbnail.jpg?width=${width}&time=0`;
}

function resolvePlayableUrl(data) {
  const playable = (
    data.canonicalPlaybackUrl ||
    data.hlsUrl ||
    data.hls_url ||
    data.videoUrl ||
    data.videoURL ||
    null
  );
  return normalizeMuxHlsUrl(playable);
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

  if (playableUrl) {
    update.hlsUrl = playableUrl;
    update.hls_url = playableUrl;
  }

  if (muxPlaybackId) {
    update.muxAdaptiveHlsUrl = `https://stream.mux.com/${muxPlaybackId}.m3u8`;
    update.muxHighHlsUrl = `https://stream.mux.com/${muxPlaybackId}/high.m3u8`;

    const thumb360 = buildMuxThumbnail(muxPlaybackId, 360);
    const thumb540 = buildMuxThumbnail(muxPlaybackId, 540);
    const thumb720 = buildMuxThumbnail(muxPlaybackId, 720);
    const thumb1080 = buildMuxThumbnail(muxPlaybackId, 1080);

    update.thumbnailUrl = data.thumbnailUrl || data.thumbnailURL || thumb720;
    update.thumbnailURL = data.thumbnailURL || data.thumbnailUrl || thumb720;
    update.thumbnails = {
      urls: {
        360: thumb360,
        540: thumb540,
        720: thumb720,
        1080: thumb1080,
      },
      migratedAt: FieldValue.serverTimestamp(),
    };
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
