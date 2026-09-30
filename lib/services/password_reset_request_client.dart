import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/backend/site_api_base.dart';
import '../core/firebase_app_check_startup.dart';

const String _kDefaultResetErrorMessage =
    'Unable to send reset email right now. Try again later.';

class PasswordResetRequestException implements Exception {
  const PasswordResetRequestException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => message;
}

/// Sends the branded StreamersTip reset email. The link opens
/// streamerstip.com/reset-password (never the firebaseapp.com handler).
Future<void> requestSitePasswordReset(
  String identifier, {
  http.Client? client,
}) async {
  final Map<String, String> headers = <String, String>{
    'Content-Type': 'application/json',
  };
  try {
    final String? appCheckToken = await fetchAppCheckHttpToken();
    if (appCheckToken != null && appCheckToken.isNotEmpty) {
      headers['X-Firebase-AppCheck'] = appCheckToken;
    }
  } catch (_) {
    // Reset is unauthenticated; send without App Check rather than fail.
  }
  final Uri uri = Uri.parse(sitePasswordResetRequestUrl());
  final String body = jsonEncode(<String, String>{
    'identifier': identifier.trim(),
  });
  final http.Response response = client != null
      ? await client.post(uri, headers: headers, body: body)
      : await http.post(uri, headers: headers, body: body);
  if (response.statusCode >= 200 && response.statusCode < 300) return;
  throw PasswordResetRequestException(
    _readErrorMessage(response.body),
    statusCode: response.statusCode,
  );
}

String _readErrorMessage(String body) {
  try {
    final Object? decoded = jsonDecode(body);
    if (decoded is Map && decoded['error'] is String) {
      final String message = (decoded['error'] as String).trim();
      if (message.isNotEmpty) return message;
    }
  } catch (_) {}
  return _kDefaultResetErrorMessage;
}
