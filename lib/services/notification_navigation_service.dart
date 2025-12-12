import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/video_url_resolver.dart';
import '../models/home_video.dart';
import '../models/user.dart';
import '../widgets/player_screen.dart';
import '../providers/home_provider.dart' as hp;

/// Service for handling navigation from notifications to posts/videos
///
/// Implements the notification spec:
/// - Post tap → Full-screen video player
/// - Handle deleted/unavailable posts
/// - Maintain back stack for proper navigation
class NotificationNavigationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Navigate to a video from a notification
  ///
  /// Opens the video using the canonical PlayerScreen (same as HomeView)
  /// This ensures consistent HUD layout with proper screen edge anchoring
  Future<void> navigateToVideo({
    required BuildContext context,
    required String videoId,
    required hp.HomeViewModel homeViewModel,
    List<HomeVideo>?
        availableVideos, // Optional: pass available videos to search
  }) async {
    try {
      // First, try to find the video in the provided available videos
      if (availableVideos != null) {
        final existingVideo =
            availableVideos.where((video) => video.id == videoId).firstOrNull;

        if (existingVideo != null) {
          // Use the existing video (faster and more reliable)
          debugPrint(
              '🎬 NotificationNavigationService: Using existing video: $videoId');
          if (context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                settings: const RouteSettings(name: 'playerScreen'),
                fullscreenDialog: true,
                builder: (context) => PlayerScreen(
                  mode: PlayerMode.homeFeed,
                  initialIndex: 0,
                  videoIds: [videoId],
                  videos: [existingVideo], // Use existing video data
                ),
              ),
            );
          }
          return;
        }
      }

      // Fallback: Fetch video data from Firestore
      debugPrint(
          '🎬 NotificationNavigationService: Video not found in available videos, fetching from Firestore: $videoId');
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();

      if (!videoDoc.exists) {
        _showVideoUnavailable(context);
        return;
      }

      final videoData = videoDoc.data()!;

      // Check if video is deleted or private
      if (videoData['isDeleted'] == true) {
        _showVideoUnavailable(context);
        return;
      }

      // Convert to HomeVideo model
      final homeVideo = _convertToHomeVideo(videoData, videoId);

      // Navigate using the canonical PlayerScreen (same as HomeView)
      // This ensures consistent HUD layout with proper screen edge anchoring
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'playerScreen'),
            fullscreenDialog: true,
            builder: (context) => PlayerScreen(
              mode: PlayerMode.homeFeed,
              initialIndex: 0, // Single video, so index 0
              videoIds: [videoId],
              videos: [homeVideo], // Pass the actual video data
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint(
          '❌ NotificationNavigationService: Error navigating to video: $e');
      if (context.mounted) {
        _showErrorSnackBar(context, 'Unable to open video');
      }
    }
  }

  /// Convert Firestore data to HomeVideo model
  HomeVideo _convertToHomeVideo(Map<String, dynamic> data, String videoId) {
    // Create User object for the creator
    final creator = User(
      id: data['userId'] ?? '',
      displayName: data['displayName'] ?? 'Unknown',
      username: data['username'] ?? 'unknown',
      avatarURL: data['userAvatarUrl'],
      bio: data['bio'] ?? '',
      onlineStatus: data['onlineStatus'] ?? 'offline',
      hashtags: (data['hashtags'] as List<dynamic>?)?.cast<String>() ?? [],
      followerCount: data['followerCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
      postCount: data['postCount'] ?? 0,
    );

    return HomeVideo(
      id: videoId,
      creator: creator,
      videoURL: resolveVideoUrl(data),
      thumbnailURL: data['thumbnailUrl'],
      likes: data['likeCount'] ?? 0,
      comments: data['commentCount'] ?? 0,
      views: data['viewCount'] ?? 0,
      caption: data['caption'] ?? '',
      categoryId: data['category'] ?? 'general',
      createdAt: data['timestamp'] as Timestamp?,
    );
  }

  /// Show video unavailable dialog
  void _showVideoUnavailable(BuildContext context) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Video Unavailable',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This video is no longer available or has been deleted.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF9248d2)),
            ),
          ),
        ],
      ),
    );
  }

  /// Show error SnackBar
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade900,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
