import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/discover_provider.dart';
import '../models/trending_creator.dart';
import 'trending_creator_ring.dart';
import 'category_card.dart';
import 'recommended_content_card.dart';
import 'search_screen.dart';
import 'activity_view.dart';
import '../providers/activity_provider.dart';
import '../services/logging_service.dart';
import '../services/error_handler_service.dart';

class DiscoverView extends ConsumerStatefulWidget {
  const DiscoverView({super.key});

  @override
  ConsumerState<DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends ConsumerState<DiscoverView> {
  String? _selectedCategory;
  int _currentCategoryPage = 0;

  @override
  void initState() {
    super.initState();
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
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
    setState(() {
      _selectedCategory = categoryId;
    });
  }

  void _navigateToCreatorProfile(BuildContext context, TrendingCreator creator) {
    try {
      LoggingService.instance.debug('Navigating to creator profile: ${creator.username}', tag: 'DiscoverView');
      // TODO: Implement navigation to StreamerCardView
      // For now, show a placeholder dialog
      _showCreatorInfoDialog(context, creator);
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error navigating to creator profile', tag: 'DiscoverView', error: e, stackTrace: stackTrace);
      ErrorHandlerService.instance.handleError(e, stackTrace, context: context);
    }
  }

  void _showCreatorQuickActions(BuildContext context, TrendingCreator creator) {
    try {
      LoggingService.instance.debug('Showing quick actions for creator: ${creator.username}', tag: 'DiscoverView');
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_add, color: Colors.white),
                title: const Text('Follow', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _followCreator(creator);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.white),
                title: const Text('Share', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _shareCreator(creator);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error showing quick actions', tag: 'DiscoverView', error: e, stackTrace: stackTrace);
      ErrorHandlerService.instance.handleError(e, stackTrace, context: context);
    }
  }

  void _showCreatorInfoDialog(BuildContext context, TrendingCreator creator) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          creator.username,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Followers: ${_formatFollowerCount(creator.followers)}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${creator.isOnline ? "Online" : "Offline"}',
              style: TextStyle(
                color: creator.isOnline ? Colors.green : Colors.grey,
              ),
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

  void _followCreator(TrendingCreator creator) {
    LoggingService.instance.info('Following creator: ${creator.username}', tag: 'DiscoverView');
    // TODO: Implement actual follow functionality
  }

  void _shareCreator(TrendingCreator creator) {
    LoggingService.instance.info('Sharing creator: ${creator.username}', tag: 'DiscoverView');
    // TODO: Implement actual share functionality
  }

  String _formatFollowerCount(int count) {
    if (count >= 1000000) {
      return "${(count / 1000000).toStringAsFixed(1)}M";
    } else if (count >= 1000) {
      return "${(count / 1000).toStringAsFixed(1)}K";
    } else {
      return count.toString();
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

  int _getTotalNotificationCount(Map<String, List<dynamic>> grouped) {
    int count = 0;
    for (final notifications in grouped.values) {
      count += notifications.length;
    }
    return count;
  }

  Widget _buildNotificationButton(BuildContext context, WidgetRef ref) {
    final activityState = ref.watch(activityProvider);
    final notificationCount = _getTotalNotificationCount(activityState.grouped);
    
    return GestureDetector(
      onTap: () {
        LoggingService.instance.debug('GestureDetector onTap triggered', tag: 'DiscoverView');
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
            if (notificationCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1000),
                  tween: Tween(begin: 0.8, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE91E63).withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          notificationCount > 99 ? '99+' : '$notificationCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF9248D2),
              Color(0xFF7768DF),
              Color(0xFF1670DE),
              Color(0xFF3C8BD6),
              Color(0xFF4897D2),
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'Discover',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
                          'Search creators, categories…',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Content
            _buildRegularContent(discoverState, discoverViewModel),

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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF9248D2),
              Color(0xFF7768DF),
              Color(0xFF1670DE),
              Color(0xFF3C8BD6),
              Color(0xFF4897D2),
            ],
          ),
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


  Widget _buildRegularContent(DiscoverState discoverState, DiscoverNotifier discoverViewModel) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          const SizedBox(height: 24),
          
          // Trending Creators Section
          _buildTrendingCreatorsSection(discoverState, discoverViewModel),
          
          const SizedBox(height: 24),
          
          // Categories Section
          _buildCategoriesSection(discoverState, discoverViewModel),
          
          const SizedBox(height: 24),
          
          // Recommended Content Section
          _buildRecommendedContentSection(discoverState, discoverViewModel),
        ],
      ),
    );
  }

  Widget _buildTrendingCreatorsSection(DiscoverState discoverState, DiscoverNotifier discoverViewModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                  isOnline: creator.isOnline,
                  onTap: () {
                    _navigateToCreatorProfile(context, creator);
                  },
                  onLongPress: () {
                    _showCreatorQuickActions(context, creator);
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

  Widget _buildCategoriesSection(DiscoverState discoverState, DiscoverNotifier discoverViewModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Categories', action: null),
          
          SizedBox(
            height: 420, // Significantly increased height to ensure all text is visible
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
                  padding: const EdgeInsets.only(bottom: 100), // Much larger bottom padding to ensure text visibility
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 24, // Even more spacing between rows
                    ),
                    itemCount: pageCategories.length,
                    itemBuilder: (context, index) {
                      final category = pageCategories[index];
                      return CategoryCard(
                        key: ValueKey(category.id), // Add key for better performance
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
                        ? const Color(0xFF40DCD1) // Teal for active page
                        : const Color(0xFF6B5AE0).withValues(alpha: 0.4), // Purple for inactive
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedContentSection(DiscoverState discoverState, DiscoverNotifier discoverViewModel) {
    return _buildRegularRecommendedContent(discoverState);
  }



  Widget _buildRegularRecommendedContent(DiscoverState discoverState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
