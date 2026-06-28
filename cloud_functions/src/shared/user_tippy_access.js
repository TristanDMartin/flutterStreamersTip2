'use strict';

const {resolveTierFromUserDoc} = require('./subscription_tier');
const {
  getAiCreditLimitForTier,
  getCrossPostWeeklyLimitForTier,
  getEntitlementsForTier,
} = require('./entitlements');
const {isSubscriptionPeriodActive} = require('./subscription_entitlements');

const STUDIO_BYPASS_UIDS = new Set(
  process.env.STUDIO_BYPASS_UIDS
    ? process.env.STUDIO_BYPASS_UIDS.split(',').map((s) => s.trim()).filter(Boolean)
    : [],
);

const STUDIO_BYPASS_EMAILS = new Set(
  process.env.STUDIO_BYPASS_EMAILS
    ? process.env.STUDIO_BYPASS_EMAILS.split(',').map((s) => s.trim().toLowerCase()).filter(Boolean)
    : [],
);

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function resolveStudioBypass({uid, email, userData = {}} = {}) {
  const uidAllowed = uid && STUDIO_BYPASS_UIDS.has(String(uid));
  const emailAllowed =
    STUDIO_BYPASS_EMAILS.has(normalizeEmail(email)) ||
    STUDIO_BYPASS_EMAILS.has(normalizeEmail(userData.email));
  const isAdmin =
    userData.isAdmin === true ||
    userData.role === 'admin' ||
    userData.admin === true;
  if (!uidAllowed && !emailAllowed && !isAdmin) {
    return null;
  }
  return {
    tier: 'studio',
    tierSource: isAdmin ? 'admin' : 'studio_bypass',
    status: 'admin_granted',
    hasEntitlement: true,
    canUseTippy: true,
    hasStudioAccess: true,
    billingRequired: false,
    crossPostLimit: getCrossPostWeeklyLimitForTier('studio'),
    limit: getAiCreditLimitForTier('studio'),
  };
}

function resolveHasTippyEntitlement(userData) {
  const entitlements = userData.entitlements || {};
  const t = entitlements.tippyAi;
  if (t === true || entitlements.tippy_ai === true) {
    return true;
  }
  if (t && typeof t === 'object' && !Array.isArray(t)) {
    if (t.enabled === true) {
      return true;
    }
    const planOrTier = t.plan || t.tier;
    if (
      planOrTier !== undefined &&
      planOrTier !== null &&
      String(planOrTier).trim() !== ''
    ) {
      return true;
    }
  }
  return false;
}

function resolveSubscriptionStatus(userData) {
  const rawStatus = String(
    userData.subscriptionStatus ||
      userData.subscription_status ||
      userData.subscription?.status ||
      userData.subscription?.subscriptionStatus ||
      'inactive',
  ).toLowerCase();
  return rawStatus;
}

function resolvePlanLimit({tier, hasEntitlement}) {
  if (tier === 'studio') {
    return getAiCreditLimitForTier('studio');
  }
  if (tier === 'pro') {
    return getAiCreditLimitForTier('pro');
  }
  if (hasEntitlement) {
    return getAiCreditLimitForTier('pro');
  }
  if (tier === 'unknown' || tier === 'starter') {
    return getAiCreditLimitForTier('starter');
  }
  return getAiCreditLimitForTier(tier);
}

function buildUserAccess(userData, options = {}) {
  const bypass = resolveStudioBypass({
    uid: options.uid,
    email: options.email,
    userData,
  });
  if (bypass) {
    return bypass;
  }
  const resolved = resolveTierFromUserDoc(userData);
  let tier = resolved.tier;
  if (
    (tier === 'pro' || tier === 'studio') &&
    !isSubscriptionPeriodActive(userData)
  ) {
    tier = 'starter';
  }
  const tierSource = resolved.sourceField;
  const status = resolveSubscriptionStatus(userData);
  const hasEntitlement = resolveHasTippyEntitlement(userData);
  const effectiveTier =
    tier === 'unknown' ? 'starter' : tier;
  // All tiers (including Free/starter) get Tippy with tier-scoped credits and features.
  const canUseTippy = true;
  return {
    tier: effectiveTier,
    tierSource,
    status,
    hasEntitlement,
    canUseTippy,
    hasStudioAccess: effectiveTier === 'studio' && canUseTippy,
    billingRequired: true,
    crossPostLimit: getCrossPostWeeklyLimitForTier(effectiveTier),
    limit: resolvePlanLimit({tier: effectiveTier, hasEntitlement}),
    entitlements: getEntitlementsForTier(effectiveTier),
  };
}

module.exports = {
  STUDIO_BYPASS_UIDS,
  STUDIO_BYPASS_EMAILS,
  buildUserAccess,
  normalizeEmail,
  resolveHasTippyEntitlement,
  resolvePlanLimit,
  resolveStudioBypass,
  resolveSubscriptionStatus,
};
