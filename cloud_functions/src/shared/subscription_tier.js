'use strict';

const {
  isPaidSubscriptionStatus,
  isSubscriptionPeriodActive,
  normalizeTierString,
  readPeriodEndFromUserDoc,
} = require('./subscription_entitlements');

/**
 * Canonical tier resolution — server-owned fields only.
 * Does not read client-writable legacy root fields (plan, tier, stripeRole).
 */
function resolveTierFromUserDoc(userData = {}) {
  const rootTierRaw = userData.subscriptionTier;
  const rootStatus = String(userData.subscriptionStatus || '')
    .toLowerCase()
    .trim();
  const periodActive = isSubscriptionPeriodActive(userData);

  if (
    rootTierRaw !== undefined &&
    rootTierRaw !== null &&
    String(rootTierRaw).trim() !== ''
  ) {
    const normalizedRoot = normalizeTierString(rootTierRaw);
    if (normalizedRoot) {
      if (isPaidSubscriptionStatus(rootStatus) && periodActive) {
        return {tier: normalizedRoot, sourceField: 'subscriptionTier'};
      }
      return {tier: 'starter', sourceField: 'subscriptionTier+inactive'};
    }
  }

  const sub =
    userData.subscription && typeof userData.subscription === 'object'
      ? userData.subscription
      : {};
  const subStatus = String(sub.status || sub.subscriptionStatus || '')
    .toLowerCase()
    .trim();
  const subTier = normalizeTierString(sub.tier || sub.plan);
  const subPeriodEnd = readPeriodEndFromUserDoc({subscription: sub});
  const subPeriodActive =
    !subPeriodEnd || subPeriodEnd.getTime() > Date.now();

  if (
    subTier &&
    isPaidSubscriptionStatus(subStatus) &&
    subPeriodActive
  ) {
    return {tier: subTier, sourceField: 'subscription.tier'};
  }

  return {tier: 'starter', sourceField: 'none'};
}

module.exports = {
  normalizeTierString,
  resolveTierFromUserDoc,
};
