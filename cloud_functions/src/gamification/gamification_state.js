/**
 * Writes canonical `users/{uid}/gamification/state` from server-owned user fields.
 */
const admin = require('firebase-admin');
const {
  levelFromTotalXp,
  rankTitleForLevel,
  xpProgressForLevel,
} = require('./level_table');

const FieldValue = admin.firestore.FieldValue;

function readInt(v, fallback = 0) {
  if (v === undefined || v === null) return fallback;
  if (typeof v === 'number' && !Number.isNaN(v)) return Math.trunc(v);
  if (typeof v === 'string') return parseInt(v, 10) || fallback;
  return fallback;
}

function readXp(userData) {
  const gam = userData.gamification;
  if (gam && typeof gam === 'object') {
    const fromGam =
      readInt(gam.totalXp) || readInt(gam.total_xp) || readInt(gam.xp);
    if (fromGam > 0) return fromGam;
  }
  return readInt(userData.totalXp) || readInt(userData.totalXP);
}

function readStreak(userData) {
  const gam = userData.gamification;
  if (gam && typeof gam === 'object') {
    return readInt(gam.streakCount) ||
      readInt(gam.streakDays) ||
      readInt(gam.streak_days);
  }
  return readInt(userData.streakCount) || readInt(userData.streakDays);
}

function readLongestStreak(userData, streakCount) {
  const gam = userData.gamification;
  if (gam && typeof gam === 'object') {
    const longest = readInt(gam.longestStreak) || readInt(gam.longest_streak);
    if (longest > 0) return longest;
  }
  return Math.max(streakCount, readInt(userData.longestStreak));
}

function readConsistencyScore(userData) {
  const summary = userData.progressionSummary;
  if (summary && typeof summary === 'object') {
    const score = summary.creatorScore;
    if (typeof score === 'number') return Math.round(score);
  }
  const gam = userData.gamification;
  if (gam && typeof gam === 'object') {
    const score = gam.creatorScore || gam.creator_score;
    if (typeof score === 'number') return Math.round(score);
  }
  return readInt(userData.creatorScore);
}

function missionMapsFromUser(userData) {
  const completedMissions = {};
  const activeMissions = [];
  const lists = [
    userData.dailyMissions,
    userData.missions,
  ].filter(Array.isArray);
  for (const list of lists) {
    for (const raw of list) {
      if (!raw || typeof raw !== 'object') continue;
      const id = raw.missionId || raw.templateId || raw.template_id || raw.id;
      if (!id) continue;
      const status = String(raw.status || 'active').toLowerCase();
      const progress = readInt(raw.progress);
      const target = readInt(raw.target, 1);
      const done =
        status === 'completed' ||
        status === 'claimed' ||
        status === 'rewarded' ||
        raw.rewardClaimed === true ||
        progress >= target;
      if (done) {
        completedMissions[String(id)] = true;
      } else if (status === 'active') {
        activeMissions.push(String(id));
      }
    }
  }
  return {completedMissions, activeMissions};
}

function badgesFromUser(userData) {
  const gam = userData.gamification;
  if (gam && Array.isArray(gam.badges)) {
    return gam.badges;
  }
  return [];
}

function buildGamificationState(uid, userData, previousState) {
  const xp = readXp(userData);
  const storedLevel = readInt((userData.gamification || {}).level, 0);
  const level = storedLevel > 0 ? storedLevel : levelFromTotalXp(xp);
  const rank = (userData.gamification || {}).rankTitle ||
    (userData.gamification || {}).rank ||
    userData.rankTitle ||
    userData.rankName ||
    rankTitleForLevel(level);
  const progress = xpProgressForLevel(level, xp);
  const streakCount = readStreak(userData);
  const previousLevel = readInt(
    previousState && previousState.level,
    level,
  );
  const leveledUp = level > previousLevel;
  const missions = missionMapsFromUser(userData);
  const lastActivityAt =
    (userData.gamification && userData.gamification.lastQualifiedActivityAt) ||
    userData.lastActiveDate ||
    FieldValue.serverTimestamp();
  return {
    uid,
    xp,
    level,
    rank,
    currentLevelXp: progress.currentLevelXp,
    nextLevelXp: progress.nextLevelXp,
    progressPercent: progress.progressPercent,
    streakCount,
    longestStreak: readLongestStreak(userData, streakCount),
    lastActivityAt,
    consistencyScore: readConsistencyScore(userData),
    badges: badgesFromUser(userData),
    completedMissions: missions.completedMissions,
    activeMissions: missions.activeMissions,
    previousLevel,
    showLevelUpModal: leveledUp,
    leveledUpAt: leveledUp ? FieldValue.serverTimestamp() : null,
    updatedAt: FieldValue.serverTimestamp(),
  };
}

/**
 * Sync `users/{uid}/gamification/state` after any server XP/level write.
 */
async function syncGamificationState(db, uid) {
  const userRef = db.collection('users').doc(uid);
  const stateRef = userRef.collection('gamification').doc('state');
  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    const stateSnap = await tx.get(stateRef);
    const userData = userSnap.exists ? userSnap.data() || {} : {};
    const previousState = stateSnap.exists ? stateSnap.data() : null;
    const state = buildGamificationState(uid, userData, previousState);
    if (!state.leveledUpAt) {
      delete state.leveledUpAt;
    }
    tx.set(stateRef, state, {merge: true});
  });
}

module.exports = {
  buildGamificationState,
  syncGamificationState,
};
