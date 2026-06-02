import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/backend/http_api_base_url.dart';
import 'content_scheduler_models.dart';

class ContentSchedulerException implements Exception {
  const ContentSchedulerException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ContentSchedulerException($statusCode): $message';
}

abstract class ContentSchedulerRepository {
  Future<List<SchedulerQueueItem>> loadQueue({
    required String idToken,
    int limit = 25,
  });
}

class HttpContentSchedulerRepository implements ContentSchedulerRepository {
  HttpContentSchedulerRepository({
    String? apiBase,
    http.Client? client,
  })  : _apiBase = resolveHttpApiBaseUrl(
          explicitOverride: apiBase,
          envDefineValue: _envApiBase,
        ),
        _client = client ?? http.Client();

  static const String _envApiBase = String.fromEnvironment(
    'CONTENT_SCHEDULER_API_BASE',
    defaultValue: '',
  );

  final String _apiBase;
  final http.Client _client;

  @override
  Future<List<SchedulerQueueItem>> loadQueue({
    required String idToken,
    int limit = 25,
  }) async {
    final int safeLimit = limit.clamp(1, 50);
    final List<Map<String, dynamic>> jobs = await _getList(
      '/api/crossPost/jobs',
      listKey: 'jobs',
      idToken: idToken,
      limit: safeLimit,
    );
    final List<Map<String, dynamic>> drafts = await _getList(
      '/api/content-scheduler/drafts',
      listKey: 'drafts',
      idToken: idToken,
      limit: safeLimit,
    );
    final List<SchedulerQueueItem> rows = <SchedulerQueueItem>[
      ...jobs.map(SchedulerQueueItem.fromJob),
      ...drafts.map(SchedulerQueueItem.fromDraft),
    ]..sort(
        (SchedulerQueueItem a, SchedulerQueueItem b) =>
            b.sortTime.compareTo(a.sortTime),
      );
    return rows;
  }

  Future<List<Map<String, dynamic>>> _getList(
    String endpoint, {
    required String listKey,
    required String idToken,
    required int limit,
  }) async {
    final Uri uri = _buildUri(endpoint, <String, String>{
      'limit': '$limit',
    });
    final http.Response response = await _client.get(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer $idToken',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 25));
    final Map<String, dynamic>? body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ContentSchedulerException(
        'Scheduler request failed.',
        statusCode: response.statusCode,
      );
    }
    if (body == null || body['ok'] != true || body[listKey] is! List) {
      throw const ContentSchedulerException('Unexpected scheduler response.');
    }
    return (body[listKey] as List)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Uri _buildUri(String endpoint, Map<String, String> query) {
    final String cleanBase = _apiBase.replaceAll(RegExp(r'/$'), '');
    final String cleanEndpoint =
        endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('$cleanBase$cleanEndpoint').replace(
      queryParameters: query,
    );
  }

  Map<String, dynamic>? _decodeMap(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
