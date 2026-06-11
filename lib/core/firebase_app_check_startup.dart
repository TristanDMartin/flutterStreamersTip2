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
  const bool debugEnabled = bool.fromEnvironment('ST_ENABLE_APP_CHECK_DEBUG');
  if (kDebugMode) {
    if (!debugEnabled) {
      debugPrint(
        'ℹ️ App Check skipped in debug '
        '(pass --dart-define=ST_ENABLE_APP_CHECK_DEBUG=true after registering '
        'the iOS debug token in Firebase Console → App Check)',
      );
      return;
    }
  } else if (!releaseEnabled) {
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
      '(${kDebugMode ? 'debug' : 'play_integrity'} provider)',
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

Future<AppCheckReadiness>? _tokenFetchInFlight;
DateTime? _lastAttestationFailureLoggedAt;
DateTime? _attestationBackoffUntil;

const Duration _attestationBackoff = Duration(seconds: 30);

bool _isAttestationFailure(String message) {
  final String lower = message.toLowerCase();
  return lower.contains('attestation') ||
      lower.contains('403') ||
      lower.contains('too many attempts');
}

/// Verifies a usable App Check token exists before Firestore writes.
Future<AppCheckReadiness> ensureAppCheckReadyForFirestore({
  bool forceRefresh = false,
}) async {
  if (Firebase.apps.isEmpty) {
    return const AppCheckReadiness(
      isReady: false,
      detail: 'Firebase not initialized',
    );
  }
  const bool releaseEnabled = bool.fromEnvironment('ST_ENABLE_APP_CHECK');
  const bool debugEnabled = bool.fromEnvironment('ST_ENABLE_APP_CHECK_DEBUG');
  if (kDebugMode ? !debugEnabled : !releaseEnabled) {
    return AppCheckReadiness.skipped;
  }
  final DateTime? backoffUntil = _attestationBackoffUntil;
  if (!forceRefresh &&
      backoffUntil != null &&
      DateTime.now().isBefore(backoffUntil)) {
    return AppCheckReadiness(
      isReady: false,
      detail: 'App Check in backoff until $backoffUntil',
    );
  }
  if (_tokenFetchInFlight != null) {
    return _tokenFetchInFlight!;
  }
  late final Future<AppCheckReadiness> fetchFuture;
  fetchFuture = _fetchAppCheckReadiness(forceRefresh: forceRefresh)
      .whenComplete(() {
    if (identical(_tokenFetchInFlight, fetchFuture)) {
      _tokenFetchInFlight = null;
    }
  });
  _tokenFetchInFlight = fetchFuture;
  return fetchFuture;
}

Future<AppCheckReadiness> _fetchAppCheckReadiness({
  required bool forceRefresh,
}) async {
  try {
    final String? token =
        await FirebaseAppCheck.instance.getToken(forceRefresh);
    if (token != null && token.isNotEmpty) {
      _attestationBackoffUntil = null;
      return AppCheckReadiness(
        isReady: true,
        detail: 'Valid App Check token (${token.length} chars)',
        debugToken: kDebugMode ? token : null,
      );
    }
    debugPrint(
      'STATUS_APP_CHECK_ERROR detail=empty_token placeholder_may_be_in_use',
    );
    return const AppCheckReadiness(
      isReady: false,
      detail: 'App Check returned an empty token (placeholder may be in use)',
    );
  } catch (e) {
    final String message = e.toString();
    if (_isAttestationFailure(message)) {
      _attestationBackoffUntil = DateTime.now().add(_attestationBackoff);
      final DateTime? lastLogged = _lastAttestationFailureLoggedAt;
      if (lastLogged == null ||
          DateTime.now().difference(lastLogged) > _attestationBackoff) {
        _lastAttestationFailureLoggedAt = DateTime.now();
        debugPrint('APP_CHECK_ATTESTATION_FAILED $message');
      }
    }
    debugPrint('STATUS_APP_CHECK_ERROR detail=$message');
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
