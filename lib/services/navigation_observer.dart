import 'package:flutter/material.dart';
import 'global_playback_manager.dart';
import '../constants/playback_owners.dart';

/// Navigation observer that handles route changes and coordinates with playback
class AppNavigationObserver extends RouteObserver<PageRoute<dynamic>> {
  final GlobalPlaybackManager _manager = GlobalPlaybackManager.instance;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _handleRouteChange(route, isForeground: true);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);

    debugPrint('🔍 NavigationObserver: didPop');
    if (route.settings.name != null || previousRoute?.settings.name != null) {
      debugPrint(
        '   - Popped route: ${route.settings.name} (${route.runtimeType})',
      );
      debugPrint(
        '   - Previous route: ${previousRoute?.settings.name} (${previousRoute?.runtimeType})',
      );
    }

    final poppedRouteName = route.settings.name ?? route.runtimeType.toString();
    final isPoppingDiscoverView = poppedRouteName.toLowerCase().contains(
          'discover',
        );

    if (isPoppingDiscoverView && previousRoute != null) {
      final previousRouteName =
          previousRoute.settings.name ?? previousRoute.runtimeType.toString();
      final isReturningToHome = previousRouteName.toLowerCase().contains(
            'home',
          );

      if (isReturningToHome) {
        debugPrint(
          '🔄 NavigationObserver: Returning to HomeView from DiscoverView - resuming videos',
        );
        _manager.unblock();
        _manager.setActiveOwner(PlaybackOwners.home);
        return;
      }
    }

    _handleRouteChange(previousRoute, isForeground: true);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _handleRouteChange(previousRoute, isForeground: true);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _handleRouteChange(newRoute, isForeground: true);
  }

  void _handleRouteChange(Route<dynamic>? route, {required bool isForeground}) {
    if (route == null) return;

    // Determine the owner based on route name or settings
    final name = route.settings.name;
    final typeName = route.runtimeType.toString().toLowerCase();
    final routeName = (name ?? typeName).toLowerCase();

    debugPrint(
      '[MediaRouteObserver] new route: ${route.settings.name ?? typeName}',
    );

    final isShellRoute = routeName == '/' || routeName.isEmpty;
    final isHomeRoute = routeName == '/home' ||
        routeName.contains('homeview') ||
        routeName == 'home';
    final isDiscoverRoute = routeName == '/discover' ||
        routeName.contains('discoverview') ||
        routeName.contains('discover');
    final isProfileRoute = routeName == '/profile' ||
        routeName.contains('profileview') ||
        routeName.contains('profile');
    final isPlayerRoute = routeName == '/player' ||
        routeName.contains('playerscreen') ||
        routeName.contains('playerview');

    final isCommentsModal =
        routeName.contains('commentsview2') || routeName == '/comments';
    final isShareSheetModal =
        routeName.contains('enhancedsharesheet') || routeName == '/share_sheet';
    final isStreamerCardRoute = routeName.contains('streamer_card');
    final isNetworkRoute =
        routeName == '/network' || routeName.contains('networkview');
    final isUpgradeRoute =
        routeName == '/upgrade' || routeName.contains('upgrade');
    final isCameraRoute = routeName.contains('camera') ||
        routeName.contains('recording') ||
        routeName.contains('preview') ||
        routeName.contains('publish') ||
        routeName.contains('upload');
    final isInboxRoute = routeName.contains('inbox') ||
        routeName.contains('chat') ||
        routeName.contains('message');
    final isSupportedPlaybackModal =
        (route is PopupRoute || route is ModalRoute) &&
            (isCommentsModal || isShareSheetModal);

    if (isShellRoute) {
      debugPrint(
        '🎛️ NavigationObserver: App shell route - playback owned by current tab',
      );
      return;
    }

    // If this is a known lightweight modal over the current view, keep playing
    if (isSupportedPlaybackModal) {
      debugPrint(
        '🎵 NavigationObserver: Modal presented - keeping video playing (route: $routeName)',
      );
      return;
    }

    if (isHomeRoute) {
      _manager.unblock();
      _manager.setActiveOwner(PlaybackOwners.home);
      return;
    }

    if (isDiscoverRoute) {
      _manager.unblock();
      _manager.setActiveOwner(PlaybackOwners.discover);
      return;
    }

    if (isProfileRoute) {
      _manager.unblock();
      _manager.setActiveOwner(PlaybackOwners.profile);
      return;
    }

    if (isPlayerRoute) {
      _manager.unblock();
      _manager.setActiveOwner(PlaybackOwners.player);
      return;
    }

    // Non-playing routes: block + pause
    if (isNetworkRoute || isUpgradeRoute) {
      _manager.setActiveOwner(PlaybackOwners.network);
      _manager.pauseAll();
      debugPrint(
        '🚫 NavigationObserver: Set non-playing owner for route: $routeName',
      );
      return;
    }

    if (isStreamerCardRoute || isCameraRoute || isInboxRoute) {
      _manager.block(
        reason: isStreamerCardRoute
            ? 'route_change_streamer'
            : isCameraRoute
                ? 'route_change_camera'
                : 'route_change_inbox',
      );
      _manager.pauseAll();
      debugPrint(
        '🚫 NavigationObserver: Blocking playback for route: $routeName',
      );
      return;
    }

    // Unnamed MaterialPageRoute (e.g. video detail from Discover) → treat as
    // a player context; the widget itself manages block/unblock via initState.
    if (route is MaterialPageRoute && name == null) {
      _manager.unblock();
      _manager.setActiveOwner(PlaybackOwners.player);
      debugPrint(
        '🎬 NavigationObserver: Unnamed MaterialPageRoute - allowing playback',
      );
      return;
    }

    // Fallback: truly unknown route → block + pause
    if (isForeground) {
      _manager.block(reason: 'route_change_unknown');
      _manager.pauseAll();
      debugPrint(
        '🚫 NavigationObserver: Unknown route - blocking playback ($routeName)',
      );
    }
  }

  /// Handle modal presentations (bottom sheets, dialogs, etc.)
  void handleModalPresentation({required bool isPresented, String? modalType}) {
    if (isPresented) {
      // TIKTOK FIX: Don't pause videos for CommentsView2 or ShareSheet - keep playing behind modal
      if (modalType?.contains('comments') == true ||
          modalType?.contains('Comments') == true ||
          modalType?.contains('share') == true ||
          modalType?.contains('Share') == true) {
        debugPrint(
          '🎵 NavigationObserver: Modal presented - keeping video playing (type: $modalType)',
        );
        return;
      }

      // 🔊 AUDIO FIX: Pause all videos when modal is presented
      _manager.pauseAll();
      debugPrint('🎵 NavigationObserver: Modal presented - $modalType');
    } else {
      // 🔊 AUDIO FIX: Resume playback when modal is dismissed
      // 🎯 SINGLE ACTIVE OWNER: Check if there's an active owner before resuming
      if (_manager.activeOwner != null) {
        _manager.resumeAfterTabSwitch();
      }
      debugPrint('🎵 NavigationObserver: Modal dismissed - $modalType');
    }
  }
}
