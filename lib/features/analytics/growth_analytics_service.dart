import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/backend/site_api_base.dart';
import 'models/growth_data.dart';

class GrowthAnalyticsException implements Exception {
  const GrowthAnalyticsException(
    this.message, {
    this.statusCode,
    this.isTransient = false,
  });

  final String message;
  final int? statusCode;
  final bool isTransient;

  @override
  String toString() => message;
}

class GrowthAnalyticsService {
  GrowthAnalyticsService({
    http.Client? httpClient,
    String? siteApiBase,
    Duration requestTimeout = const Duration(seconds: 25),
  })  : _client = httpClient ?? http.Client(),
        _siteApiBase = resolveSiteApiBase(explicitOverride: siteApiBase),
        _requestTimeout = requestTimeout;

  static const String _userFacingUnavailable =
      'Growth analytics are temporarily unavailable. '
      'Your content and planner data are safe.';

  final http.Client _client;
  final String _siteApiBase;
  final Duration _requestTimeout;

  void _logFailure({
    required String method,
    required Uri uri,
    required int? statusCode,
    String? detail,
  }) {
    developer.log(
      'growth_analytics method=$method url=$uri '
      'status=${statusCode ?? 'none'} '
      'env=$_siteApiBase ts=${DateTime.now().toUtc().toIso8601String()}'
      '${detail == null || detail.isEmpty ? '' : ' detail=$detail'}',
      name: 'GrowthAnalytics',
    );
  }

  Future<GrowthData> loadGrowthData({
    required String userId,
    required int days,
  }) async {
    final String? idToken =
        await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const GrowthAnalyticsException('You are not signed in.');
    }
    final Uri uri = Uri.parse(
      siteGrowthDataUrl(userId: userId, days: days, base: _siteApiBase),
    );
    try {
      final http.Response response = await _client
          .get(
            uri,
            headers: <String, String>{'Authorization': 'Bearer $idToken'},
          )
          .timeout(_requestTimeout);
      if (response.statusCode == 401) {
        _logFailure(method: 'GET', uri: uri, statusCode: 401);
        throw const GrowthAnalyticsException(
          'Session expired. Please sign in again.',
          statusCode: 401,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _logFailure(
          method: 'GET',
          uri: uri,
          statusCode: response.statusCode,
          detail: response.body.length > 200
              ? response.body.substring(0, 200)
              : response.body,
        );
        throw GrowthAnalyticsException(
          _userFacingUnavailable,
          statusCode: response.statusCode,
          isTransient: true,
        );
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final Object? payload = decoded['data'] ?? decoded;
        if (payload is Map<String, dynamic>) {
          return GrowthData.fromJson(payload);
        }
        // Explicit null/empty payload from a healthy endpoint.
        if (payload == null ||
            (payload is Map && payload.isEmpty) ||
            decoded['success'] == true) {
          return GrowthData.empty;
        }
      }
      return GrowthData.empty;
    } on GrowthAnalyticsException {
      rethrow;
    } on SocketException {
      _logFailure(method: 'GET', uri: uri, statusCode: null, detail: 'socket');
      throw const GrowthAnalyticsException(
        'Network unavailable. Check your connection and try again.',
        isTransient: true,
      );
    } on TimeoutException {
      _logFailure(method: 'GET', uri: uri, statusCode: null, detail: 'timeout');
      throw const GrowthAnalyticsException(
        _userFacingUnavailable,
        isTransient: true,
      );
    } on FormatException {
      _logFailure(method: 'GET', uri: uri, statusCode: null, detail: 'format');
      throw const GrowthAnalyticsException(
        _userFacingUnavailable,
        isTransient: true,
      );
    }
  }

  Future<void> refreshGrowthData({required String userId}) async {
    final String? idToken =
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw const GrowthAnalyticsException('You are not signed in.');
    }
    final Uri uri = Uri.parse(
      siteGrowthRefreshUrl(userId: userId, base: _siteApiBase),
    );
    try {
      final http.Response response = await _client
          .post(
            uri,
            headers: <String, String>{'Authorization': 'Bearer $idToken'},
          )
          .timeout(_requestTimeout);
      if (response.statusCode == 401) {
        _logFailure(method: 'POST', uri: uri, statusCode: 401);
        throw const GrowthAnalyticsException(
          'Session expired. Please sign in again.',
          statusCode: 401,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _logFailure(
          method: 'POST',
          uri: uri,
          statusCode: response.statusCode,
          detail: response.body.length > 200
              ? response.body.substring(0, 200)
              : response.body,
        );
        throw GrowthAnalyticsException(
          _userFacingUnavailable,
          statusCode: response.statusCode,
          isTransient: true,
        );
      }
    } on GrowthAnalyticsException {
      rethrow;
    } on SocketException {
      _logFailure(method: 'POST', uri: uri, statusCode: null, detail: 'socket');
      throw const GrowthAnalyticsException(
        'Network unavailable. Check your connection and try again.',
        isTransient: true,
      );
    } on TimeoutException {
      _logFailure(method: 'POST', uri: uri, statusCode: null, detail: 'timeout');
      throw const GrowthAnalyticsException(
        _userFacingUnavailable,
        isTransient: true,
      );
    }
  }

  void dispose() {
    _client.close();
  }
}

final Provider<GrowthAnalyticsService> growthAnalyticsServiceProvider =
    Provider<GrowthAnalyticsService>((Ref ref) {
  final GrowthAnalyticsService service = GrowthAnalyticsService();
  ref.onDispose(service.dispose);
  return service;
});
