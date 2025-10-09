import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import '../models/streamer_card.dart';
import '../services/network_service_optimized.dart';
import '../services/unified_avatar_service.dart';
import 'streamer_card_view.dart';

class NetworkViewOptimized extends StatefulWidget {
  const NetworkViewOptimized({super.key});

  @override
  State<NetworkViewOptimized> createState() => _NetworkViewOptimizedState();
}

class _NetworkViewOptimizedState extends State<NetworkViewOptimized>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final NetworkServiceOptimized _networkService = NetworkServiceOptimized();

  // Data
  List<User> _connections = [];
  List<User> _followers = [];
  List<User> _following = [];

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
        _networkService.getConnections(),
        _networkService.getFollowers(),
        _networkService.getFollowing(),
      ]);

      setState(() {
        _connections = results[0];
        _followers = results[1];
        _following = results[2];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Create dummy StreamerCard for testing
  StreamerCard _createDummyStreamerCard() {
    return const StreamerCard(
      id: 'dummy_streamer_123',
      username: 'teststreamer',
      displayName: 'Test Streamer',
      bio:
          'Welcome to my channel! I create amazing content about gaming, tech, and lifestyle. Follow me for daily updates and live streams!',
      avatarURL:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
      platforms: [
        Platform(
          id: 'platform_1',
          type: PlatformType.youtube,
          username: 'teststreamer',
          followers: 12500,
          url: 'https://youtube.com/@teststreamer',
        ),
        Platform(
          id: 'platform_2',
          type: PlatformType.twitch,
          username: 'teststreamer',
          followers: 8500,
          url: 'https://twitch.tv/teststreamer',
        ),
        Platform(
          id: 'platform_3',
          type: PlatformType.instagram,
          username: '@teststreamer',
          followers: 22000,
          url: 'https://instagram.com/teststreamer',
        ),
      ],
      hashtags: ['gaming', 'tech', 'lifestyle', 'streaming', 'entertainment'],
      socialLinks: [
        SocialLink(
          id: 'social_1',
          platform: 'website',
          url: 'https://teststreamer.com',
          username: 'teststreamer',
        ),
        SocialLink(
          id: 'social_2',
          platform: 'discord',
          url: 'https://discord.gg/teststreamer',
          username: 'teststreamer',
        ),
      ],
      isConnected: true,
      onlineStatus: 'online',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _buildHeader(),
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
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Text(
            'Network',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
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
          Tab(text: 'Connections'),
          Tab(text: 'Followers'),
          Tab(text: 'Following'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildConnectionsTab(),
        _buildUserList(_followers, 'No followers yet'),
        _buildUserList(_following, 'Not following anyone yet'),
      ],
    );
  }

  Widget _buildConnectionsTab() {
    if (_connections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Add dummy StreamerCard for testing
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showStreamerCard();
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9248D2), Color(0xFF25E5D2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          UnifiedAvatarService().getAvatar(
                            imageUrl:
                                'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
                            radius: 30,
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Test Streamer',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '@teststreamer',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tap to view full profile',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No connections yet',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect with other streamers to see them here',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return _buildUserList(_connections, 'No connections yet');
  }

  void _showStreamerCard() {
    final dummyCard = _createDummyStreamerCard();

    // Show StreamerCardView as modal (matching app-wide pattern)
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) {
        return StreamerCardView(
          userId: dummyCard.id,
          currentUserId: 'current_user_123', // Dummy current user ID
          onDismiss: () => Navigator.of(context).pop(),
          onFollow: (userId) async {},
          onMessage: (userId) {},
          onNavigateToTab: (tabName) {},
          onShare: (userId) {},
        );
      },
    );
  }

  Widget _buildUserList(List<User> users, String emptyMessage) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildUserTile(user);
      },
    );
  }

  Widget _buildUserTile(User user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: [
          UnifiedAvatarService().getAvatar(
            imageUrl: user.avatarURL ?? '',
            radius: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '@${user.username}',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                if (user.bio != null && user.bio!.isNotEmpty)
                  Text(
                    user.bio!,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          _buildActionButtons(user),
        ],
      ),
    );
  }

  Widget _buildActionButtons(User user) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _handleFollow(user),
          icon: const Icon(Icons.person_add, color: Colors.white),
          tooltip: 'Follow',
        ),
        IconButton(
          onPressed: () => _handleUnfollow(user),
          icon: const Icon(Icons.person_remove, color: Colors.red),
          tooltip: 'Unfollow',
        ),
        IconButton(
          onPressed: () => _handleRemove(user),
          icon: const Icon(Icons.block, color: Colors.orange),
          tooltip: 'Remove',
        ),
      ],
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
            'Loading network...',
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
            'Error loading network',
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

  Future<void> _handleFollow(User user) async {
    HapticFeedback.lightImpact();

    try {
      final success = await _networkService.followUser(user.id);
      if (success) {
        _showSnackBar('Following ${user.displayName}');
        _loadData(); // Refresh data
      } else {
        _showSnackBar('Failed to follow ${user.displayName}', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error following user', isError: true);
    }
  }

  Future<void> _handleUnfollow(User user) async {
    HapticFeedback.lightImpact();

    try {
      final success = await _networkService.unfollowUser(user.id);
      if (success) {
        _showSnackBar('Unfollowed ${user.displayName}');
        _loadData(); // Refresh data
      } else {
        _showSnackBar('Failed to unfollow ${user.displayName}', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error unfollowing user', isError: true);
    }
  }

  Future<void> _handleRemove(User user) async {
    HapticFeedback.lightImpact();

    try {
      final success = await _networkService.removeFollower(user.id);
      if (success) {
        _showSnackBar('Removed ${user.displayName}');
        _loadData(); // Refresh data
      } else {
        _showSnackBar('Failed to remove ${user.displayName}', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error removing user', isError: true);
    }
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
