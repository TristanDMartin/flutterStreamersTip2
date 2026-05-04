import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/support_shell_style.dart';
import '../services/user_blocking_service.dart';
import '../utils/avatar_url_resolver.dart';

class BlockedAccountsView extends StatefulWidget {
  const BlockedAccountsView({super.key});

  @override
  State<BlockedAccountsView> createState() => _BlockedAccountsViewState();
}

class _BlockedAccountsViewState extends State<BlockedAccountsView> {
  final UserBlockingService _blockingService = UserBlockingService();
  bool _isLoading = true;
  List<BlockedUserInfo> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get blocked user IDs
      final blockedUserIds = await _blockingService.getBlockedUsers();

      if (blockedUserIds.isEmpty) {
        setState(() {
          _blockedUsers = [];
          _isLoading = false;
        });
        return;
      }

      // Fetch user details for blocked users
      final users = <BlockedUserInfo>[];
      for (final userId in blockedUserIds) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data()!;
            users.add(BlockedUserInfo(
              id: userId,
              displayName: userData['displayName'] ?? 'Unknown User',
              username: userData['username'] ?? 'unknown',
              avatarURL: resolveAvatarUrl(userData),
              blockedAt: userData['blockedAt'] ?? userDoc.data()!['createdAt'],
            ));
          }
        } catch (e) {
          debugPrint('Error loading user $userId: $e');
        }
      }

      setState(() {
        _blockedUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading blocked users: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _unblockUser(String userId, String displayName) async {
    try {
      await _blockingService.unblockUser(userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$displayName has been unblocked'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Reload the list
        _loadBlockedUsers();
      }
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unblock user: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showUnblockConfirmation(
      String userId, String displayName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Unblock User',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to unblock $displayName? You will be able to see their content and interact with them again.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unblock', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _unblockUser(userId, displayName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Scaffold(
      backgroundColor: shell.scaffold,
      appBar: AppBar(
        backgroundColor: shell.panelSurface,
        title: Text(
          'Blocked Accounts',
          style: TextStyle(color: shell.onChrome),
        ),
        iconTheme: IconThemeData(color: shell.onChrome),
        actions: [
          if (_blockedUsers.isNotEmpty)
            IconButton(
              onPressed: _loadBlockedUsers,
              icon: Icon(Icons.refresh, color: shell.onChrome),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(shell.refreshColor),
              ),
            )
          : _blockedUsers.isEmpty
              ? _buildEmptyState()
              : _buildBlockedUsersList(),
    );
  }

  Widget _buildEmptyState() {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.block_outlined,
            color: shell.iconDim,
            size: 80,
          ),
          const SizedBox(height: 24),
          Text(
            'No Blocked Accounts',
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Users you block will appear here.\nYou can unblock them at any time.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: shell.muted,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedUsersList() {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return RefreshIndicator(
      onRefresh: _loadBlockedUsers,
      color: shell.refreshColor,
      backgroundColor: shell.refreshBackground,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _blockedUsers.length,
        itemBuilder: (context, index) {
          final user = _blockedUsers[index];
          return _buildBlockedUserCard(user);
        },
      ),
    );
  }

  Widget _buildBlockedUserCard(BlockedUserInfo user) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: shell.surfaceCardBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey.withValues(alpha: 0.3),
            backgroundImage:
                user.avatarURL != null && user.avatarURL!.isNotEmpty
                    ? CachedNetworkImageProvider(user.avatarURL!)
                    : null,
            child: user.avatarURL == null || user.avatarURL!.isEmpty
                ? Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: shell.onChrome,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: TextStyle(
                    color: shell.onChrome,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user.username}',
                  style: TextStyle(
                    color: shell.muted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.block,
                      color: Colors.red.withValues(alpha: 0.7),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Blocked',
                      style: TextStyle(
                        color: Colors.red.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Unblock button
          IconButton(
            onPressed: () =>
                _showUnblockConfirmation(user.id, user.displayName),
            icon: const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 24,
            ),
            tooltip: 'Unblock user',
          ),
        ],
      ),
    );
  }
}

class BlockedUserInfo {
  final String id;
  final String displayName;
  final String username;
  final String? avatarURL;
  final dynamic blockedAt;

  BlockedUserInfo({
    required this.id,
    required this.displayName,
    required this.username,
    this.avatarURL,
    this.blockedAt,
  });
}
