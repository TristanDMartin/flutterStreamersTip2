const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {serverTimestamp} = require('firebase/firestore');

async function run() {
  const projectId = 'demo-follows-tests';
  const rulesPath = path.join(__dirname, '..', 'firestore.rules');
  const rules = fs.readFileSync(rulesPath, 'utf8');

  const env = await initializeTestEnvironment({
    projectId,
    firestore: {rules},
  });

  try {
    const userA = env.authenticatedContext('userA');
    const userB = env.authenticatedContext('userB');
    const userC = env.authenticatedContext('userC'); // attacker/non-owner

    const dbA = userA.firestore();
    const dbB = userB.firestore();
    const dbC = userC.firestore();

    const follows = (db, id) => db.collection('follows').doc(id);

    // A follows B (UID-first)
    await assertSucceeds(
      follows(dbA, 'userA_userB').set({
        followerUserId: 'userA',
        targetUserId: 'userB',
        followerId: 'userA',
        followingId: 'userB',
        followedId: 'userB',
        isActive: true,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );

    // B follows A (mutual)
    await assertSucceeds(
      follows(dbB, 'userB_userA').set({
        followerUserId: 'userB',
        targetUserId: 'userA',
        followerId: 'userB',
        followingId: 'userA',
        followedId: 'userA',
        isActive: true,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );

    // Non-owner cannot update another user’s follow
    await assertFails(
      follows(dbC, 'userA_userB').update({
        isActive: false,
        updatedAt: serverTimestamp(),
      }),
    );

    // Owner can deactivate their follow
    await assertSucceeds(
      follows(dbA, 'userA_userB').update({
        isActive: false,
        updatedAt: serverTimestamp(),
      }),
    );

    // Non-owner cannot delete another user’s follow
    await assertFails(follows(dbC, 'userA_userB').delete());

    // Owner can delete their follow
    await assertSucceeds(follows(dbA, 'userA_userB').delete());
  } finally {
    await cleanup(env);
  }
}

async function cleanup(env) {
  try {
    await env.clearFirestore();
    await env.cleanup();
  } catch (e) {
    // ignore cleanup errors
  }
}

run()
  .then(() => {
    console.log('✅ E2E follows test finished');
    process.exit(0);
  })
  .catch((err) => {
    console.error('❌ E2E follows test failed', err);
    process.exit(1);
  });
