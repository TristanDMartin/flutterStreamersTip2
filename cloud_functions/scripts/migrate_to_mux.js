#!/usr/bin/env node
/**
 * Migrate videos from Firebase Storage to Mux.
 * Downloads each video from Storage, uploads to Mux, webhook updates Firestore.
 *
 * Prerequisites:
 *   - GOOGLE_APPLICATION_CREDENTIALS set to service account JSON
 *   - MUX_TOKEN_ID and MUX_TOKEN_SECRET in .env or env
 *
 * Usage:
 *   cd cloud_functions && node scripts/migrate_to_mux.js --dry-run
 *   cd cloud_functions && node scripts/migrate_to_mux.js --limit 5
 *   cd cloud_functions && node scripts/migrate_to_mux.js --limit 30 --offset 0
 */

const path = require('path');
const fs = require('fs');

// Load .env from cloud_functions directory
const envPath = path.join(__dirname, '../.env');
if (fs.existsSync(envPath)) {
  fs.readFileSync(envPath, 'utf8').split('\n').forEach((line) => {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) {
      process.env[m[1].trim()] = m[2].trim().replace(/^["']|["']$/g, '');
    }
  });
}

const admin = require('firebase-admin');
const os = require('os');
const { createDirectUpload } = require('../src/mux');

function parseArgs() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  const limitIdx = args.indexOf('--limit');
  const limit = limitIdx >= 0 ? parseInt(args[limitIdx + 1], 10) : 10;
  const offsetIdx = args.indexOf('--offset');
  const offset = offsetIdx >= 0 ? parseInt(args[offsetIdx + 1], 10) : 0;
  const skipStatus = args.includes('--skip-status');
  return { dryRun, limit, offset, skipStatus };
}

function extractBucketFromUrl(url) {
  if (!url || typeof url !== 'string') return null;
  const m = url.match(/\/v0\/b\/([^/]+)\//);
  if (m && m[1] && m[1] !== 'v0') return m[1];
  const gcs = url.match(/storage\.googleapis\.com\/([^/]+)/);
  return gcs ? gcs[1] : null;
}

function extractStoragePath(url) {
  if (!url || typeof url !== 'string') return null;
  const m = url.match(/firebasestorage\.googleapis\.com\/v0\/b\/[^/]+\/o\/([^?]+)/);
  if (m) {
    try {
      return decodeURIComponent(m[1]);
    } catch (_) {
      return null;
    }
  }
  const gcs = url.match(/storage\.googleapis\.com\/[^/]+\/(.+?)(?:\?|$)/);
  if (gcs) return gcs[1];
  return null;
}

function isFirebaseStorageUrl(url) {
  return url && (
    url.includes('firebasestorage.googleapis.com') ||
    url.includes('storage.googleapis.com')
  );
}

function hasMuxAlready(data) {
  return data.muxPlaybackId || data.muxAssetId ||
    (data.hlsUrl && data.hlsUrl.includes('stream.mux.com'));
}

async function downloadFromBucket(bucket, storagePath, destPath) {
  const file = bucket.file(storagePath);
  const [exists] = await file.exists();
  if (!exists) {
    throw new Error(`File not found: ${storagePath}`);
  }
  await file.download({ destination: destPath });
}

async function uploadToMux(uploadUrl, filePath) {
  const stat = fs.statSync(filePath);
  const body = fs.createReadStream(filePath);
  const res = await fetch(uploadUrl, {
    method: 'PUT',
    headers: {
      'Content-Type': 'video/mp4',
      'Content-Length': String(stat.size),
    },
    body,
    duplex: 'half',
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Mux upload failed: ${res.status} ${text}`);
  }
}

async function main() {
  const { dryRun, limit, offset, skipStatus } = parseArgs();

  const projectId = process.env.GCLOUD_PROJECT || 'streamerstip-6cfdb';
  const bucketName = process.env.STORAGE_BUCKET ||
    `${projectId}.firebasestorage.app`;

  if (!process.env.MUX_TOKEN_ID || !process.env.MUX_TOKEN_SECRET) {
    console.error('MUX_TOKEN_ID and MUX_TOKEN_SECRET must be set');
    process.exit(1);
  }

  try {
    admin.initializeApp({ projectId, storageBucket: bucketName });
  } catch (_) {
    // Already initialized
  }

  const db = admin.firestore();

  const snapshot = await db.collection('videos')
    .limit(500)
    .get();

  const candidates = [];
  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (hasMuxAlready(data)) continue;

    const videoUrl = data.videoUrl || data.videoURL || data.video_url ||
      data.mp4_720_url || data.mp4_480_url;
    if (!videoUrl || !isFirebaseStorageUrl(videoUrl)) continue;

    const userId = data.userId || data.creatorId || data.creator_id;
    if (!userId) continue;

    let storagePath = extractStoragePath(videoUrl);
    if (!storagePath || !storagePath.endsWith('.mp4')) {
      storagePath = `videos/${userId}/${doc.id}_720p.mp4`;
    }
    const bucketNameForVideo = extractBucketFromUrl(videoUrl) || bucketName;

    candidates.push({
      id: doc.id,
      userId,
      videoUrl,
      storagePath,
      bucketName: bucketNameForVideo,
      data,
    });
  }

  const toProcess = candidates.slice(offset, offset + limit);
  console.log(
    `Found ${toProcess.length} videos to migrate (total candidates: ${candidates.length}, limit=${limit}, offset=${offset}, dryRun=${dryRun})\n`
  );

  if (dryRun) {
    toProcess.forEach((v, i) =>
      console.log(`${i + 1}. ${v.id} (${v.userId}) -> ${v.storagePath}`)
    );
    return;
  }

  let succeeded = 0;
  let failed = 0;

  for (let i = 0; i < toProcess.length; i++) {
    const video = toProcess[i];
    const tempPath = path.join(os.tmpdir(), `migrate_mux_${video.id}.mp4`);

    try {
      console.log(`\n[${i + 1}/${toProcess.length}] ${video.id}`);

      if (!skipStatus) {
        await db.collection('videos').doc(video.id).set({
          status: 'processing',
          transcodingStatus: 'migrating_to_mux',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      console.log('  Creating Mux direct upload...');
      const { uploadUrl } = await createDirectUpload(video.id, video.userId);

      console.log('  Downloading from Storage...');
      const vidBucket = admin.storage().bucket(video.bucketName);
      const pathsToTry = [
        video.storagePath,
        `videos/${video.userId}/${video.id}_720p.mp4`,
        `videos/${video.userId}/${video.id}.mp4`,
      ];
      let downloaded = false;
      let lastErr = null;
      for (const p of pathsToTry) {
        try {
          await downloadFromBucket(vidBucket, p, tempPath);
          downloaded = true;
          break;
        } catch (err) {
          lastErr = err;
        }
      }
      if (!downloaded) {
        throw lastErr || new Error('File not found at any path');
      }

      const stat = fs.statSync(tempPath);
      console.log(`  Uploading to Mux (${(stat.size / 1024 / 1024).toFixed(2)} MB)...`);
      await uploadToMux(uploadUrl, tempPath);

      console.log('  Done. Mux webhook will update Firestore when processing completes.');
      succeeded++;
    } catch (err) {
      failed++;
      console.error('  Error:', err.message);
      if (!skipStatus) {
        await db.collection('videos').doc(video.id).set({
          transcodingStatus: 'migration_failed',
          transcodingError: err.message,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }
    } finally {
      try {
        if (fs.existsSync(tempPath)) fs.unlinkSync(tempPath);
      } catch (_) {}
    }
  }

  console.log(`\nDone. Succeeded: ${succeeded}, Failed: ${failed}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
