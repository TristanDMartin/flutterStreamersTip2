import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Result of pre-flight App Check before Firestore/Storage writes.
class AppCheckReadiness {
  const AppCheckReadiness({
    required this.isReady,
    required this.detail,
    this.debugToken,
  });

  final bool isReady;
  final String detail;
  final String? debugToken;

  static const AppCheckReadiness skipped = AppCheckReadiness(
    isReady: true,
    detail: 'App Check not activated for this build',
  );
}

/// Activates App Check. Debug builds use debug providers; release uses
/// Play Integrity / DeviceCheck when [ST_ENABLE_APP_CHECK] is set.
Future<void> activateAppCheckIfEnabled() async {
  if (Firebase.apps.isEmpty) {
    return;
  }
  const bool releaseEnabled = bool.fromEnvironment('ST_ENABLE_APP_CHECK');
  if (!kDebugMode && !releaseEnabled) {
    return;
  }
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleDeviceCheckProvider(),
    );
    debugPrint(
      '✅ Firebase App Check activated '
      '(${kDebugMode ? 'debug' : 'release'} provider)',
    );
    if (kDebugMode) {
      await _logDebugAppCheckToken();
    }
    FirebaseAppCheck.instance.onTokenChange.listen((String? token) {
      if (token != null && token.isNotEmpty) {
        debugPrint('🔐 App Check token refreshed (${token.length} chars)');
      }
    });
  } catch (e) {
    debugPrint('⚠️ Firebase App Check activation failed: $e');
  }
}

/// Verifies a usable App Check token exists before Firestore writes.
Future<AppCheckReadiness> ensureAppCheckReadyForFirestore() async {
  if (Firebase.apps.isEmpty) {
    return const AppCheckReadiness(
      isReady: false,
      detail: 'Firebase not initialized',
    );
  }
  const bool releaseEnabled = bool.fromEnvironment('ST_ENABLE_APP_CHECK');
  if (!kDebugMode && !releaseEnabled) {
    return AppCheckReadiness.skipped;
  }
  try {
    final String? token = await FirebaseAppCheck.instance.getToken(true);
    if (token != null && token.isNotEmpty) {
      return AppCheckReadiness(
        isReady: true,
        detail: 'Valid App Check token (${token.length} chars)',
        debugToken: kDebugMode ? token : null,
      );
    }
    return const AppCheckReadiness(
      isReady: false,
      detail: 'App Check returned an empty token (placeholder may be in use)',
    );
  } catch (e) {
    final String message = e.toString();
    return AppCheckReadiness(
      isReady: false,
      detail: message,
    );
  }
}

Future<void> _logDebugAppCheckToken() async {
  await Future<void>.delayed(const Duration(milliseconds: 800));
  final AppCheckReadiness readiness = await ensureAppCheckReadyForFirestore();
  if (readiness.isReady && readiness.debugToken != null) {
    debugPrint(
      '🔐 App Check DEBUG TOKEN (register in Firebase Console → App Check):\n'
      '   ${readiness.debugToken}',
    );
    return;
  }
  debugPrint(
    '🔐 App Check debug token unavailable: ${readiness.detail}\n'
    '   adb logcat | grep -i "app check"\n'
    '   Or set Firestore/Storage App Check enforcement to Unenforced while testing.',
  );
}
