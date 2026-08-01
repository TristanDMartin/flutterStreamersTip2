/**
 * Emulator tests: users/{uid} is owner-private; publicUsers is publicly readable.
 *
 * Uses the authoritative streamerstipReact firestore.rules contract.
 *
 * Run from flutterST/cloud_functions (has @firebase/rules-unit-testing):
 *   node users_privacy_rules_test.js
 *
 * Or:
 *   firebase emulators:exec --only firestore --project demo-users-privacy \
 *     "node cloud_functions/users_privacy_rules_test.js"
 */
const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');

const WEB_RULES = path.resolve(
  __dirname,
  '..',
  '..',
  'streamerstipReact',
  'firestore.rules',
);
const LOCAL_RULES = path.resolve(__dirname, '..', 'firestore.rules');

async function run() {
  const rulesPath = fs.existsSync(WEB_RULES) ? WEB_RULES : LOCAL_RULES;
  const rules = fs.readFileSync(rulesPath, 'utf8');
  console.log(`Using rules: ${rulesPath}`);

  const projectId = 'demo-users-privacy';
  const env = await initializeTestEnvironment({
    projectId,
    firestore: { rules },
  });

  const alice = 'alice_uid';
  const bob = 'bob_uid';

  try {
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('users').doc(alice).set({
        email: 'alice@example.com',
        stripeCustomerId: 'cus_secret_alice',
        subscriptionTier: 'studio',
        isAdmin: false,
        displayName: 'Alice',
      });
      await db.collection('users').doc(bob).set({
        email: 'bob@example.com',
        stripeCustomerId: 'cus_secret_bob',
        subscriptionTier: 'pro',
        displayName: 'Bob',
      });
      await db.collection('publicUsers').doc(alice).set({
        uid: alice,
        username: 'alice',
        displayName: 'Alice',
        avatarUrl: 'https://example.com/a.png',
      });
      await db.collection('publicUsers').doc(bob).set({
        uid: bob,
        username: 'bob',
        displayName: 'Bob',
        avatarUrl: 'https://example.com/b.png',
      });
    });

    const aliceDb = env.authenticatedContext(alice, {
      email_verified: true,
    }).firestore();
    const bobDb = env.authenticatedContext(bob, {
      email_verified: true,
    }).firestore();
    const signedOut = env.unauthenticatedContext().firestore();

    console.log('✅ owner can read own users/{uid}');
    await assertSucceeds(aliceDb.collection('users').doc(alice).get());

    console.log('✅ unrelated user cannot read users/{uid}');
    await assertFails(bobDb.collection('users').doc(alice).get());

    console.log('✅ signed-out cannot read users/{uid}');
    await assertFails(signedOut.collection('users').doc(alice).get());

    console.log('✅ owner cannot escalate subscriptionTier / isAdmin');
    await assertFails(
      aliceDb.collection('users').doc(alice).update({
        subscriptionTier: 'starter',
        isAdmin: true,
      }),
    );

    console.log('✅ anyone can read publicUsers/{uid}');
    await assertSucceeds(bobDb.collection('publicUsers').doc(alice).get());
    await assertSucceeds(signedOut.collection('publicUsers').doc(alice).get());

    console.log('All users privacy rules tests passed.');
  } finally {
    await env.cleanup();
  }
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
