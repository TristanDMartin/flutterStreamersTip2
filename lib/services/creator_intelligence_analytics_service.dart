import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/analytics/models/analytics_profile.dart';
import '../shared/analytics/analytics_event_constants.dart';

/// Firestore-backed Creator Intelligence event tracking (canonical schema).
/// Distinct from [AnalyticsService] (Firebase Analytics / Crashlytics).
class CreatorIntelligenceAnalyticsService {
  CreatorIntelligenceAnalyticsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String _eventsCollection = 'analytics_events';

  DocumentReference<Map<String, dynamic>> _profileRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('analyticsProfile')
        .doc(kAnalyticsProfileDocId);
  }

  Future<void> trackEvent({
    required String eventType,
    required String targetType,
    String? targetId,
    Map<String, dynamic>? metadata,
    String source = AnalyticsSources.app,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return;
    }
    try {
      await _firestore.collection(_eventsCollection).add(<String, dynamic>{
        'uid': user.uid,
        'eventType': eventType,
        'source': source,
        'targetType': targetType,
        if (targetId != null && targetId.isNotEmpty) 'targetId': targetId,
        'metadata': metadata ?? <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('CreatorIntelligenceAnalytics trackEvent failed: $e');
    }
  }

  Stream<AnalyticsProfile> watchProfile({String? uid}) {
    final String? resolvedUid = uid ?? _auth.currentUser?.uid;
    if (resolvedUid == null) {
      return Stream<AnalyticsProfile>.value(AnalyticsProfile.empty);
    }
    return _profileRef(resolvedUid).snapshots().map(
          (DocumentSnapshot<Map<String, dynamic>> snap) =>
              AnalyticsProfile.fromFirestore(snap.data()),
        );
  }

  Future<AnalyticsProfile> loadProfile({String? uid}) async {
    final String? resolvedUid = uid ?? _auth.currentUser?.uid;
    if (resolvedUid == null) {
      return AnalyticsProfile.empty;
    }
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await _profileRef(resolvedUid).get();
    return AnalyticsProfile.fromFirestore(snap.data());
  }

  Future<List<Map<String, dynamic>>> loadRecentEvents({
    required int windowDays,
    int limit = 200,
    String? uid,
  }) async {
    final String? resolvedUid = uid ?? _auth.currentUser?.uid;
    if (resolvedUid == null) {
      return <Map<String, dynamic>>[];
    }
    final DateTime cutoff =
        DateTime.now().subtract(Duration(days: windowDays < 1 ? 1 : windowDays));
    try {
      final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
          .collection(_eventsCollection)
          .where('uid', isEqualTo: resolvedUid)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            final Map<String, dynamic> data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            return data;
          })
          .toList();
    } catch (e) {
      debugPrint('CreatorIntelligenceAnalytics loadRecentEvents failed: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> trackVideoViewed({
    required String videoId,
    Map<String, dynamic>? metadata,
  }) {
    return trackEvent(
      eventType: AnalyticsEventTypes.videoViewed,
      targetType: AnalyticsTargetTypes.video,
      targetId: videoId,
      metadata: metadata,
    );
  }

  Future<void> trackVideoCompleted({
    required String videoId,
    Map<String, dynamic>? metadata,
  }) {
    return trackEvent(
      eventType: AnalyticsEventTypes.videoCompleted,
      targetType: AnalyticsTargetTypes.video,
      targetId: videoId,
      metadata: metadata,
    );
  }

  Future<void> trackVideoSkipped({
    required String videoId,
    Map<String, dynamic>? metadata,
  }) {
    return trackEvent(
      eventType: AnalyticsEventTypes.videoSkipped,
      targetType: AnalyticsTargetTypes.video,
      targetId: videoId,
      metadata: metadata,
    );
  }

  Future<void> trackPostLiked({required String videoId}) {
    return trackEvent(
      eventType: AnalyticsEventTypes.postLiked,
      targetType: AnalyticsTargetTypes.video,
      targetId: videoId,
    );
  }

  Future<void> trackPostSaved({required String videoId}) {
    return trackEvent(
      eventType: AnalyticsEventTypes.postSaved,
      targetType: AnalyticsTargetTypes.video,
      targetId: videoId,
    );
  }

  Future<void> trackSearchPerformed({
    required String query,
    int? resultsCount,
  }) {
    return trackEvent(
      eventType: AnalyticsEventTypes.searchPerformed,
      targetType: AnalyticsTargetTypes.tool,
      metadata: <String, dynamic>{
        'query': query,
        if (resultsCount != null) 'resultsCount': resultsCount,
      },
    );
  }

  Future<void> trackTippyQuestionAsked({String? conversationId}) {
    return trackEvent(
      eventType: AnalyticsEventTypes.tippyQuestionAsked,
      targetType: AnalyticsTargetTypes.tool,
      targetId: conversationId,
      metadata: const <String, dynamic>{'surface': 'tippy_chat'},
    );
  }

  Future<void> trackToolOpened({
    required String toolId,
    Map<String, dynamic>? metadata,
  }) {
    return trackEvent(
      eventType: AnalyticsEventTypes.toolOpened,
      targetType: AnalyticsTargetTypes.tool,
      targetId: toolId,
      metadata: metadata,
    );
  }

  Future<void> trackSubscriptionGateSeen({required String feature}) {
    return trackEvent(
      eventType: AnalyticsEventTypes.subscriptionGateSeen,
      targetType: AnalyticsTargetTypes.tool,
      metadata: <String, dynamic>{'feature': feature},
    );
  }

  Future<void> trackCommentCreated({
    required String videoId,
    String? commentId,
  }) {
    return trackEvent(
      eventType: AnalyticsEventTypes.commentCreated,
      targetType: AnalyticsTargetTypes.video,
      targetId: videoId,
      metadata: <String, dynamic>{
        if (commentId != null) 'commentId': commentId,
      },
    );
  }

  Future<void> trackProfileViewed({required String profileUserId}) {
    return trackEvent(
      eventType: AnalyticsEventTypes.profileViewed,
      targetType: AnalyticsTargetTypes.profile,
      targetId: profileUserId,
    );
  }

  Future<void> trackCreatorCardOpened({required String creatorId}) {
    return trackEvent(
      eventType: AnalyticsEventTypes.creatorCardOpened,
      targetType: AnalyticsTargetTypes.profile,
      targetId: creatorId,
    );
  }

  Future<void> trackContentPlanCreated({String? planId}) {
    return trackEvent(
      eventType: AnalyticsEventTypes.contentPlanCreated,
      targetType: AnalyticsTargetTypes.tool,
      targetId: planId,
      metadata: const <String, dynamic>{'surface': 'content_planner'},
    );
  }

  Future<void> trackPlatformConnected({required String platform}) {
    return trackEvent(
      eventType: AnalyticsEventTypes.platformConnected,
      targetType: AnalyticsTargetTypes.tool,
      targetId: platform,
    );
  }

  Future<void> trackSubscriptionStarted({String? tier}) {
    return trackEvent(
      eventType: AnalyticsEventTypes.subscriptionStarted,
      targetType: AnalyticsTargetTypes.tool,
      metadata: <String, dynamic>{
        if (tier != null) 'tier': tier,
      },
    );
  }

  Future<void> trackSubscriptionCancelled({String? tier}) {
    return trackEvent(
      eventType: AnalyticsEventTypes.subscriptionCancelled,
      targetType: AnalyticsTargetTypes.tool,
      metadata: <String, dynamic>{
        if (tier != null) 'tier': tier,
      },
    );
  }

  Future<void> trackPersonalizationCtaTapped({
    required String uiSurface,
    required String ctaSurface,
    required List<String> creatorGoals,
    required List<String> platforms,
  }) {
    return trackEvent(
      eventType: AnalyticsEventTypes.personalizationCtaTapped,
      targetType: AnalyticsTargetTypes.personalization,
      targetId: ctaSurface,
      metadata: <String, dynamic>{
        'uiSurface': uiSurface,
        'ctaSurface': ctaSurface,
        'creatorGoals': creatorGoals,
        'platforms': platforms,
        if (creatorGoals.isNotEmpty) 'primaryGoal': creatorGoals.first,
      },
    );
  }
}

final Provider<CreatorIntelligenceAnalyticsService>
    creatorIntelligenceAnalyticsProvider =
    Provider<CreatorIntelligenceAnalyticsService>((Ref ref) {
  return CreatorIntelligenceAnalyticsService();
});

final StreamProvider<AnalyticsProfile> analyticsProfileProvider =
    StreamProvider<AnalyticsProfile>((Ref ref) {
  final CreatorIntelligenceAnalyticsService service =
      ref.watch(creatorIntelligenceAnalyticsProvider);
  return service.watchProfile();
});
