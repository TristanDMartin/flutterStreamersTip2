'use strict';

/**
 * Single resolution order for app + Tippy + /me/entitlements.
 * Prefer users/{uid}.subscription.tier after migration; keep legacy fallbacks.
 */
function normalizeTierString(val) {
  if (val === undefined || val === null) {
    return null;
  }
  const s = String(val).trim().toLowerCase();
  if (s === 'pro' || s === 'professional') {
    return 'pro';
  }
  if (s === 'studio' || s === 'enterprise') {
    return 'studio';
  }
  if (s === 'starter' || s === 'free') {
    return 'starter';
  }
  return null;
}

function resolveTierFromUserDoc(userData) {
  const rootTierRaw = userData.subscriptionTier;
  const rootStatus = String(userData.subscriptionStatus || '')
    .toLowerCase()
    .trim();
  const paidStatuses =
    rootStatus === 'active' || rootStatus === 'trialing';
  if (
    rootTierRaw !== undefined &&
    rootTierRaw !== null &&
    String(rootTierRaw).trim() !== ''
  ) {
    const normalizedRoot = normalizeTierString(rootTierRaw);
    if (normalizedRoot) {
      if (paidStatuses) {
        return {tier: normalizedRoot, sourceField: 'subscriptionTier'};
      }
      return {tier: 'starter', sourceField: 'subscriptionTier+inactive'};
    }
  }

  const sub =
    userData.subscription && typeof userData.subscription === 'object'
      ? userData.subscription
      : {};
  const ent =
    userData.entitlements && typeof userData.entitlements === 'object'
      ? userData.entitlements
      : {};
  const tippyEnt =
    ent.tippyAi &&
    typeof ent.tippyAi === 'object' &&
    !Array.isArray(ent.tippyAi)
      ? ent.tippyAi
      : {};

  const candidates = [
    ['subscription.tier', sub.tier],
    ['subscription.plan', sub.plan],
    ['stripeRole', userData.stripeRole],
    ['plan', userData.plan],
    ['entitlements.tippyAi.plan', tippyEnt.plan],
    ['entitlements.tippyAi.tier', tippyEnt.tier],
    ['tier', userData.tier],
  ];

  for (let i = 0; i < candidates.length; i++) {
    const sourceField = candidates[i][0];
    const t = normalizeTierString(candidates[i][1]);
    if (t) {
      return {tier: t, sourceField};
    }
  }
  return {tier: 'unknown', sourceField: 'none'};
}

module.exports = {
  normalizeTierString,
  resolveTierFromUserDoc,
};
