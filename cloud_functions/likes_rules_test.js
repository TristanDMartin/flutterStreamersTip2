const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {serverTimestamp} = require('firebase/firestore');

const VERIFIED = {email_verified: true};
const ACTIVE_ADULT = {
  accountStatus: 'active',
  ageGate: {status: 'passed'},
};

function permissionMessage(err) {
  return String(err && (err.message || err));
}

async function assertDeniedCleanly(promise, label) {
  try {
    await promise;
  } catch (err) {
    const message = permissionMessage(err);
    if (message.includes('email_verified is undefined')) {
      throw new Error(`${label} threw on a missing email_verified claim: ${message}`);
    }
    if (message.includes('1000 expressions')) {
      throw new Error(`${label} exceeded the rules expression budget: ${message}`);
    }
    if (err.code !== 'permission-denied' && !message.includes('PERMISSION_DENIED')) {
      throw err;
    }
    return;
  }
  throw new Error(`${label} was allowed`);
}

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
    const creatorId = 'creator';

    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('users').doc(userId).set({
        id: userId,
        ...ACTIVE_ADULT,
      });
      await db.collection('users').doc(creatorId).set({
        id: creatorId,
        ...ACTIVE_ADULT,
      });
      await db.collection('users').doc('minor').set({
        id: 'minor',
        accountStatus: 'active',
        ageGate: {status: 'under_minimum_age'},
      });
      await db.collection('videos').doc(videoId).set({
        id: videoId,
        userId: creatorId,
        ownerId: creatorId,
        caption: 'test clip',
        status: 'ready',
        likes: 1,
        likeCount: 1,
      });
    });

    const aliceDb = env.authenticatedContext(userId, VERIFIED).firestore();
    const unverifiedDb = env.authenticatedContext(userId).firestore();
    const minorDb = env.authenticatedContext('minor', VERIFIED).firestore();
    const videoRef = aliceDb.collection('videos').doc(videoId);
    const likeEdge = aliceDb
      .collection('likes')
      .doc(videoId)
      .collection('byUser')
      .doc(userId);
    const videoLikeEdge = videoRef.collection('likes').doc(userId);
    const likedVideoRef = aliceDb
      .collection('users')
      .doc(userId)
      .collection('likedVideos')
      .doc(videoId);

    console.log('✅ verified adult can persist the mobile like transaction');
    await assertSucceeds(
      aliceDb.runTransaction(async (transaction) => {
        const payload = {
          userId,
          videoId,
          likedAt: serverTimestamp(),
          createdAt: serverTimestamp(),
        };
        transaction.set(videoLikeEdge, payload, {merge: true});
        transaction.set(likeEdge, payload, {merge: true});
        transaction.set(
          likedVideoRef,
          {
            videoId,
            userId,
            likedAt: serverTimestamp(),
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

    console.log('✅ verified adult can reconcile a drifted like counter by +1');
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

    console.log('✅ verified adult can persist the mobile unlike transaction');
    await assertSucceeds(
      aliceDb.runTransaction(async (transaction) => {
        transaction.delete(videoLikeEdge);
        transaction.delete(likeEdge);
        transaction.delete(likedVideoRef);
        transaction.update(videoRef, {
          likes: 2,
          likeCount: 2,
          updatedAt: serverTimestamp(),
        });
      }),
    );

    console.log('✅ missing email_verified denies profile writes without a rules crash');
    await assertDeniedCleanly(
      unverifiedDb.collection('users').doc(userId).update({
        bio: 'unverified write',
        updatedAt: serverTimestamp(),
      }),
      'unverified profile update',
    );

    console.log('✅ verified user cannot write another account like edge');
    await assertDeniedCleanly(
      aliceDb
        .collection('likes')
        .doc(videoId)
        .collection('byUser')
        .doc(creatorId)
        .set({
          userId: creatorId,
          videoId,
          likedAt: serverTimestamp(),
          createdAt: serverTimestamp(),
        }),
      'spoofed like edge',
    );

    console.log('✅ under-minimum-age account cannot create a like');
    await assertDeniedCleanly(
      minorDb
        .collection('likes')
        .doc(videoId)
        .collection('byUser')
        .doc('minor')
        .set({
          userId: 'minor',
          videoId,
          likedAt: serverTimestamp(),
          createdAt: serverTimestamp(),
        }),
      'under-minimum-age like',
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
