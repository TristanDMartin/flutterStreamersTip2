import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../providers/discover_provider.dart';
import '../providers/activity_provider.dart';
import '../providers/unread_messages_provider.dart';
import '../providers/follows_provider.dart';
import '../models/trending_creator.dart';
import 'category_card.dart';
import 'recommended_content_card.dart';
import 'streamer_card_view.dart';
import '../views/search_screen.dart';
import 'activity_view.dart';
import '../services/logging_service.dart';
import '../services/caching_service.dart';
import '../services/offline_storage_service.dart';
import '../services/accessibility_service.dart';
import '../services/global_playback_manager.dart';
import 'instant_response_button.dart';
import 'lazy_loading_list.dart';
import 'video_player_view_optimized.dart';
import '../models/home_video.dart';
import '../models/user.dart';
import '../providers/home_provider.dart' as hp;
// import 'video_thumbnail_view.dart'; // Removed - unused

/// 🔥 FIX: Field mapping utility for data model consistency
class FieldMapper {
  static String getUserId(Map<String, dynamic> data) {
    return data['userId'] ?? data['creatorId'] ?? data['creator_id'] ?? '';
  }

  static String getDisplayName(Map<String, dynamic> data) {
    return data['displayName'] ?? data['username'] ?? 'Unknown';
  }

  static String getAvatarUrl(Map<String, dynamic> data) {
    return data['avatarURL'] ?? data['profileImageURL'] ?? '';
  }

  static String getThumbnailUrl(Map<String, dynamic> data) {
    return data['thumbnailUrl'] ?? data['thumbnailURL'] ?? '';
  }

  static String getVideoUrl(Map<String, dynamic> data) {
    return data['videoUrl'] ?? data['videoURL'] ?? '';
  }

  static int safeInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double safeDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static String safeString(dynamic value) {
    return value?.toString() ?? '';
  }
}

class DiscoverView extends ConsumerStatefulWidget {
  const DiscoverView({super.key});

  @override
  ConsumerState<DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends ConsumerState<DiscoverView> {
  static const int _videosPerPage = 20;
  String? _selectedCategory;
  int _currentCategoryPage = 0;

  // 🔥 FIX: Enhanced caching with user-specific keys and TTL
  final Map<String, List<Map<String, dynamic>>> _cachedVideos = {};
  // Note: Cache timestamps and TTL are reserved for future implementation

  // Services
  final CachingService _cachingService = CachingService();
  final OfflineStorageService _offlineStorage = OfflineStorageService();
  final AccessibilityService _accessibilityService = AccessibilityService();

  // 🔥 FIX: Real-time subscriptions
  StreamSubscription<QuerySnapshot>? _trendingCreatorsSubscription;
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;

  // Common gradient used throughout the view
  static const LinearGradient _backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6633CC), // Purple (matches ProfileView)
      Color(0xFF1A1A4D), // Dark blue (matches ProfileView)
    ],
  );

  // 🔥 FIX: Consistent spacing and sizing constants
  // Note: These constants are reserved for future UI improvements

  @override
  void initState() {
    super.initState();
    // Initialize accessibility service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _accessibilityService.initialize(context);
      _loadInitialData();
      _setupRealtimeUpdates(); // 🔥 FIX: Add real-time updates
    });
  }

  @override
  void dispose() {
    // 🔥 FIX: Cancel real-time subscriptions
    _trendingCreatorsSubscription?.cancel();
    _notificationsSubscription?.cancel();

    // Clear cached videos to free memory
    _cachedVideos.clear();

    // Clean up audio when disposing DiscoverView
    GlobalPlaybackManager.instance.pauseAll();
    GlobalPlaybackManager.instance.block(reason: 'discover_view_disposed');

    super.dispose();
  }

  void _loadInitialData() {
    try {
      LoggingService.instance.debug(
        'Loading initial data',
        tag: 'DiscoverView',
      );
      ref.read(discoverProvider.notifier).loadTrendingCreators();
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error loading initial data',
        tag: 'DiscoverView',
        error: e,
        stackTrace: stackTrace,
      );
      // Safe error handling - don't call ErrorHandlerService during startup
      debugPrint('❌ DiscoverView initialization error: $e');
    }
  }

  /// 🔥 FIX: Set up real-time updates for trending creators and notifications
  void _setupRealtimeUpdates() {
    try {
      LoggingService.instance.debug(
        'Setting up real-time updates',
        tag: 'DiscoverView',
      );

      // 🔥 ENHANCED: Real-time trending creators updates based on video performance
      // Note: We'll refresh trending creators periodically instead of using a simple user stream
      // This ensures we always show creators whose videos are actually trending
      _setupTrendingCreatorsRefresh();

      // Real-time notifications updates
      final currentUser = fa.FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        _notificationsSubscription = FirebaseFirestore.instance
            .collection('notifications')
            .doc(currentUser.uid)
            .collection('items')
            .where('status', isEqualTo: 'pending')
            .snapshots()
            .listen(
          (snapshot) {
            if (mounted) {
              LoggingService.instance.debug(
                'Real-time notifications update: ${snapshot.docs.length} pending',
                tag: 'DiscoverView',
              );

              // Update notification count in real-time
              // Note: unreadMessagesProvider is a StreamProvider, so we don't need to update it manually
              // The provider will automatically update when the stream changes
            }
          },
          onError: (error) {
            LoggingService.instance.error(
              'Error in notifications stream',
              tag: 'DiscoverView',
              error: error,
            );
          },
        );
      }

      LoggingService.instance.debug(
        'Real-time updates setup complete',
        tag: 'DiscoverView',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error setting up real-time updates',
        tag: 'DiscoverView',
        error: e,
        stackTrace: stackTrace,
      );
      // Safe error handling - don't call ErrorHandlerService during startup
      debugPrint('❌ DiscoverView real-time setup error: $e');
    }
  }

  /// 🔥 ENHANCED: Set up periodic refresh of trending creators based on video performance
  void _setupTrendingCreatorsRefresh() {
    // Refresh trending creators every 5 minutes to catch new trending videos
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      LoggingService.instance.debug(
        '🔄 Refreshing trending creators based on video performance...',
        tag: 'DiscoverView',
      );

      // Use the enhanced algorithm to get trending creators
      ref.read(discoverProvider.notifier).loadTrendingCreators();
    });

    // Also refresh when new videos are uploaded (listen to videos collection)
    _trendingCreatorsSubscription = FirebaseFirestore.instance
        .collection('videos')
        .where(
          'createdAt',
          isGreaterThan: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(hours: 1)),
          ),
        )
        .snapshots()
        .listen(
      (snapshot) {
        if (mounted && snapshot.docs.isNotEmpty) {
          LoggingService.instance.debug(
            '🔥 New videos detected, refreshing trending creators...',
            tag: 'DiscoverView',
          );

          // Refresh trending creators when new videos are uploaded
          ref.read(discoverProvider.notifier).loadTrendingCreators();
        }
      },
      onError: (error) {
        LoggingService.instance.error(
          'Error in trending creators refresh stream',
          tag: 'DiscoverView',
          error: error,
        );
      },
    );
  }

  // Lazy loading methods
  Future<List<TrendingCreator>> _loadTrendingCreators(
    int page,
    int limit,
  ) async {
    try {
      // Check cache first
      final cacheKey = 'trending_creators_${page}_$limit';
      final cachedData = _cachingService.getMemoryCache<List<TrendingCreator>>(
        cacheKey,
      );
      if (cachedData != null) {
        return cachedData;
      }

      // Load from offline storage if available
      final offlineCreators = await _offlineStorage.getTrendingCreators();
      if (offlineCreators.isNotEmpty) {
        final startIndex = page * limit;
        final endIndex = (startIndex + limit).clamp(0, offlineCreators.length);
        final pageData = offlineCreators.sublist(startIndex, endIndex);

        // Cache the result
        _cachingService.setMemoryCache(cacheKey, pageData);
        return pageData;
      }

      // Fallback to provider
      final discoverState = ref.read(discoverProvider);
      final startIndex = page * limit;
      final endIndex = (startIndex + limit).clamp(
        0,
        discoverState.trendingCreators.length,
      );
      final pageData = discoverState.trendingCreators.sublist(
        startIndex,
        endIndex,
      );

      // Cache the result
      _cachingService.setMemoryCache(cacheKey, pageData);
      return pageData;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to load trending creators',
        tag: 'DiscoverView',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Widget _buildTrendingCreatorCard(
    BuildContext context,
    TrendingCreator creator,
    int index,
  ) {
    return _accessibilityService.createAccessibleListItem(
      semanticLabel:
          'Trending creator ${creator.displayName ?? creator.username}',
      semanticHint: 'Tap to view profile',
      onTap: () => _onCreatorTapped(creator),
      hapticFeedbackType: AccessibilityHapticFeedbackType.light,
      child: _buildTrendingCreatorItem(creator),
    );
  }

  void _onCreatorTapped(TrendingCreator creator) {
    HapticFeedback.lightImpact();
    LoggingService.instance.debug(
      'Creator tapped: ${creator.username}',
      tag: 'DiscoverView',
    );

    // Show StreamerCardView as full-screen modal (matching ProfileView/VideoPlayerView pattern)
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StreamerCardView(
          userId: creator.id,
          currentUserId: fa.FirebaseAuth.instance.currentUser?.uid,
          onDismiss: () => Navigator.of(context).pop(),
          onFollow: (userId) async {
            // Handle follow action using FollowsService
            HapticFeedback.lightImpact();
            LoggingService.instance.debug(
              'Follow action for user: $userId',
              tag: 'DiscoverView',
            );

            // Use the FollowsService provider to follow the user
            // This ensures EventTriggerService is properly initialized for notifications
            final followsService = ref.read(followsServiceProvider);
            final success = await followsService.followUser(userId);

            if (!success) {
              throw Exception('Failed to follow user');
            }
          },
          onMessage: (userId) {
            // Handle message action
            HapticFeedback.lightImpact();
            LoggingService.instance.debug(
              'Message action for user: $userId',
              tag: 'DiscoverView',
            );
          },
          onNavigateToTab: (tabName) {
            // Handle tab navigation
            HapticFeedback.lightImpact();
          },
          onShare: (userId) {
            // Handle share action
            HapticFeedback.lightImpact();
          },
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Widget _buildTrendingCreatorItem(TrendingCreator creator) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: creator.avatarURL != null
                ? NetworkImage(creator.avatarURL!)
                : null,
            child: creator.avatarURL == null
                ? Text(creator.username[0].toUpperCase())
                : null,
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              creator.displayName ?? creator.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${(creator.followerCount / 1000).toStringAsFixed(0)}K followers',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: _accessibilityService.getAccessibleIconSize(48),
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load creators',
            style: _accessibilityService.getAccessibleTextStyle(
              baseStyle: Theme.of(context).textTheme.headlineSmall!,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: _accessibilityService.getAccessibleTextStyle(
              baseStyle: Theme.of(context).textTheme.bodyMedium!,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Get responsive spacing based on screen size
  /// On very small screens, clamp to min 12dp gaps
  /// On tall screens, scale up to 24-32dp for a more breathable look
  double _getResponsiveSpacing(
    BuildContext context,
    double minSpacing,
    double maxSpacing,
  ) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Very small screens - clamp to minimum
    if (screenHeight < 600 || screenWidth < 360) {
      return 12.0;
    }

    // Calculate responsive spacing based on screen height
    final normalizedHeight =
        (screenHeight - 600) / (800 - 600); // Normalize between 600-800 height
    final spacing = minSpacing + (normalizedHeight * (maxSpacing - minSpacing));

    return spacing.clamp(12.0, 32.0); // Clamp between 12-32dp
  }

  void _onCategorySelected(String? categoryId) {
    try {
      // Add haptic feedback
      HapticFeedback.lightImpact();

      setState(() {
        _selectedCategory = categoryId;
        _currentCategoryPage = 0; // Reset pagination
      });

      // Category content is loaded dynamically in _getCategoryVideosForFeed

      // Show visual feedback and fetch content
      if (categoryId != null) {
        final discoverState = ref.read(discoverProvider);
        final category = discoverState.categories.firstWhere(
          (cat) => cat.id == categoryId,
          orElse: () => discoverState.categories.first,
        );

        // Category content is loaded dynamically in _getCategoryVideos

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Loading ${category.name} content...',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF6633CC),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        LoggingService.instance.debug(
          'Category selected: ${category.name}',
          tag: 'DiscoverView',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Showing all content',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF1A1A4D),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error selecting category',
        tag: 'DiscoverView',
        error: e,
        stackTrace: stackTrace,
      );
      // Safe error handling - don't call ErrorHandlerService during startup
      debugPrint('❌ DiscoverView category selection error: $e');
    }
  }

  void _navigateToActivity(BuildContext context) {
    LoggingService.instance.debug(
      'Bell icon tapped - navigating to ActivityView',
      tag: 'DiscoverView',
    );
    try {
      // Mark all notifications as read when opening ActivityView
      final currentUser = fa.FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final activityNotifier = ref.read(activityProvider.notifier);
        activityNotifier.markAllDelivered(currentUser.uid);
        LoggingService.instance.debug(
          'Marked all notifications as read',
          tag: 'DiscoverView',
        );
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) {
            LoggingService.instance.debug(
              'ActivityView page builder called',
              tag: 'DiscoverView',
            );
            return const ActivityView();
          },
        ),
      );
      LoggingService.instance.debug(
        'Navigation push completed',
        tag: 'DiscoverView',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Navigation error',
        tag: 'DiscoverView',
        error: e,
        stackTrace: stackTrace,
      );
      // Safe error handling - don't call ErrorHandlerService during startup
      debugPrint('❌ DiscoverView navigation error: $e');
    }
  }

  /// Safely cast dynamic data to List<String> for hashtags
  List<String> _safeCastToStringList(dynamic data) {
    if (data == null) return [];

    if (data is List) {
      return data.map((item) => item.toString()).toList();
    }

    if (data is String) {
      // If it's a single string, return it as a list with one item
      return [data];
    }

    // For any other type, convert to string and return as single-item list
    return [data.toString()];
  }

  /// Convert video data from DiscoverView format to HomeVideo model
  HomeVideo _convertToHomeVideo(Map<String, dynamic> video) {
    return HomeVideo(
      id: video['id'] ?? 'discover_${DateTime.now().millisecondsSinceEpoch}',
      videoURL: video['videoUrl'] ?? video['videoURL'] ?? '',
      thumbnailURL: video['thumbnailUrl'] ?? video['thumbnailURL'] ?? '',
      caption: video['title'] ?? 'Discover Video',
      creator: User(
        id: video['creatorId'] ?? 'unknown_creator',
        username: video['creator'] ?? 'Unknown Creator',
        displayName: video['creatorDisplayName'] ??
            video['creator'] ??
            'Unknown Creator',
        avatarURL: video['creatorAvatar'] ?? '',
        bio: video['creatorBio'] ?? '',
        hashtags: _safeCastToStringList(video['creatorHashtags']),
        followerCount: FieldMapper.safeInt(video['creatorFollowers']),
        followingCount: FieldMapper.safeInt(video['creatorFollowing']),
        postCount: FieldMapper.safeInt(video['creatorVideos']),
      ),
      likes: FieldMapper.safeInt(video['likes']),
      comments: FieldMapper.safeInt(video['comments']),
      views: FieldMapper.safeInt(video['views']),
      duration: FieldMapper.safeDouble(video['duration']),
      isLiked: video['isLiked'] ?? false,
      isFavorited: video['isFavorited'] ?? false,
      createdAt: video['createdAt'] ?? Timestamp.now(),
    );
  }

  Widget _buildNotificationButton(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadMessagesProvider);
    final activityState = ref.watch(activityProvider);

    // Calculate total unread count (messages + activity notifications)
    int totalUnreadCount = 0;
    unreadCountAsync.whenOrNull(
      data: (unreadCount) => totalUnreadCount += unreadCount,
    );

    // Add activity notification count
    int pendingCount = 0;
    for (final notifications in activityState.grouped.values) {
      for (final notification in notifications) {
        if (notification.status == 'pending') {
          pendingCount++;
          totalUnreadCount++;
        }
      }
    }

    // Debug badge calculation
    if (pendingCount > 0 || totalUnreadCount > 0) {
      LoggingService.instance.debug(
          '🔔 DiscoverView Badge: total=$totalUnreadCount, pending=$pendingCount, sections=${activityState.grouped.length}',
          tag: 'DiscoverView');
    }

    // Ensure ActivityProvider is initialized for current user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = fa.FirebaseAuth.instance.currentUser;
      if (currentUser != null && !activityState.isLoading) {
        final notifier = ref.read(activityProvider.notifier);
        if (!notifier.isInitialized) {
          notifier.init(currentUser.uid);
          LoggingService.instance.debug(
              '🔔 ActivityProvider initialized for user: ${currentUser.uid}',
              tag: 'DiscoverView');
        }
      }
    });

    return GestureDetector(
      onTap: () {
        LoggingService.instance.debug(
          'GestureDetector onTap triggered',
          tag: 'DiscoverView',
        );
        _navigateToActivity(context);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            const Icon(
              Icons.notifications_outlined,
              color: Colors.white,
              size: 24,
            ),
            // Notification badge
            if (totalUnreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    totalUnreadCount > 99 ? '99+' : totalUnreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final discoverViewModel = ref.watch(discoverProvider.notifier);
    final discoverState = ref.watch(discoverProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: _backgroundGradient),
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: InstantIconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                hapticType: HapticFeedbackType.lightImpact,
              ),
              title: const Text(
                'Discover',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              actions: [_buildNotificationButton(context, ref)],
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SearchScreen(),
                      ),
                    );
                  },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: Colors.white.withValues(alpha: 0.6),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Search creators, videos, hashtags…',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white.withValues(alpha: 0.4),
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Trending Creators Section with Lazy Loading
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20, // Increased top padding to move section down
                  bottom: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trending Creators',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(
                      height: 200,
                      child: LazyLoadingList<TrendingCreator>(
                        loadData: _loadTrendingCreators,
                        itemBuilder: _buildTrendingCreatorCard,
                        itemsPerPage: 10,
                        emptyBuilder: (context) =>
                            _buildEmptyTrendingCreatorsState(),
                        loadingBuilder: (context) => _buildLoadingState(),
                        errorBuilder: _buildErrorState,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Categories Section - brought up by using Transform.translate
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 0,
                  bottom: 0,
                ),
                child: Transform.translate(
                  offset:
                      const Offset(0, -12), // Move Categories up by 12 pixels
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Categories',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      // Categories PageView with proper spacing
                      SizedBox(
                        height: 320,
                        child: PageView.builder(
                          onPageChanged: (page) {
                            setState(() {
                              _currentCategoryPage = page;
                            });
                          },
                          itemCount:
                              (discoverState.categories.length / 6).ceil(),
                          itemBuilder: (context, pageIndex) {
                            final startIndex = pageIndex * 6;
                            final endIndex = (startIndex + 6).clamp(
                              0,
                              discoverState.categories.length,
                            );
                            final pageCategories = discoverState.categories
                                .sublist(startIndex, endIndex);

                            return Padding(
                              // Add bottom padding to prevent overlap with dots
                              padding: EdgeInsets.only(
                                bottom: _getResponsiveSpacing(context, 12, 12) +
                                    12, // Dots height + spacing
                              ),
                              child: GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: pageCategories.length,
                                itemBuilder: (context, index) {
                                  final category = pageCategories[index];
                                  return _accessibilityService
                                      .createAccessibleButton(
                                    semanticLabel: 'Category ${category.name}',
                                    semanticHint: _selectedCategory ==
                                            category.id
                                        ? 'Currently selected category. Tap to deselect.'
                                        : 'Tap to select this category',
                                    onPressed: () => _onCategorySelected(
                                      _selectedCategory == category.id
                                          ? null
                                          : category.id,
                                    ),
                                    hapticFeedbackType:
                                        AccessibilityHapticFeedbackType.light,
                                    child: CategoryCard(
                                      key: ValueKey(category.id),
                                      category: category,
                                      isSelected:
                                          _selectedCategory == category.id,
                                      onTap: () => _onCategorySelected(
                                        _selectedCategory == category.id
                                            ? null
                                            : category.id,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),

                      // Reduced spacing between categories and dots
                      SizedBox(
                        height: 8,
                      ),

                      // Page indicator with proper safe area handling
                      Center(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).padding.bottom + 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              (discoverState.categories.length / 6).ceil(),
                              (index) => Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: index == _currentCategoryPage
                                      ? const Color(0xFF40DCD1)
                                      : const Color(
                                          0xFF6B5AE0,
                                        ).withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Content based on category selection
            if (_selectedCategory == null) ...[
              // Default view - show resources
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resources',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: discoverState.recommendedContent.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: RecommendedContentCard(
                              content: discoverState.recommendedContent[index],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Category selected - show 3-column video grid with tap to open swipeable feed
              _buildCategoryVideoGridSliver(discoverState, discoverViewModel),
            ],

            // Bottom padding for tab bar
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryVideoGridSliver(
    DiscoverState discoverState,
    DiscoverNotifier discoverViewModel,
  ) {
    if (_selectedCategory == null)
      return const SliverToBoxAdapter(child: SizedBox.shrink());

    // Get the selected category
    final selectedCategory = discoverState.categories.firstWhere(
      (cat) => cat.id == _selectedCategory,
      orElse: () => discoverState.categories.first,
    );

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category header with clear button
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${selectedCategory.name} Videos',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                InstantTextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = null;
                    });
                  },
                  hapticType: HapticFeedbackType.lightImpact,
                  child: const Text(
                    'Clear Filter',
                    style: TextStyle(
                      color: Color(0xFF6633CC),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 3-column video grid with tap to open swipeable feed
            _buildVideoGridWithTapToSwipe(selectedCategory.id, discoverState),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoGridWithTapToSwipe(
    String categoryId,
    DiscoverState discoverState,
  ) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getCategoryVideosForFeed(categoryId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(context, snapshot.error.toString());
        }

        final categoryVideos = snapshot.data ?? [];

        if (categoryVideos.isEmpty) {
          return _buildEmptyCategoryState();
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
            childAspectRatio: 9 / 16, // 9:16 aspect ratio for portrait videos
          ),
          itemCount: categoryVideos.length,
          itemBuilder: (context, index) {
            return _buildVideoGridItemWithTap(
              categoryVideos[index],
              categoryVideos,
              index,
            );
          },
        );
      },
    );
  }

  Widget _buildVideoGridItemWithTap(
    Map<String, dynamic> video,
    List<Map<String, dynamic>> allVideos,
    int currentIndex,
  ) {
    return GestureDetector(
      onTap: () {
        LoggingService.instance.debug(
          'Tapped video: ${video['title']}',
          tag: 'DiscoverView',
        );
        _openSwipeableVideoFeed(allVideos, currentIndex);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[800],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video thumbnail
            Builder(
              builder: (context) {
                final thumbnailUrl = video['thumbnailUrl'] ??
                    video['thumbnailURL'] ??
                    video['thumbnail'] ??
                    '';

                if (thumbnailUrl.isNotEmpty) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      thumbnailUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: Icon(
                              Icons.video_library_outlined,
                              color: Colors.white54,
                              size: 32,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                } else {
                  return Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: Icon(
                        Icons.video_library_outlined,
                        color: Colors.white54,
                        size: 32,
                      ),
                    ),
                  );
                }
              },
            ),
            // Play button overlay
            const Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white,
                size: 40,
              ),
            ),
            // Duration badge (if available)
            Builder(
              builder: (context) {
                // Check both direct duration field and metadata.duration field
                dynamic duration = video['duration'];
                if (duration == null) {
                  final metadata = video['metadata'] as Map<String, dynamic>?;
                  duration = metadata?['duration'];
                }

                if (duration != null) {
                  return Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(dynamic duration) {
    if (duration == null) return '0:00';

    // Debug logging to see what we're getting
    LoggingService.instance.debug(
      'Duration value: $duration, type: ${duration.runtimeType}',
      tag: 'DiscoverView',
    );

    int seconds = 0;

    if (duration is double) {
      seconds = duration.round();
    } else if (duration is int) {
      seconds = duration;
    } else if (duration is String) {
      // Handle duration stored as string (e.g., "120" or "2:00")
      if (duration.contains(':')) {
        // Parse format like "2:00" or "1:30"
        final parts = duration.split(':');
        if (parts.length == 2) {
          final minutes = int.tryParse(parts[0]) ?? 0;
          final secs = int.tryParse(parts[1]) ?? 0;
          seconds = minutes * 60 + secs;
        }
      } else {
        // Parse as seconds string
        seconds = int.tryParse(duration) ?? 0;
      }
    } else if (duration is Duration) {
      seconds = duration.inSeconds;
    }

    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    final formatted = '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';

    LoggingService.instance.debug(
      'Formatted duration: $formatted',
      tag: 'DiscoverView',
    );
    return formatted;
  }

  void _openSwipeableVideoFeed(
    List<Map<String, dynamic>> videos,
    int startIndex,
  ) {
    // Convert to HomeVideo objects for VideoPlayerViewOptimized
    final homeVideos =
        videos.map((video) => _convertToHomeVideo(video)).toList();

    // Navigate to full-screen swipeable video feed using HomeView pattern
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _CategoryVideoFeed(
          videos: homeVideos,
          startIndex: startIndex,
          categoryId: _selectedCategory ?? 'unknown',
        ),
      ),
    );
  }

  /// Category video feed widget that follows HomeView's audio management pattern exactly
  Widget _CategoryVideoFeed({
    required List<HomeVideo> videos,
    required int startIndex,
    required String categoryId,
  }) {
    return _CategoryVideoFeedStateful(
      videos: videos,
      startIndex: startIndex,
      categoryId: categoryId,
    );
  }

  /// Get videos for the category feed with proper ordering (new videos first, then shuffle)
  Future<List<Map<String, dynamic>>> _getCategoryVideosForFeed(
    String categoryId,
  ) async {
    try {
      LoggingService.instance.debug(
        'Loading category feed videos for: $categoryId',
        tag: 'DiscoverView',
      );

      // Load mixed videos (new + trending)
      final mixedVideos = await _loadMixedCategoryVideos(categoryId, null);

      LoggingService.instance.debug(
        'Raw mixed videos loaded: ${mixedVideos.length} for $categoryId',
        tag: 'DiscoverView',
      );

      if (mixedVideos.isEmpty) {
        LoggingService.instance.debug(
          'No mixed videos found for $categoryId',
          tag: 'DiscoverView',
        );
        return [];
      }

      // Debug: Log video data to see duration field
      for (int i = 0; i < mixedVideos.length && i < 3; i++) {
        final video = mixedVideos[i];
        LoggingService.instance.debug(
          'Video $i: title=${video['title']}, duration=${video['duration']}, durationType=${video['duration']?.runtimeType}',
          tag: 'DiscoverView',
        );

        // Also check metadata.duration field
        final metadata = video['metadata'] as Map<String, dynamic>?;
        if (metadata != null) {
          LoggingService.instance.debug(
            'Video $i metadata: duration=${metadata['duration']}, durationType=${metadata['duration']?.runtimeType}',
            tag: 'DiscoverView',
          );
        }

        // Log all available fields
        LoggingService.instance.debug(
          'Video $i all fields: ${video.keys.toList()}',
          tag: 'DiscoverView',
        );
      }

      // Sort videos: new videos first, then by trending score
      mixedVideos.sort((a, b) {
        final aIsNew = a['isNew'] as bool;
        final bIsNew = b['isNew'] as bool;
        final aScore = a['trendingScore'] as double;
        final bScore = b['trendingScore'] as double;

        // New videos always appear first
        if (aIsNew && !bIsNew) return -1;
        if (!aIsNew && bIsNew) return 1;

        // Then sort by trending score (highest first)
        return bScore.compareTo(aScore);
      });

      // Convert to the format expected by the UI
      final videos = <Map<String, dynamic>>[];
      final userIds = <String>{};

      for (final videoData in mixedVideos) {
        final data = videoData['data'] as Map<String, dynamic>?;
        if (data == null) {
          LoggingService.instance.debug(
            'Skipping video with null data: ${videoData['docId']}',
            tag: 'DiscoverView',
          );
          continue;
        }

        final userId = (data['userId'] ??
            data['creatorId'] ??
            data['creator_id']) as String?;
        if (userId != null) {
          userIds.add(userId);
        }
      }

      LoggingService.instance.debug(
        'Found ${userIds.length} unique user IDs for $categoryId',
        tag: 'DiscoverView',
      );

      // Batch fetch user data
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: userIds.toList())
          .get();

      final userMap = <String, Map<String, dynamic>>{};
      for (final doc in usersSnapshot.docs) {
        userMap[doc.id] = doc.data();
      }

      LoggingService.instance.debug(
        'Fetched ${userMap.length} user documents for $categoryId',
        tag: 'DiscoverView',
      );

      // Build final video list
      for (final videoData in mixedVideos) {
        final data = videoData['data'] as Map<String, dynamic>;
        final userId = (data['userId'] ??
            data['creatorId'] ??
            data['creator_id']) as String?;

        if (userId == null) {
          LoggingService.instance.debug(
            'Skipping video with null userId: ${videoData['docId']}',
            tag: 'DiscoverView',
          );
          continue;
        }

        final userData = userMap[userId];
        if (userData == null) {
          LoggingService.instance.debug(
            'Skipping video with missing user data: ${videoData['docId']}, userId: $userId',
            tag: 'DiscoverView',
          );
          continue;
        }

        final thumbnailUrl = FieldMapper.getThumbnailUrl(data);

        videos.add({
          'id': videoData['docId'],
          'title': FieldMapper.safeString(
            data['caption'] ?? data['title'] ?? 'Untitled',
          ),
          'creator': FieldMapper.getDisplayName(userData),
          'thumbnail': thumbnailUrl,
          'thumbnailUrl': thumbnailUrl,
          'thumbnailURL': thumbnailUrl,
          'views': FieldMapper.safeInt(data['views'] ?? data['viewsCount']),
          'duration': FieldMapper.safeDouble(data['duration']),
          'videoUrl': FieldMapper.getVideoUrl(data),
          'creatorId': userId,
          'creatorAvatar': FieldMapper.getAvatarUrl(userData),
          'creatorUsername': FieldMapper.safeString(userData['username']),
          'creatorDisplayName': FieldMapper.getDisplayName(userData),
          'creatorBio': FieldMapper.safeString(userData['bio']),
          'creatorHashtags': userData['hashtags'] ?? [],
          'creatorFollowers': FieldMapper.safeInt(userData['followerCount']),
          'creatorFollowing': FieldMapper.safeInt(userData['followingCount']),
          'creatorVideos': FieldMapper.safeInt(userData['postCount']),
          'likes': FieldMapper.safeInt(data['likes'] ?? data['likesCount']),
          'comments': FieldMapper.safeInt(
            data['comments'] ?? data['commentsCount'],
          ),
          'createdAt': data['createdAt'],
          'isLiked': data['isLiked'] ?? false,
          'isFavorited': data['isFavorited'] ?? false,
          'trendingScore': videoData['trendingScore'] ?? 0.0,
          'isNew': videoData['isNew'] ?? false,
          'isTrending': (videoData['trendingScore'] ?? 0.0) > 100.0,
        });
      }

      LoggingService.instance.debug(
        'Category feed prepared ${videos.length} videos for $categoryId',
        tag: 'DiscoverView',
      );

      return videos;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error loading category feed videos for $categoryId',
        tag: 'DiscoverView',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Widget _buildLoadingState() {
    return const SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 12),
            Text(
              'Loading trending creators...',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTrendingCreatorsState() {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people, size: 32, color: Colors.white70),
            const SizedBox(height: 12),
            Text(
              'No trending creators yet',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCategoryState() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.video_library_outlined,
              size: 48,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            Text(
              'No videos found for this category',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to upload a video!',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  /// Load mixed category videos (recent + trending)
  Future<List<Map<String, dynamic>>> _loadMixedCategoryVideos(
    String categoryId,
    DocumentSnapshot? startAfter,
  ) async {
    try {
      LoggingService.instance.debug(
        'Loading mixed category videos for: $categoryId',
        tag: 'DiscoverView',
      );

      // Load recent videos (last 7 days)
      final recentVideos = await _loadRecentVideos(categoryId, startAfter);
      LoggingService.instance.debug(
        'Loaded ${recentVideos.length} recent videos for $categoryId',
        tag: 'DiscoverView',
      );

      // Load trending videos
      final trendingVideos = await _loadTrendingVideos(categoryId, startAfter);
      LoggingService.instance.debug(
        'Loaded ${trendingVideos.length} trending videos for $categoryId',
        tag: 'DiscoverView',
      );

      // Always try to load additional uncategorized videos as fallback
      // This ensures existing videos without categories also appear
      LoggingService.instance.debug(
        'Loading fallback videos for $categoryId to include uncategorized content',
        tag: 'DiscoverView',
      );

      final fallbackVideos = await _loadAllCategoryVideos(
        categoryId,
        startAfter,
      );
      LoggingService.instance.debug(
        'Fallback query returned ${fallbackVideos.length} videos for $categoryId',
        tag: 'DiscoverView',
      );

      // If we have categorized videos, combine them with fallback videos
      if (recentVideos.isNotEmpty || trendingVideos.isNotEmpty) {
        LoggingService.instance.debug(
          'Combining ${recentVideos.length + trendingVideos.length} categorized videos with ${fallbackVideos.length} fallback videos',
          tag: 'DiscoverView',
        );

        // Add fallback videos that aren't already in the categorized list
        final existingIds = <String>{};
        for (final video in recentVideos) {
          existingIds.add(video['docId'] as String);
        }
        for (final video in trendingVideos) {
          existingIds.add(video['docId'] as String);
        }

        for (final fallbackVideo in fallbackVideos) {
          final docId = fallbackVideo['docId'] as String;
          if (!existingIds.contains(docId)) {
            recentVideos.add({
              ...fallbackVideo,
              'isNew': false, // Fallback videos are not marked as new
            });
          }
        }

        LoggingService.instance.debug(
          'After combining: ${recentVideos.length} total videos for $categoryId',
          tag: 'DiscoverView',
        );
      } else {
        // If no categorized videos, return fallback videos
        LoggingService.instance.debug(
          'No categorized videos found, returning ${fallbackVideos.length} fallback videos for $categoryId',
          tag: 'DiscoverView',
        );
        return fallbackVideos;
      }

      // Combine and deduplicate
      final allVideos = <String, Map<String, dynamic>>{};

      // Add recent videos first
      for (final video in recentVideos) {
        final docId = video['docId'] as String;
        allVideos[docId] = {...video, 'isNew': true, 'trendingScore': 0.0};
      }

      // Add trending videos (don't override recent ones)
      for (final video in trendingVideos) {
        final docId = video['docId'] as String;
        if (!allVideos.containsKey(docId)) {
          allVideos[docId] = {
            ...video,
            'isNew': false,
            'trendingScore': video['trendingScore'] ?? 0.0,
          };
        }
      }

      final mixedVideos = allVideos.values.toList();
      LoggingService.instance.debug(
        'Combined ${mixedVideos.length} total videos for $categoryId',
        tag: 'DiscoverView',
      );

      // Apply pagination
      final paginatedVideos = _applyPagination(mixedVideos, startAfter);

      LoggingService.instance.debug(
        'Mixed feed: ${recentVideos.length} recent + ${trendingVideos.length} trending = ${paginatedVideos.length} total',
        tag: 'DiscoverView',
      );

      return paginatedVideos;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error loading mixed category videos for $categoryId',
        tag: 'DiscoverView',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Fallback method to load all videos for a category (no restrictions)
  Future<List<Map<String, dynamic>>> _loadAllCategoryVideos(
    String categoryId,
    DocumentSnapshot? startAfter,
  ) async {
    try {
      LoggingService.instance.debug(
        'Loading ALL videos for category: $categoryId (fallback)',
        tag: 'DiscoverView',
      );

      LoggingService.instance.debug(
        'Searching for category: "$categoryId"',
        tag: 'DiscoverView',
      );

      // Query by 'category' field first, then try 'categoryId' if no results
      Query? query = FirebaseFirestore.instance
          .collection('videos')
          .where('category', isEqualTo: categoryId)
          .where('status', isEqualTo: 'published')
          .orderBy('createdAt', descending: true)
          .limit(_videosPerPage);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      LoggingService.instance.debug(
        'Executing Firestore query: category=$categoryId, status=published, limit=$_videosPerPage',
        tag: 'DiscoverView',
      );

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get();

        LoggingService.instance.debug(
          'Query with category field returned ${snapshot.docs.length} documents',
          tag: 'DiscoverView',
        );

        // If no results, try with 'categoryId' field
        if (snapshot.docs.isEmpty) {
          LoggingService.instance.debug(
            'No results with category field, trying categoryId field',
            tag: 'DiscoverView',
          );
          query = FirebaseFirestore.instance
              .collection('videos')
              .where('categoryId', isEqualTo: categoryId)
              .where('status', isEqualTo: 'published')
              .orderBy('createdAt', descending: true)
              .limit(_videosPerPage);

          if (startAfter != null) {
            query = query.startAfterDocument(startAfter);
          }

          snapshot = await query.get();

          LoggingService.instance.debug(
            'Query with categoryId field returned ${snapshot.docs.length} documents',
            tag: 'DiscoverView',
          );
        }
      } catch (e) {
        // If query fails due to index or other issues, try without status filter
        LoggingService.instance.debug(
          'Query with status filter failed, trying without status filter: $e',
          tag: 'DiscoverView',
        );
        try {
          query = FirebaseFirestore.instance
              .collection('videos')
              .where('category', isEqualTo: categoryId)
              .orderBy('createdAt', descending: true)
              .limit(_videosPerPage);

          if (startAfter != null) {
            query = query.startAfterDocument(startAfter);
          }

          snapshot = await query.get();

          LoggingService.instance.debug(
            'Query without status filter returned ${snapshot.docs.length} documents',
            tag: 'DiscoverView',
          );
        } catch (e2) {
          // If still fails, try with categoryId without status filter
          LoggingService.instance.debug(
            'Query failed, trying categoryId without status filter: $e2',
            tag: 'DiscoverView',
          );
          query = FirebaseFirestore.instance
              .collection('videos')
              .where('categoryId', isEqualTo: categoryId)
              .orderBy('createdAt', descending: true)
              .limit(_videosPerPage);

          if (startAfter != null) {
            query = query.startAfterDocument(startAfter);
          }

          snapshot = await query.get();

          LoggingService.instance.debug(
            'Query with categoryId (no status filter) returned ${snapshot.docs.length} documents',
            tag: 'DiscoverView',
          );
        }
      }

      final videos = <Map<String, dynamic>>[];

      LoggingService.instance.debug(
        'Fallback query returned ${snapshot.docs.length} documents',
        tag: 'DiscoverView',
      );

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        LoggingService.instance.debug(
          'Video ${doc.id}: category=${data?['category']}, createdAt=${data?['createdAt']}',
          tag: 'DiscoverView',
        );

        videos.add({
          'docId': doc.id,
          'data': data,
          'isNew': false,
          'trendingScore': 0.0,
        });
      }

      LoggingService.instance.debug(
        'Processed ${videos.length} fallback videos for $categoryId',
        tag: 'DiscoverView',
      );

      return videos;
    } catch (e) {
      LoggingService.instance.error(
        'Error loading all category videos for $categoryId',
        tag: 'DiscoverView',
        error: e,
      );
      return [];
    }
  }

  /// Load recent videos (last 7 days)
  Future<List<Map<String, dynamic>>> _loadRecentVideos(
    String categoryId,
    DocumentSnapshot? startAfter,
  ) async {
    try {
      LoggingService.instance.debug(
        'Loading recent videos for category: $categoryId',
        tag: 'DiscoverView',
      );

      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      // Try to query by both 'category' and 'categoryId' fields
      Query? query = FirebaseFirestore.instance
          .collection('videos')
          .where('category', isEqualTo: categoryId)
          .where('createdAt', isGreaterThan: sevenDaysAgo)
          .orderBy('createdAt', descending: true)
          .limit(_videosPerPage);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      LoggingService.instance.debug(
        'Executing Firestore query for recent videos: category=$categoryId, limit=$_videosPerPage',
        tag: 'DiscoverView',
      );

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get();

        // If no results, try with 'categoryId' field
        if (snapshot.docs.isEmpty) {
          LoggingService.instance.debug(
            'No results with category field, trying categoryId field',
            tag: 'DiscoverView',
          );
          query = FirebaseFirestore.instance
              .collection('videos')
              .where('categoryId', isEqualTo: categoryId)
              .where('createdAt', isGreaterThan: sevenDaysAgo)
              .orderBy('createdAt', descending: true)
              .limit(_videosPerPage);

          if (startAfter != null) {
            query = query.startAfterDocument(startAfter);
          }

          snapshot = await query.get();
        }
      } catch (e) {
        // If query fails, try with 'categoryId' field instead
        LoggingService.instance.debug(
          'Query with category field failed, trying categoryId field: $e',
          tag: 'DiscoverView',
        );
        try {
          query = FirebaseFirestore.instance
              .collection('videos')
              .where('categoryId', isEqualTo: categoryId)
              .where('createdAt', isGreaterThan: sevenDaysAgo)
              .orderBy('createdAt', descending: true)
              .limit(_videosPerPage);

          if (startAfter != null) {
            query = query.startAfterDocument(startAfter);
          }

          snapshot = await query.get();
        } catch (e2) {
          // If still fails, try with categoryId without date filter
          LoggingService.instance.debug(
            'Query with date filter failed, trying categoryId without date filter: $e2',
            tag: 'DiscoverView',
          );
          query = FirebaseFirestore.instance
              .collection('videos')
              .where('categoryId', isEqualTo: categoryId)
              .orderBy('createdAt', descending: true)
              .limit(_videosPerPage);

          if (startAfter != null) {
            query = query.startAfterDocument(startAfter);
          }

          snapshot = await query.get();
        }
      }
      final videos = <Map<String, dynamic>>[];

      LoggingService.instance.debug(
        'Firestore returned ${snapshot.docs.length} documents for recent videos',
        tag: 'DiscoverView',
      );

      for (final doc in snapshot.docs) {
        videos.add({'docId': doc.id, 'data': doc.data()});
      }

      LoggingService.instance.debug(
        'Processed ${videos.length} recent videos for $categoryId',
        tag: 'DiscoverView',
      );

      return videos;
    } catch (e) {
      LoggingService.instance.error(
        'Error loading recent videos for $categoryId',
        tag: 'DiscoverView',
        error: e,
      );
      return [];
    }
  }

  /// Load trending videos
  Future<List<Map<String, dynamic>>> _loadTrendingVideos(
    String categoryId,
    DocumentSnapshot? startAfter,
  ) async {
    try {
      LoggingService.instance.debug(
        'Loading trending videos for category: $categoryId',
        tag: 'DiscoverView',
      );

      // Try to query by both 'category' and 'categoryId' fields
      Query? query = FirebaseFirestore.instance
          .collection('videos')
          .where('category', isEqualTo: categoryId)
          .where('trendingScore', isGreaterThan: 50.0)
          .orderBy('trendingScore', descending: true)
          .limit(_videosPerPage);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      LoggingService.instance.debug(
        'Executing Firestore query for trending videos: category=$categoryId, limit=$_videosPerPage',
        tag: 'DiscoverView',
      );

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get();

        LoggingService.instance.debug(
          'Query with category field returned ${snapshot.docs.length} documents',
          tag: 'DiscoverView',
        );

        // If no results, try with 'categoryId' field
        if (snapshot.docs.isEmpty) {
          LoggingService.instance.debug(
            'No results with category field, trying categoryId field',
            tag: 'DiscoverView',
          );
          query = FirebaseFirestore.instance
              .collection('videos')
              .where('categoryId', isEqualTo: categoryId)
              .where('trendingScore', isGreaterThan: 50.0)
              .orderBy('trendingScore', descending: true)
              .limit(_videosPerPage);

          if (startAfter != null) {
            query = query.startAfterDocument(startAfter);
          }

          snapshot = await query.get();

          LoggingService.instance.debug(
            'Query with categoryId field returned ${snapshot.docs.length} documents',
            tag: 'DiscoverView',
          );
        }
      } catch (e) {
        // If query fails, try with 'categoryId' field instead
        LoggingService.instance.debug(
          'Query with category field failed, trying categoryId field: $e',
          tag: 'DiscoverView',
        );
        query = FirebaseFirestore.instance
            .collection('videos')
            .where('categoryId', isEqualTo: categoryId)
            .where('trendingScore', isGreaterThan: 50.0)
            .orderBy('trendingScore', descending: true)
            .limit(_videosPerPage);

        if (startAfter != null) {
          query = query.startAfterDocument(startAfter);
        }

        snapshot = await query.get();

        LoggingService.instance.debug(
          'Query with categoryId field returned ${snapshot.docs.length} documents',
          tag: 'DiscoverView',
        );
      }
      final videos = <Map<String, dynamic>>[];

      LoggingService.instance.debug(
        'Firestore returned ${snapshot.docs.length} documents for trending videos',
        tag: 'DiscoverView',
      );

      for (final doc in snapshot.docs) {
        videos.add({'docId': doc.id, 'data': doc.data()});
      }

      LoggingService.instance.debug(
        'Processed ${videos.length} trending videos for $categoryId',
        tag: 'DiscoverView',
      );

      return videos;
    } catch (e) {
      LoggingService.instance.error(
        'Error loading trending videos for $categoryId',
        tag: 'DiscoverView',
        error: e,
      );
      return [];
    }
  }

  /// Apply pagination to video list
  List<Map<String, dynamic>> _applyPagination(
    List<Map<String, dynamic>> videos,
    DocumentSnapshot? startAfter,
  ) {
    if (startAfter == null) {
      return videos.take(_videosPerPage).toList();
    }
    return videos;
  }
}

/// Stateful widget for category video feed that follows HomeView's pattern exactly
class _CategoryVideoFeedStateful extends ConsumerStatefulWidget {
  final List<HomeVideo> videos;
  final int startIndex;
  final String categoryId;

  const _CategoryVideoFeedStateful({
    required this.videos,
    required this.startIndex,
    required this.categoryId,
  });

  @override
  ConsumerState<_CategoryVideoFeedStateful> createState() =>
      _CategoryVideoFeedStatefulState();
}

class _CategoryVideoFeedStatefulState
    extends ConsumerState<_CategoryVideoFeedStateful> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex;
    _pageController = PageController(initialPage: widget.startIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (didPop) {
        if (didPop) {
          // Clean up when navigating back
          LoggingService.instance.debug(
            'Category video feed closed, current index: $_currentIndex',
            tag: 'DiscoverView',
          );
        }
      },
      child: Material(
        color: Colors.black,
        child: Stack(
          children: [
            // Video content fills entire screen (exact HomeView pattern)
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: const ClampingScrollPhysics(), // Same as HomeView
                onPageChanged: (index) {
                  LoggingService.instance.debug(
                    'Category video page changed to index: $index, video ID: ${widget.videos[index].id}',
                    tag: 'DiscoverView',
                  );
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemCount: widget.videos.length,
                itemBuilder: (context, index) {
                  final video = widget.videos[index];
                  final isCurrentVideo =
                      index == _currentIndex; // HomeView pattern

                  LoggingService.instance.debug(
                    'Creating VideoPlayerViewOptimized for index: $index, isCurrent: $isCurrentVideo, video ID: ${video.id}',
                    tag: 'DiscoverView',
                  );

                  return VideoPlayerViewOptimized(
                    key: ValueKey(video.id), // Stable key like HomeView
                    video: video,
                    isCurrentVideo: isCurrentVideo, // HomeView pattern
                    isFirstVideo: index == 0,
                    tabId: 'discoverView_${widget.categoryId}',
                    homeViewModel: ref.read(hp.homeProvider.notifier),
                    showSheet: false,
                    sheetType: '',
                    showHUD: true, // Show HUD like HomeView
                    onShowProfile: () {
                      // Handle profile view
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => StreamerCardView(
                            userId: video.creator.id,
                            currentUserId:
                                fa.FirebaseAuth.instance.currentUser?.uid,
                            onDismiss: () => Navigator.of(context).pop(),
                            onFollow: (userId) async {
                              final followsService = ref.read(
                                followsServiceProvider,
                              );
                              await followsService.followUser(userId);
                            },
                            onMessage: (userId) {
                              // Handle message action
                            },
                            onNavigateToTab: (tabName) {
                              // Handle tab navigation
                            },
                            onShare: (userId) {
                              // Handle share action
                            },
                          ),
                          fullscreenDialog: true,
                        ),
                      );
                    },
                    onShowComments: () {
                      // Handle comments
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            backgroundColor: Colors.black,
                            appBar: AppBar(
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              leading: IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                ),
                              ),
                              title: const Text(
                                'Comments',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            body: const Center(
                              child: Text(
                                'Comments coming soon!',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    onShowShare: () {
                      // Handle share
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Share feature coming soon!'),
                          backgroundColor: Color(0xFF6633CC),
                        ),
                      );
                    },
                    onShowStreamerCard: () {
                      // Handle streamer card
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => StreamerCardView(
                            userId: video.creator.id,
                            currentUserId:
                                fa.FirebaseAuth.instance.currentUser?.uid,
                            onDismiss: () => Navigator.of(context).pop(),
                            onFollow: (userId) async {
                              final followsService = ref.read(
                                followsServiceProvider,
                              );
                              await followsService.followUser(userId);
                            },
                            onMessage: (userId) {
                              // Handle message action
                            },
                            onNavigateToTab: (tabName) {
                              // Handle tab navigation
                            },
                            onShare: (userId) {
                              // Handle share action
                            },
                          ),
                          fullscreenDialog: true,
                        ),
                      );
                    },
                    isLiked: video.isLiked,
                    isBookmarked: video.isFavorited,
                  );
                },
              ),
            ),
            // Back button overlay (HomeView pattern)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: SafeArea(
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
