import '../models/home_video.dart';
import '../models/user.dart';

class VideoService {
  Future<VideoFetchResult> fetchForYouVideos({
    required int pageSize,
    String? lastDocument,
  }) async {
    // Placeholder - would fetch videos from Firestore
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
    
    // Return sample videos for testing
    final allVideos = createSampleVideos();
    final startIndex = lastDocument != null ? int.tryParse(lastDocument) ?? 0 : 0;
    final endIndex = startIndex + pageSize;
    final videos = allVideos.skip(startIndex).take(pageSize).toList();
    
    return VideoFetchResult(
      videos: videos,
      lastDocument: endIndex < allVideos.length ? endIndex.toString() : null,
    );
  }

  Future<VideoFetchResult> fetchFollowingVideos({
    required List<String> followingIds,
    required int pageSize,
    String? lastDocument,
  }) async {
    // Placeholder - would fetch following videos from Firestore
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
    
    // Filter videos to only show those from followed users
    final allVideos = createSampleVideos();
    final followingVideos = allVideos.where((video) => 
      followingIds.contains(video.creator.id)
    ).toList();
    
    final startIndex = lastDocument != null ? int.tryParse(lastDocument) ?? 0 : 0;
    final endIndex = startIndex + pageSize;
    final videos = followingVideos.skip(startIndex).take(pageSize).toList();
    
    return VideoFetchResult(
      videos: videos,
      lastDocument: endIndex < followingVideos.length ? endIndex.toString() : null,
    );
  }

  Future<bool> toggleLike(String videoId) async {
    // Placeholder - would toggle like status in Firestore
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate network delay
    return true;
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
}

class VideoFetchResult {
  final List<HomeVideo> videos;
  final String? lastDocument;
  
  VideoFetchResult({
    required this.videos,
    this.lastDocument,
  });
}
