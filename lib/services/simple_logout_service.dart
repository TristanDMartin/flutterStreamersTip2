import 'package:flutter/material.dart';
import 'robust_auth_service.dart';
import '../widgets/auth_modal_view.dart';

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
      print('🔐 SimpleLogout: Starting instant logout...');
      print('🔐 Context mounted: ${context.mounted}');
      print('🔐 Stored navigation context before async operations');
      
      // Get auth service before any async operations
      final authService = RobustAuthenticationService();
      print('🔐 Auth service obtained');
      
      // Perform logout (this will update the auth state immediately)
      print('🔐 Calling authService.signOut()...');
      await authService.signOut();
      print('🔐 Auth service signOut completed');
      
      print('✅ SimpleLogout: Logout successful');
      
      // INSTANT navigation - bypass all delays, go straight to login
      // Use the stored navigator context instead of checking context.mounted
      print('🔄 Navigating to login screen using stored navigator...');
      
      // Go directly to AuthModalView - no delays, no launch screen, no initialization
      // This is how TikTok/Instagram do it - instant logout to login screen
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const AuthModalView(),
        ),
        (route) => false,
      );
      
      print('✅ Instant logout completed - user sees login screen immediately');
      return true;
    } catch (e) {
      print('❌ SimpleLogout: Error - $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: ${StackTrace.current}');
      
      // Show error to user using stored scaffold messenger
      try {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Logout failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        print('❌ Could not show error snackbar: $e');
      }
      
      return false;
    }
  }
}
