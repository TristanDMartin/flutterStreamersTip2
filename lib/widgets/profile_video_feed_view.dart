import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/favorites_provider.dart';
import '../providers/video_service_provider.dart';
import '../models/user.dart';
import '../models/home_video.dart';
import 'drafts_sheet_view.dart';
import 'drafts_grid_card_view.dart';
import 'published_video_card_view.dart';
import 'player_screen.dart';

class ProfileVideoFeedView extends ConsumerStatefulWidget {
  final ProfileVideoFeedType feedType;
  final String? userId;
  final VoidCallback? onVideoTap;
  
  const ProfileVideoFeedView({
    super.key,
    required this.feedType,
    this.userId,
    this.onVideoTap,
  });

  @override
  ConsumerState<ProfileVideoFeedView> createState() => _ProfileVideoFeedViewState();
}

enum ProfileVideoFeedType {
  videos,    // Tab 0: User's own videos
  favorites, // Tab 1: User's saved videos
  tagged,    // Tab 2: Videos where user is tagged
}

class _ProfileVideoFeedViewState extends ConsumerState<ProfileVideoFeedView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildGridLayout(),
      floatingActionButton: widget.feedType == ProfileVideoFeedType.videos
          ? FloatingActionButton(
              onPressed: _showDraftsSheet,
              backgroundColor: const Color(0xFF9248d2),
              child: const Icon(Icons.video_library, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildGridLayout() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _buildVideoGrid(),
    );
  }

  Widget _buildVideoGrid() {
    switch (widget.feedType) {
      case ProfileVideoFeedType.videos:
        return _buildUserVideosGrid();
      case ProfileVideoFeedType.favorites:
        return _buildFavoritesGrid();
      case ProfileVideoFeedType.tagged:
        return _buildTaggedVideosGrid();
    }
  }

  Widget _buildUserVideosGrid() {
    return Consumer(
      builder: (context, ref, child) {
        final videoService = ref.watch(videoServiceProvider);
        final allVideos = videoService.createSampleVideos();
        
        // Get user's published videos
        final userVideos = allVideos.where((video) => 
          video.creator.id == widget.userId && !video.isDraft
        ).toList();
        
        // Get drafts (placeholder for now - should come from drafts service)
        final drafts = <dynamic>[]; // TODO: Get from drafts service
        
        if (userVideos.isEmpty && drafts.isEmpty) {
          return _buildEmptyState(
            icon: Icons.videocam_outlined,
            title: 'No Videos Yet',
            subtitle: 'Start creating content to see your videos here',
          );
        }

        return _buildVideoGridWithDrafts(userVideos, drafts);
      },
    );
  }

  Widget _buildFavoritesGrid() {
    final favoritesState = ref.watch(favoritesProvider);
    final favorites = favoritesState.favorites.toList();

    if (favorites.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bookmark_border,
        title: 'No Saved Videos',
        subtitle: 'Videos you save will appear here',
      );
    }

    // Convert favorite IDs to video data
    final favoriteVideos = favorites.map((videoId) => _getSampleVideoData(videoId)).toList();
    
    return _buildVideoGridContent(favoriteVideos);
  }

  Widget _buildTaggedVideosGrid() {
    // TODO: Replace with actual tagged videos data
    final taggedVideos = _getSampleTaggedVideos();
    
    if (taggedVideos.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_outline,
        title: 'No Tagged Content',
        subtitle: 'Videos where you\'re tagged will appear here',
      );
    }

    return _buildVideoGridContent(taggedVideos);
  }

  Widget _buildVideoGridWithDrafts(List<HomeVideo> videos, List<dynamic> drafts) {
    return RefreshIndicator(
      onRefresh: () async {
        // Refresh data based on feed type
        switch (widget.feedType) {
          case ProfileVideoFeedType.favorites:
            await ref.read(favoritesProvider.notifier).forceSync();
            break;
          case ProfileVideoFeedType.videos:
          case ProfileVideoFeedType.tagged:
            // TODO: Implement refresh for user videos and tagged content
            break;
        }
      },
      color: const Color(0xFF9248d2),
      backgroundColor: Colors.black,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
          crossAxisSpacing: 16, // 16pt spacing
          mainAxisSpacing: 16,  // 16pt spacing
          childAspectRatio: 110 / 170, // Width: 110, Height: 170
        ),
        itemCount: (drafts.isNotEmpty ? 1 : 0) + videos.length,
                itemBuilder: (context, index) {
          // Show drafts card first if there are drafts
          if (drafts.isNotEmpty && index == 0) {
                    return DraftsGridCardView(
              drafts: drafts,
                      onTap: _showDraftsSheet,
                    );
          }
          
          // Adjust index for published videos
          final videoIndex = drafts.isNotEmpty ? index - 1 : index;
          if (videoIndex < videos.length) {
            final video = videos[videoIndex];
                    return PublishedVideoCardView(
                      video: video,
              onTap: () => _openVideoPlayer(video, videoIndex, videos),
            );
          }
          
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildVideoGridContent(List<Map<String, dynamic>> videos) {
    return RefreshIndicator(
      onRefresh: () async {
        // Refresh data based on feed type
        switch (widget.feedType) {
          case ProfileVideoFeedType.favorites:
            await ref.read(favoritesProvider.notifier).forceSync();
            break;
          case ProfileVideoFeedType.videos:
          case ProfileVideoFeedType.tagged:
            // TODO: Implement refresh for user videos and tagged content
            break;
        }
      },
      color: const Color(0xFF9248d2),
      backgroundColor: Colors.black,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16, // 16pt spacing
          mainAxisSpacing: 16,  // 16pt spacing
          childAspectRatio: 110 / 170, // Width: 110, Height: 170
        ),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          return _buildPublishedVideoCard(video, index);
        },
      ),
    );
  }

  Widget _buildPublishedVideoCard(Map<String, dynamic> video, int index) {
    return GestureDetector(
      onTap: () {
        widget.onVideoTap?.call();
        // TODO: Navigate to ProfileVideoPlayerView with video data
        _showVideoDetail(video);
      },
      child: Container(
        width: 110, // Exact width specification
        height: 170, // Exact height specification
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16), // 16pt corner radius
          color: Colors.grey[900],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25), // Black 25% opacity
              blurRadius: 10, // 10pt radius
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Video thumbnail
              _buildVideoThumbnailView(video),
              
              // View count overlay (ZStack alignment: .bottom)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color.fromRGBO(0, 0, 0, 0.5), // Black 50% opacity
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.play_circle_fill, // play.circle.fill
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatViews(video['views'] ?? 0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoThumbnailView(Map<String, dynamic> video) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[800],
      child: video['thumbnailUrl'] != null
                    ? Image.network(
              video['thumbnailUrl'],
                        fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.play_circle_outline,
                          color: Colors.white,
                  size: 40,
                );
              },
                      )
                    : const Icon(
              Icons.play_circle_outline,
                        color: Colors.white,
              size: 40,
            ),
    );
  }



  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    } else {
      return views.toString();
    }
  }


  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            title,
              style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showVideoDetail(Map<String, dynamic> video) {
    // TODO: Navigate to ProfileVideoPlayerView
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing: ${video['title']}'),
        backgroundColor: const Color(0xFF9248d2),
      ),
    );
  }

  void _showDraftsSheet() {
    // Get sample draft data - replace with actual drafts
    final drafts = _getSampleDrafts();
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DraftsSheetView(
          drafts: drafts,
          onDelete: (draft) {
            // TODO: Implement draft deletion
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Deleted draft: ${draft.caption.isNotEmpty ? draft.caption : 'Untitled Draft'}'),
                backgroundColor: Colors.red,
              ),
            );
          },
          onEdit: (draft) {
            // TODO: Navigate to draft editor
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Editing draft: ${draft.caption.isNotEmpty ? draft.caption : 'Untitled Draft'}'),
                backgroundColor: const Color(0xFF9248d2),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openVideoPlayer(HomeVideo video, int index, List<HomeVideo> videos) {
    final videoIds = videos.map((v) => v.id).toList();
    
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => PlayerScreen(
          mode: PlayerMode.homeFeed,
          initialIndex: index,
          videoIds: videoIds,
        ),
      ),
    );
  }

  List<HomeVideo> _getSampleDrafts() {
    const currentUser = User(
      id: 'current_user',
      username: 'current_user',
      displayName: 'Current User',
      avatarURL: 'https://example.com/avatar.jpg',
    );

    return [
      const HomeVideo(
        id: 'draft_1',
        creator: currentUser,
        videoURL: 'https://example.com/draft1.mp4',
        likes: 0,
        comments: 0,
        views: 0,
        caption: 'My first draft video',
        isLiked: false,
        isFavorited: false,
        isDraft: true,
        mlScore: 0.0,
      ),
      const HomeVideo(
        id: 'draft_2',
        creator: currentUser,
        videoURL: 'https://example.com/draft2.mp4',
        likes: 0,
        comments: 0,
        views: 0,
        caption: 'Another draft video',
        isLiked: false,
        isFavorited: false,
        isDraft: true,
        mlScore: 0.0,
      ),
    ];
  }

  // Sample data methods - replace with actual data sources
  List<Map<String, dynamic>> _getSampleUserVideos() {
    return [
      {
        'id': 'user_video_1',
        'title': 'My First Video',
        'likes': '1.2K',
        'duration': '0:45',
        'thumbnail': 'https://example.com/thumb1.jpg',
      },
      {
        'id': 'user_video_2',
        'title': 'Gaming Highlights',
        'likes': '3.4K',
        'duration': '1:23',
        'thumbnail': 'https://example.com/thumb2.jpg',
      },
      {
        'id': 'user_video_3',
        'title': 'Tutorial Series',
        'likes': '856',
        'duration': '2:15',
        'thumbnail': 'https://example.com/thumb3.jpg',
      },
    ];
  }

  List<Map<String, dynamic>> _getSampleTaggedVideos() {
    return [
      {
        'id': 'tagged_video_1',
        'title': 'Collaboration Video',
        'likes': '5.6K',
        'duration': '1:45',
        'thumbnail': 'https://example.com/tagged1.jpg',
      },
    ];
  }

  Map<String, dynamic> _getSampleVideoData(String videoId) {
    final sampleVideos = {
      '1': {
        'id': '1',
        'title': 'Epic Gaming Moment',
        'likes': '12.5K',
        'duration': '0:30',
        'thumbnail': 'https://example.com/thumb1.jpg',
      },
      '2': {
        'id': '2',
        'title': 'Digital Art Creation',
        'likes': '8.9K',
        'duration': '1:15',
        'thumbnail': 'https://example.com/thumb2.jpg',
      },
      '3': {
        'id': '3',
        'title': 'Acoustic Cover',
        'likes': '15.2K',
        'duration': '2:30',
        'thumbnail': 'https://example.com/thumb3.jpg',
      },
    };
    
    return sampleVideos[videoId] ?? {
      'id': videoId,
      'title': 'Sample Video',
      'likes': '1K',
      'duration': '1:00',
      'thumbnail': 'https://example.com/thumb.jpg',
    };
  }
}

// Grid item configuration class
class GridItem {
  final double flex;
  final double spacing;

  const GridItem(this.flex, {required this.spacing});
}