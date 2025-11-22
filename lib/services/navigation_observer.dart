import 'package:flutter/material.dart';
import 'global_playback_manager.dart';

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

    // ✅ FIX: Don't auto-resume video here
    // Let _handleRouteChange determine if we should resume based on route type
    // This prevents audio bleeding when returning to DiscoverView or other non-HomeView routes
    // Only resume when actually returning to HomeView (handled in _handleRouteChange)

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

    // DEBUG: Log all route information
    debugPrint('🔍 NavigationObserver: Route change detected:');
    debugPrint('   - Route type: ${route.runtimeType}');
    debugPrint('   - Route name: ${route.settings.name}');
    debugPrint('   - Determined owner: $owner');

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

    // 🔊 AUDIO FIX: Block playback when leaving home
    // HomeView is not a route itself, it's inside MainTabView
    // Check if we're returning to a route that contains HomeView
    final routeName = route.runtimeType.toString().toLowerCase();
    final isHomeRoute = owner == 'home' || 
                       owner == '/' || 
                       routeName.contains('hometab') ||
                       routeName.contains('maintab');
    
    // 🔥 CRITICAL: Explicitly detect NetworkView to ensure blocking
    final isNetworkView = routeName.contains('networkview') || 
                         owner?.toLowerCase().contains('network') == true;

    if (!isHomeRoute && isForeground) {
      _manager.block(reason: 'route_change_$owner');
      debugPrint(
          '🚫 NavigationObserver: Blocking playback for non-home route: $owner');
      // 🔥 CRITICAL: Explicitly handle NetworkView
      if (isNetworkView) {
        debugPrint('🚫 NavigationObserver: NetworkView detected - ensuring playback is blocked');
        _manager.pauseAll(); // Extra safety: pause all videos
      }
    } else if (isHomeRoute && isForeground) {
      _manager.unblock();
      // 🚀 TIKTOK FIX: Instantly resume video playback when returning to home
      // No delay - resume immediately for TikTok-like experience
      _manager.resumeAfterTabSwitch();
      debugPrint(
          '✅ NavigationObserver: Unblocking and instantly resuming playback for home route: $owner');
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
      _manager.resumeAfterTabSwitch();
      debugPrint('🎵 NavigationObserver: Modal dismissed - $modalType');
    }
  }
}
