import '../routing/app_routes.dart';

/// Classifies routes for global playback (home feed audio must not bleed).
abstract final class PlaybackRoutePolicies {
  static bool isShellRoute(String routeName) {
    return routeName == '/' || routeName.isEmpty;
  }

  static bool isVideoPlaybackRoute(String routeName) {
    return routeName == AppRoutes.home ||
        routeName.contains('homeview') ||
        routeName == AppRoutes.discover ||
        routeName.contains('discoverview') ||
        routeName == AppRoutes.player ||
        routeName.contains('playerscreen') ||
        routeName.contains('playerview');
  }

  static bool isCommentsOrShareModalRoute(String routeName) {
    return routeName.contains('commentsview2') ||
        routeName == '/comments' ||
        routeName.contains('enhancedsharesheet') ||
        routeName == '/share_sheet';
  }

  static bool isNonVideoScreenRoute(String routeName) {
    if (isShellRoute(routeName) || isVideoPlaybackRoute(routeName)) {
      return false;
    }
    if (isCommentsOrShareModalRoute(routeName)) {
      return false;
    }
    return routeName == AppRoutes.profile ||
        routeName == AppRoutes.editProfile ||
        routeName == AppRoutes.editLinks ||
        routeName == AppRoutes.editField ||
        routeName == AppRoutes.settings ||
        routeName == AppRoutes.shareProfile ||
        routeName == AppRoutes.menu ||
        routeName == '/admin_control' ||
        routeName == AppRoutes.activity ||
        routeName == AppRoutes.search ||
        routeName == AppRoutes.network ||
        routeName == AppRoutes.upgrade ||
        routeName == AppRoutes.inbox ||
        routeName == AppRoutes.chat ||
        routeName == AppRoutes.linkedPlatforms ||
        routeName == AppRoutes.managePosts ||
        routeName == AppRoutes.contentPlanner ||
        routeName == AppRoutes.contentScheduler ||
        routeName == AppRoutes.camera ||
        routeName.contains('editprofile') ||
        routeName.contains('edit_profile') ||
        routeName.contains('linksedit') ||
        routeName.contains('edit_links') ||
        routeName.contains('editfield') ||
        routeName.contains('settingsview') ||
        routeName.contains('shareprofile') ||
        routeName.contains('menuview') ||
        routeName.contains('activityview') ||
        routeName.contains('searchscreen') ||
        routeName.contains('manageaccount') ||
        routeName.contains('admincontrol') ||
        routeName.contains('insightsview') ||
        routeName.contains('streamer_card') ||
        routeName.contains('inboxview') ||
        routeName.contains('chatview') ||
        routeName.contains('linkedplatforms') ||
        routeName.contains('manageposts') ||
        routeName.contains('contentplanner') ||
        routeName.contains('contentscheduler') ||
        routeName.contains('tiktokcamera') ||
        routeName.contains('recording') ||
        routeName.contains('publish') ||
        routeName.contains('upload');
  }
}
