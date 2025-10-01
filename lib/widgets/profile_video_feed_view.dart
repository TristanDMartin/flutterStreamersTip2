import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../providers/favorites_provider.dart';
import '../models/home_video.dart';
import '../services/video_service.dart';
import '../services/local_draft_service.dart';
import 'drafts_sheet_view.dart';
import 'drafts_grid_card_view.dart';
import 'player_screen.dart';
import 'video_thumbnail_view.dart';
import 'video_edit_view.dart';

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
    return _buildGridLayout();
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

  Widget _buildVideoGridWithDrafts(List<HomeVideo> videos, List<Map<String, dynamic>> drafts) {
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
            return PublishedVideoThumbnail(
              videoUrl: video.videoURL,
              viewCount: video.views,
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
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 110 / 170,
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
    return PublishedVideoThumbnail(
      videoUrl: video['videoUrl'] ?? video['videoURL'] ?? '',
      viewCount: video['views'] ?? 0,
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
            child: const Text('Close', style: TextStyle(color: Color(0xFF9248d2))),
          ),
        ],
      ),
    );
  }

  void _showDraftsSheet() {
    // Get drafts from LocalDraftService
    LocalDraftService().getAllDrafts().then((drafts) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DraftsSheetView(
            drafts: drafts,
            onDelete: (draft) async {
              // Delete draft using LocalDraftService
              final success = await LocalDraftService().deleteDraft(draft['id']);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted draft: ${draft['caption']?.isNotEmpty == true ? draft['caption'] : 'Untitled Draft'}'),
                    backgroundColor: Colors.red,
                  ),
                );
                // Refresh the UI
                setState(() {});
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete draft'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            onEdit: (draft) {
              _editDraft(draft);
            },
          ),
        ),
      );
    });
  }

  // Edit draft by navigating to VideoEditView
  void _editDraft(Map<String, dynamic> draft) {
    final videoPath = draft['videoPath'] as String?;
    if (videoPath == null || videoPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft video file not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final videoFile = File(videoPath);
    if (!videoFile.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft video file is missing'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigate to VideoEditView for editing
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoEditView(
          videoFile: videoFile,
          onCancel: () {
            Navigator.of(context).pop();
          },
          onNext: () {
            // Navigate to VideoPublishingScreen with draft data
            _navigateToVideoPublishingScreen(videoFile, draft);
          },
        ),
      ),
    );
  }

  // Navigate to video publishing screen with draft data
  void _navigateToVideoPublishingScreen(File videoFile, Map<String, dynamic> draft) {
    // TODO: Implement navigation to VideoPublishingScreen with existing draft data
    // This would pass the existing draft data (caption, hashtags, etc.) for editing
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening publishing screen for: ${draft['caption']?.isNotEmpty == true ? draft['caption'] : 'Untitled Draft'}'),
        backgroundColor: const Color(0xFF9248D2),
      ),
    );
    
    // For now, just go back to drafts sheet
    Navigator.of(context).pop();
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