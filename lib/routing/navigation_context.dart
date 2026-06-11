import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/unified_avatar_service.dart' as nav;

/// Resolves a [BuildContext] that sits under [MaterialApp]'s Navigator.
///
/// Onboarding and other overlays rendered in [MaterialApp.builder] are outside
/// the navigator subtree; use this for pushes, sheets, and dialogs.
abstract final class NavigationContext {
  static BuildContext? get root =>
      nav.NavigationService.navigatorKey.currentContext;

  static bool hasNavigatorAncestor(BuildContext context) {
    return context.findAncestorStateOfType<NavigatorState>() != null;
  }

  static bool canNavigate(BuildContext context) {
    return hasNavigatorAncestor(context) || root != null;
  }

  /// Prefer the nearest Navigator (e.g. onboarding shell), then app root.
  static BuildContext requireForNavigation(BuildContext context) {
    if (hasNavigatorAncestor(context)) {
      return context;
    }
    final BuildContext? navigatorContext = root;
    if (navigatorContext != null) {
      return navigatorContext;
    }
    if (kDebugMode) {
      debugPrint(
        'NavigationContext: no Navigator ancestor for navigation request',
      );
    }
    throw FlutterError(
      'NavigationContext: no Navigator available for this operation',
    );
  }

  static bool shouldUseRootNavigator(BuildContext context) {
    return !hasNavigatorAncestor(context);
  }
}
