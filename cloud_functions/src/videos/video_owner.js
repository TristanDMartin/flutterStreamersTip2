'use strict';

function resolveOwnerId(data) {
  if (!data || typeof data !== 'object') {
    return null;
  }
  return (
    data.ownerId ||
    data.userId ||
    data.user_id ||
    data.authorId ||
    data.uid ||
    data.creatorId ||
    data.creator_id ||
    data.videoOwnerId ||
    null
  );
}

/** Canonical owner-renderable: explicit `active`, or missing/empty (legacy). */
function isOwnerRenderable(userData) {
  if (!userData || typeof userData !== 'object') {
    return false;
  }
  if (userData.isDeleted === true) {
    return false;
  }
  const status = String(userData.accountStatus || '').toLowerCase().trim();
  return status === '' || status === 'active';
}

module.exports = {
  resolveOwnerId,
  isOwnerRenderable,
};
