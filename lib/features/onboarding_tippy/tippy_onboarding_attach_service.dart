import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/app_check_http_headers.dart';
import '../../core/backend/site_api_base.dart';
import '../tippy/tippy_brain_contract.dart';
import 'tippy_onboarding_session.dart';

class TippyOnboardingAttachException implements Exception {
  const TippyOnboardingAttachException(
    this.message, {
    this.statusCode,
    this.code,
  });

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

class TippyOnboardingAttachResult {
  const TippyOnboardingAttachResult({
    required this.ok,
    this.activationState,
    this.allowApp = false,
    this.firstGrowthPlanId,
  });

  final bool ok;
  final String? activationState;
  final bool allowApp;
  final String? firstGrowthPlanId;

  bool get isActivated => activationState == 'ACTIVATED' || allowApp;
}

bool isStaleOnboardingAttach({
  int? statusCode,
  String? code,
  String? message,
}) {
  if (statusCode == 409) {
    return true;
  }
  final String haystack = '${code ?? ''} ${message ?? ''}'.toUpperCase();
  return haystack.contains('STALE_ONBOARDING_SESSION');
}

bool shouldRetryStaleOnboardingAttach({
  required int statusCode,
  required bool startedFromWelcomeAlreadySent,
}) {
  return statusCode == 409 && !startedFromWelcomeAlreadySent;
}

class TippyOnboardingAttachService {
  TippyOnboardingAttachService({
    http.Client? httpClient,
    String? siteApiBase,
  })  : _injectedClient = httpClient,
        _base = resolveSiteApiBase(explicitOverride: siteApiBase);

  final http.Client? _injectedClient;
  final String _base;

  Future<http.Response> _post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) {
    final http.Client? injected = _injectedClient;
    if (injected != null) {
      return injected.post(uri, headers: headers, body: body);
    }
    return http.post(uri, headers: headers, body: body);
  }

  Future<TippyOnboardingAttachResult> attach(
    TippyOnboardingGuestSession session, {
    bool startedFromWelcome = false,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? token = await user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw const TippyOnboardingAttachException(
        'Sign in required.',
        statusCode: 401,
      );
    }
    final String guestSessionId = session.sessionId.trim();
    if (guestSessionId.isEmpty) {
      throw const TippyOnboardingAttachException(
        'sessionId is required',
        statusCode: 400,
        code: 'SESSION_REQUIRED',
      );
    }
    try {
      final Map<String, String> headers = await buildAuthenticatedHttpHeaders(
        idToken: token,
        extra: const <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      final String firstMissionChoice = session.firstMissionChoice ??
          (session.landingChoice == 'recommended'
              ? 'accept'
              : session.landingChoice == 'explore'
                  ? 'skip'
                  : '');
      Map<String, dynamic> payloadFor(
        String sessionId, {
        required bool welcomeFlag,
      }) {
        return <String, dynamic>{
          'sessionId': sessionId,
          'answers': session.answers,
          'trialIntent': session.trialIntent,
          'notificationsChoice': session.notificationsChoice,
          'twitchConnectionStatus': session.twitchConnectionStatus,
          'landingChoice': session.landingChoice,
          'firstMissionChoice':
              firstMissionChoice.isEmpty ? null : firstMissionChoice,
          'startedFromWelcome': welcomeFlag,
          'startedAt': session.startedAt.toIso8601String(),
          'firstResultAt': session.firstResultAt?.toIso8601String(),
          'platform': 'mobile',
          'checkupGuest': checkupGuestForBrainAttach(
            sessionId: session.sessionId,
            startedFromCheckup: session.startedFromCheckup,
            checkupSessionId: session.checkupSessionId,
            checkupProfiles: session.checkupProfiles,
            checkupConfirmedAnswers: session.checkupConfirmedAnswers,
            answers: session.answers,
            checkupPresenceSummary: session.checkupPresenceSummary,
          ),
        };
      }

      Future<http.Response> postAttach(
        String sessionId, {
        required bool welcomeFlag,
      }) async {
        debugPrint(
          '[ATTACH_REQUEST] sessionIdSent=$sessionId '
          'guestSessionId=$guestSessionId '
          'startedFromWelcome=$welcomeFlag '
          'landingChoice=${session.landingChoice} '
          'firstMissionChoice=${firstMissionChoice.isEmpty ? null : firstMissionChoice}',
        );
        return _post(
              Uri.parse(
                siteApiPath('/api/tippy/onboarding/attach', base: _base),
              ),
              headers: headers,
              body: jsonEncode(
                payloadFor(sessionId, welcomeFlag: welcomeFlag),
              ),
            )
            .timeout(const Duration(seconds: 25));
      }

      void logAttachResponse(
        http.Response response,
        Map<String, dynamic> data, {
        String? extra,
      }) {
        debugPrint(
          '[ATTACH_RESPONSE] httpStatus=${response.statusCode} '
          'code=${data['code']} error=${data['error'] ?? data['message']} '
          'keys=${data.keys.join(',')} '
          'activationState=${data['activationState']} '
          'allowApp=${data['allowApp']} '
          'serverExpectedSessionId=${data['serverExpectedSessionId']} '
          'serverReceivedSessionId=${data['serverReceivedSessionId']}'
          '${extra == null ? '' : ' $extra'}',
        );
      }

      bool welcomeFlag = startedFromWelcome;
      http.Response response = await postAttach(
        guestSessionId,
        welcomeFlag: welcomeFlag,
      );
      Map<String, dynamic> data = _decodeJsonMap(response.body);
      logAttachResponse(response, data);
      final String expected =
          (data['serverExpectedSessionId'] as String? ?? '').trim();
      String activeSessionId = guestSessionId;
      if (response.statusCode == 409 &&
          expected.isNotEmpty &&
          expected != guestSessionId) {
        activeSessionId = expected;
        response = await postAttach(
          expected,
          welcomeFlag: welcomeFlag,
        );
        data = _decodeJsonMap(response.body);
        logAttachResponse(response, data, extra: 'retriedSessionId=$expected');
      }
      if (shouldRetryStaleOnboardingAttach(
        statusCode: response.statusCode,
        startedFromWelcomeAlreadySent: welcomeFlag,
      )) {
        welcomeFlag = true;
        response = await postAttach(
          activeSessionId,
          welcomeFlag: welcomeFlag,
        );
        data = _decodeJsonMap(response.body);
        logAttachResponse(
          response,
          data,
          extra: 'staleRetry startedFromWelcome=true',
        );
      }
      if (response.statusCode == 401) {
        throw const TippyOnboardingAttachException(
          'Session expired. Please sign in again.',
          statusCode: 401,
        );
      }
      if (response.statusCode == 409) {
        throw TippyOnboardingAttachException(
          (data['error'] as String?) ?? 'STALE_ONBOARDING_SESSION',
          statusCode: 409,
          code: (data['code'] as String?) ?? 'STALE_ONBOARDING_SESSION',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TippyOnboardingAttachException(
          (data['error'] as String?) ??
              (data['message'] as String?) ??
              'Could not save onboarding (${response.statusCode}).',
          statusCode: response.statusCode,
          code: data['code'] as String?,
        );
      }
      return parseTippyOnboardingAttachPayload(data);
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

  void dispose() {}
}

Map<String, dynamic> _decodeJsonMap(String body) {
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

Map<String, dynamic> _asStringKeyedMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  return <String, dynamic>{};
}

bool _readAllowApp(Object? value) {
  if (value == true || value == 1) {
    return true;
  }
  if (value is String) {
    return value.trim().toLowerCase() == 'true';
  }
  return false;
}

/// Cloud Functions / Next adapters may nest the attach payload.
TippyOnboardingAttachResult parseTippyOnboardingAttachPayload(
  Map<String, dynamic> raw,
) {
  Map<String, dynamic> data = raw;
  for (final String key in <String>['data', 'result', 'payload']) {
    final Map<String, dynamic> nested = _asStringKeyedMap(data[key]);
    if (nested.containsKey('activationState') ||
        nested.containsKey('allowApp') ||
        nested.containsKey('success') ||
        nested.containsKey('attached')) {
      data = nested;
      break;
    }
  }
  final String? activationState = data['activationState'] as String?;
  final bool allowApp = _readAllowApp(data['allowApp']);
  final bool ok = data['success'] == true ||
      data['attached'] == true ||
      data['ok'] == true ||
      activationState != null ||
      allowApp;
  return TippyOnboardingAttachResult(
    ok: ok,
    activationState: activationState,
    allowApp: allowApp,
    firstGrowthPlanId: data['firstGrowthPlanId'] as String?,
  );
}
