import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/app_check_http_headers.dart';
import '../core/backend/site_api_base.dart';
import '../features/onboarding_tippy/tippy_onboarding_session.dart';
import 'account_local_data_teardown.dart';
import 'robust_auth_service.dart';
import 'tiktok_account_switcher.dart';
import '../utils/user_facing_error.dart';

enum AccountDeletionOutcome {
  success,
  cancelled,
  failed,
}

class AccountDeletionResult {
  const AccountDeletionResult({
    required this.outcome,
    this.message,
  });

  final AccountDeletionOutcome outcome;
  final String? message;

  bool get isSuccess => outcome == AccountDeletionOutcome.success;
}

const Set<int> kRetryableAccountDeleteStatuses = <int>{404, 502, 503};

bool isRetryableAccountDeleteStatus(int status) =>
    kRetryableAccountDeleteStatuses.contains(status);

Map<String, dynamic> decodeAccountDeleteJson(String body) {
  if (body.trim().isEmpty) {
    return <String, dynamic>{};
  }
  try {
    final Object? decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
  } catch (_) {}
  return <String, dynamic>{};
}

Map<String, dynamic> unwrapAccountDeletePayload(Map<String, dynamic> raw) {
  Map<String, dynamic> data = raw;
  for (final String key in <String>['data', 'result', 'payload']) {
    final Object? nested = data[key];
    if (nested is Map) {
      final Map<String, dynamic> map = nested is Map<String, dynamic>
          ? nested
          : nested.cast<String, dynamic>();
      if (map.containsKey('ok') ||
          map.containsKey('deletedAuth') ||
          map.containsKey('alreadyDeleted')) {
        data = map;
        break;
      }
    }
  }
  return data;
}

bool isCanonicalAccountDeleteSuccess({
  required int statusCode,
  required Map<String, dynamic> body,
}) {
  if (statusCode < 200 || statusCode >= 300) {
    return false;
  }
  final Map<String, dynamic> data = unwrapAccountDeletePayload(body);
  return data['ok'] == true || data['alreadyDeleted'] == true;
}

String accountDeleteErrorMessage({
  required int statusCode,
  required Map<String, dynamic> body,
}) {
  final Map<String, dynamic> data = unwrapAccountDeletePayload(body);
  final String fromBody = ((data['message'] as String?) ??
          (data['error'] as String?) ??
          (data['code'] as String?) ??
          '')
      .trim();
  if (fromBody.isNotEmpty) {
    return fromBody;
  }
  if (statusCode == 404) {
    return 'Could not reach account deletion. Please try again.';
  }
  return 'Account deletion failed ($statusCode).';
}

/// Deletes the signed-in account via the canonical website HTTP route
/// (`POST /api/account/delete`) shared with web. Do not use a callable.
/// App Check is optional, matching web `deleteAccountClient`.
class AccountDeletionService {
  AccountDeletionService({
    http.Client? httpClient,
    String? siteApiBase,
  })  : _client = httpClient ?? http.Client(),
        _base = resolveSiteApiBase(explicitOverride: siteApiBase);

  final http.Client _client;
  final String _base;

  Future<AccountDeletionResult> deleteCurrentAccount({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const AccountDeletionResult(
        outcome: AccountDeletionOutcome.failed,
        message: 'No signed-in account found.',
      );
    }
    final String userId = user.uid;
    final RobustAuthenticationService authService =
        ref.read(robustAuthServiceProvider);
    bool cloudDeleteSucceeded = false;
    try {
      await _postCanonicalDelete(user);
      cloudDeleteSucceeded = true;
    } catch (e) {
      debugPrint('❌ AccountDeletionService cloud delete failed: $e');
      final bool authAlreadyGone =
          firebase_auth.FirebaseAuth.instance.currentUser == null;
      if (!authAlreadyGone) {
        return AccountDeletionResult(
          outcome: AccountDeletionOutcome.failed,
          message: UserFacingError.message(e),
        );
      }
      cloudDeleteSucceeded = true;
      debugPrint(
        '⚠️ AccountDeletionService: treating as success — Auth user already gone',
      );
    }
    if (!cloudDeleteSucceeded) {
      return const AccountDeletionResult(
        outcome: AccountDeletionOutcome.failed,
        message: 'Account deletion failed.',
      );
    }
    try {
      await TippyOnboardingSessionStore().invalidateAfterAccountDeletion();
    } catch (e) {
      debugPrint('⚠️ AccountDeletionService tippy invalidate: $e');
    }
    await AccountLocalDataTeardown.executeAfterAccountDeletion(
      userId: userId,
    );
    try {
      final TikTokAccountSwitcher accountSwitcher = TikTokAccountSwitcher();
      await accountSwitcher.initialize();
      await accountSwitcher.removeAccountByUid(userId);
    } catch (e) {
      debugPrint('⚠️ AccountDeletionService saved-account cleanup: $e');
    }
    await _signOutAfterDeletion(authService);
    try {
      await TippyOnboardingSessionStore().invalidateAfterAccountDeletion();
    } catch (e) {
      debugPrint('⚠️ AccountDeletionService tippy re-invalidate: $e');
    }
    return const AccountDeletionResult(
      outcome: AccountDeletionOutcome.success,
      message: 'Account deleted successfully',
    );
  }

  Future<void> _postCanonicalDelete(firebase_auth.User user) async {
    const int maxAttempts = 3;
    Object? lastError;
    for (int attempt = 0; attempt < maxAttempts; attempt += 1) {
      final String? idToken = await user.getIdToken(attempt > 0);
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Session expired. Please sign in again.');
      }
      final Map<String, String> headers = await buildAuthenticatedHttpHeaders(
        idToken: idToken,
        extra: const <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      debugPrint(
        '[ACCOUNT_DELETE_REQUEST] attempt=${attempt + 1} '
        'hasAppCheck=${headers.containsKey('X-Firebase-AppCheck')}',
      );
      final http.Response response = await _client
          .post(
            Uri.parse(siteAccountDeleteUrl(base: _base)),
            headers: headers,
            body: jsonEncode(<String, dynamic>{'confirmation': 'DELETE'}),
          )
          .timeout(const Duration(seconds: 60));
      final Map<String, dynamic> body = decodeAccountDeleteJson(response.body);
      final Map<String, dynamic> data = unwrapAccountDeletePayload(body);
      debugPrint(
        '[ACCOUNT_DELETE_RESPONSE] httpStatus=${response.statusCode} '
        'ok=${data['ok']} code=${data['code']} '
        'deletedAuth=${data['deletedAuth']} '
        'alreadyDeleted=${data['alreadyDeleted']}',
      );
      if (isCanonicalAccountDeleteSuccess(
        statusCode: response.statusCode,
        body: body,
      )) {
        return;
      }
      lastError = Exception(
        accountDeleteErrorMessage(
          statusCode: response.statusCode,
          body: body,
        ),
      );
      if (!isRetryableAccountDeleteStatus(response.statusCode) ||
          attempt == maxAttempts - 1) {
        throw lastError;
      }
      await Future<void>.delayed(
        Duration(milliseconds: 400 * (attempt + 1)),
      );
    }
    throw lastError ?? Exception('Account deletion failed.');
  }

  Future<void> _signOutAfterDeletion(
    RobustAuthenticationService authService,
  ) async {
    try {
      await authService.signOut();
    } catch (e) {
      debugPrint('⚠️ AccountDeletionService auth service sign-out: $e');
    }
  }
}
