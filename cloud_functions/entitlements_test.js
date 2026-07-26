'use strict';

const assert = require('assert');
const {
  getEntitlementsForTier,
  getAiCreditLimitForTier,
  hasBillingFeature,
  creditCostForAction,
  isUnlimited,
  canCreateContentPlan,
  canUploadVideo,
} = require('./src/shared/entitlements');

function test(name, fn) {
  try {
    fn();
    console.log(`ok ${name}`);
  } catch (err) {
    console.error(`FAIL ${name}`);
    throw err;
  }
}

test('starter AI credits are 25', () => {
  assert.strictEqual(getAiCreditLimitForTier('starter'), 25);
  assert.strictEqual(getAiCreditLimitForTier('creator'), 25);
});

test('pro AI credits are 500', () => {
  assert.strictEqual(getAiCreditLimitForTier('pro'), 500);
});

test('studio AI credits are 2500', () => {
  assert.strictEqual(getAiCreditLimitForTier('studio'), 2500);
});

test('pro has unlimited content plans', () => {
  const ent = getEntitlementsForTier('pro');
  assert.strictEqual(isUnlimited(ent.contentPlans), true);
  assert.strictEqual(ent.connectedPlatforms, 5);
});

test('studio has team feature', () => {
  assert.strictEqual(hasBillingFeature('studio', 'teamMembers'), true);
  assert.strictEqual(hasBillingFeature('starter', 'automation'), false);
});

test('credit costs', () => {
  assert.strictEqual(creditCostForAction('contentPlan'), 5);
  assert.strictEqual(creditCostForAction('growthAnalysis'), 10);
});

test('starter content plan limit is one', () => {
  assert.strictEqual(getEntitlementsForTier('starter').contentPlans, 1);
  assert.strictEqual(canCreateContentPlan('starter', 0), true);
  assert.strictEqual(canCreateContentPlan('starter', 1), false);
  assert.strictEqual(canCreateContentPlan('pro', 10), true);
});

test('uploads are unlimited on all tiers', () => {
  assert.strictEqual(isUnlimited(getEntitlementsForTier('starter').videoUploadsPerMonth), true);
  assert.strictEqual(isUnlimited(getEntitlementsForTier('pro').videoUploadsPerMonth), true);
  assert.strictEqual(isUnlimited(getEntitlementsForTier('studio').videoUploadsPerMonth), true);
  assert.strictEqual(canUploadVideo('starter', 999), true);
});

test('starter does not include cross-post or advanced analytics', () => {
  assert.strictEqual(hasBillingFeature('starter', 'crossPosting'), false);
  assert.strictEqual(hasBillingFeature('pro', 'advancedAnalytics'), false);
  assert.strictEqual(hasBillingFeature('studio', 'advancedAnalytics'), true);
});

console.log('entitlements_test.js: all passed');
