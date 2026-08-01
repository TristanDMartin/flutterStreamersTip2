import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/backend/site_api_base.dart';
import '../shared/retention/retention_event_constants.dart';

/// Posts shared retention events to the website `/api/track` endpoint.
/// Best-effort only — failures are logged and never block UI flows.
class RetentionTrackingService {
  RetentionTrackingService({
    FirebaseAuth? auth,
    http.Client? httpClient,
    String? siteApiBase,
    String? cloudFunctionTrackUrl,
    Duration timeout = const Duration(seconds: 12),
  })  : _auth = auth ?? FirebaseAuth.instance,
        _client = httpClient ?? http.Client(),
        _siteApiBase = resolveSiteApiBase(explicitOverride: siteApiBase),
        _cloudFunctionTrackUrl = (cloudFunctionTrackUrl ??
                _defaultCloudFunctionTrackUrl)
            .trim(),
        _timeout = timeout;

  static const String _defaultCloudFunctionTrackUrl =
      'https://us-central1-streamerstip-6cfdb.cloudfunctions.net/apiRetentionTrack';

  static final RetentionTrackingService instance = RetentionTrackingService();

  final FirebaseAuth _auth;
  final http.Client _client;
  final String _siteApiBase;
  final String _cloudFunctionTrackUrl;
  final Duration _timeout;

  Future<void> trackAuth({
    required String uid,
    required bool isSignup,
    Map<String, dynamic>? metadata,
  }) {
    return trackEvent(
      uid: uid,
      type: isSignup
          ? RetentionEventTypes.userSignedUp
          : RetentionEventTypes.userLoggedIn,
      metadata: metadata,
    );
  }

  Future<void> trackPlatformConnected({
    required String uid,
    required String platform,
    required bool isFirstPlatform,
    Map<String, dynamic>? metadata,
  }) {
    return trackEvent(
      uid: uid,
      type: isFirstPlatform
          ? RetentionEventTypes.connectedFirstPlatform
          : RetentionEventTypes.connectedAdditionalPlatform,
      metadata: <String, dynamic>{
        'platform': platform,
        ...?metadata,
      },
    );
  }

  Future<void> trackContentPlanCreated({
    required String uid,
    String? planId,
    Map<String, dynamic>? metadata,
  }) {
    return trackEvent(
      uid: uid,
      type: RetentionEventTypes.createdContentPlan,
      metadata: <String, dynamic>{
        if (planId != null && planId.isNotEmpty) 'planId': planId,
        ...?metadata,
      },
    );
  }

  Future<void> trackViewedAnalytics({
    required String uid,
    Map<String, dynamic>? metadata,
  }) {
    return trackEvent(
      uid: uid,
      type: RetentionEventTypes.viewedAnalytics,
      metadata: metadata,
    );
  }

  Future<void> trackViewedWeeklyReport({
    required String uid,
    String? level,
    Map<String, dynamic>? metadata,
  }) {
    return trackEvent(
      uid: uid,
      type: RetentionEventTypes.viewedWeeklyReport,
      metadata: <String, dynamic>{
        if (level != null && level.isNotEmpty) 'level': level,
        'surface': 'weekly_report',
        ...?metadata,
      },
    );
  }

  Future<void> trackEvent({
    required String uid,
    required String type,
    Map<String, dynamic>? metadata,
  }) async {
    final String normalizedUid = uid.trim();
    if (normalizedUid.isEmpty || type.trim().isEmpty) {
      return;
    }
    try {
      final User? user = _auth.currentUser;
      if (user == null || user.uid != normalizedUid) {
        return;
      }
      final String? idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        return;
      }
      final Map<String, dynamic> body = <String, dynamic>{
        'uid': normalizedUid,
        'type': type,
        'eventType': type,
        'source': RetentionEventSources.app,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      };
      final List<Uri> trackUris = <Uri>[
        Uri.parse(siteRetentionTrackUrl(base: _siteApiBase)),
        Uri.parse(_cloudFunctionTrackUrl),
      ];
      for (final Uri uri in trackUris) {
        final bool accepted = await _postTrackRequest(
          uri: uri,
          idToken: idToken,
          body: body,
          type: type,
        );
        if (accepted) {
          return;
        }
      }
    } catch (error, stackTrace) {
      debugPrint('RetentionTrackingService: track failed type=$type: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<bool> _postTrackRequest({
    required Uri uri,
    required String idToken,
    required Map<String, dynamic> body,
    required String type,
  }) async {
    try {
      final http.Response response = await _client
          .post(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      final String contentType =
          response.headers['content-type'] ?? '';
      if (contentType.contains('text/html')) {
        return false;
      }
      if (response.statusCode == 201 ||
          response.statusCode == 200 ||
          response.statusCode == 204) {
        return true;
      }
      debugPrint(
        'RetentionTrackingService: track failed '
        'type=$type uri=$uri status=${response.statusCode}',
      );
      return false;
    } catch (error) {
      debugPrint(
        'RetentionTrackingService: track request error uri=$uri type=$type: $error',
      );
      return false;
    }
  }
}
