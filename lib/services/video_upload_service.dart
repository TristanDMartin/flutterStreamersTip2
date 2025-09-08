import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'video_moderation_service.dart';
import 'enhanced_error_handling_service.dart';

class VideoUploadResult {
  final bool success;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? error;
  final Map<String, dynamic>? metadata;

  const VideoUploadResult({
    required this.success,
    this.videoUrl,
    this.thumbnailUrl,
    this.error,
    this.metadata,
  });
}

class VideoUploadService {
  static final VideoUploadService _instance = VideoUploadService._internal();
  factory VideoUploadService() => _instance;
  VideoUploadService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final VideoModerationService _moderationService = VideoModerationService();
  final EnhancedErrorHandlingService _errorHandler = EnhancedErrorHandlingService();

  /// Upload video with comprehensive moderation checks
  Future<VideoUploadResult> uploadVideo({
    required File videoFile,
    required String caption,
    required List<String> hashtags,
    required String privacy,
    required bool allowComments,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    try {
      // 1. Pre-upload moderation check
      print('🔍 Starting video moderation...');
      final moderationResult = await _moderationService.moderateVideo(
        videoFile: videoFile,
        caption: caption,
        hashtags: hashtags,
        metadata: additionalMetadata,
      );

      if (!moderationResult.isApproved) {
        print('❌ Video rejected by moderation: ${moderationResult.reason}');
        return VideoUploadResult(
          success: false,
          error: 'Content rejected: ${moderationResult.reason}',
          metadata: {
            'moderation_result': {
              'approved': false,
              'violations': moderationResult.violations,
              'reason': moderationResult.reason,
              'confidence': moderationResult.confidence,
            }
          },
        );
      }

      print('✅ Video passed moderation checks');

      // 2. Get current user
      final user = _auth.currentUser;
      if (user == null) {
        return VideoUploadResult(
          success: false,
          error: 'User not authenticated',
        );
      }

      // 3. Generate unique video ID
      final videoId = _generateVideoId();
      final userId = user.uid;

      // 4. Upload video to Firebase Storage
      print('📤 Uploading video to storage...');
      final videoUrl = await _uploadVideoFile(videoFile, videoId, userId);
      if (videoUrl == null) {
        return VideoUploadResult(
          success: false,
          error: 'Failed to upload video file',
        );
      }

      // 5. Generate and upload thumbnail
      print('🖼️ Generating thumbnail...');
      final thumbnailUrl = await _generateAndUploadThumbnail(videoFile, videoId, userId);

      // 6. Create video document in Firestore
      print('💾 Saving video metadata to Firestore...');
      final videoData = {
        'id': videoId,
        'userId': userId,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'caption': caption,
        'hashtags': hashtags,
        'privacy': privacy,
        'allowComments': allowComments,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'published',
        'views': 0,
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'moderation': {
          'approved': true,
          'checkedAt': FieldValue.serverTimestamp(),
          'confidence': moderationResult.confidence,
          'violations': [],
        },
        'metadata': {
          'fileSize': await videoFile.length(),
          'duration': 30.0, // Placeholder - would get from video processing
          'resolution': '1080x1920', // Placeholder
          'format': 'mp4',
          'uploadedAt': FieldValue.serverTimestamp(),
        },
        ...?additionalMetadata,
      };

      await _firestore
          .collection('videos')
          .doc(videoId)
          .set(videoData);

      // 7. Update user's video count
      await _updateUserVideoCount(userId);

      // 8. Add to user's profile videos
      await _addToUserProfile(userId, videoId);

      // 9. Add to appropriate feeds based on privacy
      await _addToFeeds(videoId, privacy, userId);

      print('✅ Video uploaded successfully!');
      return VideoUploadResult(
        success: true,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        metadata: {
          'videoId': videoId,
          'moderation_result': {
            'approved': true,
            'confidence': moderationResult.confidence,
            'violations': [],
          }
        },
      );

    } catch (e) {
      await _errorHandler.handleUploadError(
        operation: 'video_upload',
        error: e,
        context: {
          'file_size': await videoFile.length(),
          'caption_length': caption.length,
          'hashtags_count': hashtags.length,
          'privacy': privacy,
        },
      );
      print('❌ Video upload failed: $e');
      return VideoUploadResult(
        success: false,
        error: 'Upload failed: ${e.toString()}',
      );
    }
  }

  /// Save video as draft (bypasses moderation)
  Future<VideoUploadResult> saveAsDraft({
    required File videoFile,
    required String caption,
    required List<String> hashtags,
    required String privacy,
    required bool allowComments,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return VideoUploadResult(
          success: false,
          error: 'User not authenticated',
        );
      }

      final videoId = _generateVideoId();
      final userId = user.uid;

      // Upload video file
      final videoUrl = await _uploadVideoFile(videoFile, videoId, userId);
      if (videoUrl == null) {
        return VideoUploadResult(
          success: false,
          error: 'Failed to upload video file',
        );
      }

      // Generate thumbnail
      final thumbnailUrl = await _generateAndUploadThumbnail(videoFile, videoId, userId);

      // Save as draft
      final videoData = {
        'id': videoId,
        'userId': userId,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'caption': caption,
        'hashtags': hashtags,
        'privacy': privacy,
        'allowComments': allowComments,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'draft',
        'views': 0,
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'moderation': {
          'approved': false,
          'checkedAt': null,
          'confidence': 0.0,
          'violations': [],
        },
        'metadata': {
          'fileSize': await videoFile.length(),
          'duration': 30.0,
          'resolution': '1080x1920',
          'format': 'mp4',
          'uploadedAt': FieldValue.serverTimestamp(),
        },
        ...?additionalMetadata,
      };

      await _firestore
          .collection('videos')
          .doc(videoId)
          .set(videoData);

      // Add to user's drafts
      await _addToUserDrafts(userId, videoId);

      return VideoUploadResult(
        success: true,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        metadata: {'videoId': videoId, 'status': 'draft'},
      );

    } catch (e) {
      return VideoUploadResult(
        success: false,
        error: 'Draft save failed: ${e.toString()}',
      );
    }
  }

  /// Upload video file to Firebase Storage
  Future<String?> _uploadVideoFile(File videoFile, String videoId, String userId) async {
    try {
      final ref = _storage
          .ref()
          .child('videos')
          .child(userId)
          .child('$videoId.mp4');

      final uploadTask = ref.putFile(videoFile);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      await _errorHandler.handleUploadError(
        operation: 'video_file_upload',
        error: e,
        context: {
          'video_id': videoId,
          'user_id': userId,
          'file_size': await videoFile.length(),
        },
      );
      print('Error uploading video file: $e');
      return null;
    }
  }

  /// Generate and upload thumbnail
  Future<String?> _generateAndUploadThumbnail(File videoFile, String videoId, String userId) async {
    try {
      // This would use a video processing library to generate thumbnail
      // For now, return a placeholder
      return 'https://via.placeholder.com/300x400/9248D2/FFFFFF?text=Thumbnail';
    } catch (e) {
      print('Error generating thumbnail: $e');
      return null;
    }
  }

  /// Update user's video count
  Future<void> _updateUserVideoCount(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'videoCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user video count: $e');
    }
  }

  /// Add video to user's profile
  Future<void> _addToUserProfile(String userId, String videoId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('videos')
          .doc(videoId)
          .set({
        'videoId': videoId,
        'addedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding to user profile: $e');
    }
  }

  /// Add video to user's drafts
  Future<void> _addToUserDrafts(String userId, String videoId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('drafts')
          .doc(videoId)
          .set({
        'videoId': videoId,
        'addedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding to user drafts: $e');
    }
  }

  /// Add video to appropriate feeds
  Future<void> _addToFeeds(String videoId, String privacy, String userId) async {
    try {
      if (privacy == 'Everyone') {
        // Add to public feeds
        await _firestore
            .collection('feeds')
            .doc('for_you')
            .collection('videos')
            .doc(videoId)
            .set({
          'videoId': videoId,
          'userId': userId,
          'addedAt': FieldValue.serverTimestamp(),
        });
      }

      // Add to following feed for connections
      await _firestore
          .collection('feeds')
          .doc('following')
          .collection('videos')
          .doc(videoId)
          .set({
        'videoId': videoId,
        'userId': userId,
        'addedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding to feeds: $e');
    }
  }

  /// Generate unique video ID
  String _generateVideoId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        '_' +
        (1000 + (9999 - 1000) * (DateTime.now().microsecond / 1000000)).round().toString();
  }

  /// Get user's videos
  Future<List<Map<String, dynamic>>> getUserVideos(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting user videos: $e');
      return [];
    }
  }

  /// Get user's drafts
  Future<List<Map<String, dynamic>>> getUserDrafts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'draft')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting user drafts: $e');
      return [];
    }
  }

  /// Publish draft video
  Future<VideoUploadResult> publishDraft(String videoId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return VideoUploadResult(
          success: false,
          error: 'User not authenticated',
        );
      }

      // Get draft video
      final doc = await _firestore.collection('videos').doc(videoId).get();
      if (!doc.exists) {
        return VideoUploadResult(
          success: false,
          error: 'Draft not found',
        );
      }

      final videoData = doc.data()!;
      final videoFile = File(videoData['videoUrl']); // This would need proper file handling

      // Re-run moderation
      final moderationResult = await _moderationService.moderateVideo(
        videoFile: videoFile,
        caption: videoData['caption'],
        hashtags: List<String>.from(videoData['hashtags'] ?? []),
        metadata: videoData['metadata'],
      );

      if (!moderationResult.isApproved) {
        return VideoUploadResult(
          success: false,
          error: 'Content rejected: ${moderationResult.reason}',
        );
      }

      // Update video status
      await _firestore.collection('videos').doc(videoId).update({
        'status': 'published',
        'moderation': {
          'approved': true,
          'checkedAt': FieldValue.serverTimestamp(),
          'confidence': moderationResult.confidence,
          'violations': [],
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add to feeds
      await _addToFeeds(videoId, videoData['privacy'], user.uid);

      return VideoUploadResult(
        success: true,
        videoUrl: videoData['videoUrl'],
        thumbnailUrl: videoData['thumbnailUrl'],
        metadata: {'videoId': videoId, 'status': 'published'},
      );

    } catch (e) {
      return VideoUploadResult(
        success: false,
        error: 'Publish failed: ${e.toString()}',
      );
    }
  }
}