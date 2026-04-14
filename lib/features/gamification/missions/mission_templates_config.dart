import '../gamification_event_types.dart';
import 'mission_category.dart';
import 'mission_period.dart';
import 'mission_template.dart';

/// All mission templates (config). Server materializes instances + awards XP.
abstract final class MissionTemplatesConfig {
  static const List<MissionTemplate> all = <MissionTemplate>[
    // —— Daily (launch set) ——
    MissionTemplate(
      templateId: 'daily_post_content_v1',
      period: MissionPeriod.daily,
      category: MissionCategory.dailyPosting,
      title: 'Post 1 piece of content',
      description: 'Upload a video, post, or thread.',
      target: 1,
      rewardXp: 40,
      progressEventKeys: <String>[
        GamificationEventTypes.contentVideoUploaded,
        GamificationEventTypes.contentPostCreated,
        GamificationEventTypes.contentThreadCreated,
        GamificationEventTypes.contentPublished,
      ],
      priority: 100,
    ),
    MissionTemplate(
      templateId: 'daily_comments_v1',
      period: MissionPeriod.daily,
      category: MissionCategory.dailyEngagement,
      title: 'Leave 2 comments',
      description: 'Comment on creators you follow.',
      target: 2,
      rewardXp: 16,
      progressEventKeys: <String>[
        GamificationEventTypes.engagementCommentCreated,
      ],
      priority: 90,
    ),
    MissionTemplate(
      templateId: 'daily_plan_item_v1',
      period: MissionPeriod.daily,
      category: MissionCategory.dailyWorkflow,
      title: 'Complete 1 content plan item',
      description: 'Finish a task from your content plan.',
      target: 1,
      rewardXp: 15,
      progressEventKeys: <String>[
        GamificationEventTypes.contentPlanItemCompleted,
      ],
      priority: 85,
    ),
    MissionTemplate(
      templateId: 'daily_academy_lesson_v1',
      period: MissionPeriod.daily,
      category: MissionCategory.dailyWorkflow,
      title: 'Complete 1 academy lesson',
      description: 'Learn something new in Academy.',
      target: 1,
      rewardXp: 20,
      progressEventKeys: <String>[
        GamificationEventTypes.academyLessonCompleted,
      ],
      priority: 80,
    ),
    MissionTemplate(
      templateId: 'daily_streak_v1',
      period: MissionPeriod.daily,
      category: MissionCategory.consistency,
      title: 'Keep your streak alive',
      description: 'One qualifying action today.',
      target: 1,
      rewardXp: 10,
      progressEventKeys: <String>[
        GamificationEventTypes.activityDayQualified,
        GamificationEventTypes.streakExtended,
      ],
      priority: 95,
    ),
    MissionTemplate(
      templateId: 'daily_creator_tool_v1',
      period: MissionPeriod.daily,
      category: MissionCategory.tools,
      title: 'Use 1 creator tool',
      description: 'Caption, Tippy, or a resource.',
      target: 1,
      rewardXp: 12,
      progressEventKeys: <String>[
        GamificationEventTypes.toolCaptionGenerated,
        GamificationEventTypes.toolTippyUsed,
        GamificationEventTypes.resourceToolOpened,
        GamificationEventTypes.toolCaptionGeneratorOpened,
      ],
      priority: 70,
    ),

    // —— Weekly (launch set) ——
    MissionTemplate(
      templateId: 'weekly_publish_3_v1',
      period: MissionPeriod.weekly,
      category: MissionCategory.weeklyGrowth,
      title: 'Publish 3 posts',
      description: 'Videos, posts, or threads.',
      target: 3,
      rewardXp: 80,
      progressEventKeys: <String>[
        GamificationEventTypes.contentPublished,
        GamificationEventTypes.contentVideoUploaded,
        GamificationEventTypes.contentPostCreated,
        GamificationEventTypes.contentThreadCreated,
      ],
      priority: 100,
    ),
    MissionTemplate(
      templateId: 'weekly_active_days_v1',
      period: MissionPeriod.weekly,
      category: MissionCategory.consistency,
      title: 'Be active 5 days',
      description: 'Qualifying actions on 5 different days.',
      target: 5,
      rewardXp: 50,
      progressEventKeys: <String>[
        GamificationEventTypes.activityDayQualified,
        GamificationEventTypes.goalActiveDaysTargetHit,
      ],
      priority: 95,
    ),
    MissionTemplate(
      templateId: 'weekly_plan_items_5_v1',
      period: MissionPeriod.weekly,
      category: MissionCategory.weeklyGrowth,
      title: 'Complete 5 content plan items',
      description: 'Stay on track with your plan.',
      target: 5,
      rewardXp: 75,
      progressEventKeys: <String>[
        GamificationEventTypes.contentPlanItemCompleted,
      ],
      priority: 90,
    ),
    MissionTemplate(
      templateId: 'weekly_connect_2_v1',
      period: MissionPeriod.weekly,
      category: MissionCategory.networking,
      title: 'Connect with 2 creators',
      description: 'Mutual follows or new connections.',
      target: 2,
      rewardXp: 20,
      progressEventKeys: <String>[
        GamificationEventTypes.engagementConnectionCreated,
        GamificationEventTypes.engagementFollowCreated,
      ],
      priority: 85,
    ),
    MissionTemplate(
      templateId: 'weekly_lessons_3_v1',
      period: MissionPeriod.weekly,
      category: MissionCategory.weeklyGrowth,
      title: 'Complete 3 lessons',
      description: 'Grow skills in Academy.',
      target: 3,
      rewardXp: 60,
      progressEventKeys: <String>[
        GamificationEventTypes.academyLessonCompleted,
      ],
      priority: 80,
    ),
    MissionTemplate(
      templateId: 'weekly_cross_post_2_v1',
      period: MissionPeriod.weekly,
      category: MissionCategory.weeklyGrowth,
      title: 'Cross-post 2 pieces of content',
      description: 'Share beyond StreamersTip.',
      target: 2,
      rewardXp: 30,
      progressEventKeys: <String>[
        GamificationEventTypes.contentCrossPosted,
      ],
      priority: 75,
    ),

    // —— Onboarding ——
    MissionTemplate(
      templateId: 'onboard_profile_v1',
      period: MissionPeriod.onboarding,
      category: MissionCategory.onboarding,
      title: 'Complete your profile',
      description: 'Fill in display name, bio, and basics.',
      target: 1,
      rewardXp: 30,
      progressEventKeys: <String>[
        GamificationEventTypes.profileCompleted,
      ],
      priority: 100,
    ),
    MissionTemplate(
      templateId: 'onboard_platform_v1',
      period: MissionPeriod.onboarding,
      category: MissionCategory.onboarding,
      title: 'Connect your first platform',
      description: 'Link Twitch, YouTube, or similar.',
      target: 1,
      rewardXp: 25,
      progressEventKeys: <String>[
        GamificationEventTypes.platformConnected,
        GamificationEventTypes.milestoneFirstPlatformConnected,
      ],
      priority: 95,
    ),
    MissionTemplate(
      templateId: 'onboard_first_post_v1',
      period: MissionPeriod.onboarding,
      category: MissionCategory.onboarding,
      title: 'Make your first post',
      description: 'Share a video, post, or thread.',
      target: 1,
      rewardXp: 40,
      progressEventKeys: <String>[
        GamificationEventTypes.contentVideoUploaded,
        GamificationEventTypes.contentPostCreated,
        GamificationEventTypes.contentThreadCreated,
        GamificationEventTypes.milestoneFirstPost,
      ],
      priority: 90,
    ),
    MissionTemplate(
      templateId: 'onboard_first_lesson_v1',
      period: MissionPeriod.onboarding,
      category: MissionCategory.onboarding,
      title: 'Complete your first lesson',
      description: 'Finish any Academy lesson.',
      target: 1,
      rewardXp: 20,
      progressEventKeys: <String>[
        GamificationEventTypes.academyLessonCompleted,
        GamificationEventTypes.milestoneFirstLesson,
      ],
      priority: 85,
    ),
    MissionTemplate(
      templateId: 'onboard_first_plan_v1',
      period: MissionPeriod.onboarding,
      category: MissionCategory.onboarding,
      title: 'Create your first content plan',
      description: 'Plan your next posts.',
      target: 1,
      rewardXp: 25,
      progressEventKeys: <String>[
        GamificationEventTypes.contentPlanCreated,
        GamificationEventTypes.milestoneFirstPlan,
      ],
      priority: 80,
    ),
  ];

  static List<MissionTemplate> byPeriod(MissionPeriod p) =>
      all.where((MissionTemplate t) => t.period == p).toList();
}
