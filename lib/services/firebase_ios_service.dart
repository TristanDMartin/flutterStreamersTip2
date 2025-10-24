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
        // For iOS, we rely on AppDelegate.swift to initialize Firebase
        // This is just a check to ensure it's working
        debugPrint('🍎 Initializing Firebase for iOS...');
        await Firebase.initializeApp();
        debugPrint('✅ Firebase initialized on iOS via AppDelegate');
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
        // For Android, initialize with explicit options
        debugPrint('🤖 Initializing Firebase for Android...');
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
        debugPrint('✅ Firebase initialized on Android');
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

      // Don't throw - let the app continue without Firebase
      debugPrint('⚠️ FirebaseIOSService: Continuing without Firebase...');
    }
  }

  static bool get isInitialized => _isInitialized;
  static bool get isIOS => _isIOS;
  static bool get isWeb => _isWeb;
}
