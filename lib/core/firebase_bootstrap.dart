import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Ensures the Dart Firebase default app exists before any plugin access.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<void>? _initInFlight;

  static const FirebaseOptions _iosOptions = FirebaseOptions(
    apiKey: 'AIzaSyBGBd8N7ZYxkLkIgzVH_lAejz-AlBRxPmA',
    appId: '1:161050969080:ios:0280d1b8f828f21004cc0d',
    messagingSenderId: '161050969080',
    projectId: 'streamerstip-6cfdb',
    storageBucket: 'streamerstip-6cfdb.firebasestorage.app',
    iosBundleId: 'com.streamerstip.streamersTipApp',
  );

  static const FirebaseOptions _androidOptions = FirebaseOptions(
    apiKey: 'AIzaSyCcUq1k02c4QRvuZSZK16fD6wpUMnLXxe8',
    appId: '1:161050969080:android:07a92599a2c1a1f504cc0d',
    messagingSenderId: '161050969080',
    projectId: 'streamerstip-6cfdb',
    storageBucket: 'streamerstip-6cfdb.firebasestorage.app',
  );

  static const FirebaseOptions _webOptions = FirebaseOptions(
    apiKey: 'AIzaSyCcUq1k02c4QRvuZSZK16fD6wpUMnLXxe8',
    authDomain: 'streamerstip-6cfdb.firebaseapp.com',
    projectId: 'streamerstip-6cfdb',
    storageBucket: 'streamerstip-6cfdb.firebasestorage.app',
    messagingSenderId: '161050969080',
    appId: '1:161050969080:web:07a92599a2c1a1f504cc0d',
  );

  static bool get isReady => Firebase.apps.isNotEmpty;

  static Future<bool> ensureInitialized() {
    if (isReady) {
      return Future<bool>.value(true);
    }
    final Future<void>? inFlight = _initInFlight;
    if (inFlight != null) {
      return inFlight.then((_) => isReady);
    }
    final Future<void> init = _initializeWithRetry();
    _initInFlight = init;
    return init.whenComplete(() {
      if (identical(_initInFlight, init)) {
        _initInFlight = null;
      }
    }).then((_) => isReady);
  }

  static Future<void> _initializeWithRetry() async {
    for (int attempt = 0; attempt < 60; attempt++) {
      if (isReady) {
        return;
      }
      try {
        await _initializeForPlatform();
        if (isReady) {
          debugPrint(
            '✅ FirebaseBootstrap: ready on attempt ${attempt + 1}',
          );
          return;
        }
      } catch (e) {
        if (_isDuplicateAppError(e) && isReady) {
          return;
        }
        if (attempt == 0 || attempt % 10 == 0) {
          debugPrint('⚠️ FirebaseBootstrap attempt ${attempt + 1}: $e');
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    debugPrint(
      '❌ FirebaseBootstrap: still unavailable after retries',
    );
  }

  static Future<void> _initializeForPlatform() async {
    if (kIsWeb) {
      await Firebase.initializeApp(options: _webOptions);
      return;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        await Firebase.initializeApp(options: _iosOptions);
      case TargetPlatform.android:
        try {
          await Firebase.initializeApp();
        } catch (_) {
          await Firebase.initializeApp(options: _androidOptions);
        }
      default:
        await Firebase.initializeApp();
    }
  }

  static bool _isDuplicateAppError(Object error) {
    final String message = error.toString().toLowerCase();
    return message.contains('duplicate-app');
  }
}
