import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routing/app_routes.dart';
import 'robust_auth_service.dart';

/// Simple logout service that handles all the complexity internally.
class SimpleLogoutService {
  static final SimpleLogoutService _instance = SimpleLogoutService._internal();
  factory SimpleLogoutService() => _instance;
  SimpleLogoutService._internal();

  /// Signs out via the shared auth provider and returns to the startup shell.
  static Future<bool> logout(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState scaffoldMessenger =
        ScaffoldMessenger.of(context);

    try {
      debugPrint('🔐 SimpleLogout: Starting sign out...');
      final RobustAuthenticationService authService =
          ProviderScope.containerOf(context).read(robustAuthServiceProvider);
      await authService.signOut();
      debugPrint('✅ SimpleLogout: Sign out completed');

      navigator.pushNamedAndRemoveUntil(AppRoutes.root, (Route<dynamic> route) {
        return false;
      });
      return true;
    } catch (e) {
      debugPrint('❌ SimpleLogout: Error - $e');
      try {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Logout failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } catch (_) {}
      return false;
    }
  }
}
