import 'dart:convert';
import '../../features/onboarding_tippy/tippy_onboarding_debug_log.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/app_check_http_headers.dart';
import '../../core/backend/site_api_base.dart';
import 'account_navigation.dart';
import 'account_status_client.dart';

const List<int> kVerifiedActivationRetryDelaysMs = <int>[0, 400];

const String kVerifiedActivationPersistentError =
    'We could not finish setting up your account. Please try again.';

const Set<String> kNonRetryableActivationCodes = <String>{
  'IDENTITY_MISMATCH',
  'ACCOUNT_DISABLED',
  'ACCOUNT_SUSPENDED',
  'ACCOUNT_BLOCKED_IDENTITY',
  'AUTH_REQUIRED',
  'SIGNUP_BLOCKED',
  'SIGNUP_CHALLENGE_REQUIRED',
  'DISPOSABLE_EMAIL',
};

class VerifiedActivationException implements Exception {
  const VerifiedActivationException({
    this.code = 'ACTIVATION_FAILED',
    this.status,
    this.message = kVerifiedActivationPersistentError,
  });

  final String code;
  final int? status;
  final String message;

  @override
  String toString() => message;
}

class VerifiedActivationSession {
  const VerifiedActivationSession({
    required this.uid,
    required this.emailVerified,
  });

  final String uid;
  final bool emailVerified;
}

bool isVerifiedActivationReady({
  String? activationState,
  String? activationReason,
  String? tippyStageHint,
  bool allowApp = false,
  bool provisioned = false,
}) {
  if (allowApp || activationState == 'ACTIVATED') {
    return true;
  }
  if (!provisioned) {
    return false;
  }
  final AccountNavigation nav = navigationFromAccountStatus(
    activationState: activationState,
    activationReason: activationReason,
    tippyStageHint: tippyStageHint,
    allowApp: allowApp,
  );
  return nav.route == 'onboarding' || nav.route == 'app';
}

bool isRetryableVerifiedActivationFailure({
  String? code,
  int? status,
}) {
  final String normalized = (code ?? '').toUpperCase();
  if (kNonRetryableActivationCodes.contains(normalized)) {
    return false;
  }
  final int statusCode = status ?? 0;
  if (statusCode == 401 || statusCode == 403 || statusCode == 429) {
    return false;
  }
  if (normalized == 'PROVISION_FAILED' ||
      normalized == 'STATUS_FAILED' ||
      normalized == 'ACTIVATION_FAILED') {
    return true;
  }
  if (statusCode == 404 || statusCode == 408) {
    return true;
  }
  return statusCode >= 500 && statusCode < 600;
}

typedef ReloadVerifiedActivation = Future<VerifiedActivationSession> Function({
  bool forceRefresh,
});
typedef ProvisionVerifiedAccount = Future<void> Function(String intendedUid);
typedef FetchVerifiedActivationStatus = Future<AccountStatusSnapshot> Function();
typedef WaitVerifiedActivation = Future<void> Function(int milliseconds);

Future<AccountStatusSnapshot> runVerifiedActivationReconciliation({
  String? intendedUid,
  required ReloadVerifiedActivation reloadAndRefresh,
  required ProvisionVerifiedAccount provision,
  required FetchVerifiedActivationStatus getStatus,
  WaitVerifiedActivation? wait,
}) async {
  VerifiedActivationException? lastError;
  bool forcedRefreshAfterUnverified = false;
  for (int i = 0; i < kVerifiedActivationRetryDelaysMs.length; i++) {
    final int delay = kVerifiedActivationRetryDelaysMs[i];
    if (delay > 0) {
      await (wait ?? _defaultWait)(delay);
    }
    final bool forceRefresh = lastError?.code == 'EMAIL_VERIFICATION_REQUIRED' &&
        !forcedRefreshAfterUnverified;
    if (forceRefresh) {
      forcedRefreshAfterUnverified = true;
    }
    final VerifiedActivationSession session = await reloadAndRefresh(
      forceRefresh: forceRefresh,
    );
    if (!session.emailVerified) {
      lastError = const VerifiedActivationException(
        code: 'EMAIL_VERIFICATION_REQUIRED',
        message: 'EMAIL_VERIFICATION_REQUIRED',
      );
      if (forcedRefreshAfterUnverified && i > 0) {
        break;
      }
      continue;
    }
    try {
      await provision(intendedUid ?? session.uid);
      await reloadAndRefresh(forceRefresh: true);
    } on VerifiedActivationException catch (error) {
      lastError = error;
      logTippyActivationProof(
        '[ACTIVATION_PROOF] event=provision_failed code=${error.code} '
        'httpStatus=${error.status}',
      );
      if (error.code == 'EMAIL_VERIFICATION_REQUIRED' &&
          !forcedRefreshAfterUnverified) {
        continue;
      }
      if (isRetryableVerifiedActivationFailure(
        code: error.code,
        status: error.status,
      )) {
        continue;
      }
      rethrow;
    } catch (_) {
      lastError = const VerifiedActivationException(
        code: 'PROVISION_FAILED',
      );
      if (isRetryableVerifiedActivationFailure(
        code: lastError.code,
        status: lastError.status,
      )) {
        continue;
      }
      throw lastError;
    }
    try {
      final AccountStatusSnapshot status = await getStatus();
      if (isVerifiedActivationReady(
        activationState: status.activationState,
        activationReason: status.activationReason,
        tippyStageHint: status.tippyStageHint,
        allowApp: status.allowApp,
        provisioned: status.provisioned,
      )) {
        return status;
      }
      lastError = const VerifiedActivationException();
    } on VerifiedActivationException catch (error) {
      lastError = error;
      if (isRetryableVerifiedActivationFailure(
        code: error.code,
        status: error.status,
      )) {
        continue;
      }
      rethrow;
    } catch (error) {
      lastError = _statusExceptionFrom(error);
      if (isRetryableVerifiedActivationFailure(
        code: lastError.code,
        status: lastError.status,
      )) {
        continue;
      }
      throw lastError;
    }
  }
  if (lastError?.code == 'EMAIL_VERIFICATION_REQUIRED') {
    throw lastError!;
  }
  throw lastError ?? const VerifiedActivationException();
}

Future<AccountStatusSnapshot>? _completeVerifiedActivationInFlight;

Future<AccountStatusSnapshot> completeVerifiedActivation({
  String? intendedUid,
}) {
  final Future<AccountStatusSnapshot>? existing =
      _completeVerifiedActivationInFlight;
  if (existing != null) {
    return existing;
  }
  final Future<AccountStatusSnapshot> started =
      runVerifiedActivationReconciliation(
    intendedUid: intendedUid,
    reloadAndRefresh: _reloadAndRefreshCurrentUser,
    provision: _provisionVerifiedAccount,
    getStatus: fetchAccountStatus,
  ).whenComplete(() {
    _completeVerifiedActivationInFlight = null;
  });
  _completeVerifiedActivationInFlight = started;
  return started;
}

Future<VerifiedActivationSession> _reloadAndRefreshCurrentUser({
  bool forceRefresh = false,
}) async {
  final User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw const VerifiedActivationException(
      code: 'AUTH_REQUIRED',
      message: 'AUTH_REQUIRED',
    );
  }
  await user.reload();
  await FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh);
  final User? fresh = FirebaseAuth.instance.currentUser;
  if (fresh == null) {
    throw const VerifiedActivationException(
      code: 'AUTH_REQUIRED',
      message: 'AUTH_REQUIRED',
    );
  }
  logTippyActivationProof(
        '[ACTIVATION_PROOF] event=verify_reload emailVerified=${fresh.emailVerified} '
    'forceRefresh=$forceRefresh',
  );
  return VerifiedActivationSession(
    uid: fresh.uid,
    emailVerified: fresh.emailVerified,
  );
}

Future<void> _provisionVerifiedAccount(String intendedUid) async {
  final User? user = FirebaseAuth.instance.currentUser;
  final String? idToken = await user?.getIdToken();
  if (idToken == null || idToken.isEmpty) {
    throw const VerifiedActivationException(
      code: 'AUTH_REQUIRED',
      message: 'AUTH_REQUIRED',
    );
  }
  final Map<String, String> headers = await buildAuthenticatedHttpHeaders(
    idToken: idToken,
    extra: const <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  );
  final http.Response response = await http
      .post(
        Uri.parse(siteAccountProvisionUrl()),
        headers: headers,
        body: jsonEncode(<String, dynamic>{'intendedUid': intendedUid}),
      )
      .timeout(const Duration(seconds: 25));
  Object? decoded;
  try {
    decoded = jsonDecode(response.body);
  } catch (_) {
    decoded = null;
  }
  final Map<String, dynamic> data =
      decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  logTippyActivationProof(
        '[ACTIVATION_PROOF] event=provision_response httpStatus=${response.statusCode} '
    'code=${data['code']} decision=${data['decision']}',
  );
  if (response.statusCode >= 200 && response.statusCode < 300) {
    return;
  }
  final String code = (data['code'] as String?)?.trim().isNotEmpty == true
      ? data['code'] as String
      : 'PROVISION_FAILED';
  throw VerifiedActivationException(
    code: code,
    status: response.statusCode,
    message: (data['message'] as String?)?.trim().isNotEmpty == true
        ? data['message'] as String
        : kVerifiedActivationPersistentError,
  );
}

VerifiedActivationException _statusExceptionFrom(Object error) {
  final String raw = error.toString();
  if (raw.contains('AUTH_REQUIRED')) {
    return const VerifiedActivationException(
      code: 'AUTH_REQUIRED',
      message: 'AUTH_REQUIRED',
    );
  }
  final RegExpMatch? match = RegExp(r'STATUS_FAILED:\s*(\d+)').firstMatch(raw);
  final int? status =
      match == null ? null : int.tryParse(match.group(1) ?? '');
  return VerifiedActivationException(
    code: 'STATUS_FAILED',
    status: status,
    message: kVerifiedActivationPersistentError,
  );
}

Future<void> _defaultWait(int milliseconds) {
  return Future<void>.delayed(Duration(milliseconds: milliseconds));
}
