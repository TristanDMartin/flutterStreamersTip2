import '../models/home_video.dart';
import '../models/user.dart';
import 'real_user_data_service.dart';
import 'logging_service.dart';
import 'video_performance_service.dart';
import 'like_service.dart';

class VideoService {
  final RealUserDataService _userDataService = RealUserDataService();
  final VideoPerformanceService _videoPerformanceService = VideoPerformanceService();
  final LikeService _likeService = LikeService();

  Future<VideoFetchResult> fetchForYouVideos({
    required int pageSize,
    String? lastDocument,
  }) async {
    try {
      LoggingService.instance.debug('🎬 Fetching for you videos', tag: 'VideoService');
      
      // Use real data service instead of mock data
      final videos = await _userDataService.getForYouVideos(
        limit: pageSize,
        lastDocumentId: lastDocument,
      );
      
      // CRITICAL FIX: Load user's like state for each video
      final videosWithLikeState = await _loadLikeStatesForVideos(videos);
      
      LoggingService.instance.debug('✅ Loaded ${videosWithLikeState.length} for you videos with like states', tag: 'VideoService');
      
      return VideoFetchResult(
        videos: videosWithLikeState,
        lastDocument: videosWithLikeState.isNotEmpty ? videosWithLikeState.last.id : null,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error fetching for you videos', tag: 'VideoService', error: e, stackTrace: stackTrace);
      
      // Fallback to empty result
      return VideoFetchResult(
        videos: [],
        lastDocument: null,
      );
    }
  }

  Future<VideoFetchResult> fetchFollowingVideos({
    required List<String> followingIds,
    required int pageSize,
    String? lastDocument,
  }) async {
    try {
      LoggingService.instance.debug('👥 Fetching following videos for ${followingIds.length} users', tag: 'VideoService');
      
      // Use real data service instead of mock data
      final videos = await _userDataService.getFollowingVideos(
        followingIds,
        limit: pageSize,
      );
      
      // CRITICAL FIX: Load user's like state for each video
      final videosWithLikeState = await _loadLikeStatesForVideos(videos);
      
      LoggingService.instance.debug('✅ Loaded ${videosWithLikeState.length} following videos with like states', tag: 'VideoService');
      
      return VideoFetchResult(
        videos: videosWithLikeState,
        lastDocument: videosWithLikeState.isNotEmpty ? videosWithLikeState.last.id : null,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error fetching following videos', tag: 'VideoService', error: e, stackTrace: stackTrace);
      
      // Fallback to empty result
      return VideoFetchResult(
        videos: [],
        lastDocument: null,
      );
    }
  }

  Future<bool> toggleLike(String videoId) async {
    // Use the actual LikeService instead of placeholder
    try {
      return await _likeService.toggleLike(videoId);
    } catch (e) {
      LoggingService.instance.error('Error toggling like for video $videoId', tag: 'VideoService', error: e);
      return false;
    }
  }

  /// Load like states for a list of videos
  Future<List<HomeVideo>> _loadLikeStatesForVideos(List<HomeVideo> videos) async {
    try {
      LoggingService.instance.debug('💖 Loading like states for ${videos.length} videos', tag: 'VideoService');
      
      final videosWithLikeState = <HomeVideo>[];
      
      // Process videos in batches to avoid overwhelming the system
      const batchSize = 10;
      for (int i = 0; i < videos.length; i += batchSize) {
        final batch = videos.skip(i).take(batchSize).toList();
        
        // Load like states for this batch
        for (final video in batch) {
          try {
            final isLiked = await _likeService.isVideoLiked(video.id);
            final likeCount = await _likeService.getLikeCount(video.id);
            
            videosWithLikeState.add(video.copyWith(
              isLiked: isLiked,
              likes: likeCount,
            ));
          } catch (e) {
            // If like state loading fails, use the original video
            LoggingService.instance.warning('Failed to load like state for video ${video.id}', tag: 'VideoService');
            videosWithLikeState.add(video);
          }
        }
        
        // Small delay between batches to prevent overwhelming the system
        if (i + batchSize < videos.length) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
      
      LoggingService.instance.debug('✅ Loaded like states for ${videosWithLikeState.length} videos', tag: 'VideoService');
      return videosWithLikeState;
    } catch (e) {
      LoggingService.instance.error('Error loading like states', tag: 'VideoService', error: e);
      // Return original videos if like state loading fails
      return videos;
    }
  }

  // Get video by ID from sample data
  HomeVideo? getVideoById(String videoId) {
    final allVideos = createSampleVideos();
    try {
      return allVideos.firstWhere((video) => video.id == videoId);
    } catch (e) {
      return null;
    }
  }

  // Get multiple videos by IDs
  List<HomeVideo> getVideosByIds(List<String> videoIds) {
    final allVideos = createSampleVideos();
    return videoIds
        .map((id) => allVideos.where((video) => video.id == id).firstOrNull)
        .where((video) => video != null)
        .cast<HomeVideo>()
        .toList();
  }

  // MARK: - Sample Data Creation
  
  List<HomeVideo> createSampleVideos() {
    return [
      HomeVideo(
        id: '1',
        creator: _createSampleUser('GamingPro', 'GamingPro'),
        videoURL: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        likes: 12500,
        comments: 1200,
        caption: 'Epic Gaming Moment - Check out this insane play! 🔥',
        isLiked: false,
        isFavorited: false,
        isDraft: false,
        thumbnailURL: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg',
        views: 15420,
        mlScore: 0.85,
      ),
      HomeVideo(
        id: '2',
        creator: _createSampleUser('ArtStreamer', 'ArtStreamer'),
        videoURL: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        likes: 8900,
        comments: 456,
        caption: 'Digital Art Creation - Creating magic with digital brushes ✨',
        isLiked: true,
        isFavorited: false,
        isDraft: false,
        thumbnailURL: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/ElephantsDream.jpg',
        views: 8920,
        mlScore: 0.72,
      ),
      HomeVideo(
        id: '3',
        creator: _createSampleUser('MusicLive', 'MusicLive'),
        videoURL: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
        likes: 15200,
        comments: 2100,
        caption: 'Acoustic Cover - Cover of your favorite song 🎵',
        isLiked: false,
        isFavorited: true,
        isDraft: false,
        thumbnailURL: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerBlazes.jpg',
        views: 25600,
        mlScore: 0.91,
      ),
    ];
  }

  User _createSampleUser(String username, String displayName) {
    return User(
      id: 'user_$username',
      username: username,
      displayName: displayName,
      bio: 'Amazing content creator with a passion for sharing!',
      avatarURL: 'https://picsum.photos/200/200?random=${username.hashCode}',
      onlineStatus: 'online',
      hashtags: ['gaming', 'content', 'streaming'],
      aiSelf: 'I am a passionate content creator who loves gaming and sharing experiences with my community.',
      postCount: 42,
      followerCount: 15420,
      followingCount: 890,
    );
  }

  /// TIKTOK-STYLE: Preload video for instant playback
  Future<void> preloadVideo(String videoURL) async {
    try {
      LoggingService.instance.debug('🎬 Preloading video: $videoURL', tag: 'VideoService');
      
      // Use VideoPerformanceService to preload the video
      await _videoPerformanceService.preloadVideo(videoURL);
      
      LoggingService.instance.debug('✅ Video preloaded successfully: $videoURL', tag: 'VideoService');
    } catch (e) {
      LoggingService.instance.error('Failed to preload video: $videoURL', tag: 'VideoService', error: e);
      rethrow;
    }
  }
}

class VideoFetchResult {
  final List<HomeVideo> videos;
  final String? lastDocument;
  
  VideoFetchResult({
    required this.videos,
    this.lastDocument,
  });
}
