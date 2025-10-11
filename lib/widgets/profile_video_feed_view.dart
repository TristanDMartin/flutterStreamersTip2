import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../providers/favorites_provider.dart';
import '../services/unified_bookmark_service.dart';
import '../models/home_video.dart';
import '../models/user.dart';
import '../services/video_service.dart';
import '../services/local_draft_service.dart';
import 'player_screen.dart';
import 'optimized_thumbnail.dart';

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

  /// Check if favorites should be visible based on privacy settings
  Future<bool> _shouldShowFavorites() async {
    try {
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      // If viewing own profile, always show favorites
      if (widget.userId == currentUser.uid) {
        return true;
      }

      // If viewing someone else's profile, check their privacy settings
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId!)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data();
      final privacy = userData?['privacy'] as Map<String, dynamic>? ?? {};
      final showFavoritesOnCard = privacy['showFavoritesOnCard'] ?? false;

      return showFavoritesOnCard;
    } catch (e) {
      debugPrint(
          '❌ ProfileVideoFeedView: Error checking favorites visibility: $e');
      return false; // Default to hidden on error
    }
  }

  /// Fetch another user's favorites from Firebase
  Future<List<String>> _fetchUserFavorites(String userId) async {
    try {
      final favoritesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .get();

      final favorites = favoritesSnapshot.docs.map((doc) => doc.id).toList();
      debugPrint(
          '🎯 ProfileVideoFeedView: Fetched ${favorites.length} favorites for user $userId');
      return favorites;
    } catch (e) {
      debugPrint('❌ ProfileVideoFeedView: Error fetching user favorites: $e');
      return [];
    }
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
        // Ensure VideoService is loaded when ProfileView is accessed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final videoServiceState = ref.read(videoServiceProvider);
          final videoService = ref.read(videoServiceProvider.notifier);
          if (videoServiceState.isEmpty) {
            debugPrint(
                '🎬 ProfileView: VideoService is empty, loading videos...');
            videoService.loadAllVideos();
          }
        });

        // Watch user videos from centralized VideoService
        final userVideos = ref.watch(userVideosProvider(widget.userId ?? ''));

        debugPrint(
            '🎬 ProfileView: Found ${userVideos.length} user videos for userId: ${widget.userId}');

        // Get drafts from LocalDraftService
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: LocalDraftService().getAllDrafts(),
          builder: (context, snapshot) {
            final drafts = snapshot.data ?? [];

            debugPrint('🎬 ProfileView: Found ${drafts.length} drafts');

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
    // Check privacy settings before showing favorites
    return FutureBuilder<bool>(
      future: _shouldShowFavorites(),
      builder: (context, privacySnapshot) {
        if (privacySnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          );
        }

        final shouldShowFavorites = privacySnapshot.data ?? false;

        if (!shouldShowFavorites) {
          return _buildEmptyState(
            icon: Icons.lock_outline,
            title: 'Favorites are Private',
            subtitle: 'This user has chosen to keep their favorites private',
          );
        }

        // Get favorites based on whether viewing own profile or someone else's
        final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
        final isViewingOwnProfile = widget.userId == currentUser?.uid;

        if (isViewingOwnProfile) {
          // Use current user's favorites from unified bookmark service
          final bookmarkService = UnifiedBookmarkService.instance;

          // Get bookmarked video IDs from the service
          final bookmarkedStates = bookmarkService.bookmarkStates;
          final favorites = bookmarkedStates.entries
              .where((entry) => entry.value.isBookmarked)
              .map((entry) => entry.key)
              .toList();

          debugPrint(
              '📚 ProfileVideoFeedView: Found ${favorites.length} bookmarked videos');

          if (favorites.isEmpty) {
            return _buildEmptyState(
              icon: Icons.bookmark_border,
              title: 'No Saved Videos',
              subtitle: 'Videos you save will appear here',
            );
          }

          // Fetch real video data from Firebase for favorite video IDs
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchFavoriteVideos(favorites),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                );
              }

              if (snapshot.hasError) {
                return _buildEmptyState(
                  icon: Icons.error_outline,
                  title: 'Error Loading Videos',
                  subtitle: 'Unable to load your saved videos',
                );
              }

              final favoriteVideos = snapshot.data ?? [];

              if (favoriteVideos.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.bookmark_border,
                  title: 'No Saved Videos',
                  subtitle: 'Videos you save will appear here',
                );
              }

              return _buildVideoGridContent(favoriteVideos);
            },
          );
        } else {
          // Fetch other user's favorites from Firebase
          return FutureBuilder<List<String>>(
            future: _fetchUserFavorites(widget.userId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                );
              }

              if (snapshot.hasError) {
                return _buildEmptyState(
                  icon: Icons.error_outline,
                  title: 'Error Loading Videos',
                  subtitle: 'Unable to load your saved videos',
                );
              }

              final favoriteVideoIds = snapshot.data ?? [];

              if (favoriteVideoIds.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.bookmark_border,
                  title: 'No Saved Videos',
                  subtitle: 'This user hasn\'t saved any videos yet',
                );
              }

              // Fetch real video data from Firebase for favorite video IDs
              return FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchFavoriteVideos(favoriteVideoIds),
                builder: (context, videoSnapshot) {
                  if (videoSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    );
                  }

                  if (videoSnapshot.hasError) {
                    return _buildEmptyState(
                      icon: Icons.error_outline,
                      title: 'Error Loading Videos',
                      subtitle: 'Unable to load saved videos',
                    );
                  }

                  final favoriteVideos = videoSnapshot.data ?? [];

                  if (favoriteVideos.isEmpty) {
                    return _buildEmptyState(
                      icon: Icons.bookmark_border,
                      title: 'No Saved Videos',
                      subtitle: 'This user hasn\'t saved any videos yet',
                    );
                  }

                  return _buildVideoGridContent(favoriteVideos);
                },
              );
            },
          );
        }
      },
    );
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
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
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
            // Show the first draft as a thumbnail instead of placeholder text
            final draft = drafts.first;
            debugPrint(
                '🎬 ProfileView: Building draft card - videoPath: "${draft['videoPath']}", thumbnailPath: "${draft['thumbnailPath']}"');
            final draftVideo = HomeVideo(
              id: draft['id'] ?? 'draft_${index}',
              videoURL: draft['videoPath'] ?? '',
              thumbnailURL: draft['thumbnailPath'] ?? '',
              creator: User(
                id: 'current_user',
                displayName: 'You',
                username: 'you',
                bio: 'Your draft video',
                avatarURL: '',
              ),
              caption: draft['caption'] ?? 'Draft',
              categoryId: 'draft',
              views: 0,
              likes: 0,
              comments: 0,
              isDraft: true,
              createdAt: Timestamp.fromDate(
                DateTime.tryParse(draft['createdAt']?.toString() ?? '') ??
                    DateTime.now(),
              ),
            );

            return GridThumbnail(
              video: draftVideo,
              onTap: _showDraftsSheet,
              showDraftBadge: true,
              showDurationBadge: false,
            );
          }

          // Adjust index for published videos
          final videoIndex = drafts.isNotEmpty ? index - 1 : index;
          if (videoIndex < videos.length) {
            final video = videos[videoIndex];
            return _buildHomeVideoCard(video, videoIndex);
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
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
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

  Widget _buildHomeVideoCard(HomeVideo video, int index) {
    debugPrint('🎬 ProfileView: Building video card ${video.id}');
    debugPrint('  - thumbnailURL: "${video.thumbnailURL}"');
    debugPrint('  - videoURL: "${video.videoURL}"');
    debugPrint('  - thumbnails: ${video.thumbnails != null ? "YES" : "NO"}');
    if (video.thumbnails != null) {
      debugPrint('  - thumbnails.urls: ${video.thumbnails!.urls}');
      debugPrint(
          '  - thumbnails.generatedAt: ${video.thumbnails!.generatedAt}');
    }
    debugPrint('  - isDraft: ${video.isDraft}');
    debugPrint('  - createdAt: ${video.createdAt}');
    return GridThumbnail(
      video: video,
      onTap: () {
        widget.onVideoTap?.call();
        _openVideoPlayer(video, index, [video]);
      },
      showDraftBadge: widget.feedType == ProfileVideoFeedType.videos,
      showDurationBadge: true,
    );
  }

  Widget _buildPublishedVideoCard(Map<String, dynamic> video, int index) {
    // Convert Map to HomeVideo for GridThumbnail
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

    return GridThumbnail(
      video: homeVideo,
      onTap: () {
        widget.onVideoTap?.call();
        _openVideoPlayerFromMap(video, index);
      },
      showDraftBadge: widget.feedType == ProfileVideoFeedType.videos,
      showDurationBadge: true,
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
        'likes': 2500, // Use integer instead of string
        'comments': 120,
        'views': 15000,
        'duration': 45.0, // Use double for duration
        'thumbnail': 'https://example.com/tagged1.jpg',
        'videoUrl': 'https://example.com/tagged1.mp4',
        'creatorId': 'tagged_creator1',
        'creatorName': 'Tagged Creator 1',
        'creatorUsername': 'tagged_creator1',
        'creatorAvatar': 'https://example.com/avatar1.jpg',
        'caption': 'This is a tagged video 1',
        'categoryId': 'general',
        'createdAt': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 1))),
      },
      {
        'id': 'tagged2',
        'title': 'Tagged Video 2',
        'likes': 1800, // Use integer instead of string
        'comments': 85,
        'views': 12000,
        'duration': 80.0, // Use double for duration
        'thumbnail': 'https://example.com/tagged2.jpg',
        'videoUrl': 'https://example.com/tagged2.mp4',
        'creatorId': 'tagged_creator2',
        'creatorName': 'Tagged Creator 2',
        'creatorUsername': 'tagged_creator2',
        'creatorAvatar': 'https://example.com/avatar2.jpg',
        'caption': 'This is a tagged video 2',
        'categoryId': 'general',
        'createdAt': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 2))),
      },
    ];
  }

  /// Fetch real video data from Firebase for favorite video IDs
  Future<List<Map<String, dynamic>>> _fetchFavoriteVideos(
      List<String> videoIds) async {
    try {
      if (videoIds.isEmpty) return [];

      final List<Map<String, dynamic>> videos = [];

      // Fetch videos in batches to avoid Firestore limits
      const batchSize = 10;
      for (int i = 0; i < videoIds.length; i += batchSize) {
        final batch = videoIds.skip(i).take(batchSize).toList();

        final querySnapshot = await FirebaseFirestore.instance
            .collection('videos')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          videos.add({
            'id': doc.id,
            'videoURL': data['videoURL'] ?? data['videoUrl'] ?? '',
            'thumbnailURL': data['thumbnailURL'] ?? data['thumbnailUrl'] ?? '',
            'caption': data['caption'] ?? '',
            'likes': data['likes'] ?? 0,
            'comments': data['comments'] ?? 0,
            'views': data['views'] ?? 0,
            'duration': data['duration']?.toDouble() ?? 0.0,
            'creatorId': data['creatorId'] ?? '',
            'creatorName': data['creatorName'] ?? 'Unknown',
            'creatorUsername': data['creatorUsername'] ?? 'unknown',
            'creatorAvatar': data['creatorAvatar'] ?? '',
            'categoryId': data['categoryId'] ?? '',
            'createdAt': data['createdAt'],
          });
        }
      }

      debugPrint(
          '🎯 ProfileVideoFeedView: Fetched ${videos.length} favorite videos from Firebase');
      return videos;
    } catch (e) {
      debugPrint('❌ ProfileVideoFeedView: Error fetching favorite videos: $e');
      return [];
    }
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
          videos: videos, // Pass the actual video data
        ),
      ),
    );
  }

  Future<void> _openVideoPlayerFromMap(
      Map<String, dynamic> video, int index) async {
    // Get all videos from the current feed based on feed type
    List<Map<String, dynamic>> allVideos = [];

    switch (widget.feedType) {
      case ProfileVideoFeedType.favorites:
        final favoritesState = ref.read(favoritesProvider);
        final favorites = favoritesState.favorites.toList();
        // Fetch real video data for favorites
        final favoriteVideos = await _fetchFavoriteVideos(favorites);
        allVideos = favoriteVideos;
        break;
      case ProfileVideoFeedType.tagged:
        allVideos = _getSampleTaggedVideos();
        break;
      case ProfileVideoFeedType.videos:
        // For user videos, we'd need to get them from the provider
        // For now, create a single-item list
        allVideos = [video];
        break;
    }

    // Convert all videos to HomeVideo objects
    final homeVideos = allVideos
        .map((videoMap) => HomeVideo(
              id: videoMap['id'] ?? '',
              creator: User(
                id: videoMap['creatorId'] ?? '',
                displayName: videoMap['creatorName'] ?? 'Unknown',
                username: videoMap['creatorUsername'] ?? 'unknown',
                avatarURL: videoMap['creatorAvatar'] ?? '',
                bio: '',
                followerCount: 0,
                followingCount: 0,
              ),
              videoURL: videoMap['videoUrl'] ?? videoMap['videoURL'] ?? '',
              thumbnailURL:
                  videoMap['thumbnailUrl'] ?? videoMap['thumbnailURL'],
              likes: videoMap['likes'] ?? 0,
              comments: videoMap['comments'] ?? 0,
              views: videoMap['views'] ?? 0,
              caption: videoMap['caption'] ?? '',
              duration: videoMap['duration']?.toDouble() ?? 0.0,
              categoryId: videoMap['categoryId'] ?? '',
              createdAt: videoMap['createdAt'],
            ))
        .toList();

    final videoIds = homeVideos.map((v) => v.id).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => PlayerScreen(
          mode: PlayerMode.homeFeed,
          initialIndex: index,
          videoIds: videoIds,
          videos: homeVideos, // Pass the actual video data
        ),
      ),
    );
  }
}
