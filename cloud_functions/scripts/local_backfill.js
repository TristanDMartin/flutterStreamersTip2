#!/usr/bin/env node
/**
 * Local video backfill – transcodes on YOUR machine. Zero cloud compute cost.
 *
 * Prerequisites:
 *   - brew install ffmpeg
 *   - GOOGLE_APPLICATION_CREDENTIALS set to service account JSON
 *
 * Usage:
 *   cd cloud_functions && node scripts/local_backfill.js --dry-run
 *   cd cloud_functions && node scripts/local_backfill.js --limit 5
 *   cd cloud_functions && node scripts/local_backfill.js --limit 30
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const os = require('os');
const {transcodeVideo, uploadVariant, cleanupFiles} = require('../src/videoTranscoding');

function parseArgs() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  const limitIdx = args.indexOf('--limit');
  const limit = limitIdx >= 0 ? parseInt(args[limitIdx + 1], 10) : 10;
  return {dryRun, limit};
}

async function downloadFile(url, destPath) {
  const fetch = (await import('node-fetch')).default;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Download failed: ${res.status}`);
  const stream = fs.createWriteStream(destPath);
  await new Promise((resolve, reject) => {
    res.body.pipe(stream);
    res.body.on('error', reject);
    stream.on('finish', resolve);
  });
}

async function main() {
  const {dryRun, limit} = parseArgs();
  const projectId = process.env.GCLOUD_PROJECT || 'streamerstip-6cfdb';
  const bucketName = process.env.STORAGE_BUCKET || `${projectId}.firebasestorage.app`;
  admin.initializeApp({projectId, storageBucket: bucketName});
  const db = admin.firestore();
  const bucket = admin.storage().bucket();

  const snapshot = await db.collection('videos')
    .where('status', '==', 'published')
    .limit(limit * 2)
    .get();

  const toProcess = [];
  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (data.mp4_720_url && data.transcodingStatus === 'completed') continue;
    const videoUrl = data.videoUrl || data.videoURL || data.video_url;
    if (!videoUrl) continue;
    const userId = data.userId || data.creatorId || data.creator_id;
    if (!userId) continue;
    toProcess.push({id: doc.id, userId, videoUrl, data});
    if (toProcess.length >= limit) break;
  }

  console.log(`Found ${toProcess.length} videos to process (limit=${limit}, dryRun=${dryRun})\n`);

  if (dryRun) {
    toProcess.forEach((v, i) => console.log(`${i + 1}. ${v.id} (${v.userId})`));
    return;
  }

  let succeeded = 0;
  let failed = 0;

  for (let i = 0; i < toProcess.length; i++) {
    const video = toProcess[i];
    const tempDir = os.tmpdir();
    const tempIn = path.join(tempDir, `backfill_${video.id}_in.mp4`);
    const temp720 = path.join(tempDir, `backfill_${video.id}_720p.mp4`);

    try {
      console.log(`\n[${i + 1}/${toProcess.length}] ${video.id}`);
      await db.collection('videos').doc(video.id).set({
        transcodingStatus: 'processing',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      console.log('  Downloading...');
      await downloadFile(video.videoUrl, tempIn);

      console.log('  Transcoding 720p...');
      await transcodeVideo(tempIn, temp720, 720);

      console.log('  Uploading...');
      const url720 = await uploadVariant(bucket, video.userId, video.id, temp720, '720p');

      console.log('  Updating Firestore...');
      await db.collection('videos').doc(video.id).set({
        mp4_720_url: url720,
        videoUrl: url720,
        videoURL: url720,
        transcodingStatus: 'completed',
        transcodedAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'ready',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      succeeded++;
      console.log('  Done.');
    } catch (err) {
      failed++;
      console.error('  Error:', err.message);
      await db.collection('videos').doc(video.id).set({
        transcodingStatus: 'failed',
        transcodingError: err.message,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    } finally {
      cleanupFiles([tempIn, temp720]);
    }
  }

  console.log(`\nDone. Succeeded: ${succeeded}, Failed: ${failed}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
