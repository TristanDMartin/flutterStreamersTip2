/// Canonical event `type` strings for trusted `emitTrustedEvent` calls.
/// Backend owns XP, mission progress, and deduplication by `eventId`.
abstract final class GamificationEventTypes {
  static const String userOnboardingCompleted = 'user.onboarding_completed';

  static const String profileCompleted = 'profile.completed';
  static const String profileAvatarUploaded = 'profile.avatar_uploaded';
  static const String profileBioCompleted = 'profile.bio_completed';
  static const String profileCategorySelected = 'profile.category_selected';
  static const String profileSocialLinkAdded = 'profile.social_link_added';
  static const String profileScheduleAdded = 'profile.schedule_added';
  static const String creatorCardCompleted = 'creator_card.completed';

  static const String platformConnected = 'platform.connected';
  static const String platformDisconnected = 'platform.disconnected';

  static const String contentVideoUploaded = 'content.video_uploaded';
  static const String contentPostCreated = 'content.post_created';
  static const String contentThreadCreated = 'content.thread_created';
  static const String contentPublished = 'content.published';
  static const String contentCrossPosted = 'content.cross_posted';
  static const String contentCaptionAdded = 'content.caption_added';
  static const String contentHashtagsAdded = 'content.hashtags_added';
  static const String contentDraftSaved = 'content.draft_saved';
  static const String contentScheduled = 'content.scheduled';
  static const String contentPlanCreated = 'content.plan_created';
  static const String contentPlanItemCreated = 'content.plan_item_created';
  static const String contentPlanItemCompleted = 'content.plan_item_completed';
  static const String contentPlanItemRescheduled =
      'content.plan_item_rescheduled';

  static const String engagementCommentCreated = 'engagement.comment_created';
  static const String engagementReplyCreated = 'engagement.reply_created';
  static const String engagementLikeGiven = 'engagement.like_given';
  static const String engagementBookmarkCreated = 'engagement.bookmark_created';
  static const String engagementShareCreated = 'engagement.share_created';
  static const String engagementFollowCreated = 'engagement.follow_created';
  static const String engagementConnectionCreated =
      'engagement.connection_created';

  static const String academyLessonCompleted = 'academy.lesson_completed';
  static const String academyModuleCompleted = 'academy.module_completed';
  static const String academyCertificateEarned = 'academy.certificate_earned';
  static const String academyGuideViewed = 'academy.guide_viewed';
  static const String academyGuideBookmarked = 'academy.guide_bookmarked';
  static const String academyTrackCompleted = 'academy.track_completed';

  static const String communityMessageSent = 'community.message_sent';
  static const String communityMessageReplied = 'community.message_replied';
  static const String communityCollabRequestSent =
      'community.collab_request_sent';
  static const String communityConnectionAccepted =
      'community.connection_accepted';
  static const String communityThreadParticipated =
      'community.thread_participated';
  static const String communityLiveEventJoined = 'community.live_event_joined';
  static const String communityHelpfulReplyLiked =
      'community.helpful_reply_liked';

  static const String toolCaptionGeneratorOpened =
      'tool.caption_generator_opened';
  static const String toolCaptionGenerated = 'tool.caption_generated';
  static const String toolTippyUsed = 'tool.tippy_used';
  static const String toolOutputSaved = 'tool.output_saved';
  static const String toolWalkthroughCompleted = 'tool.walkthrough_completed';

  static const String resourceLibraryOpened = 'resource.library_opened';
  static const String resourceTemplateSaved = 'resource.template_saved';
  static const String resourceBookmarkCreated = 'resource.bookmark_created';
  static const String resourceToolOpened = 'resource.tool_opened';

  static const String discoverCreatorProfileViewed =
      'discover.creator_profile_viewed';
  static const String discoverCategoryOpened = 'discover.category_opened';
  static const String discoverSearchUsed = 'discover.search_used';
  static const String discoverTrendingViewed = 'discover.trending_viewed';

  static const String activityDayQualified = 'activity.day_qualified';
  static const String streakExtended = 'streak.extended';
  static const String streakMilestoneReached = 'streak.milestone_reached';

  static const String goalWeeklyPostGoalHit = 'goal.weekly_post_goal_hit';
  static const String goalConsistencyTargetHit = 'goal.consistency_target_hit';
  static const String goalActiveDaysTargetHit = 'goal.active_days_target_hit';
  static const String goalPostingStreakHit = 'goal.posting_streak_hit';
  static const String goalEngagementStreakHit = 'goal.engagement_streak_hit';

  static const String levelUp = 'level.up';
  static const String achievementUnlocked = 'achievement.unlocked';
  static const String missionCompleted = 'mission.completed';

  static const String milestoneFirstPost = 'milestone.first_post';
  static const String milestoneFirstComment = 'milestone.first_comment';
  static const String milestoneFirstLesson = 'milestone.first_lesson';
  static const String milestoneFirstPlan = 'milestone.first_plan';
  static const String milestoneFirstPlatformConnected =
      'milestone.first_platform_connected';
}
