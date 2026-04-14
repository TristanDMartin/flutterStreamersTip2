import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../gamification_backend_config.dart';

/// Trusted gamification events — POST only after a real product action succeeds.
/// Does not compute XP or levels.
class GamificationEventService {
  GamificationEventService({
    http.Client? httpClient,
    String? baseUrl,
  })  : _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? kGamificationEventsBaseUrl;

  final http.Client _http;
  final String _baseUrl;

  /// Worker: `baseUrl` is origin → `…/gamification/events`. Firebase HTTPS: full
  /// function URL `https://<region>-<project>.cloudfunctions.net/gamificationEvents`.
  static Uri _gamificationEventsUri(String baseUrl) {
    final String trimmed = baseUrl.trim();
    if (trimmed.contains('cloudfunctions.net')) {
      return Uri.parse(trimmed);
    }
    final String noSlash =
        trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
    return Uri.parse('$noSlash/gamification/events');
  }

  /// Event types must match website + worker contract (e.g. `content.video_uploaded`).
  Future<void> emitTrustedEvent({
    required String type,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }
    final String? token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('No ID token');
    }
    final String eventId = const Uuid().v4();
    final Uri uri = _gamificationEventsUri(_baseUrl);
    final Map<String, dynamic> body = <String, dynamic>{
      'eventId': eventId,
      'uid': user.uid,
      'type': type,
      'source': 'app',
      'entityType': entityType,
      'entityId': entityId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'metadata': metadata ??
          <String, dynamic>{
            'platform': 'streamerstip',
          },
    };
    try {
      final http.Response res = await _http.post(
        uri,
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (res.statusCode >= 400) {
        debugPrint(
          'GamificationEventService: HTTP ${res.statusCode} ${res.body}',
        );
      }
    } catch (e) {
      debugPrint('GamificationEventService: emit failed (non-fatal): $e');
    }
  }
}
