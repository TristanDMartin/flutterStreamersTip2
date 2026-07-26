import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_check_http_headers.dart';
import '../../core/backend/site_api_base.dart';
import 'models/studio_team_control_models.dart';

class StudioTeamControlException implements Exception {
  const StudioTeamControlException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class StudioTeamControlService {
  StudioTeamControlService({
    http.Client? httpClient,
    String? siteApiBase,
  })  : _client = httpClient ?? http.Client(),
        _base = resolveSiteApiBase(explicitOverride: siteApiBase);

  final http.Client _client;
  final String _base;

  Future<StudioTeamControlResponse> fetchTeamControl() async {
    final String token = await _requireToken();
    try {
      final Map<String, String> headers =
          await buildAuthenticatedHttpHeaders(idToken: token);
      final http.Response response = await _client
          .get(
            Uri.parse(siteStudioTeamControlUrl(base: _base)),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 401) {
        throw const StudioTeamControlException(
          'Session expired. Please sign in again.',
          statusCode: 401,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StudioTeamControlException(
          'Could not load team control (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const StudioTeamControlException('Invalid team control response.');
      }
      return StudioTeamControlResponse.fromJson(decoded);
    } on StudioTeamControlException {
      rethrow;
    } on SocketException {
      throw const StudioTeamControlException('Network unavailable.');
    } on TimeoutException {
      throw const StudioTeamControlException('Request timed out.');
    } on FormatException {
      throw const StudioTeamControlException('Invalid team control response.');
    }
  }

  Future<void> exportWeeklyReportJson() async {
    final String token = await _requireToken();
    final Map<String, String> headers =
        await buildAuthenticatedHttpHeaders(idToken: token);
    final http.Response response = await _client
        .get(
          Uri.parse(siteStudioExportWeeklyUrl(base: _base)),
          headers: headers,
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 403) {
      throw const StudioTeamControlException(
        'Exportable reports require Creator Studio.',
        statusCode: 403,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StudioTeamControlException(
        'Export failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    final Directory dir = await getTemporaryDirectory();
    final File file = File(
      '${dir.path}/streamerstip-weekly-report.json',
    );
    await file.writeAsBytes(response.bodyBytes);
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path)],
        text: 'StreamersTip weekly business report',
      ),
    );
  }

  Future<String> _requireToken() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? token = await user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw const StudioTeamControlException(
        'Sign in required.',
        statusCode: 401,
      );
    }
    return token;
  }

  void dispose() {
    _client.close();
  }
}
