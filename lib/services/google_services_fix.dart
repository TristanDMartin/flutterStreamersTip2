import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;

/// Google Services Fix
/// 
/// This service handles Google Play Services authentication issues
/// and provides fallback mechanisms for when Google services are unavailable.
class GoogleServicesFix {
  static bool _isInitialized = false;
  static bool _isGoogleServicesAvailable = true;

  /// Initialize Google Services with error handling
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Test Google Sign-In availability
      await _testGoogleSignIn();
      _isGoogleServicesAvailable = true;
      debugPrint('✅ GoogleServicesFix: Google Play Services available');
    } catch (e) {
      _isGoogleServicesAvailable = false;
      debugPrint('⚠️ GoogleServicesFix: Google Play Services unavailable: $e');
      debugPrint('🔧 GoogleServicesFix: Using fallback authentication methods');
    }

    _isInitialized = true;
  }

  /// Test Google Sign-In availability
  static Future<void> _testGoogleSignIn() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      
      // Try to get the current user without signing in
      await googleSignIn.signInSilently();
      
      debugPrint('✅ GoogleServicesFix: Google Sign-In test successful');
    } catch (e) {
      throw Exception('Google Sign-In test failed: $e');
    }
  }

  /// Check if Google Services are available
  static bool get isGoogleServicesAvailable => _isGoogleServicesAvailable;

  /// Get a user-friendly error message for Google Services issues
  static String getGoogleServicesErrorMessage(dynamic error) {
    if (error.toString().contains('Unknown calling package name')) {
      return 'Google Play Services configuration issue. Please contact support.';
    }
    
    if (error.toString().contains('Network error')) {
      return 'Network connection required for Google services.';
    }
    
    if (error.toString().contains('SignInRequiredException')) {
      return 'Please sign in to use Google services.';
    }
    
    return 'Google services temporarily unavailable. Please try again.';
  }

  /// Handle Google Sign-In with fallback
  static Future<fa.UserCredential?> signInWithGoogle({
    required String requestId,
  }) async {
    if (!_isGoogleServicesAvailable) {
      debugPrint('⚠️ GoogleServicesFix: Google Sign-In not available, using fallback');
      return null;
    }

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('❌ GoogleServicesFix: Google Sign-In cancelled by user');
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = fa.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await fa.FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      debugPrint('❌ GoogleServicesFix: Google Sign-In failed: $e');
      _isGoogleServicesAvailable = false;
      return null;
    }
  }

  /// Handle Google Sign-Out with error handling
  static Future<void> signOutFromGoogle() async {
    if (!_isGoogleServicesAvailable) {
      debugPrint('⚠️ GoogleServicesFix: Google Sign-Out not available');
      return;
    }

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      debugPrint('✅ GoogleServicesFix: Google Sign-Out successful');
    } catch (e) {
      debugPrint('❌ GoogleServicesFix: Google Sign-Out failed: $e');
    }
  }

  /// Reset Google Services availability (for testing)
  static void reset() {
    _isInitialized = false;
    _isGoogleServicesAvailable = true;
  }
}
