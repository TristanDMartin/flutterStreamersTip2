const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {serverTimestamp, increment} = require('firebase/firestore');

async function run() {
  const projectId = 'streamerstip-6cfdb';
  const rulesPath = path.join(__dirname, '..', 'firestore.rules');
  const rules = fs.readFileSync(rulesPath, 'utf8');

  const env = await initializeTestEnvironment({
    projectId,
    firestore: {rules},
  });

  try {
    const alice = env.authenticatedContext('alice');
    const bob = env.authenticatedContext('bob');

    const aliceDb = alice.firestore();
    const bobDb = bob.firestore();
    const comments = (db, videoId, commentId) =>
      db.collection('videos').doc(videoId).collection('comments').doc(commentId);

    const user = (uid) => ({
      id: uid,
      username: uid,
      displayName: uid,
      bio: null,
      avatarURL: null,
      onlineStatus: 'online',
      hashtags: [],
      postCount: 0,
      followerCount: 0,
      followingCount: 0,
    });

    const commentPayload = (uid, videoId, text, parentCommentId = null) => ({
      id: '',
      user: user(uid),
      text,
      timestamp: serverTimestamp(),
      likeCount: 0,
      isLiked: false,
      replies: [],
      videoId,
      userId: uid,
      authorId: uid,
      commenterId: uid,
      uid,
      username: uid,
      displayName: uid,
      authorName: uid,
      avatarURL: null,
      parentCommentId,
      likedBy: [],
      replyCount: 0,
    });

    console.log('✅ signed-in user can create a video comment');
    await assertSucceeds(
      comments(aliceDb, 'video_1777564297507_30ZA7hu7', 'comment1').set(
        commentPayload('alice', 'video_1777564297507_30ZA7hu7', 'hello'),
      ),
    );

    console.log('✅ signed-in user can create a reply comment');
    await assertSucceeds(
      comments(bobDb, 'video_1777564297507_30ZA7hu7', 'reply1').set(
        commentPayload(
          'bob',
          'video_1777564297507_30ZA7hu7',
          'reply',
          'comment1',
        ),
      ),
    );

    console.log('✅ signed-in user can update parent reply count');
    await assertSucceeds(
      comments(bobDb, 'video_1777564297507_30ZA7hu7', 'comment1').update({
        replyCount: increment(1),
        updatedAt: serverTimestamp(),
      }),
    );
  } finally {
    await env.cleanup();
  }
}

run()
  .then(() => {
    console.log('✅ Comment rules tests finished');
    process.exit(0);
  })
  .catch((err) => {
    console.error('❌ Comment rules tests failed', err);
    process.exit(1);
  });
