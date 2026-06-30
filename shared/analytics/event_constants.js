/**
 * Canonical Creator Intelligence analytics events (app + website).
 * Keep in sync with lib/shared/analytics/analytics_event_constants.dart
 */

const ANALYTICS_EVENT_TYPES = Object.freeze({
  VIDEO_VIEWED: 'video_viewed',
  VIDEO_COMPLETED: 'video_completed',
  VIDEO_SKIPPED: 'video_skipped',
  POST_LIKED: 'post_liked',
  POST_SAVED: 'post_saved',
  COMMENT_CREATED: 'comment_created',
  PROFILE_VIEWED: 'profile_viewed',
  CREATOR_CARD_OPENED: 'creator_card_opened',
  TOOL_OPENED: 'tool_opened',
  GUIDE_READ: 'guide_read',
  COURSE_STEP_COMPLETED: 'course_step_completed',
  SEARCH_PERFORMED: 'search_performed',
  TIPPY_QUESTION_ASKED: 'tippy_question_asked',
  PLATFORM_CONNECTED: 'platform_connected',
  CONTENT_PLAN_CREATED: 'content_plan_created',
  SUBSCRIPTION_GATE_SEEN: 'subscription_gate_seen',
  SUBSCRIPTION_STARTED: 'subscription_started',
  SUBSCRIPTION_CANCELLED: 'subscription_cancelled',
  PERSONALIZATION_CTA_TAPPED: 'personalization_cta_tapped',
});

const ANALYTICS_SOURCES = Object.freeze({
  APP: 'app',
  WEBSITE: 'website',
});

const ANALYTICS_TARGET_TYPES = Object.freeze({
  VIDEO: 'video',
  TOOL: 'tool',
  GUIDE: 'guide',
  PROFILE: 'profile',
  COURSE: 'course',
  PERSONALIZATION: 'personalization',
});

const ANALYTICS_PROFILE_DOC_ID = 'profile';

const EVENT_ENGAGEMENT_WEIGHTS = Object.freeze({
  video_viewed: 1,
  video_completed: 3,
  video_skipped: -1,
  post_liked: 2,
  post_saved: 2,
  comment_created: 3,
  profile_viewed: 1,
  creator_card_opened: 1,
  tool_opened: 2,
  guide_read: 2,
  course_step_completed: 4,
  search_performed: 1,
  tippy_question_asked: 2,
  platform_connected: 5,
  content_plan_created: 4,
  subscription_gate_seen: 0,
  subscription_started: 8,
  subscription_cancelled: -3,
});

module.exports = {
  ANALYTICS_EVENT_TYPES,
  ANALYTICS_SOURCES,
  ANALYTICS_TARGET_TYPES,
  ANALYTICS_PROFILE_DOC_ID,
  EVENT_ENGAGEMENT_WEIGHTS,
};
