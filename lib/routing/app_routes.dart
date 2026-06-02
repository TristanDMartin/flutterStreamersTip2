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
import '../widgets/auth_modal_view.dart';
import '../widgets/chat_view_optimized.dart';
import '../widgets/discover_view.dart';
import '../widgets/inbox_view_optimized.dart';
import '../widgets/player_screen.dart';
import '../pages/video_unavailable_page.dart';
import '../widgets/profile_view_optimized.dart';
import '../widgets/tiktok_camera_view.dart';
import '../features/content_planning/content_planner_view.dart';
import '../features/content_scheduler/content_scheduler_view.dart';
import '../features/tippy/tippy_chat_page.dart';

class AppRoutes {
  static const String root = '/';
  static const String auth = '/auth';
  static const String home = '/home';
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
  static const String activity = '/activity';
  static const String search = '/search';
  static const String player = '/player';
  static const String profile = '/profile';
  static const String chat = '/chat';
  static const String tippyChat = '/tippy';
  static const String videoUnavailable = '/video-unavailable';

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
          builder: (_) => const AuthModalView(),
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
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const ContentPlannerView(),
          fullscreenDialog: true,
        );
      case contentScheduler:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const ContentSchedulerView(),
          fullscreenDialog: true,
        );
      case upgrade:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const UpgradeView(),
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
            builder: (_) => VideoUnavailablePage(videoId: args.videoId),
          );
        }
        break;
      case tippyChat:
        return _buildRoute(
          settings: routeSettings,
          builder: (_) => const TippyChatPage(),
          fullscreenDialog: true,
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
    this.fullscreenDialog = true,
  });

  final PlayerMode mode;
  final int initialIndex;
  final List<String> videoIds;
  final List<HomeVideo>? videos;
  final bool fullscreenDialog;
}

class VideoUnavailableRouteArgs {
  const VideoUnavailableRouteArgs({required this.videoId});

  final String videoId;
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
