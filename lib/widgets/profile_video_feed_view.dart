import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'dart:async';
import 'dart:io';
import '../core/theme/support_shell_style.dart';
import '../providers/favorites_provider.dart';
import '../services/unified_bookmark_service.dart';
import '../models/home_video.dart';
import '../models/user.dart';
import '../services/video_service.dart';
import '../services/local_draft_service.dart';
import '../services/optimistic_video_service.dart';
import '../models/optimistic_video.dart';
import '../providers/video_service_provider.dart' as providers;
import 'profile_view/profile_post_count_reconcile.dart';
import '../routing/app_navigator.dart';
import '../utils/avatar_url_resolver.dart';
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
  StreamSubscription<String>? _optimisticFeedRefreshSubscription;
  Future<List<Map<String, dynamic>>>? _draftsFuture;
  List<Map<String, dynamic>> _lastResolvedDrafts =
      const <Map<String, dynamic>>[];
  bool _bootstrapLoadScheduled = false;
  String? _mergedProfileVideosForUserId;
  Set<String> _lastSyncedListenerVideoIds = const <String>{};

  bool get _isViewingOwnProfile {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    return currentUser != null &&
        widget.userId != null &&
        widget.userId == currentUser.uid;
  }

  @override
  void initState() {
    super.initState();
    _resetCachedFutures();
    _primeProfileVideoTab();
    _optimisticFeedRefreshSubscription =
        OptimisticVideoService().feedRefreshStream.listen((_) {
      if (!mounted) return;
      if (widget.feedType != ProfileVideoFeedType.videos) return;
      if (!_isViewingOwnProfile) return;

      _resetCachedFutures();
      _mergedProfileVideosForUserId = null;
      ref.invalidate(userVideosProvider(widget.userId ?? ''));
      ref.read(providers.videoServiceStateProvider.notifier).loadAllVideos();
      final String? uid = widget.userId;
      if (uid != null && uid.isNotEmpty) {
        ref
            .read(providers.videoServiceStateProvider.notifier)
            .mergeProfileVideosForUser(uid)
            .then((_) async {
          if (!mounted) {
            return;
          }
          await ProfilePostCountReconcile.afterProfileVideoMerge(uid);
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProfileVideoFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.feedType != widget.feedType) {
      _resetCachedFutures();
      _bootstrapLoadScheduled = false;
      _mergedProfileVideosForUserId = null;
      _lastSyncedListenerVideoIds = const <String>{};
      _primeProfileVideoTab();
    }
  }

  @override
  void dispose() {
    _optimisticFeedRefreshSubscription?.cancel();
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

  void _resetCachedFutures() {
    _draftsFuture = null;
    _lastResolvedDrafts = const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> _getDraftsFuture() {
    return _draftsFuture ??= LocalDraftService().getAllDrafts();
  }

  void _primeProfileVideoTab() {
    if (widget.feedType != ProfileVideoFeedType.videos) return;
    if (_isViewingOwnProfile) {
      _getDraftsFuture();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureVideoServiceLoaded();
      _mergeProfileVideosForGridIfNeeded();
    });
  }

  void _mergeProfileVideosForGridIfNeeded() {
    if (widget.feedType != ProfileVideoFeedType.videos) {
      return;
    }
    final String? uid = widget.userId;
    if (uid == null || uid.isEmpty) {
      return;
    }
    if (_mergedProfileVideosForUserId == uid) {
      return;
    }
    _mergedProfileVideosForUserId = uid;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      try {
        await ref
            .read(providers.videoServiceStateProvider.notifier)
            .mergeProfileVideosForUser(uid);
        if (mounted && _isViewingOwnProfile) {
          await ProfilePostCountReconcile.afterProfileVideoMerge(uid);
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('❌ ProfileView: mergeProfileVideosForUser failed: $e');
          debugPrint('$stackTrace');
        }
      }
    });
  }

  void _ensureVideoServiceLoaded() {
    if (!mounted || widget.feedType != ProfileVideoFeedType.videos) return;

    final videoServiceState = ref.read(providers.videoServiceStateProvider);
    final isLoadingVideos = ref.read(providers.videoServiceLoadingProvider);
    if (videoServiceState.isNotEmpty) {
      _bootstrapLoadScheduled = false;
      return;
    }
    if (isLoadingVideos || _bootstrapLoadScheduled) {
      return;
    }

    _bootstrapLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        if (kDebugMode) {
          debugPrint(
              '🎬 ProfileView: VideoService is empty, loading videos...');
        }
        ref
            .read(providers.videoServiceLoadingProvider.notifier)
            .setIsLoading(true);
        await ref
            .read(providers.videoServiceStateProvider.notifier)
            .loadAllVideos();
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('❌ ProfileView: Error bootstrapping videos: $e');
          debugPrint('❌ ProfileView: Stack trace: $stackTrace');
        }
      } finally {
        if (mounted) {
          ref
              .read(providers.videoServiceLoadingProvider.notifier)
              .setIsLoading(false);
        }
        _bootstrapLoadScheduled = false;
      }
    });
  }

  void _scheduleRealtimeDeletionSync(List<HomeVideo> videos) {
    final nextIds = videos.take(15).map((video) => video.id).toSet();
    if (setEquals(_lastSyncedListenerVideoIds, nextIds)) {
      return;
    }
    _lastSyncedListenerVideoIds = nextIds;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _setupRealtimeDeletionListeners(videos);
    });
  }

  /// Set up real-time deletion listeners for videos (first 15 to limit reads)
  void _setupRealtimeDeletionListeners(List<HomeVideo> videos) {
    final videosToListen = videos.take(15).toList();
    final currentVideoIds = videosToListen.map((v) => v.id).toSet();
    final listenersToRemove = _videoListeners.keys
        .where((id) => !currentVideoIds.contains(id))
        .toList();
    for (final id in listenersToRemove) {
      _videoListeners[id]?.cancel();
      _videoListeners.remove(id);
    }

    for (final video in videosToListen) {
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
        final status = (data?['status'] as String?)?.toLowerCase();

        // Published videos in this app commonly use `active`, so keep those
        // mounted instead of treating them like deleted content.
        const visibleStatuses = {'published', 'ready', 'active'};
        if (status == 'deleted' ||
            (status != null && !visibleStatuses.contains(status))) {
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
    ref.invalidate(providers.videoServiceStateProvider);
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
          final videoServiceState =
              ref.watch(providers.videoServiceStateProvider);
          final isLoadingVideos =
              ref.watch(providers.videoServiceLoadingProvider);
          final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
          final isViewingOwnProfile = currentUser != null &&
              widget.userId != null &&
              widget.userId == currentUser.uid;
          _ensureVideoServiceLoaded();

          // Watch user videos from centralized VideoService
          final userVideos = ref.watch(userVideosProvider(widget.userId ?? ''));
          final List<OptimisticVideo> optimisticVideos = _isViewingOwnProfile
              ? (OptimisticVideoService()
                  .getOptimisticVideosForUser(widget.userId ?? '')
                  .where((video) => video.status.isProcessing)
                  .where((video) =>
                      !userVideos.any((item) => item.id == video.videoId))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
              : <OptimisticVideo>[];

          if (kDebugMode) {
            debugPrint(
                '🎬 ProfileView: Found ${userVideos.length} user videos for userId: ${widget.userId}');
            debugPrint(
                '🎬 ProfileView: Total videos in VideoService: ${videoServiceState.length}');
            debugPrint(
                '🎬 ProfileView: Found ${optimisticVideos.length} optimistic processing videos');
          }

          final bool isServiceBootstrapping =
              videoServiceState.isEmpty && isLoadingVideos;
          final bool shouldShowLoadingPlaceholder = videoServiceState.isEmpty &&
              userVideos.isEmpty &&
              optimisticVideos.isEmpty &&
              (isLoadingVideos || !isViewingOwnProfile);

          // Own profile should stay on one stable grid path instead of bouncing
          // between multiple async sources while VideoService warms up.
          if (isViewingOwnProfile) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _getDraftsFuture(),
              initialData: _lastResolvedDrafts,
              builder: (context, snapshot) {
                final drafts = snapshot.data ?? _lastResolvedDrafts;
                if (snapshot.hasData) {
                  _lastResolvedDrafts = drafts;
                }

                if (userVideos.isEmpty &&
                    drafts.isEmpty &&
                    optimisticVideos.isEmpty &&
                    isServiceBootstrapping) {
                  return _buildLoadingGridPlaceholder();
                }

                if (userVideos.isEmpty &&
                    drafts.isEmpty &&
                    optimisticVideos.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.videocam_outlined,
                    title: 'No Videos Yet',
                    subtitle: 'Start creating content to see your videos here',
                  );
                }

                return _buildVideoGridWithDrafts(
                  userVideos,
                  drafts,
                  optimisticVideos,
                );
              },
            );
          }

          if (shouldShowLoadingPlaceholder) {
            return _buildLoadingGridPlaceholder();
          }

          if (userVideos.isEmpty && optimisticVideos.isEmpty) {
            return _buildEmptyState(
              icon: Icons.videocam_outlined,
              title: 'No Videos Yet',
              subtitle: 'This user hasn\'t posted any videos yet',
            );
          }

          return _buildVideoGridWithoutDrafts(userVideos);
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
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
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
                return Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
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
                return Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
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
                    return Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
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
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
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
      List<HomeVideo> videos,
      List<Map<String, dynamic>> drafts,
      List<OptimisticVideo> optimisticVideos) {
    _scheduleRealtimeDeletionSync(videos);

    final itemCount =
        (drafts.isNotEmpty ? 1 : 0) + optimisticVideos.length + videos.length;
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return RefreshIndicator(
      onRefresh: () async {
        _resetCachedFutures();
        // Refresh data based on feed type
        switch (widget.feedType) {
          case ProfileVideoFeedType.favorites:
            await ref.read(favoritesProvider.notifier).forceSync();
            break;
          case ProfileVideoFeedType.videos:
          case ProfileVideoFeedType.tagged:
            ref.invalidate(userVideosProvider(widget.userId ?? ''));
            await ref
                .read(providers.videoServiceStateProvider.notifier)
                .loadAllVideos();
            break;
        }
      },
      color: shell.refreshColor,
      backgroundColor: shell.refreshBackground,
      child: MasonryGridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          final draftOffset = drafts.isNotEmpty ? 1 : 0;

          // Show all drafts in the first position (index 0)
          if (drafts.isNotEmpty && index == 0) {
            final firstDraft = drafts[0];
            if (kDebugMode) {
              debugPrint(
                  '🎬 ProfileView: Building combined drafts card with ${drafts.length} drafts');
            }
            final draftVideo = HomeVideo(
              id: 'all_drafts',
              videoURL: firstDraft['videoPath'] ?? firstDraft['videoUrl'] ?? '',
              thumbnailURL:
                  firstDraft['thumbnailPath'] ?? firstDraft['thumbnailUrl'],
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

          final optimisticIndex = index - draftOffset;
          if (optimisticIndex >= 0 &&
              optimisticIndex < optimisticVideos.length) {
            return _buildOptimisticProcessingCard(
              optimisticVideos[optimisticIndex],
            );
          }

          // Show published videos after the drafts thumbnail
          final videoIndex = index - draftOffset - optimisticVideos.length;
          if (videoIndex >= 0 && videoIndex < videos.length) {
            final video = videos[videoIndex];
            return _buildHomeVideoCard(video, videoIndex, videos);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildOptimisticProcessingCard(OptimisticVideo video) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final tileWidth = (screenWidth - 32 - 32) / 3;

    DecorationImage? backgroundImage;
    if (video.localThumbnailPath != null &&
        video.localThumbnailPath!.isNotEmpty) {
      final localFile = File(video.localThumbnailPath!);
      if (localFile.existsSync()) {
        backgroundImage = DecorationImage(
          image: FileImage(localFile),
          fit: BoxFit.cover,
        );
      }
    } else if (video.thumbnailUrl != null && video.thumbnailUrl!.isNotEmpty) {
      backgroundImage = DecorationImage(
        image: NetworkImage(video.thumbnailUrl!),
        fit: BoxFit.cover,
      );
    }

    final progress = ((video.uploadProgress ?? 0.0) * 100).clamp(0, 100);

    return AspectRatio(
      aspectRatio: _resolveAspectRatioFromOptimisticVideo(video),
      child: Opacity(
        opacity: 0.92,
        child: Container(
          width: tileWidth,
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(12),
            image: backgroundImage,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.12),
                        Colors.black.withValues(alpha: 0.22),
                        Colors.black.withValues(alpha: 0.62),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1670DE).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Processing',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.38),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (video.caption.isNotEmpty)
                        Text(
                          video.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (video.caption.isNotEmpty) const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (video.uploadProgress ?? 0.0).clamp(0.0, 1.0),
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(999),
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF9248D2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        progress <= 0
                            ? 'Preparing your post...'
                            : 'Transcoding ${progress.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoGridWithoutDrafts(List<HomeVideo> videos) {
    _scheduleRealtimeDeletionSync(videos);
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return RefreshIndicator(
      onRefresh: () async {
        _resetCachedFutures();
        // Refresh data based on feed type
        switch (widget.feedType) {
          case ProfileVideoFeedType.favorites:
            await ref.read(favoritesProvider.notifier).forceSync();
            break;
          case ProfileVideoFeedType.videos:
          case ProfileVideoFeedType.tagged:
            ref.invalidate(userVideosProvider(widget.userId ?? ''));
            await ref
                .read(providers.videoServiceStateProvider.notifier)
                .loadAllVideos();
            break;
        }
      },
      color: shell.refreshColor,
      backgroundColor: shell.refreshBackground,
      child: MasonryGridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
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

    _scheduleRealtimeDeletionSync(homeVideos);
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return RefreshIndicator(
      onRefresh: () async {
        _resetCachedFutures();
        // Refresh data based on feed type
        switch (widget.feedType) {
          case ProfileVideoFeedType.favorites:
            await ref.read(favoritesProvider.notifier).forceSync();
            break;
          case ProfileVideoFeedType.videos:
          case ProfileVideoFeedType.tagged:
            ref.invalidate(userVideosProvider(widget.userId ?? ''));
            await ref
                .read(providers.videoServiceStateProvider.notifier)
                .loadAllVideos();
            break;
        }
      },
      color: shell.refreshColor,
      backgroundColor: shell.refreshBackground,
      child: MasonryGridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
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
    final latestDraft =
        allDrafts.isNotEmpty ? allDrafts.first : const <String, dynamic>{};
    final latestCaption =
        (latestDraft['caption'] as String?)?.trim().isNotEmpty == true
            ? (latestDraft['caption'] as String).trim()
            : 'Continue editing your drafts';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openAllDrafts(allDrafts),
      child: Stack(
        children: [
          GridThumbnail(
            video: draftVideo,
            onTap: null,
            showDraftBadge: false,
            showDurationBadge: false,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.10),
                      Colors.black.withValues(alpha: 0.20),
                      Colors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Drafts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.52),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Text(
                  '$draftCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    latestCaption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    draftCount == 1
                        ? '1 draft ready to finish'
                        : '$draftCount drafts ready to finish',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
      aspectRatio: _resolveAspectRatioFromHomeVideo(video),
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
      aspectRatio: _resolveAspectRatioFromVideoMap(video),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: shell.iconDim,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.62),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingGridPlaceholder() {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 9 / 16,
      ),
      itemCount: 6,
      itemBuilder: (BuildContext context, int index) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                shell.skeletonFill,
                shell.skeletonLineDim,
              ],
            ),
          ),
        );
      },
    );
  }

  double _resolveAspectRatioFromHomeVideo(HomeVideo video) {
    final ratio = video.thumbnails?.aspectRatio;
    return _sanitizeAspectRatio(ratio);
  }

  double _resolveAspectRatioFromOptimisticVideo(OptimisticVideo video) {
    final metadata = video.metadata;
    if (metadata != null) {
      final ratio = _readNum(metadata['aspectRatio']) ??
          _readNum(metadata['videoAspectRatio']) ??
          _readRatioFromDimensions(
            _readNum(metadata['sourceWidth']),
            _readNum(metadata['sourceHeight']),
          );
      if (ratio != null) {
        return _sanitizeAspectRatio(ratio);
      }
    }
    return 9 / 16;
  }

  double _resolveAspectRatioFromVideoMap(Map<String, dynamic> video) {
    final ratio = _readNum(video['aspectRatio']) ??
        _readNum(video['videoAspectRatio']) ??
        _readNum(video['thumbnails']?['aspectRatio']) ??
        _readRatioFromDimensions(
          _readNum(video['sourceWidth'] ?? video['width']),
          _readNum(video['sourceHeight'] ?? video['height']),
        ) ??
        _readRatioFromDimensions(
          _readNum(video['metadata']?['sourceWidth']),
          _readNum(video['metadata']?['sourceHeight']),
        );
    return _sanitizeAspectRatio(ratio);
  }

  double _sanitizeAspectRatio(double? ratio) {
    const fallback = 9 / 16;
    if (ratio == null || ratio.isNaN || ratio.isInfinite || ratio <= 0) {
      return fallback;
    }
    return ratio.clamp(0.45, 2.2);
  }

  double? _readRatioFromDimensions(double? width, double? height) {
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  }

  double? _readNum(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
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
              final messenger = ScaffoldMessenger.of(context);
              final success =
                  await LocalDraftService().deleteDraft(draftToDelete['id']);
              if (success) {
                if (!mounted) return success;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                        'Deleted draft: ${draftToDelete['caption']?.isNotEmpty == true ? draftToDelete['caption'] : 'Untitled Draft'}'),
                    backgroundColor: Colors.red,
                  ),
                );
              } else {
                if (!mounted) return success;
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete draft'),
                    backgroundColor: Colors.red,
                  ),
                );
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
      final draftId = draft['id'] as String?;
      if (draftId == null || draftId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft is missing its ID'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      LocalDraftService().ensureLocalVideoFile(draftId).then((videoFile) {
        if (!mounted) return;

        if (videoFile == null || !videoFile.existsSync()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Draft video is not available on this device yet'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final hashtags = (draft['hashtags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

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
      });
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

  /// ✅ FIX: Fetch real tagged videos from Firestore (requires auth).
  Future<List<Map<String, dynamic>>> _fetchTaggedVideos(String userId) async {
    if (firebase_auth.FirebaseAuth.instance.currentUser == null) {
      return [];
    }
    try {
      if (kDebugMode) {
        debugPrint(
            '🏷️ ProfileVideoFeedView: Fetching tagged videos for user: $userId');
      }

      // Keep this query index-light. Some production tag documents were created
      // before the current schema, so filter the user field locally instead of
      // relying on a composite taggedUserId + createdAt query.
      QuerySnapshot<Map<String, dynamic>> tagsSnapshot;
      try {
        tagsSnapshot = await FirebaseFirestore.instance
            .collection('tags')
            .orderBy('createdAt', descending: true)
            .limit(250)
            .get();
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              '🏷️ ProfileVideoFeedView: Ordered tags query failed, using fallback: $e');
        }
        tagsSnapshot = await FirebaseFirestore.instance
            .collection('tags')
            .limit(250)
            .get();
      }

      if (tagsSnapshot.docs.isEmpty) {
        if (kDebugMode) {
          debugPrint(
              '🏷️ ProfileVideoFeedView: No tags found for user: $userId');
        }
        return [];
      }

      // Extract unique video IDs for tags that match this profile user.
      final videoIds = tagsSnapshot.docs
          .map((doc) => doc.data())
          .where((data) => _tagMatchesUser(data, userId))
          .map(_tagVideoId)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
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
        final videoDocs = await Future.wait(batch.map((videoId) =>
            FirebaseFirestore.instance
                .collection('videos')
                .doc(videoId)
                .get()));

        for (final doc in videoDocs) {
          if (!doc.exists) continue;
          final data = doc.data();
          if (data == null) continue;
          final status = (data['status'] ?? 'published').toString();
          if (!{'published', 'ready', 'active'}.contains(status)) continue;
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
            'creatorAvatar': resolveAvatarUrl(creatorData) ?? '',
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
      if (e.toString().contains('permission-denied') ||
          e.toString().contains('PERMISSION_DENIED')) {
        return [];
      }
      debugPrint('❌ ProfileVideoFeedView: Error fetching tagged videos: $e');
      return [];
    }
  }

  bool _tagMatchesUser(Map<String, dynamic> tagData, String userId) {
    bool matches(dynamic value) {
      if (value == null) return false;
      if (value is DocumentReference) {
        return value.id == userId || value.path.endsWith('/$userId');
      }
      if (value is String) {
        return value == userId || value.endsWith('/$userId');
      }
      if (value is Map) {
        return matches(value['id']) ||
            matches(value['uid']) ||
            matches(value['userId']) ||
            matches(value['path']);
      }
      return false;
    }

    return matches(tagData['taggedUserId']) ||
        matches(tagData['taggedUserRef']) ||
        matches(tagData['taggedUser']) ||
        matches(tagData['userId']);
  }

  String? _tagVideoId(Map<String, dynamic> tagData) {
    final value =
        tagData['videoId'] ?? tagData['videoRef'] ?? tagData['video'] ?? '';
    if (value is DocumentReference) return value.id;
    if (value is String) {
      if (value.isEmpty) return null;
      return value.contains('/') ? value.split('/').last : value;
    }
    if (value is Map) {
      final id = value['id'] ?? value['videoId'] ?? value['path'];
      if (id is String && id.isNotEmpty) {
        return id.contains('/') ? id.split('/').last : id;
      }
    }
    return null;
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

    AppNavigator.openPlayer(
      context,
      mode: PlayerMode.homeFeed,
      initialIndex: index,
      videoIds: videoIds,
      videos: videos,
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

    if (!mounted) return;
    AppNavigator.openPlayer(
      context,
      mode: PlayerMode.homeFeed,
      initialIndex: index,
      videoIds: videoIds,
      videos: homeVideos,
    );
  }
}
