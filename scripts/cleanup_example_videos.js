#!/usr/bin/env node
/**
 * Delete example/seed videos from Firestore, keep user uploads.
 *
 * Identifies example videos by videoUrl containing known sample URLs:
 *   - commondatastorage.googleapis.com/gtv-videos-bucket
 *   - flutter.github.io/assets-for-api-docs
 *
 * Prerequisites:
 *   - GOOGLE_APPLICATION_CREDENTIALS set to service account JSON path
 *   - Or: service-account-key.json in project root
 *
 * Usage:
 *   node scripts/cleanup_example_videos.js --dry-run   # Preview only
 *   node scripts/cleanup_example_videos.js              # Delete
 */

const admin = require('firebase-admin');
const path = require('path');

const EXAMPLE_URL_PATTERNS = [
  'commondatastorage.googleapis.com/gtv-videos-bucket',
  'flutter.github.io/assets-for-api-docs',
  'samplelib.com',
];

function isExampleVideo(data) {
  const url =
    data.videoUrl ||
    data.videoURL ||
    data.video_url ||
    data.hlsUrl ||
    data.canonicalPlaybackUrl ||
    '';
  const urlStr = String(url).toLowerCase();
  return EXAMPLE_URL_PATTERNS.some((p) => urlStr.includes(p.toLowerCase()));
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const projectId = process.env.GCLOUD_PROJECT || 'streamerstip-6cfdb';
  const credsIdx = process.argv.indexOf('--creds');
  const credsPath =
    credsIdx >= 0 ? process.argv[credsIdx + 1] : null;

  let appOptions = { projectId };
  const keyPaths = credsPath
    ? [path.resolve(credsPath)]
    : [
        path.join(__dirname, '..', 'service-account.json'),
        path.join(__dirname, '..', 'service-account-key.json'),
        path.join(process.env.HOME || '', 'Documents', 'service-account.json'),
      ];
  let loaded = false;
  for (const keyPath of keyPaths) {
    try {
      const key = require(keyPath);
      appOptions.credential = admin.credential.cert(key);
      loaded = true;
      break;
    } catch {
      continue;
    }
  }
  if (!loaded && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    console.error(
      'Set GOOGLE_APPLICATION_CREDENTIALS or add service-account.json to project root'
    );
    process.exit(1);
  }

  if (!admin.apps.length) {
    admin.initializeApp(appOptions);
  }
  const db = admin.firestore();

  const snapshot = await db.collection('videos').get();
  const exampleIds = [];
  const userIds = [];

  for (const doc of snapshot.docs) {
    if (isExampleVideo(doc.data())) {
      exampleIds.push({ id: doc.id, ...doc.data() });
    } else {
      userIds.push(doc.id);
    }
  }

  console.log(`\n📊 Videos: ${snapshot.docs.length} total`);
  console.log(`   Example (to delete): ${exampleIds.length}`);
  console.log(`   User uploads (keep): ${userIds.length}\n`);

  if (exampleIds.length === 0) {
    console.log('✅ No example videos found.');
    return;
  }

  console.log('Example videos to delete:');
  exampleIds.forEach((v, i) => {
    const url = v.videoUrl || v.videoURL || v.video_url || '(no url)';
    const preview = String(url).length > 55 ? `${String(url).slice(0, 55)}...` : url;
    console.log(`   ${i + 1}. ${v.id} | ${preview}`);
  });

  if (dryRun) {
    console.log('\n🔒 Dry run — no changes made. Remove --dry-run to delete.');
    return;
  }

  const BATCH_SIZE = 500;
  let deleted = 0;
  for (let i = 0; i < exampleIds.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = exampleIds.slice(i, i + BATCH_SIZE);
    for (const v of chunk) {
      batch.delete(db.collection('videos').doc(v.id));
    }
    await batch.commit();
    deleted += chunk.length;
  }
  console.log(`\n✅ Deleted ${deleted} example videos.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
