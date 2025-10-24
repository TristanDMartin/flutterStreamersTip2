import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

/// Script to check Smove50's videos and their field names
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;

  print('🔍 Checking Smove50\'s videos in database...');

  try {
    // First, find Smove50's user ID
    final userQuery = await firestore
        .collection('users')
        .where('username', isEqualTo: 'smove50')
        .limit(1)
        .get();

    if (userQuery.docs.isEmpty) {
      print('❌ Smove50 user not found');
      return;
    }

    final smove50Doc = userQuery.docs.first;
    final smove50Id = smove50Doc.id;
    final smove50Data = smove50Doc.data();

    print('✅ Found Smove50 user:');
    print('   - Document ID: $smove50Id');
    print('   - Username: ${smove50Data['username']}');
    print('   - Display Name: ${smove50Data['displayName']}');
    print('   - ID field: ${smove50Data['id']}');

    // Now check for videos by this user
    print('\n🔍 Checking videos by Smove50...');

    // Try different field names
    final fieldNames = ['userId', 'creatorId', 'creator_id'];

    for (final fieldName in fieldNames) {
      print('\n📋 Checking videos with $fieldName field...');

      try {
        final videosQuery = await firestore
            .collection('videos')
            .where(fieldName, isEqualTo: smove50Id)
            .limit(5)
            .get();

        print(
            '   Found ${videosQuery.docs.length} videos with $fieldName field');

        for (final doc in videosQuery.docs) {
          final data = doc.data();
          print('   - Video ID: ${doc.id}');
          print('     - userId: ${data['userId']}');
          print('     - creatorId: ${data['creatorId']}');
          print('     - creator_id: ${data['creator_id']}');
          print('     - videoUrl: ${data['videoUrl'] ?? data['videoURL']}');
          print('     - caption: ${data['caption']}');
          print('     - createdAt: ${data['createdAt']}');
        }
      } catch (e) {
        print('   ❌ Error querying with $fieldName: $e');
      }
    }

    // Also check if there are any videos that might be Smove50's by username
    print('\n🔍 Checking videos by username match...');

    try {
      final videosByUsername = await firestore
          .collection('videos')
          .where('creatorUsername', isEqualTo: 'smove50')
          .limit(5)
          .get();

      print(
          '   Found ${videosByUsername.docs.length} videos with creatorUsername=smove50');

      for (final doc in videosByUsername.docs) {
        final data = doc.data();
        print('   - Video ID: ${doc.id}');
        print('     - userId: ${data['userId']}');
        print('     - creatorId: ${data['creatorId']}');
        print('     - creator_id: ${data['creator_id']}');
        print('     - creatorUsername: ${data['creatorUsername']}');
        print('     - videoUrl: ${data['videoUrl'] ?? data['videoURL']}');
      }
    } catch (e) {
      print('   ❌ Error querying by username: $e');
    }

    // Check total videos in database
    print('\n📊 Database overview...');
    final allVideos = await firestore.collection('videos').limit(10).get();
    print(
        '   Total videos in database: ${allVideos.docs.length} (showing first 10)');

    for (final doc in allVideos.docs) {
      final data = doc.data();
      print('   - Video ID: ${doc.id}');
      print('     - userId: ${data['userId']}');
      print('     - creatorId: ${data['creatorId']}');
      print('     - creator_id: ${data['creator_id']}');
      print('     - creatorUsername: ${data['creatorUsername']}');
    }
  } catch (e) {
    print('❌ Error checking Smove50 videos: $e');
  }

  print('\n✅ Check complete!');
}
