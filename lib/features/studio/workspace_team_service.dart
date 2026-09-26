import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../core/app_check_http_headers.dart';
import '../../core/backend/site_api_base.dart';
import 'models/workspace_team_models.dart';

class WorkspaceTeamException implements Exception {
  const WorkspaceTeamException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Workspace members + invites client (site Hosting → CF).
class WorkspaceTeamService {
  WorkspaceTeamService({
    http.Client? httpClient,
    String? siteApiBase,
  })  : _client = httpClient ?? http.Client(),
        _base = resolveSiteApiBase(explicitOverride: siteApiBase);

  final http.Client _client;
  final String _base;

  Future<WorkspaceContextSnapshot> fetchContext() async {
    final String token = await _requireToken();
    final Map<String, dynamic> body = await _get(
      Uri.parse(siteWorkspaceContextUrl(base: _base)),
      token: token,
    );
    if (body['success'] != true) {
      throw WorkspaceTeamException(
        (body['error'] ?? 'Could not load workspace.').toString(),
      );
    }
    return WorkspaceContextSnapshot.fromJson(body);
  }

  Future<WorkspaceTeamSummary> fetchTeamSummary({
    required String workspaceId,
  }) async {
    final String token = await _requireToken();
    final Map<String, dynamic> body = await _get(
      Uri.parse(
        siteWorkspaceMembersUrl(base: _base, workspaceId: workspaceId),
      ),
      token: token,
      workspaceId: workspaceId,
    );
    if (body['success'] != true) {
      throw WorkspaceTeamException(
        (body['error'] ?? 'Could not load team.').toString(),
      );
    }
    return WorkspaceTeamSummary.fromJson(body);
  }

  Future<List<WorkspaceInviteItem>> fetchIncomingInvites() async {
    final String token = await _requireToken();
    final Map<String, dynamic> body = await _get(
      Uri.parse(siteWorkspaceInvitesUrl(base: _base, scope: 'incoming')),
      token: token,
    );
    if (body['success'] != true) {
      throw WorkspaceTeamException(
        (body['error'] ?? 'Could not load invites.').toString(),
      );
    }
    return _inviteList(body['invites']);
  }

  Future<List<WorkspaceInviteItem>> fetchOutgoingInvites({
    required String workspaceId,
  }) async {
    final String token = await _requireToken();
    final Map<String, dynamic> body = await _get(
      Uri.parse(
        siteWorkspaceInvitesUrl(
          base: _base,
          scope: 'outgoing',
          workspaceId: workspaceId,
        ),
      ),
      token: token,
      workspaceId: workspaceId,
    );
    if (body['success'] != true) {
      throw WorkspaceTeamException(
        (body['error'] ?? 'Could not load pending invites.').toString(),
      );
    }
    return _inviteList(body['invites']);
  }

  Future<List<WorkspaceInviteCandidate>> searchCandidates({
    required String workspaceId,
    required String query,
  }) async {
    final String trimmed = query.trim();
    if (trimmed.length < 2) {
      return <WorkspaceInviteCandidate>[];
    }
    final String token = await _requireToken();
    final Map<String, dynamic> body = await _get(
      Uri.parse(
        siteWorkspaceMemberSearchUrl(
          base: _base,
          workspaceId: workspaceId,
          query: trimmed,
        ),
      ),
      token: token,
      workspaceId: workspaceId,
    );
    if (body['success'] != true) {
      throw WorkspaceTeamException(
        (body['error'] ?? 'Search failed.').toString(),
      );
    }
    final Object? raw = body['candidates'];
    if (raw is! List) {
      return <WorkspaceInviteCandidate>[];
    }
    final List<WorkspaceInviteCandidate> out = <WorkspaceInviteCandidate>[];
    for (final Object? item in raw) {
      if (item is Map<String, dynamic>) {
        out.add(WorkspaceInviteCandidate.fromJson(item));
      } else if (item is Map) {
        out.add(
          WorkspaceInviteCandidate.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }
    return out;
  }

  Future<void> inviteMember({
    required String workspaceId,
    required String role,
    String? email,
    String? targetUserId,
  }) async {
    final String token = await _requireToken();
    final Map<String, dynamic> body = await _send(
      method: 'POST',
      uri: Uri.parse(siteWorkspaceMembersUrl(base: _base)),
      token: token,
      workspaceId: workspaceId,
      payload: <String, dynamic>{
        'workspaceId': workspaceId,
        'role': role,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (targetUserId != null && targetUserId.trim().isNotEmpty)
          'targetUserId': targetUserId.trim(),
      },
    );
    if (body['success'] != true) {
      throw WorkspaceTeamException(
        (body['error'] ?? 'Invite failed.').toString(),
      );
    }
  }

  Future<void> revokeInvite({
    required String workspaceId,
    required String inviteId,
  }) async {
    final String token = await _requireToken();
    final Map<String, dynamic> body = await _send(
      method: 'DELETE',
      uri: Uri.parse(
        siteWorkspaceInviteUrl(base: _base, inviteId: inviteId),
      ),
      token: token,
      workspaceId: workspaceId,
    );
    if (body['success'] != true) {
      throw WorkspaceTeamException(
        (body['error'] ?? 'Revoke failed.').toString(),
      );
    }
  }

  Future<String?> acceptInvite(String inviteId) async {
    final String token = await _requireToken();
    final Map<String, dynamic> body = await _send(
      method: 'POST',
      uri: Uri.parse(
        siteWorkspaceInviteUrl(base: _base, inviteId: inviteId),
      ),
      token: token,
    );
    if (body['success'] != true) {
      throw WorkspaceTeamException(
        (body['error'] ?? 'Accept failed.').toString(),
      );
    }
    final Object? workspaceId = body['workspaceId'];
    return workspaceId is String ? workspaceId : null;
  }

  Future<void> declineInvite(String inviteId) async {
    final String token = await _requireToken();
    final Map<String, dynamic> body = await _send(
      method: 'PATCH',
      uri: Uri.parse(
        siteWorkspaceInviteUrl(base: _base, inviteId: inviteId),
      ),
      token: token,
    );
    if (body['success'] != true) {
      throw WorkspaceTeamException(
        (body['error'] ?? 'Decline failed.').toString(),
      );
    }
  }

  Future<void> changeMemberRole({
    required String workspaceId,
    required String memberId,
    required String role,
  }) async {
    final String token = await _requireToken();
    final Map<String, dynamic> body = await _send(
      method: 'PATCH',
      uri: Uri.parse(
        siteWorkspaceMemberUrl(base: _base, memberId: memberId),
      ),
      token: token,
      workspaceId: workspaceId,
      payload: <String, dynamic>{
        'workspaceId': workspaceId,
        'role': role,
      },
    );
    if (body['success'] != true) {
      throw WorkspaceTeamException(
        (body['error'] ?? 'Role change failed.').toString(),
      );
    }
  }

  Future<void> removeMember({
    required String workspaceId,
    required String memberId,
  }) async {
    final String token = await _requireToken();
    final Map<String, dynamic> body = await _send(
      method: 'DELETE',
      uri: Uri.parse(
        siteWorkspaceMemberUrl(base: _base, memberId: memberId),
      ),
      token: token,
      workspaceId: workspaceId,
    );
    if (body['success'] != true) {
      throw WorkspaceTeamException(
        (body['error'] ?? 'Remove failed.').toString(),
      );
    }
  }

  Future<Map<String, dynamic>> _get(
    Uri uri, {
    required String token,
    String? workspaceId,
  }) async {
    try {
      final Map<String, String> headers = await _headers(
        token: token,
        workspaceId: workspaceId,
      );
      final http.Response response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 25));
      return _handle(response);
    } on WorkspaceTeamException {
      rethrow;
    } on SocketException {
      throw const WorkspaceTeamException('Network unavailable.');
    } on TimeoutException {
      throw const WorkspaceTeamException('Request timed out.');
    } on FormatException {
      throw const WorkspaceTeamException('Invalid response.');
    }
  }

  Future<Map<String, dynamic>> _send({
    required String method,
    required Uri uri,
    required String token,
    String? workspaceId,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final Map<String, String> headers = await _headers(
        token: token,
        workspaceId: workspaceId,
        jsonBody: payload != null,
      );
      late final http.Response response;
      final String? encoded =
          payload == null ? null : jsonEncode(payload);
      switch (method) {
        case 'POST':
          response = await _client
              .post(uri, headers: headers, body: encoded)
              .timeout(const Duration(seconds: 30));
          break;
        case 'PATCH':
          response = await _client
              .patch(uri, headers: headers, body: encoded)
              .timeout(const Duration(seconds: 30));
          break;
        case 'DELETE':
          response = await _client
              .delete(uri, headers: headers, body: encoded)
              .timeout(const Duration(seconds: 30));
          break;
        default:
          throw WorkspaceTeamException('Unsupported method $method');
      }
      return _handle(response);
    } on WorkspaceTeamException {
      rethrow;
    } on SocketException {
      throw const WorkspaceTeamException('Network unavailable.');
    } on TimeoutException {
      throw const WorkspaceTeamException('Request timed out.');
    } on FormatException {
      throw const WorkspaceTeamException('Invalid response.');
    }
  }

  Map<String, dynamic> _handle(http.Response response) {
    final Map<String, dynamic> body = _decodeMap(response.body);
    if (response.statusCode == 401) {
      throw const WorkspaceTeamException(
        'Session expired. Please sign in again.',
        statusCode: 401,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WorkspaceTeamException(
        (body['error'] ?? 'Request failed (${response.statusCode}).')
            .toString(),
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  Future<Map<String, String>> _headers({
    required String token,
    String? workspaceId,
    bool jsonBody = false,
  }) {
    return buildAuthenticatedHttpHeaders(
      idToken: token,
      extra: <String, String>{
        'Accept': 'application/json',
        if (workspaceId != null && workspaceId.isNotEmpty)
          'X-Workspace-Id': workspaceId,
        if (jsonBody) 'Content-Type': 'application/json',
      },
    );
  }

  Future<String> _requireToken() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? token = await user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw const WorkspaceTeamException(
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

  List<WorkspaceInviteItem> _inviteList(Object? raw) {
    if (raw is! List) {
      return <WorkspaceInviteItem>[];
    }
    final List<WorkspaceInviteItem> out = <WorkspaceInviteItem>[];
    for (final Object? item in raw) {
      if (item is Map<String, dynamic>) {
        out.add(WorkspaceInviteItem.fromJson(item));
      } else if (item is Map) {
        out.add(WorkspaceInviteItem.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return out;
  }

  void dispose() {
    _client.close();
  }
}
