const admin = require('firebase-admin');
const {HttpsError} = require('firebase-functions/v2/https');
const {maybeSendLevelUpNotification} = require('./progression_notifications');
const {levelRowForTotalXp} = require('./level_table');
const {syncGamificationState} = require('./gamification_state');
const {streakFromStoredFields} = require('./daily_qualification');

const FieldValue = admin.firestore.FieldValue;

const TASKS = [
  {
    id: 'profileCompleted',
    xpReward: 50,
    priority: 10,
    source: 'users',
  },
  {
    id: 'firstPostCreated',
    xpReward: 50,
    priority: 20,
    source: 'videos',
  },
  {
    id: 'firstConnectionMade',
    xpReward: 50,
    priority: 30,
    source: 'connections',
  },
  {
    id: 'firstCommentMade',
    xpReward: 50,
    priority: 40,
    source: 'comments',
  },
  {
    id: 'firstBookmarkSaved',
    xpReward: 50,
    priority: 50,
    source: 'bookmarks',
  },
  {
    id: 'firstLikeGiven',
    xpReward: 50,
    priority: 60,
    source: 'likes',
  },
  {
    id: 'firstMessageSent',
    xpReward: 50,
    priority: 70,
    source: 'messages',
  },
];

const TASKS_BY_ID = Object.fromEntries(TASKS.map((task) => [task.id, task]));

function readInt(value, fallback = 0) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === 'string') {
    const parsed = parseInt(value, 10);
    return Number.isNaN(parsed) ? fallback : parsed;
  }
  return fallback;
}

function hasString(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function levelForXp(totalXp) {
  return levelRowForTotalXp(totalXp);
}

function scoreForEvidence(evidence, completedTaskIds) {
  const score =
    (evidence.profileCompleted && evidence.profileCompleted.completed ? 20 : 0) +
    (evidence.firstPostCreated && evidence.firstPostCreated.completed ? 20 : 0) +
    (evidence.firstCommentMade && evidence.firstCommentMade.completed ? 10 : 0) +
    (evidence.firstLikeGiven && evidence.firstLikeGiven.completed ? 10 : 0) +
    (evidence.firstBookmarkSaved && evidence.firstBookmarkSaved.completed ? 10 : 0) +
    (evidence.firstConnectionMade && evidence.firstConnectionMade.completed ? 15 : 0) +
    (evidence.firstMessageSent && evidence.firstMessageSent.completed ? 15 : 0);
  return Math.max(score, Math.min(100, completedTaskIds.length * 12));
}

function streakForUserData(userData) {
  return streakFromStoredFields(userData);
}

function safeSource(source, fallback) {
  if (typeof source !== 'string') return fallback;
  const trimmed = source.trim();
  return trimmed.length > 0 && trimmed.length <= 80 ? trimmed : fallback;
}

function userRef(db, uid) {
  return db.collection('users').doc(uid);
}

function progressionRef(db, uid, taskId) {
  return userRef(db, uid).collection('progression').doc(taskId);
}

async function hasAny(query) {
  const snap = await query.limit(1).get();
  return !snap.empty;
}

async function any(checks) {
  for (const check of checks) {
    try {
      if (await check()) return true;
    } catch (err) {
      console.warn('progression evidence query skipped', err.message || err);
    }
  }
  return false;
}

function q(query) {
  return () => hasAny(query);
}

async function hasArrayItem(db, uid, fieldNames) {
  const snap = await userRef(db, uid).get();
  const data = snap.exists ? snap.data() || {} : {};
  return fieldNames.some((field) => Array.isArray(data[field]) && data[field].length > 0);
}

async function profileEvidence(db, uid) {
  const snap = await userRef(db, uid).get();
  const data = snap.exists ? snap.data() || {} : {};
  const completed =
    hasString(data.avatarUrl || data.avatarURL || data.photoURL) &&
    hasString(data.displayName) &&
    hasString(data.username) &&
    hasString(data.bio);
  return {completed, source: 'users'};
}

async function postEvidence(db, uid) {
  const completed = await any([
    q(db.collection('videos').where('userId', '==', uid)),
    q(db.collection('videos').where('creatorId', '==', uid)),
    q(userRef(db, uid).collection('videos')),
  ]);
  return {completed, source: 'videos'};
}

async function commentEvidence(db, uid) {
  const completed = await any([
    q(db.collectionGroup('comments').where('authorId', '==', uid)),
    q(db.collectionGroup('comments').where('userId', '==', uid)),
    q(db.collectionGroup('comments').where('commenterId', '==', uid)),
    q(db.collectionGroup('comments').where('uid', '==', uid)),
    q(db.collectionGroup('comments').where('author.uid', '==', uid)),
    q(db.collectionGroup('comments').where('author.id', '==', uid)),
    q(db.collectionGroup('comments').where('user.uid', '==', uid)),
    q(db.collectionGroup('comments').where('user.id', '==', uid)),
    q(db.collection('comments').where('authorId', '==', uid)),
    q(db.collection('comments').where('userId', '==', uid)),
    q(db.collection('comments').where('commenterId', '==', uid)),
    q(db.collection('comments').where('uid', '==', uid)),
    q(db.collection('comments').where('author.uid', '==', uid)),
    q(db.collection('comments').where('author.id', '==', uid)),
    q(db.collection('comments').where('user.uid', '==', uid)),
    q(db.collection('comments').where('user.id', '==', uid)),
    q(db.collection('video_engagement')
      .where('type', '==', 'comment')
      .where('commenterId', '==', uid)),
  ]);
  return {completed, source: 'comments'};
}

async function bookmarkEvidence(db, uid) {
  const completed = await any([
    q(db.collection('bookmarks').where('userId', '==', uid)),
    q(userRef(db, uid).collection('bookmarks')),
    q(userRef(db, uid).collection('favorites')),
    q(db.collectionGroup('bookmarks').where('userId', '==', uid)),
    q(db.collection('user_favorites').doc(uid).collection('videos')),
  ]);
  return {completed, source: 'bookmarks'};
}

async function connectionEvidence(db, uid) {
  const completed = await any([
    q(db.collection('following').doc(uid).collection('users')),
    q(db.collection('followers').doc(uid).collection('users')),
    q(userRef(db, uid).collection('following')),
    q(userRef(db, uid).collection('followers')),
    q(db.collection('follows').where('followerId', '==', uid)),
    q(db.collection('follows').where('followingId', '==', uid)),
  ]);
  return {completed, source: 'connections'};
}

async function likeEvidence(db, uid) {
  const completed = await any([
    () => hasArrayItem(db, uid, ['liked_videos', 'likedVideos']),
    q(userRef(db, uid).collection('likedVideos')),
    q(userRef(db, uid).collection('liked_videos')),
    q(db.collection('likes').where('userId', '==', uid)),
    q(db.collectionGroup('likes').where('userId', '==', uid)),
    q(db.collectionGroup('byUser').where('userId', '==', uid)),
  ]);
  return {completed, source: 'likes'};
}

async function messageEvidence(db, uid) {
  const completed = await any([
    q(db.collection('messages').where('senderId', '==', uid)),
    q(db.collection('messages').where('from', '==', uid)),
    q(db.collection('messages').where('fromId', '==', uid)),
    q(db.collection('messages').where('sharerId', '==', uid)),
    q(db.collectionGroup('messages').where('senderId', '==', uid)),
    q(db.collectionGroup('messages').where('from', '==', uid)),
    q(db.collectionGroup('messages').where('fromId', '==', uid)),
    q(db.collectionGroup('messages').where('sharerId', '==', uid)),
    q(db.collection('shared_drafts').where('sharerId', '==', uid)),
    q(db.collection('sharedDrafts').where('sharerId', '==', uid)),
    q(db.collectionGroup('shared_drafts').where('sharerId', '==', uid)),
    q(db.collectionGroup('sharedDrafts').where('sharerId', '==', uid)),
    q(db.collection('draft_shares').where('sharerId', '==', uid)),
    q(db.collection('draftShares').where('sharerId', '==', uid)),
  ]);
  return {completed, source: 'messages'};
}

async function collectEvidence(db, uid) {
  const results = await Promise.all([
    profileEvidence(db, uid),
    postEvidence(db, uid),
    connectionEvidence(db, uid),
    commentEvidence(db, uid),
    bookmarkEvidence(db, uid),
    likeEvidence(db, uid),
    messageEvidence(db, uid),
  ]);
  return {
    profileCompleted: results[0],
    firstPostCreated: results[1],
    firstConnectionMade: results[2],
    firstCommentMade: results[3],
    firstBookmarkSaved: results[4],
    firstLikeGiven: results[5],
    firstMessageSent: results[6],
  };
}

async function evidenceForTask(db, uid, taskId) {
  switch (taskId) {
    case 'profileCompleted':
      return profileEvidence(db, uid);
    case 'firstPostCreated':
      return postEvidence(db, uid);
    case 'firstConnectionMade':
      return connectionEvidence(db, uid);
    case 'firstCommentMade':
      return commentEvidence(db, uid);
    case 'firstBookmarkSaved':
      return bookmarkEvidence(db, uid);
    case 'firstLikeGiven':
      return likeEvidence(db, uid);
    case 'firstMessageSent':
      return messageEvidence(db, uid);
    default:
      throw new HttpsError('invalid-argument', `Unknown progression task: ${taskId}`);
  }
}

async function completeTaskForUser(db, uid, taskId, source) {
  const task = TASKS_BY_ID[taskId];
  if (!task) {
    throw new HttpsError('invalid-argument', `Unknown progression task: ${taskId}`);
  }

  const taskRef = progressionRef(db, uid, taskId);
  const userDocRef = userRef(db, uid);
  const beforeUserSnap = await userDocRef.get();
  const previousLevel = beforeUserSnap.exists ? readInt((beforeUserSnap.data() || {}).level, 1) : 1;
  let completedNow = false;

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(taskRef);
    const userSnapTx = await tx.get(userDocRef);
    if (snap.exists && snap.data() && snap.data().completed === true) {
      return;
    }
    completedNow = true;
    const userDataTx = userSnapTx.exists ? userSnapTx.data() || {} : {};
    const gamTx =
      userDataTx.gamification && typeof userDataTx.gamification === 'object'
        ? userDataTx.gamification
        : {};
    const currentXp =
      readInt(gamTx.totalXp) ||
      readInt(gamTx.totalXP) ||
      readInt(userDataTx.totalXp) ||
      readInt(userDataTx.totalXP);
    const nextXp = currentXp + task.xpReward;
    tx.set(taskRef, {
      taskId: task.id,
      completed: true,
      xpReward: task.xpReward,
      completedAt: FieldValue.serverTimestamp(),
      source: safeSource(source, task.source),
      checkedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    // Award into global XP once; never replace Worker/mission totals later.
    tx.set(userDocRef, {
      totalXP: nextXp,
      totalXp: nextXp,
      completedTaskCount: FieldValue.increment(1),
      gamification: {
        ...gamTx,
        totalXp: nextXp,
        totalXP: nextXp,
      },
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  });

  const summary = await recalculateUserProgressSummary(db, uid);
  if (completedNow) {
    await maybeSendLevelUpNotification(db, uid, previousLevel, summary);
  }
  return {completedNow};
}

async function markIncompleteIfNeeded(db, uid, taskId, source) {
  const task = TASKS_BY_ID[taskId];
  if (!task) return;
  const taskRef = progressionRef(db, uid, taskId);
  const snap = await taskRef.get();
  if (snap.exists && snap.data() && snap.data().completed === true) return;
  await taskRef.set({
    taskId,
    completed: false,
    xpReward: task.xpReward,
    source: safeSource(source, task.source),
    checkedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
}

async function recalculateUserProgressSummary(db, uid) {
  const userDocRef = userRef(db, uid);
  const [snap, userSnap, evidence] = await Promise.all([
    userDocRef.collection('progression').get(),
    userDocRef.get(),
    collectEvidence(db, uid),
  ]);
  const userData = userSnap.exists ? userSnap.data() || {} : {};
  let onboardingXp = 0;
  let completedTaskCount = 0;
  const completedTaskIds = [];
  for (const doc of snap.docs) {
    const data = doc.data() || {};
    if (data.completed !== true) continue;
    completedTaskCount += 1;
    completedTaskIds.push(doc.id);
    const task = TASKS_BY_ID[doc.id];
    onboardingXp += readInt(data.xpReward, task ? task.xpReward : 0);
  }
  completedTaskIds.sort((a, b) => {
    const taskA = TASKS_BY_ID[a];
    const taskB = TASKS_BY_ID[b];
    return readInt(taskA && taskA.priority, 999) - readInt(taskB && taskB.priority, 999);
  });
  const creatorScore = scoreForEvidence(evidence, completedTaskIds);
  const streak = streakForUserData(userData);
  const existingGam =
    userData.gamification && typeof userData.gamification === 'object'
      ? userData.gamification
      : {};
  // Global XP is Worker/events + one-time onboarding increments — never the
  // onboarding task sum alone (that was wiping mission XP on every refresh).
  const globalXp =
    readInt(existingGam.totalXp) ||
    readInt(existingGam.totalXP) ||
    readInt(userData.totalXp) ||
    readInt(userData.totalXP) ||
    onboardingXp;
  const levelRow = levelForXp(globalXp);
  const onboardingLevelRow = levelForXp(onboardingXp);
  const progressionSummary = {
    totalXP: onboardingXp,
    totalXp: onboardingXp,
    creatorScore,
    level: onboardingLevelRow.level,
    rankTitle: onboardingLevelRow.rankName,
    rankName: onboardingLevelRow.rankName,
    streakCount: streak.streakCount,
    streakDays: streak.streakCount,
    streakStatus: streak.streakStatus,
    streakLabel: streak.streakLabel,
    lastActiveDate: streak.lastActiveDate,
    completedTaskIds,
    completedTaskCount,
    updatedAt: FieldValue.serverTimestamp(),
  };
  await userDocRef.set({
    creatorScore,
    streakCount: streak.streakCount,
    streakDays: streak.streakCount,
    lastActiveDate: streak.lastActiveDate,
    completedTaskCount,
    progressionSummary,
    updatedAt: FieldValue.serverTimestamp(),
    gamification: {
      ...existingGam,
      creatorScore,
      streakDays: streak.streakCount,
      streakCount: streak.streakCount,
      streakStatus: streak.streakStatus,
      streakLabel: streak.streakLabel,
      lastActiveDate: streak.lastActiveDate,
      updatedAt: FieldValue.serverTimestamp(),
    },
  }, {merge: true});
  await syncGamificationState(db, uid);
  return {
    totalXP: globalXp,
    onboardingXp,
    level: levelRow.level,
    rankName: levelRow.rankName,
    rankTitle: levelRow.rankName,
    creatorScore,
    streakCount: streak.streakCount,
    lastActiveDate: streak.lastActiveDate,
    completedTaskIds,
    completedTaskCount,
  };
}

async function refreshUserProgressForUser(db, uid) {
  const evidence = await collectEvidence(db, uid);
  const completed = [];

  for (const task of TASKS) {
    const taskEvidence = evidence[task.id] || {
      completed: false,
      source: task.source,
    };
    if (taskEvidence.completed) {
      await completeTaskForUser(db, uid, task.id, taskEvidence.source);
      completed.push(task.id);
    } else {
      await markIncompleteIfNeeded(db, uid, task.id, taskEvidence.source);
    }
  }

  const summary = await recalculateUserProgressSummary(db, uid);
  return {...summary, completed};
}

async function handleProgressionCallable(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError('unauthenticated', 'Must be logged in');
  }

  const db = admin.firestore();
  const uid = request.auth.uid;
  const data = request.data || {};
  const action = typeof data.action === 'string' ? data.action.trim() : 'refresh';

  if (action === 'refresh') {
    return {
      ok: true,
      action,
      progress: await refreshUserProgressForUser(db, uid),
    };
  }

  if (action === 'dismissLevelUpModal') {
    const stateRef = db.collection('users').doc(uid)
      .collection('gamification').doc('state');
    await stateRef.set({
      showLevelUpModal: false,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {ok: true, action};
  }

  if (action === 'completeTask') {
    const taskId = typeof data.taskId === 'string' ? data.taskId.trim() : '';
    if (!taskId) {
      throw new HttpsError('invalid-argument', 'taskId is required');
    }
    const evidence = await evidenceForTask(db, uid, taskId);
    if (!evidence.completed) {
      await markIncompleteIfNeeded(db, uid, taskId, evidence.source);
      await recalculateUserProgressSummary(db, uid);
      return {
        ok: true,
        action,
        progress: {
          completedNow: false,
          reason: 'evidence_not_found',
        },
      };
    }
    return {
      ok: true,
      action,
      progress: await completeTaskForUser(db, uid, taskId, evidence.source),
    };
  }

  throw new HttpsError('invalid-argument', `Unknown progression action: ${action}`);
}

module.exports = {
  handleProgressionCallable,
  refreshUserProgressForUser,
  completeTaskForUser,
};
