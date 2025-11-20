import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user.dart';
import '../services/network_service_optimized.dart';
import 'streamer_card_view.dart';
import '../services/unified_avatar_service.dart';

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
    return _buildUserList(_connections, 'No connections yet');
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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openStreamerCardForUser(user),
      child: Container(
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

  void _openStreamerCardForUser(User user) {
    final currentUserId =
        firebase_auth.FirebaseAuth.instance.currentUser?.uid;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StreamerCardView(
          userId: user.id,
          currentUserId: currentUserId,
          onDismiss: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
