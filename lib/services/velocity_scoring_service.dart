import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Velocity-based scoring service - Rewards fast-growing content
/// Implements engagement velocity, viral coefficient, and comment quality
class VelocityScoringService {
  static VelocityScoringService? _instance;
  static VelocityScoringService get instance =>
      _instance ??= VelocityScoringService._();

  VelocityScoringService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate velocity-based boost for a video
  Future<double> calculateVelocityBoost(String videoId) async {
    try {
      double multiplier = 1.0;

      // 1. Engagement velocity (likes/views over time)
      final engagementVelocity = await _calculateEngagementVelocity(videoId);
      if (engagementVelocity > 0.5) {
        multiplier *= (1.0 + engagementVelocity); // Up to 2x boost
        log('⚡ Engagement velocity boost: ${engagementVelocity.toStringAsFixed(2)} - ${multiplier.toStringAsFixed(2)}x');
      }

      // 2. Viral coefficient (shares per view ratio)
      final viralCoefficient = await _calculateViralCoefficient(videoId);
      if (viralCoefficient > 0.1) {
        multiplier *= (1.0 + (viralCoefficient * 2)); // Up to 3x boost
        log('🚀 Viral coefficient boost: ${viralCoefficient.toStringAsFixed(2)} - ${multiplier.toStringAsFixed(2)}x');
      }

      // 3. Comment quality score
      final commentQuality = await _calculateCommentQuality(videoId);
      if (commentQuality > 0.6) {
        multiplier *= (1.0 + (commentQuality * 0.5)); // Up to 1.5x boost
        log('💬 Comment quality boost: ${commentQuality.toStringAsFixed(2)} - ${multiplier.toStringAsFixed(2)}x');
      }

      // 4. Time-to-first-action (faster = better)
      final timeToAction = await _calculateTimeToFirstAction(videoId);
      if (timeToAction > 0.7) {
        multiplier *= 1.3; // Fast initial engagement
        log('⏱️ Time-to-action boost: ${timeToAction.toStringAsFixed(2)} - 1.3x');
      }

      log('✅ Total velocity boost for $videoId: ${multiplier.toStringAsFixed(2)}x');
      return multiplier;
    } catch (e) {
      log('❌ Error calculating velocity boost: $e');
      return 1.0;
    }
  }

  /// Calculate engagement velocity (rate of likes/views over time)
  Future<double> _calculateEngagementVelocity(String videoId) async {
    try {
      // Get video creation time
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();

      if (!videoDoc.exists) return 0.0;

      final createdAt = (videoDoc.data()?['createdAt'] as Timestamp?)?.toDate();
      if (createdAt == null) return 0.0;

      final hoursSinceCreation = DateTime.now().difference(createdAt).inHours;
      if (hoursSinceCreation == 0) return 0.0;

      // Get total engagement
      final likesCount = videoDoc.data()?['likesCount'] ?? 0;
      final commentsCount = videoDoc.data()?['commentsCount'] ?? 0;
      final sharesCount = videoDoc.data()?['sharesCount'] ?? 0;
      final viewsCount = videoDoc.data()?['viewsCount'] ?? 1;

      // Calculate engagement per hour
      final totalEngagement =
          likesCount + (commentsCount * 2) + (sharesCount * 3);
      final engagementPerHour = totalEngagement / hoursSinceCreation;

      // Calculate engagement rate
      final engagementRate = totalEngagement / viewsCount;

      // Velocity = (engagement/hour) * engagement_rate
      final velocity = (engagementPerHour / 10) * engagementRate; // Normalize

      log('⚡ Engagement velocity: $videoId - ${totalEngagement}/$hoursSinceCreation hours = ${velocity.toStringAsFixed(2)}');

      return velocity.clamp(0.0, 1.0);
    } catch (e) {
      log('❌ Error calculating engagement velocity: $e');
      return 0.0;
    }
  }

  /// Calculate viral coefficient (shares per view ratio)
  Future<double> _calculateViralCoefficient(String videoId) async {
    try {
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();

      if (!videoDoc.exists) return 0.0;

      final sharesCount = videoDoc.data()?['sharesCount'] ?? 0;
      final viewsCount = videoDoc.data()?['viewsCount'] ?? 1;

      // Viral coefficient = shares / views
      final coefficient = sharesCount / viewsCount;

      log('🚀 Viral coefficient: $videoId - $sharesCount/$viewsCount = ${coefficient.toStringAsFixed(3)}');

      return coefficient.clamp(0.0, 1.0);
    } catch (e) {
      log('❌ Error calculating viral coefficient: $e');
      return 0.0;
    }
  }

  /// Calculate comment quality score
  Future<double> _calculateCommentQuality(String videoId) async {
    try {
      final commentsSnapshot = await _firestore
          .collection('comments')
          .where('videoId', isEqualTo: videoId)
          .limit(50)
          .get();

      if (commentsSnapshot.docs.isEmpty) return 0.0;

      double qualityScore = 0.0;
      int totalComments = 0;

      for (final doc in commentsSnapshot.docs) {
        final data = doc.data();
        final text = data['text'] ?? '';
        final repliesCount = data['repliesCount'] ?? 0;

        // Quality factors
        final lengthScore =
            (text.length / 100).clamp(0.0, 1.0); // Longer = better
        final repliesScore =
            (repliesCount / 5).clamp(0.0, 1.0); // More replies = better

        final commentQuality = (lengthScore * 0.6) + (repliesScore * 0.4);
        qualityScore += commentQuality;
        totalComments++;
      }

      final avgQuality = totalComments > 0 ? qualityScore / totalComments : 0.0;

      log('💬 Comment quality: $videoId - ${totalComments} comments, avg: ${avgQuality.toStringAsFixed(2)}');

      return avgQuality.clamp(0.0, 1.0);
    } catch (e) {
      log('❌ Error calculating comment quality: $e');
      return 0.0;
    }
  }

  /// Calculate time-to-first-action score (faster = better)
  Future<double> _calculateTimeToFirstAction(String videoId) async {
    try {
      // Get video creation time
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();

      if (!videoDoc.exists) return 0.0;

      final createdAt = (videoDoc.data()?['createdAt'] as Timestamp?)?.toDate();
      if (createdAt == null) return 0.0;

      // Get first engagement
      final firstEngagement = await _firestore
          .collection('engagement')
          .where('videoId', isEqualTo: videoId)
          .where('engagementScore', isGreaterThan: 5.0)
          .orderBy('engagementScore', descending: false)
          .orderBy('lastUpdated', descending: false)
          .limit(1)
          .get();

      if (firstEngagement.docs.isEmpty) return 0.0;

      final firstEngagementTime =
          (firstEngagement.docs.first.data()['lastUpdated'] as Timestamp?)
              ?.toDate();
      if (firstEngagementTime == null) return 0.0;

      final minutesToFirstAction =
          firstEngagementTime.difference(createdAt).inMinutes;

      // Score: faster = better
      // < 5 min = 1.0, 30 min = 0.5, > 60 min = 0.0
      final score = (1.0 - (minutesToFirstAction / 60)).clamp(0.0, 1.0);

      log('⏱️ Time-to-first-action: $videoId - $minutesToFirstAction min, score: ${score.toStringAsFixed(2)}');

      return score;
    } catch (e) {
      log('❌ Error calculating time-to-first-action: $e');
      return 0.0;
    }
  }

  /// Calculate overall velocity score for ranking
  Future<double> calculateOverallVelocityScore(String videoId) async {
    try {
      final engagementVelocity = await _calculateEngagementVelocity(videoId);
      final viralCoefficient = await _calculateViralCoefficient(videoId);
      final commentQuality = await _calculateCommentQuality(videoId);
      final timeToAction = await _calculateTimeToFirstAction(videoId);

      // Weighted combination
      final score = (engagementVelocity * 0.35) +
          (viralCoefficient * 0.30) +
          (commentQuality * 0.20) +
          (timeToAction * 0.15);

      log('🎯 Overall velocity score for $videoId: ${score.toStringAsFixed(2)}');

      return score.clamp(0.0, 1.0);
    } catch (e) {
      log('❌ Error calculating overall velocity score: $e');
      return 0.0;
    }
  }
}
