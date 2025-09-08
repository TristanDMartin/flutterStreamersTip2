import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/connection.dart';
import '../providers/shared_draft_provider.dart';

class ShareSheet extends ConsumerWidget {
  final String videoId;
  final String videoUrl;
  final String videoCaption;
  final VoidCallback? onClose;

  const ShareSheet({
    super.key,
    required this.videoId,
    required this.videoUrl,
    required this.videoCaption,
    this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionsAsync = ref.watch(sharedDraftConnectionsProvider);
    
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF9248D2), // Primary purple
            Color(0xFF7768DF), // Secondary purple
          ],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with drag handle and close button
          _buildHeader(context),
          
          // Quick Share to Friends (Row 1)
          connectionsAsync.when(
            data: (connections) => _buildQuickShareRow(context, connections),
            loading: () => _buildLoadingConnections(),
            error: (error, stack) => _buildErrorConnections(),
          ),
          
          const SizedBox(height: 24),
          
          // External/Social Share Options (Row 2)
          _buildSocialShareRow(context),
          
          const SizedBox(height: 24),
          
          // Utility Actions (Row 3)
          _buildUtilityActionsRow(context),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Spacer(),
          const Text(
            'Share to',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // Close button
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              onClose?.call();
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 18,
              ),
            ),
              ),
            ],
          ),
    );
  }

  Widget _buildQuickShareRow(BuildContext context, List<Connection> connections) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Share',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: connections.length,
              itemBuilder: (context, index) {
                final connection = connections[index];
                return _buildFriendItem(context, connection);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingConnections() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Share',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12),
          Expanded(
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorConnections() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Share',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12),
          Expanded(
            child: Center(
              child: Text(
                'Unable to load connections',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendItem(BuildContext context, Connection connection) {
    return GestureDetector(
      onTap: () => _shareToFriend(context, connection),
      child: Container(
        width: 70,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            // Profile picture
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF9248d2),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: Image.network(
                  connection.avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF9248d2),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 24,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Display name
            Text(
              connection.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Status
            Text(
              connection.isOnline ? 'Online now' : 'Active today',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialShareRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSocialShareItem(
            context,
            icon: Icons.people,
            label: 'Friends',
            onTap: () => _shareToFriends(context),
          ),
          _buildSocialShareItem(
            context,
            icon: Icons.link,
            label: 'Copy Link',
            onTap: () => _copyLink(context),
          ),
          _buildSocialShareItem(
            context,
            icon: Icons.share,
            label: 'System Share',
            onTap: () => _systemShare(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialShareItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9248D2), Color(0xFF7768DF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              icon,
                color: Colors.white,
                size: 28,
              ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
                color: Colors.white,
              fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUtilityActionsRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildUtilityActionItem(
            context,
            icon: Icons.group_add,
            label: 'Create Group',
            onTap: () => _createGroup(context),
          ),
          _buildUtilityActionItem(
            context,
            icon: Icons.screenshot,
            label: 'Snapshot',
            onTap: () => _takeSnapshot(context),
          ),
          _buildUtilityActionItem(
            context,
            icon: Icons.report,
            label: 'Report',
            onTap: () => _reportContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityActionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Action handlers
  void _shareToFriend(BuildContext context, Connection connection) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing to ${connection.displayName}'),
        backgroundColor: const Color(0xFF9248D2),
        duration: const Duration(seconds: 2),
      ),
    );
    // TODO: Implement actual sharing to friend
  }

  void _shareToFriends(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sharing to multiple friends'),
        backgroundColor: Color(0xFF9248D2),
        duration: Duration(seconds: 2),
      ),
    );
    // TODO: Implement sharing to multiple friends
  }

  void _copyLink(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard'),
        backgroundColor: Color(0xFF9248D2),
        duration: Duration(seconds: 2),
      ),
    );
    // TODO: Implement actual link copying
  }

  void _systemShare(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening system share sheet'),
        backgroundColor: Color(0xFF9248D2),
        duration: Duration(seconds: 2),
      ),
    );
    // TODO: Implement system share
  }

  void _createGroup(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Creating group chat'),
        backgroundColor: Color(0xFF9248D2),
        duration: Duration(seconds: 2),
      ),
    );
    // TODO: Implement group creation
  }

  void _takeSnapshot(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Taking snapshot'),
        backgroundColor: Color(0xFF9248D2),
        duration: Duration(seconds: 2),
      ),
    );
    // TODO: Implement snapshot functionality
  }

  void _reportContent(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reporting content'),
        backgroundColor: Color(0xFF9248D2),
        duration: Duration(seconds: 2),
      ),
    );
    // TODO: Implement content reporting
  }
}