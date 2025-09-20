import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseIOSService {
  static bool _isInitialized = false;
  static bool _isIOS = false;

  static Future<void> initialize() async {
    _isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    
    if (_isInitialized) {
      debugPrint('✅ Firebase already initialized');
      return;
    }

    try {
      if (_isIOS) {
        // For iOS, we rely on AppDelegate.swift to initialize Firebase
        // This is just a check to ensure it's working
        await Firebase.initializeApp();
        debugPrint('✅ Firebase initialized on iOS via AppDelegate');
      } else {
        // For Android, initialize normally
        await Firebase.initializeApp();
        debugPrint('✅ Firebase initialized on Android');
      }
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('⚠️ Firebase initialization failed: $e');
      if (_isIOS) {
        debugPrint('💡 iOS: Make sure FirebaseApp.configure() is called in AppDelegate.swift');
      }
      // Don't throw - let the app continue without Firebase
    }
  }

  static bool get isInitialized => _isInitialized;
  static bool get isIOS => _isIOS;
}
