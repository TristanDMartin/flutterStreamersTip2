import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/backend/site_api_base.dart';
import '../features/growth/creator_growth_contract.dart';

/// Posts canonical growth product events to `/api/track` (`bus: product`).
/// Best-effort only — never blocks UI.
class ProductEventTrackingService {
  ProductEventTrackingService({
    FirebaseAuth? auth,
    http.Client? httpClient,
    String? siteApiBase,
    Duration timeout = const Duration(seconds: 12),
  })  : _auth = auth ?? FirebaseAuth.instance,
        _client = httpClient ?? http.Client(),
        _siteApiBase = resolveSiteApiBase(explicitOverride: siteApiBase),
        _timeout = timeout;

  static final ProductEventTrackingService instance =
      ProductEventTrackingService();

  final FirebaseAuth _auth;
  final http.Client _client;
  final String _siteApiBase;
  final Duration _timeout;

  Future<void> track({
    required String eventName,
    String? surface,
    String? tier,
    String? eventId,
    Map<String, dynamic>? metadata,
  }) async {
    final String canonical =
        CreatorGrowthContract.canonicalizeProductEventName(eventName.trim());
    if (!CreatorGrowthContract.isCanonicalProductEvent(canonical)) {
      return;
    }
    final User? user = _auth.currentUser;
    final String? uid = user?.uid;
    if (user == null || uid == null || uid.isEmpty) {
      return;
    }
    try {
      final String? idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        return;
      }
      final Map<String, dynamic> body = <String, dynamic>{
        'bus': 'product',
        'eventName': canonical,
        'uid': uid,
        'platform': 'mobile',
        'source': 'app',
        if (surface != null && surface.isNotEmpty) 'surface': surface,
        if (tier != null && tier.isNotEmpty) 'tier': tier,
        if (eventId != null && eventId.isNotEmpty) 'eventId': eventId,
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      };
      final http.Response response = await _client
          .post(
            Uri.parse(siteRetentionTrackUrl(base: _siteApiBase)),
            headers: <String, String>{
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'ProductEventTrackingService: $canonical failed '
          '${response.statusCode}',
        );
      }
    } catch (error) {
      debugPrint('ProductEventTrackingService: $canonical error: $error');
    }
  }

  Future<void> onboardingStarted({required String sessionId}) {
    return track(
      eventName: 'onboarding_started',
      surface: 'tippy_onboarding',
      metadata: <String, dynamic>{'sessionId': sessionId},
    );
  }

  Future<void> onboardingCompleted({
    required String sessionId,
    int? ttfrMs,
  }) {
    final String? uid = _auth.currentUser?.uid;
    return track(
      eventName: 'onboarding_completed',
      surface: 'tippy_onboarding',
      eventId: uid != null && uid.isNotEmpty
          ? 'onboarding_completed:$uid:$sessionId'
          : null,
      metadata: <String, dynamic>{
        'sessionId': sessionId,
        if (ttfrMs != null) 'ttfrMs': ttfrMs,
      },
    );
  }

  Future<void> creatorProfileCompleted({String? surface}) {
    final String? uid = _auth.currentUser?.uid;
    return track(
      eventName: 'creator_profile_completed',
      surface: surface ?? 'profile',
      eventId: uid != null && uid.isNotEmpty
          ? 'creator_profile_completed:$uid'
          : null,
    );
  }

  Future<void> creatorScoreViewed({String? surface}) {
    return track(
      eventName: 'creator_score_viewed',
      surface: surface ?? 'creator_score',
    );
  }

  Future<void> creatorScoreShared({String? surface}) {
    return track(
      eventName: 'creator_score_shared',
      surface: surface ?? 'creator_score',
    );
  }

  Future<void> profileShared({String? surface}) {
    return track(
      eventName: 'profile_shared',
      surface: surface ?? 'profile',
    );
  }

  Future<void> weeklyReportOpened({String? level}) {
    return track(
      eventName: 'weekly_report_opened',
      surface: 'weekly_report',
      metadata: <String, dynamic>{
        if (level != null && level.isNotEmpty) 'level': level,
      },
    );
  }

  Future<void> paywallViewed({String? upgradeTo}) {
    return track(
      eventName: 'paywall_viewed',
      surface: 'upgrade_sheet',
      metadata: <String, dynamic>{
        if (upgradeTo != null && upgradeTo.isNotEmpty) 'upgradeTo': upgradeTo,
      },
    );
  }

  Future<void> upgradeStarted({String? upgradeTo}) {
    return track(
      eventName: 'upgrade_started',
      surface: 'upgrade_sheet',
      metadata: <String, dynamic>{
        if (upgradeTo != null && upgradeTo.isNotEmpty) 'upgradeTo': upgradeTo,
      },
    );
  }

  Future<void> growthPlanCreated({String? planId}) {
    return track(
      eventName: 'growth_plan_created',
      surface: 'content_planning',
      metadata: <String, dynamic>{
        if (planId != null && planId.isNotEmpty) 'planId': planId,
      },
    );
  }
}
