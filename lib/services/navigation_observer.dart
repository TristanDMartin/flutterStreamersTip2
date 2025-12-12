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
          '   - Popped route: ${route.settings.name} (${route.runtimeType})');
      debugPrint(
          '   - Previous route: ${previousRoute?.settings.name} (${previousRoute?.runtimeType})');
    }

    // 🔥 CRITICAL FIX: Detect return from DiscoverView to HomeView
    final poppedRouteName = route.settings.name ?? route.runtimeType.toString();
    final isPoppingDiscoverView =
        poppedRouteName.toLowerCase().contains('discover');

    if (isPoppingDiscoverView && previousRoute != null) {
      final previousRouteName =
          previousRoute.settings.name ?? previousRoute.runtimeType.toString();
      final isReturningToHome =
          previousRouteName.toLowerCase().contains('home') ||
              previousRouteName == '/' ||
              previousRouteName.isEmpty;

      if (isReturningToHome) {
        debugPrint(
            '🔄 NavigationObserver: Returning to HomeView from DiscoverView - resuming videos');
        // 🔥 CRITICAL: Unblock first (DiscoverView may have blocked playback)
        _manager.unblock();
        // 🎯 SINGLE ACTIVE OWNER: Set home as active owner
        // VideoPlayerViewOptimized's activeOwnerSubscription listener will automatically resume
        _manager.setActiveOwner(PlaybackOwners.home);
        return;
      }
    }

    // ✅ FIX: Let _handleRouteChange determine if we should resume based on route type
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
    String? owner;

    if (route.settings.name != null) {
      owner = route.settings.name;
    } else {
      // Fallback to route class name
      final routeName = route.runtimeType.toString();
      if (routeName.contains('HomeView')) {
        owner = 'home';
      } else if (routeName.contains('Profile')) {
        owner = 'profile';
      } else if (routeName.contains('Recording') ||
          routeName.contains('Camera')) {
        owner = 'recording';
      } else if (routeName.contains('Comments')) {
        owner = 'comments';
      } else if (routeName.contains('Share')) {
        owner = 'share';
      } else {
        owner = routeName.toLowerCase();
      }
    }

    // 🔥 CRITICAL: Enhanced route detection with detailed logging
    final routeName = route.settings.name ?? route.runtimeType.toString();
    debugPrint('[MediaRouteObserver] new route: $routeName');

    // TIKTOK FIX: Don't pause video for CommentsView2 or ShareSheet modals - keep video playing behind
    final shouldKeepVideoPlaying =
        owner?.contains('modalbottomsheetroute') == true ||
            owner?.contains('comments') == true ||
            owner?.contains('share') == true ||
            route.runtimeType.toString().contains('ModalBottomSheetRoute');

    if (shouldKeepVideoPlaying) {
      debugPrint(
          '🎵 NavigationObserver: Modal opened - keeping video playing (owner: $owner, routeType: ${route.runtimeType})');
      // Don't call onRouteChange for these modals - let video keep playing
      return;
    }

    // 🔊 Enhanced route detection
    final routeNameLower = routeName.toLowerCase();
    final isHomeRoute = routeName == '/home' ||
        routeName == 'home' ||
        routeNameLower.contains('homeview') ||
        routeNameLower.contains('hometab') ||
        routeNameLower.contains('maintab') ||
        owner == 'home' ||
        owner == '/';

    final isProfileRoute = routeName == '/profile' ||
        routeName == 'profile' ||
        routeName == 'ProfileView' ||
        routeNameLower.contains('profileview') ||
        owner?.toLowerCase() == 'profile';

    final isPlayerRoute = routeName == '/player' ||
        routeName == 'player' ||
        routeName == 'playerScreen' ||
        routeNameLower.contains('playerview') ||
        routeNameLower.contains('playerscreen') ||
        owner?.toLowerCase().contains('player') == true;

    final isDiscoverRoute = routeNameLower.contains('discoverview') ||
        routeNameLower.contains('discover') ||
        owner?.toLowerCase().contains('discover') == true;

    // 🔥 CRITICAL: Explicitly detect NetworkView to ensure blocking
    final isNetworkView = routeNameLower.contains('networkview') ||
        owner?.toLowerCase().contains('network') == true;

    // 🎯 SINGLE ACTIVE OWNER: Use setActiveOwner for video-playing routes
    if (isPlayerRoute) {
      debugPrint('[MediaRouteObserver] Entering PLAYER – setting active owner');
      _manager.setActiveOwner(PlaybackOwners.player);
      return;
    }

    if (isProfileRoute) {
      debugPrint(
          '[MediaRouteObserver] Entering PROFILE – setting active owner');
      _manager.setActiveOwner(PlaybackOwners.profile);
      return;
    }

    if (isDiscoverRoute) {
      debugPrint(
          '[MediaRouteObserver] Entering DISCOVER – setting active owner');
      _manager.setActiveOwner(PlaybackOwners.discover);
      return;
    }

    if (isHomeRoute) {
      debugPrint('[MediaRouteObserver] Entering HOME – setting active owner');
      _manager.setActiveOwner(PlaybackOwners.home);
      return;
    }

    final shouldBlock = !isHomeRoute && !isDiscoverRoute;

    if (shouldBlock && isForeground) {
      _manager.block(reason: 'route_change_$owner');
      debugPrint(
          '🚫 NavigationObserver: Blocking playback for non-home route: $owner');
      // 🔥 CRITICAL: Explicitly handle NetworkView
      if (isNetworkView) {
        debugPrint(
            '🚫 NavigationObserver: NetworkView detected - ensuring playback is blocked');
        _manager.pauseAll(); // Extra safety: pause all videos
      }
    } else if (!shouldBlock && isForeground) {
      // 🎯 SINGLE ACTIVE OWNER: For video-playing routes, setActiveOwner handles everything
      // For non-video routes, just unblock
      if (isHomeRoute || isDiscoverRoute || isProfileRoute || isPlayerRoute) {
        // setActiveOwner already called above for these routes
        _manager.unblock();
      } else {
        _manager.unblock();
        // Only call resumeAfterTabSwitch for non-video routes that were blocked
        _manager.resumeAfterTabSwitch();
      }
      debugPrint('✅ NavigationObserver: Unblocking playback for route: $owner');
    }

    if (route.settings.name != null) {
      debugPrint(
          '🎵 NavigationObserver: Route changed to ${route.settings.name} (owner: $owner, foreground: $isForeground)');
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
            '🎵 NavigationObserver: Modal presented - keeping video playing (type: $modalType)');
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
