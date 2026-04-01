import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Creator growth service - Boosts new and consistent creators
class CreatorGrowthService {
  static CreatorGrowthService? _instance;
  static CreatorGrowthService get instance =>
      _instance ??= CreatorGrowthService._();

  CreatorGrowthService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Creator boost multipliers
  static const double newCreatorBoost = 2.0; // First 10 videos
  static const double consistencyBoost = 1.5; // Weekly uploaders
  static const double growthBoost = 1.8; // Fast-growing creators
  static const double comebackBoost = 1.4; // Returning creators

  /// Calculate creator boost multiplier for video scoring
  Future<double> getCreatorBoostMultiplier(String creatorId) async {
    try {
      final metrics = await _getCreatorMetrics(creatorId);

      double multiplier = 1.0; // Base multiplier

      // 1. New Creator Boost (first 10 videos)
      if (metrics.totalVideos <= 10) {
        multiplier *= newCreatorBoost;
        log('🆕 New creator boost applied: $creatorId (${metrics.totalVideos} videos) - ${newCreatorBoost}x');
      }

      // 2. Consistency Boost (uploads weekly)
      if (metrics.uploadConsistency > 0.7) {
        multiplier *= consistencyBoost;
        log(
          '📅 Consistency boost applied: $creatorId '
          '(${(metrics.uploadConsistency * 100).toStringAsFixed(0)}%) - '
          '${consistencyBoost}x',
        );
      }

      // 3. Growth Velocity Boost (>20% follower growth per week)
      if (metrics.growthVelocity > 0.2) {
        multiplier *= growthBoost;
        log(
          '📈 Growth boost applied: $creatorId '
          '(${(metrics.growthVelocity * 100).toStringAsFixed(0)}% growth) - '
          '${growthBoost}x',
        );
      }

      // 4. Comeback Boost (inactive → active)
      if (metrics.isComebackCreator) {
        multiplier *= comebackBoost;
        log('🔄 Comeback boost applied: $creatorId - ${comebackBoost}x');
      }

      log('✅ Total creator boost for $creatorId: ${multiplier.toStringAsFixed(2)}x');
      return multiplier;
    } catch (e) {
      log('❌ Error calculating creator boost: $e');
      return 1.0; // No boost on error
    }
  }

  /// Get creator metrics from Firestore
  Future<CreatorMetrics> _getCreatorMetrics(String creatorId) async {
    try {
      // Get creator's video count
      final videosSnapshot = await _firestore
          .collection('videos')
          .where('creatorId', isEqualTo: creatorId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      final totalVideos = videosSnapshot.docs.length;

      // Calculate upload consistency
      final consistency = _calculateUploadConsistency(videosSnapshot.docs);

      // Get follower growth data
      final growthVelocity = await _calculateGrowthVelocity(creatorId);

      // Check if comeback creator
      final isComebackCreator =
          await _isComeback(creatorId, videosSnapshot.docs);

      return CreatorMetrics(
        creatorId: creatorId,
        totalVideos: totalVideos,
        uploadConsistency: consistency,
        growthVelocity: growthVelocity,
        isComebackCreator: isComebackCreator,
      );
    } catch (e) {
      log('❌ Error getting creator metrics: $e');
      return CreatorMetrics(
        creatorId: creatorId,
        totalVideos: 0,
        uploadConsistency: 0.0,
        growthVelocity: 0.0,
        isComebackCreator: false,
      );
    }
  }

  /// Calculate upload consistency (0-1 score)
  double _calculateUploadConsistency(List<QueryDocumentSnapshot> videos) {
    if (videos.length < 2) return 0.0;

    // Check last 10 videos for weekly consistency
    final recentVideos = videos.take(10).toList();
    final now = DateTime.now();
    int weeksWithUploads = 0;

    for (int week = 0; week < 10; week++) {
      final weekStart = now.subtract(Duration(days: 7 * (week + 1)));
      final weekEnd = now.subtract(Duration(days: 7 * week));

      final hasUploadThisWeek = recentVideos.any((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null &&
            createdAt.isAfter(weekStart) &&
            createdAt.isBefore(weekEnd);
      });

      if (hasUploadThisWeek) weeksWithUploads++;
    }

    return weeksWithUploads / 10.0; // 0-1 score
  }

  /// Calculate follower growth velocity (% per week)
  Future<double> _calculateGrowthVelocity(String creatorId) async {
    if (_auth.currentUser == null) return 0.0;
    try {
      final snapshot = await _firestore
          .collection('creator_stats')
          .doc(creatorId)
          .collection('follower_history')
          .orderBy('timestamp', descending: true)
          .limit(8)
          .get();

      if (snapshot.docs.length < 2) return 0.0;

      final latest = snapshot.docs.first.data();
      final oldest = snapshot.docs.last.data();

      final currentFollowers = latest['followerCount'] ?? 0;
      final previousFollowers = oldest['followerCount'] ?? 0;

      if (previousFollowers == 0) return 0.0;

      final growth = (currentFollowers - previousFollowers) / previousFollowers;
      final weeks = snapshot.docs.length;

      return growth / weeks; // Growth per week
    } catch (e) {
      if (e.toString().contains('permission-denied') ||
          e.toString().contains('PERMISSION_DENIED')) {
        return 0.0;
      }
      log('⚠️ Error calculating growth velocity: $e');
      return 0.0;
    }
  }

  /// Check if creator is making a comeback (inactive → active)
  Future<bool> _isComeback(
      String creatorId, List<QueryDocumentSnapshot> videos) async {
    if (videos.length < 2) return false;

    final latest = videos.first.data() as Map<String, dynamic>;
    final latestDate = (latest['createdAt'] as Timestamp?)?.toDate();

    if (latestDate == null) return false;

    // Check if latest upload is within last 7 days
    final isRecentUpload = DateTime.now().difference(latestDate).inDays <= 7;

    if (!isRecentUpload) return false;

    // Check if there was a gap before this (30+ days)
    if (videos.length >= 2) {
      final previous = videos[1].data() as Map<String, dynamic>;
      final previousDate = (previous['createdAt'] as Timestamp?)?.toDate();

      if (previousDate != null) {
        final gap = latestDate.difference(previousDate).inDays;
        return gap >= 30; // 30+ day gap = comeback
      }
    }

    return false;
  }

  /// Update creator metrics after new upload
  Future<void> updateCreatorMetrics(String creatorId) async {
    try {
      final metrics = await _getCreatorMetrics(creatorId);

      // Save to Firestore
      await _firestore.collection('creator_metrics').doc(creatorId).set({
        'totalVideos': metrics.totalVideos,
        'uploadConsistency': metrics.uploadConsistency,
        'growthVelocity': metrics.growthVelocity,
        'isComebackCreator': metrics.isComebackCreator,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      log('✅ Creator metrics updated: $creatorId');
    } catch (e) {
      log('❌ Error updating creator metrics: $e');
    }
  }
}

/// Creator metrics model
class CreatorMetrics {
  final String creatorId;
  final int totalVideos;
  final double uploadConsistency; // 0-1
  final double growthVelocity; // % per week
  final bool isComebackCreator;

  CreatorMetrics({
    required this.creatorId,
    required this.totalVideos,
    required this.uploadConsistency,
    required this.growthVelocity,
    required this.isComebackCreator,
  });
}
