import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/backend/http_api_base_url.dart';
import 'content_planning_models.dart';

class ContentPlanningException implements Exception {
  const ContentPlanningException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ContentPlanningException($statusCode): $message';
}

abstract class ContentPlanningRepository {
  Future<List<ContentPlan>> listPlans({
    required String idToken,
    required String userId,
  });

  Stream<List<ContentPlan>> watchPlans({
    required String userId,
  });

  /// Single plan by Firestore document id (`users/{userId}/contentPlans/{id}`
  /// or top-level `contentPlans/{id}`).
  Future<ContentPlan?> getPlanById({
    required String idToken,
    required String userId,
    required String planId,
  });

  Future<void> updatePlan({
    required String userId,
    required ContentPlan plan,
  });
}

class HttpContentPlanningRepository implements ContentPlanningRepository {
  HttpContentPlanningRepository({
    String? apiBase,
    http.Client? client,
  })  : _apiBase = resolveHttpApiBaseUrl(
          explicitOverride: apiBase,
          envDefineValue: _envApiBase,
        ),
        _client = client ?? http.Client();

  static const String _envApiBase = String.fromEnvironment(
    'CONTENT_PLANNING_API_BASE',
    defaultValue: '',
  );

  final String _apiBase;
  final http.Client _client;

  @override
  Future<List<ContentPlan>> listPlans({
    required String idToken,
    required String userId,
  }) async {
    final Uri uri = _buildUri('/api/content-planning/plans', <String, String>{
      'userId': userId,
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
      throw ContentPlanningException(
        'Content planning request failed.',
        statusCode: response.statusCode,
      );
    }
    if (body == null || body['success'] == false) {
      throw const ContentPlanningException(
          'Unexpected content planning response.');
    }
    final Object? rawPlans = body['plans'] ?? body['data'];
    if (rawPlans is! List) {
      return const <ContentPlan>[];
    }
    return rawPlans
        .whereType<Map<String, dynamic>>()
        .map(ContentPlan.fromJson)
        .where((ContentPlan plan) => plan.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Stream<List<ContentPlan>> watchPlans({
    required String userId,
  }) {
    return const Stream<List<ContentPlan>>.empty();
  }

  @override
  Future<ContentPlan?> getPlanById({
    required String idToken,
    required String userId,
    required String planId,
  }) async {
    return null;
  }

  @override
  Future<void> updatePlan({
    required String userId,
    required ContentPlan plan,
  }) async {
    throw const ContentPlanningException('Remote plan editing is unavailable.');
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

class FirestoreContentPlanningRepository implements ContentPlanningRepository {
  FirestoreContentPlanningRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _userContentPlansRef(
    String userId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('contentPlans');
  }

  ContentPlan _planFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String userId,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return ContentPlan.fromJson(<String, dynamic>{
      ...data,
      'ownerUid': data['ownerUid'] ?? data['userId'] ?? userId,
      'userId': data['userId'] ?? data['ownerUid'] ?? userId,
      'id': doc.id,
    });
  }

  DateTime? _planSortTime(ContentPlan plan) {
    return plan.updatedAt ?? plan.createdAt ?? plan.scheduledAt;
  }

  bool _planIsNewerThan(ContentPlan candidate, ContentPlan existing) {
    final DateTime? c = _planSortTime(candidate);
    final DateTime? e = _planSortTime(existing);
    if (c == null) {
      return false;
    }
    if (e == null) {
      return true;
    }
    return c.isAfter(e);
  }

  int _comparePlans(ContentPlan a, ContentPlan b) {
    final DateTime? aScheduled = a.scheduledAt;
    final DateTime? bScheduled = b.scheduledAt;
    if (aScheduled != null && bScheduled != null) {
      return aScheduled.compareTo(bScheduled);
    }
    if (aScheduled != null) return -1;
    if (bScheduled != null) return 1;
    final DateTime? da = a.createdAt ?? a.updatedAt;
    final DateTime? db = b.createdAt ?? b.updatedAt;
    if (da == null && db == null) return a.title.compareTo(b.title);
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _queryUserSubPlans(
    String userId,
  ) async {
    try {
      return await _userContentPlansRef(userId)
          .orderBy('updatedAt', descending: true)
          .get();
    } on FirebaseException {
      return _userContentPlansRef(userId).get();
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _queryTopLevelPlans(
    String userId,
  ) async {
    try {
      return await _firestore
          .collection('contentPlans')
          .where('userId', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .get();
    } on FirebaseException {
      return _firestore
          .collection('contentPlans')
          .where('userId', isEqualTo: userId)
          .get();
    }
  }

  @override
  Future<List<ContentPlan>> listPlans({
    required String idToken,
    required String userId,
  }) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> userSubSnap =
          await _queryUserSubPlans(userId);
      final QuerySnapshot<Map<String, dynamic>> topSnap =
          await _queryTopLevelPlans(userId);
      final Map<String, ContentPlan> byId = <String, ContentPlan>{};
      void ingest(QuerySnapshot<Map<String, dynamic>> snap) {
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snap.docs) {
          final ContentPlan plan = _planFromDoc(doc, userId);
          if (plan.id.isEmpty) {
            continue;
          }
          final ContentPlan? existing = byId[plan.id];
          if (existing == null || _planIsNewerThan(plan, existing)) {
            byId[plan.id] = plan;
          }
        }
      }

      ingest(userSubSnap);
      ingest(topSnap);
      final List<ContentPlan> plans = byId.values.toList(growable: false);
      plans.sort(_comparePlans);
      debugPrint(
        'ContentPlannerView loaded ${plans.length} plans; '
        '${plans.where((p) => p.source == 'tippy_ai').length} tippy_ai; '
        'filters=none path=users/$userId/contentPlans + legacy contentPlans',
      );
      return plans;
    } on FirebaseException catch (error) {
      throw ContentPlanningException(
        error.message ?? 'Could not read content plans.',
        statusCode: null,
      );
    }
  }

  @override
  Stream<List<ContentPlan>> watchPlans({
    required String userId,
  }) {
    debugPrint('ContentPlannerView listening path: users/$userId/contentPlans');
    late final StreamController<List<ContentPlan>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? userSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? topLevelSub;
    QuerySnapshot<Map<String, dynamic>>? latestUserSub;
    QuerySnapshot<Map<String, dynamic>>? latestTopLevel;

    void emit() {
      final Map<String, ContentPlan> byId = <String, ContentPlan>{};
      void ingest(QuerySnapshot<Map<String, dynamic>>? snap) {
        if (snap == null) return;
        for (final DocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
          final ContentPlan plan = _planFromDoc(doc, userId);
          if (plan.id.isEmpty) continue;
          final ContentPlan? existing = byId[plan.id];
          if (existing == null || _planIsNewerThan(plan, existing)) {
            byId[plan.id] = plan;
          }
        }
      }

      ingest(latestUserSub);
      ingest(latestTopLevel);
      final List<ContentPlan> plans = byId.values.toList(growable: false)
        ..sort(_comparePlans);
      if (!controller.isClosed) {
        debugPrint(
          'ContentPlannerView snapshot loaded ${plans.length} plans; '
          '${plans.where((p) => p.source == 'tippy_ai').length} tippy_ai; '
          'filters=none',
        );
        controller.add(plans);
      }
    }

    controller = StreamController<List<ContentPlan>>(
      onListen: () {
        userSub = _userContentPlansRef(userId).snapshots().listen(
          (QuerySnapshot<Map<String, dynamic>> snap) {
            latestUserSub = snap;
            emit();
          },
          onError: controller.addError,
        );
        topLevelSub = _firestore
            .collection('contentPlans')
            .where('userId', isEqualTo: userId)
            .snapshots()
            .listen(
          (QuerySnapshot<Map<String, dynamic>> snap) {
            latestTopLevel = snap;
            emit();
          },
          onError: (Object error, StackTrace stack) {
            debugPrint('Legacy contentPlans listener skipped: $error');
          },
        );
      },
      onCancel: () async {
        await userSub?.cancel();
        await topLevelSub?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<ContentPlan?> getPlanById({
    required String idToken,
    required String userId,
    required String planId,
  }) async {
    if (planId.isEmpty) {
      return null;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _userContentPlansRef(userId).doc(planId).get();
      if (userDoc.exists) {
        final Map<String, dynamic>? data = userDoc.data();
        if (data != null) {
          return ContentPlan.fromJson(<String, dynamic>{
            ...data,
            'userId': data['userId'] ?? userId,
            'id': userDoc.id,
          });
        }
      }
      final DocumentSnapshot<Map<String, dynamic>> topDoc =
          await _firestore.collection('contentPlans').doc(planId).get();
      if (!topDoc.exists) {
        return null;
      }
      final Map<String, dynamic>? data = topDoc.data();
      if (data == null) {
        return null;
      }
      return ContentPlan.fromJson(<String, dynamic>{
        ...data,
        'userId': data['userId'] ?? userId,
        'id': topDoc.id,
      });
    } on FirebaseException catch (error) {
      throw ContentPlanningException(
        error.message ?? 'Could not read that content plan.',
        statusCode: null,
      );
    }
  }

  @override
  Future<void> updatePlan({
    required String userId,
    required ContentPlan plan,
  }) async {
    if (plan.id.isEmpty) {
      throw const ContentPlanningException('Plan id is required.');
    }
    final Map<String, dynamic> update = plan.toUpdateJson()
      ..addAll(<String, dynamic>{
        'userId': userId,
        'ownerUid': userId,
        'source': plan.source ?? 'app',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    final DocumentSnapshot<Map<String, dynamic>> userDoc =
        await _userContentPlansRef(userId).doc(plan.id).get();
    if (userDoc.exists) {
      await _userContentPlansRef(userId).doc(plan.id).set(
            update,
            SetOptions(merge: true),
          );
      return;
    }
    await _firestore.collection('contentPlans').doc(plan.id).set(
          update,
          SetOptions(merge: true),
        );
  }
}
