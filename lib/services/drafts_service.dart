import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../features/gamification/emit_gamification_event.dart';
import '../features/gamification/gamification_event_types.dart';
import 'post_counter_service.dart';

class DraftsService {
  static final DraftsService _instance = DraftsService._internal();
  factory DraftsService() => _instance;
  DraftsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get user's drafts
  Future<List<Map<String, dynamic>>> getUserDrafts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('drafts')
          .orderBy('addedAt', descending: true)
          .get();

      final List<Map<String, dynamic>> drafts = [];

      for (final doc in snapshot.docs) {
        final draftData = doc.data();
        final videoId = draftData['videoId'] as String?;

        if (videoId != null) {
          // Get the actual video data
          final videoDoc =
              await _firestore.collection('videos').doc(videoId).get();

          if (videoDoc.exists) {
            final videoData = videoDoc.data()!;

            // Create a draft object with video data
            final draft = {
              'id': videoId,
              'videoId': videoId,
              'caption': videoData['caption'] ?? '',
              'thumbnailUrl': videoData['thumbnailUrl'],
              'videoUrl': videoData['videoUrl'],
              'createdAt': videoData['createdAt'],
              'status': videoData['status'] ?? 'draft',
              'privacy': videoData['privacy'] ?? 'Everyone',
              'category': videoData['metadata']?['category'] ?? 'gaming',
              'hashtags': videoData['hashtags'] ?? <String>[],
              'addedAt': draftData['addedAt'],
            };

            drafts.add(draft);
          }
        }
      }

      return drafts;
    } catch (e) {
      debugPrint('Error getting user drafts: $e');
      return [];
    }
  }

  /// Get current user's drafts
  Future<List<Map<String, dynamic>>> getCurrentUserDrafts() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    return getUserDrafts(user.uid);
  }

  /// Delete a draft
  Future<bool> deleteDraft(String videoId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Check if video was published before deleting
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();

      bool wasPublished = false;
      if (videoDoc.exists) {
        final videoData = videoDoc.data()!;
        final status = videoData['status'] as String? ?? 'draft';
        final privacy = videoData['privacy'] as String? ?? 'private';
        wasPublished = status == 'published' &&
            (privacy == 'public' || privacy == 'followers');
      }

      // Delete from drafts collection
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('drafts')
          .doc(videoId)
          .delete();

      // Delete the video document
      await _firestore.collection('videos').doc(videoId).delete();

      // Decrement post count if it was published
      if (wasPublished) {
        try {
          final postCounterService = PostCounterService();
          await postCounterService.decrementPostCount(user.uid,
              postId: videoId);
          debugPrint(
              '✅ PostCounterService decremented for deleted published video');
        } catch (e) {
          debugPrint('⚠️ Failed to decrement PostCounterService: $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting draft: $e');
      return false;
    }
  }

  /// Publish a draft (convert draft to published video)
  Future<bool> publishDraft(String videoId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Update video status to published
      await _firestore.collection('videos').doc(videoId).update({
        'status': 'published',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Remove from drafts collection
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('drafts')
          .doc(videoId)
          .delete();

      // Add to appropriate feeds based on privacy
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();

      if (videoDoc.exists) {
        final videoData = videoDoc.data()!;
        final privacy = videoData['privacy'] as String? ?? 'Everyone';
        final category = videoData['metadata']?['category'] as String?;

        // Add to feeds (reuse the logic from VideoUploadService)
        await _addToFeeds(videoId, privacy, user.uid, category: category);

        // Update PostCounterService for accurate post count
        try {
          final postCounterService = PostCounterService();
          await postCounterService.incrementPostCount(user.uid,
              postId: videoId);
          debugPrint('✅ PostCounterService updated for published draft');
        } catch (e) {
          debugPrint('⚠️ Failed to update PostCounterService for draft: $e');
          // Continue anyway, this is not critical
        }
        scheduleGamificationEvent(
          GamificationEventTypes.contentPublished,
          entityType: 'video',
          entityId: videoId,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error publishing draft: $e');
      return false;
    }
  }

  /// Add video to appropriate feeds based on privacy setting
  Future<void> _addToFeeds(String videoId, String privacy, String userId,
      {String? category}) async {
    try {
      switch (privacy) {
        case 'Everyone':
          // Add to public feeds (For You feed)
          await _firestore
              .collection('feeds')
              .doc('for_you')
              .collection('videos')
              .doc(videoId)
              .set({
            'videoId': videoId,
            'userId': userId,
            'privacy': privacy,
            'addedAt': FieldValue.serverTimestamp(),
          });

          // Add to following feed
          await _firestore
              .collection('feeds')
              .doc('following')
              .collection('videos')
              .doc(videoId)
              .set({
            'videoId': videoId,
            'userId': userId,
            'privacy': privacy,
            'addedAt': FieldValue.serverTimestamp(),
          });

          // Add to category feed if category is specified
          if (category != null && category.isNotEmpty) {
            await _firestore
                .collection('feeds')
                .doc('categories')
                .collection(category)
                .doc(videoId)
                .set({
              'videoId': videoId,
              'userId': userId,
              'category': category,
              'privacy': privacy,
              'addedAt': FieldValue.serverTimestamp(),
            });
          }
          break;

        case 'Connections':
          // Add only to following feed
          await _firestore
              .collection('feeds')
              .doc('following')
              .collection('videos')
              .doc(videoId)
              .set({
            'videoId': videoId,
            'userId': userId,
            'privacy': privacy,
            'addedAt': FieldValue.serverTimestamp(),
          });

          // Add to connections-only category feeds
          if (category != null && category.isNotEmpty) {
            await _firestore
                .collection('feeds')
                .doc('connections_categories')
                .collection(category)
                .doc(videoId)
                .set({
              'videoId': videoId,
              'userId': userId,
              'category': category,
              'privacy': privacy,
              'addedAt': FieldValue.serverTimestamp(),
            });
          }
          break;

        case 'Private':
          // Add only to user's private collection
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('private_videos')
              .doc(videoId)
              .set({
            'videoId': videoId,
            'userId': userId,
            'privacy': privacy,
            'addedAt': FieldValue.serverTimestamp(),
          });
          break;

        default:
          // Default to private
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('private_videos')
              .doc(videoId)
              .set({
            'videoId': videoId,
            'userId': userId,
            'privacy': privacy,
            'addedAt': FieldValue.serverTimestamp(),
          });
          break;
      }
    } catch (e) {
      debugPrint('Error adding to feeds: $e');
    }
  }
}
