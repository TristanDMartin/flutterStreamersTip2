import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../services/admin_service.dart';

/// Callable Cloud Functions (`us-central1`): server accepts JWT `admin`
/// claim or Firestore user-doc admin fields (same model as client rules).
class AdminBackendService {
  AdminBackendService._();

  static final FirebaseFunctions _fn =
      FirebaseFunctions.instanceFor(region: 'us-central1');
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<Map<String, dynamic>> execute(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final HttpsCallable callable = _fn.httpsCallable('adminExecute');
    final HttpsCallableResult result = await callable.call(<String, dynamic>{
      'action': action,
      'payload': payload,
    });
    final Object? data = result.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> dashboardStats() async {
    try {
      return await _fetchCloudDashboardStats();
    } catch (e) {
      debugPrint('ADMIN_SYNC_STATE phase=dashboard_cloud_error error=$e');
      final bool granted = await AdminService.instance.resolveAdminAccess();
      if (!granted) {
        rethrow;
      }
      final String? code = _cloudFunctionErrorCode(e);
      if (code == 'invalid-argument') {
        rethrow;
      }
      await AdminService.instance.refreshIdTokenForAdminSession();
      debugPrint(
        'ADMIN_FINAL_DECISION=granted source=client_dashboard_fallback '
        'code=${code ?? 'unknown'}',
      );
      return _fetchFirestoreDashboardStats();
    }
  }

  static String? _cloudFunctionErrorCode(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.code;
    }
    if (error is FirebaseException) {
      return error.code;
    }
    if (error is PlatformException) {
      final Object? details = error.details;
      if (details is Map) {
        final Object? code = details['code'];
        if (code is String && code.isNotEmpty) {
          return code;
        }
      }
      final String haystack =
          '${error.code} ${error.message ?? ''} ${error.details ?? ''}'
              .toLowerCase();
      for (final String token in <String>[
        'permission-denied',
        'not-found',
        'unavailable',
        'unauthenticated',
        'internal',
        'failed-precondition',
        'deadline-exceeded',
      ]) {
        if (haystack.contains(token)) {
          return token;
        }
      }
    }
    final String text = error.toString().toLowerCase();
    for (final String token in <String>[
      'permission-denied',
      'not-found',
      'unavailable',
      'unauthenticated',
    ]) {
      if (text.contains(token)) {
        return token;
      }
    }
    if (text.contains('firebase_functions')) {
      return 'unknown';
    }
    return null;
  }

  static Future<Map<String, dynamic>> _fetchCloudDashboardStats() async {
    final HttpsCallable callable = _fn.httpsCallable('adminDashboardStats');
    final HttpsCallableResult result = await callable.call();
    final Object? data = result.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  static Future<int> _countWhere(
    String collection,
    String field,
    Object value,
  ) async {
    try {
      final AggregateQuerySnapshot snap = await _firestore
          .collection(collection)
          .where(field, isEqualTo: value)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint(
        '⚠️ client dashboard count $collection/$field=$value: $e',
      );
      return 0;
    }
  }

  static Future<Map<String, dynamic>> _fetchFirestoreDashboardStats() async {
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, now.day);
    int newUsersToday = 0;
    try {
      final AggregateQuerySnapshot snap = await _firestore
          .collection('users')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .count()
          .get();
      newUsersToday = snap.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ client dashboard newUsersToday: $e');
    }
    final List<int> counts = await Future.wait<int>(<Future<int>>[
      _countWhere('reports', 'status', 'open'),
      _countWhere('videos', 'moderationStatus', 'flagged'),
      _countWhere('videos', 'status', 'failed'),
      _countWhere('users', 'accountStatus', 'banned'),
      _countWhere('videos', 'status', 'processing'),
      _countCollection('videos'),
    ]);
    return <String, dynamic>{
      'openReports': counts[0],
      'flaggedVideos': counts[1],
      'failedUploads': counts[2],
      'bannedUsers': counts[3],
      'processingVideos': counts[4],
      'totalUploads': counts[5],
      'newUsersToday': newUsersToday,
    };
  }

  static Future<Map<String, dynamic>> creatorIntelligenceStats() async {
    try {
      final HttpsCallable callable = _fn.httpsCallable('adminDashboardStats');
      final HttpsCallableResult result = await callable.call();
      final Object? data = result.data;
      if (data is Map<String, dynamic>) {
        final Object? ci = data['creatorIntelligence'];
        if (ci is Map<String, dynamic>) {
          return ci;
        }
      }
      if (data is Map) {
        final Object? ci = data['creatorIntelligence'];
        if (ci is Map) {
          return Map<String, dynamic>.from(ci);
        }
      }
      return <String, dynamic>{};
    } catch (e) {
      debugPrint('creatorIntelligenceStats error: $e');
      rethrow;
    }
  }

  static Future<int> _countCollection(String collection) async {
    try {
      final AggregateQuerySnapshot snap =
          await _firestore.collection(collection).count().get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ client dashboard count $collection: $e');
      return 0;
    }
  }
}
