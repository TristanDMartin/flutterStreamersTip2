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
      });
    });

    const creatorDb = env.authenticatedContext(userId).firestore();

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

    console.log('✅ owner can update after optimistic + mux callable merge');
    await assertSucceeds(
      creatorDb.collection('videos').doc(muxFlowVideoId).update({
        caption: 'hello world',
        hashtags: ['gaming'],
        privacy: 'Everyone',
        visibility: 'public',
        allowComments: true,
        category: 'gaming',
        categoryId: 'gaming',
        category_id: 'gaming',
        categories: ['gaming'],
        updatedAt: serverTimestamp(),
        thumbnailUrl: 'https://placehold.co/720x1280/1a1a2e/ffffff?text=Processing',
        thumbnails: {
          urls: {
            '360': 'https://placehold.co/720x1280/1a1a2e/ffffff?text=Processing',
            '540': 'https://placehold.co/720x1280/1a1a2e/ffffff?text=Processing',
            '720': 'https://placehold.co/720x1280/1a1a2e/ffffff?text=Processing',
          },
          generatedAt: serverTimestamp(),
        },
        status: 'processing',
        visible: false,
        isReadyForFeed: false,
        sourcePlatform: 'app',
        isMux: true,
        muxStatus: 'processing',
        muxUploadId: 'mux_after_callable',
        views: 0,
        likes: 0,
        comments: 0,
        shares: 0,
        moderation: {
          approved: true,
          checkedAt: serverTimestamp(),
          confidence: 1.0,
          violations: [],
        },
        metadata: {
          fileSize: 2086084,
          duration: 11,
          resolution: '1080x1920',
          format: 'mp4',
          uploadedAt: serverTimestamp(),
          categoryOriginal: 'gaming',
          categoryCanonical: 'gaming',
        },
        cross_platform_sharing: [],
        watermark_applied: false,
        moderation_confidence: 1.0,
        moderation_checked_at: '2026-05-21T00:03:43.589700',
        duration: 11,
        fileSize: 2086084,
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

    console.log('✅ owner can update after mux webhook activated doc');
    await assertSucceeds(
      creatorDb.collection('videos').doc(webhookActiveVideoId).update({
        caption: 'final caption',
        updatedAt: serverTimestamp(),
        status: 'processing',
        visible: false,
        isReadyForFeed: false,
      }),
    );

    console.log('✅ owner can mark upload failed via merge (includes owner ids)');
    await assertSucceeds(
      creatorDb.collection('videos').doc(muxFlowVideoId).set(
        {
          userId,
          creatorId: userId,
          creator_id: userId,
          status: 'failed',
          visible: false,
          isReadyForFeed: false,
          uploadError: 'test failure',
          errorMessage: 'test failure',
          muxStatus: 'failed',
          updatedAt: serverTimestamp(),
        },
        {merge: true},
      ),
    );

    console.log('✅ owner can merge worker placeholder (full client metadata)');
    await assertSucceeds(
      creatorDb.collection('videos').doc(workerVideoId).set(
        {
          userId,
          creatorId: userId,
          creator_id: userId,
          caption: 'hello world',
          hashtags: ['gaming'],
          privacy: 'Everyone',
          visibility: 'public',
          allowComments: true,
          category: 'gaming',
          categoryId: 'gaming',
          category_id: 'gaming',
          categories: ['gaming'],
          updatedAt: serverTimestamp(),
          thumbnailUrl:
            'https://placehold.co/720x1280/1a1a2e/ffffff?text=Processing',
          thumbnails: {
            urls: {
              '360':
                'https://placehold.co/720x1280/1a1a2e/ffffff?text=Processing',
              '540':
                'https://placehold.co/720x1280/1a1a2e/ffffff?text=Processing',
              '720':
                'https://placehold.co/720x1280/1a1a2e/ffffff?text=Processing',
            },
            generatedAt: serverTimestamp(),
          },
          status: 'processing',
          visible: false,
          isReadyForFeed: false,
          sourcePlatform: 'app',
          isMux: true,
          muxStatus: 'processing',
          muxUploadId: 'mux_upload_test',
          views: 0,
          likes: 0,
          comments: 0,
          shares: 0,
          moderation: {
            approved: true,
            checkedAt: serverTimestamp(),
            confidence: 1.0,
            violations: [],
          },
          metadata: {
            fileSize: 4884475,
            duration: 18,
            resolution: '1080x1920',
            format: 'mp4',
            uploadedAt: serverTimestamp(),
            categoryOriginal: 'gaming',
            categoryCanonical: 'gaming',
          },
          cross_platform_sharing: [],
          watermark_applied: false,
          moderation_confidence: 1.0,
          moderation_checked_at: '2026-05-20T22:24:44.058299',
          duration: 18,
          fileSize: 4884475,
        },
        {merge: true},
      ),
    );

    console.log('✅ owner can update worker placeholder (full client metadata)');
    await assertSucceeds(
      creatorDb.collection('videos').doc(workerVideoId).update({
        caption: 'hello world',
        hashtags: ['gaming'],
        privacy: 'Everyone',
        visibility: 'public',
        allowComments: true,
        category: 'gaming',
        categoryId: 'gaming',
        category_id: 'gaming',
        categories: ['gaming'],
        updatedAt: serverTimestamp(),
        thumbnailUrl: 'https://placehold.co/720x1280/1a1a2e/ffffff?text=Processing',
        thumbnails: {
          urls: {
            '360': 'https://placehold.co/720x1280/1a1a2e/ffffff?text=Processing',
            '540': 'https://placehold.co/720x1280/1a1a2e/ffffff?text=Processing',
            '720': 'https://placehold.co/720x1280/1a1a2e/ffffff?text=Processing',
          },
          generatedAt: serverTimestamp(),
        },
        status: 'processing',
        visible: false,
        isReadyForFeed: false,
        sourcePlatform: 'app',
        isMux: true,
        muxStatus: 'processing',
        muxUploadId: 'mux_upload_test',
        views: 0,
        likes: 0,
        comments: 0,
        shares: 0,
        moderation: {
          approved: true,
          checkedAt: serverTimestamp(),
          confidence: 1.0,
          violations: [],
        },
        metadata: {
          fileSize: 4884475,
          duration: 18,
          resolution: '1080x1920',
          format: 'mp4',
          uploadedAt: serverTimestamp(),
          categoryOriginal: 'gaming',
          categoryCanonical: 'gaming',
        },
        cross_platform_sharing: [],
        watermark_applied: false,
        moderation_confidence: 1.0,
        moderation_checked_at: '2026-05-20T22:24:44.058299',
        duration: 18,
        fileSize: 4884475,
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
