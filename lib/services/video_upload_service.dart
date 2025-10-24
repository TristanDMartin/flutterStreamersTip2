import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'video_moderation_service.dart';
import 'enhanced_error_handling_service.dart';
import 'video_processing_service.dart';
import 'logging_service.dart';
import 'tag_mention_service.dart';
import 'post_counter_service.dart';

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
  final EnhancedErrorHandlingService _errorHandler =
      EnhancedErrorHandlingService();
  final TagMentionService _tagMentionService = TagMentionService();

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
      debugPrint('🚀 Starting video upload process...');

      // 0. Validate file exists and is readable
      if (!await videoFile.exists()) {
        return const VideoUploadResult(
          success: false,
          error: 'Video file not found',
        );
      }

      final fileSize = await videoFile.length();
      debugPrint(
          '📁 Video file size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // 1. Pre-upload moderation check
      debugPrint('🔍 Starting video moderation...');
      final moderationResult = await _moderationService.moderateVideo(
        videoFile: videoFile,
        caption: caption,
        hashtags: hashtags,
        metadata: additionalMetadata,
      );

      if (!moderationResult.isApproved) {
        debugPrint(
            '❌ Video rejected by moderation: ${moderationResult.reason}');
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

      debugPrint('✅ Video passed moderation checks');

      // 2. Get current user
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ VideoUploadService: User not authenticated');
        return const VideoUploadResult(
          success: false,
          error: 'User not authenticated',
        );
      }

      debugPrint('✅ VideoUploadService: User authenticated - UID: ${user.uid}');
      debugPrint('✅ VideoUploadService: User email: ${user.email}');

      // Force refresh auth token
      try {
        final idToken = await user.getIdToken(true);
        debugPrint(
            '✅ VideoUploadService: Auth token refreshed - Length: ${idToken?.length ?? 0}');
      } catch (e) {
        debugPrint('❌ VideoUploadService: Failed to refresh auth token: $e');
        return VideoUploadResult(
          success: false,
          error: 'Authentication token refresh failed: $e',
        );
      }

      // 3. Generate unique video ID
      final videoId = _generateVideoId();
      final userId = user.uid;
      debugPrint('🎬 Generated video ID: $videoId');

      // 4. Upload video to Firebase Storage
      debugPrint('📤 Uploading video to storage...');
      final videoUrl = await _uploadVideoFile(videoFile, videoId, userId);
      if (videoUrl == null) {
        debugPrint('❌ Failed to upload video file to storage');
        return const VideoUploadResult(
          success: false,
          error: 'Failed to upload video file to storage',
        );
      }
      debugPrint('✅ Video uploaded successfully: $videoUrl');

      // 5. Generate and upload thumbnail
      debugPrint('🖼️ Generating thumbnail...');
      String? thumbnailUrl;
      try {
        thumbnailUrl =
            await _generateAndUploadThumbnail(videoFile, videoId, userId);
        debugPrint('✅ Thumbnail generated: $thumbnailUrl');
      } catch (e) {
        debugPrint('❌ Thumbnail generation failed: $e');
        return VideoUploadResult(
          success: false,
          error: 'Failed to generate thumbnail: ${e.toString()}',
        );
      }

      if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
        debugPrint('❌ Thumbnail URL is null or empty');
        return const VideoUploadResult(
          success: false,
          error: 'Failed to generate thumbnail - no URL returned',
        );
      }

      // Create VideoThumbnails object for new format
      final thumbnails = {
        'urls': {
          '360': thumbnailUrl,
          '540': thumbnailUrl,
          '720': thumbnailUrl,
        },
        'generatedAt': FieldValue.serverTimestamp(),
      };

      // 6. Create video document in Firestore
      debugPrint('💾 Saving video metadata to Firestore...');

      // Extract category from additionalMetadata
      final category = additionalMetadata?['category'] as String? ?? 'General';

      debugPrint('🔥 VideoUploadService: Category extracted: $category');
      debugPrint(
          '🔥 VideoUploadService: Additional metadata: $additionalMetadata');
      debugPrint('🔥 VideoUploadService: User UID: $userId');
      debugPrint('🔥 VideoUploadService: Auth UID: ${user.uid}');
      debugPrint('🔥 VideoUploadService: UIDs match: ${userId == user.uid}');

      final videoData = {
        'id': videoId,
        'userId': userId,
        'creatorId': userId, // Add for web/cross-platform compatibility
        'creator_id': userId, // Snake case variant for website compatibility
        'videoUrl': videoUrl,
        'thumbnailUrl':
            thumbnailUrl, // Keep legacy field for backward compatibility
        'thumbnails': thumbnails, // New format for multiple sizes
        'caption': caption,
        'hashtags': hashtags,
        'privacy': privacy,
        'allowComments': allowComments,
        'category':
            category, // 🔥 FIX: Add category field directly to video document
        'categoryId': category, // Alternative field name for compatibility
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
          'fileSize': fileSize,
          'duration': 30.0, // Placeholder - would get from video processing
          'resolution': '1080x1920', // Placeholder
          'format': 'mp4',
          'uploadedAt': FieldValue.serverTimestamp(),
        },
        ...?additionalMetadata,
      };

      try {
        debugPrint(
            '🔥 VideoUploadService: Attempting to save video document to Firestore...');
        debugPrint('🔥 VideoUploadService: Video ID: $videoId');
        debugPrint('🔥 VideoUploadService: User ID: $userId');
        debugPrint(
            '🔥 VideoUploadService: Video data keys: ${videoData.keys.toList()}');
        debugPrint(
            '🔥 VideoUploadService: Video data values: ${videoData.values.map((v) => v.toString()).toList()}');

        await _firestore.collection('videos').doc(videoId).set(videoData);
        debugPrint(
            '✅ VideoUploadService: Video document saved to Firestore successfully');
      } catch (e) {
        debugPrint('❌ VideoUploadService: Failed to save video document: $e');
        debugPrint('❌ VideoUploadService: Error type: ${e.runtimeType}');
        debugPrint('❌ VideoUploadService: Error details: ${e.toString()}');
        return VideoUploadResult(
          success: false,
          error: 'Failed to save video metadata: ${e.toString()}',
        );
      }

      // 7. Update user's video count
      try {
        await _updateUserVideoCount(userId);
        debugPrint('✅ User video count updated');
      } catch (e) {
        debugPrint('⚠️ Failed to update user video count: $e');
        // Continue anyway, this is not critical
      }

      // 7.5. Update PostCounterService for accurate post count
      try {
        final postCounterService = PostCounterService();
        await postCounterService.incrementPostCount(userId, postId: videoId);
        debugPrint('✅ PostCounterService updated for published video');
      } catch (e) {
        debugPrint('⚠️ Failed to update PostCounterService: $e');
        // Continue anyway, this is not critical
      }

      // 8. Add to user's profile videos
      try {
        await _addToUserProfile(userId, videoId);
        debugPrint('✅ Video added to user profile');
      } catch (e) {
        debugPrint('⚠️ Failed to add video to user profile: $e');
        // Continue anyway, this is not critical
      }

      // 9. Add to appropriate feeds based on privacy and category
      try {
        final category = additionalMetadata?['category'] as String?;
        await _addToFeeds(videoId, privacy, userId, category: category);
        debugPrint('✅ Video added to feeds');
      } catch (e) {
        debugPrint('⚠️ Failed to add video to feeds: $e');
        // Continue anyway, this is not critical
      }

      // 10. Process tags and mentions from caption
      try {
        debugPrint('🏷️ Processing tags and mentions from caption...');
        await _tagMentionService.processVideoTagsAndMentions(
          videoId: videoId,
          videoOwnerId: userId,
          caption: caption,
          postThumbnailUrl: thumbnailUrl,
        );
        debugPrint('✅ Tags and mentions processed');
      } catch (e) {
        debugPrint('⚠️ Failed to process tags and mentions: $e');
        // Continue anyway, this is not critical
      }

      debugPrint('🎉 Video uploaded successfully!');
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
      debugPrint('❌ Video upload failed with exception: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');

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

      // Provide more specific error messages based on the error type
      String errorMessage = 'Upload failed: ${e.toString()}';
      if (e.toString().contains('permission-denied')) {
        errorMessage = 'Permission denied. Please check your account status.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('storage')) {
        errorMessage = 'Storage error. Please try again.';
      } else if (e.toString().contains('firestore')) {
        errorMessage = 'Database error. Please try again.';
      }

      return VideoUploadResult(
        success: false,
        error: errorMessage,
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
        return const VideoUploadResult(
          success: false,
          error: 'User not authenticated',
        );
      }

      final videoId = _generateVideoId();
      final userId = user.uid;

      // Upload video file
      final videoUrl = await _uploadVideoFile(videoFile, videoId, userId);
      if (videoUrl == null) {
        return const VideoUploadResult(
          success: false,
          error: 'Failed to upload video file',
        );
      }

      // Generate thumbnail
      final thumbnailUrl =
          await _generateAndUploadThumbnail(videoFile, videoId, userId);

      // Save as draft
      // Extract category from additionalMetadata
      final category = additionalMetadata?['category'] as String?;

      final videoData = {
        'id': videoId,
        'userId': userId,
        'creatorId': userId, // Add for web/cross-platform compatibility
        'creator_id': userId, // Snake case variant for website compatibility
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'caption': caption,
        'hashtags': hashtags,
        'privacy': privacy,
        'allowComments': allowComments,
        'category':
            category, // 🔥 FIX: Add category field directly to video document
        'categoryId': category, // Alternative field name for compatibility
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

      await _firestore.collection('videos').doc(videoId).set(videoData);

      // Add to user's drafts and profile
      await _addToUserDrafts(userId, videoId);
      await _addToUserProfile(userId, videoId);

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
  Future<String?> _uploadVideoFile(
      File videoFile, String videoId, String userId) async {
    try {
      debugPrint('📁 Uploading file: ${videoFile.path}');
      debugPrint(
          '📁 File size: ${(await videoFile.length() / 1024 / 1024).toStringAsFixed(2)} MB');

      final ref =
          _storage.ref().child('videos').child(userId).child('$videoId.mp4');

      debugPrint('📁 Storage path: ${ref.fullPath}');

      final uploadTask = ref.putFile(videoFile);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        debugPrint(
            '📁 Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ Video uploaded successfully to: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading video file: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');

      await _errorHandler.handleUploadError(
        operation: 'video_file_upload',
        error: e,
        context: {
          'video_id': videoId,
          'user_id': userId,
          'file_size': await videoFile.length(),
          'file_path': videoFile.path,
        },
      );
      return null;
    }
  }

  /// Generate and upload thumbnail
  Future<String?> _generateAndUploadThumbnail(
      File videoFile, String videoId, String userId) async {
    try {
      debugPrint('🖼️ Starting thumbnail generation...');
      debugPrint('🖼️ Video file path: ${videoFile.path}');
      debugPrint('🖼️ Video file exists: ${await videoFile.exists()}');
      debugPrint('🖼️ Video file size: ${await videoFile.length()} bytes');

      // Use the new video processing service for thumbnail generation
      final processingService = VideoProcessingService();
      final result = await processingService.processVideo(
        inputFile: videoFile,
        videoId: videoId,
        userId: userId,
      );

      debugPrint('🖼️ Thumbnail generated: ${result.thumbnailUrl}');

      if (result.thumbnailUrl.isEmpty) {
        throw Exception('VideoProcessingService returned empty thumbnail URL');
      }

      return result.thumbnailUrl;
    } catch (e) {
      debugPrint('❌ Error generating thumbnail: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');

      LoggingService.instance.error('Error generating thumbnail',
          tag: 'VideoUploadService', error: e);

      // 🔥 FIX: Fail the upload if thumbnail generation fails
      rethrow;
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
      // print('Error updating user video count: $e');
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
      // print('Error adding to user profile: $e');
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
      // print('Error adding to user drafts: $e');
    }
  }

  /// Add video to appropriate feeds based on privacy setting
  Future<void> _addToFeeds(String videoId, String privacy, String userId,
      {String? category}) async {
    try {
      switch (privacy) {
        case 'Everyone':
          // Add to public feeds (For You feed)
          await _firestore
              .collection('feeds')
              .doc('for_you')
              .collection('videos')
              .doc(videoId)
              .set({
            'videoId': videoId,
            'userId': userId,
            'privacy': privacy,
            'addedAt': FieldValue.serverTimestamp(),
          });

          // Add to following feed for user's followers
          await _firestore
              .collection('feeds')
              .doc('following')
              .collection('videos')
              .doc(videoId)
              .set({
            'videoId': videoId,
            'userId': userId,
            'privacy': privacy,
            'addedAt': FieldValue.serverTimestamp(),
          });

          // Add to category feed if category is specified
          if (category != null && category.isNotEmpty) {
            await _firestore
                .collection('feeds')
                .doc('categories')
                .collection(category)
                .doc(videoId)
                .set({
              'videoId': videoId,
              'userId': userId,
              'category': category,
              'privacy': privacy,
              'addedAt': FieldValue.serverTimestamp(),
            });
          }
          break;

        case 'Connections':
          // Add only to following feed (connections can see)
          await _firestore
              .collection('feeds')
              .doc('following')
              .collection('videos')
              .doc(videoId)
              .set({
            'videoId': videoId,
            'userId': userId,
            'privacy': privacy,
            'addedAt': FieldValue.serverTimestamp(),
          });

          // Add to connections-only category feed if category is specified
          if (category != null && category.isNotEmpty) {
            await _firestore
                .collection('feeds')
                .doc('connections_categories')
                .collection(category)
                .doc(videoId)
                .set({
              'videoId': videoId,
              'userId': userId,
              'category': category,
              'privacy': privacy,
              'addedAt': FieldValue.serverTimestamp(),
            });
          }
          break;

        case 'Private':
          // Add only to user's private collection (not in any public feeds)
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('private_videos')
              .doc(videoId)
              .set({
            'videoId': videoId,
            'userId': userId,
            'privacy': privacy,
            'addedAt': FieldValue.serverTimestamp(),
          });
          break;

        default:
          // Default to private if unknown privacy setting
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('private_videos')
              .doc(videoId)
              .set({
            'videoId': videoId,
            'userId': userId,
            'privacy': privacy,
            'addedAt': FieldValue.serverTimestamp(),
          });
          break;
      }
    } catch (e) {
      debugPrint('Error adding to feeds: $e');
    }
  }

  /// Generate unique video ID
  String _generateVideoId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${(1000 + (9999 - 1000) * (DateTime.now().microsecond / 1000000)).round()}';
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
      // print('Error getting user videos: $e');
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
      // print('Error getting user drafts: $e');
      return [];
    }
  }

  /// Publish draft video
  Future<VideoUploadResult> publishDraft(String videoId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const VideoUploadResult(
          success: false,
          error: 'User not authenticated',
        );
      }

      // Get draft video
      final doc = await _firestore.collection('videos').doc(videoId).get();
      if (!doc.exists) {
        return const VideoUploadResult(
          success: false,
          error: 'Draft not found',
        );
      }

      final videoData = doc.data()!;
      final videoFile =
          File(videoData['videoUrl']); // This would need proper file handling

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
      final category = videoData['metadata']?['category'] as String?;
      await _addToFeeds(videoId, videoData['privacy'], user.uid,
          category: category);

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
