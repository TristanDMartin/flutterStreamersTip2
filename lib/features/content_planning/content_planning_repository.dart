import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

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

  /// Single plan by Firestore document id (under `users/{userId}/contentPlans`).
  Future<ContentPlan?> getPlanById({
    required String idToken,
    required String userId,
    required String planId,
  });
}

class HttpContentPlanningRepository implements ContentPlanningRepository {
  HttpContentPlanningRepository({
    String? apiBase,
    http.Client? client,
  })  : _apiBase = _resolveApiBase(apiBase),
        _client = client ?? http.Client();

  static const String _envApiBase = String.fromEnvironment(
    'CONTENT_PLANNING_API_BASE',
    defaultValue: '',
  );

  final String _apiBase;
  final http.Client _client;

  static String _resolveApiBase(String? explicit) {
    final String configured = (explicit ?? _envApiBase).trim();
    if (configured.isNotEmpty) return configured;
    return 'https://streamerstip.com';
  }

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
  Future<ContentPlan?> getPlanById({
    required String idToken,
    required String userId,
    required String planId,
  }) async {
    return null;
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

  @override
  Future<List<ContentPlan>> listPlans({
    required String idToken,
    required String userId,
  }) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('contentPlans')
            .orderBy('createdAt', descending: true)
            .get();
      } on FirebaseException {
        snapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('contentPlans')
            .get();
      }
      final List<ContentPlan> plans = snapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            return ContentPlan.fromJson(<String, dynamic>{
              ...doc.data(),
              'id': doc.id,
            });
          })
          .where((ContentPlan plan) => plan.id.isNotEmpty)
          .toList(growable: false);
      plans.sort((ContentPlan a, ContentPlan b) {
        final DateTime? da = a.updatedAt;
        final DateTime? db = b.updatedAt;
        if (da == null && db == null) {
          return 0;
        }
        if (da == null) {
          return 1;
        }
        if (db == null) {
          return -1;
        }
        return db.compareTo(da);
      });
      return plans;
    } on FirebaseException catch (error) {
      throw ContentPlanningException(
        error.message ?? 'Could not read content plans.',
        statusCode: null,
      );
    }
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
      final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('contentPlans')
          .doc(planId)
          .get();
      if (!doc.exists) {
        return null;
      }
      final Map<String, dynamic>? data = doc.data();
      if (data == null) {
        return null;
      }
      return ContentPlan.fromJson(<String, dynamic>{
        ...data,
        'id': doc.id,
      });
    } on FirebaseException catch (error) {
      throw ContentPlanningException(
        error.message ?? 'Could not read that content plan.',
        statusCode: null,
      );
    }
  }
}
