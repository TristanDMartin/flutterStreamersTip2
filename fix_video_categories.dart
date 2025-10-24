import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart'; // Required for WidgetsFlutterBinding.ensureInitialized()

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;

  print('🔍 Fixing video categories...');

  try {
    // Get all videos without category field
    final videosSnapshot = await firestore
        .collection('videos')
        .where('status', isEqualTo: 'published')
        .get();

    print('📊 Found ${videosSnapshot.docs.length} published videos');

    int fixedCount = 0;
    int alreadyFixedCount = 0;

    for (final doc in videosSnapshot.docs) {
      final data = doc.data();

      // Check if video already has category field
      if (data['category'] != null || data['categoryId'] != null) {
        alreadyFixedCount++;
        continue;
      }

      // Try to determine category from metadata or set default
      String category = 'gaming'; // Default category

      // Check if category is in metadata
      if (data['metadata'] != null && data['metadata']['category'] != null) {
        category = data['metadata']['category'] as String;
      }
      // Check if category is in additionalMetadata
      else if (data['additionalMetadata'] != null &&
          data['additionalMetadata']['category'] != null) {
        category = data['additionalMetadata']['category'] as String;
      }
      // Check hashtags for category hints
      else if (data['hashtags'] != null) {
        final hashtags = List<String>.from(data['hashtags'] ?? []);
        category = _determineCategoryFromHashtags(hashtags);
      }
      // Check caption for category hints
      else if (data['caption'] != null) {
        final caption = data['caption'] as String;
        category = _determineCategoryFromCaption(caption);
      }

      // Update the video document with category field
      await doc.reference.update({
        'category': category,
        'categoryId': category, // Alternative field name for compatibility
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print(
          '✅ Fixed video "${data['caption'] ?? 'Untitled'}" -> Category: $category');
      fixedCount++;
    }

    print('\n📊 Summary:');
    print('   - Total videos: ${videosSnapshot.docs.length}');
    print('   - Already had category: $alreadyFixedCount');
    print('   - Fixed: $fixedCount');
    print(
        '   - Remaining: ${videosSnapshot.docs.length - alreadyFixedCount - fixedCount}');
  } catch (e) {
    print('❌ Error fixing video categories: $e');
  }

  print('\n🔍 Video category fix completed.');
}

/// Determine category from hashtags
String _determineCategoryFromHashtags(List<String> hashtags) {
  final categoryKeywords = {
    'gaming': [
      'gaming',
      'game',
      'play',
      'stream',
      'twitch',
      'youtube',
      'gamer'
    ],
    'music': ['music', 'song', 'sing', 'dance', 'beat', 'melody', 'concert'],
    'art': ['art', 'draw', 'paint', 'sketch', 'design', 'creative', 'artist'],
    'comedy': ['comedy', 'funny', 'joke', 'laugh', 'humor', 'meme', 'comic'],
    'dance': ['dance', 'dancing', 'choreo', 'moves', 'rhythm', 'step'],
    'sports': ['sport', 'fitness', 'gym', 'workout', 'run', 'bike', 'football'],
    'tech': ['tech', 'technology', 'coding', 'programming', 'software', 'app'],
    'food': ['food', 'cooking', 'recipe', 'eat', 'meal', 'kitchen', 'chef'],
    'fashion': ['fashion', 'style', 'outfit', 'clothes', 'dress', 'shoes'],
    'fitness': ['fitness', 'gym', 'workout', 'exercise', 'health', 'body'],
  };

  for (final category in categoryKeywords.keys) {
    for (final keyword in categoryKeywords[category]!) {
      if (hashtags.any((tag) => tag.toLowerCase().contains(keyword))) {
        return category;
      }
    }
  }

  return 'gaming'; // Default fallback
}

/// Determine category from caption
String _determineCategoryFromCaption(String caption) {
  final categoryKeywords = {
    'gaming': [
      'gaming',
      'game',
      'play',
      'stream',
      'twitch',
      'youtube',
      'gamer'
    ],
    'music': ['music', 'song', 'sing', 'dance', 'beat', 'melody', 'concert'],
    'art': ['art', 'draw', 'paint', 'sketch', 'design', 'creative', 'artist'],
    'comedy': ['comedy', 'funny', 'joke', 'laugh', 'humor', 'meme', 'comic'],
    'dance': ['dance', 'dancing', 'choreo', 'moves', 'rhythm', 'step'],
    'sports': ['sport', 'fitness', 'gym', 'workout', 'run', 'bike', 'football'],
    'tech': ['tech', 'technology', 'coding', 'programming', 'software', 'app'],
    'food': ['food', 'cooking', 'recipe', 'eat', 'meal', 'kitchen', 'chef'],
    'fashion': ['fashion', 'style', 'outfit', 'clothes', 'dress', 'shoes'],
    'fitness': ['fitness', 'gym', 'workout', 'exercise', 'health', 'body'],
  };

  final lowerCaption = caption.toLowerCase();

  for (final category in categoryKeywords.keys) {
    for (final keyword in categoryKeywords[category]!) {
      if (lowerCaption.contains(keyword)) {
        return category;
      }
    }
  }

  return 'gaming'; // Default fallback
}
