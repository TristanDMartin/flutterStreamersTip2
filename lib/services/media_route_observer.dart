import 'package:flutter/material.dart';
import 'global_playback_manager.dart';

class MediaRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  final GlobalPlaybackManager _playback = GlobalPlaybackManager.instance;

  void _handleRouteChange(PageRoute<dynamic>? newRoute) {
    final name = newRoute?.settings.name ?? 'UNKNOWN';
    debugPrint('[MediaRouteObserver] new route: $name');

    final isHomeRoute =
        name == '/home' || name == 'home' || name.contains('HomeView');

    final isProfileRoute =
        name == '/profile' || name == 'profile' || name.contains('ProfileView');

    final isPlayerRoute = name == '/player' ||
        name == 'player' ||
        name.contains('PlayerView') ||
        name.contains('playerScreen'); // Matches user's previous fix naming

    if (isProfileRoute || isPlayerRoute) {
      debugPrint(
          '[MediaRouteObserver] Entering PROFILE/PLAYER – cleaning Home');

      // 1) stop every controller
      _playback.pauseAll();

      // 2) dispose all Home-owned controllers
      _playback.disposeControllersForOwner('home/forYou');
      _playback.disposeControllersForOwner('home/following');
      _playback.disposeControllersForOwner('home/feed');

      // 3) now allow profile/player audio to take over
      _playback.unblock();
      _playback.resumeAfterTabSwitch();
    } else if (isHomeRoute) {
      debugPrint(
          '[MediaRouteObserver] Entering HOME – cleaning Profile/Player');

      _playback.pauseAll();
      _playback.disposeControllersForOwner('profile/main');
      _playback.disposeControllersForOwner('profile/player');

      // likely re-block until Home user taps to unmute
      _playback.block();
    }
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) _handleRouteChange(route);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute is PageRoute) _handleRouteChange(previousRoute);
  }
}
