import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/backend/firebase_https_function_url.dart';
import '../features/entitlements/me_entitlements_models.dart';

typedef MeEntitlementsTokenProvider = Future<String?> Function();

class MeEntitlementsException implements Exception {
  const MeEntitlementsException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MeEntitlementsService {
  MeEntitlementsService({
    String? apiBase,
    http.Client? httpClient,
    MeEntitlementsTokenProvider? tokenProvider,
    Duration requestTimeout = _defaultTimeout,
  })  : _apiBase = resolveFirebaseHttpsFunctionUrl(
          explicitOverride: apiBase,
          envDefineValue: _envApiBase,
          functionName: _httpFunctionName,
          region: _functionsRegion,
        ),
        _client = httpClient ?? http.Client(),
        _tokenProvider = tokenProvider,
        _requestTimeout = requestTimeout;

  static const String _envApiBase = String.fromEnvironment(
    'ME_ENTITLEMENTS_API_BASE',
    defaultValue: '',
  );
  static const Duration _defaultTimeout = Duration(seconds: 20);
  static const String _functionsRegion = 'us-central1';
  static const String _httpFunctionName = 'meEntitlements';

  final String _apiBase;
  final http.Client _client;
  final MeEntitlementsTokenProvider? _tokenProvider;
  final Duration _requestTimeout;

  bool get hasApiBase => _apiBase.trim().isNotEmpty;

  Future<MeEntitlementsData> fetchCurrentUserEntitlements() async {
    if (!hasApiBase) {
      if (kDebugMode) {
        debugPrint('MeEntitlementsService: no API base configured');
      }
      throw const MeEntitlementsException(
          'Entitlements API is not configured.');
    }
    final String? idToken = await _resolveIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const MeEntitlementsException('You are not signed in.');
    }
    final Uri uri = _buildUri('');
    final Map<String, String> headers = <String, String>{
      'Authorization': 'Bearer $idToken',
    };
    try {
      final http.Response response =
          await _client.get(uri, headers: headers).timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (kDebugMode) {
          debugPrint(
            'MeEntitlementsService: HTTP ${response.statusCode} '
            '${response.body}',
          );
        }
        throw MeEntitlementsException(
          'Entitlements request failed (${response.statusCode}).',
        );
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const MeEntitlementsException('Invalid entitlements response.');
      }
      if (decoded['success'] != true) {
        throw const MeEntitlementsException('Entitlements were not granted.');
      }
      final MeEntitlementsData out =
          MeEntitlementsData.fromResponseJson(decoded);
      if (kDebugMode) {
        debugPrint(
          'MeEntitlementsService: uid=${out.uid} tier=${out.tier} '
          'source=${out.tierSource} status=${out.subscriptionStatus} '
          'tippyEnabled=${out.tippyAi.enabled}',
        );
      }
      return out;
    } on MeEntitlementsException {
      rethrow;
    } on SocketException {
      throw const MeEntitlementsException(
        'Network unavailable. Check your connection and try again.',
      );
    } on TimeoutException {
      throw const MeEntitlementsException(
        'The request timed out. Try again.',
      );
    } on FormatException {
      throw const MeEntitlementsException('Invalid entitlements response.');
    }
  }

  Uri _buildUri(String suffix) {
    final String b = _apiBase.replaceAll(RegExp(r'/$'), '');
    final String s = suffix.startsWith('/') ? suffix : '/$suffix';
    if (s == '/') {
      return Uri.parse(b);
    }
    return Uri.parse('$b$s');
  }

  Future<String?> _resolveIdToken() async {
    if (_tokenProvider != null) {
      return _tokenProvider!.call();
    }
    final User? user = FirebaseAuth.instance.currentUser;
    return user?.getIdToken(true);
  }

  void dispose() {
    _client.close();
  }
}
