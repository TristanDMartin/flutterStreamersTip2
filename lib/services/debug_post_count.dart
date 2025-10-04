import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Debug service to diagnose post count issues
class DebugPostCount {
  static final DebugPostCount _instance = DebugPostCount._internal();
  factory DebugPostCount() => _instance;
  DebugPostCount._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Debug current user's post count situation
  Future<void> debugCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('❌ No authenticated user');
      return;
    }

    debugPrint('🔍 DEBUGGING POST COUNT FOR USER: ${user.uid}');
    debugPrint('=' * 50);

    try {
      // 1. Check user document
      debugPrint('1️⃣ Checking user document...');
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final postCount = userData['postCount'] ?? 0;
        debugPrint('   ✅ User document exists');
        debugPrint('   📊 Current postCount: $postCount');
        debugPrint('   📊 User data keys: ${userData.keys.toList()}');
      } else {
        debugPrint('   ❌ User document does not exist!');
        return;
      }

      // 2. Check videos collection
      debugPrint('\n2️⃣ Checking videos collection...');
      final videosSnapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: user.uid)
          .get();

      debugPrint('   📊 Total videos found: ${videosSnapshot.docs.length}');

      if (videosSnapshot.docs.isEmpty) {
        debugPrint('   ⚠️ No videos found for this user');
        return;
      }

      // 3. Analyze each video
      debugPrint('\n3️⃣ Analyzing each video...');
      int countablePosts = 0;
      int totalPosts = videosSnapshot.docs.length;

      for (int i = 0; i < videosSnapshot.docs.length; i++) {
        final doc = videosSnapshot.docs[i];
        final data = doc.data();

        final videoId = doc.id;
        final status = data['status'] as String? ?? 'draft';
        final privacy = data['privacy'] as String? ?? 'private';
        final caption = data['caption'] as String? ?? 'No caption';
        final createdAt = data['createdAt'];

        final shouldCount = _shouldCountPost(status, privacy);
        if (shouldCount) countablePosts++;

        debugPrint('   Video ${i + 1}:');
        debugPrint('     ID: $videoId');
        debugPrint('     Status: $status');
        debugPrint('     Privacy: $privacy');
        debugPrint(
            '     Caption: ${caption.length > 50 ? '${caption.substring(0, 50)}...' : caption}');
        debugPrint('     Created: $createdAt');
        debugPrint('     Should Count: $shouldCount');
        debugPrint('     ---');
      }

      // 4. Summary
      debugPrint('\n4️⃣ SUMMARY:');
      debugPrint('   📊 Total videos: $totalPosts');
      debugPrint('   📊 Countable posts: $countablePosts');
      debugPrint('   📊 Current counter: ${userDoc.data()?['postCount'] ?? 0}');
      debugPrint(
          '   📊 Needs fix: ${countablePosts != (userDoc.data()?['postCount'] ?? 0)}');

      // 5. Try to fix
      if (countablePosts != (userDoc.data()?['postCount'] ?? 0)) {
        debugPrint('\n5️⃣ Attempting to fix...');
        try {
          await _firestore.collection('users').doc(user.uid).update({
            'postCount': countablePosts,
            'lastPostCountReconciliation': FieldValue.serverTimestamp(),
            'debugFixedAt': FieldValue.serverTimestamp(),
          });
          debugPrint('   ✅ Post count updated to: $countablePosts');
        } catch (e) {
          debugPrint('   ❌ Failed to update post count: $e');
        }
      } else {
        debugPrint('   ✅ Post count is already correct!');
      }
    } catch (e) {
      debugPrint('❌ Error during debug: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }

    debugPrint('=' * 50);
    debugPrint('🔍 DEBUG COMPLETE');
  }

  /// Check if a post should be counted
  bool _shouldCountPost(String status, String privacy) {
    const countableStatuses = ['published', 'public'];
    const excludedStatuses = [
      'draft',
      'scheduled',
      'archived',
      'deleted',
      'hidden',
      'moderation',
      'private'
    ];
    const countablePrivacyLevels = ['public', 'followers'];

    final statusLower = status.toLowerCase();
    final privacyLower = privacy.toLowerCase();

    return countableStatuses.contains(statusLower) &&
        !excludedStatuses.contains(statusLower) &&
        countablePrivacyLevels.contains(privacyLower);
  }

  /// Simple fix method
  Future<bool> simpleFix() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      debugPrint('🔧 SIMPLE FIX: Starting...');

      // Count actual posts
      final videosSnapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: user.uid)
          .get();

      int countablePosts = 0;
      for (final doc in videosSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'draft';
        final privacy = data['privacy'] as String? ?? 'private';

        if (_shouldCountPost(status, privacy)) {
          countablePosts++;
        }
      }

      debugPrint('🔧 SIMPLE FIX: Found $countablePosts countable posts');

      // Update counter
      await _firestore.collection('users').doc(user.uid).update({
        'postCount': countablePosts,
        'simpleFixAt': FieldValue.serverTimestamp(),
      });

      debugPrint('🔧 SIMPLE FIX: Updated post count to $countablePosts');
      return true;
    } catch (e) {
      debugPrint('🔧 SIMPLE FIX: Error - $e');
      return false;
    }
  }
}
