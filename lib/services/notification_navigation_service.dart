import 'package:flutter/material.dart';
import '../models/home_video.dart';
import '../utils/home_video_from_firestore.dart';
import '../providers/home_provider.dart' as hp;
import '../routing/app_navigator.dart';
import '../widgets/player_screen.dart';

/// Service for handling navigation from notifications to posts/videos
///
/// Implements the notification spec:
/// - Post tap → Full-screen video player
/// - Handle deleted/unavailable posts
/// - Maintain back stack for proper navigation
class NotificationNavigationService {
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
            AppNavigator.openPlayer(
              context,
              mode: PlayerMode.homeFeed,
              initialIndex: 0,
              videoIds: [videoId],
              videos: [existingVideo],
            );
          }
          return;
        }
      }

      debugPrint(
          '🎬 NotificationNavigationService: Video not found in available videos, fetching from Firestore: $videoId');
      final HomeVideo? homeVideo = await loadHomeVideoForPlayback(videoId);
      if (homeVideo == null) {
        if (context.mounted) {
          await AppNavigator.openVideoUnavailable(context, videoId: videoId);
        }
        return;
      }

      // Navigate using the canonical PlayerScreen (same as HomeView)
      // This ensures consistent HUD layout with proper screen edge anchoring
      if (context.mounted) {
        AppNavigator.openPlayer(
          context,
          mode: PlayerMode.homeFeed,
          initialIndex: 0,
          videoIds: [videoId],
          videos: [homeVideo],
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
