'use strict';

const assert = require('assert');
const {
  applyCreditDeduction,
  canAffordCredits,
  resolveCreditCost,
} = require('./src/shared/tippy_credit_manager');

function test(name, fn) {
  try {
    fn();
    console.log(`ok ${name}`);
  } catch (err) {
    console.error(`not ok ${name}`);
    throw err;
  }
}

test('uses centralized action costs', () => {
  assert.strictEqual(resolveCreditCost('captionRewrite'), 1);
  assert.strictEqual(resolveCreditCost('contentPlan'), 5);
});

test('deducts exactly once from a successful credit snapshot', () => {
  const next = applyCreditDeduction(
    {remaining: 10, used: 2, limit: 12, tier: 'pro'},
    'captionRewrite',
  );
  assert.deepStrictEqual(next, {
    remaining: 9,
    used: 3,
    limit: 12,
    tier: 'pro',
    resetAt: undefined,
  });
});

test('does not mutate the input snapshot', () => {
  const current = {remaining: 1, used: 0, limit: 1, tier: 'starter'};
  applyCreditDeduction(current, 'captionRewrite');
  assert.deepStrictEqual(current, {
    remaining: 1,
    used: 0,
    limit: 1,
    tier: 'starter',
  });
});

test('returns null without decrement when credits are insufficient', () => {
  const current = {remaining: 0, used: 25, limit: 25, tier: 'starter'};
  assert.strictEqual(canAffordCredits(current.remaining, 'captionRewrite'), false);
  assert.strictEqual(
    applyCreditDeduction(current, 'captionRewrite'),
    null,
  );
  assert.strictEqual(current.remaining, 0);
  assert.strictEqual(current.used, 25);
});

console.log('tippy_credit_manager_test.js: all passed');
