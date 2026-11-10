const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {serverTimestamp} = require('firebase/firestore');

async function run() {
  const projectId = 'streamerstip-6cfdb';
  const rulesPath = path.join(__dirname, '..', 'firestore.rules');
  const rules = fs.readFileSync(rulesPath, 'utf8');

  const env = await initializeTestEnvironment({
    projectId,
    firestore: {rules},
  });

  try {
    const userId = 'creator_uid';
    const videoId = 'video_optimistic_test';

    await env.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc(userId).set({
        id: userId,
        username: 'creator',
        accountStatus: 'active',
        ageGate: {status: 'passed'},
      });
    });

    const creatorDb = env.authenticatedContext(userId, {
      email_verified: true,
    }).firestore();

    console.log('✅ owner can create processing video placeholder');
    await assertSucceeds(
      creatorDb.collection('videos').doc(videoId).set({
        userId,
        creatorId: userId,
        creator_id: userId,
        caption: 'test upload',
        category: 'gaming',
        status: 'processing',
        createdAt: serverTimestamp(),
        duration: 0,
        fileSize: 0,
        metadata: {privacy: 'Everyone'},
      }),
    );

    console.log('✅ owner can update self-created placeholder (caption only)');
    await assertSucceeds(
      creatorDb.collection('videos').doc(videoId).update({
        caption: 'updated caption',
        updatedAt: serverTimestamp(),
      }),
    );

    const workerVideoId = 'video_worker_then_client';
    await env.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('videos').doc(workerVideoId).set({
        id: workerVideoId,
        userId,
        creatorId: userId,
        creator_id: userId,
        status: 'uploading',
        processingState: 'uploading',
        isReadyForFeed: false,
        videoUrl: '',
        thumbnailUrl: '',
        hasMuxPlaybackId: false,
        caption: '',
        hashtags: [],
        privacy: 'public',
        visibility: 'public',
        allowComments: true,
        category: 'general',
        views: 0,
        likes: 0,
        comments: 0,
        isMux: true,
        muxStatus: 'processing',
        muxUploadId: 'mux_upload_test',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    });

    console.log('✅ owner can update worker placeholder (caption only)');
    await assertSucceeds(
      creatorDb.collection('videos').doc(workerVideoId).update({
        caption: 'hello world',
        updatedAt: serverTimestamp(),
      }),
    );

    const muxFlowVideoId = 'video_optimistic_then_mux_callable';
    await env.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('videos').doc(muxFlowVideoId).set({
        userId,
        creatorId: userId,
        creator_id: userId,
        caption: 'test upload',
        category: 'gaming',
        categoryId: 'gaming',
        category_id: 'gaming',
        categories: ['gaming'],
        status: 'processing',
        duration: 0,
        fileSize: 0,
        metadata: {categoryOriginal: 'gaming', categoryCanonical: 'gaming'},
        visible: false,
        isReadyForFeed: false,
        isMux: true,
        muxStatus: 'processing',
        muxUploadId: 'mux_after_callable',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    });

    console.log('✅ owner can edit allowlisted metadata after mux callable');
    await assertSucceeds(
      creatorDb.collection('videos').doc(muxFlowVideoId).update({
        caption: 'hello world',
        description: 'hello world',
        title: 'Launch clip',
        hashtags: ['gaming'],
        privacy: 'Everyone',
        isPublic: true,
        allowComments: true,
        category: 'gaming',
        categoryId: 'gaming',
        thumbnailUrl: 'https://placehold.co/720x1280/1a1a2e/ffffff?text=Processing',
        updatedAt: serverTimestamp(),
      }),
    );

    console.log('❌ owner cannot change isReadyForFeed');
    await assertFails(
      creatorDb.collection('videos').doc(muxFlowVideoId).update({
        isReadyForFeed: true,
        updatedAt: serverTimestamp(),
      }),
    );

    console.log('❌ owner cannot spoof playback or counter fields');
    await assertFails(
      creatorDb.collection('videos').doc(muxFlowVideoId).update({
        muxPlaybackId: 'spoofed',
        canonicalPlaybackUrl: 'https://stream.mux.com/spoofed.m3u8',
        publishedAt: serverTimestamp(),
        views: 100,
        likes: 100,
        updatedAt: serverTimestamp(),
      }),
    );

    const webhookActiveVideoId = 'video_webhook_active_then_client';
    await env.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('videos').doc(webhookActiveVideoId).set({
        userId,
        creatorId: userId,
        creator_id: userId,
        status: 'active',
        visible: true,
        isReadyForFeed: true,
        playbackReady: true,
        hlsUrl: 'https://stream.mux.com/test.m3u8',
        muxPlaybackId: 'mux_playback_1',
        muxAssetId: 'mux_asset_1',
        caption: '',
        category: 'gaming',
        isMux: true,
        muxStatus: 'processing',
        muxUploadId: 'mux_upload_test',
      });
    });

    console.log('✅ owner can edit caption after the webhook marks the video ready');
    await assertSucceeds(
      creatorDb.collection('videos').doc(webhookActiveVideoId).update({
        caption: 'final caption',
        updatedAt: serverTimestamp(),
      }),
    );

    console.log('❌ owner cannot clear isReadyForFeed after the webhook');
    await assertFails(
      creatorDb.collection('videos').doc(webhookActiveVideoId).update({
        caption: 'final caption',
        isReadyForFeed: false,
        updatedAt: serverTimestamp(),
      }),
    );

    console.log('❌ client cannot mark the canonical video failed');
    await assertFails(
      creatorDb.collection('videos').doc(muxFlowVideoId).set(
        {
          userId,
          creatorId: userId,
          creator_id: userId,
          status: 'failed',
          visible: false,
          isReadyForFeed: false,
          uploadError: 'test failure',
          updatedAt: serverTimestamp(),
        },
        {merge: true},
      ),
    );

    console.log('❌ client cannot merge server-owned processing fields');
    await assertFails(
      creatorDb.collection('videos').doc(workerVideoId).set(
        {
          caption: 'hello world',
          status: 'processing',
          isReadyForFeed: false,
          muxUploadId: 'mux_upload_test',
          views: 0,
          likes: 0,
          updatedAt: serverTimestamp(),
        },
        {merge: true},
      ),
    );

    const strangerDb = env.authenticatedContext('stranger_uid', {
      email_verified: true,
    }).firestore();
    console.log('❌ another creator cannot edit the video');
    await assertFails(
      strangerDb.collection('videos').doc(webhookActiveVideoId).update({
        caption: 'stolen',
        updatedAt: serverTimestamp(),
      }),
    );

    console.log('✅ owner can tombstone with the soft-delete patch');
    await assertSucceeds(
      creatorDb.collection('videos').doc(webhookActiveVideoId).update({
        status: 'deleted',
        isDeleted: true,
        deletedAt: serverTimestamp(),
        deletedBy: userId,
        updatedAt: serverTimestamp(),
      }),
    );

    const readyVideoId = 'video_ready_tombstone_gate';
    await env.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('videos').doc(readyVideoId).set({
        userId,
        creatorId: userId,
        status: 'ready',
        isReadyForFeed: true,
        caption: 'live',
      });
    });
    console.log('❌ tombstone cannot also change isReadyForFeed');
    await assertFails(
      creatorDb.collection('videos').doc(readyVideoId).update({
        status: 'deleted',
        isDeleted: true,
        isReadyForFeed: false,
        updatedAt: serverTimestamp(),
      }),
    );

    const orphanVideoId = 'video_orphan_no_user';
    await env.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('videos').doc(orphanVideoId).set({
        id: orphanVideoId,
        status: 'uploading',
        muxUploadId: 'mux_orphan',
      });
    });
    console.log('❌ owner cannot update orphan video (no userId on doc)');
    await assertFails(
      creatorDb.collection('videos').doc(orphanVideoId).update({
        caption: 'fix',
        status: 'processing',
        updatedAt: serverTimestamp(),
      }),
    );

    console.log('All video rules tests passed.');
  } finally {
    await env.cleanup();
  }
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
