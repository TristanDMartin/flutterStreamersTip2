const assert = require('assert');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({projectId: 'streamerstip-6cfdb'});
}

const {
  handleProgressionCallable,
  refreshUserProgressForUser,
} = require('./src/gamification/progression_callable');

const db = admin.firestore();

async function clearCollection(path) {
  const snap = await db.collection(path).get();
  const batch = db.batch();
  snap.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
}

async function clearProgression(uid) {
  const snap = await db.collection('users').doc(uid).collection('progression').get();
  const batch = db.batch();
  snap.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
}

async function seedFullyCompletedUser(uid) {
  await db.collection('users').doc(uid).set({
    avatarUrl: 'https://example.test/avatar.png',
    displayName: 'Progression Tester',
    username: 'progression_tester',
    bio: 'Testing the whole progression path.',
    liked_videos: ['video-1'],
  });
  await db.collection('videos').doc('video-1').set({
    userId: uid,
    creatorId: uid,
  });
  await db.collection('videos').doc('other-video').collection('comments').doc('comment-1').set({
    authorId: uid,
    text: 'First comment evidence',
  });
  await db.collection('users').doc(uid).collection('bookmarks').doc('video-1').set({
    userId: uid,
    videoId: 'video-1',
  });
  await db.collection('following').doc(uid).collection('users').doc('user-2').set({
    userId: 'user-2',
  });
  await db.collection('videos').doc('video-1').collection('likes').doc(uid).set({
    userId: uid,
    videoId: 'video-1',
  });
  await db.collection('chats').doc('chat-1').collection('messages').doc('message-1').set({
    senderId: uid,
    text: 'First message evidence',
  });
}

async function taskStates(uid) {
  const snap = await db.collection('users').doc(uid).collection('progression').get();
  return Object.fromEntries(snap.docs.map((doc) => [doc.id, doc.data()]));
}

async function main() {
  const uid = 'user-progress-1';
  const noEvidenceUid = 'user-no-evidence';
  const fromOnlyUid = 'user-from-only-message';
  await clearCollection('users');
  await clearCollection('videos');
  await clearCollection('following');
  await clearCollection('chats');

  await seedFullyCompletedUser(uid);
  await refreshUserProgressForUser(db, uid);

  const states = await taskStates(uid);
  const expectedTaskIds = [
    'profileCompleted',
    'firstPostCreated',
    'firstConnectionMade',
    'firstCommentMade',
    'firstBookmarkSaved',
    'firstLikeGiven',
    'firstMessageSent',
  ];
  for (const taskId of expectedTaskIds) {
    assert.strictEqual(states[taskId]?.completed, true, `${taskId} should be completed`);
    assert.strictEqual(states[taskId]?.xpReward, 50, `${taskId} should reward 50 XP`);
  }

  const userSnap = await db.collection('users').doc(uid).get();
  const userData = userSnap.data();
  assert.strictEqual(userData.totalXP, 350, 'totalXP should equal seven completed tasks');
  assert.strictEqual(userData.totalXp, 350, 'totalXp compatibility field should match');
  assert.strictEqual(userData.completedTaskCount, 7, 'completedTaskCount should match');
  assert.strictEqual(userData.level, 3, '350 XP should be level 3');
  assert.strictEqual(userData.rankName, 'Clip Builder', '350 XP should be Clip Builder');
  assert.strictEqual(userData.gamification.totalXp, 350, 'gamification.totalXp should match');
  assert.strictEqual(
    userData.progressionSummary.totalXP,
    350,
    'progressionSummary.totalXP should match',
  );
  assert.strictEqual(
    userData.progressionSummary.rankTitle,
    'Clip Builder',
    'progressionSummary.rankTitle should match',
  );
  assert.deepStrictEqual(
    userData.progressionSummary.completedTaskIds,
    expectedTaskIds,
    'progressionSummary.completedTaskIds should drive active task filtering',
  );
  assert.strictEqual(
    userData.progressionSummary.creatorScore,
    100,
    'fully completed user should have a max creator score',
  );
  assert.strictEqual(
    userData.progressionSummary.streakStatus,
    'Start today',
    'evidence refresh should not mark the daily streak active',
  );

  await refreshUserProgressForUser(db, uid);
  const afterSecondRefresh = (await db.collection('users').doc(uid).get()).data();
  assert.strictEqual(afterSecondRefresh.totalXP, 350, 'refresh should not double-award XP');
  assert.strictEqual(afterSecondRefresh.completedTaskCount, 7, 'refresh should not double-count tasks');
  assert.strictEqual(
    afterSecondRefresh.progressionSummary.totalXP,
    350,
    'summary refresh should not double-award XP',
  );

  await db.collection('users').doc(noEvidenceUid).set({
    displayName: 'No Evidence Yet',
  });
  const directResult = await handleProgressionCallable({
    auth: {uid: noEvidenceUid},
    data: {
      action: 'completeTask',
      taskId: 'firstCommentMade',
    },
  });
  assert.strictEqual(directResult.progress.reason, 'evidence_not_found');
  const noEvidenceStates = await taskStates(noEvidenceUid);
  assert.strictEqual(noEvidenceStates.firstCommentMade.completed, false);

  await db.collection('users').doc(fromOnlyUid).set({
    displayName: 'From Only Message',
  });
  await db.collection('chats').doc('chat-from-only').collection('messages').doc('message-1').set({
    from: fromOnlyUid,
    to: 'other-user',
    text: 'Message evidence written by ChatNotifier',
  });
  await handleProgressionCallable({
    auth: {uid: fromOnlyUid},
    data: {
      action: 'completeTask',
      taskId: 'firstMessageSent',
    },
  });
  const fromOnlyStates = await taskStates(fromOnlyUid);
  assert.strictEqual(fromOnlyStates.firstMessageSent.completed, true);

  await clearProgression(uid);
  await clearProgression(noEvidenceUid);
  await clearProgression(fromOnlyUid);
  await clearCollection('users');
  await clearCollection('videos');
  await clearCollection('following');
  await clearCollection('chats');
}

main()
  .then(() => {
    console.log('progression callable tests passed');
    process.exit(0);
  })
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
