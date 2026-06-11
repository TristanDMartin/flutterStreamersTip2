const admin = require('firebase-admin');
const {
  ANALYTICS_PROFILE_DOC_ID,
  EVENT_ENGAGEMENT_WEIGHTS,
} = require('./event_constants');

const FieldValue = admin.firestore.FieldValue;

function readInt(v) {
  if (v === undefined || v === null) return 0;
  if (typeof v === 'number' && !Number.isNaN(v)) return Math.trunc(v);
  if (typeof v === 'string') return parseInt(v, 10) || 0;
  return 0;
}

function readTs(val) {
  if (!val) return null;
  if (typeof val.toDate === 'function') return val.toDate();
  if (val instanceof Date) return val;
  return null;
}

function readStringList(raw) {
  if (!Array.isArray(raw)) return [];
  return raw.map((e) => String(e));
}

function readIntMap(raw) {
  if (!raw || typeof raw !== 'object') return {};
  const out = {};
  for (const [k, v] of Object.entries(raw)) {
    out[k] = readInt(v);
  }
  return out;
}

function stageFromScore(score) {
  if (score >= 120) return 'established';
  if (score >= 40) return 'growing';
  return 'beginner';
}

function buildRecommendations(profile, event) {
  const actions = readStringList(profile.recommendedNextActions);
  const eventType = String(event.eventType || '');
  const suggestions = [];
  if (eventType === 'video_skipped') {
    suggestions.push('Try shorter clips or stronger hooks in the first 3 seconds.');
  }
  if (eventType === 'search_performed') {
    suggestions.push('Explore creator tools matched to your recent searches.');
  }
  if (eventType === 'tippy_question_asked') {
    suggestions.push('Turn your Tippy answer into a content plan or post.');
  }
  if ((profile.engagementScore || 0) < 20) {
    suggestions.push('Publish one short this week to build momentum.');
  }
  if (eventType === 'platform_connected') {
    suggestions.push('Review growth analytics for your connected platform.');
  }
  const merged = [...suggestions, ...actions].filter(Boolean);
  return [...new Set(merged)].slice(0, 5);
}

function computeChurnRisk(profile, now) {
  const lastActive = readTs(profile.lastActiveAt);
  if (!lastActive) return 0;
  const daysIdle = (now.getTime() - lastActive.getTime()) / (1000 * 60 * 60 * 24);
  const score = readInt(profile.engagementScore);
  let risk = 0;
  if (daysIdle >= 21) risk += 0.55;
  else if (daysIdle >= 14) risk += 0.35;
  else if (daysIdle >= 7) risk += 0.15;
  if (score < 15) risk += 0.25;
  const skips = readInt((profile.eventCounts || {}).video_skipped);
  const views = readInt((profile.eventCounts || {}).video_viewed);
  if (views > 10 && skips / views > 0.6) risk += 0.15;
  return Math.min(1, Math.max(0, risk));
}

function preferredTypeFromCounts(targetCounts) {
  let best = 'video';
  let bestVal = 0;
  for (const [type, count] of Object.entries(targetCounts || {})) {
    const c = readInt(count);
    if (c > bestVal) {
      bestVal = c;
      best = type;
    }
  }
  return best;
}

function applyCategoryMaps(profile, event) {
  const favorite = readIntMap(profile.favoriteCategories);
  const ignored = readIntMap(profile.ignoredCategories);
  const category = event.metadata && event.metadata.category
    ? String(event.metadata.category).trim()
    : '';
  const eventType = String(event.eventType || '');
  if (category) {
    if (eventType === 'video_skipped') {
      ignored[category] = readInt(ignored[category]) + 1;
    } else if (
      eventType === 'video_viewed' ||
      eventType === 'video_completed' ||
      eventType === 'post_liked'
    ) {
      favorite[category] = readInt(favorite[category]) + 1;
    }
  }
  return {favoriteCategories: favorite, ignoredCategories: ignored};
}

async function aggregateAnalyticsProfile(uid, event) {
  const db = admin.firestore();
  const ref = db
      .collection('users')
      .doc(uid)
      .collection('analyticsProfile')
      .doc(ANALYTICS_PROFILE_DOC_ID);
  const now = new Date();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const profile = snap.exists ? snap.data() : {};
    const eventType = String(event.eventType || '');
    const targetType = String(event.targetType || 'video');
    const weight = EVENT_ENGAGEMENT_WEIGHTS[eventType] ?? 1;
    const eventCounts = readIntMap(profile.eventCounts);
    eventCounts[eventType] = readInt(eventCounts[eventType]) + 1;
    const targetCounts = readIntMap(profile.targetTypeCounts);
    targetCounts[targetType] = readInt(targetCounts[targetType]) + 1;
    const engagementScore = Math.max(
        0,
        readInt(profile.engagementScore) + weight,
    );
    const categoryMaps = applyCategoryMaps(profile, event);
    let recentSearches = readStringList(profile.recentSearches);
    if (eventType === 'search_performed' && event.metadata && event.metadata.query) {
      const q = String(event.metadata.query).trim();
      if (q) {
        recentSearches = [q, ...recentSearches.filter((s) => s !== q)].slice(0, 10);
      }
    }
    const nextProfile = {
      favoriteCategories: categoryMaps.favoriteCategories,
      ignoredCategories: categoryMaps.ignoredCategories,
      preferredContentType: preferredTypeFromCounts(targetCounts),
      creatorStage: stageFromScore(engagementScore),
      engagementScore,
      eventCounts,
      targetTypeCounts: targetCounts,
      recentSearches,
      lastActiveAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    nextProfile.recommendedNextActions = buildRecommendations(
        {...profile, ...nextProfile},
        event,
    );
    nextProfile.churnRisk = computeChurnRisk(
        {...profile, ...nextProfile, lastActiveAt: now},
        now,
    );
    tx.set(ref, nextProfile, {merge: true});
  });
}

module.exports = {aggregateAnalyticsProfile};
