/// Canonical retention events for journey emails (keep in sync with
/// streamerstipReact/types/retention.ts and CROSS_PLATFORM_EVENT_SPEC.md).
class RetentionEventTypes {
  RetentionEventTypes._();

  static const String userSignedUp = 'user_signed_up';
  static const String emailVerified = 'email_verified';
  static const String userLoggedIn = 'user_logged_in';
  static const String connectedFirstPlatform = 'connected_first_platform';
  static const String connectedAdditionalPlatform =
      'connected_additional_platform';
  static const String createdFirstContentPlan = 'created_first_content_plan';
  static const String createdContentPlan = 'created_content_plan';
  static const String editedContentPlan = 'edited_content_plan';
  static const String createdFirstScheduledPost = 'created_first_scheduled_post';
  static const String scheduledPost = 'scheduled_post';
  static const String completedContentItem = 'completed_content_item';
  static const String missedScheduledPost = 'missed_scheduled_post';
  static const String viewedAnalytics = 'viewed_analytics';
  static const String viewedWeeklyReport = 'viewed_weekly_report';
  static const String subscriptionStarted = 'subscription_started';
  static const String subscriptionCanceled = 'subscription_canceled';
}

class RetentionEventSources {
  RetentionEventSources._();

  static const String app = 'app';
  static const String web = 'web';
}
