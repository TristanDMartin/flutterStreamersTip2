'use strict';

const assert = require('assert');
const {
  RATE_LIMIT_MAX_REPORTS,
  parseReportRequest,
  buildReportId,
  isRateLimited,
  nextRateLimit,
} = require('./src/reports/report_request');

function test(name, fn) {
  try {
    fn();
    console.log(`ok ${name}`);
  } catch (err) {
    console.error(`FAIL ${name}`);
    throw err;
  }
}

test('accepts a valid video report', () => {
  const actual = parseReportRequest({targetType: 'video', targetId: 'v1', reason: ' Spam '});
  assert.deepStrictEqual(actual, {
    ok: true,
    request: {
      targetType: 'video', targetId: 'v1', reason: 'Spam', details: null,
      videoId: null, postId: null, chatId: null,
    },
  });
});

test('rejects unknown target type', () => {
  const actual = parseReportRequest({targetType: 'livestream', targetId: 'x', reason: 'Spam'});
  assert.strictEqual(actual.reason, 'invalid_target_type');
});

test('rejects path-like target ids', () => {
  const actual = parseReportRequest({targetType: 'video', targetId: '../users/a', reason: 'Spam'});
  assert.strictEqual(actual.reason, 'invalid_target_id');
});

test('rejects missing reason and oversized details', () => {
  assert.strictEqual(parseReportRequest({targetType: 'video', targetId: 'v', reason: ' '}).reason, 'invalid_reason');
  const inputDetails = 'x'.repeat(1001);
  const actual = parseReportRequest({targetType: 'video', targetId: 'v', reason: 'Spam', details: inputDetails});
  assert.strictEqual(actual.reason, 'details_too_long');
});

test('nested targets require their parent id', () => {
  assert.strictEqual(parseReportRequest({targetType: 'videoComment', targetId: 'c', reason: 'Spam'}).reason, 'missing_videoId');
  assert.strictEqual(parseReportRequest({targetType: 'threadComment', targetId: 'c', reason: 'Spam'}).reason, 'missing_postId');
  assert.strictEqual(parseReportRequest({targetType: 'message', targetId: 'm', reason: 'Spam'}).reason, 'missing_chatId');
});

test('rejects invalid context ids', () => {
  const actual = parseReportRequest({targetType: 'user', targetId: 'u', reason: 'Spam', chatId: 'a/b'});
  assert.strictEqual(actual.reason, 'invalid_context_id');
});

test('report id is deterministic and scoped for nested targets', () => {
  assert.strictEqual(buildReportId({reporterId: 'r', targetType: 'video', targetId: 'v1'}), 'r_video_v1');
  assert.strictEqual(
      buildReportId({reporterId: 'r', targetType: 'videoComment', targetId: 'c1', videoId: 'v1'}),
      'r_videoComment_v1_c1',
  );
  assert.strictEqual(
      buildReportId({reporterId: 'r', targetType: 'user', targetId: 'u1', chatId: 'dm_r_u1'}),
      'r_user_u1',
  );
});

test('rate limit blocks at max within window and resets after', () => {
  const nowMs = 10 * 60 * 60 * 1000;
  const inputFull = {windowStartMs: nowMs - 1000, count: RATE_LIMIT_MAX_REPORTS};
  assert.strictEqual(isRateLimited(inputFull, nowMs), true);
  assert.strictEqual(isRateLimited({windowStartMs: nowMs - 2 * 60 * 60 * 1000, count: 99}, nowMs), false);
  assert.deepStrictEqual(nextRateLimit(undefined, nowMs), {windowStartMs: nowMs, count: 1});
  assert.deepStrictEqual(nextRateLimit({windowStartMs: nowMs - 1000, count: 3}, nowMs), {windowStartMs: nowMs - 1000, count: 4});
});
