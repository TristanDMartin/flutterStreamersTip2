import 'package:flutter/material.dart';
import 'global_playback_manager.dart';
import '../constants/playback_owners.dart';
import '../utils/playback_route_policies.dart';

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

    final String poppedRouteName =
        route.settings.name ?? route.runtimeType.toString();
    final bool isPoppingDiscoverView =
        poppedRouteName.toLowerCase().contains('discover');

    if (isPoppingDiscoverView && previousRoute != null) {
      final String previousRouteName =
          previousRoute.settings.name ?? previousRoute.runtimeType.toString();
      final bool isReturningToHome =
          previousRouteName.toLowerCase().contains('home');

      if (isReturningToHome) {
        debugPrint(
          '🔄 NavigationObserver: Returning to HomeView from DiscoverView',
        );
        _activateVideoSurface(PlaybackOwners.home);
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

  void _activateVideoSurface(String owner) {
    _manager.unblock();
    _manager.setActiveOwner(owner);
  }

  void _suppressPlayback({required String reason, String? visibleOwner}) {
    _manager.block(reason: reason);
    _manager.pauseAll();
    if (visibleOwner != null) {
      _manager.setVisibleOwner(visibleOwner);
    }
    debugPrint('🚫 NavigationObserver: Suppressed playback ($reason)');
  }

  void _handleRouteChange(Route<dynamic>? route, {required bool isForeground}) {
    if (route == null) {
      return;
    }

    final String? name = route.settings.name;
    final String typeName = route.runtimeType.toString().toLowerCase();
    final String routeName = (name ?? typeName).toLowerCase();

    debugPrint(
      '[NavigationObserver] route: ${route.settings.name ?? typeName}',
    );

    if (PlaybackRoutePolicies.isShellRoute(routeName)) {
      debugPrint(
        '🎛️ NavigationObserver: Shell route — tab owns playback',
      );
      return;
    }

    final bool isSupportedPlaybackModal =
        (route is PopupRoute || route is ModalRoute) &&
            PlaybackRoutePolicies.isCommentsOrShareModalRoute(routeName);

    if (isSupportedPlaybackModal) {
      debugPrint(
        '🎵 NavigationObserver: Comments/share modal — keep playing',
      );
      return;
    }

    if (PlaybackRoutePolicies.isVideoPlaybackRoute(routeName)) {
      final String owner = routeName.contains('discover')
          ? PlaybackOwners.discover
          : routeName.contains('player')
              ? PlaybackOwners.player
              : PlaybackOwners.home;
      _activateVideoSurface(owner);
      return;
    }

    if (routeName == '/profile' || routeName.contains('profileview')) {
      _suppressPlayback(
        reason: 'route_change_profile',
        visibleOwner: PlaybackOwners.profile,
      );
      return;
    }

    if (PlaybackRoutePolicies.isNonVideoScreenRoute(routeName)) {
      _suppressPlayback(reason: 'route_change_non_video');
      return;
    }

    if (route is MaterialPageRoute && name == null) {
      _suppressPlayback(reason: 'route_change_overlay');
      return;
    }

    if (isForeground) {
      _suppressPlayback(reason: 'route_change_unknown');
    }
  }

  /// Handle modal presentations (bottom sheets, dialogs, etc.)
  void handleModalPresentation({
    required bool isPresented,
    String? modalType,
  }) {
    if (isPresented) {
      if (modalType?.contains('comments') == true ||
          modalType?.contains('Comments') == true ||
          modalType?.contains('share') == true ||
          modalType?.contains('Share') == true) {
        debugPrint(
          '🎵 NavigationObserver: Modal presented — keep playing ($modalType)',
        );
        return;
      }
      _manager.block(reason: 'modal_${modalType ?? 'unknown'}');
      _manager.pauseAll();
      debugPrint('🎵 NavigationObserver: Modal presented — $modalType');
      return;
    }

    if (_manager.isPlaybackBlocked) {
      debugPrint(
        '🎵 NavigationObserver: Modal dismissed — still blocked, no resume',
      );
      return;
    }

    final String? owner = _manager.visibleOwner ?? _manager.activeOwner;
    if (owner == PlaybackOwners.home || owner == PlaybackOwners.discover) {
      _manager.resumeAfterTabSwitch();
    }
    debugPrint('🎵 NavigationObserver: Modal dismissed — $modalType');
  }
}
