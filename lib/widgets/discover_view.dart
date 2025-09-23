import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/discover_provider.dart';
import '../models/trending_creator.dart';
import 'trending_creator_ring.dart';
import 'category_card.dart';
import 'recommended_content_card.dart';
import 'search_screen.dart';
import 'activity_view.dart';
import 'streamer_card_view.dart';
import '../providers/activity_provider.dart';
import '../services/logging_service.dart';
import '../services/error_handler_service.dart';
import '../services/robust_auth_service.dart';
import 'optimized_image.dart';

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
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
      LoggingService.instance.debug('Loading initial data', tag: 'DiscoverView');
      ref.read(discoverProvider.notifier).loadTrendingCreators();
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error loading initial data', tag: 'DiscoverView', error: e, stackTrace: stackTrace);
      ErrorHandlerService.instance.handleError(e, stackTrace, context: context);
    }
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
        
        LoggingService.instance.debug('Category selected: ${category.name}', tag: 'DiscoverView');
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
      LoggingService.instance.error('Error selecting category', tag: 'DiscoverView', error: e, stackTrace: stackTrace);
      ErrorHandlerService.instance.handleError(e, stackTrace, context: context);
    }
  }


  void _navigateToCreatorProfile(BuildContext context, TrendingCreator creator) {
    try {
      LoggingService.instance.debug('Navigating to creator profile: ${creator.username}', tag: 'DiscoverView');
      
      // Navigate to StreamerCardView
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => StreamerCardView(
            userId: creator.id,
            currentUserId: ref.read(robustAuthServiceProvider).currentUser?.id,
            onDismiss: () => Navigator.of(context).pop(),
          ),
        ),
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error navigating to creator profile', tag: 'DiscoverView', error: e, stackTrace: stackTrace);
      ErrorHandlerService.instance.handleError(e, stackTrace, context: context);
    }
  }



  void _navigateToActivity(BuildContext context) {
    LoggingService.instance.debug('Bell icon tapped - navigating to ActivityView', tag: 'DiscoverView');
    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) {
            LoggingService.instance.debug('ActivityView page builder called', tag: 'DiscoverView');
            return const ActivityView();
          },
        ),
      );
      LoggingService.instance.debug('Navigation push completed', tag: 'DiscoverView');
    } catch (e, stackTrace) {
      LoggingService.instance.error('Navigation error', tag: 'DiscoverView', error: e, stackTrace: stackTrace);
      ErrorHandlerService.instance.handleError(e, stackTrace, context: context);
    }
  }

  void _showVideoDetails(Map<String, dynamic> video) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          video['title'],
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Creator: ${video['creator']}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Views: ${video['views']} • Duration: ${video['duration']}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
      LoggingService.instance.error('Error loading more videos', tag: 'DiscoverView', error: e);
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
    return GestureDetector(
      onTap: () {
        LoggingService.instance.debug('GestureDetector onTap triggered', tag: 'DiscoverView');
        _navigateToActivity(context);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(8),
        child: const Icon(
          Icons.notifications_outlined,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
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
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        Icon(Icons.search, color: Colors.white.withValues(alpha: 0.6)),
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

            // Trending Creators Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Trending Creators',
                      action: () => discoverViewModel.loadTrendingCreators(),
                    ),
                    
                    if (discoverState.isLoadingTrendingCreators)
                      _buildLoadingState()
                    else if (discoverState.trendingCreators.isEmpty)
                      _buildEmptyTrendingCreatorsState()
                    else
                      _buildTrendingCreatorsList(discoverState.trendingCreators),
                  ],
                ),
              ),
            ),

            // Categories Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Categories', action: null),
                    
                    SizedBox(
                      height: 420,
                      child: PageView.builder(
                        onPageChanged: (page) {
                          setState(() {
                            _currentCategoryPage = page;
                          });
                        },
                        itemCount: (discoverState.categories.length / 6).ceil(),
                        itemBuilder: (context, pageIndex) {
                          final startIndex = pageIndex * 6;
                          final endIndex = (startIndex + 6).clamp(0, discoverState.categories.length);
                          final pageCategories = discoverState.categories.sublist(startIndex, endIndex);
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 100),
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 24,
                              ),
                              itemCount: pageCategories.length,
                              itemBuilder: (context, index) {
                                final category = pageCategories[index];
                                return CategoryCard(
                                  key: ValueKey(category.id),
                                  category: category,
                                  isSelected: _selectedCategory == category.id,
                                  onTap: () => _onCategorySelected(
                                    _selectedCategory == category.id ? null : category.id,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Page indicator
                    Center(
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
                                  : const Color(0xFF6B5AE0).withValues(alpha: 0.4),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error building DiscoverView', tag: 'DiscoverView', error: e, stackTrace: stackTrace);
      return _buildErrorState(context, e);
    }
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: _backgroundGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please try again later',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loadInitialData();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildCategoryVideoGridSliver(DiscoverState discoverState, DiscoverNotifier discoverViewModel) {
    if (_selectedCategory == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
    
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
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = null;
                    });
                  },
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

  Widget _buildTrendingCreatorsList(List<TrendingCreator> creators) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: creators.length,
        itemBuilder: (context, index) {
          final creator = creators[index];
          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 12, // 12px spacing as specified
              right: index == creators.length - 1 ? 12 : 0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TrendingCreatorRing(
                  key: ValueKey(creator.id),
                  imageUrl: creator.avatarURL,
                  username: creator.username,
                  userId: creator.id,
                  onTap: () {
                    _navigateToCreatorProfile(context, creator);
                  },
                  onLongPress: () {
                    // TODO: Implement quick actions
                    LoggingService.instance.debug('Long press on creator: ${creator.username}', tag: 'DiscoverView');
                  },
                ),
                
                const SizedBox(height: 8), // 12px gap as specified
                
                // Username below circle
                SizedBox(
                  width: 84, // Match ring width
                  child: Text(
                    creator.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12, // 12-14pt as specified
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  Widget _buildVideoGridWithPagination(String categoryId, DiscoverState discoverState) {
    // Get current page of videos
    final categoryVideos = _getCategoryVideos(categoryId);
    
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
            childAspectRatio: 9 / 16, // 9:16 aspect ratio for portrait videos
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
              child: TextButton(
                onPressed: _loadMoreVideos,
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
  }

  List<Map<String, dynamic>> _getCategoryVideos(String categoryId) {
    // Check if we have cached videos for this category
    if (_cachedVideos.containsKey(categoryId)) {
      final cachedVideos = _cachedVideos[categoryId]!;
      final endIndex = ((_currentVideoPage + 1) * _videosPerPage).clamp(0, cachedVideos.length);
      return cachedVideos.sublist(0, endIndex);
    }
    
    // Generate and cache all videos for this category
    final allVideos = _generateCategoryVideos(categoryId);
    _cachedVideos[categoryId] = allVideos;
    
    // Return first page
    final endIndex = _videosPerPage.clamp(0, allVideos.length);
    return allVideos.sublist(0, endIndex);
  }

  List<Map<String, dynamic>> _generateCategoryVideos(String categoryId) {
    // This would normally fetch from your data source
    // For now, return sample data based on category
    switch (categoryId) {
      case 'gaming':
        return [
          {
            'id': '1',
            'title': 'Epic Gaming Moments',
            'creator': 'GamerPro',
            'thumbnail': 'https://via.placeholder.com/300x533/FF6CAB/FFFFFF?text=Gaming+1',
            'views': '1.2K',
            'duration': '5:30',
            'color': 0xFFFF6CAB,
          },
          {
            'id': '2',
            'title': 'New Game Review',
            'creator': 'GameReviewer',
            'thumbnail': 'https://via.placeholder.com/300x533/8E54E9/FFFFFF?text=Gaming+2',
            'views': '856',
            'duration': '8:15',
            'color': 0xFF8E54E9,
          },
          {
            'id': '3',
            'title': 'Pro Gaming Tips',
            'creator': 'ProGamer',
            'thumbnail': 'https://via.placeholder.com/300x533/3D99F7/FFFFFF?text=Gaming+3',
            'views': '2.1K',
            'duration': '3:45',
            'color': 0xFF3D99F7,
          },
          {
            'id': '4',
            'title': 'Gameplay Highlights',
            'creator': 'GameHighlights',
            'thumbnail': 'https://via.placeholder.com/300x533/FF6CAB/FFFFFF?text=Gaming+4',
            'views': '743',
            'duration': '6:20',
            'color': 0xFFFF6CAB,
          },
          {
            'id': '5',
            'title': 'Speedrun Attempt',
            'creator': 'SpeedRunner',
            'thumbnail': 'https://via.placeholder.com/300x533/8E54E9/FFFFFF?text=Gaming+5',
            'views': '1.5K',
            'duration': '12:30',
            'color': 0xFF8E54E9,
          },
          {
            'id': '6',
            'title': 'Gaming Setup Tour',
            'creator': 'SetupGamer',
            'thumbnail': 'https://via.placeholder.com/300x533/3D99F7/FFFFFF?text=Gaming+6',
            'views': '934',
            'duration': '7:15',
            'color': 0xFF3D99F7,
          },
        ];
      case 'music':
        return [
          {
            'id': '1',
            'title': 'Live Performance',
            'creator': 'MusicArtist',
            'thumbnail': 'https://via.placeholder.com/300x533/FF6CAB/FFFFFF?text=Music+1',
            'views': '2.1K',
            'duration': '12:45',
            'color': 0xFFFF6CAB,
          },
          {
            'id': '2',
            'title': 'Acoustic Cover',
            'creator': 'AcousticSinger',
            'thumbnail': 'https://via.placeholder.com/300x533/8E54E9/FFFFFF?text=Music+2',
            'views': '1.8K',
            'duration': '4:20',
            'color': 0xFF8E54E9,
          },
          {
            'id': '3',
            'title': 'Studio Session',
            'creator': 'StudioMusician',
            'thumbnail': 'https://via.placeholder.com/300x533/3D99F7/FFFFFF?text=Music+3',
            'views': '1.2K',
            'duration': '8:30',
            'color': 0xFF3D99F7,
          },
          {
            'id': '4',
            'title': 'Music Tutorial',
            'creator': 'MusicTeacher',
            'thumbnail': 'https://via.placeholder.com/300x533/FF6CAB/FFFFFF?text=Music+4',
            'views': '956',
            'duration': '15:20',
            'color': 0xFFFF6CAB,
          },
        ];
      case 'art':
        return [
          {
            'id': '1',
            'title': 'Digital Art Tutorial',
            'creator': 'ArtCreator',
            'thumbnail': 'https://via.placeholder.com/300x533/FF6CAB/FFFFFF?text=Art+1',
            'views': '543',
            'duration': '15:20',
            'color': 0xFFFF6CAB,
          },
          {
            'id': '2',
            'title': 'Speed Painting',
            'creator': 'SpeedPainter',
            'thumbnail': 'https://via.placeholder.com/300x533/8E54E9/FFFFFF?text=Art+2',
            'views': '1.1K',
            'duration': '6:45',
            'color': 0xFF8E54E9,
          },
          {
            'id': '3',
            'title': 'Art Process',
            'creator': 'ProcessArtist',
            'thumbnail': 'https://via.placeholder.com/300x533/3D99F7/FFFFFF?text=Art+3',
            'views': '789',
            'duration': '9:30',
            'color': 0xFF3D99F7,
          },
          {
            'id': '4',
            'title': 'Sketch Challenge',
            'creator': 'SketchArtist',
            'thumbnail': 'https://via.placeholder.com/300x533/FF6CAB/FFFFFF?text=Art+4',
            'views': '432',
            'duration': '5:15',
            'color': 0xFFFF6CAB,
          },
          {
            'id': '5',
            'title': 'Art Supplies Review',
            'creator': 'ArtReviewer',
            'thumbnail': 'https://via.placeholder.com/300x533/8E54E9/FFFFFF?text=Art+5',
            'views': '678',
            'duration': '11:20',
            'color': 0xFF8E54E9,
          },
        ];
      default:
        return [];
    }
  }

  Widget _buildVideoGridItem(Map<String, dynamic> video, String categoryId) {
    return GestureDetector(
      onTap: () {
        LoggingService.instance.debug('Tapped video: ${video['title']}', tag: 'DiscoverView');
        // Navigate to video player or show video details
        _showVideoDetails(video);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Color(video['color'] ?? 0xFF6633CC),
        ),
        child: Stack(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: OptimizedImage(
                imageUrl: video['thumbnail'],
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                placeholder: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(video['color'] ?? 0xFF6633CC),
                        Color(video['color'] ?? 0xFF6633CC).withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(video['color'] ?? 0xFF6633CC),
                        Color(video['color'] ?? 0xFF6633CC).withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
            
            // Play icon overlay
            const Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white,
                size: 32,
              ),
            ),
            
            // View count overlay (bottom-left)
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      video['views'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
              child: IconButton(
                onPressed: action,
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.white,
                  size: 16,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
        ],
      ),
    );
  }
}
