import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/support_shell_style.dart';
import '../models/scheduled_post.dart';
import '../routing/app_navigator.dart';
import '../routing/app_routes.dart';
import '../services/firestore_scheduled_post_service.dart';
import '../services/scheduled_post_publisher_service.dart';
import '../services/scheduled_post_service.dart';
import '../services/video_analytics_service.dart';
// import 'edit_post_view.dart'; // Removed - unused
// import 'post_progress_view.dart'; // Removed - unused
// import 'post_analytics_view.dart'; // Removed - unused
// import 'platform_reconnection_view.dart'; // Removed - unused

enum PostSortOption {
  dateDesc,
  dateAsc,
  status,
  platform,
  engagement,
}

enum BulkAction {
  delete,
  cancel,
  publish,
  export,
}

class ManagePostsView extends StatefulWidget {
  const ManagePostsView({
    super.key,
    this.initialTab = ManagePostsInitialTab.scheduled,
    this.launchSource = ManagePostsLaunchSource.direct,
  });

  final ManagePostsInitialTab initialTab;
  final ManagePostsLaunchSource launchSource;

  @override
  State<ManagePostsView> createState() => _ManagePostsViewState();
}

class _ManagePostsViewState extends State<ManagePostsView>
    with TickerProviderStateMixin {
  final FirestoreScheduledPostService _postService =
      FirestoreScheduledPostService();
  final ScheduledPostService _scheduledPostService = ScheduledPostService();
  final VideoAnalyticsService _videoAnalyticsService = VideoAnalyticsService();
  List<ScheduledPost> _posts = [];
  bool _isLoading = true;
  PostStatus? _filterStatus;
  PlatformKey? _filterPlatform;
  String _searchQuery = '';
  late TabController _tabController;

  // Bulk operations
  Set<String> _selectedPosts = {};
  bool _isSelectionMode = false;

  // Sorting
  PostSortOption _sortOption = PostSortOption.dateDesc;

  // Real-time updates
  bool _isRealTimeEnabled = true;
  int _refreshInterval = 30; // seconds
  int _retryCount = 0;
  static const int _maxRetries = 3;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _tabIndexFor(widget.initialTab),
    );
    _loadPosts();
    _startRealTimeUpdates();
    _checkAndPublishOverduePosts();
  }

  int _tabIndexFor(ManagePostsInitialTab tab) {
    switch (tab) {
      case ManagePostsInitialTab.scheduled:
        return 0;
      case ManagePostsInitialTab.publishing:
        return 1;
      case ManagePostsInitialTab.published:
        return 2;
    }
  }

  /// Check for posts that are past their scheduled time and trigger publishing
  Future<void> _checkAndPublishOverduePosts() async {
    try {
      final publisherService = ScheduledPostPublisherService();
      await publisherService.checkNow();
      // Reload posts to reflect status changes
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _loadPosts();
      });
    } catch (e) {
      // Silently fail - the periodic publisher will handle it
    }
  }

  void _startRealTimeUpdates() {
    _refreshTimer?.cancel();
    if (_isRealTimeEnabled) {
      _refreshTimer = Timer(Duration(seconds: _refreshInterval), () {
        if (mounted) {
          _loadPosts();
          _startRealTimeUpdates();
        }
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final posts = await _postService.getScheduledPosts(
        status: _filterStatus,
        platform: _filterPlatform,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );

      final sortedPosts = _sortPosts(posts);

      if (!mounted) return;
      setState(() {
        _posts = sortedPosts;
        _isLoading = false;
        _retryCount = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (_retryCount < _maxRetries) {
        _retryCount++;
        _showErrorSnackBar(
            'Failed to load posts. Retrying... ($_retryCount/$_maxRetries)');
        Timer(Duration(seconds: _retryCount * 2), () {
          if (mounted) _loadPosts();
        });
      } else {
        _showErrorSnackBar(
            'Failed to load posts after $_maxRetries attempts: $e');
      }
    }
  }

  List<ScheduledPost> _sortPosts(List<ScheduledPost> posts) {
    switch (_sortOption) {
      case PostSortOption.dateDesc:
        posts.sort((a, b) => (b.schedule?.scheduledAtUtc ?? DateTime(1970))
            .compareTo(a.schedule?.scheduledAtUtc ?? DateTime(1970)));
        break;
      case PostSortOption.dateAsc:
        posts.sort((a, b) => (a.schedule?.scheduledAtUtc ?? DateTime(1970))
            .compareTo(b.schedule?.scheduledAtUtc ?? DateTime(1970)));
        break;
      case PostSortOption.status:
        posts.sort((a, b) => a.status.index.compareTo(b.status.index));
        break;
      case PostSortOption.platform:
        posts.sort((a, b) {
          final aKey = a.platforms.isNotEmpty ? a.platforms.first.key : '';
          final bKey = b.platforms.isNotEmpty ? b.platforms.first.key : '';
          return aKey.compareTo(bKey);
        });
        break;
      case PostSortOption.engagement:
        posts.sort((a, b) =>
            b.analyticsHints['engagement']
                ?.compareTo(a.analyticsHints['engagement'] ?? 0) ??
            0);
        break;
    }
    return posts;
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: shell.pageGradient,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: shell.onChrome,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: shell.onChrome),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Manage Posts',
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: <Widget>[
            if (_isSelectionMode) ...<Widget>[
              IconButton(
                icon: Icon(Icons.close_rounded, color: shell.onChrome),
                onPressed: _exitSelectionMode,
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                onPressed:
                    _selectedPosts.isNotEmpty ? _showBulkActionDialog : null,
              ),
            ] else ...<Widget>[
              IconButton(
                icon: Icon(Icons.search_rounded, color: shell.onChrome),
                onPressed: _showSearchDialog,
              ),
              IconButton(
                icon: Icon(Icons.sort_rounded, color: shell.onChrome),
                onPressed: _showSortDialog,
              ),
              IconButton(
                icon: Icon(Icons.filter_list_rounded, color: shell.onChrome),
                onPressed: _showFilterDialog,
              ),
              IconButton(
                icon: Icon(Icons.more_vert_rounded, color: shell.onChrome),
                onPressed: _showMoreOptionsDialog,
              ),
            ],
          ],
          bottom: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: shell.chipSelectedBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: shell.chipSelectedBorder),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: cs.outlineVariant.withValues(alpha: 0.35),
            labelColor: shell.chipSelectedFg,
            unselectedLabelColor: shell.muted,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            tabs: const <Widget>[
              Tab(text: 'Scheduled'),
              Tab(text: 'Publishing'),
              Tab(text: 'Published'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: <Widget>[
            _buildPostsList(context, PostStatus.scheduled),
            _buildPostsList(context, PostStatus.publishing),
            _buildPostsList(context, PostStatus.published),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsList(BuildContext context, PostStatus status) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final filteredPosts =
        _posts.where((post) => post.status == status).toList();

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: cs.primary),
      );
    }

    if (filteredPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              _getEmptyStateIcon(status),
              size: 64,
              color: shell.iconDim,
            ),
            const SizedBox(height: 16),
            Text(
              _getEmptyStateMessage(status),
              style: TextStyle(
                color: shell.muted,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      color: cs.primary,
      backgroundColor: shell.refreshBackground,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.of(context).padding.top + 132,
          16,
          24,
        ),
        itemCount: filteredPosts.length,
        itemBuilder: (BuildContext context, int index) {
          final ScheduledPost post = filteredPosts[index];
          return _buildPostCard(context, post);
        },
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, ScheduledPost post) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final bool isSelected = _selectedPosts.contains(post.id);

    return GestureDetector(
      onTap: _isSelectionMode ? () => _togglePostSelection(post.id) : null,
      onLongPress: () => _enterSelectionMode(post.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? shell.chipSelectedBg.withValues(alpha: 0.55)
              : shell.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? shell.chipSelectedBorder : shell.surfaceCardBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: shell.shadowSoft,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildPostHeader(context, post, isSelected),
            _buildPostContent(context, post),
            _buildPostActions(context, post),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader(
    BuildContext context,
    ScheduledPost post,
    bool isSelected,
  ) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final isOverdue = post.status == PostStatus.scheduled &&
        post.schedule?.scheduledAtUtc != null &&
        post.schedule!.scheduledAtUtc.isBefore(DateTime.now());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          if (_isSelectionMode) ...<Widget>[
            Checkbox(
              value: isSelected,
              onChanged: (bool? value) => _togglePostSelection(post.id),
              activeColor: cs.primary,
            ),
            const SizedBox(width: 8),
          ],
          _buildStatusChip(context, post.status, isOverdue: isOverdue),
          const Spacer(),
          if (isOverdue) ...<Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.tertiary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: cs.tertiary, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.schedule_rounded, color: cs.tertiary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Overdue',
                    style: TextStyle(
                      color: cs.tertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              _formatScheduleTime(
                  post.schedule?.scheduledAtUtc ?? DateTime.now()),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: isOverdue ? cs.tertiary : shell.muted,
                fontSize: 12,
                fontWeight: isOverdue ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent(BuildContext context, ScheduledPost post) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (post.media.isNotEmpty) ...<Widget>[
            _buildMediaPreview(context, post.media.first),
            const SizedBox(height: 12),
          ],
          Text(
            post.caption,
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (post.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: post.tags
                  .take(3)
                  .map(
                    (String tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#$tag',
                        style: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          _buildPlatformStatuses(context, post),
        ],
      ),
    );
  }

  Widget _buildMediaPreview(BuildContext context, PostMedia media) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: shell.skeletonFill,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.network(
              media.src,
              fit: BoxFit.cover,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                return Container(
                  color: shell.skeletonFill,
                  child: Icon(
                    Icons.image_outlined,
                    color: shell.iconDim,
                    size: 32,
                  ),
                );
              },
            ),
            if (media.type == MediaType.video)
              Container(
                color: cs.shadow.withValues(alpha: 0.35),
                child: Center(
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    color: shell.onChrome,
                    size: 48,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformStatuses(BuildContext context, ScheduledPost post) {
    if (post.platforms.isEmpty) {
      return _buildActionChip(
          context, 'StreamersTip only', Icons.verified_rounded);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: post.platforms
              .map(
                (PlatformConfig platform) =>
                    _buildPlatformStatus(context, platform),
              )
              .toList(),
        ),
        if (_failedPlatforms(post).isNotEmpty ||
            _reauthPlatforms(post).isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildPlatformIssuesSummary(post),
        ],
      ],
    );
  }

  Widget _buildPlatformStatus(
    BuildContext context,
    PlatformConfig platform,
  ) {
    final PlatformStatus status = platform.status ?? PlatformStatus.pending;
    final Color color =
        _getPlatformStatusColor(Theme.of(context).colorScheme, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getPlatformIcon(platform.key),
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            _getPlatformStatusText(status),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostActions(BuildContext context, ScheduledPost post) {
    final failedPlatforms = _failedPlatforms(post);
    final reauthPlatforms = _reauthPlatforms(post);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          if (post.status == PostStatus.scheduled) ...<Widget>[
            _buildActionButton(
              context,
              'Publish Now',
              Icons.publish_rounded,
              () => _publishNow(post),
            ),
            _buildActionButton(
              context,
              'Cancel',
              Icons.cancel_rounded,
              () => _cancelPost(post),
            ),
            _buildActionButton(
              context,
              'Progress',
              Icons.insights_rounded,
              () => _showPostProgress(post),
            ),
          ] else if (post.status == PostStatus.publishing) ...<Widget>[
            _buildActionChip(
                context, 'Publishing', Icons.schedule_send_rounded),
            _buildActionButton(
              context,
              'Progress',
              Icons.insights_rounded,
              () => _showPostProgress(post),
            ),
          ] else if (post.status == PostStatus.published) ...<Widget>[
            _buildActionButton(
              context,
              'View Post',
              Icons.open_in_new_rounded,
              () => _viewPost(post),
            ),
            _buildActionButton(
              context,
              'Analytics',
              Icons.bar_chart_rounded,
              () => _showPostAnalytics(post),
            ),
            if (failedPlatforms.isNotEmpty) ...<Widget>[
              _buildActionButton(
                context,
                'Retry Failed',
                Icons.refresh_rounded,
                () => _retryPost(post, platformKeys: failedPlatforms),
              ),
            ],
          ] else if (post.status == PostStatus.failed) ...<Widget>[
            _buildActionButton(
              context,
              failedPlatforms.isNotEmpty ? 'Retry Failed' : 'Retry',
              Icons.refresh_rounded,
              () => _retryPost(
                post,
                platformKeys:
                    failedPlatforms.isNotEmpty ? failedPlatforms : null,
              ),
            ),
            _buildActionButton(
              context,
              'Progress',
              Icons.insights_rounded,
              () => _showPostProgress(post),
            ),
            if (reauthPlatforms.isNotEmpty) ...<Widget>[
              _buildActionButton(
                context,
                'Reconnect',
                Icons.link_off_rounded,
                () => _openReconnectPlatforms(post),
              ),
            ] else ...<Widget>[
              _buildActionButton(
                context,
                'Analytics',
                Icons.bar_chart_rounded,
                () => _showPostAnalytics(post),
              ),
            ],
          ] else if (post.status == PostStatus.canceled ||
              post.status == PostStatus.draft) ...<Widget>[
            _buildActionButton(
              context,
              'Progress',
              Icons.insights_rounded,
              () => _showPostProgress(post),
            ),
          ],
          if (post.platforms.isNotEmpty) ...<Widget>[
            _buildActionButton(
              context,
              'Details',
              Icons.toc_rounded,
              () => _showPlatformDetails(post),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionChip(
    BuildContext context,
    String label,
    IconData icon,
  ) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: shell.chipUnselectedBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: shell.chipUnselectedBorder,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: shell.iconDim),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: shell.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: shell.panelSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: shell.panelBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: shell.onChrome.withValues(alpha: 0.85)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: shell.onChrome.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(
    BuildContext context,
    PostStatus status, {
    bool isOverdue = false,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color color = isOverdue ? cs.tertiary : _getStatusColor(cs, status);
    final text = _getStatusText(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getStatusColor(ColorScheme cs, PostStatus status) {
    switch (status) {
      case PostStatus.scheduled:
        return cs.primary;
      case PostStatus.publishing:
        return cs.tertiary;
      case PostStatus.published:
        return cs.secondary;
      case PostStatus.failed:
        return cs.error;
      case PostStatus.canceled:
        return cs.outline;
      case PostStatus.draft:
        return cs.onSurfaceVariant;
    }
  }

  String _getStatusText(PostStatus status) {
    switch (status) {
      case PostStatus.scheduled:
        return 'Scheduled';
      case PostStatus.publishing:
        return 'Publishing';
      case PostStatus.published:
        return 'Published';
      case PostStatus.failed:
        return 'Failed';
      case PostStatus.canceled:
        return 'Canceled';
      case PostStatus.draft:
        return 'Draft';
    }
  }

  Color _getPlatformStatusColor(ColorScheme cs, PlatformStatus status) {
    switch (status) {
      case PlatformStatus.pending:
        return cs.primary;
      case PlatformStatus.publishing:
        return cs.tertiary;
      case PlatformStatus.published:
        return cs.secondary;
      case PlatformStatus.failed:
        return cs.error;
      case PlatformStatus.needsReauth:
        return cs.tertiary;
      case PlatformStatus.canceled:
        return cs.outline;
    }
  }

  String _getPlatformStatusText(PlatformStatus status) {
    switch (status) {
      case PlatformStatus.pending:
        return 'Pending';
      case PlatformStatus.publishing:
        return 'Publishing';
      case PlatformStatus.published:
        return 'Published';
      case PlatformStatus.failed:
        return 'Failed';
      case PlatformStatus.needsReauth:
        return 'Reauth';
      case PlatformStatus.canceled:
        return 'Canceled';
    }
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform) {
      case 'youtube':
        return Icons.play_circle_filled;
      case 'tiktok':
        return Icons.music_note;
      case 'instagram':
        return Icons.camera_alt;
      case 'x':
        return Icons.alternate_email;
      case 'facebook':
        return Icons.facebook;
      case 'linkedin':
        return Icons.business;
      default:
        return Icons.public;
    }
  }

  IconData _getEmptyStateIcon(PostStatus status) {
    switch (status) {
      case PostStatus.scheduled:
        return Icons.schedule;
      case PostStatus.publishing:
        return Icons.hourglass_empty;
      case PostStatus.published:
        return Icons.check_circle_outline;
      default:
        return Icons.inbox;
    }
  }

  String _getEmptyStateMessage(PostStatus status) {
    switch (status) {
      case PostStatus.scheduled:
        return 'No scheduled posts';
      case PostStatus.publishing:
        return 'No posts currently publishing';
      case PostStatus.published:
        return 'No published posts';
      default:
        return 'No posts found';
    }
  }

  String _formatScheduleTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Now';
    }
  }

  void _showSearchDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ColorScheme cs = Theme.of(dialogContext).colorScheme;
        final TextTheme tt = Theme.of(dialogContext).textTheme;
        return AlertDialog(
          backgroundColor: cs.surfaceContainerHigh,
          title: Text('Search Posts', style: tt.titleLarge),
          content: TextField(
            style: tt.bodyLarge,
            decoration: InputDecoration(
              hintText: 'Search by caption or tags...',
              hintStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: cs.surfaceContainerLow,
            ),
            onChanged: (String value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                });
                _loadPosts();
                Navigator.pop(dialogContext);
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () {
                _loadPosts();
                Navigator.pop(dialogContext);
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        final TextTheme tt = Theme.of(sheetContext).textTheme;
        final ColorScheme cs = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Filter Posts',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Text(
                  'Status',
                  style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: PostStatus.values
                      .map(
                        (PostStatus status) => FilterChip(
                          label: Text(_getStatusText(status)),
                          selected: _filterStatus == status,
                          onSelected: (bool selected) {
                            setState(() {
                              _filterStatus = selected ? status : null;
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Platform',
                  style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: PlatformKey.values
                      .map(
                        (PlatformKey platform) => FilterChip(
                          label: Text(_getPlatformName(platform)),
                          selected: _filterPlatform == platform,
                          onSelected: (bool selected) {
                            setState(() {
                              _filterPlatform = selected ? platform : null;
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    _loadPosts();
                    Navigator.pop(sheetContext);
                  },
                  child: const Text('Apply Filters'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getPlatformName(PlatformKey platform) {
    switch (platform) {
      case PlatformKey.youtube:
        return 'YouTube';
      case PlatformKey.tiktok:
        return 'TikTok';
      case PlatformKey.instagram:
        return 'Instagram';
      case PlatformKey.x:
        return 'X (Twitter)';
      case PlatformKey.facebook:
        return 'Facebook';
      case PlatformKey.linkedin:
        return 'LinkedIn';
    }
  }

  void _publishNow(ScheduledPost post) async {
    try {
      await _postService.publishNow(post.id);
      _showSuccessSnackBar('Post published successfully');
      _loadPosts();
    } catch (e) {
      _showErrorSnackBar('Failed to publish post: $e');
    }
  }

  void _cancelPost(ScheduledPost post) async {
    final confirmed = await _showConfirmDialog(
      'Cancel Post',
      'Are you sure you want to cancel this scheduled post?',
    );

    if (confirmed) {
      try {
        await _postService.cancelPost(post.id);
        _showSuccessSnackBar('Post canceled');
        _loadPosts();
      } catch (e) {
        _showErrorSnackBar('Failed to cancel post: $e');
      }
    }
  }

  void _viewPost(ScheduledPost post) async {
    HapticFeedback.lightImpact();

    // Find published platform URLs
    final publishedPlatforms = post.platforms
        .where((p) =>
            p.status == PlatformStatus.published && p.payload?['url'] != null)
        .toList();

    if (publishedPlatforms.isEmpty) {
      _showInfoSnackBar('No published URLs available');
      return;
    }

    if (publishedPlatforms.length == 1) {
      // Single platform - open directly
      final url = publishedPlatforms.first.payload!['url']!;
      await _launchUrl(url);
    } else {
      // Multiple platforms - show selection dialog
      _showPlatformSelectionDialog(publishedPlatforms);
    }
  }

  void _retryPost(
    ScheduledPost post, {
    List<String>? platformKeys,
  }) async {
    try {
      if (post.status == PostStatus.published) {
        await _postService.retryExternalPlatforms(
          post.id,
          platformKeys: platformKeys,
        );
      } else {
        await _postService.retryPost(post.id, platformKeys: platformKeys);
      }
      if (platformKeys != null && platformKeys.isNotEmpty) {
        _showSuccessSnackBar(
          'Retry queued for ${platformKeys.map(_getPlatformNameFromString).join(', ')}',
        );
      } else {
        _showSuccessSnackBar('Post retry initiated');
      }
      _loadPosts();
    } catch (e) {
      _showErrorSnackBar('Failed to retry post: $e');
    }
  }

  List<String> _failedPlatforms(ScheduledPost post) {
    return post.platforms
        .where((platform) => platform.status == PlatformStatus.failed)
        .map((platform) => platform.key)
        .toList();
  }

  List<String> _reauthPlatforms(ScheduledPost post) {
    return post.platforms
        .where((platform) => platform.status == PlatformStatus.needsReauth)
        .map((platform) => platform.key)
        .toList();
  }

  Widget _buildPlatformIssuesSummary(ScheduledPost post) {
    final failed = _failedPlatforms(post);
    final reauth = _reauthPlatforms(post);
    final parts = <String>[];
    if (failed.isNotEmpty) {
      parts.add(
        'Failed: ${failed.map(_getPlatformNameFromString).join(', ')}',
      );
    }
    if (reauth.isNotEmpty) {
      parts.add(
        'Reconnect: ${reauth.map(_getPlatformNameFromString).join(', ')}',
      );
    }

    return Text(
      parts.join('  |  '),
      style: TextStyle(
        color: StSupportShellStyle.of(context).muted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Future<void> _openReconnectPlatforms(ScheduledPost post) async {
    final reauth = _reauthPlatforms(post);
    if (reauth.isEmpty) {
      _showInfoSnackBar('No reconnect actions needed for this post.');
      return;
    }

    final reconnectUpdated = await AppNavigator.openLinkedPlatforms<bool>(
      context,
      initialPlatforms: reauth,
    );
    if (mounted) {
      if (reconnectUpdated == true) {
        _showSuccessSnackBar(
          'Platform connections updated. Retry failed destinations when you are ready.',
        );
      }
      _loadPosts();
    }
  }

  void _showPostProgress(ScheduledPost post) {
    final scheduledAt = post.schedule?.scheduledAtUtc;
    final successfulCount = post.platforms
        .where((platform) => platform.status == PlatformStatus.published)
        .length;
    final inFlightCount = post.platforms
        .where((platform) => platform.status == PlatformStatus.publishing)
        .length;
    final failedCount = _failedPlatforms(post).length;
    final reauthCount = _reauthPlatforms(post).length;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        final TextTheme tt = Theme.of(sheetContext).textTheme;
        final ColorScheme cs = Theme.of(sheetContext).colorScheme;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Publish Progress',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  post.caption.isEmpty ? 'Untitled post' : post.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                _buildProgressMetric(
                  sheetContext,
                  'Current status',
                  _getStatusText(post.status),
                ),
                if (scheduledAt != null)
                  _buildProgressMetric(
                    sheetContext,
                    'Scheduled for',
                    '${MaterialLocalizations.of(sheetContext).formatFullDate(scheduledAt)} '
                        '${MaterialLocalizations.of(sheetContext).formatTimeOfDay(TimeOfDay.fromDateTime(scheduledAt))}',
                  ),
                _buildProgressMetric(
                  sheetContext,
                  'Destinations completed',
                  '$successfulCount of ${post.platforms.length}',
                ),
                if (inFlightCount > 0)
                  _buildProgressMetric(
                    sheetContext,
                    'Currently publishing',
                    '$inFlightCount',
                  ),
                if (failedCount > 0)
                  _buildProgressMetric(
                    sheetContext,
                    'Needs retry',
                    _failedPlatforms(post)
                        .map(_getPlatformNameFromString)
                        .join(', '),
                  ),
                if (reauthCount > 0)
                  _buildProgressMetric(
                    sheetContext,
                    'Needs reconnect',
                    _reauthPlatforms(post)
                        .map(_getPlatformNameFromString)
                        .join(', '),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Publishing Timeline',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadPublishingHistory(post),
                  builder: (BuildContext _,
                      AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(color: cs.primary),
                      );
                    }

                    final List<Map<String, dynamic>> history =
                        snapshot.data ?? const <Map<String, dynamic>>[];
                    if (history.isEmpty) {
                      final StSupportShellStyle shell =
                          StSupportShellStyle.of(sheetContext);
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: shell.surfaceCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: shell.surfaceCardBorder),
                        ),
                        child: Text(
                          snapshot.hasError
                              ? 'Detailed publishing history is not available from the backend for this post yet.'
                              : 'No per-attempt publishing history is available for this post yet.',
                          style: tt.bodySmall?.copyWith(color: shell.muted),
                        ),
                      );
                    }

                    return Column(
                      children: history
                          .map(
                            (Map<String, dynamic> entry) =>
                                _buildHistoryEntry(sheetContext, entry),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryEntry(BuildContext context, Map<String, dynamic> entry) {
    final status = entry['status']?.toString() ?? 'update';
    final platform = entry['platform']?.toString();
    final message = entry['message']?.toString() ??
        entry['detail']?.toString() ??
        'Status updated';
    final rawTimestamp = entry['timestamp'] ?? entry['createdAt'];
    DateTime? timestamp;
    if (rawTimestamp is String) {
      timestamp = DateTime.tryParse(rawTimestamp);
    } else if (rawTimestamp is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    }

    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: shell.surfaceCardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: _historyStatusColor(cs, status),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  platform == null || platform.isEmpty
                      ? _historyStatusLabel(status)
                      : '${_getPlatformNameFromString(platform)} • ${_historyStatusLabel(status)}',
                  style: tt.titleSmall?.copyWith(
                    color: shell.onChrome,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: tt.bodySmall?.copyWith(color: shell.muted),
                ),
                if (timestamp != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    '${MaterialLocalizations.of(context).formatShortDate(timestamp)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(timestamp))}',
                    style: tt.labelSmall?.copyWith(color: shell.iconDim),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _historyStatusColor(ColorScheme cs, String rawStatus) {
    switch (rawStatus.toLowerCase()) {
      case 'published':
      case 'success':
      case 'completed':
        return cs.primary;
      case 'publishing':
      case 'processing':
      case 'queued':
        return cs.tertiary;
      case 'failed':
      case 'error':
        return cs.error;
      case 'needsreauth':
      case 'needs_reauth':
        return cs.secondary;
      default:
        return cs.outline;
    }
  }

  String _historyStatusLabel(String rawStatus) {
    switch (rawStatus.toLowerCase()) {
      case 'needsreauth':
      case 'needs_reauth':
        return 'Needs Reconnect';
      default:
        if (rawStatus.isEmpty) {
          return 'Update';
        }
        return '${rawStatus[0].toUpperCase()}${rawStatus.substring(1)}';
    }
  }

  Future<List<Map<String, dynamic>>> _loadPublishingHistory(
    ScheduledPost post,
  ) async {
    final localHistory =
        (post.analyticsHints['publishingHistory'] as List<dynamic>? ?? const [])
            .map((entry) => Map<String, dynamic>.from(entry as Map))
            .toList();
    try {
      final remoteHistory =
          await _scheduledPostService.getPublishingHistory(post.id);
      if (remoteHistory.isNotEmpty) {
        return remoteHistory;
      }
      return localHistory;
    } catch (_) {
      return localHistory;
    }
  }

  void _showPostAnalytics(ScheduledPost post) {
    final List<String> successfulPlatforms = post.platforms
        .where((PlatformConfig p) => p.status == PlatformStatus.published)
        .map((PlatformConfig p) => _getPlatformNameFromString(p.key))
        .toList();
    final String? videoId = _resolveVideoId(post);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        final TextTheme tt = Theme.of(sheetContext).textTheme;
        final ColorScheme cs = Theme.of(sheetContext).colorScheme;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Post Analytics',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              FutureBuilder<VideoAnalytics?>(
                future: _loadVideoAnalytics(post),
                builder: (
                  BuildContext _,
                  AsyncSnapshot<VideoAnalytics?> snapshot,
                ) {
                  final VideoAnalytics? analytics = snapshot.data;
                  final Map<String, dynamic> fallback = post.analyticsHints;
                  final Object views = analytics?.views ??
                      fallback['views'] ??
                      fallback['impressions'] ??
                      0;
                  final Object likes =
                      analytics?.likes ?? fallback['likes'] ?? 0;
                  final Object comments =
                      analytics?.comments ?? fallback['comments'] ?? 0;
                  final Object shares =
                      analytics?.shares ?? fallback['shares'] ?? 0;
                  final Object engagement =
                      analytics?.engagementRate ?? fallback['engagement'] ?? 0;
                  final Object averageWatchTime = analytics?.averageWatchTime ??
                      fallback['averageWatchTime'] ??
                      0;
                  final Object completionRate = analytics?.completionRate ??
                      fallback['completionRate'] ??
                      0;
                  final Object uniqueViewers = analytics?.uniqueViewers ??
                      fallback['uniqueViewers'] ??
                      0;
                  final Object audienceReach = analytics?.audienceReach ??
                      fallback['audienceReach'] ??
                      0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          videoId != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(color: cs.primary),
                        ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: <Widget>[
                          _buildAnalyticsCard(sheetContext, 'Views', '$views'),
                          _buildAnalyticsCard(sheetContext, 'Likes', '$likes'),
                          _buildAnalyticsCard(
                            sheetContext,
                            'Comments',
                            '$comments',
                          ),
                          _buildAnalyticsCard(
                              sheetContext, 'Shares', '$shares'),
                          _buildAnalyticsCard(
                            sheetContext,
                            'Engagement',
                            _formatRate(engagement),
                          ),
                          _buildAnalyticsCard(
                            sheetContext,
                            'Avg Watch',
                            _formatSeconds(averageWatchTime),
                          ),
                          _buildAnalyticsCard(
                            sheetContext,
                            'Completion',
                            _formatRate(completionRate),
                          ),
                          _buildAnalyticsCard(
                            sheetContext,
                            'Unique Viewers',
                            '$uniqueViewers',
                          ),
                          _buildAnalyticsCard(
                            sheetContext,
                            'Reach',
                            '$audienceReach',
                          ),
                        ],
                      ),
                      if (snapshot.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Showing saved analytics hints because live '
                            'analytics could not be loaded.',
                            style: tt.bodySmall?.copyWith(color: cs.tertiary),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                successfulPlatforms.isEmpty
                    ? 'No external destinations have completed yet.'
                    : 'Published destinations: ${successfulPlatforms.join(', ')}',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPlatformDetails(ScheduledPost post) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        final TextTheme tt = Theme.of(sheetContext).textTheme;
        final ColorScheme cs = Theme.of(sheetContext).colorScheme;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Platform Status',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              ...post.platforms.map((PlatformConfig platform) {
                final PlatformStatus status =
                    platform.status ?? PlatformStatus.pending;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _getPlatformIconFromString(platform.key),
                    color:
                        _getPlatformColorFromString(sheetContext, platform.key),
                  ),
                  title: Text(
                    _getPlatformNameFromString(platform.key),
                    style: tt.titleSmall?.copyWith(color: cs.onSurface),
                  ),
                  subtitle: Text(
                    platform.error?.isNotEmpty == true
                        ? '${_getPlatformStatusText(status)}: ${platform.error}'
                        : _getPlatformStatusText(status),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  trailing: _buildInlinePlatformAction(
                    sheetContext,
                    post,
                    platform,
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget? _buildInlinePlatformAction(
    BuildContext sheetContext,
    ScheduledPost post,
    PlatformConfig platform,
  ) {
    final PlatformStatus status = platform.status ?? PlatformStatus.pending;
    if (status == PlatformStatus.failed) {
      return TextButton(
        onPressed: () {
          Navigator.pop(sheetContext);
          _retryPost(post, platformKeys: <String>[platform.key]);
        },
        child: const Text('Retry'),
      );
    }
    if (status == PlatformStatus.needsReauth) {
      return TextButton(
        onPressed: () {
          Navigator.pop(sheetContext);
          _openReconnectPlatforms(post);
        },
        child: const Text('Reconnect'),
      );
    }
    return null;
  }

  Widget _buildProgressMetric(
    BuildContext context,
    String label,
    String value,
  ) {
    final TextTheme tt = Theme.of(context).textTheme;
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: tt.bodySmall?.copyWith(color: shell.iconDim),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: tt.bodyMedium?.copyWith(
                color: shell.onChrome,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(
    BuildContext context,
    String label,
    String value,
  ) {
    final TextTheme tt = Theme.of(context).textTheme;
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      width: 104,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: shell.surfaceCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: tt.titleLarge?.copyWith(
              color: shell.onChrome,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: tt.labelMedium?.copyWith(color: shell.muted),
          ),
        ],
      ),
    );
  }

  String? _resolveVideoId(ScheduledPost post) {
    final analytics = post.analyticsHints;
    final directId = analytics['videoId'] as String?;
    if (directId != null && directId.isNotEmpty) {
      return directId;
    }
    final streamersTipId = analytics['streamerstipVideoId'] as String?;
    if (streamersTipId != null && streamersTipId.isNotEmpty) {
      return streamersTipId;
    }
    return null;
  }

  Future<VideoAnalytics?> _loadVideoAnalytics(ScheduledPost post) async {
    final videoId = _resolveVideoId(post);
    if (videoId == null) {
      return null;
    }
    await _videoAnalyticsService.fetchAnalytics(videoId);
    return _videoAnalyticsService.videoAnalytics[videoId];
  }

  String _formatRate(Object? value) {
    final numericValue = switch (value) {
      num v => v.toDouble(),
      _ => 0.0,
    };
    if (numericValue <= 1) {
      return '${(numericValue * 100).toStringAsFixed(1)}%';
    }
    return '${numericValue.toStringAsFixed(1)}%';
  }

  String _formatSeconds(Object? value) {
    final seconds = switch (value) {
      num v => v.toDouble(),
      _ => 0.0,
    };
    return '${seconds.toStringAsFixed(1)}s';
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final TextTheme tt = Theme.of(dialogContext).textTheme;
        final ColorScheme cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surfaceContainerHigh,
          title: Text(title, style: tt.titleLarge),
          content: Text(message, style: tt.bodyMedium),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _showSuccessSnackBar(String message) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: cs.primaryContainer,
        content: Text(
          message,
          style: TextStyle(color: cs.onPrimaryContainer),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: cs.errorContainer,
        content: Text(
          message,
          style: TextStyle(color: cs.onErrorContainer),
        ),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: cs.secondaryContainer,
        content: Text(
          message,
          style: TextStyle(color: cs.onSecondaryContainer),
        ),
      ),
    );
  }

  // Bulk operations
  void _enterSelectionMode(String postId) {
    setState(() {
      _isSelectionMode = true;
      _selectedPosts = {postId};
    });
    HapticFeedback.lightImpact();
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedPosts.clear();
    });
    HapticFeedback.lightImpact();
  }

  void _togglePostSelection(String postId) {
    setState(() {
      if (_selectedPosts.contains(postId)) {
        _selectedPosts.remove(postId);
      } else {
        _selectedPosts.add(postId);
      }
    });
    HapticFeedback.lightImpact();
  }

  void _showBulkActionDialog() {
    final List<ScheduledPost> selectedPosts = _posts
        .where((ScheduledPost post) => _selectedPosts.contains(post.id))
        .toList();
    final bool canPublish = selectedPosts.isNotEmpty &&
        selectedPosts
            .every((ScheduledPost post) => post.status == PostStatus.scheduled);
    final bool canCancel = selectedPosts.any(
      (ScheduledPost post) => post.status == PostStatus.scheduled,
    );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        final TextTheme tt = Theme.of(sheetContext).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Bulk Actions (${_selectedPosts.length} selected)',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                if (canPublish)
                  _buildBulkActionTile(
                    sheetContext,
                    'Publish Now',
                    Icons.publish,
                    BulkAction.publish,
                  ),
                if (canCancel)
                  _buildBulkActionTile(
                    sheetContext,
                    'Cancel Posts',
                    Icons.cancel,
                    BulkAction.cancel,
                  ),
                _buildBulkActionTile(
                  sheetContext,
                  'Delete Posts',
                  Icons.delete,
                  BulkAction.delete,
                ),
                _buildBulkActionTile(
                  sheetContext,
                  'Export Data',
                  Icons.download,
                  BulkAction.export,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBulkActionTile(
    BuildContext sheetContext,
    String title,
    IconData icon,
    BulkAction action,
  ) {
    final TextTheme tt = Theme.of(sheetContext).textTheme;
    final ColorScheme cs = Theme.of(sheetContext).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.onSurfaceVariant),
      title: Text(title, style: tt.titleSmall?.copyWith(color: cs.onSurface)),
      onTap: () {
        Navigator.pop(sheetContext);
        _performBulkAction(action);
      },
    );
  }

  void _performBulkAction(BulkAction action) async {
    final selectedPosts =
        _posts.where((post) => _selectedPosts.contains(post.id)).toList();

    switch (action) {
      case BulkAction.publish:
        await _bulkPublish(selectedPosts);
        break;
      case BulkAction.cancel:
        await _bulkCancel(selectedPosts);
        break;
      case BulkAction.delete:
        await _bulkDelete(selectedPosts);
        break;
      case BulkAction.export:
        await _bulkExport(selectedPosts);
        break;
    }
  }

  Future<void> _bulkPublish(List<ScheduledPost> posts) async {
    setState(() {
      _isLoading = true;
    });

    try {
      for (final post in posts) {
        await _postService.publishNow(post.id);
      }
      _showSuccessSnackBar('${posts.length} posts published successfully');
      _loadPosts();
      _exitSelectionMode();
    } catch (e) {
      _showErrorSnackBar('Failed to publish posts: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _bulkCancel(List<ScheduledPost> posts) async {
    final confirmed = await _showConfirmDialog(
      'Cancel Posts',
      'Are you sure you want to cancel ${posts.length} scheduled posts?',
    );

    if (confirmed) {
      setState(() {
        _isLoading = true;
      });

      try {
        for (final post in posts) {
          await _postService.cancelPost(post.id);
        }
        _showSuccessSnackBar('${posts.length} posts canceled successfully');
        _loadPosts();
        _exitSelectionMode();
      } catch (e) {
        _showErrorSnackBar('Failed to cancel posts: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _bulkDelete(List<ScheduledPost> posts) async {
    final confirmed = await _showConfirmDialog(
      'Delete Posts',
      'Are you sure you want to permanently delete ${posts.length} posts? This action cannot be undone.',
    );

    if (confirmed) {
      setState(() {
        _isLoading = true;
      });

      try {
        for (final post in posts) {
          await _postService.deletePost(post.id);
        }
        _showSuccessSnackBar('${posts.length} posts deleted successfully');
        _loadPosts();
        _exitSelectionMode();
      } catch (e) {
        _showErrorSnackBar('Failed to delete posts: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _bulkExport(List<ScheduledPost> posts) async {
    if (posts.isEmpty) {
      _showInfoSnackBar('No posts selected for export.');
      return;
    }
    await _exportPosts(
      posts,
      filePrefix: 'selected_posts_export',
      successMessage: 'Exported ${posts.length} posts',
    );
  }

  // Sorting
  void _showSortDialog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        final TextTheme tt = Theme.of(sheetContext).textTheme;
        final ColorScheme cs = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Sort Posts',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                ...PostSortOption.values.map((PostSortOption option) {
                  final bool isSelected = option == _sortOption;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected ? cs.primary : cs.outline,
                    ),
                    title: Text(
                      _getSortOptionLabel(option),
                      style: tt.titleSmall?.copyWith(color: cs.onSurface),
                    ),
                    onTap: () {
                      setState(() {
                        _sortOption = option;
                        _posts = _sortPosts(
                          List<ScheduledPost>.from(_posts),
                        );
                      });
                      Navigator.pop(sheetContext);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getSortOptionLabel(PostSortOption option) {
    switch (option) {
      case PostSortOption.dateDesc:
        return 'Date (Newest First)';
      case PostSortOption.dateAsc:
        return 'Date (Oldest First)';
      case PostSortOption.status:
        return 'Status';
      case PostSortOption.platform:
        return 'Platform';
      case PostSortOption.engagement:
        return 'Engagement';
    }
  }

  // More options
  void _showMoreOptionsDialog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        final TextTheme tt = Theme.of(sheetContext).textTheme;
        final ColorScheme cs = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'More Options',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.download, color: cs.onSurfaceVariant),
                  title: Text(
                    'Export All Posts',
                    style: tt.titleSmall?.copyWith(color: cs.onSurface),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _exportAllPosts();
                  },
                ),
                ListTile(
                  leading: Icon(
                    _isRealTimeEnabled ? Icons.pause : Icons.play_arrow,
                    color: cs.onSurfaceVariant,
                  ),
                  title: Text(
                    _isRealTimeEnabled
                        ? 'Pause Auto-Refresh'
                        : 'Enable Auto-Refresh',
                    style: tt.titleSmall?.copyWith(color: cs.onSurface),
                  ),
                  onTap: () {
                    setState(() {
                      _isRealTimeEnabled = !_isRealTimeEnabled;
                    });
                    if (_isRealTimeEnabled) {
                      _startRealTimeUpdates();
                    } else {
                      _refreshTimer?.cancel();
                    }
                    Navigator.pop(sheetContext);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.settings, color: cs.onSurfaceVariant),
                  title: Text(
                    'Refresh Settings',
                    style: tt.titleSmall?.copyWith(color: cs.onSurface),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showRefreshSettingsDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _exportAllPosts() async {
    if (_posts.isEmpty) {
      _showInfoSnackBar('No posts available to export.');
      return;
    }
    await _exportPosts(
      _posts,
      filePrefix: 'all_posts_export',
      successMessage: 'All posts exported successfully',
    );
  }

  Future<void> _exportPosts(
    List<ScheduledPost> posts, {
    required String filePrefix,
    required String successMessage,
  }) async {
    try {
      _showInfoSnackBar('Preparing export...');
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/${filePrefix}_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      final payload = {
        'exportedAt': DateTime.now().toIso8601String(),
        'count': posts.length,
        'posts': posts.map((post) => post.toJson()).toList(),
      };
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
      );

      if (!mounted) {
        return;
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'StreamersTip posts export',
        ),
      );
      _showSuccessSnackBar(successMessage);
    } catch (e) {
      _showErrorSnackBar('Failed to export posts: $e');
    }
  }

  void _showRefreshSettingsDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final TextTheme tt = Theme.of(dialogContext).textTheme;
        final ColorScheme cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surfaceContainerHigh,
          title: Text('Refresh Settings', style: tt.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Refresh Interval: $_refreshInterval seconds',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              SliderTheme(
                data: SliderTheme.of(dialogContext).copyWith(
                  activeTrackColor: cs.primary,
                  inactiveTrackColor: cs.outlineVariant,
                  thumbColor: cs.primary,
                  overlayColor: cs.primary.withValues(alpha: 0.12),
                ),
                child: Slider(
                  value: _refreshInterval.toDouble(),
                  min: 10,
                  max: 300,
                  divisions: 29,
                  onChanged: (double value) {
                    setState(() {
                      _refreshInterval = value.round();
                    });
                  },
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                if (_isRealTimeEnabled) {
                  _startRealTimeUpdates();
                } else {
                  _refreshTimer?.cancel();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // Platform selection for viewing posts
  void _showPlatformSelectionDialog(List<PlatformConfig> platforms) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        final TextTheme tt = Theme.of(sheetContext).textTheme;
        final ColorScheme cs = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Select Platform',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                ...platforms.map(
                  (PlatformConfig platform) => ListTile(
                    leading: Icon(
                      _getPlatformIconFromString(platform.key),
                      color: _getPlatformColorFromString(
                        sheetContext,
                        platform.key,
                      ),
                    ),
                    title: Text(
                      _getPlatformNameFromString(platform.key),
                      style: tt.titleSmall?.copyWith(color: cs.onSurface),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _launchUrl(platform.payload!['url']!);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar('Could not open URL: $url');
      }
    } catch (e) {
      _showErrorSnackBar('Error opening URL: $e');
    }
  }

  IconData _getPlatformIconFromString(String platform) {
    switch (platform) {
      case 'youtube':
        return Icons.play_circle_filled;
      case 'tiktok':
        return Icons.music_note;
      case 'instagram':
        return Icons.camera_alt;
      case 'x':
        return Icons.alternate_email;
      case 'facebook':
        return Icons.facebook;
      case 'linkedin':
        return Icons.business;
      default:
        return Icons.public;
    }
  }

  Color _getPlatformColorFromString(BuildContext context, String platform) {
    final Brightness brightness = Theme.of(context).brightness;
    final ColorScheme cs = Theme.of(context).colorScheme;
    switch (platform) {
      case 'youtube':
        return Colors.red;
      case 'tiktok':
        return brightness == Brightness.dark ? cs.onSurface : Colors.black;
      case 'instagram':
        return Colors.purple;
      case 'x':
        return cs.primary;
      case 'facebook':
        return cs.primary;
      case 'linkedin':
        return cs.primary;
      default:
        return cs.outline;
    }
  }

  String _getPlatformNameFromString(String platform) {
    switch (platform) {
      case 'youtube':
        return 'YouTube';
      case 'tiktok':
        return 'TikTok';
      case 'instagram':
        return 'Instagram';
      case 'x':
        return 'X (Twitter)';
      case 'facebook':
        return 'Facebook';
      case 'linkedin':
        return 'LinkedIn';
      default:
        return platform;
    }
  }
}
