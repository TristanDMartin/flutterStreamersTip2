import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Result of pre-flight App Check before Firestore/Storage writes.
class AppCheckReadiness {
  const AppCheckReadiness({
    required this.isReady,
    required this.detail,
    this.appCheckToken,
    this.debugToken,
  });

  final bool isReady;
  final String detail;
  final String? appCheckToken;
  final String? debugToken;

  static const AppCheckReadiness skipped = AppCheckReadiness(
    isReady: true,
    detail: 'App Check not activated for this build',
  );
}

/// Whether App Check is enabled for this build.
///
/// Release/profile: on by default (opt out with [ST_DISABLE_APP_CHECK]).
/// Debug: opt in with [ST_ENABLE_APP_CHECK_DEBUG].
bool isAppCheckEnabledForBuild() {
  const bool disabled = bool.fromEnvironment('ST_DISABLE_APP_CHECK');
  if (disabled) {
    return false;
  }
  if (kDebugMode) {
    return const bool.fromEnvironment('ST_ENABLE_APP_CHECK_DEBUG');
  }
  return true;
}

const String _androidDebugToken = String.fromEnvironment(
  'ST_ANDROID_APP_CHECK_DEBUG_TOKEN',
  defaultValue: '',
);
const String _appleDebugToken = String.fromEnvironment(
  'ST_APPLE_APP_CHECK_DEBUG_TOKEN',
  defaultValue: '',
);

String? _nonEmptyDebugToken(String value) {
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Activates App Check. Debug builds use debug providers; release/profile use
/// Play Integrity / DeviceCheck by default.
Future<void> activateAppCheckIfEnabled() async {
  if (Firebase.apps.isEmpty) {
    return;
  }
  if (!isAppCheckEnabledForBuild()) {
    if (kDebugMode) {
      debugPrint(
        'ℹ️ App Check skipped in debug '
        '(pass --dart-define=ST_ENABLE_APP_CHECK_DEBUG=true after registering '
        'the iOS debug token in Firebase Console → App Check)',
      );
    }
    return;
  }
  if (_activationCompleted) {
    return;
  }
  final Future<void>? existingActivation = _activationInFlight;
  if (existingActivation != null) {
    return existingActivation;
  }
  late final Future<void> activationFuture;
  activationFuture = _activateAppCheck().whenComplete(() {
    if (identical(_activationInFlight, activationFuture)) {
      _activationInFlight = null;
    }
  });
  _activationInFlight = activationFuture;
  return activationFuture;
}

Future<void> _activateAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? AndroidDebugProvider(
              debugToken: _nonEmptyDebugToken(_androidDebugToken),
            )
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? AppleDebugProvider(
              debugToken: _nonEmptyDebugToken(_appleDebugToken),
            )
          : const AppleDeviceCheckProvider(),
    );
    debugPrint(
      '✅ Firebase App Check activated '
      '(${kDebugMode ? 'debug' : 'play_integrity'} provider)',
    );
    if (kDebugMode && _androidDebugToken.trim().isNotEmpty) {
      debugPrint(
        '🔐 Android App Check debug token supplied by '
        'ST_ANDROID_APP_CHECK_DEBUG_TOKEN',
      );
    }
    if (kDebugMode && _appleDebugToken.trim().isNotEmpty) {
      debugPrint(
        '🔐 Apple App Check debug token supplied by '
        'ST_APPLE_APP_CHECK_DEBUG_TOKEN',
      );
    }
    _activationCompleted = true;
    if (kDebugMode) {
      await _logDebugAppCheckToken();
    }
    FirebaseAppCheck.instance.onTokenChange.listen((String? token) {
      if (token != null && token.isNotEmpty) {
        debugPrint('🔐 App Check token refreshed (${token.length} chars)');
      }
    });
  } catch (e) {
    final String message = e.toString();
    if (message.toLowerCase().contains('app not registered') ||
        message.toLowerCase().contains('failed_precondition')) {
      debugPrint(
        '⚠️ App Check misconfiguration: register this Android/iOS app in '
        'Firebase Console → App Check. '
        'Debug: flutter run --dart-define=ST_ENABLE_APP_CHECK_DEBUG=true '
        '--dart-define=ST_ANDROID_APP_CHECK_DEBUG_TOKEN=<registered-token>',
      );
    }
    debugPrint('⚠️ Firebase App Check activation failed: $e');
  }
}

Future<AppCheckReadiness>? _tokenFetchInFlight;
Future<void>? _activationInFlight;
bool _activationCompleted = false;
DateTime? _lastAttestationFailureLoggedAt;
DateTime? _attestationBackoffUntil;

const Duration _attestationBackoff = Duration(seconds: 30);

bool _isAttestationFailure(String message) {
  final String lower = message.toLowerCase();
  return lower.contains('attestation') ||
      lower.contains('403') ||
      lower.contains('400') ||
      lower.contains('app not registered') ||
      lower.contains('failed_precondition') ||
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
  if (!isAppCheckEnabledForBuild()) {
    return AppCheckReadiness.skipped;
  }
  await activateAppCheckIfEnabled();
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
  fetchFuture =
      _fetchAppCheckReadiness(forceRefresh: forceRefresh).whenComplete(() {
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
        appCheckToken: token,
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

/// App Check token for HTTP backends (`X-Firebase-AppCheck` header).
Future<String?> fetchAppCheckHttpToken({bool forceRefresh = false}) async {
  if (!isAppCheckEnabledForBuild() || Firebase.apps.isEmpty) {
    return null;
  }
  final DateTime? backoffUntil = _attestationBackoffUntil;
  if (!forceRefresh &&
      backoffUntil != null &&
      DateTime.now().isBefore(backoffUntil)) {
    return null;
  }
  try {
    final String? token =
        await FirebaseAppCheck.instance.getToken(forceRefresh);
    if (token != null && token.isNotEmpty) {
      _attestationBackoffUntil = null;
      return token;
    }
    return null;
  } catch (e) {
    final String message = e.toString();
    if (_isAttestationFailure(message)) {
      _attestationBackoffUntil = DateTime.now().add(_attestationBackoff);
      final DateTime? lastLogged = _lastAttestationFailureLoggedAt;
      if (lastLogged == null ||
          DateTime.now().difference(lastLogged) > _attestationBackoff) {
        _lastAttestationFailureLoggedAt = DateTime.now();
        debugPrint('APP_CHECK_HTTP_TOKEN_FAILED (backoff) $message');
      }
    } else {
      debugPrint('APP_CHECK_HTTP_TOKEN_FAILED $message');
    }
    return null;
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
