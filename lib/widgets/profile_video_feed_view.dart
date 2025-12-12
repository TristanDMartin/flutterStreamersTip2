import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'dart:io';
import 'dart:async';
import '../providers/favorites_provider.dart';
import '../services/unified_bookmark_service.dart';
import '../models/home_video.dart';
import '../models/user.dart';
import '../services/video_service.dart';
import '../services/local_draft_service.dart';
import '../services/real_user_data_service.dart';
import '../providers/video_service_provider.dart' as providers;
import 'player_screen.dart';
import 'optimized_thumbnail.dart';
import 'video_publishing_screen.dart';
import 'drafts_sheet_view.dart';

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
  // Real-time deletion listeners
  final Map<String, StreamSubscription<DocumentSnapshot>> _videoListeners = {};

  @override
  void dispose() {
    // Cancel all video deletion listeners
    for (final subscription in _videoListeners.values) {
      subscription.cancel();
    }
    _videoListeners.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildGridLayout();
  }

  /// Set up real-time deletion listeners for videos
  void _setupRealtimeDeletionListeners(List<HomeVideo> videos) {
    // Cancel existing listeners for videos no longer in the list
    final currentVideoIds = videos.map((v) => v.id).toSet();
    final listenersToRemove = _videoListeners.keys
        .where((id) => !currentVideoIds.contains(id))
        .toList();
    for (final id in listenersToRemove) {
      _videoListeners[id]?.cancel();
      _videoListeners.remove(id);
    }

    // Add listeners for new videos
    for (final video in videos) {
      if (_videoListeners.containsKey(video.id)) continue;

      final subscription = FirebaseFirestore.instance
          .collection('videos')
          .doc(video.id)
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;

        // If video document doesn't exist or status is 'deleted', invalidate provider
        if (!snapshot.exists) {
          _handleVideoDeletion(video.id);
          return;
        }

        final data = snapshot.data();
        final status = data?['status'] as String?;

        // Remove video if status is 'deleted' or not 'published'
        if (status == 'deleted' || status != 'published') {
          _handleVideoDeletion(video.id);
        }
      });

      _videoListeners[video.id] = subscription;
    }
  }

  /// Handle video deletion by invalidating the provider
  void _handleVideoDeletion(String videoId) {
    if (!mounted) return;

    // Cancel listener for deleted video
    _videoListeners[videoId]?.cancel();
    _videoListeners.remove(videoId);

    // Invalidate providers to refresh the feed
    ref.invalidate(userVideosProvider(widget.userId ?? ''));
    ref.invalidate(videoServiceProvider);
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
      if (kDebugMode) {
        debugPrint(
            '❌ ProfileVideoFeedView: Error checking favorites visibility: $e');
      }
      return false; // Default to hidden on error
    }
  }

  /// Load user videos directly from Firestore (bypasses VideoService)
  Future<List<HomeVideo>> _loadUserVideosDirectly(String userId) async {
    try {
      if (kDebugMode) {
        debugPrint(
            '🎬 ProfileView: Loading videos directly for userId: $userId');
      }

      final userDataService = RealUserDataService();
      final videos = await userDataService.getUserVideos(userId, limit: 100);

      if (kDebugMode) {
        debugPrint(
            '🎬 ProfileView: Loaded ${videos.length} videos directly from Firestore');
      }

      return videos;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ProfileView: Error loading videos directly: $e');
      }
      return [];
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
      if (kDebugMode) {
        debugPrint(
            '🎯 ProfileVideoFeedView: Fetched ${favorites.length} favorites for user $userId');
      }
      return favorites;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ProfileVideoFeedView: Error fetching user favorites: $e');
      }
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
        try {
          // Only try to load VideoService once per build cycle
          final videoServiceState = ref.watch(videoServiceProvider);
          final isLoadingVideos =
              ref.read(providers.videoServiceLoadingProvider);

          // Only trigger load if VideoService is empty and not already loading
          if (videoServiceState.isEmpty && !isLoadingVideos) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                final videoService = ref.read(videoServiceProvider.notifier);
                if (kDebugMode) {
                  debugPrint(
                      '🎬 ProfileView: VideoService is empty, loading videos...');
                }
                // Mark as loading to prevent multiple simultaneous loads
                ref.read(providers.videoServiceLoadingProvider.notifier).state =
                    true;
                // Load videos in background
                videoService.loadAllVideos().then((_) {
                  if (mounted) {
                    ref
                        .read(providers.videoServiceLoadingProvider.notifier)
                        .state = false;
                  }
                }).catchError((e, stackTrace) {
                  if (mounted) {
                    ref
                        .read(providers.videoServiceLoadingProvider.notifier)
                        .state = false;
                  }
                  if (kDebugMode) {
                    debugPrint('❌ ProfileView: Error loading videos: $e');
                    debugPrint('❌ ProfileView: Stack trace: $stackTrace');
                  }
                });
              } catch (e, stackTrace) {
                if (kDebugMode) {
                  debugPrint('❌ ProfileView: Error in postFrameCallback: $e');
                  debugPrint('❌ ProfileView: Stack trace: $stackTrace');
                }
                // Reset loading state on error
                try {
                  ref
                      .read(providers.videoServiceLoadingProvider.notifier)
                      .state = false;
                } catch (_) {
                  // Ignore errors when resetting state
                }
              }
            });
          }

          // Watch user videos from centralized VideoService
          final userVideos = ref.watch(userVideosProvider(widget.userId ?? ''));

          if (kDebugMode) {
            debugPrint(
                '🎬 ProfileView: Found ${userVideos.length} user videos for userId: ${widget.userId}');
            debugPrint(
                '🎬 ProfileView: Total videos in VideoService: ${videoServiceState.length}');
          }

          // If no videos found and VideoService is empty, try loading directly
          if (userVideos.isEmpty && videoServiceState.isEmpty) {
            return FutureBuilder<List<HomeVideo>>(
              future: _loadUserVideosDirectly(widget.userId ?? ''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF9248d2),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  if (kDebugMode) {
                    debugPrint(
                        '❌ ProfileView: Error loading videos directly: ${snapshot.error}');
                  }
                  return _buildEmptyState(
                    icon: Icons.videocam_outlined,
                    title: 'No Videos Yet',
                    subtitle: 'Start creating content to see your videos here',
                  );
                }

                final directVideos = snapshot.data ?? [];
                if (directVideos.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.videocam_outlined,
                    title: 'No Videos Yet',
                    subtitle: 'Start creating content to see your videos here',
                  );
                }

                // Show videos loaded directly
                final currentUser =
                    firebase_auth.FirebaseAuth.instance.currentUser;
                final isViewingOwnProfile = currentUser != null &&
                    widget.userId != null &&
                    widget.userId == currentUser.uid;

                if (isViewingOwnProfile) {
                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: LocalDraftService().getAllDrafts(),
                    builder: (context, draftSnapshot) {
                      final drafts = draftSnapshot.data ?? [];
                      return _buildVideoGridWithDrafts(directVideos, drafts);
                    },
                  );
                } else {
                  return _buildVideoGridWithoutDrafts(directVideos);
                }
              },
            );
          }

          // Check if viewing own profile - only show drafts for current user
          final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
          final isViewingOwnProfile = currentUser != null &&
              widget.userId != null &&
              widget.userId == currentUser.uid;

          // Only load drafts if viewing own profile
          if (isViewingOwnProfile) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: LocalDraftService().getAllDrafts(),
              builder: (context, snapshot) {
                final drafts = snapshot.data ?? [];

                if (kDebugMode) {
                  debugPrint(
                      '🎬 ProfileView: Found ${drafts.length} drafts (own profile)');
                }

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
          } else {
            // Viewing someone else's profile - don't show drafts
            if (userVideos.isEmpty) {
              return _buildEmptyState(
                icon: Icons.videocam_outlined,
                title: 'No Videos Yet',
                subtitle: 'This user hasn\'t posted any videos yet',
              );
            }

            return _buildVideoGridWithoutDrafts(userVideos);
          }
        } catch (e, stackTrace) {
          if (kDebugMode) {
            debugPrint('❌ ProfileView: Error in _buildUserVideosGrid: $e');
            debugPrint('❌ ProfileView: Stack trace: $stackTrace');
          }
          return _buildEmptyState(
            icon: Icons.error_outline,
            title: 'Error Loading Videos',
            subtitle: 'Please try again later',
          );
        }
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

          if (kDebugMode) {
            debugPrint(
                '📚 ProfileVideoFeedView: Found ${favorites.length} bookmarked videos');
          }

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
    // ✅ FIX: Load real tagged videos from Firestore
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    final targetUserId = widget.userId ?? currentUser?.uid;

    if (targetUserId == null) {
      return _buildEmptyState(
        icon: Icons.person_outline,
        title: 'No Tagged Content',
        subtitle: 'Videos where you\'re tagged will appear here',
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchTaggedVideos(targetUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF9248d2),
            ),
          );
        }

        if (snapshot.hasError) {
          if (kDebugMode) {
            debugPrint(
                '❌ ProfileVideoFeedView: Error loading tagged videos: ${snapshot.error}');
          }
          return _buildEmptyState(
            icon: Icons.error_outline,
            title: 'Error Loading Tagged Videos',
            subtitle: 'Please try again later',
          );
        }

        final taggedVideos = snapshot.data ?? [];

        if (taggedVideos.isEmpty) {
          return _buildEmptyState(
            icon: Icons.person_outline,
            title: 'No Tagged Content',
            subtitle: 'Videos where you\'re tagged will appear here',
          );
        }

        return _buildVideoGridContent(taggedVideos);
      },
    );
  }

  Widget _buildVideoGridWithDrafts(
      List<HomeVideo> videos, List<Map<String, dynamic>> drafts) {
    // Set up real-time deletion listeners for videos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRealtimeDeletionListeners(videos);
    });

    final itemCount = (drafts.isNotEmpty ? 1 : 0) + videos.length;

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
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // Show all drafts in the first position (index 0)
          if (drafts.isNotEmpty && index == 0) {
            final firstDraft = drafts[0];
            if (kDebugMode) {
              debugPrint(
                  '🎬 ProfileView: Building combined drafts card with ${drafts.length} drafts');
            }
            final draftVideo = HomeVideo(
              id: 'all_drafts',
              videoURL: firstDraft['videoPath'] ?? '',
              thumbnailURL: firstDraft['thumbnailPath'] ?? '',
              creator: User(
                id: 'current_user',
                displayName: 'You',
                username: 'you',
                bio: 'Your draft videos',
                avatarURL: '',
              ),
              caption: '${drafts.length} Draft${drafts.length > 1 ? 's' : ''}',
              categoryId: 'draft',
              views: 0,
              likes: 0,
              comments: 0,
              isDraft: true,
              createdAt: Timestamp.fromDate(
                DateTime.tryParse(firstDraft['createdAt']?.toString() ?? '') ??
                    DateTime.now(),
              ),
            );

            return _buildCombinedDraftsThumbnail(
              draftVideo,
              drafts.length,
              drafts,
            );
          }

          // Show published videos after the drafts thumbnail
          final videoIndex = drafts.isNotEmpty ? index - 1 : index;
          if (videoIndex >= 0 && videoIndex < videos.length) {
            final video = videos[videoIndex];
            return _buildHomeVideoCard(video, videoIndex, videos);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildVideoGridWithoutDrafts(List<HomeVideo> videos) {
    // Set up real-time deletion listeners for videos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRealtimeDeletionListeners(videos);
    });

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
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 9 / 16,
        ),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          // Ensure we're not showing drafts (safety check)
          if (video.isDraft == true) {
            return const SizedBox.shrink();
          }
          return _buildHomeVideoCard(video, index, videos);
        },
      ),
    );
  }

  Widget _buildVideoGridContent(List<Map<String, dynamic>> videos) {
    // Convert Map videos to HomeVideo for deletion listeners
    final homeVideos = videos
        .map((v) {
          try {
            return HomeVideo(
              id: v['id'] as String? ?? '',
              creator: User(
                id: v['creatorId'] as String? ?? '',
                displayName: v['creatorName'] as String? ?? 'Unknown',
                username: v['creatorUsername'] as String? ?? 'unknown',
                avatarURL: v['creatorAvatar'] as String?,
              ),
              videoURL:
                  v['videoURL'] as String? ?? v['videoUrl'] as String? ?? '',
              thumbnailURL:
                  v['thumbnailURL'] as String? ?? v['thumbnailUrl'] as String?,
              caption: v['caption'] as String? ?? '',
              likes: (v['likes'] as int?) ?? 0,
              comments: (v['comments'] as int?) ?? 0,
              views: (v['views'] as int?) ?? 0,
              duration: (v['duration'] as double?) ?? 0.0,
              categoryId: v['categoryId'] as String? ?? '',
            );
          } catch (e) {
            if (kDebugMode) {
              debugPrint('❌ Error converting video to HomeVideo: $e');
            }
            return null;
          }
        })
        .whereType<HomeVideo>()
        .toList();

    // Set up real-time deletion listeners for videos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRealtimeDeletionListeners(homeVideos);
    });

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
          return _buildPublishedVideoCard(video, index, videos);
        },
      ),
    );
  }

  Widget _buildCombinedDraftsThumbnail(
    HomeVideo draftVideo,
    int draftCount,
    List<Map<String, dynamic>> allDrafts,
  ) {
    return Stack(
      children: [
        GridThumbnail(
          video: draftVideo,
          onTap: () => _openAllDrafts(allDrafts),
          showDraftBadge: false,
          showDurationBadge: false,
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$draftCount Draft${draftCount > 1 ? 's' : ''}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeVideoCard(
      HomeVideo video, int index, List<HomeVideo> allVideos) {
    if (kDebugMode) {
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
    }
    return GridThumbnail(
      video: video,
      onTap: () {
        widget.onVideoTap?.call();
        // ✅ FIX: Pass all videos so user can swipe up/down to see other videos
        _openVideoPlayer(video, index, allVideos);
      },
      showDraftBadge: widget.feedType == ProfileVideoFeedType.videos,
      showDurationBadge: true,
    );
  }

  Widget _buildPublishedVideoCard(Map<String, dynamic> video, int index,
      List<Map<String, dynamic>> allVideos) {
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
        // ✅ FIX: Pass all videos and find correct index so user can swipe through them
        final correctIndex =
            allVideos.indexWhere((v) => (v['id'] ?? '') == homeVideo.id);
        final videoIndex = correctIndex >= 0 ? correctIndex : index;
        _openVideoPlayerFromMap(video, videoIndex, allVideos);
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

  void _openAllDrafts(List<Map<String, dynamic>> drafts) {
    if (mounted) {
      Navigator.of(context)
          .push(
        MaterialPageRoute(
          builder: (context) => DraftsSheetView(
            drafts: drafts,
            onDraftTap: (selectedDraft) => _editDraft(selectedDraft),
            onDelete: (draftToDelete) async {
              final success =
                  await LocalDraftService().deleteDraft(draftToDelete['id']);
              if (success) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Deleted draft: ${draftToDelete['caption']?.isNotEmpty == true ? draftToDelete['caption'] : 'Untitled Draft'}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete draft'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
              return success;
            },
          ),
        ),
      )
          .then((_) {
        // Refresh when returning from drafts sheet
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _editDraft(Map<String, dynamic> draft) {
    try {
      final videoFile = File(draft['videoPath']);
      if (!videoFile.existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video file not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final hashtags = (draft['hashtags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VideoPublishingScreen(
              videoFile: videoFile,
              caption: draft['caption'] ?? '',
              hashtags: hashtags,
              onPublish: () {
                // Delete draft after successful publish
                LocalDraftService().deleteDraft(draft['id']);
                Navigator.of(context).pop();
                setState(() {});
              },
              onCancel: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error editing draft: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening draft: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper methods

  /// ✅ FIX: Fetch real tagged videos from Firestore
  Future<List<Map<String, dynamic>>> _fetchTaggedVideos(String userId) async {
    try {
      if (kDebugMode) {
        debugPrint(
            '🏷️ ProfileVideoFeedView: Fetching tagged videos for user: $userId');
      }

      // Query tags collection to find videos where this user is tagged
      final tagsSnapshot = await FirebaseFirestore.instance
          .collection('tags')
          .where('taggedUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      if (tagsSnapshot.docs.isEmpty) {
        if (kDebugMode) {
          debugPrint(
              '🏷️ ProfileVideoFeedView: No tags found for user: $userId');
        }
        return [];
      }

      // Extract unique video IDs
      final videoIds = tagsSnapshot.docs
          .map((doc) => doc.data()['videoId'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .toList();

      if (videoIds.isEmpty) {
        if (kDebugMode) {
          debugPrint('🏷️ ProfileVideoFeedView: No valid video IDs found');
        }
        return [];
      }

      if (kDebugMode) {
        debugPrint(
            '🏷️ ProfileVideoFeedView: Found ${videoIds.length} tagged video IDs');
      }

      // Fetch video documents in batches (Firestore limit is 10 for 'whereIn')
      final List<Map<String, dynamic>> taggedVideos = [];
      const batchSize = 10;

      for (int i = 0; i < videoIds.length; i += batchSize) {
        final batch = videoIds.skip(i).take(batchSize).toList();
        final videosSnapshot = await FirebaseFirestore.instance
            .collection('videos')
            .where(FieldPath.documentId, whereIn: batch)
            .where('status', isEqualTo: 'published') // Only published videos
            .get();

        for (final doc in videosSnapshot.docs) {
          final data = doc.data();
          final videoCreatorId = data['userId'] ?? data['creatorId'] ?? '';

          // Fetch creator data
          final creatorDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(videoCreatorId)
              .get();

          if (!creatorDoc.exists) continue;

          final creatorData = creatorDoc.data()!;

          taggedVideos.add({
            'id': doc.id,
            'videoUrl': data['videoUrl'] ?? data['videoURL'] ?? '',
            'videoURL': data['videoUrl'] ?? data['videoURL'] ?? '',
            'thumbnailUrl': data['thumbnailUrl'] ?? data['thumbnailURL'] ?? '',
            'thumbnailURL': data['thumbnailUrl'] ?? data['thumbnailURL'] ?? '',
            'creatorId': videoCreatorId,
            'creatorName': creatorData['displayName'] ??
                creatorData['username'] ??
                'Unknown',
            'creatorUsername': creatorData['username'] ?? 'unknown',
            'creatorAvatar':
                creatorData['avatarURL'] ?? creatorData['avatarUrl'] ?? '',
            'likes': data['likes'] ?? data['likeCount'] ?? 0,
            'comments': data['comments'] ?? data['commentCount'] ?? 0,
            'views': data['views'] ?? data['viewCount'] ?? 0,
            'caption':
                data['caption'] ?? data['title'] ?? data['description'] ?? '',
            'duration': (data['duration'] ?? 0.0).toDouble(),
            'categoryId': data['categoryId'] ?? data['category'] ?? 'general',
            'createdAt': data['createdAt'] ?? Timestamp.now(),
          });
        }
      }

      debugPrint(
          '✅ ProfileVideoFeedView: Loaded ${taggedVideos.length} tagged videos');
      return taggedVideos;
    } catch (e) {
      debugPrint('❌ ProfileVideoFeedView: Error fetching tagged videos: $e');
      return [];
    }
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

      if (kDebugMode) {
        debugPrint(
            '🎯 ProfileVideoFeedView: Fetched ${videos.length} favorite videos from Firebase');
      }
      return videos;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ ProfileVideoFeedView: Error fetching favorite videos: $e');
      }
      return [];
    }
  }

  void _openVideoPlayer(HomeVideo video, int index, List<HomeVideo> videos) {
    final videoIds = videos.map((v) => v.id).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'playerScreen'),
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

  Future<void> _openVideoPlayerFromMap(Map<String, dynamic> video, int index,
      List<Map<String, dynamic>>? providedVideos) async {
    // Get all videos from the current feed based on feed type
    List<Map<String, dynamic>> allVideos;

    // If videos are provided (for user videos feed), use them directly
    if (providedVideos != null && providedVideos.isNotEmpty) {
      allVideos = providedVideos;
    } else {
      // Otherwise, fetch based on feed type (for favorites and tagged)
      allVideos = [];
      switch (widget.feedType) {
        case ProfileVideoFeedType.favorites:
          final favoritesState = ref.read(favoritesProvider);
          final favorites = favoritesState.favorites.toList();
          // Fetch real video data for favorites
          final favoriteVideos = await _fetchFavoriteVideos(favorites);
          allVideos = favoriteVideos;
          break;
        case ProfileVideoFeedType.tagged:
          // ✅ FIX: Fetch real tagged videos from Firestore
          final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
          final targetUserId = widget.userId ?? currentUser?.uid;
          if (targetUserId != null) {
            allVideos = await _fetchTaggedVideos(targetUserId);
          } else {
            allVideos = [];
          }
          break;
        case ProfileVideoFeedType.videos:
          // ✅ FIX: Get all user videos from provider so user can swipe through them
          final userVideos = ref.read(userVideosProvider(widget.userId ?? ''));
          // Convert HomeVideo list to Map format for consistency
          allVideos = userVideos
              .map((v) => {
                    'id': v.id,
                    'videoUrl': v.videoURL,
                    'videoURL': v.videoURL,
                    'thumbnailUrl': v.thumbnailURL,
                    'thumbnailURL': v.thumbnailURL,
                    'creatorId': v.creator.id,
                    'creatorName': v.creator.displayName,
                    'creatorUsername': v.creator.username,
                    'creatorAvatar': v.creator.avatarURL,
                    'likes': v.likes,
                    'comments': v.comments,
                    'views': v.views,
                    'caption': v.caption,
                    'duration': v.duration,
                    'categoryId': v.categoryId,
                    'createdAt': v.createdAt,
                  })
              .toList();
          break;
      }
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
        settings: const RouteSettings(name: 'playerScreen'),
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
