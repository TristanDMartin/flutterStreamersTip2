import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/home_video.dart';
import '../providers/discover_provider.dart';
import '../models/trending_creator.dart';
import '../models/category.dart';
import 'trending_creator_card.dart';
import 'category_card.dart';
import 'recommended_content_card.dart';
import '../models/video_clip.dart';
import 'video_grid.dart';
import 'category_video_viewer.dart';
import 'search_screen.dart';

class DiscoverView extends ConsumerStatefulWidget {
  const DiscoverView({super.key});

  @override
  ConsumerState<DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends ConsumerState<DiscoverView> {
  final String _searchText = '';
  final bool _isSearching = false;
  String? _selectedCategory;
  List<HomeVideo> _selectedCategoryVideos = [];
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
    final discoverViewModel = ref.read(discoverProvider.notifier);
    discoverViewModel.loadTrendingCreators();
  }

  void _onCategorySelected(String? categoryId) {
    setState(() {
      _selectedCategory = categoryId;
    });

    if (categoryId != null) {
      _fetchVideosForCategory(categoryId);
    } else {
      setState(() {
        _selectedCategoryVideos = [];
      });
    }
  }

  Future<void> _fetchVideosForCategory(String categoryId) async {
    try {
      final discoverViewModel = ref.read(discoverProvider.notifier);
      final videos = await discoverViewModel.fetchVideosForCategory(categoryId);
      
      setState(() {
        _selectedCategoryVideos = videos;
      });
    } catch (e) {
      print('Error fetching videos for category $categoryId: $e');
      setState(() {
        _selectedCategoryVideos = [];
      });
    }
  }

  void _onClipSelected(VideoClip clip) {
    // Navigate to CategoryVideoViewer
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CategoryVideoViewer(
          videos: _selectedCategoryVideos.isNotEmpty
              ? _selectedCategoryVideos
              : _selectedCategoryVideos,
          selectedIndex: 0,
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
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  onPressed: () {
                    // TODO: Navigate to ActivityView
                  },
                ),
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
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.white.withOpacity(0.6)),
                        const SizedBox(width: 10),
                        Text(
                          'Search creators, categories…',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
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
            if (_isSearching)
              _buildSearchResults()
            else
              _buildRegularContent(discoverState, discoverViewModel),

            // Bottom padding for tab bar
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    // TODO: Implement search results
    return const SliverToBoxAdapter(
      child: Center(
        child: Text(
          'Search results will appear here',
          style: TextStyle(color: Colors.white),
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
                color: Colors.white.withOpacity(0.85),
                fontSize: 14,
              ),
            ),
            Text(
              'Popular creators will appear here',
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
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
        itemCount: creators.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 16,
              right: index == creators.length - 1 ? 0 : 0,
            ),
            child: TrendingCreatorCard(
              creator: creators[index],
              onTap: () {
                // TODO: Navigate to StreamerCardView
              },
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
            height: 280,
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
                
                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: pageCategories.length,
                  itemBuilder: (context, index) {
                    final category = pageCategories[index];
                    return CategoryCard(
                      category: category,
                      isSelected: _selectedCategory == category.id,
                      onTap: () => _onCategorySelected(
                        _selectedCategory == category.id ? null : category.id,
                      ),
                    );
                  },
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
                        : const Color(0xFF6B5AE0).withOpacity(0.6),
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
    if (_selectedCategory != null) {
      final category = discoverState.categories.firstWhere(
        (c) => c.id == _selectedCategory,
        orElse: () => const Category(id: '', name: '', icon: '', color: Colors.grey),
      );
      
      if (category.id.isNotEmpty) {
        return _buildCategoryContent(category);
      }
    }
    
    return _buildRegularRecommendedContent(discoverState);
  }

  Widget _buildCategoryContent(Category category) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          if (_selectedCategoryVideos.isEmpty)
            _buildEmptyCategoryView()
          else
            VideoGrid(
              videos: _selectedCategoryVideos,
              onVideoSelected: _onClipSelected,
              categoryId: _selectedCategory!,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyCategoryView() {
    return const Center(
      child: Column(
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 48,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No clips in this category yet',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Be the first to share content in this category!',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
