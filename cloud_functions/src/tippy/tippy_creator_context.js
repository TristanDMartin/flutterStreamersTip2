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

function readStringList(raw, limit = 8) {
  if (!Array.isArray(raw)) {
    return [];
  }
  return raw
    .map((value) => String(value || '').trim())
    .filter(Boolean)
    .slice(0, limit);
}

const GOAL_LABELS = {
  growth: 'Grow audience and engagement',
  monetization: 'Monetize content',
  ai_assistance: 'AI coaching and workflow help',
  networking: 'Build creator connections',
  content_creation: 'Plan and create content',
  streaming: 'Improve live streaming',
};

const PLATFORM_LABELS = {
  twitch: 'Twitch',
  youtube: 'YouTube',
  tiktok: 'TikTok',
  kick: 'Kick',
  instagram: 'Instagram',
  facebook_gaming: 'Facebook Gaming',
};

const PLATFORM_GUIDANCE = {
  twitch:
    'Twitch context: categories, stream titles, raids, clips, panels, ' +
    'and live engagement.',
  youtube:
    'YouTube context: thumbnails, hooks, Shorts vs long-form, and ' +
    'upload cadence.',
  tiktok:
    'TikTok context: hooks in the first second, trends, and vertical pacing.',
  kick:
    'Kick context: live categories, discoverability, and clip highlights.',
  instagram:
    'Instagram context: Reels hooks, aesthetic consistency, and CTAs.',
  facebook_gaming:
    'Facebook Gaming context: live discovery, community posts, and clips.',
};

function readOnboardingGoals(userData) {
  const onboarding =
    userData.onboarding &&
    typeof userData.onboarding === 'object' &&
    !Array.isArray(userData.onboarding)
      ? userData.onboarding
      : {};
  return readStringList(
    userData.creatorGoals || onboarding.creatorGoals || onboarding.creatorGoal,
  );
}

function readOnboardingPlatforms(userData) {
  const onboarding =
    userData.onboarding &&
    typeof userData.onboarding === 'object' &&
    !Array.isArray(userData.onboarding)
      ? userData.onboarding
      : {};
  return readStringList(onboarding.platforms);
}

function appendMemoryLines(lines, memory) {
  if (!memory || typeof memory !== 'object' || Object.keys(memory).length === 0) {
    return;
  }
  const niche =
    memory.niche &&
    Array.isArray(memory.niche.labels) &&
    memory.niche.labels.length > 0
      ? memory.niche.labels.join(', ')
      : readString(memory.niche, ['primaryCategoryId']);
  if (niche) {
    lines.push(`Creator niche focus: ${niche}.`);
  }
  const posting =
    memory.posting && typeof memory.posting === 'object' ? memory.posting : null;
  if (posting) {
    const avg = readNumber(posting, ['avgUploadsPerWeek']);
    const week = readNumber(posting, ['postsThisWeek']);
    if (avg != null || week != null) {
      const parts = [];
      if (avg != null) {
        parts.push(`average ${avg} uploads/week`);
      }
      if (week != null) {
        parts.push(`${week} posts this week`);
      }
      lines.push(`Posting rhythm: ${parts.join(', ')}.`);
    }
  }
  const style =
    memory.contentStyle && typeof memory.contentStyle === 'object'
      ? memory.contentStyle
      : null;
  if (style) {
    const avgDuration = readNumber(style, ['avgDurationSec']);
    const dominant = readString(style, ['dominantFormat']);
    if (avgDuration != null || dominant) {
      lines.push(
        `Content style: ${dominant || 'mixed'}` +
          (avgDuration != null ? `, ~${avgDuration}s average length` : '') +
          '.',
      );
    }
  }
  const performance =
    memory.performance && typeof memory.performance === 'object'
      ? memory.performance
      : null;
  if (performance && Array.isArray(performance.insightLines)) {
    for (const insight of performance.insightLines.slice(0, 3)) {
      if (insight) {
        lines.push(`Performance insight: ${insight}`);
      }
    }
  }
  if (Array.isArray(memory.weakPoints) && memory.weakPoints.length > 0) {
    lines.push(`Improve: ${memory.weakPoints.join(', ')}.`);
  }
  if (Array.isArray(memory.strongPoints) && memory.strongPoints.length > 0) {
    lines.push(`Strengths: ${memory.strongPoints.join(', ')}.`);
  }
}

function appendGoalLines(lines, goals) {
  if (!Array.isArray(goals) || goals.length === 0) {
    return;
  }
  const labels = goals.slice(0, 5).map((goal) => {
    const title = readString(goal, ['title']) || readString(goal, ['type']);
    const target = readNumber(goal, ['targetValue']);
    const current = readNumber(goal, ['currentValue']);
    if (target != null && current != null && target > 0) {
      const pct = Math.min(100, Math.round((current / target) * 100));
      return `${title} (${pct}%)`;
    }
    return title;
  }).filter(Boolean);
  if (labels.length > 0) {
    lines.push(`Active creator goals: ${labels.join('; ')}.`);
    lines.push('Anchor advice to these goals when relevant.');
  }
}

function appendAnalyticsProfileLines(lines, analyticsProfile) {
  if (!analyticsProfile || typeof analyticsProfile !== 'object') {
    return;
  }
  const stage = readString(analyticsProfile, ['creatorStage']);
  if (stage) {
    lines.push(`Creator stage (app analytics): ${stage}.`);
  }
  const score = readNumber(analyticsProfile, ['engagementScore']);
  if (score != null) {
    lines.push(`Engagement score: ${score}.`);
  }
  const actions = analyticsProfile.recommendedNextActions;
  if (Array.isArray(actions) && actions.length > 0) {
    lines.push(
      `Recommended next actions: ${actions.slice(0, 3).join('; ')}.`,
    );
  }
}

function appendPersonalizationLines(lines, userData) {
  const goals = readOnboardingGoals(userData);
  const platforms = readOnboardingPlatforms(userData);
  if (goals.length > 0) {
    const labels = goals.map((goal) => GOAL_LABELS[goal] || goal);
    lines.push(`Onboarding creator goals: ${labels.join('; ')}.`);
  }
  if (platforms.length > 0) {
    const labels = platforms.map(
      (platform) => PLATFORM_LABELS[platform.toLowerCase()] || platform,
    );
    lines.push(`Primary platforms: ${labels.join(', ')}.`);
    for (const platform of platforms.slice(0, 3)) {
      const guidance = PLATFORM_GUIDANCE[String(platform).toLowerCase()];
      if (guidance) {
        lines.push(guidance);
      }
    }
  }
  if (goals.includes('ai_assistance')) {
    lines.push(
      'Prioritize actionable coaching, scripts, and next-step plans.',
    );
  }
  if (goals.includes('content_creation')) {
    lines.push(
      'Suggest concrete content ideas, hooks, and weekly cadence.',
    );
  }
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
  if (extras.memory && typeof extras.memory === 'object') {
    appendMemoryLines(lines, extras.memory);
  }
  if (Array.isArray(extras.goals) && extras.goals.length > 0) {
    appendGoalLines(lines, extras.goals);
  }
  if (
    extras.analyticsProfile &&
    typeof extras.analyticsProfile === 'object'
  ) {
    appendAnalyticsProfileLines(lines, extras.analyticsProfile);
  }
  appendPersonalizationLines(lines, userData);
  if (lines.length === 0) {
    return 'Creator context: limited profile data available; ask one clarifying question when personalization matters.';
  }
  return `Creator context:\n${lines.join('\n')}`;
}

module.exports = {
  appendAnalyticsProfileLines,
  appendGoalLines,
  appendMemoryLines,
  buildCreatorContextBlock,
};
