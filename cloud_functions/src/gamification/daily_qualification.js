/**
 * Server-owned daily activity + streak updates for activity.day_qualified events.
 */
const admin = require('firebase-admin');

const FieldValue = admin.firestore.FieldValue;

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

function todayKey(date = new Date()) {
  return date.toISOString().slice(0, 10);
}

function yesterdayKey(date = new Date()) {
  const d = new Date(date);
  d.setUTCDate(d.getUTCDate() - 1);
  return todayKey(d);
}

function readLastActiveDate(userData) {
  const gam =
    userData.gamification && typeof userData.gamification === 'object'
      ? userData.gamification
      : {};
  return (
    gam.lastActiveDate ||
    userData.lastActiveDate ||
    (userData.progressionSummary &&
      userData.progressionSummary.lastActiveDate) ||
    null
  );
}

function readStreakCount(userData) {
  const gam =
    userData.gamification && typeof userData.gamification === 'object'
      ? userData.gamification
      : {};
  return readInt(
    gam.streakCount ??
      gam.streakDays ??
      userData.streakCount ??
      userData.streakDays,
    0,
  );
}

/**
 * Build Firestore merge fields when user qualifies for the day.
 * @returns {{ skipped: boolean, streakExtended?: boolean, updates?: object }}
 */
function buildDailyQualificationUpdates(userData) {
  const today = todayKey();
  const yesterday = yesterdayKey();
  const prevDate = readLastActiveDate(userData);
  if (prevDate === today) {
    return {skipped: true};
  }
  const gam =
    userData.gamification && typeof userData.gamification === 'object'
      ? {...userData.gamification}
      : {};
  let streakCount = readStreakCount(userData);
  let streakExtended = false;
  if (prevDate === yesterday) {
    streakCount = Math.max(1, streakCount) + 1;
    streakExtended = true;
  } else {
    streakCount = 1;
    streakExtended = prevDate !== today;
  }
  const longestStreak = Math.max(
    streakCount,
    readInt(gam.longestStreak ?? userData.longestStreak, 0),
  );
  const mergedGam = {
    ...gam,
    lastActiveDate: today,
    lastQualifiedActivityAt: FieldValue.serverTimestamp(),
    streakCount,
    streakDays: streakCount,
    longestStreak,
    updatedAt: FieldValue.serverTimestamp(),
  };
  return {
    skipped: false,
    streakExtended,
    updates: {
      lastActiveDate: today,
      lastQualifiedActivityAt: FieldValue.serverTimestamp(),
      streakCount,
      streakDays: streakCount,
      longestStreak,
      gamification: mergedGam,
    },
  };
}

function streakFromStoredFields(userData) {
  const streakCount = readStreakCount(userData);
  const lastActiveDate = readLastActiveDate(userData);
  const today = todayKey();
  const activeToday = lastActiveDate === today;
  return {
    streakCount: activeToday ? Math.max(1, streakCount) : streakCount,
    lastActiveDate,
    streakStatus: activeToday ? 'Active today' : 'Start today',
    streakLabel:
      streakCount > 0 ? `${streakCount} day streak` : 'Start today',
  };
}

module.exports = {
  buildDailyQualificationUpdates,
  streakFromStoredFields,
  todayKey,
  yesterdayKey,
  FieldValue,
};
