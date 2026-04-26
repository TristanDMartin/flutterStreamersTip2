import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'billing_backend_config.dart';
import 'mobile_purchase_verification_payload.dart';

class MobilePurchaseVerificationException implements Exception {
  const MobilePurchaseVerificationException(this.message);

  final String message;

  @override
  String toString() => 'MobilePurchaseVerificationException: $message';
}

class MobilePurchaseVerificationClient {
  const MobilePurchaseVerificationClient({this.httpClient});

  final http.Client? httpClient;

  Future<void> submitPurchase({
    required MobilePurchaseVerificationPayload payload,
  }) async {
    final String trimmed = kMobileBillingVerifyUrl.trim();
    if (trimmed.isEmpty) {
      throw const MobilePurchaseVerificationException(
        'MOBILE_BILLING_VERIFY_URL is not set. '
        'Add --dart-define=MOBILE_BILLING_VERIFY_URL=... at build time.',
      );
    }
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
    final http.Client client = httpClient ?? http.Client();
    final bool ownsClient = httpClient == null;
    try {
      final http.Response response = await client.post(
        Uri.parse(trimmed),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(payload.toJson()),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
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
