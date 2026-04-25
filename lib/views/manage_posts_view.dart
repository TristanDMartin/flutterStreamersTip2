import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Manage Posts',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              if (_isSelectionMode) ...[
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _exitSelectionMode,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed:
                      _selectedPosts.isNotEmpty ? _showBulkActionDialog : null,
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: _showSearchDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.sort, color: Colors.white),
                  onPressed: _showSortDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list, color: Colors.white),
                  onPressed: _showFilterDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onPressed: _showMoreOptionsDialog,
                ),
              ],
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF9248D2),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Scheduled'),
                Tab(text: 'Publishing'),
                Tab(text: 'Published'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPostsList(PostStatus.scheduled),
              _buildPostsList(PostStatus.publishing),
              _buildPostsList(PostStatus.published),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostsList(PostStatus status) {
    final filteredPosts =
        _posts.where((post) => post.status == status).toList();

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
        ),
      );
    }

    if (filteredPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEmptyStateIcon(status),
              size: 64,
              color: Colors.white30,
            ),
            const SizedBox(height: 16),
            Text(
              _getEmptyStateMessage(status),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      color: const Color(0xFF9248D2),
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.of(context).padding.top + 132,
          16,
          24,
        ),
        itemCount: filteredPosts.length,
        itemBuilder: (context, index) {
          final post = filteredPosts[index];
          return _buildPostCard(post);
        },
      ),
    );
  }

  Widget _buildPostCard(ScheduledPost post) {
    final isSelected = _selectedPosts.contains(post.id);

    return GestureDetector(
      onTap: _isSelectionMode ? () => _togglePostSelection(post.id) : null,
      onLongPress: () => _enterSelectionMode(post.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF9248D2).withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF9248D2)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostHeader(post, isSelected),
            _buildPostContent(post),
            _buildPostActions(post),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader(ScheduledPost post, bool isSelected) {
    final isOverdue = post.status == PostStatus.scheduled &&
        post.schedule?.scheduledAtUtc != null &&
        post.schedule!.scheduledAtUtc.isBefore(DateTime.now());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_isSelectionMode) ...[
            Checkbox(
              value: isSelected,
              onChanged: (value) => _togglePostSelection(post.id),
              activeColor: const Color(0xFF9248D2),
            ),
            const SizedBox(width: 8),
          ],
          _buildStatusChip(post.status, isOverdue: isOverdue),
          const Spacer(),
          if (isOverdue) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange, width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, color: Colors.orange, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Overdue',
                    style: TextStyle(
                      color: Colors.orange,
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
                color: isOverdue ? Colors.orange : Colors.white70,
                fontSize: 12,
                fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent(ScheduledPost post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.media.isNotEmpty) ...[
            _buildMediaPreview(post.media.first),
            const SizedBox(height: 12),
          ],
          Text(
            post.caption,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: post.tags
                  .take(3)
                  .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9248D2).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#$tag',
                          style: const TextStyle(
                            color: Color(0xFF9248D2),
                            fontSize: 10,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          _buildPlatformStatuses(post),
        ],
      ),
    );
  }

  Widget _buildMediaPreview(PostMedia media) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withValues(alpha: 0.1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Show thumbnail/image
            Image.network(
              media.src,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.white.withValues(alpha: 0.1),
                child: const Icon(
                  Icons.image,
                  color: Colors.white30,
                  size: 32,
                ),
              ),
            ),
            // Show play icon overlay for videos
            if (media.type == MediaType.video)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformStatuses(ScheduledPost post) {
    if (post.platforms.isEmpty) {
      return _buildActionChip('StreamersTip only', Icons.verified);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: post.platforms
              .map((platform) => _buildPlatformStatus(platform))
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

  Widget _buildPlatformStatus(PlatformConfig platform) {
    final status = platform.status ?? PlatformStatus.pending;
    final color = _getPlatformStatusColor(status);

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

  Widget _buildPostActions(ScheduledPost post) {
    final failedPlatforms = _failedPlatforms(post);
    final reauthPlatforms = _reauthPlatforms(post);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (post.status == PostStatus.scheduled) ...[
            _buildActionButton(
              'Publish Now',
              Icons.publish,
              () => _publishNow(post),
            ),
            _buildActionButton(
              'Cancel',
              Icons.cancel,
              () => _cancelPost(post),
            ),
            _buildActionButton(
              'Progress',
              Icons.insights,
              () => _showPostProgress(post),
            ),
          ] else if (post.status == PostStatus.publishing) ...[
            _buildActionChip('Publishing', Icons.schedule_send),
            _buildActionButton(
              'Progress',
              Icons.insights,
              () => _showPostProgress(post),
            ),
          ] else if (post.status == PostStatus.published) ...[
            _buildActionButton(
              'View Post',
              Icons.open_in_new,
              () => _viewPost(post),
            ),
            _buildActionButton(
              'Analytics',
              Icons.bar_chart,
              () => _showPostAnalytics(post),
            ),
            if (failedPlatforms.isNotEmpty) ...[
              _buildActionButton(
                'Retry Failed',
                Icons.refresh,
                () => _retryPost(post, platformKeys: failedPlatforms),
              ),
            ],
          ] else if (post.status == PostStatus.failed) ...[
            _buildActionButton(
              failedPlatforms.isNotEmpty ? 'Retry Failed' : 'Retry',
              Icons.refresh,
              () => _retryPost(
                post,
                platformKeys:
                    failedPlatforms.isNotEmpty ? failedPlatforms : null,
              ),
            ),
            _buildActionButton(
              'Progress',
              Icons.insights,
              () => _showPostProgress(post),
            ),
            if (reauthPlatforms.isNotEmpty) ...[
              _buildActionButton(
                'Reconnect',
                Icons.link_off,
                () => _openReconnectPlatforms(post),
              ),
            ] else ...[
              _buildActionButton(
                'Analytics',
                Icons.bar_chart,
                () => _showPostAnalytics(post),
              ),
            ],
          ] else if (post.status == PostStatus.canceled ||
              post.status == PostStatus.draft) ...[
            _buildActionButton(
              'Progress',
              Icons.insights,
              () => _showPostProgress(post),
            ),
          ],
          if (post.platforms.isNotEmpty) ...[
            _buildActionButton(
              'Details',
              Icons.toc,
              () => _showPlatformDetails(post),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(PostStatus status, {bool isOverdue = false}) {
    final color = isOverdue ? Colors.orange : _getStatusColor(status);
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

  Color _getStatusColor(PostStatus status) {
    switch (status) {
      case PostStatus.scheduled:
        return Colors.blue;
      case PostStatus.publishing:
        return Colors.orange;
      case PostStatus.published:
        return Colors.green;
      case PostStatus.failed:
        return Colors.red;
      case PostStatus.canceled:
        return Colors.grey;
      case PostStatus.draft:
        return Colors.purple;
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

  Color _getPlatformStatusColor(PlatformStatus status) {
    switch (status) {
      case PlatformStatus.pending:
        return Colors.blue;
      case PlatformStatus.publishing:
        return Colors.orange;
      case PlatformStatus.published:
        return Colors.green;
      case PlatformStatus.failed:
        return Colors.red;
      case PlatformStatus.needsReauth:
        return Colors.amber;
      case PlatformStatus.canceled:
        return Colors.grey;
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Search Posts',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search by caption or tags...',
            hintStyle: TextStyle(color: Colors.white70),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
              });
              _loadPosts();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              _loadPosts();
              Navigator.pop(context);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Filter Posts',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            // Status filter
            const Text(
              'Status',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: PostStatus.values
                  .map((status) => FilterChip(
                        label: Text(_getStatusText(status)),
                        selected: _filterStatus == status,
                        onSelected: (selected) {
                          setState(() {
                            _filterStatus = selected ? status : null;
                          });
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            // Platform filter
            const Text(
              'Platform',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: PlatformKey.values
                  .map((platform) => FilterChip(
                        label: Text(_getPlatformName(platform)),
                        selected: _filterPlatform == platform,
                        onSelected: (selected) {
                          setState(() {
                            _filterPlatform = selected ? platform : null;
                          });
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _loadPosts();
                Navigator.pop(context);
              },
              child: const Text('Apply Filters'),
            ),
          ],
        ),
      ),
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
      style: const TextStyle(
        color: Colors.white60,
        fontSize: 11,
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Publish Progress',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                post.caption.isEmpty ? 'Untitled post' : post.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              _buildProgressMetric(
                'Current status',
                _getStatusText(post.status),
              ),
              if (scheduledAt != null)
                _buildProgressMetric(
                  'Scheduled for',
                  '${MaterialLocalizations.of(context).formatFullDate(scheduledAt)} '
                      '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(scheduledAt))}',
                ),
              _buildProgressMetric(
                'Destinations completed',
                '$successfulCount of ${post.platforms.length}',
              ),
              if (inFlightCount > 0)
                _buildProgressMetric('Currently publishing', '$inFlightCount'),
              if (failedCount > 0)
                _buildProgressMetric(
                  'Needs retry',
                  _failedPlatforms(post)
                      .map(_getPlatformNameFromString)
                      .join(', '),
                ),
              if (reauthCount > 0)
                _buildProgressMetric(
                  'Needs reconnect',
                  _reauthPlatforms(post)
                      .map(_getPlatformNameFromString)
                      .join(', '),
                ),
              const SizedBox(height: 12),
              const Text(
                'Publishing Timeline',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadPublishingHistory(post),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    );
                  }

                  final history = snapshot.data ?? const [];
                  if (history.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        snapshot.hasError
                            ? 'Detailed publishing history is not available from the backend for this post yet.'
                            : 'No per-attempt publishing history is available for this post yet.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: history
                        .map((entry) => _buildHistoryEntry(entry))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryEntry(Map<String, dynamic> entry) {
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: _historyStatusColor(status),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  platform == null || platform.isEmpty
                      ? _historyStatusLabel(status)
                      : '${_getPlatformNameFromString(platform)} • ${_historyStatusLabel(status)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                if (timestamp != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${MaterialLocalizations.of(context).formatShortDate(timestamp)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(timestamp))}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _historyStatusColor(String rawStatus) {
    switch (rawStatus.toLowerCase()) {
      case 'published':
      case 'success':
      case 'completed':
        return Colors.greenAccent;
      case 'publishing':
      case 'processing':
      case 'queued':
        return Colors.orangeAccent;
      case 'failed':
      case 'error':
        return Colors.redAccent;
      case 'needsreauth':
      case 'needs_reauth':
        return Colors.amberAccent;
      default:
        return Colors.white54;
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
    final successfulPlatforms = post.platforms
        .where((platform) => platform.status == PlatformStatus.published)
        .map((platform) => _getPlatformNameFromString(platform.key))
        .toList();
    final videoId = _resolveVideoId(post);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Post Analytics',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<VideoAnalytics?>(
              future: _loadVideoAnalytics(post),
              builder: (context, snapshot) {
                final analytics = snapshot.data;
                final fallback = post.analyticsHints;
                final views = analytics?.views ??
                    fallback['views'] ??
                    fallback['impressions'] ??
                    0;
                final likes = analytics?.likes ?? fallback['likes'] ?? 0;
                final comments =
                    analytics?.comments ?? fallback['comments'] ?? 0;
                final shares = analytics?.shares ?? fallback['shares'] ?? 0;
                final engagement =
                    analytics?.engagementRate ?? fallback['engagement'] ?? 0;
                final averageWatchTime = analytics?.averageWatchTime ??
                    fallback['averageWatchTime'] ??
                    0;
                final completionRate = analytics?.completionRate ??
                    fallback['completionRate'] ??
                    0;
                final uniqueViewers =
                    analytics?.uniqueViewers ?? fallback['uniqueViewers'] ?? 0;
                final audienceReach =
                    analytics?.audienceReach ?? fallback['audienceReach'] ?? 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        videoId != null)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(),
                      ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildAnalyticsCard('Views', '$views'),
                        _buildAnalyticsCard('Likes', '$likes'),
                        _buildAnalyticsCard('Comments', '$comments'),
                        _buildAnalyticsCard('Shares', '$shares'),
                        _buildAnalyticsCard(
                          'Engagement',
                          _formatRate(engagement),
                        ),
                        _buildAnalyticsCard(
                          'Avg Watch',
                          _formatSeconds(averageWatchTime),
                        ),
                        _buildAnalyticsCard(
                          'Completion',
                          _formatRate(completionRate),
                        ),
                        _buildAnalyticsCard('Unique Viewers', '$uniqueViewers'),
                        _buildAnalyticsCard('Reach', '$audienceReach'),
                      ],
                    ),
                    if (snapshot.hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Showing saved analytics hints because live analytics could not be loaded.',
                          style: TextStyle(
                            color: Colors.orangeAccent.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
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
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlatformDetails(ScheduledPost post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Platform Status',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...post.platforms.map((platform) {
              final status = platform.status ?? PlatformStatus.pending;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _getPlatformIconFromString(platform.key),
                  color: _getPlatformColorFromString(platform.key),
                ),
                title: Text(
                  _getPlatformNameFromString(platform.key),
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  platform.error?.isNotEmpty == true
                      ? '${_getPlatformStatusText(status)}: ${platform.error}'
                      : _getPlatformStatusText(status),
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: _buildInlinePlatformAction(post, platform),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget? _buildInlinePlatformAction(
      ScheduledPost post, PlatformConfig platform) {
    final status = platform.status ?? PlatformStatus.pending;
    if (status == PlatformStatus.failed) {
      return TextButton(
        onPressed: () {
          Navigator.pop(context);
          _retryPost(post, platformKeys: [platform.key]);
        },
        child: const Text('Retry'),
      );
    }
    if (status == PlatformStatus.needsReauth) {
      return TextButton(
        onPressed: () {
          Navigator.pop(context);
          _openReconnectPlatforms(post);
        },
        child: const Text('Reconnect'),
      );
    }
    return null;
  }

  Widget _buildProgressMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(String label, String value) {
    return Container(
      width: 104,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
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
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF9248D2),
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
    final selectedPosts =
        _posts.where((post) => _selectedPosts.contains(post.id)).toList();
    final canPublish = selectedPosts.isNotEmpty &&
        selectedPosts.every((post) => post.status == PostStatus.scheduled);
    final canCancel =
        selectedPosts.any((post) => post.status == PostStatus.scheduled);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bulk Actions (${_selectedPosts.length} selected)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (canPublish)
              _buildBulkActionTile(
                'Publish Now',
                Icons.publish,
                BulkAction.publish,
              ),
            if (canCancel)
              _buildBulkActionTile(
                'Cancel Posts',
                Icons.cancel,
                BulkAction.cancel,
              ),
            _buildBulkActionTile(
                'Delete Posts', Icons.delete, BulkAction.delete),
            _buildBulkActionTile(
                'Export Data', Icons.download, BulkAction.export),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkActionTile(String title, IconData icon, BulkAction action) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context);
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sort Posts',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...PostSortOption.values.map(
              (option) {
                final isSelected = option == _sortOption;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color:
                        isSelected ? const Color(0xFF9248D2) : Colors.white54,
                  ),
                  title: Text(
                    _getSortOptionLabel(option),
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    setState(() {
                      _sortOption = option;
                      _posts = _sortPosts(List<ScheduledPost>.from(_posts));
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ],
        ),
      ),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'More Options',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.white70),
              title: const Text('Export All Posts',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _exportAllPosts();
              },
            ),
            ListTile(
              leading: Icon(
                _isRealTimeEnabled ? Icons.pause : Icons.play_arrow,
                color: Colors.white70,
              ),
              title: Text(
                _isRealTimeEnabled
                    ? 'Pause Auto-Refresh'
                    : 'Enable Auto-Refresh',
                style: const TextStyle(color: Colors.white),
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
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white70),
              title: const Text('Refresh Settings',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showRefreshSettingsDialog();
              },
            ),
          ],
        ),
      ),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Refresh Settings',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Refresh Interval: $_refreshInterval seconds',
                style: const TextStyle(color: Colors.white70)),
            Slider(
              value: _refreshInterval.toDouble(),
              min: 10,
              max: 300,
              divisions: 29,
              onChanged: (value) {
                setState(() {
                  _refreshInterval = value.round();
                });
              },
              activeColor: const Color(0xFF9248D2),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_isRealTimeEnabled) {
                _startRealTimeUpdates();
              } else {
                _refreshTimer?.cancel();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Platform selection for viewing posts
  void _showPlatformSelectionDialog(List<PlatformConfig> platforms) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Platform',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...platforms.map((platform) => ListTile(
                  leading: Icon(
                    _getPlatformIconFromString(platform.key),
                    color: _getPlatformColorFromString(platform.key),
                  ),
                  title: Text(
                    _getPlatformNameFromString(platform.key),
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _launchUrl(platform.payload!['url']!);
                  },
                )),
          ],
        ),
      ),
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

  Color _getPlatformColorFromString(String platform) {
    switch (platform) {
      case 'youtube':
        return Colors.red;
      case 'tiktok':
        return Colors.black;
      case 'instagram':
        return Colors.purple;
      case 'x':
        return Colors.blue;
      case 'facebook':
        return Colors.blue;
      case 'linkedin':
        return Colors.blue;
      default:
        return Colors.grey;
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
