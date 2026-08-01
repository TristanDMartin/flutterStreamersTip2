import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../core/app_check_http_headers.dart';
import '../../core/backend/http_api_base_url.dart';

/// Content planning APIs live on the Mux Worker in production (not Hosting).
const String kContentPlanningWorkerBase =
    'https://streamerstip-mux-api.streamerstip.workers.dev';

class ContentPlanningApiException implements Exception {
  const ContentPlanningApiException(
    this.message, {
    this.statusCode,
    this.code,
  });

  final String message;
  final int? statusCode;
  final String? code;

  bool get isVersionConflict =>
      statusCode == 409 || code == 'VERSION_CONFLICT';

  @override
  String toString() => message;
}

/// Phase 5 optimistic concurrency conflict on item PATCH.
class ContentPlanningVersionConflictException
    extends ContentPlanningApiException {
  const ContentPlanningVersionConflictException({
    required this.expectedVersion,
    required this.currentVersion,
    String message = 'Item was updated elsewhere. Refresh and try again.',
  }) : super(
          message,
          statusCode: 409,
          code: 'VERSION_CONFLICT',
        );

  final int expectedVersion;
  final int currentVersion;
}

/// Phase 0 client: profile calendar + scheduled-post sync via Worker.
class ContentPlanningApiClient {
  ContentPlanningApiClient({
    http.Client? httpClient,
    String? apiBase,
  })  : _client = httpClient ?? http.Client(),
        _base = resolveHttpApiBaseUrl(
          explicitOverride: apiBase,
          envDefineValue: _envApiBase,
          productionDefault: kContentPlanningWorkerBase,
        );

  static const String _envApiBase = String.fromEnvironment(
    'CONTENT_PLANNING_API_BASE',
    defaultValue: '',
  );

  final http.Client _client;
  final String _base;

  Future<Map<String, String>> _authHeaders() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const ContentPlanningApiException(
        'Sign in required.',
        statusCode: 401,
      );
    }
    final String? token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const ContentPlanningApiException(
        'Sign in required.',
        statusCode: 401,
      );
    }
    return buildAuthenticatedHttpHeaders(
      idToken: token,
      extra: const <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
  }

  Uri _uri(String path) {
    final String cleanBase = _base.replaceAll(RegExp(r'/$'), '');
    final String cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$cleanBase$cleanPath');
  }

  Future<Map<String, dynamic>> _decode(http.Response response) async {
    try {
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  Never _throwApiFailure(
    Map<String, dynamic> body,
    int statusCode,
    String fallback,
  ) {
    final String code =
        (body['code'] ?? body['error'] ?? '').toString().trim();
    if (statusCode == 409 || code == 'VERSION_CONFLICT') {
      throw ContentPlanningVersionConflictException(
        expectedVersion: _readInt(body['expectedVersion']),
        currentVersion: _readInt(body['currentVersion']),
        message: (body['message'] ?? body['error'] ?? fallback).toString(),
      );
    }
    throw ContentPlanningApiException(
      (body['message'] ?? body['error'] ?? fallback).toString(),
      statusCode: statusCode,
      code: code.isEmpty ? null : code,
    );
  }

  static int _readInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  /// Phase 5: PATCH plan item via Worker (supports [expectedVersion]).
  Future<int?> patchPlanItem({
    required String userId,
    required String planId,
    required String itemId,
    String? title,
    String? description,
    String? type,
    String? status,
    String? caption,
    String? notes,
    List<Map<String, dynamic>>? platforms,
    List<String>? tags,
    String? profileCalendar,
    String? streamerCalendar,
    int? expectedVersion,
  }) async {
    final Map<String, String> headers = await _authHeaders();
    final http.Response response = await _client
        .patch(
          _uri('/api/content-planning/plans/$planId/items/$itemId'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'userId': userId,
            if (title != null) 'title': title,
            if (description != null) 'description': description,
            if (type != null) 'type': type,
            if (status != null) 'status': status,
            if (caption != null) 'caption': caption,
            if (notes != null) 'notes': notes,
            if (platforms != null) 'platforms': platforms,
            if (tags != null) 'tags': tags,
            if (profileCalendar != null) 'profileCalendar': profileCalendar,
            if (streamerCalendar != null) 'streamerCalendar': streamerCalendar,
            if (expectedVersion != null) 'expectedVersion': expectedVersion,
          }),
        )
        .timeout(const Duration(seconds: 25));
    final Map<String, dynamic> body = await _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      _throwApiFailure(
        body,
        response.statusCode,
        'Failed to update plan item.',
      );
    }
    final Object? version = body['version'];
    if (version is int) return version;
    if (version is num) return version.round();
    return null;
  }

  /// Phase 5: DELETE plan item via Worker (cascades cancel linked posts).
  Future<void> deletePlanItem({
    required String userId,
    required String planId,
    required String itemId,
  }) async {
    final Map<String, String> headers = await _authHeaders();
    final http.Response response = await _client
        .delete(
          _uri('/api/content-planning/plans/$planId/items/$itemId'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'userId': userId,
          }),
        )
        .timeout(const Duration(seconds: 25));
    final Map<String, dynamic> body = await _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      _throwApiFailure(
        body,
        response.statusCode,
        'Failed to delete plan item.',
      );
    }
  }

  /// Phase 4: rebuild calendar projections from contentItems on the Worker.
  Future<void> syncProfileCalendar({required String userId}) async {
    final Map<String, String> headers = await _authHeaders();
    final http.Response response = await _client
        .post(
          _uri('/api/content-planning/sync-profile-calendar'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{'userId': userId}),
        )
        .timeout(const Duration(seconds: 25));
    final Map<String, dynamic> body = await _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      throw ContentPlanningApiException(
        (body['message'] ??
                body['error'] ??
                'Failed to sync profile calendar projections.')
            .toString(),
        statusCode: response.statusCode,
      );
    }
  }

  Future<({String planId, String itemId})> createProfileCalendarItem({
    required String userId,
    required String title,
    required DateTime date,
    String description = '',
    bool isPrivate = false,
    bool? showOnStreamerPage,
    String? timezone,
  }) async {
    final Map<String, String> headers = await _authHeaders();
    final String tz = timezone ?? DateTime.now().timeZoneName;
    final http.Response response = await _client
        .post(
          _uri('/api/content-planning/profile-calendar-item'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'userId': userId,
            'title': title,
            'description': description,
            'date': date.toUtc().toIso8601String(),
            'isPrivate': isPrivate,
            if (showOnStreamerPage != null)
              'showOnStreamerPage': showOnStreamerPage,
            'timezone': tz,
          }),
        )
        .timeout(const Duration(seconds: 25));
    final Map<String, dynamic> body = await _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      _throwApiFailure(
        body,
        response.statusCode,
        'Failed to create calendar item.',
      );
    }
    final String planId = (body['planId'] ?? '').toString();
    final String itemId = (body['itemId'] ?? '').toString();
    if (planId.isEmpty || itemId.isEmpty) {
      throw const ContentPlanningApiException('Invalid create response.');
    }
    return (planId: planId, itemId: itemId);
  }

  Future<void> updateProfileCalendarItem({
    required String userId,
    required String planId,
    required String itemId,
    String? title,
    String? description,
    DateTime? date,
    bool? isPrivate,
    bool? showOnStreamerPage,
    String? timezone,
    int? expectedVersion,
  }) async {
    final Map<String, String> headers = await _authHeaders();
    final http.Response response = await _client
        .patch(
          _uri('/api/content-planning/profile-calendar-item'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'userId': userId,
            'planId': planId,
            'itemId': itemId,
            if (title != null) 'title': title,
            if (description != null) 'description': description,
            if (date != null) 'date': date.toUtc().toIso8601String(),
            if (isPrivate != null) 'isPrivate': isPrivate,
            if (showOnStreamerPage != null)
              'showOnStreamerPage': showOnStreamerPage,
            if (timezone != null) 'timezone': timezone,
            if (expectedVersion != null) 'expectedVersion': expectedVersion,
          }),
        )
        .timeout(const Duration(seconds: 25));
    final Map<String, dynamic> body = await _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      _throwApiFailure(
        body,
        response.statusCode,
        'Failed to update calendar item.',
      );
    }
  }

  Future<void> deleteProfileCalendarItem({
    required String userId,
    required String planId,
    required String itemId,
  }) async {
    final Map<String, String> headers = await _authHeaders();
    final http.Response response = await _client
        .delete(
          _uri('/api/content-planning/profile-calendar-item'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'userId': userId,
            'planId': planId,
            'itemId': itemId,
          }),
        )
        .timeout(const Duration(seconds: 25));
    final Map<String, dynamic> body = await _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      _throwApiFailure(
        body,
        response.statusCode,
        'Failed to delete calendar item.',
      );
    }
  }

  Future<({
    String planId,
    String itemId,
    String publishJobId,
    String idempotencyKey,
  })> syncScheduledPost({
    required String userId,
    required String scheduledPostId,
    required String title,
    String? caption,
    String? description,
    String? videoId,
    String? thumbnailUrl,
    String? videoUrl,
    String status = 'scheduled',
    DateTime? scheduledAt,
    String? timezone,
    List<Map<String, dynamic>>? platforms,
    String? notes,
    String? idempotencyKey,
  }) async {
    final Map<String, String> headers = await _authHeaders();
    final http.Response response = await _client
        .post(
          _uri('/api/content-planning/sync-scheduled-post'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'userId': userId,
            'scheduledPostId': scheduledPostId,
            'title': title,
            if (caption != null) 'caption': caption,
            if (description != null) 'description': description,
            if (videoId != null) 'videoId': videoId,
            if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
            if (videoUrl != null) 'videoUrl': videoUrl,
            'status': status,
            if (scheduledAt != null)
              'scheduledAt': scheduledAt.toUtc().toIso8601String(),
            if (timezone != null) 'timezone': timezone,
            if (platforms != null) 'platforms': platforms,
            if (notes != null) 'notes': notes,
            if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
          }),
        )
        .timeout(const Duration(seconds: 25));
    final Map<String, dynamic> body = await _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      throw ContentPlanningApiException(
        (body['message'] ?? body['error'] ?? 'Failed to sync scheduled post.')
            .toString(),
        statusCode: response.statusCode,
      );
    }
    return (
      planId: (body['planId'] ?? '').toString(),
      itemId: (body['itemId'] ?? '').toString(),
      publishJobId: (body['publishJobId'] ?? '').toString(),
      idempotencyKey: (body['idempotencyKey'] ?? '').toString(),
    );
  }

  Future<void> deleteSyncedScheduledPost({
    required String userId,
    required String scheduledPostId,
  }) async {
    final Map<String, String> headers = await _authHeaders();
    final http.Response response = await _client
        .delete(
          _uri('/api/content-planning/sync-scheduled-post'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'userId': userId,
            'scheduledPostId': scheduledPostId,
          }),
        )
        .timeout(const Duration(seconds: 25));
    final Map<String, dynamic> body = await _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      throw ContentPlanningApiException(
        (body['message'] ??
                body['error'] ??
                'Failed to remove scheduled post from planner.')
            .toString(),
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> migrateLegacyCalendarEvents({
    required String userId,
    String? timezone,
  }) async {
    final Map<String, String> headers = await _authHeaders();
    final http.Response response = await _client
        .post(
          _uri('/api/content-planning/migrate-legacy-calendar'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'userId': userId,
            if (timezone != null) 'timezone': timezone,
          }),
        )
        .timeout(const Duration(seconds: 40));
    final Map<String, dynamic> body = await _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      throw ContentPlanningApiException(
        (body['message'] ?? body['error'] ?? 'Failed to migrate calendar.')
            .toString(),
        statusCode: response.statusCode,
      );
    }
  }
}
