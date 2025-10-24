import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart'; // Required for WidgetsFlutterBinding.ensureInitialized()
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  print('🔍 Checking your uploaded videos...');

  try {
    // Get current user
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      print('❌ No user logged in. Please log in first.');
      return;
    }

    print('👤 Current user: ${currentUser.email} (${currentUser.uid})');

    // Get all videos by current user
    final videosSnapshot = await firestore
        .collection('videos')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .get();

    print('\n📊 Found ${videosSnapshot.docs.length} videos by you');

    if (videosSnapshot.docs.isEmpty) {
      print(
          '❌ No videos found. Make sure you\'re logged in with the correct account.');
      return;
    }

    for (int i = 0; i < videosSnapshot.docs.length; i++) {
      final doc = videosSnapshot.docs[i];
      final data = doc.data();

      print('\n--- Video ${i + 1} ---');
      print('ID: ${doc.id}');
      print('Caption: ${data['caption'] ?? 'No caption'}');
      print('Status: ${data['status'] ?? 'Unknown'}');
      print('Privacy: ${data['privacy'] ?? 'Unknown'}');
      print('Created: ${data['createdAt'] ?? 'Unknown'}');
      print('Category: ${data['category'] ?? 'MISSING ❌'}');
      print('CategoryId: ${data['categoryId'] ?? 'MISSING ❌'}');
      print('Hashtags: ${data['hashtags'] ?? 'None'}');

      // Check if video has category in metadata
      if (data['metadata'] != null && data['metadata']['category'] != null) {
        print('Category in metadata: ${data['metadata']['category']}');
      }

      // Check if video has category in additionalMetadata
      if (data['additionalMetadata'] != null &&
          data['additionalMetadata']['category'] != null) {
        print(
            'Category in additionalMetadata: ${data['additionalMetadata']['category']}');
      }

      // Check if video appears in any category feeds
      print('Checking category feeds...');
      final categories = [
        'gaming',
        'music',
        'art',
        'comedy',
        'dance',
        'sports',
        'tech',
        'food',
        'fashion',
        'fitness'
      ];
      for (final category in categories) {
        try {
          final categoryFeed = await firestore
              .collection('feeds')
              .doc('categories')
              .collection(category)
              .doc(doc.id)
              .get();

          if (categoryFeed.exists) {
            print('  ✅ Found in $category feed');
          }
        } catch (e) {
          // Ignore errors for individual category checks
        }
      }
    }

    // Check if videos appear in main feeds
    print('\n🔍 Checking main feeds...');

    // Check For You feed
    final forYouFeed = await firestore
        .collection('feeds')
        .doc('for_you')
        .collection('videos')
        .where('userId', isEqualTo: currentUser.uid)
        .get();
    print('For You feed: ${forYouFeed.docs.length} videos');

    // Check Following feed
    final followingFeed = await firestore
        .collection('feeds')
        .doc('following')
        .collection('videos')
        .where('userId', isEqualTo: currentUser.uid)
        .get();
    print('Following feed: ${followingFeed.docs.length} videos');
  } catch (e) {
    print('❌ Error checking videos: $e');
  }

  print('\n🔍 Video check completed.');
}
