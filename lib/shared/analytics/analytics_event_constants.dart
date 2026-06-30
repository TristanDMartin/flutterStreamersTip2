/// Canonical Creator Intelligence analytics events (app + website).
/// Keep in sync with shared/analytics/event_constants.js
library;

class AnalyticsEventTypes {
  AnalyticsEventTypes._();

  static const String videoViewed = 'video_viewed';
  static const String videoCompleted = 'video_completed';
  static const String videoSkipped = 'video_skipped';
  static const String postLiked = 'post_liked';
  static const String postSaved = 'post_saved';
  static const String commentCreated = 'comment_created';
  static const String profileViewed = 'profile_viewed';
  static const String creatorCardOpened = 'creator_card_opened';
  static const String toolOpened = 'tool_opened';
  static const String guideRead = 'guide_read';
  static const String courseStepCompleted = 'course_step_completed';
  static const String searchPerformed = 'search_performed';
  static const String tippyQuestionAsked = 'tippy_question_asked';
  static const String platformConnected = 'platform_connected';
  static const String contentPlanCreated = 'content_plan_created';
  static const String subscriptionGateSeen = 'subscription_gate_seen';
  static const String subscriptionStarted = 'subscription_started';
  static const String subscriptionCancelled = 'subscription_cancelled';
  static const String personalizationCtaTapped = 'personalization_cta_tapped';
}

class AnalyticsSources {
  AnalyticsSources._();

  static const String app = 'app';
  static const String website = 'website';
}

class AnalyticsTargetTypes {
  AnalyticsTargetTypes._();

  static const String video = 'video';
  static const String tool = 'tool';
  static const String guide = 'guide';
  static const String profile = 'profile';
  static const String course = 'course';
  static const String personalization = 'personalization';
}

const String kAnalyticsProfileDocId = 'profile';

const String kAnalyticsPrivacyNotice =
    'We use activity data to improve your recommendations, analytics, '
    'and creator growth tools.';
