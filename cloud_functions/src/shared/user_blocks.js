'use strict';

const admin = require('firebase-admin');

/** Mirrors firestore.rules `pairIsBlocked` (either direction). */
async function isPairBlocked(userA, userB) {
  if (!userA || !userB || userA === userB) return false;
  const users = admin.firestore().collection('users');
  const [aBlocksB, bBlocksA] = await Promise.all([
    users.doc(userA).collection('blockedUsers').doc(userB).get(),
    users.doc(userB).collection('blockedUsers').doc(userA).get(),
  ]);
  return aBlocksB.exists || bBlocksA.exists;
}

module.exports = {isPairBlocked};
