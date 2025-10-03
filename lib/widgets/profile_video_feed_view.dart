import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/favorites_provider.dart';
import '../models/home_video.dart';
import '../models/user.dart';
import '../services/video_service.dart';
import '../services/local_draft_service.dart';
import 'player_screen.dart';
import 'tiktok_video_thumbnail.dart';

// Grid item configuration class
class GridItem {
  final double flex;
  final double spacing;

  const GridItem(this.flex, {required this.spacing});
}

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
  ConsumerState<ProfileVideoFeedView> createState() =>
      _ProfileVideoFeedViewState();
}

enum ProfileVideoFeedType {
  videos, // Tab 0: User's own videos
  favorites, // Tab 1: User's saved videos
  tagged, // Tab 2: Videos where user is tagged
}

class _ProfileVideoFeedViewState extends ConsumerState<ProfileVideoFeedView> {
  @override
  Widget build(BuildContext context) {
    return _buildGridLayout();
  }

  Widget _buildGridLayout() {
    return Padding(
      padding: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 8.0, // Small top padding to separate from tab buttons
      ),
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
        // Watch user videos from centralized VideoService
        final userVideos = ref.watch(userVideosProvider(widget.userId ?? ''));

        // Get drafts from LocalDraftService
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: LocalDraftService().getAllDrafts(),
          builder: (context, snapshot) {
            final drafts = snapshot.data ?? [];

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
    final favoriteVideos =
        favorites.map((videoId) => _getSampleVideoData(videoId)).toList();

    return _buildVideoGridContent(favoriteVideos);
  }

  Widget _buildTaggedVideosGrid() {
    // Tagged videos data - placeholder implementation for future development
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

  Widget _buildVideoGridWithDrafts(
      List<HomeVideo> videos, List<Map<String, dynamic>> drafts) {
    return RefreshIndicator(
      onRefresh: () async {
        // Refresh data based on feed type
        switch (widget.feedType) {
          case ProfileVideoFeedType.favorites:
            await ref.read(favoritesProvider.notifier).forceSync();
            break;
          case ProfileVideoFeedType.videos:
          case ProfileVideoFeedType.tagged:
            // Refresh for user videos and tagged content - placeholder for future implementation
            break;
        }
      },
      color: const Color(0xFF9248d2),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16, // Tight gutters = 16pt
          mainAxisSpacing: 16, // Tight gutters = 16pt
          childAspectRatio: 9 / 16, // Strict 9:16 aspect ratio (portrait)
        ),
        itemCount: (drafts.isNotEmpty ? 1 : 0) + videos.length,
        itemBuilder: (context, index) {
          // Show drafts card first if there are drafts
          if (drafts.isNotEmpty && index == 0) {
            // return DraftsGridCardView(
            //   drafts: drafts,
            //   onTap: _showDraftsSheet,
            // );
            return GestureDetector(
              onTap: _showDraftsSheet,
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Drafts Coming Soon',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            );
          }

          // Adjust index for published videos
          final videoIndex = drafts.isNotEmpty ? index - 1 : index;
          if (videoIndex < videos.length) {
            final video = videos[videoIndex];
            return TikTokVideoThumbnail(
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
            // Refresh for user videos and tagged content - placeholder for future implementation
            break;
        }
      },
      color: const Color(0xFF9248d2),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16, // Tight gutters = 16pt
          mainAxisSpacing: 16, // Tight gutters = 16pt
          childAspectRatio: 9 / 16, // Strict 9:16 aspect ratio (portrait)
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
    // Convert Map to HomeVideo for TikTokVideoThumbnail
    final homeVideo = HomeVideo(
      id: video['id'] ?? '',
      creator: User(
        id: video['creatorId'] ?? '',
        displayName: video['creatorName'] ?? 'Unknown',
        username: video['creatorUsername'] ?? 'unknown',
        avatarURL: video['creatorAvatar'] ?? '',
        bio: '',
        followerCount: 0,
        followingCount: 0,
      ),
      videoURL: video['videoUrl'] ?? video['videoURL'] ?? '',
      thumbnailURL: video['thumbnailUrl'] ?? video['thumbnailURL'],
      likes: video['likes'] ?? 0,
      comments: video['comments'] ?? 0,
      views: video['views'] ?? 0,
      caption: video['caption'] ?? '',
      duration: video['duration']?.toDouble() ?? 0.0,
      categoryId: video['categoryId'] ?? '',
      createdAt: video['createdAt'],
    );

    return TikTokVideoThumbnail(
      video: homeVideo,
      onTap: () {
        widget.onVideoTap?.call();
        _showVideoDetail(video);
      },
    );
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
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showVideoDetail(Map<String, dynamic> video) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          video['title'] ?? 'Video',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'Likes: ${video['likes'] ?? 'N/A'}\nDuration: ${video['duration'] ?? 'N/A'}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Close', style: TextStyle(color: Color(0xFF9248d2))),
          ),
        ],
      ),
    );
  }

  void _showDraftsSheet() {
    // Get drafts from LocalDraftService
    LocalDraftService().getAllDrafts().then((drafts) {
      if (mounted) {
        // Navigator.of(context).push(
        //   MaterialPageRoute(
        //     builder: (context) => DraftsSheetView(
        //       drafts: drafts,
        //       onDelete: (draft) async {
        //         // Delete draft using LocalDraftService
        //         final success = await LocalDraftService().deleteDraft(draft['id']);
        //         if (success) {
        //           ScaffoldMessenger.of(context).showSnackBar(
        //             SnackBar(
        //               content: Text('Deleted draft: ${draft['caption']?.isNotEmpty == true ? draft['caption'] : 'Untitled Draft'}'),
        //               backgroundColor: Colors.red,
        //             ),
        //           );
        //           // Refresh the UI
        //           setState(() {});
        //         } else {
        //           ScaffoldMessenger.of(context).showSnackBar(
        //             const SnackBar(
        //               content: Text('Failed to delete draft'),
        //               backgroundColor: Colors.red,
        //             ),
        //           );
        //         }
        //       },
        //       onEdit: (draft) {
        //         _editDraft(draft);
        //       },
        //     ),
        //   ),
        // );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Drafts sheet feature coming soon!')),
        );
      }
    });
  }

  // Helper methods
  List<Map<String, dynamic>> _getSampleTaggedVideos() {
    return [
      {
        'id': 'tagged1',
        'title': 'Tagged Video 1',
        'likes': '2.5K',
        'duration': '0:45',
        'thumbnail': 'https://example.com/tagged1.jpg',
      },
      {
        'id': 'tagged2',
        'title': 'Tagged Video 2',
        'likes': '1.8K',
        'duration': '1:20',
        'thumbnail': 'https://example.com/tagged2.jpg',
      },
    ];
  }

  Map<String, dynamic> _getSampleVideoData(String videoId) {
    return {
      'id': videoId,
      'title': 'Favorite Video',
      'likes': '1.2K',
      'duration': '0:30',
      'thumbnail': 'https://example.com/favorite.jpg',
    };
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
}
