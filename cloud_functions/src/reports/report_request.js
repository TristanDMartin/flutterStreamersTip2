'use strict';

const TARGET_TYPES = Object.freeze([
  'video',
  'user',
  'videoComment',
  'thread',
  'threadComment',
  'message',
]);

const MAX_REASON_LENGTH = 120;
const MAX_DETAILS_LENGTH = 1000;
const ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;
const RATE_LIMIT_MAX_REPORTS = 20;

function isValidId(value) {
  return typeof value === 'string' && ID_PATTERN.test(value);
}

function readOptionalId(value) {
  if (value == null || value === '') return null;
  return isValidId(value) ? value : undefined;
}

const REQUIRED_PARENT_KEY = Object.freeze({
  videoComment: 'videoId',
  threadComment: 'postId',
  message: 'chatId',
});

/**
 * Validates and normalizes a raw callable payload.
 * Returns `{ok: false, reason}` or `{ok: true, request}`.
 */
function parseReportRequest(raw) {
  if (!raw || typeof raw !== 'object') return {ok: false, reason: 'invalid_payload'};
  const targetType = String(raw.targetType || '');
  if (!TARGET_TYPES.includes(targetType)) return {ok: false, reason: 'invalid_target_type'};
  if (!isValidId(raw.targetId)) return {ok: false, reason: 'invalid_target_id'};
  const reason = typeof raw.reason === 'string' ? raw.reason.trim() : '';
  if (!reason || reason.length > MAX_REASON_LENGTH) return {ok: false, reason: 'invalid_reason'};
  const details = typeof raw.details === 'string' ? raw.details.trim() : '';
  if (details.length > MAX_DETAILS_LENGTH) return {ok: false, reason: 'details_too_long'};
  const videoId = readOptionalId(raw.videoId);
  const postId = readOptionalId(raw.postId);
  const chatId = readOptionalId(raw.chatId);
  if ([videoId, postId, chatId].includes(undefined)) return {ok: false, reason: 'invalid_context_id'};
  const parentKey = REQUIRED_PARENT_KEY[targetType];
  const context = {videoId, postId, chatId};
  if (parentKey && !context[parentKey]) return {ok: false, reason: `missing_${parentKey}`};
  return {
    ok: true,
    request: {targetType, targetId: raw.targetId, reason, details: details || null, ...context},
  };
}

/** Deterministic id: one report per reporter per target. */
function buildReportId(input) {
  const parentKey = REQUIRED_PARENT_KEY[input.targetType];
  const targetKey = parentKey ? `${input[parentKey]}_${input.targetId}` : input.targetId;
  return `${input.reporterId}_${input.targetType}_${targetKey}`;
}

function isRateLimited(limitData, nowMs) {
  const windowStart = limitData?.windowStartMs || 0;
  if (nowMs - windowStart >= RATE_LIMIT_WINDOW_MS) return false;
  return (limitData?.count || 0) >= RATE_LIMIT_MAX_REPORTS;
}

function nextRateLimit(limitData, nowMs) {
  const windowStart = limitData?.windowStartMs || 0;
  if (nowMs - windowStart >= RATE_LIMIT_WINDOW_MS) return {windowStartMs: nowMs, count: 1};
  return {windowStartMs: windowStart, count: (limitData?.count || 0) + 1};
}

module.exports = {
  TARGET_TYPES,
  MAX_DETAILS_LENGTH,
  RATE_LIMIT_MAX_REPORTS,
  parseReportRequest,
  buildReportId,
  isRateLimited,
  nextRateLimit,
};
