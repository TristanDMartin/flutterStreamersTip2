import 'package:flutter/material.dart';

import 'global_playback_manager.dart';
import '../constants/playback_owners.dart';
import '../utils/playback_route_policies.dart';

/// Navigation observer that handles route changes and coordinates with playback.
class AppNavigationObserver extends RouteObserver<PageRoute<dynamic>> {
  AppNavigationObserver._();

  static final AppNavigationObserver instance = AppNavigationObserver._();

  final GlobalPlaybackManager _manager = GlobalPlaybackManager.instance;
  final List<Route<dynamic>> _blockingRoutes = <Route<dynamic>>[];

  @visibleForTesting
  void clearRoutePlaybackSuppressions() {
    final List<Route<dynamic>> routes =
        List<Route<dynamic>>.from(_blockingRoutes);
    for (final Route<dynamic> route in routes) {
      _releaseRouteBlock(route);
    }
    _blockingRoutes.clear();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (_shouldBlockRoute(route)) {
      _handleRoutePush(route);
      return;
    }
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

    _handleRoutePop(route);

    final String poppedRouteName =
        route.settings.name ?? route.runtimeType.toString();
    final bool isPoppingDiscoverView =
        poppedRouteName.toLowerCase().contains('discover');

    if (isPoppingDiscoverView && previousRoute != null) {
      final String previousRouteName =
          previousRoute.settings.name ?? previousRoute.runtimeType.toString();
      final bool isReturningToHome =
          previousRouteName.toLowerCase().contains('home');

      if (isReturningToHome && !_manager.isSuppressedForSignOut) {
        debugPrint(
          '🔄 NavigationObserver: Returning to HomeView from DiscoverView',
        );
        _activateVideoSurface(PlaybackOwners.home);
        return;
      }
    }

    if (previousRoute != null && !_shouldBlockRoute(previousRoute)) {
      final String previousName =
          (previousRoute.settings.name ?? previousRoute.runtimeType.toString())
              .toLowerCase();
      // Share/comments sheets used to suppress via route_change_unknown without
      // entering _blockingRoutes, so unblock() on pop never ran. Clear orphaned
      // overlay blocks when returning to the shell feed.
      if (PlaybackRoutePolicies.isShellRoute(previousName) &&
          _manager.isPlaybackBlocked) {
        final String? reason = _manager.blockReason;
        if (reason == 'route_change_unknown' ||
            reason == 'route_change_overlay' ||
            (reason != null && reason.startsWith('route_overlay_'))) {
          debugPrint(
            '🔓 NavigationObserver: Clearing orphaned overlay block ($reason)',
          );
          _manager.forceUnblock();
          final String? owner = _manager.visibleOwner ?? _manager.activeOwner;
          if (owner == PlaybackOwners.home || owner == PlaybackOwners.discover) {
            _manager.resumeAfterTabSwitch();
          }
        }
      }
      _handleRouteChange(previousRoute, isForeground: true);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _handleRoutePop(route);
    _handleRouteChange(previousRoute, isForeground: true);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute != null) {
      _handleRoutePop(oldRoute);
    }
    if (newRoute != null) {
      _handleRoutePush(newRoute);
    }
    _handleRouteChange(newRoute, isForeground: true);
  }

  String _routeBlockReason(Route<dynamic> route) {
    final String? name = route.settings.name;
    if (name != null && name.isNotEmpty) {
      return 'route_$name';
    }
    return 'route_overlay_${route.hashCode}';
  }

  bool _shouldBlockRoute(Route<dynamic> route) {
    if (route is! PageRoute && route is! MaterialPageRoute) {
      return false;
    }
    final String? name = route.settings.name;
    final String routeName = (name ?? route.runtimeType.toString()).toLowerCase();

    if (PlaybackRoutePolicies.isShellRoute(routeName)) {
      return false;
    }
    if (PlaybackRoutePolicies.isOnboardingRoute(routeName)) {
      return false;
    }
    if (PlaybackRoutePolicies.isVideoPlaybackRoute(routeName)) {
      return false;
    }
    if (PlaybackRoutePolicies.isCommentsOrShareModalRoute(routeName)) {
      return false;
    }
    if (PlaybackRoutePolicies.isKeepPlayingOverlayRoute(routeName)) {
      return false;
    }
    if (PlaybackRoutePolicies.isNonVideoScreenRoute(routeName)) {
      return true;
    }
    if (route is MaterialPageRoute && name == null) {
      return true;
    }
    return false;
  }

  void _handleRoutePush(Route<dynamic> route) {
    if (!_shouldBlockRoute(route)) {
      return;
    }
    if (_blockingRoutes.contains(route)) {
      return;
    }
    _blockingRoutes.add(route);
    _manager.block(reason: _routeBlockReason(route));
  }

  void _handleRoutePop(Route<dynamic> route) {
    _releaseRouteBlock(route);
  }

  void _releaseRouteBlock(Route<dynamic> route) {
    if (!_blockingRoutes.remove(route)) {
      return;
    }
    _manager.unblock(reason: _routeBlockReason(route));
  }

  void _activateVideoSurface(String owner) {
    _manager.unblock();
    _manager.setVisibleOwner(owner);
  }

  void _suppressPlayback({required String reason, String? visibleOwner}) {
    _manager.block(reason: reason);
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

    if (_manager.isSuppressedForSignOut) {
      debugPrint(
        '🚫 NavigationObserver: Sign-out suppression active — skip restore',
      );
      return;
    }

    if (PlaybackRoutePolicies.isShellRoute(routeName)) {
      debugPrint(
        '🎛️ NavigationObserver: Shell route — tab owns playback',
      );
      return;
    }

    if (PlaybackRoutePolicies.isOnboardingRoute(routeName)) {
      debugPrint(
        '🎓 NavigationObserver: Onboarding route — gate owns playback',
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

    if (PlaybackRoutePolicies.isKeepPlayingOverlayRoute(routeName)) {
      debugPrint(
        '🎵 NavigationObserver: Keep-playing overlay — no block',
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
    final String reason = 'modal_${modalType ?? 'unknown'}';
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
      _manager.block(reason: reason);
      debugPrint('🎵 NavigationObserver: Modal presented — $modalType');
      return;
    }

    _manager.unblock(reason: reason);

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
