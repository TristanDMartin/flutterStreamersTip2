import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../core/app_check_http_headers.dart';
import '../../core/backend/site_api_base.dart';
import 'approval_queue_models.dart';

class ApprovalQueueException implements Exception {
  const ApprovalQueueException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isVersionConflict => statusCode == 409;

  @override
  String toString() => message;
}

/// Workspace Approval Queue client (site Hosting → `/api/workspace/approvals`).
class ApprovalQueueService {
  ApprovalQueueService({
    http.Client? httpClient,
    String? siteApiBase,
  })  : _client = httpClient ?? http.Client(),
        _base = resolveSiteApiBase(explicitOverride: siteApiBase);

  final http.Client _client;
  final String _base;

  Future<ApprovalQueueRequest> fetchApprovalDetail({
    required String workspaceId,
    required String requestId,
  }) async {
    final String token = await _requireToken();
    final Uri uri = Uri.parse(
      siteWorkspaceApprovalUrl(requestId: requestId, base: _base),
    );
    try {
      final Map<String, String> headers = await _headers(
        token: token,
        workspaceId: workspaceId,
      );
      final http.Response response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 25));
      final Map<String, dynamic> body = _decodeMap(response.body);
      if (response.statusCode == 401) {
        throw const ApprovalQueueException(
          'Session expired. Please sign in again.',
          statusCode: 401,
        );
      }
      if (response.statusCode == 403) {
        throw ApprovalQueueException(
          (body['error'] ?? 'You do not have access to this approval.')
              .toString(),
          statusCode: 403,
        );
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          body['success'] != true) {
        throw ApprovalQueueException(
          (body['error'] ?? 'Could not load approval.')
              .toString(),
          statusCode: response.statusCode,
        );
      }
      final Object? requestRaw = body['request'];
      if (requestRaw is! Map) {
        throw const ApprovalQueueException('Invalid approval response.');
      }
      final Map<String, dynamic> requestMap =
          Map<String, dynamic>.from(requestRaw);
      if ((requestMap['workspaceId']?.toString() ?? '').isEmpty) {
        requestMap['workspaceId'] = workspaceId;
      }
      return ApprovalQueueRequest.fromJson(requestMap);
    } on ApprovalQueueException {
      rethrow;
    } on SocketException {
      throw const ApprovalQueueException('Network unavailable.');
    } on TimeoutException {
      throw const ApprovalQueueException('Request timed out.');
    } on FormatException {
      throw const ApprovalQueueException('Invalid approval response.');
    }
  }

  Future<ApprovalDecideResult> decideApproval({
    required String workspaceId,
    required String requestId,
    required String decision,
    required String contentVersionId,
    String? reasonCode,
    String? notes,
    String? commentBody,
  }) async {
    final String token = await _requireToken();
    final Uri uri = Uri.parse(
      siteWorkspaceApprovalUrl(requestId: requestId, base: _base),
    );
    try {
      final Map<String, String> headers = await _headers(
        token: token,
        workspaceId: workspaceId,
        jsonBody: true,
      );
      final http.Response response = await _client
          .post(
            uri,
            headers: headers,
            body: jsonEncode(<String, dynamic>{
              'action': 'decide',
              'decision': decision,
              'contentVersionId': contentVersionId,
              if (reasonCode != null && reasonCode.isNotEmpty)
                'reasonCode': reasonCode,
              if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
              if (commentBody != null && commentBody.trim().isNotEmpty)
                'commentBody': commentBody.trim(),
              'sourcePlatform': 'mobile',
            }),
          )
          .timeout(const Duration(seconds: 30));
      final Map<String, dynamic> body = _decodeMap(response.body);
      if (response.statusCode == 401) {
        throw const ApprovalQueueException(
          'Session expired. Please sign in again.',
          statusCode: 401,
        );
      }
      if (response.statusCode == 409) {
        throw ApprovalQueueException(
          (body['error'] ??
                  'This approval changed. Refresh and try again.')
              .toString(),
          statusCode: 409,
        );
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          body['success'] != true) {
        throw ApprovalQueueException(
          (body['error'] ?? 'Could not save decision.')
              .toString(),
          statusCode: response.statusCode,
        );
      }
      return ApprovalDecideResult.fromJson(body);
    } on ApprovalQueueException {
      rethrow;
    } on SocketException {
      throw const ApprovalQueueException('Network unavailable.');
    } on TimeoutException {
      throw const ApprovalQueueException('Request timed out.');
    } on FormatException {
      throw const ApprovalQueueException('Invalid decision response.');
    }
  }

  Future<Map<String, String>> _headers({
    required String token,
    required String workspaceId,
    bool jsonBody = false,
  }) {
    return buildAuthenticatedHttpHeaders(
      idToken: token,
      extra: <String, String>{
        'X-Workspace-Id': workspaceId,
        'Accept': 'application/json',
        if (jsonBody) 'Content-Type': 'application/json',
      },
    );
  }

  Future<String> _requireToken() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? token = await user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw const ApprovalQueueException(
        'Sign in required.',
        statusCode: 401,
      );
    }
    return token;
  }

  Map<String, dynamic> _decodeMap(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  void dispose() {
    _client.close();
  }
}
