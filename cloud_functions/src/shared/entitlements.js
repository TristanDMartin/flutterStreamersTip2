'use strict';

/**
 * Canonical plan limits for StreamersTip (website, app, Stripe, API).
 * Do not duplicate these values elsewhere — import this module only.
 *
 * Tier keys: starter (Creator), pro (Creator Pro), studio (Creator Studio).
 * Use -1 for unlimited numeric limits.
 */

const UNLIMITED = -1;

const TIER_ENTITLEMENTS = {
  starter: {
    displayName: 'Creator',
    aiCreditsPerMonth: 25,
    analyticsWindowDays: 7,
    contentPlans: 1,
    connectedPlatforms: 1,
    teamMembers: 0,
    crossPostWeeklyLimit: 1,
    schedulingEnabled: true,
    features: {
      advancedAnalytics: false,
      contentPlanner: true,
      bulkPublishing: false,
      crossPosting: true,
      automation: false,
      teamMembers: false,
      analyticsExport: false,
      advancedReports: false,
      tippyPremium: false,
      scheduling: true,
    },
  },
  pro: {
    displayName: 'Creator Pro',
    aiCreditsPerMonth: 500,
    analyticsWindowDays: 90,
    contentPlans: UNLIMITED,
    connectedPlatforms: 5,
    teamMembers: 0,
    crossPostWeeklyLimit: UNLIMITED,
    schedulingEnabled: true,
    features: {
      advancedAnalytics: true,
      contentPlanner: true,
      bulkPublishing: true,
      crossPosting: true,
      automation: false,
      teamMembers: false,
      analyticsExport: false,
      advancedReports: true,
      tippyPremium: true,
      scheduling: true,
    },
  },
  studio: {
    displayName: 'Creator Studio',
    aiCreditsPerMonth: 2500,
    analyticsWindowDays: 365,
    contentPlans: UNLIMITED,
    connectedPlatforms: UNLIMITED,
    teamMembers: 5,
    crossPostWeeklyLimit: UNLIMITED,
    schedulingEnabled: true,
    features: {
      advancedAnalytics: true,
      contentPlanner: true,
      bulkPublishing: true,
      crossPosting: true,
      automation: true,
      teamMembers: true,
      analyticsExport: true,
      advancedReports: true,
      tippyPremium: true,
      scheduling: true,
    },
  },
};

/** Future Agency tier — config placeholder only (not sold yet). */
const AGENCY_ENTITLEMENTS_PLACEHOLDER = {
  displayName: 'Agency',
  teamMembers: UNLIMITED,
};

const AI_CREDIT_COSTS = {
  captionRewrite: 1,
  hashtags: 1,
  captionGeneration: 2,
  contentPlan: 5,
  growthAnalysis: 10,
};

const BILLING_FEATURES = Object.freeze([
  'advancedAnalytics',
  'contentPlanner',
  'bulkPublishing',
  'crossPosting',
  'automation',
  'teamMembers',
  'analyticsExport',
  'advancedReports',
  'tippyPremium',
  'scheduling',
]);

function normalizeTierKey(tier) {
  const s = String(tier || '').trim().toLowerCase();
  if (s === 'pro' || s === 'professional' || s === 'creatorpro') {
    return 'pro';
  }
  if (s === 'studio' || s === 'enterprise' || s === 'creatorstudio') {
    return 'studio';
  }
  if (s === 'starter' || s === 'free' || s === 'creator') {
    return 'starter';
  }
  return 'starter';
}

function isUnlimited(value) {
  return Number(value) < 0;
}

function getEntitlementsForTier(tier) {
  const key = normalizeTierKey(tier);
  return TIER_ENTITLEMENTS[key] || TIER_ENTITLEMENTS.starter;
}

function getAiCreditLimitForTier(tier) {
  return getEntitlementsForTier(tier).aiCreditsPerMonth;
}

function getCrossPostWeeklyLimitForTier(tier) {
  return getEntitlementsForTier(tier).crossPostWeeklyLimit;
}

function hasBillingFeature(tier, featureName) {
  const ent = getEntitlementsForTier(tier);
  const features = ent.features || {};
  return features[featureName] === true;
}

function creditCostForAction(action) {
  const key = String(action || '').trim();
  if (!key) {
    return 1;
  }
  const cost = AI_CREDIT_COSTS[key];
  return Number.isFinite(cost) && cost > 0 ? cost : 1;
}

module.exports = {
  UNLIMITED,
  TIER_ENTITLEMENTS,
  AGENCY_ENTITLEMENTS_PLACEHOLDER,
  AI_CREDIT_COSTS,
  BILLING_FEATURES,
  normalizeTierKey,
  isUnlimited,
  getEntitlementsForTier,
  getAiCreditLimitForTier,
  getCrossPostWeeklyLimitForTier,
  hasBillingFeature,
  creditCostForAction,
};
