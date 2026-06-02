const admin = require('firebase-admin');

const FieldValue = admin.firestore.FieldValue;

const DEFAULT_SETTINGS = {
  pushNotifications: true,
  momentumReminders: true,
  streakProtection: true,
  missionUpdates: true,
  levelUps: true,
  weeklyRecap: true,
  quietHoursStart: '22:00',
  quietHoursEnd: '08:00',
};

function todayKey(date = new Date(), timezone = 'UTC') {
  try {
    return new Intl.DateTimeFormat('en-CA', {
      timeZone: timezone || 'UTC',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(date);
  } catch (_) {
    return date.toISOString().slice(0, 10);
  }
}

function localHour(date = new Date(), timezone = 'UTC') {
  try {
    return Number(new Intl.DateTimeFormat('en-US', {
      timeZone: timezone || 'UTC',
      hour: '2-digit',
      hour12: false,
    }).format(date));
  } catch (_) {
    return date.getUTCHours();
  }
}

function localWeekday(date = new Date(), timezone = 'UTC') {
  try {
    return new Intl.DateTimeFormat('en-US', {
      timeZone: timezone || 'UTC',
      weekday: 'short',
    }).format(date);
  } catch (_) {
    return ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][date.getUTCDay()];
  }
}

function parseHour(value, fallback) {
  if (typeof value !== 'string') return fallback;
  const hour = Number(value.split(':')[0]);
  return Number.isFinite(hour) ? hour : fallback;
}

function isQuietHour(settings, hour) {
  const start = parseHour(settings.quietHoursStart, 22);
  const end = parseHour(settings.quietHoursEnd, 8);
  if (start === end) return false;
  if (start < end) return hour >= start && hour < end;
  return hour >= start || hour < end;
}

function mergeSettings(raw = {}) {
  return {...DEFAULT_SETTINGS, ...raw};
}

function readTimestamp(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

function missionListFromUserData(data = {}) {
  const arrays = [];
  if (Array.isArray(data.dailyMissions)) arrays.push(...data.dailyMissions);
  if (Array.isArray(data.missions)) {
    arrays.push(...data.missions.filter((mission) => {
      const cadence = mission.cadence || mission.period || mission.type || '';
      return String(cadence).toLowerCase().includes('daily');
    }));
  }
  return arrays;
}

function incompleteDailyMissions(data = {}) {
  return missionListFromUserData(data).filter((mission) => {
    if (!mission || typeof mission !== 'object') return false;
    return mission.isCompleted !== true && mission.completed !== true;
  });
}

function almostCompleteMission(missions) {
  return missions.find((mission) => {
    const target = Number(mission.target || mission.goal || 0);
    const progress = Number(mission.progress || mission.count || 0);
    return target > 0 && progress / target >= 0.5;
  });
}

function missionTitle(mission) {
  return mission.title || mission.name || 'today’s mission';
}

async function getTokens(db, uid) {
  const snap = await db.collection('users').doc(uid).collection('deviceTokens').get();
  return snap.docs.map((doc) => doc.id).filter(Boolean);
}

async function sendProgressionPush(db, uid, notification) {
  const tokens = await getTokens(db, uid);
  if (tokens.length === 0) return {sent: 0};

  const payload = {
    notification: {
      title: notification.title,
      body: notification.body,
    },
    data: {
      type: 'progression',
      progressionType: notification.type,
      route: notification.route || '/progression',
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      ...(notification.data || {}),
    },
    android: {priority: 'normal'},
    apns: {
      payload: {
        aps: {
          sound: 'default',
        },
      },
    },
  };

  let sent = 0;
  const failedTokens = [];
  for (const token of tokens) {
    try {
      await admin.messaging().send({...payload, token});
      sent += 1;
    } catch (error) {
      console.log(`progression push failed for token: ${error.code || error.message}`);
      failedTokens.push(token);
    }
  }

  if (failedTokens.length > 0) {
    const batch = db.batch();
    failedTokens.forEach((token) => {
      batch.delete(db.collection('users').doc(uid).collection('deviceTokens').doc(token));
    });
    await batch.commit();
  }

  await db.collection('notifications').doc(uid).collection('items').add({
    type: 'progression',
    progressionType: notification.type,
    title: notification.title,
    message: notification.body,
    route: notification.route || '/progression',
    status: 'pending',
    createdAt: FieldValue.serverTimestamp(),
  });

  return {sent};
}

async function canSendProgressionNotification(db, uid, settings, type, now = new Date()) {
  if (settings.pushNotifications === false) return false;
  if (settings.progressionNotifications === false) return false;
  const timezone = settings.timezone || 'UTC';
  const hour = localHour(now, timezone);
  if (isQuietHour(settings, hour)) return false;
  const day = todayKey(now, timezone);
  const stateRef = db.collection('users').doc(uid)
    .collection('progressionNotificationState')
    .doc(day);
  const stateSnap = await stateRef.get();
  const state = stateSnap.exists ? stateSnap.data() || {} : {};
  if ((state.count || 0) >= 2) return false;
  if (state[type] === true) return false;
  return true;
}

async function markProgressionNotificationSent(db, uid, settings, type, now = new Date()) {
  const day = todayKey(now, settings.timezone || 'UTC');
  await db.collection('users').doc(uid)
    .collection('progressionNotificationState')
    .doc(day)
    .set({
      [type]: true,
      count: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
}

async function maybeSend(db, uid, settings, notification, now = new Date()) {
  if (!(await canSendProgressionNotification(db, uid, settings, notification.type, now))) {
    return {sent: 0, skipped: true};
  }
  const result = await sendProgressionPush(db, uid, notification);
  if (result.sent > 0) {
    await markProgressionNotificationSent(db, uid, settings, notification.type, now);
  }
  return result;
}

function hasQualifiedActivityToday(userData, settings, now = new Date()) {
  const timezone = settings.timezone || 'UTC';
  const today = todayKey(now, timezone);
  const gam =
    userData.gamification && typeof userData.gamification === 'object'
      ? userData.gamification
      : {};
  if (typeof gam.lastActiveDate === 'string' && gam.lastActiveDate === today) {
    return true;
  }
  if (typeof userData.lastActiveDate === 'string' && userData.lastActiveDate === today) {
    return true;
  }
  const keys = [
    'lastQualifiedActivityAt',
    'lastActiveAt',
  ];
  for (const key of keys) {
    const rootVal = userData[key];
    const gamVal = gam[key];
    for (const value of [rootVal, gamVal]) {
      if (typeof value === 'string' && value.startsWith(today)) return true;
      const date = readTimestamp(value);
      if (date && todayKey(date, timezone) === today) return true;
    }
  }
  return false;
}

async function maybeSendLevelUpNotification(db, uid, previousLevel, nextSummary) {
  const nextLevel = Number(nextSummary && nextSummary.level);
  if (!Number.isFinite(nextLevel) || nextLevel <= Number(previousLevel || 0)) {
    return {sent: 0, skipped: true};
  }
  const settingsSnap = await db.collection('users').doc(uid)
    .collection('notificationSettings')
    .doc('main')
    .get();
  const settings = mergeSettings(settingsSnap.exists ? settingsSnap.data() : {});
  if (settings.levelUps === false) return {sent: 0, skipped: true};

  const levelStateRef = db.collection('users').doc(uid)
    .collection('progressionNotificationState')
    .doc(`level_${nextLevel}`);
  const levelStateSnap = await levelStateRef.get();
  if (levelStateSnap.exists) return {sent: 0, skipped: true};

  const result = await sendProgressionPush(db, uid, {
    type: 'levelUp',
    title: 'Level up!',
    body: `You reached Level ${nextLevel} — ${nextSummary.rankTitle || 'new creator rewards'} are ready.`,
    route: '/progression',
    data: {level: String(nextLevel)},
  });
  if (result.sent > 0) {
    await levelStateRef.set({
      sentAt: FieldValue.serverTimestamp(),
      level: nextLevel,
    }, {merge: true});
  }
  return result;
}

async function evaluateUserForProgressionPush(db, userDoc, now = new Date()) {
  const uid = userDoc.id;
  const userData = userDoc.data() || {};
  const settingsSnap = await userDoc.ref.collection('notificationSettings').doc('main').get();
  const settings = mergeSettings({
    timezone: userData.timezone || 'UTC',
    ...(settingsSnap.exists ? settingsSnap.data() : {}),
  });
  const missions = incompleteDailyMissions(userData);
  const activeHour = Number(settings.preferredMomentumHour) ||
    localHour(readTimestamp(userData.lastActiveAt) || now, settings.timezone);
  const hour = localHour(now, settings.timezone);
  const completedToday = hasQualifiedActivityToday(userData, settings, now);
  const streakCount = Number(userData.streakCount || userData.streakDays || 0);
  const almost = almostCompleteMission(missions);
  const totalXp = Number(userData.totalXP || userData.totalXp || 0);
  const creatorScore = Number(userData.creatorScore || 0);

  if (settings.weeklyRecap !== false && localWeekday(now, settings.timezone) === 'Mon' && hour >= 9) {
    return maybeSend(db, uid, settings, {
      type: 'weeklyRecap',
      title: 'Your creator week is ready',
      body: `${totalXp} XP earned total • ${streakCount} day streak • Creator score ${Math.round(creatorScore)}.`,
      route: '/progression',
    }, now);
  }

  if (missions.length === 0) return {uid, skipped: 'no_incomplete_missions'};

  if (settings.streakProtection !== false && streakCount > 0 && !completedToday && hour >= 17) {
    return maybeSend(db, uid, settings, {
      type: 'streakProtection',
      title: 'Your streak is waiting',
      body: 'Complete one creator action today to keep it alive.',
      route: '/progression',
    }, now);
  }

  if (settings.missionUpdates !== false && almost && hour >= 16) {
    return maybeSend(db, uid, settings, {
      type: 'missionAlmostComplete',
      title: 'You’re close to a mission clear',
      body: `You’re 1 action away from completing today’s mission: ${missionTitle(almost)}.`,
      route: '/progression',
      data: {missionId: String(almost.missionId || almost.id || '')},
    }, now);
  }

  if (settings.momentumReminders !== false && Math.abs(hour - activeHour) <= 1) {
    return maybeSend(db, uid, settings, {
      type: 'dailyMomentum',
      title: 'Keep your creator momentum moving',
      body: 'Post, comment, or upload once today to keep your progress alive.',
      route: '/progression',
    }, now);
  }

  return {uid, skipped: 'outside_trigger_window'};
}

async function runProgressionNotificationSweep() {
  const db = admin.firestore();
  const users = await db.collection('users').limit(500).get();
  const results = [];
  for (const userDoc of users.docs) {
    try {
      results.push(await evaluateUserForProgressionPush(db, userDoc));
    } catch (error) {
      console.error(`progression notification sweep failed for ${userDoc.id}`, error);
      results.push({uid: userDoc.id, error: error.message});
    }
  }
  return {checked: users.size, results};
}

module.exports = {
  runProgressionNotificationSweep,
  maybeSendLevelUpNotification,
  evaluateUserForProgressionPush,
};
