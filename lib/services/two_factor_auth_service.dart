import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_check_http_headers.dart';
import '../core/backend/site_api_base.dart';

const Duration _kTwoFactorTimeout = Duration(seconds: 30);

class TwoFactorApiException implements Exception {
  const TwoFactorApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class TwoFactorSetupSecret {
  const TwoFactorSetupSecret({required this.secret, required this.otpauthUrl});

  final String secret;
  final String otpauthUrl;
}

/// 2FA secrets and backup codes live server-side at
/// `users/{uid}/security/twoFactor`; all mutations go through
/// `/api/two-factor/*` (same contract as the website).
class TwoFactorAuthService {
  TwoFactorAuthService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<Map<String, dynamic>> _post(
    String action, [
    Map<String, dynamic> body = const <String, dynamic>{},
  ]) =>
      _send(action, body: body);

  Future<Map<String, dynamic>> _send(
    String action, {
    Map<String, dynamic>? body,
  }) async {
    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const TwoFactorApiException('Sign in again to continue.');
    }
    final String? idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const TwoFactorApiException('Session expired. Sign in again.');
    }
    final Map<String, String> headers = await buildAuthenticatedHttpHeaders(
      idToken: idToken,
      extra: const <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
    final Uri uri = Uri.parse(siteTwoFactorUrl(action));
    final http.Client client = _client ?? http.Client();
    try {
      final http.Response response = body == null
          ? await client.get(uri, headers: headers).timeout(_kTwoFactorTimeout)
          : await client
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(_kTwoFactorTimeout);
      final Map<String, dynamic> data = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      }
      throw TwoFactorApiException(
        data['error'] is String
            ? data['error'] as String
            : 'Two-factor request failed.',
        statusCode: response.statusCode,
      );
    } finally {
      if (_client == null) client.close();
    }
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return <String, dynamic>{};
  }

  /// Starts authenticator setup; the server stores the pending secret.
  Future<TwoFactorSetupSecret> startAuthenticatorSetup({
    required String email,
  }) async {
    final Map<String, dynamic> data = await _post('generate');
    final String secret = (data['manualEntryKey'] ?? data['secret'] ?? '')
        .toString();
    if (secret.isEmpty) {
      throw const TwoFactorApiException('Could not start 2FA setup.');
    }
    final String label = Uri.encodeComponent('StreamersTip:$email');
    return TwoFactorSetupSecret(
      secret: secret,
      otpauthUrl:
          'otpauth://totp/$label?secret=$secret&issuer=StreamersTip',
    );
  }

  /// Confirms setup with a TOTP code; returns one-time backup codes.
  Future<List<String>> confirmAuthenticatorSetup(String code) async {
    final Map<String, dynamic> data =
        await _post('verify', <String, dynamic>{'token': code.trim()});
    if (data['success'] != true) {
      throw const TwoFactorApiException('Invalid code. Please try again.');
    }
    final Object? codes = data['backupCodes'];
    return codes is List ? codes.map((Object? c) => '$c').toList() : <String>[];
  }

  /// Disables 2FA. Requires a current authenticator or backup code.
  Future<bool> disable2FA(String userId, {required String code}) async {
    await _post('disable', <String, dynamic>{'code': code.trim()});
    return true;
  }

  Future<Map<String, dynamic>?> get2FAStatus(String userId) async {
    try {
      final Map<String, dynamic> data = await _send('status');
      return <String, dynamic>{
        'enabled': data['enabled'] == true,
        'verified': data['verified'] == true,
        'hasSecret': data['hasSecret'] == true,
        'sessionVerified': data['sessionVerified'] != false,
        'method': data['method'],
        'backupCodesRemaining': data['backupCodesRemaining'] ?? 0,
      };
    } catch (e) {
      debugPrint('❌ Failed to get 2FA status: $e');
      return null;
    }
  }

  /// Verifies a TOTP code or a one-time backup code server-side.
  Future<bool> verify2FACode({
    required String userId,
    required String code,
  }) async {
    try {
      final Map<String, dynamic> data =
          await _post('challenge', <String, dynamic>{'token': code.trim()});
      return data['success'] == true;
    } on TwoFactorApiException catch (e) {
      if (e.statusCode == 400) return false;
      rethrow;
    }
  }

  Future<bool> verifyBackupCode({
    required String userId,
    required String code,
  }) =>
      verify2FACode(userId: userId, code: code);

  /// True when this sign-in (server `auth_time`) still needs a 2FA code.
  /// Fails closed: if the server status is unavailable, accounts with the
  /// server-written `twoFactorVerified` flag are still challenged.
  Future<bool> isSessionChallengeRequired(String userId) async {
    final Map<String, dynamic>? status = await get2FAStatus(userId);
    if (status == null) return requires2FA(userId);
    return status['verified'] == true &&
        status['hasSecret'] == true &&
        status['sessionVerified'] == false;
  }

  Future<bool> requires2FA(String userId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final Map<String, dynamic>? data = doc.data();
      return data?['twoFactorVerified'] == true;
    } catch (e) {
      debugPrint('❌ Failed to read 2FA flag: $e');
      return false;
    }
  }
}
