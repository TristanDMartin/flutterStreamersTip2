import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class VideoCategorizationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add categories to all existing videos based on content analysis
  static Future<Map<String, int>> categorizeAllExistingVideos() async {
    try {
      debugPrint('🔧 Starting video categorization...');

      // Get all published videos without category
      final videosSnapshot = await _firestore
          .collection('videos')
          .where('status', isEqualTo: 'published')
          .where('privacy', isEqualTo: 'Everyone')
          .get();

      debugPrint('📊 Found ${videosSnapshot.docs.length} published videos');

      int updatedCount = 0;
      final Map<String, int> categoryStats = {};

      for (final doc in videosSnapshot.docs) {
        final data = doc.data();

        // Skip if already has category
        if (data['category'] != null) {
          debugPrint(
              'Skipping ${doc.id} - already has category: ${data['category']}');
          continue;
        }

        // Determine category from content
        final category = _determineCategoryFromContent(data);

        // Update the video with category
        await doc.reference.update({
          'category': category,
          'categoryId': category,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint(
            '✅ Updated ${doc.id}: "${data['caption'] ?? 'No caption'}" → $category');
        categoryStats[category] = (categoryStats[category] ?? 0) + 1;
        updatedCount++;
      }

      debugPrint(
          '🎉 Successfully updated $updatedCount videos with categories!');
      debugPrint('📈 Category distribution: $categoryStats');

      return categoryStats;
    } catch (e) {
      debugPrint('❌ Error categorizing videos: $e');
      rethrow;
    }
  }

  /// Determine category from video content
  static String _determineCategoryFromContent(Map<String, dynamic> data) {
    final caption = (data['caption'] ?? '').toLowerCase();
    final hashtags = (data['hashtags'] as List<dynamic>? ?? [])
        .map((h) => h.toString().toLowerCase())
        .join(' ');
    final content = '$caption $hashtags'.toLowerCase();

    // Smart category detection based on content
    if (content.contains('music') ||
        content.contains('song') ||
        content.contains('dance') ||
        content.contains('beat') ||
        content.contains('melody') ||
        content.contains('sing') ||
        content.contains('audio')) {
      return 'music';
    } else if (content.contains('art') ||
        content.contains('draw') ||
        content.contains('paint') ||
        content.contains('sketch') ||
        content.contains('design') ||
        content.contains('creative') ||
        content.contains('artist')) {
      return 'art';
    } else if (content.contains('tech') ||
        content.contains('coding') ||
        content.contains('programming') ||
        content.contains('code') ||
        content.contains('software') ||
        content.contains('developer') ||
        content.contains('computer')) {
      return 'tech';
    } else if (content.contains('sport') ||
        content.contains('fitness') ||
        content.contains('gym') ||
        content.contains('workout') ||
        content.contains('exercise') ||
        content.contains('training') ||
        content.contains('athlete')) {
      return 'sports';
    } else if (content.contains('food') ||
        content.contains('cooking') ||
        content.contains('recipe') ||
        content.contains('eat') ||
        content.contains('meal') ||
        content.contains('chef') ||
        content.contains('kitchen')) {
      return 'food';
    } else if (content.contains('chat') ||
        content.contains('talk') ||
        content.contains('stream') ||
        content.contains('live') ||
        content.contains('discussion') ||
        content.contains('conversation')) {
      return 'just-chatting';
    } else if (content.contains('tutorial') ||
        content.contains('learn') ||
        content.contains('teach') ||
        content.contains('guide') ||
        content.contains('how to') ||
        content.contains('education') ||
        content.contains('lesson')) {
      return 'tutorials';
    } else if (content.contains('fashion') ||
        content.contains('style') ||
        content.contains('outfit') ||
        content.contains('clothes') ||
        content.contains('wear') ||
        content.contains('model') ||
        content.contains('beauty')) {
      return 'fashion';
    } else if (content.contains('roleplay') ||
        content.contains('acting') ||
        content.contains('character') ||
        content.contains('story') ||
        content.contains('drama') ||
        content.contains('theater')) {
      return 'roleplay';
    } else if (content.contains('podcast') ||
        content.contains('interview') ||
        content.contains('discussion') ||
        content.contains('audio') ||
        content.contains('radio')) {
      return 'podcasts';
    } else if (content.contains('fitness') ||
        content.contains('health') ||
        content.contains('wellness') ||
        content.contains('yoga') ||
        content.contains('meditation')) {
      return 'fitness';
    } else {
      // Default to gaming for general content
      return 'gaming';
    }
  }

  /// Get category statistics
  static Future<Map<String, int>> getCategoryStats() async {
    try {
      final videosSnapshot = await _firestore
          .collection('videos')
          .where('status', isEqualTo: 'published')
          .where('privacy', isEqualTo: 'Everyone')
          .get();

      final Map<String, int> stats = {};

      for (final doc in videosSnapshot.docs) {
        final data = doc.data();
        final category = data['category'] as String? ?? 'uncategorized';
        stats[category] = (stats[category] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      debugPrint('❌ Error getting category stats: $e');
      return {};
    }
  }
}
