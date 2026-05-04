'use strict';

const {resolveTierFromUserDoc} = require('./subscription_tier');

const TIER_CREDIT_LIMITS = {
  starter: 10,
  pro: 250,
  studio: 963,
};

const STUDIO_BYPASS_UIDS = new Set([
  'bU0RxyZ2L4ULAv1Co5L4f825yV73',
  'jsmbQMLQjoUyC5cUFvkrRbi9mkp1',
]);

const STUDIO_BYPASS_EMAILS = new Set([
  'buzzz@streamerstip.com',
]);

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
    crossPostLimit: -1,
    limit: TIER_CREDIT_LIMITS.studio,
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
    return TIER_CREDIT_LIMITS.studio;
  }
  if (tier === 'pro') {
    return TIER_CREDIT_LIMITS.pro;
  }
  if (hasEntitlement) {
    return TIER_CREDIT_LIMITS.pro;
  }
  if (tier === 'unknown' || tier === 'starter') {
    return TIER_CREDIT_LIMITS.starter;
  }
  return TIER_CREDIT_LIMITS[tier] || 0;
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
  const tier = resolved.tier;
  const tierSource = resolved.sourceField;
  const status = resolveSubscriptionStatus(userData);
  const hasEntitlement = resolveHasTippyEntitlement(userData);
  const hasActiveSubscription = ['active', 'trialing', 'past_due'].includes(
    status,
  );
  const isTierAllowed = tier === 'pro' || tier === 'studio';
  const canUseTippy =
    hasEntitlement || (hasActiveSubscription && isTierAllowed);
  return {
    tier,
    tierSource,
    status,
    hasEntitlement,
    canUseTippy,
    hasStudioAccess: tier === 'studio' && canUseTippy,
    billingRequired: true,
    crossPostLimit: tier === 'starter' ? 1 : -1,
    limit: resolvePlanLimit({tier, hasEntitlement}),
  };
}

module.exports = {
  STUDIO_BYPASS_UIDS,
  STUDIO_BYPASS_EMAILS,
  TIER_CREDIT_LIMITS,
  buildUserAccess,
  normalizeEmail,
  resolveHasTippyEntitlement,
  resolvePlanLimit,
  resolveStudioBypass,
  resolveSubscriptionStatus,
};
