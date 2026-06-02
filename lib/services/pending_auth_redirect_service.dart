import 'package:flutter/material.dart';
import '../routing/app_routes.dart';
import 'unified_avatar_service.dart' as nav;

class PendingAuthRedirect {
  const PendingAuthRedirect({
    this.routeName,
    this.arguments,
    this.action,
  });

  final String? routeName;
  final Object? arguments;
  final Future<void> Function(BuildContext context)? action;
}

class PendingAuthRedirectService {
  PendingAuthRedirectService._();

  static final PendingAuthRedirectService instance =
      PendingAuthRedirectService._();

  PendingAuthRedirect? _pendingRedirect;

  bool get hasPendingRedirect => _pendingRedirect != null;

  void setRedirect({
    required String routeName,
    Object? arguments,
  }) {
    _pendingRedirect = PendingAuthRedirect(
      routeName: routeName,
      arguments: arguments,
    );
  }

  void setAction(Future<void> Function(BuildContext context) action) {
    _pendingRedirect = PendingAuthRedirect(action: action);
  }

  void clear() {
    _pendingRedirect = null;
  }

  static bool _isAppRootShellRoute(String? routeName) {
    return routeName == null ||
        routeName == AppRoutes.root ||
        routeName == AppRoutes.home;
  }

  void _closeAuthOverlayRoutes(NavigatorState navigator) {
    if (!navigator.canPop()) {
      return;
    }
    navigator.popUntil((Route<dynamic> route) => route.isFirst);
  }

  Future<void> consumeOrGoHome(BuildContext context) async {
    if (!context.mounted) {
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    final PendingAuthRedirect? pendingRedirect = _pendingRedirect;
    _pendingRedirect = null;

    final String? currentRoute = ModalRoute.of(context)?.settings.name;
    if (_isAppRootShellRoute(currentRoute)) {
      // AppStartupWrapper already swaps auth → home on login. Pushing another
      // /home route duplicates the tree and trips _dependents.isEmpty.
      _closeAuthOverlayRoutes(navigator);
    } else {
      await navigator.pushNamedAndRemoveUntil(
        AppRoutes.home,
        (Route<dynamic> route) => false,
      );
    }

    if (pendingRedirect == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navContext = nav.NavigationService.navigatorKey.currentContext;
      final navState = nav.NavigationService.navigatorKey.currentState;
      if (navContext == null || navState == null) return;

      final action = pendingRedirect.action;
      if (action != null) {
        action(navContext);
        return;
      }

      final routeName = pendingRedirect.routeName;
      if (routeName == null) return;
      navState.pushNamed(
        routeName,
        arguments: pendingRedirect.arguments,
      );
    });
  }
}
