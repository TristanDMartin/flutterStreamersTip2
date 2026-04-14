/**
 * Mirrors lib/features/gamification/missions/mission_templates_config.dart
 */
const MISSION_TEMPLATES = {
  daily_post_content_v1: {
    target: 1,
    rewardXp: 40,
    progressEventKeys: new Set([
      'content.video_uploaded',
      'content.post_created',
      'content.thread_created',
      'content.published',
    ]),
  },
  daily_comments_v1: {
    target: 2,
    rewardXp: 16,
    progressEventKeys: new Set(['engagement.comment_created']),
  },
  daily_plan_item_v1: {
    target: 1,
    rewardXp: 15,
    progressEventKeys: new Set(['content.plan_item_completed']),
  },
  daily_academy_lesson_v1: {
    target: 1,
    rewardXp: 20,
    progressEventKeys: new Set(['academy.lesson_completed']),
  },
  daily_streak_v1: {
    target: 1,
    rewardXp: 10,
    progressEventKeys: new Set(['activity.day_qualified', 'streak.extended']),
  },
  daily_creator_tool_v1: {
    target: 1,
    rewardXp: 12,
    progressEventKeys: new Set([
      'tool.caption_generated',
      'tool.tippy_used',
      'resource.tool_opened',
      'tool.caption_generator_opened',
    ]),
  },
  weekly_publish_3_v1: {
    target: 3,
    rewardXp: 80,
    progressEventKeys: new Set([
      'content.published',
      'content.video_uploaded',
      'content.post_created',
      'content.thread_created',
    ]),
  },
  weekly_active_days_v1: {
    target: 5,
    rewardXp: 50,
    progressEventKeys: new Set([
      'activity.day_qualified',
      'goal.active_days_target_hit',
    ]),
  },
  weekly_plan_items_5_v1: {
    target: 5,
    rewardXp: 75,
    progressEventKeys: new Set(['content.plan_item_completed']),
  },
  weekly_connect_2_v1: {
    target: 2,
    rewardXp: 20,
    progressEventKeys: new Set([
      'engagement.connection_created',
      'engagement.follow_created',
    ]),
  },
  weekly_lessons_3_v1: {
    target: 3,
    rewardXp: 60,
    progressEventKeys: new Set(['academy.lesson_completed']),
  },
  weekly_cross_post_2_v1: {
    target: 2,
    rewardXp: 30,
    progressEventKeys: new Set(['content.cross_posted']),
  },
  onboard_profile_v1: {
    target: 1,
    rewardXp: 30,
    progressEventKeys: new Set(['profile.completed']),
  },
  onboard_platform_v1: {
    target: 1,
    rewardXp: 25,
    progressEventKeys: new Set([
      'platform.connected',
      'milestone.first_platform_connected',
    ]),
  },
  onboard_first_post_v1: {
    target: 1,
    rewardXp: 40,
    progressEventKeys: new Set([
      'content.video_uploaded',
      'content.post_created',
      'content.thread_created',
      'milestone.first_post',
    ]),
  },
  onboard_first_lesson_v1: {
    target: 1,
    rewardXp: 20,
    progressEventKeys: new Set([
      'academy.lesson_completed',
      'milestone.first_lesson',
    ]),
  },
  onboard_first_plan_v1: {
    target: 1,
    rewardXp: 25,
    progressEventKeys: new Set([
      'content.plan_created',
      'milestone.first_plan',
    ]),
  },
};

module.exports = {MISSION_TEMPLATES};
