import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseIOSService {
  static bool _isInitialized = false;
  static bool _isIOS = false;
  static bool _isWeb = false;

  static Future<void> initialize() async {
    _isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    _isWeb = kIsWeb;

    if (_isInitialized) {
      debugPrint('✅ Firebase already initialized');
      return;
    }

    try {
      debugPrint('🔥 FirebaseIOSService: Starting Firebase initialization...');
      debugPrint(
          '📱 Platform: iOS=$_isIOS, Web=$_isWeb, Android=${!_isIOS && !_isWeb}');

      if (_isIOS) {
        // For iOS, AppDelegate.swift already initializes Firebase synchronously
        // Check if Firebase is already initialized before trying to initialize again
        debugPrint('🍎 Checking Firebase initialization for iOS...');

        // Check if Firebase is already initialized by AppDelegate
        if (Firebase.apps.isEmpty) {
          // Not initialized yet - wait briefly for AppDelegate to finish
          debugPrint(
              '⚠️ Firebase not initialized yet - waiting for AppDelegate...');
          await Future.delayed(const Duration(milliseconds: 100));

          // Check again - if still not initialized, initialize it ourselves
          if (Firebase.apps.isEmpty) {
            debugPrint(
                '🔥 Initializing Firebase in Flutter (AppDelegate may have failed)...');
            await Firebase.initializeApp();
            debugPrint('✅ Firebase initialized in Flutter');
          } else {
            debugPrint('✅ Firebase initialized by AppDelegate (after wait)');
          }
        } else {
          debugPrint('✅ Firebase already initialized by AppDelegate');
        }
      } else if (_isWeb) {
        // For web, initialize with default options
        debugPrint('🌐 Initializing Firebase for Web...');
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: "AIzaSyCcUq1k02c4QRvuZSZK16fD6wpUMnLXxe8",
            authDomain: "streamerstip-6cfdb.firebaseapp.com",
            projectId: "streamerstip-6cfdb",
            storageBucket: "streamerstip-6cfdb.firebasestorage.app",
            messagingSenderId: "161050969080",
            appId: "1:161050969080:web:07a92599a2c1a1f504cc0d",
          ),
        );
        debugPrint('✅ Firebase initialized on Web');
      } else {
        // For Android, try to initialize with default options first
        debugPrint('🤖 Initializing Firebase for Android...');
        try {
          // Try default initialization first (uses google-services.json)
          await Firebase.initializeApp();
          debugPrint('✅ Firebase initialized on Android (default)');
        } catch (e) {
          debugPrint(
              '⚠️ Default initialization failed, trying explicit options: $e');
          // Fallback to explicit options
          await Firebase.initializeApp(
            options: const FirebaseOptions(
              apiKey: "AIzaSyCcUq1k02c4QRvuZSZK16fD6wpUMnLXxe8",
              authDomain: "streamerstip-6cfdb.firebaseapp.com",
              projectId: "streamerstip-6cfdb",
              storageBucket: "streamerstip-6cfdb.firebasestorage.app",
              messagingSenderId: "161050969080",
              appId: "1:161050969080:android:07a92599a2c1a1f504cc0d",
            ),
          );
          debugPrint('✅ Firebase initialized on Android (explicit)');
        }
      }

      // Minimal delay - Firebase should be ready immediately after initialization
      // Only wait if absolutely necessary (reduced from 500ms)
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify Firebase is properly initialized
      if (Firebase.apps.isEmpty) {
        debugPrint('⚠️ Firebase.apps is empty after initialization attempt');
        // Don't throw - allow app to continue in degraded mode
        // The app will show auth screen and work without Firebase
      } else {
        debugPrint(
            '✅ Firebase verified - ${Firebase.apps.length} app(s) initialized');
      }

      _isInitialized = true;
      debugPrint(
          '🎉 FirebaseIOSService: Firebase initialization completed successfully!');
    } catch (e) {
      debugPrint('❌ FirebaseIOSService: Firebase initialization failed: $e');
      debugPrint('📍 Error type: ${e.runtimeType}');
      debugPrint('📍 Error details: ${e.toString()}');

      if (_isIOS) {
        debugPrint(
            '💡 iOS: Make sure FirebaseApp.configure() is called in AppDelegate.swift');
      } else if (_isWeb) {
        debugPrint(
            '💡 Web: Make sure Firebase is properly configured in web/index.html');
      } else {
        debugPrint(
            '💡 Android: Make sure google-services.json is in android/app/ and Firebase is properly configured');
      }

      // Don't rethrow - allow app to continue in degraded mode
      // The app will show auth screen and work without Firebase
      debugPrint(
          '⚠️ FirebaseIOSService: Firebase initialization failed - app will continue in degraded mode');
      _isInitialized = false;
    }
  }

  static bool get isInitialized => _isInitialized;
  static bool get isIOS => _isIOS;
  static bool get isWeb => _isWeb;
}
