import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:streamers_tip/utils/secure_log.dart';

/// Result of a server-side report submission.
class ReportSubmission {
  const ReportSubmission({required this.reportId, required this.isDuplicate});

  final String reportId;
  final bool isDuplicate;
}

/// Submits moderation reports through the `submitReport` callable; the server
/// resolves content owners, dedupes, rate-limits, and maintains counters.
class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<String> _requireReporterId() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be authenticated to report content');
    }
    return currentUser.uid;
  }

  Future<ReportSubmission> _submitReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? additionalDetails,
    String? videoId,
    String? postId,
    String? chatId,
  }) async {
    await _requireReporterId();
    try {
      final HttpsCallableResult<dynamic> result =
          await _functions.httpsCallable('submitReport').call(<String, dynamic>{
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        if (additionalDetails != null) 'details': additionalDetails,
        if (videoId != null) 'videoId': videoId,
        if (postId != null) 'postId': postId,
        if (chatId != null) 'chatId': chatId,
      });
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(result.data as Map);
      secureLog('📋 ReportService: $targetType report submitted',
          name: 'ReportService');
      return ReportSubmission(
        reportId: data['reportId'] as String? ?? '',
        isDuplicate: data['duplicate'] == true,
      );
    } catch (e) {
      secureLog('❌ ReportService: Error reporting $targetType: $e',
          name: 'ReportService');
      rethrow;
    }
  }

  /// Report a video. [creatorId] is ignored; the server resolves the owner.
  Future<ReportSubmission> reportVideo({
    required String videoId,
    String? creatorId,
    required String reason,
    String? additionalDetails,
  }) =>
      _submitReport(
        targetType: 'video',
        targetId: videoId,
        reason: reason,
        additionalDetails: additionalDetails,
      );

  /// Report a user. Pass [chatId] from DMs so the server can attach recent
  /// messages from that user as moderation evidence.
  Future<ReportSubmission> reportUser({
    required String userId,
    required String reason,
    String? additionalDetails,
    String? chatId,
  }) =>
      _submitReport(
        targetType: 'user',
        targetId: userId,
        reason: reason,
        additionalDetails: additionalDetails,
        chatId: chatId,
      );

  Future<ReportSubmission> reportMessage({
    required String chatId,
    required String messageId,
    required String reason,
    String? additionalDetails,
  }) =>
      _submitReport(
        targetType: 'message',
        targetId: messageId,
        reason: reason,
        additionalDetails: additionalDetails,
        chatId: chatId,
      );

  Future<ReportSubmission> reportComment({
    required String videoId,
    required String commentId,
    String? commentAuthorId,
    required String reason,
    String? additionalDetails,
  }) =>
      _submitReport(
        targetType: 'videoComment',
        targetId: commentId,
        reason: reason,
        additionalDetails: additionalDetails,
        videoId: videoId,
      );

  Future<ReportSubmission> reportThread({
    required String postId,
    String? authorId,
    required String reason,
    String? additionalDetails,
  }) =>
      _submitReport(
        targetType: 'thread',
        targetId: postId,
        reason: reason,
        additionalDetails: additionalDetails,
      );

  Future<ReportSubmission> reportThreadComment({
    required String postId,
    required String commentId,
    String? commentAuthorId,
    required String reason,
    String? additionalDetails,
  }) =>
      _submitReport(
        targetType: 'threadComment',
        targetId: commentId,
        reason: reason,
        additionalDetails: additionalDetails,
        postId: postId,
      );

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
      secureLog(
          '❌ ReportService: Error checking thread comment report status: $e',
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
