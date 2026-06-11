'use strict';

const admin = require('firebase-admin');

const {getAiCreditLimitForTier} = require('./entitlements');

const DEFAULT_CREDIT_LIMIT = getAiCreditLimitForTier('pro');

function toNum(val) {
  if (val === undefined || val === null) {
    return NaN;
  }
  if (typeof val === 'number' && !Number.isNaN(val)) {
    return val;
  }
  const n = Number(String(val).trim());
  return Number.isFinite(n) ? n : NaN;
}

function toCreditSnapshot(rawCredits, fallbackLimit) {
  const remaining = Number(rawCredits.remaining || 0);
  const used = Number(rawCredits.used || 0);
  const limit = Number(
    rawCredits.limit !== undefined && rawCredits.limit !== null
      ? rawCredits.limit
      : fallbackLimit,
  );
  const tier = String(rawCredits.tier || 'starter');
  return {
    remaining: remaining < 0 ? 0 : remaining,
    used: used < 0 ? 0 : used,
    limit,
    tier,
  };
}

function readDate(val) {
  if (!val) {
    return null;
  }
  if (typeof val.toDate === 'function') {
    return val.toDate();
  }
  if (val instanceof Date) {
    return val;
  }
  const d = new Date(val);
  return Number.isNaN(d.getTime()) ? null : d;
}

function nextMonthlyResetAt(now = new Date()) {
  return new Date(Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth() + 1,
    1,
    0,
    0,
    0,
  ));
}

function normalizeLegacyCredits(rawCredits, access) {
  const credits = toCreditSnapshot(
    rawCredits,
    access.limit > 0 ? access.limit : DEFAULT_CREDIT_LIMIT,
  );
  const cap = access.limit > 0 ? access.limit : credits.limit;
  const cappedUsed = credits.used > cap ? cap : credits.used;
  const derivedRemaining = cap - cappedUsed;
  return {
    remaining: derivedRemaining < 0 ? 0 : derivedRemaining,
    used: cappedUsed,
    limit: cap,
    tier: access.tier,
  };
}

function firstFiniteNum(obj, keys) {
  if (!obj || typeof obj !== 'object') {
    return NaN;
  }
  for (let i = 0; i < keys.length; i++) {
    const v = toNum(obj[keys[i]]);
    if (Number.isFinite(v)) {
      return v;
    }
  }
  return NaN;
}

/**
 * Website billing may use varying keys on entitlements.tippyAi.
 * Legacy path uses users.tippyCredits. Prefer entitlements when present.
 */
function readEntitlementTippyCreditHints(userData) {
  const ent = userData.entitlements && userData.entitlements.tippyAi;
  if (!ent || typeof ent !== 'object' || Array.isArray(ent)) {
    return null;
  }
  const limitKeys = [
    'monthlyCredits',
    'monthly_credits',
    'monthlyAiCredits',
    'aiCreditLimit',
    'creditLimit',
    'creditsLimit',
  ];
  const usedKeys = [
    'usedCredits',
    'used_credits',
    'aiCreditsUsed',
    'creditsUsed',
    'used',
  ];
  const remKeys = [
    'remainingCredits',
    'remaining_credits',
    'aiCreditsRemaining',
    'creditsRemaining',
    'balance',
    'remaining',
  ];
  const limit = firstFiniteNum(ent, limitKeys);
  const used = firstFiniteNum(ent, usedKeys);
  const rem = firstFiniteNum(ent, remKeys);
  if (!Number.isFinite(limit) || limit <= 0) {
    return null;
  }
  if (Number.isFinite(rem) && rem >= 0) {
    const usedDerived = Math.min(limit, Math.max(0, limit - rem));
    return {
      limit,
      used: usedDerived,
      remaining: Math.min(rem, limit),
    };
  }
  if (Number.isFinite(used) && used >= 0) {
    const u = used > limit ? limit : used;
    return {
      limit,
      used: u,
      remaining: Math.max(0, limit - u),
    };
  }
  return null;
}

function resolveCreditsForUser(userData, access) {
  const directLimit = toNum(userData.creditsMonthlyLimit);
  const directRemaining = toNum(userData.creditsRemaining);
  const directReset = readDate(userData.creditsResetAt);
  const effectiveLimit = access.limit > 0
    ? access.limit
    : Number.isFinite(directLimit) && directLimit > 0
      ? directLimit
      : DEFAULT_CREDIT_LIMIT;
  if (!directReset || directReset.getTime() <= Date.now()) {
    return {
      remaining: effectiveLimit,
      used: 0,
      limit: effectiveLimit,
      tier: access.tier,
      resetAt: nextMonthlyResetAt(),
      needsReset: true,
    };
  }
  if (Number.isFinite(directLimit) && directLimit > 0 &&
      Number.isFinite(directRemaining) && directRemaining >= 0) {
    const remaining = Math.min(directRemaining, effectiveLimit);
    return {
      remaining,
      used: Math.max(0, effectiveLimit - remaining),
      limit: effectiveLimit,
      tier: access.tier,
      resetAt: directReset,
      needsReset: false,
    };
  }
  const legacy = normalizeLegacyCredits(userData.tippyCredits || {}, access);
  const hint = readEntitlementTippyCreditHints(userData);
  if (!hint) {
    return {
      ...legacy,
      resetAt: directReset || nextMonthlyResetAt(),
      needsReset: false,
    };
  }
  const mergedLimit = Math.max(
    hint.limit,
    access.limit,
    legacy.limit,
  );
  if (legacy.remaining <= 0 && hint.remaining > 0) {
    return {
      remaining: Math.min(hint.remaining, mergedLimit),
      used: Math.min(hint.used, mergedLimit),
      limit: mergedLimit,
      tier: access.tier,
      resetAt: directReset || nextMonthlyResetAt(),
      needsReset: false,
    };
  }
  if (legacy.remaining > 0 || legacy.used > 0) {
    return {
      remaining: legacy.remaining,
      used: legacy.used,
      limit: mergedLimit,
      tier: access.tier,
      resetAt: directReset || nextMonthlyResetAt(),
      needsReset: false,
    };
  }
  return {
    remaining: Math.min(hint.remaining, mergedLimit),
    used: Math.min(hint.used, mergedLimit),
    limit: mergedLimit,
    tier: access.tier,
    resetAt: directReset || nextMonthlyResetAt(),
    needsReset: false,
  };
}

function buildCreditWrite(credits, access) {
  const resetAt = credits.resetAt || nextMonthlyResetAt();
  return {
    tier: access.tier,
    effectiveTier: access.tier,
    hasStudioAccess: access.hasStudioAccess === true,
    subscriptionStatus: access.status,
    billingRequired: access.billingRequired !== false,
    creditsRemaining: credits.remaining,
    creditsMonthlyLimit: credits.limit,
    creditsResetAt: admin.firestore.Timestamp.fromDate(resetAt),
    tippyCredits: {
      remaining: credits.remaining,
      used: credits.used,
      limit: credits.limit,
      tier: access.tier,
    },
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

module.exports = {
  buildCreditWrite,
  nextMonthlyResetAt,
  resolveCreditsForUser,
  normalizeLegacyCredits,
  readEntitlementTippyCreditHints,
  toCreditSnapshot,
};
