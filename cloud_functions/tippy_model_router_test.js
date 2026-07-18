'use strict';

const assert = require('assert');
const {
  DEFAULT_MODEL,
  FALLBACK_MODELS,
  normalizeModel,
  resolveFallbackModelsForPath,
  resolveModelForPath,
} = require('./src/tippy/tippy_model_router');

function test(name, fn) {
  try {
    fn();
    console.log(`ok ${name}`);
  } catch (err) {
    console.error(`not ok ${name}`);
    throw err;
  }
}

const OLD_ENV = {...process.env};

function resetEnv() {
  process.env = {...OLD_ENV};
  delete process.env.TIPPY_CHAT_MODEL;
  delete process.env.TIPPY_ANTHROPIC_MODEL;
  delete process.env.ANTHROPIC_MODEL;
  delete process.env.TIPPY_ANTHROPIC_FALLBACK_MODELS;
}

test('uses active default model', () => {
  resetEnv();
  assert.strictEqual(DEFAULT_MODEL, 'claude-sonnet-4-6');
  assert.strictEqual(resolveModelForPath('/tippy/chat', {}), DEFAULT_MODEL);
});

test('maps retired Claude model ids to supported replacements', () => {
  resetEnv();
  assert.strictEqual(
    normalizeModel('claude-sonnet-4-20250514'),
    'claude-sonnet-4-6',
  );
  assert.strictEqual(
    normalizeModel('claude-3-5-haiku-20241022'),
    'claude-haiku-4-5-20251001',
  );
});

test('normalizes route env models before sending provider request', () => {
  resetEnv();
  process.env.TIPPY_CHAT_MODEL = 'claude-sonnet-4-20250514';
  assert.strictEqual(resolveModelForPath('/tippy/chat', {}), DEFAULT_MODEL);
});

test('builds unique fallback chain from env and production defaults', () => {
  resetEnv();
  process.env.TIPPY_CHAT_MODEL = 'claude-sonnet-4-20250514';
  process.env.TIPPY_ANTHROPIC_FALLBACK_MODELS =
    'claude-sonnet-4-6, claude-3-5-haiku-20241022';
  assert.deepStrictEqual(resolveFallbackModelsForPath('/tippy/chat', {}), [
    DEFAULT_MODEL,
    ...FALLBACK_MODELS,
  ]);
});

resetEnv();
console.log('tippy_model_router_test.js: all passed');
