import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../core/app_check_http_headers.dart';
import '../../core/backend/site_api_base.dart';
import 'models/weekly_report_models.dart';

class WeeklyReportException implements Exception {
  const WeeklyReportException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class WeeklyReportService {
  WeeklyReportService({
    http.Client? httpClient,
    String? siteApiBase,
  })  : _client = httpClient ?? http.Client(),
        _base = resolveSiteApiBase(explicitOverride: siteApiBase);

  final http.Client _client;
  final String _base;

  Future<WeeklyReportResponse> fetchWeeklyReport() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? token = await user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw const WeeklyReportException('Sign in required.', statusCode: 401);
    }
    try {
      final Map<String, String> headers =
          await buildAuthenticatedHttpHeaders(idToken: token);
      final http.Response response = await _client
          .get(Uri.parse(siteWeeklyReportUrl(base: _base)), headers: headers)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 401) {
        throw const WeeklyReportException(
          'Session expired. Please sign in again.',
          statusCode: 401,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw WeeklyReportException(
          'Could not load weekly report (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const WeeklyReportException('Invalid weekly report response.');
      }
      return WeeklyReportResponse.fromJson(decoded);
    } on WeeklyReportException {
      rethrow;
    } on SocketException {
      throw const WeeklyReportException('Network unavailable.');
    } on TimeoutException {
      throw const WeeklyReportException('Request timed out.');
    } on FormatException {
      throw const WeeklyReportException('Invalid weekly report response.');
    }
  }

  void dispose() {
    _client.close();
  }
}
