import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/discover_provider.dart';
import '../providers/activity_provider.dart';
import '../providers/unread_messages_provider.dart';
import '../models/trending_creator.dart';
import 'category_card.dart';
import 'recommended_content_card.dart';
// import 'search_screen.dart'; // Removed - unused
import 'activity_view.dart';
import '../services/logging_service.dart';
import '../services/error_handler_service.dart';
import '../services/caching_service.dart';
import '../services/offline_storage_service.dart';
import '../services/accessibility_service.dart';
import 'instant_response_button.dart';
import 'lazy_loading_list.dart';
import 'video_player_view_optimized.dart';
import '../models/home_video.dart';
import '../models/user.dart';
import '../providers/home_provider.dart' as hp;
// import 'video_thumbnail_view.dart'; // Removed - unused

class DiscoverView extends ConsumerStatefulWidget {
  const DiscoverView({super.key});

  @override
  ConsumerState<DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends ConsumerState<DiscoverView> {
  String? _selectedCategory;
  int _currentCategoryPage = 0;

  // Video grid pagination
  static const int _videosPerPage = 12;
  int _currentVideoPage = 0;
  bool _isLoadingMoreVideos = false;
  final Map<String, List<Map<String, dynamic>>> _cachedVideos = {};

  // Services
  final CachingService _cachingService = CachingService();
  final OfflineStorageService _offlineStorage = OfflineStorageService();
  final AccessibilityService _accessibilityService = AccessibilityService();

  // Common gradient used throughout the view
  static const LinearGradient _backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6633CC), // Purple (matches ProfileView)
      Color(0xFF1A1A4D), // Dark blue (matches ProfileView)
    ],
  );

  @override
  void initState() {
    super.initState();
    // Initialize accessibility service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _accessibilityService.initialize(context);
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    // Clear cached videos to free memory
    _cachedVideos.clear();
    super.dispose();
  }

  void _loadInitialData() {
    try {
      LoggingService.instance
          .debug('Loading initial data', tag: 'DiscoverView');
      ref.read(discoverProvider.notifier).loadTrendingCreators();
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error loading initial data',
          tag: 'DiscoverView', error: e, stackTrace: stackTrace);
      ErrorHandlerService.instance.handleError(e, stackTrace, context: context);
    }
  }

  // Lazy loading methods
  Future<List<TrendingCreator>> _loadTrendingCreators(
      int page, int limit) async {
    try {
      // Check cache first
      final cacheKey = 'trending_creators_${page}_$limit';
      final cachedData =
          _cachingService.getMemoryCache<List<TrendingCreator>>(cacheKey);
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
      final endIndex =
          (startIndex + limit).clamp(0, discoverState.trendingCreators.length);
      final pageData =
          discoverState.trendingCreators.sublist(startIndex, endIndex);

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
      BuildContext context, TrendingCreator creator, int index) {
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
    // Creator profile navigation - placeholder for future implementation
    LoggingService.instance
        .debug('Creator tapped: ${creator.username}', tag: 'DiscoverView');
  }

  Widget _buildTrendingCreatorItem(TrendingCreator creator) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Column(
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
          Text(
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
          Text(
            '${(creator.followerCount / 1000).toStringAsFixed(0)}K followers',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
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
      BuildContext context, double minSpacing, double maxSpacing) {
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
        _currentVideoPage = 0; // Reset video pagination
        _isLoadingMoreVideos = false; // Reset loading state
      });

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

        LoggingService.instance
            .debug('Category selected: ${category.name}', tag: 'DiscoverView');
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
      LoggingService.instance.error('Error selecting category',
          tag: 'DiscoverView', error: e, stackTrace: stackTrace);
      ErrorHandlerService.instance.handleError(e, stackTrace, context: context);
    }
  }

  void _navigateToActivity(BuildContext context) {
    LoggingService.instance.debug(
        'Bell icon tapped - navigating to ActivityView',
        tag: 'DiscoverView');
    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) {
            LoggingService.instance
                .debug('ActivityView page builder called', tag: 'DiscoverView');
            return const ActivityView();
          },
        ),
      );
      LoggingService.instance
          .debug('Navigation push completed', tag: 'DiscoverView');
    } catch (e, stackTrace) {
      LoggingService.instance.error('Navigation error',
          tag: 'DiscoverView', error: e, stackTrace: stackTrace);
      ErrorHandlerService.instance.handleError(e, stackTrace, context: context);
    }
  }

  void _showVideoDetails(Map<String, dynamic> video) {
    // Convert video data to HomeVideo model for VideoPlayerViewOptimized
    final homeVideo = _convertToHomeVideo(video);

    // Navigate to full-screen video player with audio enhancement
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Full-screen video player with TikTok-style audio enhancement
              VideoPlayerViewOptimized(
                video: homeVideo,
                isCurrentVideo: true,
                isFirstVideo: true,
                tabId: 'discoverView', // Specific tab ID for DiscoverView
                homeViewModel: ref.read(hp.homeProvider.notifier),
                showSheet: false,
                sheetType: '',
                onShowProfile: () {
                  // Handle profile view
                  Navigator.of(context).pop();
                },
                onShowComments: () {
                  // Handle comments
                  Navigator.of(context).pop();
                },
                onShowShare: () {
                  // Handle share
                  Navigator.of(context).pop();
                },
                onShowStreamerCard: () {
                  // Handle streamer card
                  Navigator.of(context).pop();
                },
                isLiked: false,
                isBookmarked: false,
              ),
              // Close button
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 28,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    shape: const CircleBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        hashtags: video['creatorHashtags'] ?? [],
        followerCount: video['creatorFollowers'] ?? 0,
        followingCount: video['creatorFollowing'] ?? 0,
        postCount: video['creatorVideos'] ?? 0,
      ),
      likes: video['likes'] ?? 0,
      comments: video['comments'] ?? 0,
      views: video['views'] ?? 0,
      duration: video['duration'] ?? 0.0,
      isLiked: false,
      isFavorited: false,
      createdAt: Timestamp.now(),
    );
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMoreVideos || _selectedCategory == null) return;

    setState(() {
      _isLoadingMoreVideos = true;
    });

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _currentVideoPage++;
        _isLoadingMoreVideos = false;
      });
    } catch (e) {
      LoggingService.instance
          .error('Error loading more videos', tag: 'DiscoverView', error: e);
      setState(() {
        _isLoadingMoreVideos = false;
      });
    }
  }

  bool _hasMoreVideos(String categoryId) {
    if (!_cachedVideos.containsKey(categoryId)) return false;
    final allVideos = _cachedVideos[categoryId]!;
    final currentCount = (_currentVideoPage + 1) * _videosPerPage;
    return currentCount < allVideos.length;
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
    for (final notifications in activityState.grouped.values) {
      for (final notification in notifications) {
        if (notification.status == 'pending') {
          totalUnreadCount++;
        }
      }
    }

    return GestureDetector(
      onTap: () {
        LoggingService.instance
            .debug('GestureDetector onTap triggered', tag: 'DiscoverView');
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
        decoration: const BoxDecoration(
          gradient: _backgroundGradient,
        ),
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
              actions: [
                _buildNotificationButton(context, ref),
              ],
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: GestureDetector(
                  onTap: () {
                    // Navigator.of(context).push(
                    //   MaterialPageRoute(
                    //     builder: (_) => const SearchScreen(),
                    //   ),
                    // );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Search feature coming soon!')),
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
                        Icon(Icons.search,
                            color: Colors.white.withValues(alpha: 0.6)),
                        const SizedBox(width: 10),
                        Text(
                          'Search creators, videos, hashtags…',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white.withValues(alpha: 0.4),
                          size: 16,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Trending Creators',
                      action: () => discoverViewModel.loadTrendingCreators(),
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
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Categories Section
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Categories', action: null),

                    // Categories PageView with proper spacing
                    SizedBox(
                      height: 320,
                      child: PageView.builder(
                        onPageChanged: (page) {
                          setState(() {
                            _currentCategoryPage = page;
                          });
                        },
                        itemCount: (discoverState.categories.length / 6).ceil(),
                        itemBuilder: (context, pageIndex) {
                          final startIndex = pageIndex * 6;
                          final endIndex = (startIndex + 6)
                              .clamp(0, discoverState.categories.length);
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
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: pageCategories.length,
                              itemBuilder: (context, index) {
                                final category = pageCategories[index];
                                return _accessibilityService
                                    .createAccessibleButton(
                                  semanticLabel: 'Category ${category.name}',
                                  semanticHint: _selectedCategory == category.id
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

                    // Responsive spacing between categories and dots (16-24dp as specified)
                    SizedBox(
                      height: _getResponsiveSpacing(
                          context, 16, 24), // Normal spacing
                    ),

                    // Page indicator with proper safe area handling
                    Center(
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).padding.bottom +
                              _getResponsiveSpacing(context, 16, 24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            (discoverState.categories.length / 6).ceil(),
                            (index) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index == _currentCategoryPage
                                    ? const Color(0xFF40DCD1)
                                    : const Color(0xFF6B5AE0)
                                        .withValues(alpha: 0.4),
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

            // Content based on category selection
            if (_selectedCategory == null) ...[
              // Default view - show resources
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Resources', action: null),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: discoverState.recommendedContent.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
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
              // Category selected - show 3-column video grid with pagination
              _buildCategoryVideoGridSliver(discoverState, discoverViewModel),
            ],

            // Bottom padding for tab bar
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryVideoGridSliver(
      DiscoverState discoverState, DiscoverNotifier discoverViewModel) {
    if (_selectedCategory == null)
      return const SliverToBoxAdapter(child: SizedBox.shrink());

    // Get the selected category
    final selectedCategory = discoverState.categories.firstWhere(
      (cat) => cat.id == _selectedCategory,
      orElse: () => discoverState.categories.first,
    );

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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

            const SizedBox(height: 16),

            // 3-column video grid with pagination
            _buildVideoGridWithPagination(selectedCategory.id, discoverState),
          ],
        ),
      ),
    );
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
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
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
            const Icon(
              Icons.people,
              size: 32,
              color: Colors.white70,
            ),
            const SizedBox(height: 12),
            Text(
              'No trending creators yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
              ),
            ),
            Text(
              'Popular creators will appear here',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoGridWithPagination(
      String categoryId, DiscoverState discoverState) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getCategoryVideos(categoryId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildEmptyCategoryState(categoryId);
        }

        final categoryVideos = snapshot.data ?? [];

        if (categoryVideos.isEmpty) {
          return _buildEmptyCategoryState(categoryId);
        }

        return Column(
          children: [
            // Video grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio:
                    9 / 16, // 9:16 aspect ratio for portrait videos
              ),
              itemCount: categoryVideos.length,
              itemBuilder: (context, index) {
                return _buildVideoGridItem(categoryVideos[index], categoryId);
              },
            ),

            // Load more button or loading indicator
            if (_hasMoreVideos(categoryId)) ...[
              const SizedBox(height: 16),
              if (_isLoadingMoreVideos)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              else
                Center(
                  child: InstantTextButton(
                    onPressed: _loadMoreVideos,
                    hapticType: HapticFeedbackType.mediumImpact,
                    child: const Text(
                      'Load More Videos',
                      style: TextStyle(
                        color: Color(0xFF6633CC),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getCategoryVideos(
      String categoryId) async {
    // Check if we have cached videos for this category
    if (_cachedVideos.containsKey(categoryId)) {
      final cachedVideos = _cachedVideos[categoryId]!;
      final endIndex = ((_currentVideoPage + 1) * _videosPerPage)
          .clamp(0, cachedVideos.length);
      return cachedVideos.sublist(0, endIndex);
    }

    // Generate and cache all videos for this category
    final allVideos = await _generateCategoryVideos(categoryId);
    _cachedVideos[categoryId] = allVideos;

    // Return first page
    final endIndex = _videosPerPage.clamp(0, allVideos.length);
    return allVideos.sublist(0, endIndex);
  }

  Future<List<Map<String, dynamic>>> _generateCategoryVideos(
      String categoryId) async {
    try {
      // Load real videos from Firestore for this category
      final query = FirebaseFirestore.instance
          .collection('videos')
          .where('status', isEqualTo: 'published')
          .where('privacy', isEqualTo: 'Everyone')
          .where('category', isEqualTo: categoryId)
          .limit(20);

      final snapshot = await query.get();
      final videos = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;

        if (userId == null) continue;

        // Get creator data
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (!userDoc.exists) continue;

        final userData = userDoc.data()!;

        videos.add({
          'id': doc.id,
          'title': data['caption'] ?? data['title'] ?? 'Untitled',
          'creator':
              userData['displayName'] ?? userData['username'] ?? 'Unknown',
          'thumbnail': data['thumbnailUrl'] ?? '',
          'views': '${data['views'] ?? 0}',
          'duration':
              '0:00', // Duration placeholder - actual duration parsing to be implemented
          'color': _getCategoryColor(categoryId),
          'videoUrl': data['videoUrl'] ?? '',
          'creatorId': userId,
        });
      }

      return videos;
    } catch (e) {
      debugPrint('Error loading category videos: $e');
      return [];
    }
  }

  int _getCategoryColor(String categoryId) {
    // Return appropriate color for category
    switch (categoryId) {
      case 'gaming':
        return 0xFFFF6CAB;
      case 'music':
        return 0xFF8E54E9;
      case 'art':
        return 0xFF3D99F7;
      case 'comedy':
        return 0xFF4CAF50;
      case 'dance':
        return 0xFFFF9800;
      case 'sports':
        return 0xFF9C27B0;
      case 'education':
        return 0xFFE91E63;
      case 'lifestyle':
        return 0xFFFF5722;
      case 'food':
        return 0xFF2196F3;
      case 'travel':
        return 0xFF795548;
      case 'fashion':
        return 0xFF607D8B;
      default:
        return 0xFF6633CC; // Default purple color
    }
  }

  Widget _buildVideoGridItem(Map<String, dynamic> video, String categoryId) {
    return GestureDetector(
      onTap: () {
        LoggingService.instance
            .debug('Tapped video: ${video['title']}', tag: 'DiscoverView');
        _showVideoDetails(video);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[800],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video thumbnail or placeholder
            if (video['thumbnailUrl'] != null || video['thumbnailURL'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  video['thumbnailUrl'] ?? video['thumbnailURL'] ?? '',
                  fit: BoxFit.cover,
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
              )
            else
              Container(
                color: Colors.grey[800],
                child: const Center(
                  child: Icon(
                    Icons.video_library_outlined,
                    color: Colors.white54,
                    size: 32,
                  ),
                ),
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
            if (video['duration'] != null)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatDuration(video['duration']),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Format duration in seconds to MM:SS format
  String _formatDuration(dynamic duration) {
    if (duration == null) return '0:00';

    int seconds = 0;
    if (duration is int) {
      seconds = duration;
    } else if (duration is double) {
      seconds = duration.round();
    } else if (duration is String) {
      seconds = int.tryParse(duration) ?? 0;
    }

    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildEmptyCategoryState(String categoryId) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              color: Colors.white.withValues(alpha: 0.5),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'No videos found for this category',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new content!',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Section Header Widget
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? action;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (action != null)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: InstantIconButton(
                onPressed: action,
                hapticType: HapticFeedbackType.lightImpact,
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
