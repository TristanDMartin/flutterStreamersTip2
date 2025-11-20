import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'status_button.dart';
import '../providers/status_provider.dart';
import '../models/user_status.dart';

/// Example of how to integrate StatusButton into ProfileView
class ProfileViewWithStatus extends ConsumerWidget {
  const ProfileViewWithStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: const [
          // Status button in app bar
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: StatusButton(showLabel: false, size: 8),
          ),
        ],
      ),
      body: Column(
        children: [
          // Profile header with status
          _buildProfileHeader(ref),
          
          // Other profile content
          const Expanded(
            child: Center(
              child: Text('Profile content goes here'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(WidgetRef ref) {
    final statusAsync = ref.watch(currentUserStatusProvider);
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Avatar
          const CircleAvatar(
            radius: 50,
            child: Icon(Icons.person, size: 50),
          ),
          
          const SizedBox(height: 16),
          
          // Name and status
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'John Doe',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 12),
              // Status button next to name
              StatusButton(showLabel: true),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Status details
          statusAsync.when(
            data: (presence) => Text(
              _getStatusText(presence),
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            loading: () => const Text(
              'Loading status...',
              style: TextStyle(color: Colors.grey),
            ),
            error: (error, stack) => const Text(
              'Status unavailable',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(UserPresence presence) {
    switch (presence.status) {
      case UserStatus.online:
        return 'Active now';
      case UserStatus.offline:
        return 'Last seen ${_formatLastSeen(presence.lastSeen)}';
      case UserStatus.busy:
        return 'Busy';
      case UserStatus.dnd:
        return 'Do not disturb';
      case UserStatus.streaming:
        return 'Live streaming';
    }
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'unknown';
    
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

/// Example of how to integrate status display in StreamerCardView
class StreamerCardWithStatus extends ConsumerWidget {
  final String userId;
  
  const StreamerCardWithStatus({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(userStatusProvider(userId));
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Streamer info with status
            Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  child: Icon(Icons.person),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Streamer Name',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Status indicator
                statusAsync.when(
                  data: (presence) => Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getStatusColor(presence.status),
                      shape: BoxShape.circle,
                    ),
                  ),
                  loading: () => const SizedBox(
                    width: 8,
                    height: 8,
                    child: CircularProgressIndicator(strokeWidth: 1),
                  ),
                  error: (error, stack) => Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Status text
            statusAsync.when(
              data: (presence) => Text(
                _getStatusText(presence),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              loading: () => const Text(
                'Loading...',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              error: (error, stack) => const Text(
                'Status unavailable',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return const Color(0xFF4CAF50); // Green
      case UserStatus.offline:
        return const Color(0xFF9E9E9E); // Grey
      case UserStatus.busy:
        return const Color(0xFFFF9800); // Orange
      case UserStatus.dnd:
        return const Color(0xFFF44336); // Red
      case UserStatus.streaming:
        return const Color(0xFF9C27B0); // Purple
    }
  }

  String _getStatusText(UserPresence presence) {
    switch (presence.status) {
      case UserStatus.online:
        return 'Online';
      case UserStatus.offline:
        return 'Offline';
      case UserStatus.busy:
        return 'Busy';
      case UserStatus.dnd:
        return 'Do not disturb';
      case UserStatus.streaming:
        return 'Live streaming';
    }
  }
}
