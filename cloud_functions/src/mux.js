const admin = require('firebase-admin');

const MUX_API = 'https://api.mux.com';
const MUX_STREAM_BASE = 'https://stream.mux.com';

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
  return {
    uploadUrl: data.data.url,
    uploadId: data.data.id,
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
  const hlsUrl = `${MUX_STREAM_BASE}/${playbackId}/high.m3u8`;
  const thumbnailUrl =
    `https://image.mux.com/${playbackId}/thumbnail.jpg?width=720&time=0`;
  const duration = data.duration != null ? Math.round(data.duration) : null;

  const firestore = admin.firestore();
  const videoRef = firestore.collection('videos').doc(videoId);

  const thumbnails = {
    urls: { 360: thumbnailUrl, 540: thumbnailUrl, 720: thumbnailUrl },
    generatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const updates = {
    hlsUrl,
    hls_url: hlsUrl,
    mp4_720_url: hlsUrl,
    videoUrl: hlsUrl,
    videoURL: hlsUrl,
    canonicalPlaybackUrl: hlsUrl,
    thumbnailUrl,
    thumbnailURL: thumbnailUrl,
    thumbnails,
    status: 'active',
    isReadyForFeed: true,
    playbackReady: true,
    transcodingStatus: 'completed',
    muxAssetId: data.id,
    muxPlaybackId: playbackId,
    engagementScore: 0,
    publishedAt: admin.firestore.FieldValue.serverTimestamp(),
    transcodedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await videoRef.set(updates, { merge: true });

  if (duration != null) {
    await videoRef.update({
      'metadata.duration': duration,
    });
  }

  console.log(`Mux webhook: updated video ${videoId} with HLS URL`);
}

module.exports = {
  createDirectUpload,
  handleMuxWebhook,
};
