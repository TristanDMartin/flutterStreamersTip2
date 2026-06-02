const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
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
    const aliceDb = env.authenticatedContext('alice').firestore();
    const bobDb = env.authenticatedContext('bob').firestore();

    console.log('✅ signed-in user can create their own interaction event');
    await assertSucceeds(
      aliceDb.collection('user_interactions').add({
        userId: 'alice',
        videoId: 'video_1',
        creatorId: 'creator_1',
        interactionType: 'watch_3s',
        watchPercentage: 0,
        timestamp: serverTimestamp(),
        metadata: {categoryId: 'tips'},
      }),
    );

    console.log('✅ signed-in user cannot spoof interaction ownership');
    await assertFails(
      aliceDb.collection('user_interactions').add({
        userId: 'bob',
        videoId: 'video_1',
        interactionType: 'skip',
        timestamp: serverTimestamp(),
      }),
    );

    console.log('✅ signed-in user can register their own FCM device token');
    await assertSucceeds(
      aliceDb
        .collection('users')
        .doc('alice')
        .collection('deviceTokens')
        .doc('token_alice')
        .set({
          token: 'token_alice',
          platform: 'ios',
          updatedAt: serverTimestamp(),
          source: 'test',
        }),
    );

    console.log('✅ signed-in user cannot write another user device token');
    await assertFails(
      bobDb
        .collection('users')
        .doc('alice')
        .collection('deviceTokens')
        .doc('token_bob')
        .set({
          token: 'token_bob',
          platform: 'android',
          updatedAt: serverTimestamp(),
        }),
    );

    console.log('✅ token field must match the token document id');
    await assertFails(
      aliceDb
        .collection('users')
        .doc('alice')
        .collection('deviceTokens')
        .doc('token_alice_doc')
        .set({
          token: 'different_token',
          platform: 'ios',
          updatedAt: serverTimestamp(),
        }),
    );

    console.log('✅ signed-in user can write and query their own bookmark edge');
    await assertSucceeds(
      aliceDb
        .collection('videos')
        .doc('video_1')
        .collection('bookmarks')
        .doc('alice')
        .set({
          userId: 'alice',
          videoId: 'video_1',
          bookmarkedAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
          source: 'rules_test',
        }),
    );
    await assertSucceeds(
      aliceDb.collectionGroup('bookmarks').where('userId', '==', 'alice').get(),
    );

    console.log('✅ signed-in user cannot spoof bookmark ownership');
    await assertFails(
      aliceDb
        .collection('videos')
        .doc('video_1')
        .collection('bookmarks')
        .doc('bob')
        .set({
          userId: 'bob',
          videoId: 'video_1',
          bookmarkedAt: serverTimestamp(),
        }),
    );

    console.log('✅ signed-in user can create their own session summary');
    await assertSucceeds(
      aliceDb.collection('user_sessions').add({
        userId: 'alice',
        startTime: serverTimestamp(),
        endTime: serverTimestamp(),
        sessionDuration: 42,
        videosWatched: 3,
        engagementActions: 1,
        retentionScore: 27.5,
      }),
    );

    console.log('✅ signed-in user cannot spoof session ownership');
    await assertFails(
      aliceDb.collection('user_sessions').add({
        userId: 'bob',
        startTime: serverTimestamp(),
        endTime: serverTimestamp(),
        sessionDuration: 42,
        videosWatched: 3,
        engagementActions: 1,
        retentionScore: 27.5,
      }),
    );
  } finally {
    await env.cleanup();
  }
}

run()
  .then(() => {
    console.log('✅ Interaction rules tests finished');
    process.exit(0);
  })
  .catch((err) => {
    console.error('❌ Interaction rules tests failed', err);
    process.exit(1);
  });
