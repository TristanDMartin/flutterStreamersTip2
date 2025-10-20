import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/follows_provider.dart';

/// Quick test widget to verify follow/unfollow functionality
class FollowTestWidget extends ConsumerWidget {
  final String targetUserId;

  const FollowTestWidget({
    super.key,
    required this.targetUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Follow Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Testing follow/unfollow for user: $targetUserId'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _testFollow(ref),
              child: const Text('Test Follow'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _testUnfollow(ref),
              child: const Text('Test Unfollow'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _testNotifications(context),
              child: const Text('Check Notifications'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _fixUserFields(),
              child: const Text('Fix User Fields'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testFollow(WidgetRef ref) async {
    try {
      final followsService = ref.read(followsServiceProvider);
      final success = await followsService.followUser(targetUserId);

      if (success) {
        debugPrint('✅ Follow test: SUCCESS');
        _showSnackBar('Follow successful!');
      } else {
        debugPrint('❌ Follow test: FAILED');
        _showSnackBar('Follow failed!');
      }
    } catch (e) {
      debugPrint('❌ Follow test error: $e');
      _showSnackBar('Follow error: $e');
    }
  }

  Future<void> _testUnfollow(WidgetRef ref) async {
    try {
      final followsService = ref.read(followsServiceProvider);
      final success = await followsService.unfollowUser(targetUserId);

      if (success) {
        debugPrint('✅ Unfollow test: SUCCESS');
        _showSnackBar('Unfollow successful!');
      } else {
        debugPrint('❌ Unfollow test: FAILED');
        _showSnackBar('Unfollow failed!');
      }
    } catch (e) {
      debugPrint('❌ Unfollow test error: $e');
      _showSnackBar('Unfollow error: $e');
    }
  }

  Future<void> _testNotifications(BuildContext context) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showSnackBar('Not logged in');
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(currentUser.uid)
          .collection('items')
          .limit(5)
          .get();

      debugPrint('📱 Notifications count: ${snapshot.docs.length}');
      _showSnackBar('Found ${snapshot.docs.length} notifications');

      for (final doc in snapshot.docs) {
        final data = doc.data();
        debugPrint(
            '📱 Notification: ${data['type']} - ${data['user']?['displayName']}');
      }
    } catch (e) {
      debugPrint('❌ Notifications test error: $e');
      _showSnackBar('Notifications error: $e');
    }
  }

  Future<void> _fixUserFields() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showSnackBar('Not logged in');
        return;
      }

      // Fix current user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set({
        'followingCount': 0,
        'followersCount': 0,
        'connectionsCount': 0,
      }, SetOptions(merge: true));

      // Fix target user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .set({
        'followingCount': 0,
        'followersCount': 0,
        'connectionsCount': 0,
      }, SetOptions(merge: true));

      debugPrint('✅ User fields fixed');
      _showSnackBar('User fields fixed!');
    } catch (e) {
      debugPrint('❌ Fix fields error: $e');
      _showSnackBar('Fix fields error: $e');
    }
  }

  void _showSnackBar(String message) {
    // This would need a BuildContext, but for testing we'll just print
    debugPrint('📱 SnackBar: $message');
  }
}
