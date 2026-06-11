'use strict';

const {creditCostForAction} = require('./entitlements');

/**
 * Single entry for AI credit costs — Tippy routes must use this module.
 */
function resolveCreditCost(action) {
  return creditCostForAction(action);
}

function canAffordCredits(remaining, action) {
  const cost = resolveCreditCost(action);
  return Number(remaining) >= cost;
}

function applyCreditDeduction(credits, action) {
  const cost = resolveCreditCost(action);
  const limit = Number(credits.limit) || 0;
  const used = Number(credits.used) || 0;
  const remaining = Number(credits.remaining) || 0;
  if (remaining < cost) {
    return null;
  }
  const nextUsed = used + cost;
  const nextRemaining = remaining - cost;
  return {
    remaining: nextRemaining < 0 ? 0 : nextRemaining,
    used: nextUsed > limit ? limit : nextUsed,
    limit,
    tier: credits.tier,
    resetAt: credits.resetAt,
  };
}

module.exports = {
  applyCreditDeduction,
  canAffordCredits,
  resolveCreditCost,
};
