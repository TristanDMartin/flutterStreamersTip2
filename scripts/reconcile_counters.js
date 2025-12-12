#!/usr/bin/env node
/**
 * Recompute follower/following/connections counts from follows collection
 * and compare to stored counters in users. Exits non-zero on drift.
 *
 * Usage (emulator):
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/reconcile_counters.js
 *
 * Usage (prod — be careful, read-only):
 *   node scripts/reconcile_counters.js
 */

const admin = require('firebase-admin');

async function main() {
  if (process.env.FIRESTORE_EMULATOR_HOST) {
    process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-follows-tests';
    admin.initializeApp({projectId: process.env.GCLOUD_PROJECT});
  } else {
    admin.initializeApp();
  }

  const db = admin.firestore();
  const userCounters = new Map(); // userId -> {followers, following, connections}

  console.log('Reading follows...');
  const snapshot = await db.collection('follows').get();
  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (data.isActive === false) continue;
    const follower = data.followerUserId || data.followerId;
    const target = data.targetUserId || data.followingId || data.followedId;
    if (!follower || !target) continue;
    if (!userCounters.has(follower)) userCounters.set(follower, {followers: 0, following: 0, connections: 0});
    if (!userCounters.has(target)) userCounters.set(target, {followers: 0, following: 0, connections: 0});
    userCounters.get(follower).following += 1;
    userCounters.get(target).followers += 1;
  }

  // Compute mutual connections
  console.log('Computing connections...');
  const followingMap = new Map(); // userId -> Set(targets)
  const followerMap = new Map(); // userId -> Set(followers)
  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (data.isActive === false) continue;
    const follower = data.followerUserId || data.followerId;
    const target = data.targetUserId || data.followingId || data.followedId;
    if (!follower || !target) continue;
    if (!followingMap.has(follower)) followingMap.set(follower, new Set());
    if (!followerMap.has(target)) followerMap.set(target, new Set());
    followingMap.get(follower).add(target);
    followerMap.get(target).add(follower);
  }
  for (const [user, followingSet] of followingMap.entries()) {
    const followersSet = followerMap.get(user) || new Set();
    const mutual = new Set([...followingSet].filter((id) => followersSet.has(id)));
    if (!userCounters.has(user)) userCounters.set(user, {followers: 0, following: 0, connections: 0});
    userCounters.get(user).connections = mutual.size;
  }

  console.log('Comparing with stored user counters...');
  const usersSnapshot = await db.collection('users').get();
  let driftCount = 0;
  const driftDetails = [];

  for (const doc of usersSnapshot.docs) {
    const userId = doc.id;
    const stored = doc.data();
    const computed = userCounters.get(userId) || {followers: 0, following: 0, connections: 0};
    const storedFollowers = stored.followersCount || stored.followerCount || 0;
    const storedFollowing = stored.followingCount || 0;
    const storedConnections = stored.connectionsCount || 0;

    const diffFollowers = storedFollowers - computed.followers;
    const diffFollowing = storedFollowing - computed.following;
    const diffConnections = storedConnections - computed.connections;

    if (diffFollowers !== 0 || diffFollowing !== 0 || diffConnections !== 0) {
      driftCount += 1;
      driftDetails.push({
        userId,
        stored: {followers: storedFollowers, following: storedFollowing, connections: storedConnections},
        computed,
      });
    }
  }

  if (driftCount === 0) {
    console.log('✅ No drift detected.');
    process.exit(0);
  } else {
    console.error(`❌ Drift detected for ${driftCount} users.`);
    driftDetails.slice(0, 20).forEach((d) => {
      console.error(
        `User ${d.userId}: stored f=${d.stored.followers}, fo=${d.stored.following}, c=${d.stored.connections} | computed f=${d.computed.followers}, fo=${d.computed.following}, c=${d.computed.connections}`,
      );
    });
    if (driftDetails.length > 20) {
      console.error(`...and ${driftDetails.length - 20} more`);
    }
    process.exit(1);
  }
}

main().catch((err) => {
  console.error('❌ Reconciliation failed', err);
  process.exit(1);
});
