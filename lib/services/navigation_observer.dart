import 'package:flutter/material.dart';
import '../services/global_playback_coordinator.dart';

/// Navigation observer that handles route changes and coordinates with playback
class AppNavigationObserver extends RouteObserver<PageRoute<dynamic>> {
  final GlobalPlaybackCoordinator _coordinator = GlobalPlaybackCoordinator();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _handleRouteChange(route, isForeground: true);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
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

    // Notify coordinator about route change
    _coordinator.onRouteChange(owner, isForeground);

    if (route.settings.name != null) {
      debugPrint(
          '🎵 NavigationObserver: Route changed to ${route.settings.name} (owner: $owner, foreground: $isForeground)');
    }
  }

  /// Handle modal presentations (bottom sheets, dialogs, etc.)
  void handleModalPresentation({required bool isPresented, String? modalType}) {
    if (isPresented) {
      // Pause all videos when modal is presented
      _coordinator.pauseAll(reason: 'modalPresented: $modalType');
      debugPrint('🎵 NavigationObserver: Modal presented - $modalType');
    } else {
      // Resume playback when modal is dismissed
      _coordinator.resumePlayback();
      debugPrint('🎵 NavigationObserver: Modal dismissed - $modalType');
    }
  }
}
