const admin = require('firebase-admin');

const MUX_API = 'https://api.mux.com';
const MUX_STREAM_BASE = 'https://stream.mux.com';

function buildMuxPlaybackUrls(playbackId) {
  const safePlaybackId = String(playbackId || '').trim();
  if (!safePlaybackId) {
    return {
      adaptiveHlsUrl: '',
      highHlsUrl: '',
    };
  }

  return {
    adaptiveHlsUrl: `${MUX_STREAM_BASE}/${safePlaybackId}.m3u8`,
    highHlsUrl: `${MUX_STREAM_BASE}/${safePlaybackId}/high.m3u8`,
  };
}

function getMuxCredentials() {
  const tokenId = process.env.MUX_TOKEN_ID;
  const tokenSecret = process.env.MUX_TOKEN_SECRET;
  if (!tokenId || !tokenSecret) {
    throw new Error('MUX_TOKEN_ID and MUX_TOKEN_SECRET must be set in .env');
  }
  return { tokenId, tokenSecret };
}

function muxAuth(tokenId, tokenSecret) {
  const encoded = Buffer.from(`${tokenId}:${tokenSecret}`).toString('base64');
  return `Basic ${encoded}`;
}

/**
 * Create a Mux direct upload URL.
 * Returns { uploadUrl, uploadId } for client to PUT video file.
 */
async function createDirectUpload(videoId, userId) {
  const { tokenId, tokenSecret } = getMuxCredentials();
  const res = await fetch(`${MUX_API}/video/v1/uploads`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: muxAuth(tokenId, tokenSecret),
    },
    body: JSON.stringify({
      cors_origin: '*',
      new_asset_settings: {
        playback_policies: ['public'],
        video_quality: 'basic',
        passthrough: videoId,
        meta: { creator_id: userId },
      },
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Mux create upload failed: ${res.status} ${err}`);
  }
  const data = await res.json();
  const uploadId = data.data.id;
  const firestore = admin.firestore();
  const videoRef = firestore.collection('videos').doc(videoId);
  await videoRef.set(
    {
      userId,
      creatorId: userId,
      creator_id: userId,
      status: 'processing',
      visibility: 'public',
      visible: false,
      isReadyForFeed: false,
      isDeleted: false,
      isMux: true,
      muxStatus: 'processing',
      muxUploadId: uploadId || '',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return {
    uploadUrl: data.data.url,
    uploadId,
  };
}

/**
 * Handle Mux webhook payload. On video.asset.ready, update Firestore.
 * Payload: { type: 'video.asset.ready', data: { id, passthrough, playback_ids, duration } }
 */
async function handleMuxWebhook(payload) {
  const type = payload.type;
  if (type !== 'video.asset.ready') return;

  const data = payload.data || payload.object || payload;
  if (!data) return;

  const passthrough = data.passthrough ?? data.passthrough_id;
  if (!passthrough) {
    console.warn('Mux webhook: no passthrough (videoId)');
    return;
  }

  const videoId = String(passthrough).trim();
  const playbackIds = data.playback_ids || [];
  const publicPlayback = playbackIds.find((p) => p && p.policy === 'public') ||
    playbackIds[0];
  if (!publicPlayback || !publicPlayback.id) {
    console.warn('Mux webhook: no playback ID');
    return;
  }

  const playbackId = publicPlayback.id;
  const { adaptiveHlsUrl, highHlsUrl } = buildMuxPlaybackUrls(playbackId);
  const hlsUrl = adaptiveHlsUrl;
  const thumbnailUrl =
    `https://image.mux.com/${playbackId}/thumbnail.jpg?width=720&time=0`;
  const duration = data.duration != null ? Math.round(data.duration) : null;

  const firestore = admin.firestore();
  const videoRef = firestore.collection('videos').doc(videoId);
  const beforeSnap = await videoRef.get();
  const beforeData = beforeSnap.exists ? beforeSnap.data() || {} : {};
  // Client may mark uploads failed (e.g. network after bytes reached Mux) while
  // Mux still emits video.asset.ready. Without this guard, merge overwrites
  // status/visible and the item appears in Discover as "active".
  const hasClientUploadFailure =
    beforeData.status === 'failed' ||
    (Boolean(beforeData.uploadError) && beforeData.visible === false);
  if (hasClientUploadFailure) {
    console.warn(
      `Mux webhook: skip activation for ${videoId} (client upload failed)`,
    );
    return;
  }
  const userId =
    beforeData.userId ||
    beforeData.creatorId ||
    beforeData.creator_id ||
    (data.meta && data.meta.creator_id) ||
    null;
  const privacy = beforeData.privacy || 'Everyone';
  const visibility =
    beforeData.visibility ||
    (privacy === 'Everyone' || privacy === 'Public' || privacy === 'public'
      ? 'public'
      : privacy === 'Private' || privacy === 'private'
        ? 'private'
        : 'public');
  const category =
    beforeData.category ||
    beforeData.categoryId ||
    beforeData.category_id ||
    (beforeData.metadata && beforeData.metadata.categoryCanonical) ||
    (beforeData.metadata && beforeData.metadata.categoryOriginal) ||
    'gaming';

  const thumbnails = {
    urls: { 360: thumbnailUrl, 540: thumbnailUrl, 720: thumbnailUrl },
    generatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const updates = {
    hlsUrl,
    hls_url: hlsUrl,
    muxAdaptiveHlsUrl: adaptiveHlsUrl,
    muxHighHlsUrl: highHlsUrl,
    mp4_720_url: highHlsUrl,
    videoUrl: hlsUrl,
    videoURL: hlsUrl,
    canonicalPlaybackUrl: hlsUrl,
    thumbnailUrl,
    thumbnailURL: thumbnailUrl,
    thumbnails,
    status: 'ready',
    visible: true,
    isReadyForFeed: true,
    isDeleted: false,
    playbackReady: true,
    transcodingStatus: 'completed',
    muxAssetId: data.id,
    muxPlaybackId: playbackId,
    engagementScore: 0,
    publishedAt: admin.firestore.FieldValue.serverTimestamp(),
    transcodedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (userId) {
    updates.userId = userId;
    updates.creatorId = userId;
    updates.creator_id = userId;
  }
  updates.privacy = privacy;
  updates.visibility = visibility;
  if (category) {
    updates.category = category;
    updates.categoryId = category;
    updates.category_id = category;
    updates.categories = beforeData.categories || [category];
  }

  await videoRef.set(updates, { merge: true });

  if (duration != null) {
    await videoRef.update({
      'metadata.duration': duration,
    });
  }

  if (userId) {
    const batch = firestore.batch();
    batch.set(
      firestore.collection('users').doc(userId).collection('videos').doc(videoId),
      {
        videoId,
        userId,
        status: 'ready',
        visible: true,
        privacy,
        visibility,
        category,
        addedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    if (privacy === 'Everyone' || privacy === 'Public' || privacy === 'public') {
      batch.set(
        firestore.collection('feeds').doc('for_you').collection('videos').doc(videoId),
        {
          videoId,
          userId,
          privacy,
          status: 'ready',
          addedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      batch.set(
        firestore.collection('feeds').doc('following').collection('videos').doc(videoId),
        {
          videoId,
          userId,
          privacy,
          status: 'ready',
          addedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      if (category) {
        batch.set(
          firestore.collection('feeds').doc('categories').collection(String(category)).doc(videoId),
          {
            videoId,
            userId,
            category,
            privacy,
            status: 'ready',
            addedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
      }
    }

    await batch.commit();
  }

  console.log(`Mux webhook: updated video ${videoId} with HLS URL`);
}

module.exports = {
  createDirectUpload,
  handleMuxWebhook,
};
