'use strict';

function readNumber(obj, keys) {
  if (!obj || typeof obj !== 'object') {
    return null;
  }
  for (const key of keys) {
    const raw = obj[key];
    if (typeof raw === 'number' && Number.isFinite(raw)) {
      return raw;
    }
    if (typeof raw === 'string' && raw.trim().length > 0) {
      const n = Number(raw);
      if (Number.isFinite(n)) {
        return n;
      }
    }
  }
  return null;
}

function readString(obj, keys) {
  if (!obj || typeof obj !== 'object') {
    return '';
  }
  for (const key of keys) {
    const raw = obj[key];
    if (typeof raw === 'string' && raw.trim().length > 0) {
      return raw.trim();
    }
  }
  return '';
}

function mergeProgressMaps(userData) {
  const gam =
    userData.gamification &&
    typeof userData.gamification === 'object' &&
    !Array.isArray(userData.gamification)
      ? userData.gamification
      : {};
  const summary =
    userData.progressionSummary &&
    typeof userData.progressionSummary === 'object' &&
    !Array.isArray(userData.progressionSummary)
      ? userData.progressionSummary
      : {};
  return {...gam, ...summary};
}

function readMissionTitles(userData, limit = 3) {
  const lists = [
    userData.dailyMissions,
    userData.missions,
    userData.activeMissions,
  ];
  const titles = [];
  for (const raw of lists) {
    if (!Array.isArray(raw)) {
      continue;
    }
    for (const item of raw) {
      if (!item || typeof item !== 'object') {
        continue;
      }
      const title = readString(item, ['title', 'name']);
      if (title && !titles.includes(title)) {
        titles.push(title);
      }
      if (titles.length >= limit) {
        return titles;
      }
    }
  }
  return titles;
}

/**
 * Compact creator snapshot for Tippy system prompts (no PII beyond display name).
 * @param {object} userData Firestore users/{uid} document
 * @param {object} [extras] Optional request hints (category, scheduledThisWeek, etc.)
 * @returns {string}
 */
function buildCreatorContextBlock(userData = {}, extras = {}) {
  const progress = mergeProgressMaps(userData);
  const lines = [];
  const tier = readString(userData, ['subscriptionTier', 'subscription_tier']);
  if (tier) {
    lines.push(`Subscription tier (billing): ${tier}.`);
  }
  const level = readNumber(progress, ['level', 'creatorLevel']);
  const totalXp = readNumber(progress, ['totalXp', 'totalXP', 'xp']);
  const creatorScore = readNumber(progress, [
    'creatorScore',
    'creator_score',
  ]);
  const streakDays = readNumber(progress, [
    'streakDays',
    'streakCount',
    'streak_days',
  ]);
  const rankTitle = readString(progress, [
    'rankTitle',
    'rankName',
    'rank_title',
  ]);
  const streakStatus = readString(progress, ['streakStatus', 'streak_status']);
  const nextHint = readString(progress, [
    'nextActionHint',
    'nextAction',
    'next_action',
  ]);
  if (level != null || totalXp != null || creatorScore != null) {
    const parts = [];
    if (level != null) {
      parts.push(`level ${level}`);
    }
    if (totalXp != null) {
      parts.push(`${totalXp} XP`);
    }
    if (creatorScore != null) {
      parts.push(`creator score ${creatorScore}`);
    }
    lines.push(`Progression: ${parts.join(', ')}.`);
  }
  if (rankTitle) {
    lines.push(`Rank: ${rankTitle}.`);
  }
  if (streakDays != null) {
    lines.push(
      `Posting streak: ${streakDays} day(s)` +
        (streakStatus ? ` (${streakStatus}).` : '.'),
    );
  }
  const missions = readMissionTitles(userData);
  if (missions.length > 0) {
    lines.push(`Active missions: ${missions.join('; ')}.`);
  }
  if (nextHint) {
    lines.push(`Suggested next action in app: ${nextHint}`);
  }
  const usage =
    userData.usage &&
    typeof userData.usage === 'object' &&
    !Array.isArray(userData.usage)
      ? userData.usage
      : null;
  if (usage) {
    const postsWeek = readNumber(usage, [
      'postsThisWeek',
      'posts_this_week',
    ]);
    if (postsWeek != null) {
      lines.push(`Posts this week (usage): ${postsWeek}.`);
    }
  }
  if (extras.category) {
    lines.push(`Current post category: ${extras.category}.`);
  }
  if (extras.scheduledThisWeek != null) {
    lines.push(
      `Scheduled posts this week: ${extras.scheduledThisWeek}.`,
    );
  }
  if (extras.surface) {
    lines.push(`User is in: ${extras.surface}.`);
  }
  if (lines.length === 0) {
    return 'Creator context: limited profile data available; ask one clarifying question when personalization matters.';
  }
  return `Creator context:\n${lines.join('\n')}`;
}

module.exports = {
  buildCreatorContextBlock,
};
