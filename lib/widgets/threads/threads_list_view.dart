import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../models/forum_post.dart';
import '../../services/forum_service.dart';
import '../../utils/user_facing_error.dart';
import '../../models/forum_category.dart';
import '../../core/theme/support_shell_style.dart';
import 'thread_detail_screen.dart';
import 'create_thread_screen.dart';
import 'forum_post_card.dart';

/// Threads list view for the Threads tab
class ThreadsListView extends ConsumerStatefulWidget {
  const ThreadsListView({super.key, this.embeddedInHome = true});

  /// When false, shows a standalone header with back navigation (e.g. from
  /// CommentView onboarding).
  final bool embeddedInHome;

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
        _errorMessage = UserFacingError.message(e);
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
    final double headerHeight =
        widget.embeddedInHome ? safeAreaTop + 50 + 16 : 0;

    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF071120) : shell.scaffold,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1.05),
            radius: 1.18,
            colors: dark
                ? <Color>[
                    scheme.primary.withValues(alpha: 0.10),
                    const Color(0xFF071120),
                  ]
                : <Color>[
                    scheme.primary.withValues(alpha: 0.06),
                    shell.scaffold,
                  ],
          ),
        ),
        child: SafeArea(
          top:
              false, // Don't add SafeArea padding since header is positioned absolutely
          child: Column(
            children: [
              if (widget.embeddedInHome)
                SizedBox(height: headerHeight)
              else
                _buildStandaloneTopBar(shell, scheme, safeAreaTop),
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
                                child: _buildThreadsFeed(),
                              ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => _navigateToCreateThread(),
        backgroundColor: scheme.primary,
        elevation: 2,
        child: Icon(
          Icons.edit_rounded,
          color: scheme.onPrimary,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildStandaloneTopBar(
    StSupportShellStyle shell,
    ColorScheme scheme,
    double safeAreaTop,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, safeAreaTop + 4, 16, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: scheme.onSurface,
            ),
          ),
          Text(
            'Threads',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadsFeed() {
    final List<ForumPost> rest = _threads.length > 1
        ? _threads.skip(1).toList(growable: false)
        : const <ForumPost>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
      children: <Widget>[
        if (_threads.isNotEmpty) ...<Widget>[
          Text(
            'Featured discussion',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.56),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ForumPostCard(
            post: _threads.first,
            featured: true,
            onTap: () => _navigateToThread(_threads.first),
          ),
          const SizedBox(height: 16),
        ],
        if (rest.isNotEmpty) ...<Widget>[
          _ThreadFeedModule(
            title: _sortBy == ThreadSortBy.trending
                ? 'Trending creator topics'
                : 'Latest conversations',
            subtitle: 'Fast discussions from the creator community',
          ),
          const SizedBox(height: 8),
          ...rest.map((ForumPost post) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ForumPostCard(
                post: post,
                onTap: () => _navigateToThread(post),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildFilters(StSupportShellStyle shell, ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Threads',
                      style: TextStyle(
                        color: shell.onChrome,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Discuss content creation, streaming, clips, and growth.',
                      style: TextStyle(
                        color: shell.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() => _sortBy = ThreadSortBy.trending);
                  _loadThreads();
                },
                icon: const Icon(Icons.explore_outlined, size: 17),
                label: const Text('Explore'),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: shell.surfaceCard.withValues(alpha: 0.52),
                border: Border.all(
                  color: shell.surfaceCardBorder.withValues(alpha: 0.62),
                ),
              ),
              child: TextField(
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Search creator discussions',
                  hintStyle: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.42),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: scheme.onSurface.withValues(alpha: 0.44),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                onChanged: _handleSearchChanged,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                ...ThreadSortBy.values.map((ThreadSortBy sort) {
                  final bool selected = _sortBy == sort;
                  return _ThreadTab(
                    label: _getSortLabel(sort),
                    selected: selected,
                    onTap: () {
                      setState(() => _sortBy = sort);
                      _loadThreads();
                    },
                  );
                }),
                if (_categories.isNotEmpty)
                  PopupMenuButton<String?>(
                    tooltip: 'Categories',
                    color: scheme.surface,
                    itemBuilder: (context) => <PopupMenuEntry<String?>>[
                      PopupMenuItem<String?>(
                        value: null,
                        child: Text(
                          'All topics',
                          style: TextStyle(
                            color: _selectedCategory == null
                                ? scheme.primary
                                : scheme.onSurface,
                            fontWeight: _selectedCategory == null
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      const PopupMenuDivider(),
                      ..._categories.map((ForumCategory category) {
                        return PopupMenuItem<String?>(
                          value: category.id,
                          child: Text(
                            category.name,
                            style: TextStyle(
                              color: _selectedCategory == category.id
                                  ? scheme.primary
                                  : scheme.onSurface,
                              fontWeight: _selectedCategory == category.id
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        );
                      }),
                    ],
                    onSelected: (String? value) {
                      setState(() => _selectedCategory = value);
                      _loadThreads();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            _selectedCategory == null
                                ? 'Gaming'
                                : _categories
                                    .firstWhere(
                                      (ForumCategory c) =>
                                          c.id == _selectedCategory,
                                      orElse: () => _categories.first,
                                    )
                                    .name,
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.58),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 17,
                            color: scheme.onSurface.withValues(alpha: 0.48),
                          ),
                        ],
                      ),
                    ),
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
                        ? <Color>[
                            scheme.primary,
                            scheme.secondary,
                          ]
                        : <Color>[
                            scheme.error,
                            scheme.error.withValues(alpha: 0.78),
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
                      borderRadius: BorderRadius.circular(22),
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
                    colors: <Color>[
                      scheme.secondary,
                      scheme.primary,
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
    ).then((_) => _loadThreads());
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

class _ThreadTab extends StatelessWidget {
  const _ThreadTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 18, bottom: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label == 'Popular' ? 'Following' : label,
              style: TextStyle(
                color: selected
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.54),
                fontSize: 14,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selected ? 22 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadFeedModule extends StatelessWidget {
  const _ThreadFeedModule({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.54),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.trending_up_rounded,
            color: scheme.primary.withValues(alpha: 0.78),
            size: 20,
          ),
        ],
      ),
    );
  }
}
