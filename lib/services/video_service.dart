import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/home_video.dart';
import 'real_user_data_service.dart';

class VideoService extends StateNotifier<List<HomeVideo>> {
  VideoService() : super([]);
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RealUserDataService _userDataService = RealUserDataService();
  
  /// Load all videos from Firestore and store them in memory
  Future<void> loadAllVideos() async {
    try {
      debugPrint('🎬 VideoService: Loading all videos...');
      
      // Get all videos (simple query, no complex indexes needed)
      final snapshot = await _firestore
          .collection('videos')
          .limit(100) // Reasonable limit
          .get();
      
      final videos = <HomeVideo>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        
        // Filter for published videos only
        if (data['status'] != 'published') {
          continue;
        }
        
        final userId = data['userId'] as String?;
        if (userId == null) continue;
        
        // Get creator data
        final creator = await _userDataService.getUserById(userId);
        if (creator == null) continue;
        
        final video = HomeVideo(
          id: doc.id,
          creator: creator,
          videoURL: data['videoUrl'] ?? '',
          thumbnailURL: data['thumbnailUrl'] ?? '',
          caption: data['caption'] ?? data['title'] ?? 'Untitled',
          categoryId: data['category'] ?? 'general',
          views: data['views']?.toInt() ?? 0,
          likes: data['likes']?.toInt() ?? 0,
          comments: data['comments']?.toInt() ?? 0,
          isDraft: false,
        );
        
        videos.add(video);
      }
      
      // Remove duplicates based on video ID
      final uniqueVideos = <String, HomeVideo>{};
      for (final video in videos) {
        if (video.id.isNotEmpty) {
          uniqueVideos[video.id] = video;
        }
      }
      
      // Convert back to list and sort by creation date (newest first)
      final deduplicatedVideos = uniqueVideos.values.toList();
      
      state = deduplicatedVideos;
      debugPrint('✅ VideoService: Loaded ${deduplicatedVideos.length} unique videos (removed ${videos.length - deduplicatedVideos.length} duplicates)');
    } catch (e) {
      debugPrint('❌ VideoService: Error loading videos: $e');
      state = [];
    }
  }
  
  /// Add a new video to the service (called after upload)
  void addVideo(HomeVideo video) {
    final currentVideos = List<HomeVideo>.from(state);
    
    // Check if video already exists to prevent duplicates
    final existingIndex = currentVideos.indexWhere((v) => v.id == video.id);
    if (existingIndex != -1) {
      // Replace existing video instead of adding duplicate
      currentVideos[existingIndex] = video;
      debugPrint('🔄 VideoService: Updated existing video: ${video.caption}');
    } else {
      // Add new video to beginning (newest first)
      currentVideos.insert(0, video);
      debugPrint('✅ VideoService: Added new video: ${video.caption}');
    }
    
    state = currentVideos;
  }
  
  /// Get videos for a specific user
  List<HomeVideo> getUserVideos(String userId) {
    return state.where((video) => video.creator.id == userId).toList();
  }
  
  /// Get videos for a specific category
  List<HomeVideo> getCategoryVideos(String categoryId) {
    return state.where((video) => video.categoryId == categoryId).toList();
  }
  
  /// Get all videos (for HomeView)
  List<HomeVideo> getAllVideos() {
    return state;
  }
  
  /// Update video stats (likes, views, etc.)
  void updateVideoStats(String videoId, {
    int? views,
    int? likes,
    int? comments,
  }) {
    final currentVideos = List<HomeVideo>.from(state);
    final index = currentVideos.indexWhere((video) => video.id == videoId);
    
    if (index != -1) {
      final video = currentVideos[index];
      currentVideos[index] = video.copyWith(
        views: views ?? video.views,
        likes: likes ?? video.likes,
        comments: comments ?? video.comments,
      );
      state = currentVideos;
    }
  }
  
  /// Refresh videos from Firestore
  Future<void> refresh() async {
    await loadAllVideos();
  }

  /// Preload video for performance optimization
  Future<void> preloadVideo(String videoId) async {
    try {
      debugPrint('🎬 VideoService: Preloading video: $videoId');
      // This could be extended to actually preload video data
      // For now, just log the preload request
      debugPrint('✅ VideoService: Video preload requested: $videoId');
    } catch (e) {
      debugPrint('❌ VideoService: Error preloading video: $e');
    }
  }

  /// Fetch "For You" videos (public videos) - returns a result object with videos and pagination info
  Future<Map<String, dynamic>> fetchForYouVideos({
    int? pageSize,
    dynamic lastDocument,
  }) async {
    try {
      debugPrint('🎬 VideoService: Fetching For You videos...');
      
      // Get all videos from current state and filter for public ones
      final allVideos = state;
      final forYouVideos = allVideos.where((video) => 
        !video.isDraft // Only published videos
      ).toList();
      
      debugPrint('✅ VideoService: Found ${forYouVideos.length} For You videos');
      return {
        'videos': forYouVideos,
        'lastDocument': null, // No pagination for now
      };
          } catch (e) {
      debugPrint('❌ VideoService: Error fetching For You videos: $e');
      return {
        'videos': <HomeVideo>[],
        'lastDocument': null,
      };
    }
  }

  /// Fetch following videos (from users the current user follows) - returns a result object
  Future<Map<String, dynamic>> fetchFollowingVideos({
    List<String>? followingIds,
    int? pageSize,
    dynamic lastDocument,
  }) async {
    try {
      debugPrint('🎬 VideoService: Fetching Following videos...');
      
      // For now, return all videos (this could be enhanced to filter by following relationships)
      final allVideos = state;
      final followingVideos = allVideos.where((video) => 
        !video.isDraft // Only published videos
      ).toList();
      
      debugPrint('✅ VideoService: Found ${followingVideos.length} Following videos');
      return {
        'videos': followingVideos,
        'lastDocument': null, // No pagination for now
      };
    } catch (e) {
      debugPrint('❌ VideoService: Error fetching Following videos: $e');
      return {
        'videos': <HomeVideo>[],
        'lastDocument': null,
      };
    }
  }

  /// Toggle like status for a video
  Future<bool> toggleLike(String videoId) async {
    try {
      debugPrint('🎬 VideoService: Toggling like for video: $videoId');
      
      final currentVideos = List<HomeVideo>.from(state);
      final index = currentVideos.indexWhere((video) => video.id == videoId);
      
      if (index != -1) {
        final video = currentVideos[index];
        final newIsLiked = !video.isLiked;
        final newLikeCount = newIsLiked ? video.likes + 1 : video.likes - 1;
        
        currentVideos[index] = video.copyWith(
          isLiked: newIsLiked,
          likes: newLikeCount,
        );
        
        state = currentVideos;
        debugPrint('✅ VideoService: Like toggled for video: $videoId');
        return newIsLiked;
      }
      return false;
    } catch (e) {
      debugPrint('❌ VideoService: Error toggling like: $e');
      return false;
    }
  }

  /// Get videos by their IDs
  Future<List<HomeVideo>> getVideosByIds(List<String> videoIds) async {
    try {
      debugPrint('🎬 VideoService: Getting videos by IDs: $videoIds');
      
      final allVideos = state;
      final requestedVideos = allVideos.where((video) => 
        videoIds.contains(video.id)
      ).toList();
      
      debugPrint('✅ VideoService: Found ${requestedVideos.length} videos by IDs');
      return requestedVideos;
    } catch (e) {
      debugPrint('❌ VideoService: Error getting videos by IDs: $e');
      return [];
    }
  }
}

// Provider for VideoService
final videoServiceProvider = StateNotifierProvider<VideoService, List<HomeVideo>>((ref) {
  return VideoService();
});

// Helper providers for filtered videos
final userVideosProvider = Provider.family<List<HomeVideo>, String>((ref, userId) {
  final allVideos = ref.watch(videoServiceProvider);
  return allVideos.where((video) => video.creator.id == userId).toList();
});

final categoryVideosProvider = Provider.family<List<HomeVideo>, String>((ref, categoryId) {
  final allVideos = ref.watch(videoServiceProvider);
  return allVideos.where((video) => video.categoryId == categoryId).toList();
});