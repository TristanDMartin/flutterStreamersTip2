import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/app_check_http_headers.dart';
import '../../core/backend/firebase_https_function_url.dart';
import '../../core/backend/site_api_base.dart';
import '../../services/production_monitoring_service.dart';
import 'models/subscription_snapshot.dart';

typedef SubscriptionTokenProvider = Future<String?> Function();

class SubscriptionRepositoryException implements Exception {
  const SubscriptionRepositoryException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Fetches `/api/user/entitlements` — single source for tier limits and gates.
class SubscriptionRepository {
  SubscriptionRepository({
    String? siteApiBase,
    String? legacyCloudFunctionBase,
    http.Client? httpClient,
    SubscriptionTokenProvider? tokenProvider,
    Duration requestTimeout = const Duration(seconds: 20),
    Duration cacheTtl = const Duration(minutes: 5),
  })  : _siteApiBase = resolveSiteApiBase(explicitOverride: siteApiBase),
        _legacyBase = resolveFirebaseHttpsFunctionUrl(
          explicitOverride: legacyCloudFunctionBase,
          envDefineValue: _legacyEnvBase,
          functionName: 'meEntitlements',
          region: 'us-central1',
        ),
        _client = httpClient ?? http.Client(),
        _tokenProvider = tokenProvider,
        _requestTimeout = requestTimeout,
        _cacheTtl = cacheTtl;

  static const String _legacyEnvBase = String.fromEnvironment(
    'ME_ENTITLEMENTS_API_BASE',
    defaultValue: '',
  );

  final String _siteApiBase;
  final String _legacyBase;
  final http.Client _client;
  final SubscriptionTokenProvider? _tokenProvider;
  final Duration _requestTimeout;
  final Duration _cacheTtl;

  SubscriptionSnapshot? _cached;
  DateTime? _fetchedAt;
  bool _loggedSiteApiFallback = false;

  bool get hasSiteApiBase => _siteApiBase.isNotEmpty;

  bool get hasLegacyApiBase => _legacyBase.trim().isNotEmpty;

  SubscriptionSnapshot? peekCached() => _cached;

  void invalidateCache() {
    _cached = null;
    _fetchedAt = null;
  }

  Future<SubscriptionSnapshot> fetchEntitlements({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cached != null && _fetchedAt != null) {
      final Duration age = DateTime.now().difference(_fetchedAt!);
      if (age < _cacheTtl) {
        return _cached!;
      }
    }
    final String? idToken = await _resolveIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const SubscriptionRepositoryException('You are not signed in.');
    }
    final SubscriptionSnapshot snapshot = await _fetchWithFallback(idToken);
    _cached = snapshot;
    _fetchedAt = DateTime.now();
    if (kDebugMode) {
      debugPrint(
        'SubscriptionRepository: tier=${snapshot.tierApi} '
        'paid=${snapshot.isPaid} credits=${snapshot.creditsRemaining}/'
        '${snapshot.creditsLimit}',
      );
    }
    return snapshot;
  }

  Future<SubscriptionSnapshot> _fetchWithFallback(String idToken) async {
    if (hasSiteApiBase) {
      try {
        return await _getEntitlements(
          Uri.parse(siteUserEntitlementsUrl(base: _siteApiBase)),
          idToken,
        );
      } on SubscriptionRepositoryException catch (e) {
        if (hasLegacyApiBase && e.statusCode != 401) {
          if (kDebugMode && !_loggedSiteApiFallback) {
            _loggedSiteApiFallback = true;
            debugPrint(
              'SubscriptionRepository: site API failed (${e.statusCode}), '
              'trying legacy CF',
            );
          }
          return _getEntitlements(Uri.parse(_legacyBase), idToken);
        }
        rethrow;
      }
    }
    if (hasLegacyApiBase) {
      return _getEntitlements(Uri.parse(_legacyBase), idToken);
    }
    throw const SubscriptionRepositoryException(
      'Entitlements API is not configured. Set SITE_API_BASE.',
    );
  }

  Future<SubscriptionSnapshot> _getEntitlements(
    Uri uri,
    String idToken,
  ) async {
    try {
      final Map<String, String> headers =
          await buildAuthenticatedHttpHeaders(idToken: idToken);
      final http.Response response = await _client
          .get(
            uri,
            headers: headers,
          )
          .timeout(_requestTimeout);
      if (response.statusCode == 401) {
        await ProductionMonitoringService.instance.recordHttpFailure(
          endpoint: 'me_entitlements',
          statusCode: response.statusCode,
        );
        throw const SubscriptionRepositoryException(
          'Session expired. Please sign in again.',
          statusCode: 401,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await ProductionMonitoringService.instance.recordHttpFailure(
          endpoint: 'me_entitlements',
          statusCode: response.statusCode,
        );
        if (kDebugMode) {
          debugPrint(
            'SubscriptionRepository: HTTP ${response.statusCode} '
            '${response.body}',
          );
        }
        throw SubscriptionRepositoryException(
          'Entitlements request failed (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const SubscriptionRepositoryException(
          'Invalid entitlements response.',
        );
      }
      return SubscriptionSnapshot.fromResponseJson(decoded);
    } on SubscriptionRepositoryException {
      rethrow;
    } on SocketException {
      throw const SubscriptionRepositoryException(
        'Network unavailable. Check your connection and try again.',
      );
    } on TimeoutException {
      throw const SubscriptionRepositoryException(
        'The request timed out. Try again.',
      );
    } on FormatException {
      throw const SubscriptionRepositoryException(
        'Invalid entitlements response.',
      );
    }
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
