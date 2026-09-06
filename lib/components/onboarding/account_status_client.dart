import 'dart:convert';
import '../../features/onboarding_tippy/tippy_onboarding_debug_log.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../core/app_check_http_headers.dart';
import '../../core/backend/site_api_base.dart';
import 'account_enforcement.dart';
import 'account_navigation.dart';

class SignupRestrictionException implements Exception {
  const SignupRestrictionException({
    required this.code,
    required this.reason,
    required this.message,
  });

  final String code;
  final String reason;
  final String message;

  @override
  String toString() => message;
}

SignupRestrictionException _signupRestrictionFromResponse(
  http.Response response,
) {
  Object? decoded;
  try {
    decoded = jsonDecode(response.body);
  } catch (_) {
    decoded = null;
  }
  final Map<String, dynamic> data =
      decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  final String code = (data['code'] as String?) ?? 'PENDING_FAILED';
  final List<String> reasons = (data['reasons'] is List)
      ? (data['reasons'] as List<dynamic>)
          .map((dynamic value) => '$value')
          .toList()
      : <String>[];
  final ({String reason, String message}) mapped = messageFromSignupRestriction(
    code: code,
    reason: data['reason'] as String?,
    reasons: reasons,
    decision: data['decision'] as String?,
  );
  return SignupRestrictionException(
    code: code,
    reason: mapped.reason,
    message: mapped.message,
  );
}

class AccountStatusSnapshot {
  const AccountStatusSnapshot({
    required this.activationState,
    required this.tippyStageHint,
    required this.allowApp,
    required this.lifecycle,
    this.activationReason,
    this.username,
    this.preferredUsername,
    this.canonicalUsername,
    this.provisioned = false,
    this.accountStatus,
  });

  final String? activationState;
  final String? activationReason;
  final String? tippyStageHint;
  final bool allowApp;
  final String? lifecycle;
  final String? username;
  final String? preferredUsername;
  final String? canonicalUsername;
  final bool provisioned;
  final String? accountStatus;

  AccountNavigation get navigation => navigationFromAccountStatus(
        activationState: activationState,
        activationReason: activationReason,
        tippyStageHint: tippyStageHint,
        allowApp: allowApp,
      );
}

const Duration _statusCacheTtl = Duration(milliseconds: 2500);
AccountStatusSnapshot? _statusCache;
DateTime? _statusCacheAt;
Future<AccountStatusSnapshot>? _statusInFlight;

void clearAccountStatusClientCache() {
  _statusCache = null;
  _statusCacheAt = null;
  _statusInFlight = null;
}

void seedAccountStatusClientCache(AccountStatusSnapshot value) {
  _statusInFlight = null;
  _statusCache = value;
  _statusCacheAt = DateTime.now();
}

Future<AccountStatusSnapshot> fetchAccountStatus({bool force = false}) async {
  if (!force &&
      _statusCache != null &&
      _statusCacheAt != null &&
      DateTime.now().difference(_statusCacheAt!) < _statusCacheTtl) {
    return _statusCache!;
  }
  if (!force && _statusInFlight != null) {
    return _statusInFlight!;
  }
  _statusInFlight = _fetchAccountStatusOnce();
  try {
    final AccountStatusSnapshot value = await _statusInFlight!;
    _statusCache = value;
    _statusCacheAt = DateTime.now();
    return value;
  } catch (error) {
    final AccountStatusSnapshot? cached = _statusCache;
    if (cached != null &&
        cached.activationState == 'EMAIL_VERIFICATION_REQUIRED') {
      return cached;
    }
    rethrow;
  } finally {
    _statusInFlight = null;
  }
}

Future<AccountStatusSnapshot> _fetchAccountStatusOnce() async {
  final User? user = FirebaseAuth.instance.currentUser;
  final String? idToken = await user?.getIdToken();
  if (idToken == null || idToken.isEmpty) {
    throw StateError('AUTH_REQUIRED');
  }
  final Map<String, String> headers = await buildAuthenticatedHttpHeaders(
    idToken: idToken,
    extra: const <String, String>{'Accept': 'application/json'},
  );
  final Stopwatch sw = Stopwatch()..start();
  final http.Response response = await http
      .get(Uri.parse(siteAccountStatusUrl()), headers: headers)
      .timeout(const Duration(seconds: 20));
  logTippyActivationProof(
    '[ACTIVATION_PROOF] event=status_request httpStatus=${response.statusCode} '
    'durationMs=${sw.elapsedMilliseconds}',
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('STATUS_FAILED: ${response.statusCode}');
  }
  final Object? decoded = jsonDecode(response.body);
  final Map<String, dynamic> data =
      decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  return AccountStatusSnapshot(
    activationState: data['activationState'] as String?,
    activationReason: data['activationReason'] as String?,
    tippyStageHint: data['tippyStageHint'] as String?,
    allowApp: data['allowApp'] == true,
    lifecycle: data['lifecycle'] as String?,
    username: (data['username'] as String?)?.trim(),
    preferredUsername: (data['preferredUsername'] as String?)?.trim(),
    canonicalUsername: (data['canonicalUsername'] as String?)?.trim(),
    provisioned: data['provisioned'] == true,
    accountStatus: (data['accountStatus'] as String?)?.trim(),
  );
}

Future<void> createPendingAccount({
  String? preferredUsername,
  String? displayName,
  String? onboardingSessionId,
}) async {
  final User? user = FirebaseAuth.instance.currentUser;
  final String? idToken = await user?.getIdToken(true);
  if (idToken == null || idToken.isEmpty) {
    throw StateError('AUTH_REQUIRED');
  }
  final Map<String, String> headers = await buildAuthenticatedHttpHeaders(
    idToken: idToken,
    extra: const <String, String>{'Content-Type': 'application/json'},
  );
  final http.Response response = await http
      .post(
        Uri.parse(siteAccountPendingUrl()),
        headers: headers,
        body: jsonEncode(<String, dynamic>{
          'preferredUsername': preferredUsername,
          'displayName': displayName,
          if (onboardingSessionId != null)
            'onboardingSessionId': onboardingSessionId,
        }),
      )
      .timeout(const Duration(seconds: 20));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw _signupRestrictionFromResponse(response);
  }
  clearAccountStatusClientCache();
  seedAccountStatusClientCache(
    AccountStatusSnapshot(
      activationState: 'EMAIL_VERIFICATION_REQUIRED',
      tippyStageHint: 'verify_email',
      allowApp: false,
      lifecycle: 'PENDING_VERIFICATION',
      preferredUsername: preferredUsername?.trim(),
      provisioned: false,
    ),
  );
}

Future<void> saveOwnerAvatarUrl({
  required String uid,
  required String avatarUrl,
}) async {
  final User? user = FirebaseAuth.instance.currentUser;
  final String? idToken = await user?.getIdToken(true);
  if (idToken == null || idToken.isEmpty) {
    throw StateError('AUTH_REQUIRED');
  }
  final Map<String, String> headers = await buildAuthenticatedHttpHeaders(
    idToken: idToken,
    extra: const <String, String>{'Content-Type': 'application/json'},
  );
  final String body = jsonEncode(<String, dynamic>{
    'userId': uid,
    'avatarURL': avatarUrl,
    'avatarUrl': avatarUrl,
  });
  http.Response response = await http
      .post(
        Uri.parse(siteAvatarSaveUrl()),
        headers: headers,
        body: body,
      )
      .timeout(const Duration(seconds: 20));
  logTippyActivationProof(
        '[ACTIVATION_PROOF] event=avatar_save_api httpStatus=${response.statusCode}',
  );
  if (response.statusCode == 404) {
    response = await http
        .put(
          Uri.parse(siteAvatarSyncUrl()),
          headers: headers,
          body: body,
        )
        .timeout(const Duration(seconds: 20));
    logTippyActivationProof(
        '[ACTIVATION_PROOF] event=avatar_sync_api httpStatus=${response.statusCode}',
    );
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('AVATAR_SAVE_FAILED: ${response.statusCode}');
  }
}
