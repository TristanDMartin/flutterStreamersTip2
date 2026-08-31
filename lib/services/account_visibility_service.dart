import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_check_http_headers.dart';
import '../core/backend/site_api_base.dart';
import 'account_deletion_service.dart';

class AccountVisibilityResult {
  const AccountVisibilityResult({
    required this.ok,
    this.message,
  });

  final bool ok;
  final String? message;
}

/// Canonical deactivate / reactivate HTTP routes shared with web.
class AccountVisibilityService {
  AccountVisibilityService({
    http.Client? httpClient,
    String? siteApiBase,
  })  : _client = httpClient ?? http.Client(),
        _base = resolveSiteApiBase(explicitOverride: siteApiBase);

  final http.Client _client;
  final String _base;

  Future<AccountVisibilityResult> deactivateCurrentAccount() {
    return _postVisibility(
      url: siteAccountDeactivateUrl(base: _base),
      action: 'deactivate',
    );
  }

  Future<AccountVisibilityResult> reactivateCurrentAccount() {
    return _postVisibility(
      url: siteAccountReactivateUrl(base: _base),
      action: 'reactivate',
    );
  }

  Future<AccountVisibilityResult> _postVisibility({
    required String url,
    required String action,
  }) async {
    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const AccountVisibilityResult(
        ok: false,
        message: 'No signed-in account found.',
      );
    }
    Object? lastError;
    for (int attempt = 0; attempt < 3; attempt += 1) {
      try {
        final String? idToken = await user.getIdToken(attempt > 0);
        if (idToken == null || idToken.isEmpty) {
          return const AccountVisibilityResult(
            ok: false,
            message: 'Session expired. Please sign in again.',
          );
        }
        final Map<String, String> headers = await buildAuthenticatedHttpHeaders(
          idToken: idToken,
          extra: const <String, String>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        );
        final http.Response response = await _client
            .post(
              Uri.parse(url),
              headers: headers,
              body: jsonEncode(<String, dynamic>{}),
            )
            .timeout(const Duration(seconds: 60));
        final Map<String, dynamic> body =
            decodeAccountDeleteJson(response.body);
        final Map<String, dynamic> data = unwrapAccountDeletePayload(body);
        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            data['ok'] == true) {
          return const AccountVisibilityResult(ok: true);
        }
        lastError = accountDeleteErrorMessage(
          statusCode: response.statusCode,
          body: body,
        );
        if (!isRetryableAccountDeleteStatus(response.statusCode) ||
            attempt == 2) {
          return AccountVisibilityResult(
            ok: false,
            message: lastError.toString(),
          );
        }
      } catch (e) {
        lastError = e;
        debugPrint('⚠️ AccountVisibilityService $action failed: $e');
        if (attempt == 2) {
          return AccountVisibilityResult(
            ok: false,
            message: e.toString(),
          );
        }
      }
      await Future<void>.delayed(
        Duration(milliseconds: 400 * (attempt + 1)),
      );
    }
    return AccountVisibilityResult(
      ok: false,
      message: lastError?.toString() ?? 'Account $action failed.',
    );
  }
}
