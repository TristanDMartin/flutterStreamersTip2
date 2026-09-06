import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/app_check_http_headers.dart';
import '../../core/backend/site_api_base.dart';
import 'email_verification.dart';
import 'email_verification_intent_store.dart';

const String kEmailVerificationOrigin = String.fromEnvironment(
  'EMAIL_VERIFICATION_ORIGIN',
);

String resolveAppEmailVerificationOrigin({
  String configuredOrigin = kEmailVerificationOrigin,
  bool isDebug = kDebugMode,
  bool isWeb = kIsWeb,
  String? webOrigin,
  String? siteApiBase,
}) {
  final String override = configuredOrigin.trim();
  if (override.isNotEmpty) {
    if (!isDebug && isLocalVerificationOrigin(override)) {
      return resolveVerificationContinueOrigin(
        kProductionEmailVerificationOrigin,
      );
    }
    return resolveVerificationContinueOrigin(override);
  }
  if (isDebug) {
    if (isWeb) {
      final String origin = (webOrigin ?? Uri.base.origin).trim();
      if (isAllowedVerificationOrigin(origin)) {
        return origin;
      }
    }
    return resolveVerificationContinueOrigin('http://localhost:3000');
  }
  final String site = resolveSiteApiBase(explicitOverride: siteApiBase);
  if (isLocalVerificationOrigin(site)) {
    return resolveVerificationContinueOrigin(
      kProductionEmailVerificationOrigin,
    );
  }
  return resolveVerificationContinueOrigin(site);
}

String siteEmailVerificationSendUrl({String? base}) =>
    siteApiPath('/api/auth/email-verification/send', base: base);

Future<void> _sendClientFirebaseVerification({
  required User user,
  required EmailVerificationIntent intent,
  String? resumePath,
}) async {
  await user.sendEmailVerification(
    ActionCodeSettings(
      url: buildEmailVerificationContinueUrl(
        origin: intent.origin,
        intentUid: intent.uid,
        resumePath: resumePath,
      ),
      handleCodeInApp: false,
    ),
  );
}

/// Prefer branded StreamersTip Resend path; Firebase client send is
/// local/dev fallback only when the server returns `client_fallback`.
Future<EmailVerificationIntent> sendBoundEmailVerification({
  required User user,
  String? onboardingSessionId,
  String? resumePath,
}) async {
  final String? email = user.email;
  if (email == null || email.isEmpty) {
    throw StateError('VERIFICATION_EMAIL_REQUIRED');
  }
  final EmailVerificationIntent intent = createEmailVerificationIntent(
    uid: user.uid,
    email: email,
    origin: resolveAppEmailVerificationOrigin(),
    onboardingSessionId: onboardingSessionId,
  );
  await EmailVerificationIntentStore.save(intent);
  final String resume = (resumePath ?? '').trim().isNotEmpty
      ? resumePath!.trim()
      : '/onboarding';

  try {
    final String? idToken = await user.getIdToken();
    if (idToken != null && idToken.isNotEmpty) {
      final Map<String, String> headers = await buildAuthenticatedHttpHeaders(
        idToken: idToken,
        extra: const <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      final http.Response response = await http
          .post(
            Uri.parse(siteEmailVerificationSendUrl()),
            headers: headers,
            body: jsonEncode(<String, Object?>{
              'resumePath': resume,
              'origin': intent.origin,
              'onboardingSessionId': onboardingSessionId,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Object? decoded = jsonDecode(response.body);
        final Map<String, dynamic> data =
            decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
        final String mode = (data['mode'] as String?)?.trim() ?? '';
        if (mode == 'branded') {
          return intent;
        }
        if (mode == 'client_fallback') {
          await _sendClientFirebaseVerification(
            user: user,
            intent: intent,
            resumePath: resume,
          );
          return intent;
        }
      }
    }
  } catch (error) {
    debugPrint('Branded verification send soft-fail: $error');
  }

  if (kDebugMode) {
    await _sendClientFirebaseVerification(
      user: user,
      intent: intent,
      resumePath: resume,
    );
    return intent;
  }
  throw StateError('VERIFICATION_EMAIL_SEND_FAILED');
}

Future<VerificationIdentityResult> confirmBoundEmailVerification({
  required String intendedUid,
  required String intendedEmail,
}) async {
  final User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return const VerificationIdentityResult(
      status: VerificationIdentityStatus.signedOut,
    );
  }
  await user.reload();
  final User? fresh = FirebaseAuth.instance.currentUser;
  return evaluateVerificationIdentity(
    intendedUid: intendedUid,
    intendedEmail: intendedEmail,
    currentUid: fresh?.uid,
    currentEmail: fresh?.email,
    emailVerified: fresh?.emailVerified == true,
  );
}
