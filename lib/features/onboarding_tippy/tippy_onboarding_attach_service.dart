import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../core/app_check_http_headers.dart';
import '../../core/backend/site_api_base.dart';
import 'tippy_onboarding_session.dart';

class TippyOnboardingAttachException implements Exception {
  const TippyOnboardingAttachException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class TippyOnboardingAttachService {
  TippyOnboardingAttachService({
    http.Client? httpClient,
    String? siteApiBase,
  })  : _client = httpClient ?? http.Client(),
        _base = resolveSiteApiBase(explicitOverride: siteApiBase);

  final http.Client _client;
  final String _base;

  Future<bool> attach(TippyOnboardingGuestSession session) async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? token = await user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw const TippyOnboardingAttachException(
        'Sign in required.',
        statusCode: 401,
      );
    }
    try {
      final Map<String, String> headers =
          await buildAuthenticatedHttpHeaders(idToken: token);
      final http.Response response = await _client
          .post(
            Uri.parse(siteApiPath('/api/tippy/onboarding/attach', base: _base)),
            headers: headers,
            body: jsonEncode(<String, dynamic>{
              'sessionId': session.sessionId,
              'answers': session.answers,
              'trialIntent': session.trialIntent,
              'notificationsChoice': session.notificationsChoice,
              'landingChoice': session.landingChoice,
            }),
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode == 401) {
        throw const TippyOnboardingAttachException(
          'Session expired. Please sign in again.',
          statusCode: 401,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TippyOnboardingAttachException(
          'Could not save onboarding (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
      return true;
    } on TippyOnboardingAttachException {
      rethrow;
    } on SocketException {
      throw const TippyOnboardingAttachException('Network unavailable.');
    } on TimeoutException {
      throw const TippyOnboardingAttachException('Request timed out.');
    } on FormatException {
      throw const TippyOnboardingAttachException('Invalid attach response.');
    }
  }

  void dispose() {
    _client.close();
  }
}
