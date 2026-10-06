'use strict';

const {
  isPaidSubscriptionStatus,
  isSubscriptionPeriodActive,
  normalizeTierString,
} = require('./subscription_entitlements');

/**
 * Canonical tier resolution — server-owned fields only.
 * Does not read client-writable fields (plan, tier, stripeRole, or the
 * users/{uid}.subscription map). Billing docs are merged into
 * `subscriptionTier` by loadUserWithBilling.
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

  return {tier: 'starter', sourceField: 'none'};
}

module.exports = {
  normalizeTierString,
  resolveTierFromUserDoc,
};
