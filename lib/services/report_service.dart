import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as dev;

/// Service for handling video and user reports
class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Report a video with specific reason
  Future<void> reportVideo({
    required String videoId,
    required String creatorId,
    required String reason,
    String? additionalDetails,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated to report content');
      }

      final reportData = {
        'videoId': videoId,
        'creatorId': creatorId,
        'reporterId': currentUser.uid,
        'reason': reason,
        'additionalDetails': additionalDetails,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, reviewed, resolved, dismissed
        'reviewedBy': null,
        'reviewedAt': null,
        'actionTaken': null,
      };

      // Add report to reports collection
      await _firestore.collection('reports').add(reportData);

      // Update video report count
      await _firestore.collection('videos').doc(videoId).update({
        'reportCount': FieldValue.increment(1),
        'lastReportedAt': FieldValue.serverTimestamp(),
      });

      // Update creator report count
      await _firestore.collection('users').doc(creatorId).update({
        'reportCount': FieldValue.increment(1),
        'lastReportedAt': FieldValue.serverTimestamp(),
      });

      dev.log('📋 ReportService: Video report submitted successfully',
          name: 'ReportService');
    } catch (e) {
      dev.log('❌ ReportService: Error reporting video: $e',
          name: 'ReportService');
      rethrow;
    }
  }

  /// Report a user with specific reason
  Future<void> reportUser({
    required String userId,
    required String reason,
    String? additionalDetails,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated to report content');
      }

      final reportData = {
        'userId': userId,
        'reporterId': currentUser.uid,
        'reason': reason,
        'additionalDetails': additionalDetails,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'reviewedBy': null,
        'reviewedAt': null,
        'actionTaken': null,
      };

      // Add report to user_reports collection
      await _firestore.collection('user_reports').add(reportData);

      // Update user report count
      await _firestore.collection('users').doc(userId).update({
        'reportCount': FieldValue.increment(1),
        'lastReportedAt': FieldValue.serverTimestamp(),
      });

      dev.log('📋 ReportService: User report submitted successfully',
          name: 'ReportService');
    } catch (e) {
      dev.log('❌ ReportService: Error reporting user: $e',
          name: 'ReportService');
      rethrow;
    }
  }

  /// Get report statistics for a video
  Future<Map<String, dynamic>> getVideoReportStats(String videoId) async {
    try {
      final reportsQuery = await _firestore
          .collection('reports')
          .where('videoId', isEqualTo: videoId)
          .get();

      final reports = reportsQuery.docs;
      final reasonCounts = <String, int>{};

      for (final doc in reports) {
        final reason = doc.data()['reason'] as String? ?? 'Unknown';
        reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
      }

      return {
        'totalReports': reports.length,
        'reasonCounts': reasonCounts,
        'lastReported': reports.isNotEmpty
            ? reports
                .map((doc) => doc.data()['timestamp'])
                .reduce((a, b) => a.compareTo(b) > 0 ? a : b)
            : null,
      };
    } catch (e) {
      dev.log('❌ ReportService: Error getting video report stats: $e',
          name: 'ReportService');
      return {
        'totalReports': 0,
        'reasonCounts': <String, int>{},
        'lastReported': null,
      };
    }
  }

  /// Check if user has already reported this video
  Future<bool> hasUserReportedVideo(String videoId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final existingReport = await _firestore
          .collection('reports')
          .where('videoId', isEqualTo: videoId)
          .where('reporterId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      return existingReport.docs.isNotEmpty;
    } catch (e) {
      dev.log('❌ ReportService: Error checking if user reported video: $e',
          name: 'ReportService');
      return false;
    }
  }

  /// Get available report reasons
  List<String> getReportReasons() {
    return [
      'Spam',
      'Nudity or sexual activity',
      'Violence or dangerous acts',
      'Hate speech or harassment',
      'Dangerous goods or services',
      'Bullying or harassment',
      'Intellectual property violation',
      'False information',
      'Self-harm or suicide',
      'Terrorism',
      'Other',
    ];
  }
}
