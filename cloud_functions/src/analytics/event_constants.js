/** Keep in sync with shared/analytics/event_constants.js */
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
  ANALYTICS_PROFILE_DOC_ID,
  EVENT_ENGAGEMENT_WEIGHTS,
};
