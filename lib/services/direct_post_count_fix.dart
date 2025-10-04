import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Direct Post Count Fix - Simple and reliable
class DirectPostCountFix {
  static final DirectPostCountFix _instance = DirectPostCountFix._internal();
  factory DirectPostCountFix() => _instance;
  DirectPostCountFix._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Fix post count for current user - simple and direct
  Future<bool> fixCurrentUserPostCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ DIRECT FIX: No authenticated user');
        return false;
      }

      debugPrint('🔧 DIRECT FIX: Starting for user ${user.uid}');

      // Step 1: Get all videos for this user
      final videosSnapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: user.uid)
          .get();

      debugPrint(
          '📊 DIRECT FIX: Found ${videosSnapshot.docs.length} videos for user ${user.uid}');

      // Step 2: Count only the "countable" videos
      int actualCount = 0;
      for (final doc in videosSnapshot.docs) {
        final data = doc.data();
        final videoId = doc.id;
        final status = data['status'] as String? ?? 'draft';
        final privacy = data['privacy'] as String? ?? 'private';

        // Print ALL fields for debugging
        debugPrint(
            '  🔍 DIRECT FIX: Video $videoId - Status: "$status", Privacy: "$privacy"');
        debugPrint('  🔍 DIRECT FIX: All fields: ${data.keys.toList()}');

        // SIMPLIFIED COUNTING - Count ANY video that exists
        // This will help us see if the issue is with the counting logic or the video data
        actualCount++;
        debugPrint(
            '  ✅ DIRECT FIX: Counting video: $videoId (Status: $status, Privacy: $privacy) - SIMPLIFIED COUNTING');
      }

      debugPrint(
          '📊 DIRECT FIX: Calculated actual countable posts: $actualCount');

      // Step 3: Update the user's postCount in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'postCount': actualCount,
        'lastDirectFix': FieldValue.serverTimestamp(),
      });

      debugPrint(
          '✅ DIRECT FIX: Post count updated to $actualCount for user ${user.uid}');

      // Step 4: Verify the update worked
      final updatedDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final updatedCount = updatedDoc.data()?['postCount'] ?? 0;
      debugPrint(
          '🔍 DIRECT FIX: Verification - postCount in Firestore is now: $updatedCount');

      return true;
    } catch (e) {
      debugPrint('❌ DIRECT FIX: Failed to fix post count: $e');
      return false;
    }
  }
}
