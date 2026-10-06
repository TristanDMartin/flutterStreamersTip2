const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');

const VERIFIED = {email_verified: true};
const ACTIVE_ADULT = {accountStatus: 'active', ageGate: {status: 'passed'}};

async function seed(env) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const uid of ['alice', 'bob', 'carol', 'mallory']) {
      await db.doc(`users/${uid}`).set({...ACTIVE_ADULT, bio: 'hi'});
    }
    await db.doc('users/bob/blockedUsers/mallory').set({blockedAt: 1});
    await db.doc('videos/v_bob').set({ownerId: 'bob', status: 'ready'});
    await db.doc('threads/t_bob').set({authorId: 'bob', title: 'x'});
  });
}

async function run() {
  const rules = fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8');
  const env = await initializeTestEnvironment({
    projectId: 'demo-wave2-rules',
    firestore: {rules},
  });
  const db = (uid) => env.authenticatedContext(uid, VERIFIED).firestore();
  const results = [];
  const check = async (name, promise) => {
    try {
      await promise;
      results.push(`ok ${name}`);
    } catch (err) {
      results.push(`FAIL ${name}: ${err.message}`);
    }
  };
  try {
    await seed(env);
    const alice = db('alice');
    const mallory = db('mallory');

    await check('owner can update profile bio', assertSucceeds(alice.doc('users/alice').update({bio: 'new'})));
    for (const field of ['totalXp', 'tippyCredits', 'creditsRemaining', 'progressionSummary', 'missions', 'level']) {
      await check(`owner cannot write ${field}`, assertFails(alice.doc('users/alice').update({[field]: 999})));
    }
    await check('owner cannot write subscription map',
        assertFails(alice.doc('users/alice').update({subscription: {tier: 'studio', status: 'active'}})));
    await check('owner cannot write stripeRole', assertFails(alice.doc('users/alice').update({stripeRole: 'studio'})));

    await check('forumNotification create allowed',
        assertSucceeds(alice.collection('forumNotifications').add({userId: 'bob', fromUserId: 'alice', type: 'thread_invite'})));
    await check('forumNotification spoofed sender denied',
        assertFails(alice.collection('forumNotifications').add({userId: 'bob', fromUserId: 'carol', type: 'x'})));
    await check('forumNotification to blocker denied',
        assertFails(mallory.collection('forumNotifications').add({userId: 'bob', fromUserId: 'mallory', type: 'x'})));
    await check('tag allowed', assertSucceeds(alice.collection('tags').add({taggerId: 'alice', taggedUserId: 'bob', videoId: 'v'})));
    await check('tag blocked pair denied',
        assertFails(mallory.collection('tags').add({taggerId: 'mallory', taggedUserId: 'bob', videoId: 'v'})));
    await check('mention blocked pair denied',
        assertFails(mallory.collection('mentions').add({mentionerId: 'mallory', mentionedUserId: 'bob', videoId: 'v'})));
    await check('shared draft allowed',
        assertSucceeds(alice.collection('shared_drafts').add({sharerId: 'alice', recipients: ['bob']})));
    await check('shared draft >50 recipients denied',
        assertFails(alice.collection('shared_drafts').add({sharerId: 'alice', recipients: Array.from({length: 51}, (_, i) => `u${i}`)})));

    await check('dm_ chat create allowed',
        assertSucceeds(alice.doc('chats/dm_alice_bob').set({participants: ['alice', 'bob']})));
    await check('non-dm 2-person chat denied',
        assertFails(alice.doc('chats/random123').set({participants: ['alice', 'carol']})));
    await check('group chat create denied',
        assertFails(alice.doc('chats/group1').set({participants: ['alice', 'bob', 'carol']})));
    await check('dm with blocker denied',
        assertFails(mallory.doc('chats/dm_bob_mallory').set({participants: ['bob', 'mallory']})));

    const followPayload = (from, to) => ({followerUserId: from, targetUserId: to, isActive: true});
    await check('follow allowed', assertSucceeds(alice.doc('follows/alice_bob').set(followPayload('alice', 'bob'))));
    await check('follow blocker denied', assertFails(mallory.doc('follows/mallory_bob').set(followPayload('mallory', 'bob'))));

    await check('like allowed',
        assertSucceeds(alice.doc('likes/v_bob/byUser/alice').set({userId: 'alice', videoId: 'v_bob'})));
    await check('like on blocker video denied',
        assertFails(mallory.doc('likes/v_bob/byUser/mallory').set({userId: 'mallory', videoId: 'v_bob'})));

    await check('thread reply allowed',
        assertSucceeds(alice.collection('threads/t_bob/replies').add({authorId: 'alice', text: 'hi'})));
    await check('thread reply to blocker denied',
        assertFails(mallory.collection('threads/t_bob/replies').add({authorId: 'mallory', text: 'hi'})));
    await check('thread reaction to blocker denied',
        assertFails(mallory.collection('threads/t_bob/reactions').add({userId: 'mallory', emoji: 'x'})));
  } finally {
    await env.cleanup();
  }
  results.forEach((line) => console.log(line));
  const failed = results.filter((line) => line.startsWith('FAIL'));
  if (failed.length) {
    console.error(`wave2_rules_test: ${failed.length} failed`);
    process.exit(1);
  }
  console.log('wave2_rules_test: all passed');
}

run();
