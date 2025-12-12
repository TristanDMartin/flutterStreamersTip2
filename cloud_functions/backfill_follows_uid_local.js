#!/usr/bin/env node
/**
 * Idempotent backfill for follows:
 * - Upsert followerUserId / targetUserId from legacy fields
 * - Ensure isActive is boolean (default true)
 * - Fill createdAt/updatedAt if missing
 *
 * Safety:
 * - DRY_RUN=true by default (no writes)
 * - Limit processed docs via BATCH_LIMIT (default 500)
 * - Stop if failures exceed MAX_ERRORS (default 5)
 *
 * Usage (emulator):
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 DRY_RUN=true node backfill_follows_uid_local.js
 */

const admin = require('firebase-admin');

async function main() {
  const dryRun = (process.env.DRY_RUN || 'true').toLowerCase() !== 'false';
  const batchLimit = parseInt(process.env.BATCH_LIMIT || '500', 10);
  const maxErrors = parseInt(process.env.MAX_ERRORS || '5', 10);

  if (process.env.FIRESTORE_EMULATOR_HOST) {
    process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-follows-tests';
    admin.initializeApp({projectId: process.env.GCLOUD_PROJECT});
  } else {
    admin.initializeApp();
  }

  const db = admin.firestore();
  const followsRef = db.collection('follows').limit(batchLimit);
  const snapshot = await followsRef.get();

  console.log(
    `Backfill start: dryRun=${dryRun} batchLimit=${batchLimit} maxErrors=${maxErrors}`,
  );

  let processed = 0;
  let updated = 0;
  let failed = 0;

  for (const doc of snapshot.docs) {
    processed += 1;
    const data = doc.data();
    const followerUserId = data.followerUserId || data.followerId;
    const targetUserId = data.targetUserId || data.followingId || data.followedId;
    if (!followerUserId || !targetUserId) continue;

    const updates = {};
    if (!data.followerUserId) updates.followerUserId = followerUserId;
    if (!data.targetUserId) updates.targetUserId = targetUserId;
    if (typeof data.isActive !== 'boolean') updates.isActive = true;
    if (!data.createdAt) updates.createdAt = admin.firestore.FieldValue.serverTimestamp();
    updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();
    if (Object.keys(updates).length === 0) continue;

    try {
      if (!dryRun) {
        await doc.ref.set(updates, {merge: true});
      }
      updated += 1;
    } catch (e) {
      failed += 1;
      console.error(`❌ Failed to update ${doc.id}:`, e.message);
      if (failed >= maxErrors) {
        console.error('❌ Max errors reached, stopping.');
        break;
      }
    }
  }

  console.log(
    `Backfill finished: processed=${processed}, updated=${updated}, failed=${failed}, dryRun=${dryRun}`,
  );

  if (failed > 0) process.exit(1);
  process.exit(0);
}

main().catch((err) => {
  console.error('❌ Backfill failed', err);
  process.exit(1);
});
