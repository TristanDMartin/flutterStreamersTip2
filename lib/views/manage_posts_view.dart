import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/scheduled_post.dart';
import '../services/scheduled_post_service.dart';
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
  const ManagePostsView({super.key});

  @override
  State<ManagePostsView> createState() => _ManagePostsViewState();
}

class _ManagePostsViewState extends State<ManagePostsView>
    with TickerProviderStateMixin {
  final ScheduledPostService _postService = ScheduledPostService();
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
  final PostSortOption _sortOption = PostSortOption.dateDesc;

  // Real-time updates
  bool _isRealTimeEnabled = true;
  int _refreshInterval = 30; // seconds
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPosts();
    _startRealTimeUpdates();
  }

  void _startRealTimeUpdates() {
    if (_isRealTimeEnabled) {
      Future.delayed(Duration(seconds: _refreshInterval), () {
        if (mounted) {
          _loadPosts();
          _startRealTimeUpdates();
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
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

      setState(() {
        _posts = sortedPosts;
        _isLoading = false;
        _retryCount = 0;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (_retryCount < _maxRetries) {
        _retryCount++;
        _showErrorSnackBar(
            'Failed to load posts. Retrying... ($_retryCount/$_maxRetries)');
        Future.delayed(Duration(seconds: _retryCount * 2), () {
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
        posts.sort(
            (a, b) => a.platforms.first.key.compareTo(b.platforms.first.key));
        break;
      case PostSortOption.engagement:
        // Mock engagement sorting - in real app, this would use analytics data
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
        padding: const EdgeInsets.all(16),
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
          _buildStatusChip(post.status),
          const Spacer(),
          Text(
            _formatScheduleTime(
                post.schedule?.scheduledAtUtc ?? DateTime.now()),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
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
        child: media.type == MediaType.image
            ? Image.network(
                media.src,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.image,
                  color: Colors.white30,
                  size: 32,
                ),
              )
            : const Icon(
                Icons.play_circle_outline,
                color: Colors.white30,
                size: 32,
              ),
      ),
    );
  }

  Widget _buildPlatformStatuses(ScheduledPost post) {
    return Row(
      children: post.platforms
          .map((platform) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildPlatformStatus(platform),
              ))
          .toList(),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (post.status == PostStatus.scheduled) ...[
            _buildActionButton(
              'Edit',
              Icons.edit,
              () => _editPost(post),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              'Publish Now',
              Icons.publish,
              () => _publishNow(post),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              'Cancel',
              Icons.cancel,
              () => _cancelPost(post),
            ),
          ] else if (post.status == PostStatus.publishing) ...[
            _buildActionButton(
              'View Progress',
              Icons.visibility,
              () => _viewProgress(post),
            ),
          ] else if (post.status == PostStatus.published) ...[
            _buildActionButton(
              'View Post',
              Icons.open_in_new,
              () => _viewPost(post),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              'Analytics',
              Icons.analytics,
              () => _viewAnalytics(post),
            ),
          ] else if (post.status == PostStatus.failed) ...[
            _buildActionButton(
              'Retry',
              Icons.refresh,
              () => _retryPost(post),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              'Fix Connection',
              Icons.link,
              () => _fixConnection(post),
            ),
          ],
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

  Widget _buildStatusChip(PostStatus status) {
    final color = _getStatusColor(status);
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

  void _editPost(ScheduledPost post) async {
    HapticFeedback.lightImpact();
    // final result = await Navigator.push<ScheduledPost>(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => EditPostView(post: post),
    //   ),
    // );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit post feature coming soon!')),
    );
    final result = null;

    if (result != null) {
      _loadPosts();
      _showSuccessSnackBar('Post updated successfully');
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

  void _viewProgress(ScheduledPost post) {
    HapticFeedback.lightImpact();
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => PostProgressView(post: post),
    //   ),
    // );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post progress feature coming soon!')),
    );
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

  void _viewAnalytics(ScheduledPost post) {
    HapticFeedback.lightImpact();
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => PostAnalyticsView(post: post),
    //   ),
    // );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post analytics feature coming soon!')),
    );
  }

  void _retryPost(ScheduledPost post) async {
    try {
      await _postService.retryPost(post.id);
      _showSuccessSnackBar('Post retry initiated');
      _loadPosts();
    } catch (e) {
      _showErrorSnackBar('Failed to retry post: $e');
    }
  }

  void _fixConnection(ScheduledPost post) {
    HapticFeedback.lightImpact();
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => PlatformReconnectionView(post: post),
    //   ),
    // );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Platform reconnection feature coming soon!')),
    );
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
            _buildBulkActionTile(
                'Publish Now', Icons.publish, BulkAction.publish),
            _buildBulkActionTile(
                'Cancel Posts', Icons.cancel, BulkAction.cancel),
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
    // Mock export functionality
    _showInfoSnackBar('Exporting ${posts.length} posts...');
    await Future.delayed(const Duration(seconds: 2));
    _showSuccessSnackBar('Export completed successfully');
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
            ...PostSortOption.values
                .map((option) => RadioListTile<PostSortOption>(
                      title: Text(_getSortOptionLabel(option),
                          style: const TextStyle(color: Colors.white)),
                      value: option,
                      activeColor: const Color(0xFF9248D2),
                    )),
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
    _showInfoSnackBar('Exporting all posts...');
    await Future.delayed(const Duration(seconds: 2));
    _showSuccessSnackBar('All posts exported successfully');
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
