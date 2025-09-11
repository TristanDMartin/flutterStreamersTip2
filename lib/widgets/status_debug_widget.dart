import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/status_provider.dart';
import '../models/user_status.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StatusDebugWidget extends ConsumerWidget {
  const StatusDebugWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final statusAsync = ref.watch(statusNotifierProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha:0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Status Debug Info',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // User info
          Text(
            'User: ${user?.uid ?? 'Not authenticated'}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            'Email: ${user?.email ?? 'No email'}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          
          const SizedBox(height: 8),
          
          // Status info
          statusAsync.when(
            data: (presence) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: ${presence.status.value}',
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                ),
                Text(
                  'Display Name: ${presence.status.displayName}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Text(
                  'Last Seen: ${presence.lastSeen?.toString() ?? 'Never'}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Text(
                  'Last Active: ${presence.lastActive?.toString() ?? 'Never'}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
            loading: () => const Text(
              'Status: Loading...',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
            error: (error, stack) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status: Error',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
                Text(
                  'Error: $error',
                  style: const TextStyle(color: Colors.red, fontSize: 10),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Action buttons
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final updateStatus = ref.read(updateStatusProvider);
                  await updateStatus(UserStatus.online);
                },
                child: const Text('Set Online', style: TextStyle(fontSize: 10)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final updateStatus = ref.read(updateStatusProvider);
                  await updateStatus(UserStatus.offline);
                },
                child: const Text('Set Offline', style: TextStyle(fontSize: 10)),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Username mapping info
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha:0.3)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Firebase Console Tracking:',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '• Users: /users/{uid} (main data)',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
                Text(
                  '• Usernames: /usernames/{username} (easy lookup)',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
                Text(
                  '• Status: /users/{uid}/presence/status',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
