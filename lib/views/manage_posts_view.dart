import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/scheduled_post.dart';
import '../services/scheduled_post_service.dart';

class ManagePostsView extends StatefulWidget {
  const ManagePostsView({super.key});

  @override
  State<ManagePostsView> createState() => _ManagePostsViewState();
}

class _ManagePostsViewState extends State<ManagePostsView> with TickerProviderStateMixin {
  final ScheduledPostService _postService = ScheduledPostService();
  List<ScheduledPost> _posts = [];
  bool _isLoading = true;
  PostStatus? _filterStatus;
  PlatformKey? _filterPlatform;
  String _searchQuery = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPosts();
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
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load posts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
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
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: _showFilterDialog,
          ),
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
    );
  }

  Widget _buildPostsList(PostStatus status) {
    final filteredPosts = _posts.where((post) => post.status == status).toList();
    
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPostHeader(post),
          _buildPostContent(post),
          _buildPostActions(post),
        ],
      ),
    );
  }

  Widget _buildPostHeader(ScheduledPost post) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatusChip(post.status),
          const Spacer(),
          Text(
            _formatScheduleTime(post.schedule.scheduledAtUtc),
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
              children: post.tags.take(3).map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              )).toList(),
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
      children: post.platforms.map((platform) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: _buildPlatformStatus(platform),
      )).toList(),
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
              children: PostStatus.values.map((status) => FilterChip(
                label: Text(_getStatusText(status)),
                selected: _filterStatus == status,
                onSelected: (selected) {
                  setState(() {
                    _filterStatus = selected ? status : null;
                  });
                },
              )).toList(),
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
              children: PlatformKey.values.map((platform) => FilterChip(
                label: Text(_getPlatformName(platform)),
                selected: _filterPlatform == platform,
                onSelected: (selected) {
                  setState(() {
                    _filterPlatform = selected ? platform : null;
                  });
                },
              )).toList(),
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

  void _editPost(ScheduledPost post) {
    // Navigate to edit post screen
    _showInfoSnackBar('Edit post functionality coming soon');
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
    _showInfoSnackBar('View progress functionality coming soon');
  }

  void _viewPost(ScheduledPost post) {
    _showInfoSnackBar('View post functionality coming soon');
  }

  void _viewAnalytics(ScheduledPost post) {
    _showInfoSnackBar('Analytics functionality coming soon');
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
    _showInfoSnackBar('Fix connection functionality coming soon');
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
}
