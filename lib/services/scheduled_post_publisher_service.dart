import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import 'firestore_scheduled_post_service.dart';
import 'post_counter_service.dart';
import '../models/scheduled_post.dart';

/// Service to periodically check and publish scheduled posts
class ScheduledPostPublisherService {
  static final ScheduledPostPublisherService _instance =
      ScheduledPostPublisherService._internal();
  factory ScheduledPostPublisherService() => _instance;
  ScheduledPostPublisherService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreScheduledPostService _scheduledPostService =
      FirestoreScheduledPostService();
  Timer? _checkTimer;
  bool _isRunning = false;

  /// Start periodic checking for scheduled posts
  /// Default interval is 30 seconds for more responsive publishing
  void startPeriodicCheck({Duration interval = const Duration(seconds: 30)}) {
    if (_isRunning) {
      developer.log('⚠️ Scheduled post publisher already running',
          name: 'ScheduledPostPublisherService');
      return;
    }

    _isRunning = true;
    developer.log('✅ Starting scheduled post publisher (checking every ${interval.inSeconds} seconds)',
        name: 'ScheduledPostPublisherService');

    // Check immediately
    _checkAndPublish();

    // Then check periodically
    _checkTimer = Timer.periodic(interval, (_) {
      _checkAndPublish();
    });
  }
  
  /// Stop periodic checking
  void stopPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _isRunning = false;
    developer.log('⏸️ Stopped scheduled post publisher',
        name: 'ScheduledPostPublisherService');
  }

  /// Check for posts ready to publish and publish them
  Future<void> _checkAndPublish() async {
    try {
      final readyPosts = await _scheduledPostService.getPostsReadyToPublish();
      
      if (readyPosts.isEmpty) {
        developer.log('📭 No scheduled posts ready to publish',
            name: 'ScheduledPostPublisherService');
        return;
      }

      developer.log('📬 Found ${readyPosts.length} scheduled posts ready to publish',
          name: 'ScheduledPostPublisherService');

      for (final postData in readyPosts) {
        try {
          await _publishScheduledPost(postData);
        } catch (e) {
          developer.log('❌ Error publishing scheduled post ${postData['id']}: $e',
              name: 'ScheduledPostPublisherService');
          // Mark as failed
          await _scheduledPostService.updateScheduledPostStatus(
            postData['id'],
            PostStatus.failed,
          );
        }
      }
    } catch (e) {
      developer.log('❌ Error checking scheduled posts: $e',
          name: 'ScheduledPostPublisherService');
    }
  }

  /// Publish a scheduled post
  Future<void> _publishScheduledPost(Map<String, dynamic> postData) async {
    final postId = postData['id'] as String;
    final videoId = postData['videoId'] as String;

    developer.log('📤 Publishing scheduled post: $postId, video: $videoId',
        name: 'ScheduledPostPublisherService');

    // Update scheduled post status to publishing
    await _scheduledPostService.updateScheduledPostStatus(
      postId,
      PostStatus.publishing,
    );

    try {
      // Get the video document
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();
      if (!videoDoc.exists) {
        throw Exception('Video not found: $videoId');
      }

      final videoData = videoDoc.data()!;
      final privacy = videoData['privacy'] as String? ?? 'Everyone';
      final category = videoData['metadata']?['category'] as String?;
      final userId = videoData['userId'] as String? ?? 
          (videoData['creatorId'] as String?);

      if (userId == null || userId.isEmpty) {
        throw Exception('Video has no userId or creatorId');
      }

      // Ensure video has creatorId for profile queries
      final hasCreatorId = videoData['creatorId'] != null;
      if (!hasCreatorId) {
        await _firestore.collection('videos').doc(videoId).update({
          'creatorId': userId,
        });
      }

      // Update video status to published and ensure all required fields are set
      final updateData = <String, dynamic>{
        'status': 'published',
        'creatorId': userId, // Ensure creatorId is set (for profile queries)
        'updatedAt': FieldValue.serverTimestamp(),
        // Remove scheduledAtUtc since it's now published
        'scheduledAtUtc': FieldValue.delete(),
      };

      // Ensure category/categoryId is set for VideoService (it looks for both)
      if (category != null && category.isNotEmpty) {
        updateData['category'] = category;
        updateData['categoryId'] = category; // VideoService might look for this too
      }

      await _firestore.collection('videos').doc(videoId).update(updateData);

      developer.log('✅ Updated video document: $videoId with status=published, creatorId=$userId, category=$category',
          name: 'ScheduledPostPublisherService');

      // Verify video document has all required fields before publishing
      final finalVideoDoc = await _firestore.collection('videos').doc(videoId).get();
      final finalVideoData = finalVideoDoc.data()!;
      
      developer.log('📋 Video document fields before publishing: ${finalVideoData.keys.toList()}',
          name: 'ScheduledPostPublisherService');
      developer.log('   - status: ${finalVideoData['status']}',
          name: 'ScheduledPostPublisherService');
      developer.log('   - privacy: ${finalVideoData['privacy']}',
          name: 'ScheduledPostPublisherService');
      developer.log('   - creatorId: ${finalVideoData['creatorId']}',
          name: 'ScheduledPostPublisherService');
      developer.log('   - videoUrl: ${finalVideoData['videoUrl'] != null ? "YES" : "NO"}',
          name: 'ScheduledPostPublisherService');
      developer.log('   - thumbnailUrl: ${finalVideoData['thumbnailUrl'] != null ? "YES" : "NO"}',
          name: 'ScheduledPostPublisherService');
      developer.log('   - category: ${finalVideoData['category']}',
          name: 'ScheduledPostPublisherService');

      // Add to user's profile videos collection (same as VideoUploadService)
      await _addToUserProfile(userId, videoId);

      // Add to feeds using the same logic as VideoUploadService
      await _addToFeeds(videoId, privacy, userId, category: category);

      // Update PostCounterService
      try {
        final postCounterService = PostCounterService();
        await postCounterService.incrementPostCount(userId, postId: videoId);
        developer.log('✅ PostCounterService updated for published scheduled video',
            name: 'ScheduledPostPublisherService');
      } catch (e) {
        developer.log('⚠️ Failed to update PostCounterService: $e',
            name: 'ScheduledPostPublisherService');
      }

      // Update scheduled post status to published
      await _scheduledPostService.updateScheduledPostStatus(
        postId,
        PostStatus.published,
      );

      // Final verification: Check that video is now published and has all required fields
      final verificationDoc = await _firestore.collection('videos').doc(videoId).get();
      final verificationData = verificationDoc.data()!;
      
      developer.log('✅ Successfully published scheduled post: $postId',
          name: 'ScheduledPostPublisherService');
      developer.log('📋 Final verification - Video $videoId:',
          name: 'ScheduledPostPublisherService');
      developer.log('   - Status: ${verificationData['status']} (should be "published")',
          name: 'ScheduledPostPublisherService');
      developer.log('   - Privacy: ${verificationData['privacy']} (should be "Everyone" for feeds)',
          name: 'ScheduledPostPublisherService');
      developer.log('   - CreatorId: ${verificationData['creatorId']}',
          name: 'ScheduledPostPublisherService');
      developer.log('   - VideoUrl: ${verificationData['videoUrl'] != null ? "✅" : "❌"}',
          name: 'ScheduledPostPublisherService');
      developer.log('   - ThumbnailUrl: ${verificationData['thumbnailUrl'] != null ? "✅" : "❌"}',
          name: 'ScheduledPostPublisherService');
      developer.log('   - Category: ${verificationData['category']}',
          name: 'ScheduledPostPublisherService');
      developer.log('💡 VideoService will pick up this video on next refresh',
          name: 'ScheduledPostPublisherService');
      
      // Try to refresh VideoService if possible (it may not be initialized)
      // This is best-effort - VideoService will pick up the video on next manual refresh
      _tryRefreshVideoService(videoId, userId);
    } catch (e) {
      developer.log('❌ Error publishing scheduled post: $e',
          name: 'ScheduledPostPublisherService');
      // Mark as failed
      await _scheduledPostService.updateScheduledPostStatus(
        postId,
        PostStatus.failed,
      );
      rethrow;
    }
  }

  /// Add video to user's profile videos collection
  Future<void> _addToUserProfile(String userId, String videoId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('videos')
          .doc(videoId)
          .set({
        'videoId': videoId,
        'addedAt': FieldValue.serverTimestamp(),
      });
      developer.log('✅ Added video to user profile: $videoId',
          name: 'ScheduledPostPublisherService');
    } catch (e) {
      developer.log('⚠️ Error adding video to user profile: $e',
          name: 'ScheduledPostPublisherService');
      // Don't throw - this is not critical
    }
  }

  /// Add video to appropriate feeds based on privacy setting
  /// (Matches VideoUploadService._addToFeeds logic)
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

          // Add to following feed for user's followers
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
          // Add only to following feed (connections can see)
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

          // Add to connections-only category feed if category is specified
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
          // Private videos don't go to feeds
          developer.log('⏭️ Skipping feed addition for private video: $videoId',
              name: 'ScheduledPostPublisherService');
          break;
      }

      developer.log('✅ Added video to feeds: $videoId (privacy: $privacy)',
          name: 'ScheduledPostPublisherService');
    } catch (e) {
      developer.log('⚠️ Error adding video to feeds: $e',
          name: 'ScheduledPostPublisherService');
      // Don't throw - this is not critical
    }
  }

  /// Manually trigger a check for scheduled posts (useful for testing)
  Future<void> checkNow() async {
    await _checkAndPublish();
  }
  
  /// Try to refresh VideoService after publishing (best-effort)
  /// This method attempts to notify that a new video is available
  void _tryRefreshVideoService(String videoId, String userId) {
    try {
      // Log that a video was published - HomeView can listen for this
      developer.log('📢 Video published notification: videoId=$videoId, userId=$userId',
          name: 'ScheduledPostPublisherService');
      developer.log('💡 HomeView should refresh VideoService to show the new video',
          name: 'ScheduledPostPublisherService');
      
      // Note: We can't directly access Riverpod providers from here since this is a background service
      // VideoService will pick up the video on next refresh (pull-to-refresh, app restart, or navigation)
      // Alternatively, we could use a global event bus or notification system here
    } catch (e) {
      // Silently fail - this is just a best-effort notification
    }
  }
}
