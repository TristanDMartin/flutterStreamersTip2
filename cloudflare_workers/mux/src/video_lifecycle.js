/**
 * Shared video upload / delete lifecycle for the Mux Worker.
 * App + website should call these HTTP routes — not duplicate Firestore writes.
 */

const STUCK_UPLOAD_MS = 2 * 60 * 60 * 1000;

export function generateVideoId() {
  const ts = Date.now();
  const rand = Math.random().toString(36).slice(2, 10);
  return `video_${ts}_${rand}`;
}

export function isVideoDeleted(data) {
  if (!data || typeof data !== 'object') return false;
  if (data.isDeleted === true || data.deleted === true) return true;
  const status = String(data.status || '').toLowerCase();
  if (status === 'deleted' || status === 'removed') return true;
  if (data.deletedAt) return true;
  return false;
}

function parseMillis(value) {
  if (!value) return null;
  if (value instanceof Date) return value.getTime();
  if (typeof value === 'string') {
    const ms = Date.parse(value);
    return Number.isNaN(ms) ? null : ms;
  }
  if (typeof value === 'object' && value.__timestamp) {
    return Date.now();
  }
  return null;
}

export function isStaleUploadDoc(data) {
  const status = String(data.status || data.processingState || '').toLowerCase();
  if (!['uploading', 'pending', 'processing'].includes(status)) {
    return false;
  }
  const updatedMs =
    parseMillis(data.updatedAt) ||
    parseMillis(data.createdAt) ||
    null;
  if (updatedMs == null) return true;
  return Date.now() - updatedMs > STUCK_UPLOAD_MS;
}

/**
 * Resolves Firestore doc id for a new upload. Never reuses deleted or feed-active ids.
 */
export async function allocateVideoIdForNewUpload(env, clientVideoId, uid, deps) {
  const { firestoreGetDocument } = deps;
  const hint = String(clientVideoId || '').trim();
  if (!hint) {
    return { videoId: generateVideoId(), replacedClientId: false };
  }

  const existing = await firestoreGetDocument(env, `videos/${hint}`);
  if (existing == null) {
    return { videoId: hint, replacedClientId: false };
  }
  if (Object.keys(existing).length === 0) {
    return { videoId: hint, replacedClientId: false };
  }

  const owner = String(
    existing.userId || existing.creatorId || existing.creator_id || '',
  ).trim();
  if (owner && owner !== uid) {
    return {
      error: 'VIDEO_ID_NOT_OWNED',
      message: 'videoId belongs to another user',
      status: 403,
    };
  }

  if (isVideoDeleted(existing)) {
    return { videoId: generateVideoId(), replacedClientId: true };
  }

  const status = String(existing.status || '').toLowerCase();
  if (['active', 'published', 'ready'].includes(status)) {
    return { videoId: generateVideoId(), replacedClientId: true };
  }

  if (['uploading', 'pending', 'processing'].includes(status)) {
    if (isStaleUploadDoc(existing)) {
      return { videoId: generateVideoId(), replacedClientId: true };
    }
    return {
      error: 'VIDEO_UPLOAD_IN_PROGRESS',
      message:
        'An upload is already in progress for this video. Start a new post instead.',
      status: 409,
      existingVideoId: hint,
    };
  }

  if (status === 'failed') {
    return { videoId: generateVideoId(), replacedClientId: true };
  }

  return { videoId: generateVideoId(), replacedClientId: true };
}

export function pendingVideoFields({
  videoId,
  uid,
  body,
  uploadId,
  isDraft,
}) {
  return {
    id: videoId,
    userId: uid,
    creatorId: uid,
    creator_id: uid,
    status: 'uploading',
    processingState: 'uploading',
    isReadyForFeed: false,
    isDeleted: false,
    visible: false,
    videoUrl: '',
    thumbnailUrl: '',
    hasMuxPlaybackId: false,
    caption: body.caption || '',
    hashtags: body.hashtags || [],
    privacy: body.privacy || 'public',
    visibility: body.visibility || body.privacy || 'public',
    allowComments: body.allowComments !== false,
    category: body.category || 'general',
    views: 0,
    likes: 0,
    comments: 0,
    isMux: true,
    muxStatus: 'processing',
    muxUploadId: uploadId || '',
    isDraft: isDraft === true,
    createdAt: { __timestamp: true },
    updatedAt: { __timestamp: true },
  };
}

export function failedUploadFields(errorCode, errorMessage) {
  return {
    status: 'failed',
    processingState: 'failed',
    isReadyForFeed: false,
    visible: false,
    muxStatus: 'failed',
    errorCode,
    errorMessage: String(errorMessage || errorCode).slice(0, 500),
    updatedAt: { __timestamp: true },
  };
}
