import 'dart:async';
import 'dart:developer' as developer;
import 'firestore_scheduled_post_service.dart';
import '../models/scheduled_post.dart';

/// Service to periodically check and publish scheduled posts
class ScheduledPostPublisherService {
  static final ScheduledPostPublisherService _instance =
      ScheduledPostPublisherService._internal();
  factory ScheduledPostPublisherService() => _instance;
  ScheduledPostPublisherService._internal();

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

    developer.log('📤 Publishing scheduled post: $postId',
        name: 'ScheduledPostPublisherService');

    try {
      await _scheduledPostService.publishNow(postId);
    } catch (e) {
      developer.log('❌ Error publishing scheduled post: $e',
          name: 'ScheduledPostPublisherService');
      rethrow;
    }
  }

  /// Manually trigger a check for scheduled posts (useful for testing)
  Future<void> checkNow() async {
    await _checkAndPublish();
  }
  
}
