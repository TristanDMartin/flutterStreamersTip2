import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/home_video.dart';
import '../models/user.dart';
import '../widgets/streamer_card_view.dart';
import '../widgets/player_screen.dart';
import 'app_routes.dart';

class AppNavigator {
  static Future<T?> openPlayer<T>(
    BuildContext context, {
    required PlayerMode mode,
    required int initialIndex,
    required List<String> videoIds,
    List<HomeVideo>? videos,
    bool fullscreenDialog = true,
  }) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.player,
      arguments: PlayerRouteArgs(
        mode: mode,
        initialIndex: initialIndex,
        videoIds: videoIds,
        videos: videos,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  static Future<T?> openProfile<T>(
    BuildContext context, {
    required User user,
    bool isCurrentUser = false,
    bool fullscreenDialog = true,
  }) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.profile,
      arguments: ProfileRouteArgs(
        user: user,
        isCurrentUser: isCurrentUser,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  static Future<T?> openChat<T>(
    BuildContext context, {
    required Chat chat,
    required String otherUserId,
    required String otherUserName,
    String? otherUserAvatarUrl,
    bool otherUserIsOnline = false,
    Map<String, dynamic>? draftToSend,
    bool fullscreenDialog = true,
  }) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.chat,
      arguments: ChatRouteArgs(
        chat: chat,
        otherUserId: otherUserId,
        otherUserName: otherUserName,
        otherUserAvatarUrl: otherUserAvatarUrl,
        otherUserIsOnline: otherUserIsOnline,
        draftToSend: draftToSend,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  static Future<T?> openDiscover<T>(BuildContext context) {
    return Navigator.of(context).pushNamed<T>(AppRoutes.discover);
  }

  static Future<T?> openActivity<T>(BuildContext context) {
    return Navigator.of(context).pushNamed<T>(AppRoutes.activity);
  }

  static Future<T?> openSearch<T>(BuildContext context) {
    return Navigator.of(context).pushNamed<T>(AppRoutes.search);
  }

  static Future<T?> openSettings<T>(
    BuildContext context, {
    String? initialSearchQuery,
  }) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.settings,
      arguments: SettingsRouteArgs(
        initialSearchQuery: initialSearchQuery,
      ),
    );
  }

  static Future<T?> openManagePosts<T>(BuildContext context) {
    return openManagePostsWithArgs(
      context,
      initialTab: ManagePostsInitialTab.scheduled,
      launchSource: ManagePostsLaunchSource.direct,
    );
  }

  static Future<T?> openManagePostsWithArgs<T>(
    BuildContext context, {
    required ManagePostsInitialTab initialTab,
    required ManagePostsLaunchSource launchSource,
  }) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.managePosts,
      arguments: ManagePostsRouteArgs(
        initialTab: initialTab,
        launchSource: launchSource,
      ),
    );
  }

  static Future<T?> openLinkedPlatforms<T>(
    BuildContext context, {
    List<String> initialPlatforms = const [],
    bool fullscreenDialog = false,
  }) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.linkedPlatforms,
      arguments: LinkedPlatformsRouteArgs(
        initialPlatforms: initialPlatforms,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  static Future<T?> openStreamerCard<T>(
    BuildContext context, {
    required String userId,
    String? currentUserId,
    VoidCallback? onDismiss,
    Function(String userId)? onFollow,
    Function(String userId)? onMessage,
    Function(String userId)? onShare,
    Function(String tabName)? onNavigateToTab,
    bool fullscreenDialog = true,
  }) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(
        settings: const RouteSettings(name: '/streamer_card'),
        fullscreenDialog: fullscreenDialog,
        builder: (_) => StreamerCardView(
          userId: userId,
          currentUserId: currentUserId,
          onDismiss: onDismiss,
          onFollow: onFollow,
          onMessage: onMessage,
          onShare: onShare,
          onNavigateToTab: onNavigateToTab,
        ),
      ),
    );
  }

  static Future<T?> replaceWithHome<T>(BuildContext context) {
    return Navigator.of(context)
        .pushNamedAndRemoveUntil<T>(AppRoutes.home, (route) => false);
  }

  static Future<T?> replaceWithAuth<T>(BuildContext context) {
    return Navigator.of(context)
        .pushNamedAndRemoveUntil<T>(AppRoutes.auth, (route) => false);
  }
}
