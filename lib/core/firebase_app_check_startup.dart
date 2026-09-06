import 'dart:async';

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

Completer<void>? _activationCompleter;
bool _providerInstalled = false;
String _activeProviderLabel = 'none';
DateTime? _lastTokenSuccessAt;
String? _cachedTokenPreview;

Future<AppCheckReadiness>? _tokenFetchInFlight;
DateTime? _lastAttestationFailureLoggedAt;
DateTime? _attestationBackoffUntil;

const Duration _attestationBackoff = Duration(seconds: 30);
const Duration _tokenFetchTimeout = Duration(seconds: 8);
const Duration _cachedTokenFreshness = Duration(minutes: 45);

/// Whether App Check is enabled for this build.
///
/// On by default for debug, profile, and release.
/// Opt out only with `--dart-define=ST_DISABLE_APP_CHECK=true`.
bool isAppCheckEnabledForBuild() {
  const bool disabled = bool.fromEnvironment('ST_DISABLE_APP_CHECK');
  return !disabled;
}

bool get isAppCheckProviderInstalled => _providerInstalled;

String get appCheckProviderLabel => _activeProviderLabel;

bool _isAttestationFailure(String message) {
  final String lower = message.toLowerCase();
  return lower.contains('attestation') ||
      lower.contains('403') ||
      lower.contains('400') ||
      lower.contains('app not registered') ||
      lower.contains('failed_precondition') ||
      lower.contains('too many attempts') ||
      lower.contains('no appcheckprovider') ||
      lower.contains('placeholder');
}

/// Activates App Check once Firebase is ready.
///
/// - Release: Play Integrity (Android) / DeviceCheck (Apple)
/// - Debug/profile: debug providers (register token in Firebase Console)
///
/// Safe to call multiple times; concurrent callers share one in-flight future.
/// Failed / premature attempts can be retried (completer cleared).
Future<void> activateAppCheckIfEnabled() async {
  if (_providerInstalled) {
    return;
  }
  final Completer<void>? existing = _activationCompleter;
  if (existing != null) {
    return existing.future;
  }
  final Completer<void> completer = Completer<void>();
  _activationCompleter = completer;
  try {
    if (Firebase.apps.isEmpty) {
      debugPrint('APP_CHECK_INIT_SKIP reason=firebase_not_ready');
      return;
    }
    if (!isAppCheckEnabledForBuild()) {
      debugPrint('APP_CHECK_INIT_SKIP reason=ST_DISABLE_APP_CHECK');
      return;
    }
    final bool useDebugProvider = !kReleaseMode;
    _activeProviderLabel =
        useDebugProvider ? 'debug' : 'play_integrity_or_device_check';
    debugPrint('APP_CHECK_INIT_START provider=$_activeProviderLabel');
    await FirebaseAppCheck.instance.activate(
      providerAndroid: useDebugProvider
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: useDebugProvider
          ? const AppleDebugProvider()
          : const AppleDeviceCheckProvider(),
    );
    _providerInstalled = true;
    debugPrint('APP_CHECK_INIT_SUCCESS provider=$_activeProviderLabel');
    FirebaseAppCheck.instance.onTokenChange.listen((String? token) {
      if (token != null && token.isNotEmpty) {
        _lastTokenSuccessAt = DateTime.now();
        _cachedTokenPreview = '${token.length} chars';
        debugPrint(
          'APP_CHECK_TOKEN_REFRESHED tokenPresent=true '
          'length=${token.length}',
        );
      }
    });
    // Never block activate on the first token fetch.
    if (useDebugProvider) {
      unawaited(_logDebugAppCheckToken());
    }
  } catch (e) {
    final String message = e.toString();
    debugPrint('APP_CHECK_INIT_FAILED error=$message');
    if (message.toLowerCase().contains('app not registered') ||
        message.toLowerCase().contains('failed_precondition')) {
      debugPrint(
        '⚠️ App Check misconfiguration: register the app in Firebase '
        'Console → App Check (Android package '
        'com.streamerstip.streamersTipApp). '
        'Debug: register the printed DEBUG TOKEN under Manage debug tokens.',
      );
    }
  } finally {
    if (!completer.isCompleted) {
      completer.complete();
    }
    // Allow a later retry if activate never installed a provider.
    if (!_providerInstalled) {
      _activationCompleter = null;
    }
  }
}

/// Call after Firebase + activate so Share already has a warm token.
///
/// Retries a few times in the background; never throws.
Future<void> warmAppCheckAtStartup() async {
  if (!isAppCheckEnabledForBuild()) {
    debugPrint('APP_CHECK_WARM_SKIP reason=disabled');
    return;
  }
  if (Firebase.apps.isEmpty) {
    debugPrint('APP_CHECK_WARM_SKIP reason=firebase_not_ready');
    return;
  }
  debugPrint('APP_CHECK_WARM_START');
  await activateAppCheckIfEnabled();
  if (!_providerInstalled) {
    debugPrint('APP_CHECK_WARM_FAILED reason=provider_not_installed');
    return;
  }
  for (int attempt = 1; attempt <= 3; attempt++) {
    final AppCheckReadiness readiness = await ensureAppCheckReadyForFirestore(
      forceRefresh: attempt > 1,
    );
    if (readiness.isReady) {
      debugPrint(
        'APP_CHECK_WARM_SUCCESS attempt=$attempt detail=${readiness.detail}',
      );
      return;
    }
    debugPrint(
      'APP_CHECK_WARM_RETRY attempt=$attempt detail=${readiness.detail}',
    );
    await Future<void>.delayed(Duration(seconds: attempt));
  }
  debugPrint('APP_CHECK_WARM_EXHAUSTED');
}

/// Verifies a usable App Check token exists before Firestore / Worker calls.
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
  if (!_providerInstalled) {
    return const AppCheckReadiness(
      isReady: false,
      detail: 'No AppCheckProvider installed (activation failed)',
    );
  }
  if (!forceRefresh &&
      _lastTokenSuccessAt != null &&
      DateTime.now().difference(_lastTokenSuccessAt!) < _cachedTokenFreshness &&
      _cachedTokenPreview != null) {
    debugPrint(
      'APP_CHECK_TOKEN_CACHE_HIT preview=$_cachedTokenPreview '
      'ageMs=${DateTime.now().difference(_lastTokenSuccessAt!).inMilliseconds}',
    );
    return AppCheckReadiness(
      isReady: true,
      detail: 'Cached App Check token ($_cachedTokenPreview)',
    );
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
  final Stopwatch sw = Stopwatch()..start();
  debugPrint(
    'APP_CHECK_TOKEN_REQUEST forceRefresh=$forceRefresh '
    'provider=$_activeProviderLabel',
  );
  try {
    final String? token = await FirebaseAppCheck.instance
        .getToken(forceRefresh)
        .timeout(_tokenFetchTimeout);
    sw.stop();
    if (token != null && token.isNotEmpty) {
      _attestationBackoffUntil = null;
      _lastTokenSuccessAt = DateTime.now();
      _cachedTokenPreview = '${token.length} chars';
      debugPrint(
        'APP_CHECK_TOKEN_SUCCESS tokenPresent=true '
        'elapsedMs=${sw.elapsedMilliseconds} length=${token.length}',
      );
      return AppCheckReadiness(
        isReady: true,
        detail: 'Valid App Check token (${token.length} chars)',
        debugToken: !kReleaseMode ? token : null,
      );
    }
    debugPrint(
      'APP_CHECK_TOKEN_FAILED error=empty_token '
      'elapsedMs=${sw.elapsedMilliseconds}',
    );
    return const AppCheckReadiness(
      isReady: false,
      detail: 'App Check returned an empty token (placeholder may be in use)',
    );
  } on TimeoutException {
    sw.stop();
    debugPrint(
      'APP_CHECK_TOKEN_FAILED error=timeout '
      'elapsedMs=${sw.elapsedMilliseconds}',
    );
    return AppCheckReadiness(
      isReady: false,
      detail:
          'App Check token fetch timed out after ${sw.elapsedMilliseconds}ms',
    );
  } catch (e) {
    sw.stop();
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
    debugPrint(
      'APP_CHECK_TOKEN_FAILED error=$message '
      'elapsedMs=${sw.elapsedMilliseconds}',
    );
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
  await activateAppCheckIfEnabled();
  if (!_providerInstalled) {
    return null;
  }
  final DateTime? backoffUntil = _attestationBackoffUntil;
  if (!forceRefresh &&
      backoffUntil != null &&
      DateTime.now().isBefore(backoffUntil)) {
    return null;
  }
  final AppCheckReadiness readiness = await ensureAppCheckReadyForFirestore(
    forceRefresh: forceRefresh,
  );
  if (!readiness.isReady) {
    return null;
  }
  try {
    final String? token = await FirebaseAppCheck.instance
        .getToken(false)
        .timeout(const Duration(seconds: 3));
    if (token != null && token.isNotEmpty) {
      return token;
    }
    return null;
  } catch (e) {
    debugPrint('APP_CHECK_HTTP_TOKEN_FAILED $e');
    return null;
  }
}

Future<void> _logDebugAppCheckToken() async {
  await Future<void>.delayed(const Duration(milliseconds: 500));
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
    '   adb logcat | grep -iE "App Check|DEBUG TOKEN|FirebaseAppCheck"\n'
    '   Register the token under Firebase Console → App Check → '
    'Manage debug tokens, then force-stop and relaunch.',
  );
}
