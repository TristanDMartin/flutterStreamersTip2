'use strict';

const {resolveCanonicalPlaybackUrl} = require('../feed_ranking');
const {resolveOwnerId, isOwnerRenderable} = require('./video_owner');

const PUBLISHABLE_VIDEO_STATUSES = new Set([
  'ready',
  'active',
  'published',
  'scheduled',
]);

function isVideoTombstoned(videoData) {
  const status = String(videoData.status || '').toLowerCase();
  const moderation = String(videoData.moderationStatus || '').toLowerCase();
  return (
    videoData.isDeleted === true ||
    videoData.deleted === true ||
    status === 'deleted' ||
    moderation === 'removed' ||
    videoData.ownerActive === false
  );
}

/**
 * Decides whether a scheduled post may publish its video.
 * The post author must own the video; the video must be processed, playable,
 * and not tombstoned; the owner must be renderable.
 */
function evaluateScheduledPublish({postData, videoData, ownerData}) {
  const authorId = postData?.authorId || postData?.userId || null;
  if (!postData?.videoId || !authorId) {
    return {ok: false, reason: 'missing_video_or_author'};
  }
  if (!videoData) {
    return {ok: false, reason: 'video_not_found'};
  }
  if (resolveOwnerId(videoData) !== authorId) {
    return {ok: false, reason: 'author_not_owner'};
  }
  if (isVideoTombstoned(videoData)) {
    return {ok: false, reason: 'video_tombstoned'};
  }
  const status = String(videoData.status || '').toLowerCase();
  if (!PUBLISHABLE_VIDEO_STATUSES.has(status)) {
    return {ok: false, reason: 'video_not_processed'};
  }
  if (!resolveCanonicalPlaybackUrl(videoData)) {
    return {ok: false, reason: 'playback_missing'};
  }
  if (!isOwnerRenderable(ownerData)) {
    return {ok: false, reason: 'owner_not_renderable'};
  }
  return {ok: true, ownerId: authorId};
}

module.exports = {
  evaluateScheduledPublish,
};
