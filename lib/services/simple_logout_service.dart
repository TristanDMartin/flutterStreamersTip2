import 'package:flutter/material.dart';
import 'robust_auth_service.dart';

/// Simple logout service that handles all the complexity internally
class SimpleLogoutService {
  static final SimpleLogoutService _instance = SimpleLogoutService._internal();
  factory SimpleLogoutService() => _instance;
  SimpleLogoutService._internal();

  /// Simple logout that handles everything
  static Future<bool> logout(BuildContext context) async {
    // Store navigation context BEFORE any async operations
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      debugPrint('🔐 SimpleLogout: Starting instant logout...');
      debugPrint('🔐 Context mounted: ${context.mounted}');
      debugPrint('🔐 Stored navigation context before async operations');

      // Get auth service before any async operations
      final authService = RobustAuthenticationService();
      debugPrint('🔐 Auth service obtained');

      // Perform logout (this will update the auth state immediately)
      debugPrint('🔐 Calling authService.signOut()...');
      await authService.signOut();
      debugPrint('🔐 Auth service signOut completed');

      debugPrint('✅ SimpleLogout: Logout successful');

      // INSTANT navigation - bypass all delays, go straight to login
      // Use the stored navigator context instead of checking context.mounted
      debugPrint('🔄 Navigating to login screen using stored navigator...');

      navigator.pushNamedAndRemoveUntil('/auth', (route) => false);

      debugPrint(
          '✅ Instant logout completed - user sees login screen immediately');
      return true;
    } catch (e) {
      debugPrint('❌ SimpleLogout: Error - $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Stack trace: ${StackTrace.current}');

      // Show error to user using stored scaffold messenger
      try {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Logout failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        debugPrint('❌ Could not show error snackbar: $e');
      }

      return false;
    }
  }
}
