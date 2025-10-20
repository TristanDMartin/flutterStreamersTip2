import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Migration script to add creatorId and creator_id fields to existing videos
/// that only have userId field
Future<void> main() async {
  print('🔄 Starting video creator field migration...');

  // Initialize Firebase
  await Firebase.initializeApp();
  final firestore = FirebaseFirestore.instance;

  try {
    // Get all videos
    final videosSnapshot = await firestore.collection('videos').get();

    print('📊 Found ${videosSnapshot.docs.length} videos to process');

    int updatedCount = 0;
    int skippedCount = 0;
    int errorCount = 0;

    for (final doc in videosSnapshot.docs) {
      final data = doc.data();
      final videoId = doc.id;

      // Check if video already has all three fields
      final hasUserId = data.containsKey('userId');
      final hasCreatorId = data.containsKey('creatorId');
      final hasCreatorIdSnake = data.containsKey('creator_id');

      if (hasUserId && hasCreatorId && hasCreatorIdSnake) {
        print('✅ Video $videoId already has all creator fields, skipping');
        skippedCount++;
        continue;
      }

      // Get the userId value (could be in any of the three fields)
      final userId = (data['userId'] ?? data['creatorId'] ?? data['creator_id'])
          as String?;

      if (userId == null || userId.isEmpty) {
        print('⚠️  Video $videoId has no valid creator ID, skipping');
        errorCount++;
        continue;
      }

      // Update the document with all three field variants
      try {
        final updateData = <String, dynamic>{};

        if (!hasUserId) {
          updateData['userId'] = userId;
        }
        if (!hasCreatorId) {
          updateData['creatorId'] = userId;
        }
        if (!hasCreatorIdSnake) {
          updateData['creator_id'] = userId;
        }

        if (updateData.isNotEmpty) {
          await firestore.collection('videos').doc(videoId).update(updateData);

          print('✅ Updated video $videoId: ${updateData.keys.join(', ')}');
          updatedCount++;
        }
      } catch (e) {
        print('❌ Error updating video $videoId: $e');
        errorCount++;
      }
    }

    print('');
    print('✅ Migration complete!');
    print('📊 Statistics:');
    print('   - Updated: $updatedCount videos');
    print('   - Skipped: $skippedCount videos');
    print('   - Errors: $errorCount videos');
    print('   - Total processed: ${videosSnapshot.docs.length} videos');
  } catch (e) {
    print('❌ Migration failed: $e');
    rethrow;
  }
}
