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
    const alice = env.authenticatedContext('alice');
    const bob = env.authenticatedContext('bob');
    const charlie = env.authenticatedContext('charlie');

    const aliceDb = alice.firestore();
    const bobDb = bob.firestore();
    const charlieDb = charlie.firestore();

    const follows = (db, id) => db.collection('follows').doc(id);

    const validPayload = {
      followerUserId: 'alice',
      targetUserId: 'bob',
      followerId: 'alice',
      followingId: 'bob',
      followedId: 'bob',
      isActive: true,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };

    const uidFirstOnly = {
      followerUserId: 'alice',
      targetUserId: 'bob',
      isActive: true,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };

    console.log('✅ should allow UID-first create with matching doc id');
    await assertSucceeds(follows(aliceDb, 'alice_bob').set(validPayload));

    console.log('❌ should deny create when doc id does not match follower_target');
    await assertFails(follows(aliceDb, 'alice_bob_extra').set(uidFirstOnly));

    console.log('❌ should deny create when follower == target (self follow)');
    await assertFails(
      follows(aliceDb, 'alice_alice').set({
        followerUserId: 'alice',
        targetUserId: 'alice',
        isActive: true,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );

    console.log('❌ should deny create when isActive is false');
    await assertFails(
      follows(aliceDb, 'alice_bob_false').set({
        ...validPayload,
        isActive: false,
      }),
    );

    console.log('✅ should allow update by follower to toggle isActive');
    await assertSucceeds(
      follows(aliceDb, 'alice_bob').update({
        isActive: false,
        updatedAt: serverTimestamp(),
      }),
    );

    console.log('❌ should deny update by non-follower');
    await assertFails(
      follows(charlieDb, 'alice_bob').update({
        isActive: true,
        updatedAt: serverTimestamp(),
      }),
    );

    console.log('✅ should allow legacy create path (followerId/followingId only)');
    await assertSucceeds(
      follows(bobDb, 'bob_charlie').set({
        followerId: 'bob',
        followingId: 'charlie',
        isActive: true,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  } finally {
    await cleanupEmulators();
  }

  async function cleanupEmulators() {
    try {
      await (await import('@firebase/rules-unit-testing')).cleanup();
    } catch (e) {
      // ignore cleanup errors
    }
  }
}

run()
  .then(() => {
    console.log('✅ Tests finished');
    process.exit(0);
  })
  .catch((err) => {
    console.error('❌ Tests failed', err);
    process.exit(1);
  });
