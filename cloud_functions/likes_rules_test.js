const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
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
    const videoId = 'video_1777564297507_30ZA7hu7';
    const userId = 'alice';

    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('users').doc(userId).set({
        id: userId,
        username: userId,
        liked_videos: [],
      });
      await db.collection('videos').doc(videoId).set({
        id: videoId,
        userId: 'creator',
        caption: 'test clip',
        status: 'ready',
        likes: 1,
        likeCount: 1,
      });
    });

    const aliceDb = env.authenticatedContext(userId).firestore();
    const userRef = aliceDb.collection('users').doc(userId);
    const videoRef = aliceDb.collection('videos').doc(videoId);
    const likeRef = aliceDb
      .collection('likes')
      .doc(videoId)
      .collection('byUser')
      .doc(userId);
    const legacyLikedRef = userRef.collection('likedVideos').doc(videoId);

    console.log('✅ signed-in user can persist a like transaction');
    await assertSucceeds(
      aliceDb.runTransaction(async (transaction) => {
        transaction.set(
          likeRef,
          {
            userId,
            videoId,
            likedAt: serverTimestamp(),
            createdAt: serverTimestamp(),
          },
          {merge: true},
        );
        transaction.set(
          legacyLikedRef,
          {
            videoId,
            likedAt: serverTimestamp(),
          },
          {merge: true},
        );
        transaction.set(
          userRef,
          {
            liked_videos: [videoId],
            updatedAt: serverTimestamp(),
          },
          {merge: true},
        );
        transaction.update(videoRef, {
          likes: 2,
          likeCount: 2,
          updatedAt: serverTimestamp(),
        });
      }),
    );

    console.log('✅ signed-in user can reconcile drifted like counters');
    await env.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('videos').doc(videoId).update({
        likes: 1,
        likeCount: 2,
      });
    });
    await assertSucceeds(
      videoRef.update({
        likes: 3,
        likeCount: 3,
        updatedAt: serverTimestamp(),
      }),
    );

    console.log('✅ signed-in user can persist an unlike transaction');
    await assertSucceeds(
      aliceDb.runTransaction(async (transaction) => {
        transaction.delete(likeRef);
        transaction.delete(legacyLikedRef);
        transaction.set(
          userRef,
          {
            liked_videos: [],
            updatedAt: serverTimestamp(),
          },
          {merge: true},
        );
        transaction.update(videoRef, {
          likes: 2,
          likeCount: 2,
          updatedAt: serverTimestamp(),
        });
      }),
    );
  } finally {
    await env.cleanup();
  }
}

run()
  .then(() => {
    console.log('✅ Like rules tests finished');
    process.exit(0);
  })
  .catch((err) => {
    console.error('❌ Like rules tests failed', err);
    process.exit(1);
  });
