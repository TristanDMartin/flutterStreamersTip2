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

  Future<void> consumeOrGoHome(BuildContext context) async {
    final navigator = Navigator.of(context);
    final pendingRedirect = _pendingRedirect;
    _pendingRedirect = null;

    if (pendingRedirect == null) {
      navigator.pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
      return;
    }

    navigator.pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);

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
