import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../models/forum_post.dart';
import '../../services/forum_service.dart';
import '../../models/forum_category.dart';
import '../../constants/app_colors.dart';
import '../../core/theme/support_shell_style.dart';
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // Calculate header height: SafeArea top + FeedSelector height (50) + margins (8*2)
    final mediaQuery = MediaQuery.of(context);
    final safeAreaTop = mediaQuery.padding.top;
    final headerHeight = safeAreaTop + 50 + 16; // SafeArea + FeedSelector height + margins

    return Scaffold(
      backgroundColor: shell.scaffold,
      body: Container(
        color: shell.scaffold,
        child: SafeArea(
          top: false, // Don't add SafeArea padding since header is positioned absolutely
          child: Column(
            children: [
              // Top padding to account for persistent header (FeedSelectorWidget)
              SizedBox(height: headerHeight),
              // Search and Filters
              _buildFilters(shell, scheme),
              
              // Threads Grid/List
              Expanded(
                child: _isLoading
                    ? _buildThreadsStatusCard(
                        shell,
                        scheme,
                        icon: Icons.forum_outlined,
                        title: 'Loading Threads',
                        message:
                            'Pulling in fresh conversations from across the community.',
                        showProgress: true,
                      )
                    : _errorMessage != null
                        ? _buildThreadsStatusCard(
                            shell,
                            scheme,
                            icon: Icons.cloud_off_outlined,
                            title: 'Threads Are Taking A Beat',
                            message: _errorMessage!,
                            showProgress: false,
                            actionLabel: 'Try Again',
                            onAction: _loadThreads,
                          )
                        : _threads.isEmpty
                            ? _buildEmptyState(shell, scheme)
                            : RefreshIndicator(
                                onRefresh: _loadThreads,
                                color: shell.refreshColor,
                                backgroundColor: shell.refreshBackground,
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
            colors: <Color>[
              scheme.primary,
              scheme.secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.38),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _navigateToCreateThread(),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Icon(
            Icons.add,
            color: scheme.onPrimary,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(StSupportShellStyle shell, ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: shell.heroGradient,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: shell.heroBorder,
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: shell.isLight
                ? scheme.shadow.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.18),
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
                  color: shell.surfaceCard,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: shell.surfaceCardBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.forum_outlined,
                      size: 14,
                      color: shell.onChrome,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Threads',
                      style: TextStyle(
                        color: shell.onChrome,
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
                  color: shell.muted,
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
              color: shell.surfaceCard,
              border: Border.all(
                color: shell.surfaceCardBorder,
              ),
            ),
            child: TextField(
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Search threads...',
                hintStyle: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.45),
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: scheme.primary,
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
                              ? scheme.onPrimary
                              : scheme.onSurface.withValues(alpha: 0.65),
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      selectedColor: scheme.primary,
                      backgroundColor: shell.surfaceCard,
                      side: BorderSide(
                        color: isSelected
                            ? scheme.primary
                            : shell.surfaceCardBorder,
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
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selectedColor: scheme.secondary,
                      backgroundColor: shell.surfaceCard,
                      side: BorderSide(
                        color: scheme.secondary,
                        width: 1,
                      ),
                      deleteIcon: Icon(
                        Icons.close,
                        size: 16,
                        color: scheme.onPrimary,
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
                        color: shell.surfaceCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: shell.surfaceCardBorder,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.category,
                            size: 16,
                            color: scheme.onSurface.withValues(alpha: 0.55),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Category',
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.55),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    color: shell.isLight ? scheme.surface : AppColors.supportTopSurface,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: null,
                        child: Text(
                          'All Categories',
                          style: TextStyle(
                            color: _selectedCategory == null
                                ? scheme.primary
                                : scheme.onSurface,
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
                                  ? scheme.primary
                                  : scheme.onSurface,
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

  Widget _buildThreadsStatusCard(
    StSupportShellStyle shell,
    ColorScheme scheme, {
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
            color: shell.surfaceCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: shell.surfaceCardBorder,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: shell.shadowSoft,
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
                    ? Padding(
                        padding: const EdgeInsets.all(18),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            scheme.onPrimary,
                          ),
                        ),
                      )
                    : Icon(icon, color: scheme.onPrimary, size: 34),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  color: scheme.onSurface,
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
                  color: scheme.onSurface.withValues(alpha: 0.62),
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
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
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

  Widget _buildEmptyState(StSupportShellStyle shell, ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: shell.surfaceCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: shell.surfaceCardBorder,
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
                child: Icon(
                  Icons.forum_outlined,
                  color: scheme.onPrimary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Start The Conversation',
                style: TextStyle(
                  color: scheme.onSurface,
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
                  color: scheme.onSurface.withValues(alpha: 0.62),
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
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
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
