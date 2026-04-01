#!/usr/bin/env node
/**
 * Backfill legacy embedded video comment replies into first-class reply docs.
 *
 * What it does:
 * - scans a batch of videos
 * - finds top-level video comments with legacy embedded `replies`
 * - creates deterministic first-class reply docs with `parentCommentId`
 * - recomputes parent `replyCount`
 * - marks parents with migration metadata so the job is idempotent
 *
 * Safety:
 * - DRY_RUN=true by default
 * - does not delete legacy embedded reply arrays
 * - deterministic reply doc IDs prevent duplicate writes across reruns
 *
 * Usage (emulator dry run):
 *   cd cloud_functions
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 DRY_RUN=true node scripts/migrate_legacy_video_comment_replies.js
 *
 * Usage (prod dry run):
 *   cd cloud_functions
 *   DRY_RUN=true node scripts/migrate_legacy_video_comment_replies.js
 *
 * Usage (prod write after dry run):
 *   cd cloud_functions
 *   DRY_RUN=false VIDEO_LIMIT=100 node scripts/migrate_legacy_video_comment_replies.js
 *
 * Optional env:
 * - VIDEO_LIMIT=100
 * - COMMENT_LIMIT_PER_VIDEO=200
 * - START_AFTER_VIDEO_ID=abc123
 * - MAX_ERRORS=10
 * - MIGRATION_VERSION=1
 */

const admin = require('firebase-admin');
const crypto = require('crypto');

function envBool(name, defaultValue) {
  const raw = process.env[name];
  if (!raw) return defaultValue;
  return raw.toLowerCase() !== 'false';
}

function parseIntEnv(name, defaultValue) {
  const raw = process.env[name];
  if (!raw) return defaultValue;
  const parsed = parseInt(raw, 10);
  return Number.isFinite(parsed) ? parsed : defaultValue;
}

function normalizeTimestamp(raw) {
  if (!raw) return null;
  if (raw instanceof admin.firestore.Timestamp) return raw;
  if (raw && typeof raw.toDate === 'function') {
    return admin.firestore.Timestamp.fromDate(raw.toDate());
  }
  if (raw instanceof Date) {
    return admin.firestore.Timestamp.fromDate(raw);
  }
  if (typeof raw === 'number') {
    return admin.firestore.Timestamp.fromMillis(raw);
  }
  if (typeof raw === 'string') {
    const asDate = new Date(raw);
    if (!Number.isNaN(asDate.getTime())) {
      return admin.firestore.Timestamp.fromDate(asDate);
    }
  }
  return null;
}

function normalizeUser(rawUser) {
  if (!rawUser || typeof rawUser !== 'object') {
    return {
      id: 'unknown',
      username: 'unknown',
      displayName: 'Unknown',
      avatarURL: null,
    };
  }

  return {
    ...rawUser,
    id: rawUser.id || rawUser.uid || rawUser.userId || 'unknown',
    username: rawUser.username || rawUser.displayName || 'unknown',
    displayName:
      rawUser.displayName || rawUser.username || rawUser.name || 'Unknown',
    avatarURL:
      rawUser.avatarURL ||
      rawUser.avatarUrl ||
      rawUser.photoURL ||
      rawUser.photoUrl ||
      null,
  };
}

function buildLegacyReplySourceKey(parentId, reply, index) {
  const user = normalizeUser(reply.user || reply.author);
  const timestamp = normalizeTimestamp(reply.timestamp || reply.createdAt);
  const payload = JSON.stringify({
    parentId,
    index,
    id: reply.id || null,
    text: reply.text || reply.content || '',
    userId: user.id,
    timestamp: timestamp ? timestamp.toMillis() : null,
  });
  return crypto.createHash('sha1').update(payload).digest('hex');
}

function buildReplyDocData({reply, parentId}) {
  const user = normalizeUser(reply.user || reply.author);
  const likedBy = Array.isArray(reply.likedBy)
    ? reply.likedBy.filter((value) => typeof value === 'string')
    : [];
  const likeCount = Number.isFinite(reply.likeCount)
    ? reply.likeCount
    : Number.isFinite(reply.likes)
      ? reply.likes
      : likedBy.length;
  const deleted = reply.deleted === true || reply.text === '[deleted]';
  const timestamp =
    normalizeTimestamp(reply.timestamp || reply.createdAt) ||
    admin.firestore.Timestamp.now();

  return {
    user,
    text: deleted ? '[deleted]' : reply.text || reply.content || '',
    timestamp,
    likeCount,
    isLiked: false,
    replies: [],
    parentCommentId: parentId,
    likedBy,
    replyCount: 0,
    deleted,
    createdAt: timestamp,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    legacyReplySource: 'embedded_array',
  };
}

async function main() {
  const dryRun = envBool('DRY_RUN', true);
  const videoLimit = parseIntEnv('VIDEO_LIMIT', 100);
  const commentLimitPerVideo = parseIntEnv('COMMENT_LIMIT_PER_VIDEO', 200);
  const maxErrors = parseIntEnv('MAX_ERRORS', 10);
  const migrationVersion = parseIntEnv('MIGRATION_VERSION', 1);
  const startAfterVideoId = process.env.START_AFTER_VIDEO_ID || null;

  if (process.env.FIRESTORE_EMULATOR_HOST) {
    process.env.GCLOUD_PROJECT =
      process.env.GCLOUD_PROJECT || 'demo-legacy-comment-replies';
    admin.initializeApp({projectId: process.env.GCLOUD_PROJECT});
  } else {
    admin.initializeApp();
  }

  const db = admin.firestore();
  let videosQuery = db
    .collection('videos')
    .orderBy(admin.firestore.FieldPath.documentId())
    .limit(videoLimit);

  if (startAfterVideoId) {
    videosQuery = videosQuery.startAfter(startAfterVideoId);
  }

  const videosSnapshot = await videosQuery.get();

  console.log(
    [
      'Legacy video reply migration start:',
      `dryRun=${dryRun}`,
      `videoLimit=${videoLimit}`,
      `commentLimitPerVideo=${commentLimitPerVideo}`,
      `migrationVersion=${migrationVersion}`,
      `startAfterVideoId=${startAfterVideoId || '-'}`,
    ].join(' '),
  );

  let videosScanned = 0;
  let parentsScanned = 0;
  let parentsWithLegacyReplies = 0;
  let parentsUpdated = 0;
  let repliesCreated = 0;
  let repliesSkippedExisting = 0;
  let failed = 0;

  for (const videoDoc of videosSnapshot.docs) {
    videosScanned += 1;
    const commentsSnapshot = await videoDoc.ref
      .collection('comments')
      .limit(commentLimitPerVideo)
      .get();

    for (const commentDoc of commentsSnapshot.docs) {
      const commentData = commentDoc.data();
      const parentCommentId =
        typeof commentData.parentCommentId === 'string'
          ? commentData.parentCommentId.trim()
          : '';
      if (parentCommentId) {
        continue;
      }

      parentsScanned += 1;

      const rawReplies = Array.isArray(commentData.replies) ? commentData.replies : [];
      if (rawReplies.length === 0) {
        continue;
      }

      const alreadyMigratedVersion =
        commentData.legacyRepliesMigrationVersion || 0;
      if (alreadyMigratedVersion >= migrationVersion) {
        continue;
      }

      parentsWithLegacyReplies += 1;

      try {
        const existingRepliesSnapshot = await videoDoc.ref
          .collection('comments')
          .where('parentCommentId', '==', commentDoc.id)
          .get();

        const existingReplyIds = new Set(existingRepliesSnapshot.docs.map((doc) => doc.id));
        let activeReplyCount = existingRepliesSnapshot.docs.reduce((count, doc) => {
          const deleted = doc.data().deleted === true;
          return deleted ? count : count + 1;
        }, 0);

        const batch = db.batch();
        let createdForParent = 0;
        let skippedForParent = 0;

        rawReplies.forEach((reply, index) => {
          if (!reply || typeof reply !== 'object') {
            return;
          }

          const sourceKey = buildLegacyReplySourceKey(commentDoc.id, reply, index);
          const replyDocId = `legacy_${sourceKey}`;
          if (existingReplyIds.has(replyDocId)) {
            skippedForParent += 1;
            return;
          }

          const replyData = buildReplyDocData({
            reply,
            parentId: commentDoc.id,
          });
          replyData.legacyReplySourceKey = sourceKey;
          replyData.migrationVersion = migrationVersion;

          batch.set(videoDoc.ref.collection('comments').doc(replyDocId), replyData, {
            merge: true,
          });
          createdForParent += 1;

          if (!replyData.deleted) {
            activeReplyCount += 1;
          }
        });

        batch.set(
          commentDoc.ref,
          {
            replyCount: activeReplyCount,
            legacyRepliesMigrationVersion: migrationVersion,
            legacyRepliesMigratedAt: admin.firestore.FieldValue.serverTimestamp(),
            legacyRepliesSourceCount: rawReplies.length,
            legacyRepliesCreatedCount: existingRepliesSnapshot.docs.length + createdForParent,
          },
          {merge: true},
        );

        if (!dryRun) {
          await batch.commit();
        }

        parentsUpdated += 1;
        repliesCreated += createdForParent;
        repliesSkippedExisting += skippedForParent;

        console.log(
          [
            `video=${videoDoc.id}`,
            `parent=${commentDoc.id}`,
            `legacyReplies=${rawReplies.length}`,
            `created=${createdForParent}`,
            `skippedExisting=${skippedForParent}`,
            `replyCount=${activeReplyCount}`,
            dryRun ? 'dryRun=true' : 'written=true',
          ].join(' '),
        );
      } catch (error) {
        failed += 1;
        console.error(
          `❌ Failed parent ${commentDoc.ref.path}: ${error.message}`,
        );
        if (failed >= maxErrors) {
          console.error('❌ Max errors reached, stopping migration.');
          process.exit(1);
        }
      }
    }
  }

  console.log(
    [
      'Legacy video reply migration finished:',
      `videosScanned=${videosScanned}`,
      `parentsScanned=${parentsScanned}`,
      `parentsWithLegacyReplies=${parentsWithLegacyReplies}`,
      `parentsUpdated=${parentsUpdated}`,
      `repliesCreated=${repliesCreated}`,
      `repliesSkippedExisting=${repliesSkippedExisting}`,
      `failed=${failed}`,
      `dryRun=${dryRun}`,
    ].join(' '),
  );

  if (videosSnapshot.docs.length > 0) {
    const lastVideoId = videosSnapshot.docs[videosSnapshot.docs.length - 1].id;
    console.log(`Next cursor: START_AFTER_VIDEO_ID=${lastVideoId}`);
  }

  process.exit(failed > 0 ? 1 : 0);
}

main().catch((error) => {
  console.error('❌ Migration failed', error);
  process.exit(1);
});
