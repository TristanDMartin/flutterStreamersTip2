import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/backend/site_api_base.dart';
import 'models/growth_data.dart';

class GrowthAnalyticsException implements Exception {
  const GrowthAnalyticsException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

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

  final http.Client _client;
  final String _siteApiBase;
  final Duration _requestTimeout;

  Future<GrowthData> loadGrowthData({
    required String userId,
    required int days,
  }) async {
    final String? idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
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
        throw const GrowthAnalyticsException(
          'Session expired. Please sign in again.',
          statusCode: 401,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw GrowthAnalyticsException(
          'Growth analytics request failed (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final Object? payload = decoded['data'] ?? decoded;
        if (payload is Map<String, dynamic>) {
          return GrowthData.fromJson(payload);
        }
      }
      return GrowthData.empty;
    } on GrowthAnalyticsException {
      rethrow;
    } on SocketException {
      throw const GrowthAnalyticsException(
        'Network unavailable. Check your connection and try again.',
      );
    } on TimeoutException {
      throw const GrowthAnalyticsException(
        'The request timed out. Try again.',
      );
    } on FormatException {
      throw const GrowthAnalyticsException(
        'Invalid growth analytics response.',
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
        throw const GrowthAnalyticsException(
          'Session expired. Please sign in again.',
          statusCode: 401,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw GrowthAnalyticsException(
          'Refresh failed (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
    } on GrowthAnalyticsException {
      rethrow;
    } on SocketException {
      throw const GrowthAnalyticsException(
        'Network unavailable. Check your connection and try again.',
      );
    } on TimeoutException {
      throw const GrowthAnalyticsException(
        'The request timed out. Try again.',
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
