import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../models/forum_post.dart';
import '../../services/forum_service.dart';
import '../../models/forum_category.dart';
import '../../constants/app_colors.dart';
import 'thread_detail_screen.dart';
import 'create_thread_screen.dart';
import 'forum_post_card.dart';

/// Threads list view for the Threads tab
class ThreadsListView extends ConsumerStatefulWidget {
  const ThreadsListView({super.key});

  @override
  ConsumerState<ThreadsListView> createState() => _ThreadsListViewState();
}

class _ThreadsListViewState extends ConsumerState<ThreadsListView> {
  final ForumService _forumService = ForumService();
  List<ForumPost> _threads = [];
  bool _isLoading = true;
  String? _errorMessage;
  ThreadSortBy _sortBy = ThreadSortBy.recent;
  String? _selectedCategory;
  String _searchQuery = '';
  List<ForumCategory> _categories = [];
  Timer? _searchDebounce;
  int _activeLoadRequestId = 0;

  @override
  void initState() {
    super.initState();
    // Lazy load: Only load when widget is actually visible
    // This prevents loading on app startup if Threads tab is not active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadCategories();
        _loadThreads();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _forumService.getCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      debugPrint('❌ Error loading categories: $e');
    }
  }

  Future<void> _loadThreads() async {
    final requestId = ++_activeLoadRequestId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final threads = await _forumService.getPosts(
        categoryId: _selectedCategory,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        sortBy: _sortBy,
        pageSize: _searchQuery.isNotEmpty ? 50 : 10,
      );
      if (!mounted || requestId != _activeLoadRequestId) return;
      setState(() {
        _threads = threads;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _activeLoadRequestId) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    setState(() {
      _searchQuery = value;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadThreads);
  }

  @override
  Widget build(BuildContext context) {
    // Calculate header height: SafeArea top + FeedSelector height (50) + margins (8*2)
    final mediaQuery = MediaQuery.of(context);
    final safeAreaTop = mediaQuery.padding.top;
    final headerHeight = safeAreaTop + 50 + 16; // SafeArea + FeedSelector height + margins

    return Scaffold(
      backgroundColor: AppColors.supportBackground,
      body: Container(
        color: AppColors.supportBackground,
        child: SafeArea(
          top: false, // Don't add SafeArea padding since header is positioned absolutely
          child: Column(
            children: [
              // Top padding to account for persistent header (FeedSelectorWidget)
              SizedBox(height: headerHeight),
              // Search and Filters
              _buildFilters(),
              
              // Threads Grid/List
              Expanded(
                child: _isLoading
                    ? _buildThreadsStatusCard(
                        icon: Icons.forum_outlined,
                        title: 'Loading Threads',
                        message:
                            'Pulling in fresh conversations from across the community.',
                        showProgress: true,
                      )
                    : _errorMessage != null
                        ? _buildThreadsStatusCard(
                            icon: Icons.cloud_off_outlined,
                            title: 'Threads Are Taking A Beat',
                            message: _errorMessage!,
                            showProgress: false,
                            actionLabel: 'Try Again',
                            onAction: _loadThreads,
                          )
                        : _threads.isEmpty
                            ? _buildEmptyState()
                            : RefreshIndicator(
                                onRefresh: _loadThreads,
                                color: AppColors.primary,
                                backgroundColor: AppColors.surface,
                                child: GridView.builder(
                                  padding: const EdgeInsets.all(12),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.75,
                                  ),
                                  itemCount: _threads.length,
                                  itemBuilder: (context, index) {
                                    return ForumPostCard(
                                      post: _threads[index],
                                      onTap: () => _navigateToThread(_threads[index]),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _navigateToCreateThread(),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.supportSurfaceGradient,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.forum_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Threads',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${_threads.length} live',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search bar with gradient border effect
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            child: TextField(
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Search threads...',
                hintStyle: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.supportAccent,
                  size: 22,
                ),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: _handleSearchChanged,
            ),
          ),
          const SizedBox(height: 12),
          // Filter chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Sort filter chips
                ...ThreadSortBy.values.map((sort) {
                  final isSelected = _sortBy == sort;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(
                        _getSortLabel(sort),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.10),
                        width: 1,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _sortBy = sort);
                          _loadThreads();
                        }
                      },
                    ),
                  );
                }),
                const SizedBox(width: 8),
                // Category filter chip
                if (_selectedCategory != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: true,
                      label: Text(
                        _categories
                            .firstWhere(
                              (c) => c.id == _selectedCategory,
                              orElse: () => _categories.first,
                            )
                            .name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selectedColor: AppColors.secondary,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      side: const BorderSide(
                        color: AppColors.secondary,
                        width: 1,
                      ),
                      deleteIcon: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                      onSelected: (selected) {
                        if (!selected) {
                          setState(() => _selectedCategory = null);
                          _loadThreads();
                        }
                      },
                    ),
                  ),
                // Category dropdown button
                if (_categories.isNotEmpty)
                  PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.category,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Category',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    color: AppColors.supportTopSurface,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: null,
                        child: Text(
                          'All Categories',
                          style: TextStyle(
                            color: _selectedCategory == null
                                ? AppColors.primary
                                : AppColors.textPrimary,
                            fontWeight: _selectedCategory == null
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      const PopupMenuDivider(),
                      ..._categories.map((category) {
                        return PopupMenuItem(
                          value: category.id,
                          child: Text(
                            category.name,
                            style: TextStyle(
                              color: _selectedCategory == category.id
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                              fontWeight: _selectedCategory == category.id
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      }),
                    ],
                    onSelected: (value) {
                      setState(() => _selectedCategory = value);
                      _loadThreads();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadsStatusCard({
    required IconData icon,
    required String title,
    required String message,
    required bool showProgress,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: showProgress
                        ? [
                            AppColors.primary.withValues(alpha: 0.95),
                            AppColors.secondary.withValues(alpha: 0.95),
                          ]
                        : [
                            AppColors.error.withValues(alpha: 0.92),
                            AppColors.warning.withValues(alpha: 0.88),
                          ],
                  ),
                ),
                child: showProgress
                    ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(icon, color: Colors.white, size: 34),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(actionLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.tertiary.withValues(alpha: 0.92),
                      AppColors.primary.withValues(alpha: 0.88),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.forum_outlined,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Start The Conversation',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No threads match "${_searchQuery.trim()}". Try a broader search or start your own.'
                    : 'There are no threads here yet. Be the first to post something worth talking about.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: _navigateToCreateThread,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Create Thread'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToThread(ForumPost post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ThreadDetailScreen(postId: post.id),
      ),
    );
  }

  void _navigateToCreateThread() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateThreadScreen(),
      ),
    ).then((_) {
      // Refresh threads after creating
      _loadThreads();
    });
  }

  String _getSortLabel(ThreadSortBy sort) {
    switch (sort) {
      case ThreadSortBy.recent:
        return 'Recent';
      case ThreadSortBy.popular:
        return 'Popular';
      case ThreadSortBy.trending:
        return 'Trending';
      case ThreadSortBy.activeNow:
        return 'Active Now';
      case ThreadSortBy.new_:
        return 'New';
    }
  }
}
