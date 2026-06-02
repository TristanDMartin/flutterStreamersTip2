const EARLY_WINDOW_MS = 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

function asMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === 'function') return value.toMillis();
  if (typeof value.seconds === 'number') return value.seconds * 1000;
  if (value instanceof Date) return value.getTime();
  if (typeof value === 'number') return value;
  return 0;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, Number(value) || 0));
}

function logScore(value, divisor) {
  return Math.log1p(Math.max(0, Number(value) || 0)) * divisor;
}

function normalizeMuxHlsUrl(url) {
  if (typeof url !== 'string' || !url.trim()) return null;
  const trimmed = url.trim();
  if (!trimmed.includes('stream.mux.com')) return trimmed;
  try {
    const parsed = new URL(trimmed);
    const first = parsed.pathname.split('/').filter(Boolean)[0];
    const playbackId = String(first || '').replace('.m3u8', '');
    return playbackId ? `https://stream.mux.com/${playbackId}.m3u8` : trimmed;
  } catch (_) {
    return trimmed;
  }
}

function firstNonEmpty(values) {
  for (const value of values) {
    if (typeof value === 'string' && value.trim()) return value.trim();
  }
  return null;
}

function resolveCanonicalPlaybackUrl(data) {
  const fromFields = firstNonEmpty([
    data.canonicalPlaybackUrl,
    data.hlsUrl,
    data.hls_url,
    data.playbackUrl,
    data.videoUrl,
    data.videoURL,
    data.video_url,
  ]);
  if (fromFields) return normalizeMuxHlsUrl(fromFields);

  const muxPlaybackId = firstNonEmpty([
    data.muxPlaybackId,
    data.playbackId,
    data.mux_playback_id,
  ]);
  return muxPlaybackId
    ? `https://stream.mux.com/${muxPlaybackId}.m3u8`
    : null;
}

function isReadyStatus(data) {
  const status = String(data.status || '').toLowerCase();
  return ['ready', 'active', 'published'].includes(status);
}

function isPublicFeedEligible(data) {
  if (!data || data.isDeleted === true || data.deleted === true) return false;
  const visibility = String(data.visibility || '').toLowerCase();
  const privacy = String(data.privacy || '').toLowerCase();
  if (visibility && visibility !== 'public') return false;
  if (!visibility && privacy && !['everyone', 'public'].includes(privacy)) {
    return false;
  }
  if (data.isReadyForFeed === false) return false;
  return isReadyStatus(data) && !!resolveCanonicalPlaybackUrl(data);
}

function scoreVideoForFeed(data, options = {}) {
  const nowMs = options.nowMs || Date.now();
  const createdMs = asMillis(data.publishedAt) || asMillis(data.createdAt);
  const ageMs = Math.max(0, nowMs - createdMs);
  const ageHours = ageMs / (60 * 60 * 1000);
  const earlyBoost = ageMs <= EARLY_WINDOW_MS
    ? 140 - (ageMs / EARLY_WINDOW_MS) * 35
    : 0;

  const recencyScore = earlyBoost || Math.max(0, 80 - ageMs / DAY_MS * 8);
  const engagementScore =
    logScore(data.likes || data.likeCount, 12) +
    logScore(data.comments || data.commentCount, 16) +
    logScore(data.shares || data.shareCount, 18) +
    logScore(data.views || data.viewCount, 5);
  const creatorScore = clamp(data.creatorScore || data.creator_score, 0, 100);
  const watchTimeScore = clamp(data.watchTimeScore || data.avgWatchSeconds, 0, 100);
  const completionRate = clamp(data.completionRate || data.avgCompletionRate, 0, 1) * 100;
  const relationshipScore = clamp(data.relationshipScore, 0, 100);
  const categoryMatchScore = clamp(data.categoryMatchScore, 0, 100);
  const diversityPenalty = clamp(data.diversityPenalty, 0, 100);
  const duplicatePenalty = clamp(data.duplicatePenalty, 0, 100);
  const stalePenalty = ageHours > 24 ? Math.min(60, (ageHours - 24) * 0.75) : 0;

  const finalScore =
    recencyScore +
    engagementScore +
    watchTimeScore +
    creatorScore * 0.25 +
    relationshipScore * 0.4 +
    categoryMatchScore * 0.35 +
    completionRate * 0.5 -
    diversityPenalty -
    duplicatePenalty -
    stalePenalty;

  return {
    finalScore: Number(finalScore.toFixed(4)),
    recencyScore: Number(recencyScore.toFixed(4)),
    engagementScore: Number(engagementScore.toFixed(4)),
    creatorScore,
    watchTimeScore,
    completionRate,
    relationshipScore,
    categoryMatchScore,
    diversityPenalty,
    duplicatePenalty,
    stalePenalty: Number(stalePenalty.toFixed(4)),
    earlyWindowMinutes: 60,
    rankedAtMs: nowMs,
  };
}

function feedMirrorPayload(videoId, data, admin) {
  const scores = scoreVideoForFeed(data);
  const canonicalPlaybackUrl = resolveCanonicalPlaybackUrl(data);
  return {
    videoId,
    userId: data.userId || data.creatorId || data.creator_id || null,
    creatorId: data.userId || data.creatorId || data.creator_id || null,
    category: data.category || data.categoryId || 'general',
    status: 'ready',
    visibility: data.visibility || 'public',
    canonicalPlaybackUrl,
    thumbnailUrl: data.thumbnailUrl || data.thumbnailURL || null,
    createdAt: data.createdAt || null,
    publishedAt: data.publishedAt || data.createdAt || null,
    finalScore: scores.finalScore,
    rank: scores,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

module.exports = {
  isPublicFeedEligible,
  scoreVideoForFeed,
  feedMirrorPayload,
  resolveCanonicalPlaybackUrl,
};
