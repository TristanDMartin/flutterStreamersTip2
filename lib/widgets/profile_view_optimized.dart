import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart' as app_user;
import '../models/home_video.dart';
import '../models/calendar_event.dart';
import '../services/profile_service_optimized.dart';

class ProfileViewOptimized extends StatefulWidget {
  final app_user.User user;
  final bool isCurrentUser;

  const ProfileViewOptimized({
    super.key,
    required this.user,
    required this.isCurrentUser,
  });

  @override
  State<ProfileViewOptimized> createState() => _ProfileViewOptimizedState();
}

class _ProfileViewOptimizedState extends State<ProfileViewOptimized>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ProfileServiceOptimized _profileService = ProfileServiceOptimized();

  // Data
  List<HomeVideo> _videos = [];
  List<CalendarEvent> _events = [];
  List<Map<String, dynamic>> _platforms = [];
  bool _isFollowing = false;

  // State
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load all data in parallel
      final results = await Future.wait([
        _profileService.getUserVideos(widget.user.id),
        _profileService.getUserEvents(widget.user.id),
        _profileService.getUserPlatforms(widget.user.id),
        if (!widget.isCurrentUser) _profileService.isFollowing(widget.user.id),
      ]);

      setState(() {
        _videos = results[0] as List<HomeVideo>;
        _events = results[1] as List<CalendarEvent>;
        _platforms = results[2] as List<Map<String, dynamic>>;
        if (!widget.isCurrentUser) {
          _isFollowing = results[3] as bool;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _buildHeader(),
          _buildProfileInfo(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _error != null
                    ? _buildErrorState()
                    : _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Expanded(
            child: Text(
              'Profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: _showProfileMenu,
            icon: const Icon(Icons.more_horiz, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Avatar and basic info
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: widget.user.avatarURL != null
                    ? NetworkImage(widget.user.avatarURL!)
                    : null,
                child: widget.user.avatarURL == null
                    ? Text(
                        widget.user.displayName.isNotEmpty
                            ? widget.user.displayName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '@${widget.user.username}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStat('Posts', widget.user.postCount),
                        const SizedBox(width: 20),
                        _buildStat('Followers', widget.user.followerCount),
                        const SizedBox(width: 20),
                        _buildStat('Following', widget.user.followingCount),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Bio
          if (widget.user.bio != null && widget.user.bio?.isNotEmpty == true)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.user.bio ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Action buttons
          if (widget.isCurrentUser)
            _buildCurrentUserActions()
          else
            _buildOtherUserActions(),
        ],
      ),
    );
  }

  Widget _buildStat(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentUserActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _editProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9248D2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Edit Profile',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _shareProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[800],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Icon(Icons.share, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildOtherUserActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isFollowing ? _unfollowUser : _followUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isFollowing ? Colors.grey[800] : const Color(0xFF9248D2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              _isFollowing ? 'Following' : 'Follow',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _messageUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[800],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Icon(Icons.message, color: Colors.white),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _shareProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[800],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Icon(Icons.share, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF9248D2),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        tabs: const [
          Tab(text: 'Videos'),
          Tab(text: 'Events'),
          Tab(text: 'Platforms'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildVideosTab(),
        _buildEventsTab(),
        _buildPlatformsTab(),
      ],
    );
  }

  Widget _buildVideosTab() {
    if (_videos.isEmpty) {
      return _buildEmptyState('No videos yet', Icons.video_library_outlined);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        return _buildVideoThumbnail(video);
      },
    );
  }

  Widget _buildVideoThumbnail(HomeVideo video) {
    return GestureDetector(
      onTap: () => _playVideo(video),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[800],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: (video.thumbnailURL?.isNotEmpty == true)
              ? Image.network(
                  video.thumbnailURL!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.video_library,
                      color: Colors.grey,
                      size: 40,
                    );
                  },
                )
              : const Icon(
                  Icons.video_library,
                  color: Colors.grey,
                  size: 40,
                ),
        ),
      ),
    );
  }

  Widget _buildEventsTab() {
    if (_events.isEmpty) {
      return _buildEmptyState('No events yet', Icons.event);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index];
        return _buildEventCard(event);
      },
    );
  }

  Widget _buildEventCard(CalendarEvent event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            event.description,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDate(event.date),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformsTab() {
    if (_platforms.isEmpty) {
      return _buildEmptyState('No platforms yet', Icons.link);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _platforms.length,
      itemBuilder: (context, index) {
        final platform = _platforms[index];
        return _buildPlatformCard(platform);
      },
    );
  }

  Widget _buildPlatformCard(Map<String, dynamic> platform) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _getPlatformIcon(platform['type']),
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  platform['type'].toString().toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '@${platform['username']}',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${platform['followers']} followers',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _openPlatform(platform['url']),
            icon: const Icon(Icons.open_in_new, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
          ),
          SizedBox(height: 16),
          Text(
            'Loading profile...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading profile',
            style: TextStyle(
              color: Colors.red[400],
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9248D2),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  IconData _getPlatformIcon(String type) {
    switch (type.toLowerCase()) {
      case 'youtube':
        return Icons.play_circle_filled;
      case 'twitch':
        return Icons.live_tv;
      case 'instagram':
        return Icons.camera_alt;
      case 'tiktok':
        return Icons.music_note;
      default:
        return Icons.link;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showProfileMenu() {
    HapticFeedback.lightImpact();
    // TODO: Show profile menu
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile menu coming soon'),
        backgroundColor: Color(0xFF9248D2),
      ),
    );
  }

  void _editProfile() {
    HapticFeedback.lightImpact();
    // TODO: Navigate to edit profile
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit profile coming soon'),
        backgroundColor: Color(0xFF9248D2),
      ),
    );
  }

  void _shareProfile() {
    HapticFeedback.lightImpact();
    // TODO: Share profile
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share profile coming soon'),
        backgroundColor: Color(0xFF9248D2),
      ),
    );
  }

  Future<void> _followUser() async {
    HapticFeedback.lightImpact();
    
    try {
      final success = await _profileService.followUser(widget.user.id);
      if (success) {
        setState(() {
          _isFollowing = true;
        });
        _showSnackBar('Following ${widget.user.displayName}');
      } else {
        _showSnackBar('Failed to follow user', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error following user', isError: true);
    }
  }

  Future<void> _unfollowUser() async {
    HapticFeedback.lightImpact();
    
    try {
      final success = await _profileService.unfollowUser(widget.user.id);
      if (success) {
        setState(() {
          _isFollowing = false;
        });
        _showSnackBar('Unfollowed ${widget.user.displayName}');
      } else {
        _showSnackBar('Failed to unfollow user', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error unfollowing user', isError: true);
    }
  }

  void _messageUser() {
    HapticFeedback.lightImpact();
    // TODO: Navigate to chat
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message feature coming soon'),
        backgroundColor: Color(0xFF9248D2),
      ),
    );
  }

  void _playVideo(HomeVideo video) {
    HapticFeedback.lightImpact();
    // TODO: Play video
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Video player coming soon'),
        backgroundColor: Color(0xFF9248D2),
      ),
    );
  }

  void _openPlatform(String? url) {
    HapticFeedback.lightImpact();
    // TODO: Open platform URL
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Platform link coming soon'),
        backgroundColor: Color(0xFF9248D2),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF9248D2),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
