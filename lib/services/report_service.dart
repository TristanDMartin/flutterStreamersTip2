import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:streamers_tip/utils/secure_log.dart';

/// Service for handling video and user reports
class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> _requireReporterId() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be authenticated to report content');
    }
    return currentUser.uid;
  }

  Future<void> _submitContentReport(Map<String, dynamic> reportData) async {
    await _firestore.collection('reports').add({
      ...reportData,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
      'reviewedBy': null,
      'reviewedAt': null,
      'actionTaken': null,
    });
  }

  /// Report a video with specific reason
  Future<void> reportVideo({
    required String videoId,
    required String creatorId,
    required String reason,
    String? additionalDetails,
  }) async {
    try {
      final reporterId = await _requireReporterId();

      final reportData = {
        'reportType': 'video',
        'videoId': videoId,
        'creatorId': creatorId,
        'reporterId': reporterId,
        'reason': reason,
        'additionalDetails': additionalDetails,
      };

      await _submitContentReport(reportData);

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

      secureLog('📋 ReportService: Video report submitted successfully',
          name: 'ReportService');
    } catch (e) {
      secureLog('❌ ReportService: Error reporting video: $e',
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
      final reporterId = await _requireReporterId();

      final reportData = {
        'userId': userId,
        'reporterId': reporterId,
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

      secureLog('📋 ReportService: User report submitted successfully',
          name: 'ReportService');
    } catch (e) {
      secureLog('❌ ReportService: Error reporting user: $e',
          name: 'ReportService');
      rethrow;
    }
  }

  Future<void> reportComment({
    required String videoId,
    required String commentId,
    required String commentAuthorId,
    required String reason,
    String? additionalDetails,
  }) async {
    try {
      final reporterId = await _requireReporterId();

      await _submitContentReport({
        'reportType': 'videoComment',
        'videoId': videoId,
        'commentId': commentId,
        'creatorId': commentAuthorId,
        'reporterId': reporterId,
        'reason': reason,
        'additionalDetails': additionalDetails,
      });

      await _firestore.collection('videos').doc(videoId).update({
        'commentReportCount': FieldValue.increment(1),
        'lastReportedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(commentAuthorId).update({
        'reportCount': FieldValue.increment(1),
        'lastReportedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      secureLog('❌ ReportService: Error reporting comment: $e',
          name: 'ReportService');
      rethrow;
    }
  }

  Future<void> reportThread({
    required String postId,
    required String authorId,
    required String reason,
    String? additionalDetails,
  }) async {
    try {
      final reporterId = await _requireReporterId();

      await _submitContentReport({
        'reportType': 'thread',
        'postId': postId,
        'creatorId': authorId,
        'reporterId': reporterId,
        'reason': reason,
        'additionalDetails': additionalDetails,
      });

      await _firestore.collection('forumPosts').doc(postId).update({
        'reportCount': FieldValue.increment(1),
        'lastReportedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(authorId).update({
        'reportCount': FieldValue.increment(1),
        'lastReportedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      secureLog('❌ ReportService: Error reporting thread: $e',
          name: 'ReportService');
      rethrow;
    }
  }

  Future<void> reportThreadComment({
    required String postId,
    required String commentId,
    required String commentAuthorId,
    required String reason,
    String? additionalDetails,
  }) async {
    try {
      final reporterId = await _requireReporterId();

      await _submitContentReport({
        'reportType': 'threadComment',
        'postId': postId,
        'commentId': commentId,
        'creatorId': commentAuthorId,
        'reporterId': reporterId,
        'reason': reason,
        'additionalDetails': additionalDetails,
      });

      await _firestore.collection('forumPosts').doc(postId).update({
        'commentReportCount': FieldValue.increment(1),
        'lastReportedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(commentAuthorId).update({
        'reportCount': FieldValue.increment(1),
        'lastReportedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      secureLog('❌ ReportService: Error reporting thread comment: $e',
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
      secureLog('❌ ReportService: Error getting video report stats: $e',
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
      secureLog('❌ ReportService: Error checking if user reported video: $e',
          name: 'ReportService');
      return false;
    }
  }

  Future<bool> hasUserReportedComment({
    required String videoId,
    required String commentId,
  }) async {
    try {
      final reporterId = await _requireReporterId();
      final existingReport = await _firestore
          .collection('reports')
          .where('reportType', isEqualTo: 'videoComment')
          .where('videoId', isEqualTo: videoId)
          .where('commentId', isEqualTo: commentId)
          .where('reporterId', isEqualTo: reporterId)
          .limit(1)
          .get();
      return existingReport.docs.isNotEmpty;
    } catch (e) {
      secureLog('❌ ReportService: Error checking comment report status: $e',
          name: 'ReportService');
      return false;
    }
  }

  Future<bool> hasUserReportedThread(String postId) async {
    try {
      final reporterId = await _requireReporterId();
      final existingReport = await _firestore
          .collection('reports')
          .where('reportType', isEqualTo: 'thread')
          .where('postId', isEqualTo: postId)
          .where('reporterId', isEqualTo: reporterId)
          .limit(1)
          .get();
      return existingReport.docs.isNotEmpty;
    } catch (e) {
      secureLog('❌ ReportService: Error checking thread report status: $e',
          name: 'ReportService');
      return false;
    }
  }

  Future<bool> hasUserReportedThreadComment({
    required String postId,
    required String commentId,
  }) async {
    try {
      final reporterId = await _requireReporterId();
      final existingReport = await _firestore
          .collection('reports')
          .where('reportType', isEqualTo: 'threadComment')
          .where('postId', isEqualTo: postId)
          .where('commentId', isEqualTo: commentId)
          .where('reporterId', isEqualTo: reporterId)
          .limit(1)
          .get();
      return existingReport.docs.isNotEmpty;
    } catch (e) {
      secureLog('❌ ReportService: Error checking thread comment report status: $e',
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
