import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../core/app_check_http_headers.dart';
import '../../core/backend/site_api_base.dart';
import '../../services/production_monitoring_service.dart';
import 'billing_backend_config.dart';
import 'mobile_purchase_verification_payload.dart';

class MobilePurchaseVerificationException implements Exception {
  const MobilePurchaseVerificationException(this.message);

  final String message;

  @override
  String toString() => 'MobilePurchaseVerificationException: $message';
}

class MobilePurchaseVerificationClient {
  MobilePurchaseVerificationClient({
    this.httpClient,
    String? siteApiBase,
    String? legacyVerifyUrl,
  })  : _siteApiBase = resolveSiteApiBase(explicitOverride: siteApiBase),
        _legacyVerifyUrl = (legacyVerifyUrl ?? kMobileBillingVerifyUrl).trim();

  final http.Client? httpClient;
  final String _siteApiBase;
  final String _legacyVerifyUrl;

  bool get hasSiteVerify => _siteApiBase.isNotEmpty;

  bool get hasLegacyVerify => _legacyVerifyUrl.isNotEmpty;

  Future<void> submitPurchase({
    required MobilePurchaseVerificationPayload payload,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const MobilePurchaseVerificationException(
        'You must be signed in to complete a subscription purchase.',
      );
    }
    final String? idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const MobilePurchaseVerificationException(
        'Could not read Firebase ID token.',
      );
    }
    if (hasSiteVerify) {
      try {
        await _postVerify(
          uri: _siteVerifyUri(payload),
          idToken: idToken,
          body: payload.toSiteApiJson(),
        );
        return;
      } on MobilePurchaseVerificationException catch (e) {
        if (!hasLegacyVerify || e.message.contains('404')) {
          rethrow;
        }
      }
    }
    if (!hasLegacyVerify) {
      throw const MobilePurchaseVerificationException(
        'Billing verify URL is not configured. Set SITE_API_BASE or '
        'MOBILE_BILLING_VERIFY_URL.',
      );
    }
    await _postVerify(
      uri: Uri.parse(_legacyVerifyUrl),
      idToken: idToken,
      body: payload.toLegacyCloudFunctionJson(),
    );
  }

  Uri _siteVerifyUri(MobilePurchaseVerificationPayload payload) {
    final String url = payload.isIos
        ? siteAppleBillingVerifyUrl(base: _siteApiBase)
        : siteGoogleBillingVerifyUrl(base: _siteApiBase);
    return Uri.parse(url);
  }

  Future<void> _postVerify({
    required Uri uri,
    required String idToken,
    required Map<String, dynamic> body,
  }) async {
    final http.Client client = httpClient ?? http.Client();
    final bool ownsClient = httpClient == null;
    try {
      final Map<String, String> headers =
          await buildAuthenticatedHttpHeaders(
        idToken: idToken,
        extra: const <String, String>{'Content-Type': 'application/json'},
      );
      final http.Response response = await client.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await ProductionMonitoringService.instance.recordHttpFailure(
          endpoint: 'verify_mobile_purchase',
          statusCode: response.statusCode,
        );
        throw MobilePurchaseVerificationException(
          'Verification failed (${response.statusCode}): ${response.body}',
        );
      }
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }
}
