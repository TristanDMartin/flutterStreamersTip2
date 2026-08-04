import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/home_video.dart';
import '../models/user.dart';
import '../views/linked_platforms_view.dart';
import '../views/manage_posts_view.dart';
import '../views/search_screen.dart';
import '../views/settings_view.dart';
import '../views/upgrade_view.dart';
import '../widgets/activity_view.dart';
import '../widgets/app_startup_wrapper.dart';
import '../widgets/chat_view_optimized.dart';
import '../widgets/discover_view.dart';
import '../widgets/inbox_view_optimized.dart';
import '../widgets/player_screen.dart';
import '../pages/video_unavailable_page.dart';
import '../widgets/profile_view_optimized.dart';
import '../widgets/tiktok_camera_view.dart';
import '../features/analytics/creator_intelligence_view.dart';
import '../features/analytics/creator_video_insights_view.dart';
import '../features/analytics/growth_analytics_view.dart';
import '../features/content_planning/content_planner_view.dart';
import '../features/content_scheduler/content_scheduler_view.dart';
import '../features/academy/views/academy_category_view.dart';
import '../features/academy/views/academy_guide_view.dart';
import '../features/academy/views/academy_home_view.dart';
import '../features/academy/views/academy_lesson_view.dart';
import '../features/academy/views/academy_path_view.dart';
import '../features/academy/views/academy_progress_view.dart';
import '../features/academy/views/academy_saved_view.dart';
import '../features/academy/views/academy_search_view.dart';
import '../features/approvals/approval_review_view.dart';
import '../features/reports/weekly_report_view.dart';
import '../features/studio/studio_team_control_view.dart';
import '../features/onboarding_tippy/tippy_onboarding_view.dart';
import '../features/tippy/models/tippy_launch_context.dart';
import '../features/tippy/tippy_chat_page.dart';

class AppRoutes {
  static const String root = '/';
  static const String auth = '/auth';
  static const String home = '/home';
  static const String onboarding = '/onboarding';
  static const String contextualTip = '/contextual_tip';
  static const String network = '/network';
  static const String camera = '/camera';
  static const String inbox = '/inbox';
  static const String settings = '/settings';
  static const String managePosts = '/manage-posts';
  static const String contentPlanner = '/content-planner';
  static const String contentScheduler = '/content-scheduler';
  static const String upgrade = '/upgrade';
  static const String linkedPlatforms = '/linked-platforms';
  static const String discover = '/discover';
  static const String academy = '/academy';
  static const String academySearch = '/academy/search';
  static const String academySaved = '/academy/saved';
  static const String academyProgress = '/academy/progress';
  static const String academyCategory = '/academy/category';
  static const String academyPath = '/academy/path';
  static const String academyGuide = '/academy/guide';
  static const String academyLesson = '/academy/lesson';
  static const String activity = '/activity';
  static const String search = '/search';
  static const String player = '/player';
  static const String profile = '/profile';
  static const String chat = '/chat';
  static const String tippyChat = '/tippy';
  static const String videoUnavailable = '/video-unavailable';
  static const String editProfile = '/edit_profile';
  static const String editLinks = '/edit_links';
  static const String editField = '/edit_field';
  static const String shareProfile = '/share_profile';
  static const String menu = '/menu';
  static const String growthAnalytics = '/growth-analytics';
  static const String videoInsights = '/video-insights';
  static const String creatorIntelligence = '/creator-intelligence';
  static const String weeklyReport = '/weekly-report';
  static const String studioTeamControl = '/studio-team-control';
  static const String approvalReview = '/approval-review';

  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case root:
      case home:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const AppStartupWrapper(initialTabIndex: 0),
        );
      case network:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const AppStartupWrapper(initialTabIndex: 1),
        );
      case auth:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const AppStartupWrapper(initialTabIndex: 0),
        );
      case camera:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const TikTokCameraView(),
          fullscreenDialog: true,
        );
      case inbox:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const InboxViewOptimized(),
          fullscreenDialog: true,
        );
      case settings:
        final args = routeSettings.arguments;
        if (args is SettingsRouteArgs) {
          return _buildRoute(
            settings: routeSettings,
            builder: (_) => SettingsView(
              initialSearchQuery: args.initialSearchQuery,
            ),
          );
        }
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const SettingsView(),
        );
      case managePosts:
        final args = routeSettings.arguments;
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => ManagePostsView(
            initialTab: args is ManagePostsRouteArgs
                ? args.initialTab
                : ManagePostsInitialTab.scheduled,
            launchSource: args is ManagePostsRouteArgs
                ? args.launchSource
                : ManagePostsLaunchSource.direct,
          ),
        );
      case contentPlanner:
        final args = routeSettings.arguments;
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => ContentPlannerView(
            initialScope: args is ContentPlannerRouteArgs
                ? args.initialScope
                : ContentPlannerInitialScope.today,
          ),
          fullscreenDialog: true,
        );
      case contentScheduler:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const ContentSchedulerView(),
          fullscreenDialog: true,
        );
      case upgrade:
        final Object? upgradeArgs = routeSettings.arguments;
        final bool autoStartPro = upgradeArgs is UpgradeRouteArgs &&
            upgradeArgs.autoStartPro;
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => UpgradeView(autoStartPro: autoStartPro),
        );
      case linkedPlatforms:
        final args = routeSettings.arguments;
        if (args is LinkedPlatformsRouteArgs) {
          return _buildRoute(
            settings: routeSettings,
            builder: (_) => LinkedPlatformsView(
              initialPlatforms: args.initialPlatforms,
            ),
            fullscreenDialog: args.fullscreenDialog,
          );
        }
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const LinkedPlatformsView(),
        );
      case discover:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const DiscoverView(),
        );
      case academy:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const AcademyHomeView(),
        );
      case academySearch:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const AcademySearchView(),
        );
      case academySaved:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const AcademySavedView(),
        );
      case academyProgress:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const AcademyProgressView(),
        );
      case academyCategory:
        final Object? categoryArgs = routeSettings.arguments;
        if (categoryArgs is AcademyCategoryRouteArgs) {
          return _buildRoute(
            settings: routeSettings,
            builder: (_) => AcademyCategoryView(
              categoryId: categoryArgs.categoryId,
            ),
          );
        }
        break;
      case academyPath:
        final Object? pathArgs = routeSettings.arguments;
        if (pathArgs is AcademyPathRouteArgs) {
          return _buildRoute(
            settings: routeSettings,
            builder: (_) => AcademyPathView(pathId: pathArgs.pathId),
          );
        }
        break;
      case academyGuide:
        final Object? guideArgs = routeSettings.arguments;
        if (guideArgs is AcademyGuideRouteArgs) {
          return _buildRoute(
            settings: routeSettings,
            builder: (_) => AcademyGuideView(guideId: guideArgs.guideId),
          );
        }
        break;
      case academyLesson:
        final Object? lessonArgs = routeSettings.arguments;
        if (lessonArgs is AcademyLessonRouteArgs) {
          return _buildRoute(
            settings: routeSettings,
            builder: (_) => AcademyLessonView(
              lessonId: lessonArgs.lessonId,
              guideId: lessonArgs.guideId,
            ),
          );
        }
        break;
      case activity:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const ActivityView(),
        );
      case search:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const SearchScreen(),
        );
      case player:
        final args = routeSettings.arguments;
        if (args is PlayerRouteArgs) {
          return _buildRoute(
            settings: routeSettings,
            builder: (_) => PlayerScreen(
              mode: args.mode,
              initialIndex: args.initialIndex,
              videoIds: args.videoIds,
              videos: args.videos,
              focusCommentId: args.focusCommentId,
            ),
            fullscreenDialog: args.fullscreenDialog,
          );
        }
        break;
      case profile:
        final args = routeSettings.arguments;
        if (args is ProfileRouteArgs) {
          return _buildRoute(
            settings: routeSettings,
            builder: (_) => ProfileViewOptimized(
              user: args.user,
              isCurrentUser: args.isCurrentUser,
            ),
            fullscreenDialog: args.fullscreenDialog,
          );
        }
        break;
      case chat:
        final args = routeSettings.arguments;
        if (args is ChatRouteArgs) {
          return _buildRoute(
            settings: routeSettings,
            builder: (_) => ChatViewOptimized(
              chat: args.chat,
              otherUserId: args.otherUserId,
              otherUserName: args.otherUserName,
              otherUserAvatarURL: args.otherUserAvatarUrl,
              otherUserIsOnline: args.otherUserIsOnline,
              draftToSend: args.draftToSend,
            ),
            fullscreenDialog: args.fullscreenDialog,
          );
        }
        break;
      case videoUnavailable:
        final args = routeSettings.arguments;
        if (args is VideoUnavailableRouteArgs) {
          return _buildRoute(
            settings: routeSettings,
            builder: (_) => VideoUnavailablePage(
              videoId: args.videoId,
              creatorId: args.creatorId,
              creatorName: args.creatorName,
              creatorUsername: args.creatorUsername,
            ),
          );
        }
        break;
      case tippyChat:
        final TippyLaunchContext launchContext =
            routeSettings.arguments is TippyLaunchContext
                ? routeSettings.arguments! as TippyLaunchContext
                : const TippyLaunchContext();
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => TippyChatPage(launchContext: launchContext),
          fullscreenDialog: true,
        );
      case onboarding:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const TippyOnboardingView(),
          fullscreenDialog: true,
        );
      case growthAnalytics:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const GrowthAnalyticsView(),
        );
      case videoInsights:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const CreatorVideoInsightsView(),
        );
      case creatorIntelligence:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const CreatorIntelligenceView(),
        );
      case weeklyReport:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const WeeklyReportView(),
        );
      case studioTeamControl:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const StudioTeamControlView(),
        );
      case approvalReview:
        final Object? args = routeSettings.arguments;
        final ApprovalReviewArgs? reviewArgs =
            args is ApprovalReviewArgs ? args : null;
        if (reviewArgs == null ||
            reviewArgs.requestId.isEmpty ||
            reviewArgs.workspaceId.isEmpty) {
          return _buildRoute(
            settings: routeSettings,
            builder: (_) => const StudioTeamControlView(),
          );
        }
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => ApprovalReviewView(
            requestId: reviewArgs.requestId,
            workspaceId: reviewArgs.workspaceId,
          ),
        );
    }

    return _buildRoute(
      settings: routeSettings,
      builder: (_) => const AppStartupWrapper(initialTabIndex: 0),
    );
  }

  static MaterialPageRoute<dynamic> _buildRoute({
    required RouteSettings settings,
    required WidgetBuilder builder,
    bool fullscreenDialog = false,
  }) {
    return MaterialPageRoute<dynamic>(
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
    );
  }
}

class PlayerRouteArgs {
  const PlayerRouteArgs({
    required this.mode,
    required this.initialIndex,
    required this.videoIds,
    this.videos,
    this.focusCommentId,
    this.fullscreenDialog = true,
  });

  final PlayerMode mode;
  final int initialIndex;
  final List<String> videoIds;
  final List<HomeVideo>? videos;
  final String? focusCommentId;
  final bool fullscreenDialog;
}

class VideoUnavailableRouteArgs {
  const VideoUnavailableRouteArgs({
    required this.videoId,
    this.creatorId,
    this.creatorName,
    this.creatorUsername,
  });

  final String videoId;
  final String? creatorId;
  final String? creatorName;
  final String? creatorUsername;
}

class ProfileRouteArgs {
  const ProfileRouteArgs({
    required this.user,
    this.isCurrentUser = false,
    this.fullscreenDialog = true,
  });

  final User user;
  final bool isCurrentUser;
  final bool fullscreenDialog;
}

class ChatRouteArgs {
  const ChatRouteArgs({
    required this.chat,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatarUrl,
    this.otherUserIsOnline = false,
    this.draftToSend,
    this.fullscreenDialog = true,
  });

  final Chat chat;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatarUrl;
  final bool otherUserIsOnline;
  final Map<String, dynamic>? draftToSend;
  final bool fullscreenDialog;
}

enum ManagePostsInitialTab { scheduled, publishing, published }

enum ManagePostsLaunchSource { direct, commandCenter, tippy }

class ManagePostsRouteArgs {
  const ManagePostsRouteArgs({
    required this.initialTab,
    required this.launchSource,
  });

  final ManagePostsInitialTab initialTab;
  final ManagePostsLaunchSource launchSource;
}

class ContentPlannerRouteArgs {
  const ContentPlannerRouteArgs({
    this.initialScope = ContentPlannerInitialScope.today,
  });

  final ContentPlannerInitialScope initialScope;
}

class SettingsRouteArgs {
  const SettingsRouteArgs({
    this.initialSearchQuery,
  });

  final String? initialSearchQuery;
}

class LinkedPlatformsRouteArgs {
  const LinkedPlatformsRouteArgs({
    this.initialPlatforms = const [],
    this.fullscreenDialog = false,
  });

  final List<String> initialPlatforms;
  final bool fullscreenDialog;
}

class AcademyCategoryRouteArgs {
  const AcademyCategoryRouteArgs({required this.categoryId});

  final String categoryId;
}

class AcademyPathRouteArgs {
  const AcademyPathRouteArgs({required this.pathId});

  final String pathId;
}

class AcademyGuideRouteArgs {
  const AcademyGuideRouteArgs({required this.guideId});

  final String guideId;
}

class AcademyLessonRouteArgs {
  const AcademyLessonRouteArgs({
    required this.lessonId,
    this.guideId,
  });

  final String lessonId;
  final String? guideId;
}
