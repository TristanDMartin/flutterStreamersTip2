import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'video_moderation_service.dart';
import 'enhanced_error_handling_service.dart';
import 'video_processing_service.dart';
import 'tag_mention_service.dart';
import 'mux_upload_service.dart';
import 'cross_post_service.dart';
import '../features/gamification/emit_gamification_event.dart';
import '../features/gamification/gamification_event_types.dart';
import '../utils/category_schema.dart';

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

class CrossPublishResult {
  final VideoUploadResult streamerstipResult;
  final List<CrossPostResult> crossPostResults;

  const CrossPublishResult({
    required this.streamerstipResult,
    required this.crossPostResults,
  });

  bool get streamerstipSuccess => streamerstipResult.success;
  List<CrossPostResult> get successfulPlatforms =>
      crossPostResults.where((r) => r.isSuccess).toList();
  List<CrossPostResult> get failedPlatforms =>
      crossPostResults.where((r) => !r.isSuccess).toList();
}

class VideoUploadService {
  static final VideoUploadService _instance = VideoUploadService._internal();
  factory VideoUploadService() => _instance;
  VideoUploadService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final VideoModerationService _moderationService = VideoModerationService();
  final EnhancedErrorHandlingService _errorHandler =
      EnhancedErrorHandlingService();
  final TagMentionService _tagMentionService = TagMentionService();

  static const String _muxPlaceholderThumbnailUrl =
      'https://placehold.co/720x1280/1a1a2e/ffffff?text=Processing';

  /// Upload video with comprehensive moderation checks
  Future<VideoUploadResult> uploadVideo({
    required File videoFile,
    required String caption,
    required List<String> hashtags,
    required String privacy,
    required bool allowComments,
    String? videoId,
    Map<String, dynamic>? additionalMetadata,
    bool isDraft = false,
    void Function(double)? onProgress,
  }) async {
    String? activeVideoId = videoId;
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

      // Extract video duration
      final videoProcessingService = VideoProcessingService();
      final duration = await videoProcessingService.getVideoDuration(videoFile);
      final durationSeconds = duration.inSeconds.toDouble();
      debugPrint('⏱️ Video duration: $durationSeconds seconds');

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
      String? idToken;
      try {
        idToken = await user.getIdToken(true);
        debugPrint(
            '✅ VideoUploadService: Auth token refreshed - Length: ${idToken?.length ?? 0}');
      } catch (e) {
        debugPrint('❌ VideoUploadService: Failed to refresh auth token: $e');
        return VideoUploadResult(
          success: false,
          error: 'Authentication token refresh failed: $e',
        );
      }
      if (idToken == null || idToken.isEmpty) {
        return const VideoUploadResult(
          success: false,
          error: 'Failed to get authentication token',
        );
      }

      // 3. Generate unique video ID
      activeVideoId = activeVideoId?.trim().isNotEmpty == true
          ? activeVideoId!.trim()
          : _generateVideoId();
      final userId = user.uid;
      debugPrint('🎬 Using video ID: $activeVideoId');

      // 4. Upload video via Mux (Worker creates doc, returns upload URL)
      String? videoUrl;
      String? thumbnailUrl;
      String? muxUploadId;
      try {
        final muxResult = await MuxUploadService.instance.createDirectUpload(
          videoId: activeVideoId,
          userId: userId,
          idToken: idToken,
          isDraft: isDraft,
        );
        muxUploadId = muxResult.uploadId.isNotEmpty ? muxResult.uploadId : null;
        debugPrint('📤 Uploading video to Mux...');
        await MuxUploadService.instance.uploadToMux(
          videoFile: videoFile,
          uploadUrl: muxResult.uploadUrl,
          onProgress: onProgress,
        );
        videoUrl = null;
        thumbnailUrl = _muxPlaceholderThumbnailUrl;
        debugPrint('✅ Video uploaded to Mux (webhook will set playback URL)');
      } catch (e) {
        debugPrint('⚠️ Mux upload failed: $e');
        String errorDetail = e.toString();
        if (e is DioException) {
          final code = e.response?.statusCode;
          final body = e.response?.data;
          if (body is Map && body['error'] != null) {
            final msg = body['error'] as String;
            debugPrint('🔐 Worker $code: $msg');
            errorDetail = msg;
          }
        }
        await _markVideoUploadFailed(
          videoId: activeVideoId,
          userId: userId,
          errorMessage: errorDetail,
        );
        return VideoUploadResult(
          success: false,
          error: 'Upload failed: $errorDetail',
          metadata: {'videoId': activeVideoId},
        );
      }

      final canonicalThumbnailUrl = _withSizingParams(thumbnailUrl, width: 720);
      final thumbnails = {
        'urls': {
          '360': canonicalThumbnailUrl,
          '540': canonicalThumbnailUrl,
          '720': canonicalThumbnailUrl,
        },
        'generatedAt': FieldValue.serverTimestamp(),
      };

      // 6. Create video document in Firestore
      debugPrint('💾 Saving video metadata to Firestore...');

      final rawCategory = additionalMetadata?['category'] as String?;
      final category = (rawCategory != null && rawCategory.isNotEmpty)
          ? rawCategory
          : _detectCategoryFromContent(caption, hashtags);

      debugPrint('🔥 VideoUploadService: Category extracted: $category');
      debugPrint(
          '🔥 VideoUploadService: Additional metadata: $additionalMetadata');
      debugPrint('🔥 VideoUploadService: User UID: $userId');
      debugPrint('🔥 VideoUploadService: Auth UID: ${user.uid}');
      debugPrint('🔥 VideoUploadService: UIDs match: ${userId == user.uid}');

      final updateData = _buildAllowedVideoMetadataUpdate(
        caption: caption,
        hashtags: hashtags,
        privacy: privacy,
        allowComments: allowComments,
        category: category,
        thumbnailUrl: canonicalThumbnailUrl,
        thumbnails: thumbnails,
        videoUrl: videoUrl,
        status: 'processing',
        moderationConfidence: moderationResult.confidence,
        fileSize: fileSize,
        durationSeconds: durationSeconds,
        additionalMetadata: additionalMetadata,
        isMux: true,
        muxStatus: 'processing',
        muxUploadId: muxUploadId,
      );

      try {
        debugPrint(
            '🔥 VideoUploadService: Attempting to save video document to Firestore...');
        debugPrint('🔥 VideoUploadService: Video ID: $activeVideoId');
        debugPrint(
            '🔥 VideoUploadService: Update keys: ${updateData.keys.toList()}');

        await _upsertVideoDocument(
          videoId: activeVideoId,
          updateData: updateData,
        );
        debugPrint(
            '✅ VideoUploadService: Video document saved to Firestore successfully');
      } catch (e) {
        debugPrint('❌ VideoUploadService: Failed to save video document: $e');
        debugPrint('❌ VideoUploadService: Error type: ${e.runtimeType}');
        debugPrint('❌ VideoUploadService: Error details: ${e.toString()}');
        await _markVideoUploadFailed(
          videoId: activeVideoId,
          userId: userId,
          errorMessage: 'Failed to save video metadata: ${e.toString()}',
        );
        return VideoUploadResult(
          success: false,
          error: 'Failed to save video metadata: ${e.toString()}',
          metadata: {'videoId': activeVideoId},
        );
      }

      // Do not increment counts or insert into public/profile feeds while Mux
      // is still processing. The backend webhook is the source of truth for
      // ready/published visibility.

      // 10. Process tags and mentions from caption
      try {
        debugPrint('🏷️ Processing tags and mentions from caption...');
        await _tagMentionService.processVideoTagsAndMentions(
          videoId: activeVideoId,
          videoOwnerId: userId,
          caption: caption,
          postThumbnailUrl: canonicalThumbnailUrl,
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
        thumbnailUrl: canonicalThumbnailUrl,
        metadata: {
          'videoId': activeVideoId,
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
      final userId = _auth.currentUser?.uid;
      if (activeVideoId != null && userId != null) {
        await _markVideoUploadFailed(
          videoId: activeVideoId,
          userId: userId,
          errorMessage: e.toString(),
        );
      }

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
        metadata: activeVideoId == null ? null : {'videoId': activeVideoId},
      );
    }
  }

  Future<void> _markVideoUploadFailed({
    required String videoId,
    required String userId,
    required String errorMessage,
  }) async {
    try {
      final failedData = <String, dynamic>{
        'userId': userId,
        'creatorId': userId,
        'creator_id': userId,
        'status': 'failed',
        'visible': false,
        'isReadyForFeed': false,
        'uploadError': errorMessage,
        'errorMessage': errorMessage,
        'muxStatus': 'failed',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _firestore
          .collection('videos')
          .doc(videoId)
          .set(failedData, SetOptions(merge: true));
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('videos')
          .doc(videoId)
          .set({
        'status': 'failed',
        'visible': false,
        'uploadError': errorMessage,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ VideoUploadService: Marked failed upload hidden: $videoId');
    } catch (markError) {
      debugPrint(
          '⚠️ VideoUploadService: Failed to mark upload failed for $videoId: $markError');
    }
  }

  Future<void> _upsertVideoDocument({
    required String videoId,
    required Map<String, dynamic> updateData,
  }) async {
    final docRef = _firestore.collection('videos').doc(videoId);

    try {
      await docRef.update(updateData);
      return;
    } catch (e) {
      final isNotFound = e.toString().contains('not-found') ||
          e.toString().contains('NOT_FOUND');
      if (!isNotFound) {
        rethrow;
      }

      debugPrint(
          '⚠️ VideoUploadService: Worker-created video doc not ready yet, retrying with merge set...');

      await docRef.set(updateData, SetOptions(merge: true));
    }
  }

  /// Upload to StreamersTip AND cross-post to external platforms concurrently.
  ///
  /// StreamersTip upload is always primary. Cross-post failures never block it.
  /// Uses [Future.wait] with [eagerError: false] so both actions run to
  /// completion regardless of individual failures.
  Future<CrossPublishResult> publishWithCrossPost({
    required File videoFile,
    required String caption,
    required List<String> hashtags,
    required String privacy,
    required bool allowComments,
    required List<CrossPostRequest> crossPostRequests,
    String? videoId,
    Map<String, dynamic>? additionalMetadata,
    DateTime? scheduleAt,
    void Function(double)? onProgress,
  }) async {
    // Fire both concurrently; eagerError: false keeps both running.
    final futures = await Future.wait(
      [
        uploadVideo(
          videoFile: videoFile,
          caption: caption,
          hashtags: hashtags,
          privacy: privacy,
          allowComments: allowComments,
          videoId: videoId,
          additionalMetadata: additionalMetadata,
          onProgress: onProgress,
        ),
        if (crossPostRequests.isNotEmpty)
          CrossPostService.instance.publishToAll(
            requests: crossPostRequests,
          )
        else
          Future.value(<CrossPostResult>[]),
      ],
      eagerError: false,
    );

    final stResult = futures[0] as VideoUploadResult;
    final cpResults = futures[1] as List<CrossPostResult>;
    return CrossPublishResult(
      streamerstipResult: stResult,
      crossPostResults: cpResults,
    );
  }

  String _withSizingParams(String url, {int width = 720}) {
    try {
      final uri = Uri.parse(url);
      final params = Map<String, String>.from(uri.queryParameters);
      params['w'] = '$width';
      params.remove('h');
      params.remove('fit');
      params.remove('crop');
      return uri.replace(queryParameters: params).toString();
    } catch (_) {
      return url;
    }
  }

  /// Save video as draft (uses Mux; webhook sets status 'draft').
  Future<VideoUploadResult> saveAsDraft({
    required File videoFile,
    required String caption,
    required List<String> hashtags,
    required String privacy,
    required bool allowComments,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    return uploadVideo(
      videoFile: videoFile,
      caption: caption,
      hashtags: hashtags,
      privacy: privacy,
      allowComments: allowComments,
      additionalMetadata: additionalMetadata,
      isDraft: true,
    );
  }

  /// Builds update map with only Firestore-whitelisted fields.
  /// Worker creates the doc; Flutter updates only allowed metadata.
  /// Aligns with website schema: isMux, muxStatus, muxUploadId for cross-platform.
  Map<String, dynamic> _buildAllowedVideoMetadataUpdate({
    required String caption,
    required List<String> hashtags,
    required String privacy,
    required bool allowComments,
    required String category,
    required String thumbnailUrl,
    required Map<String, dynamic> thumbnails,
    String? videoUrl,
    required String status,
    required double moderationConfidence,
    required int fileSize,
    required double durationSeconds,
    Map<String, dynamic>? additionalMetadata,
    bool isMux = true,
    String muxStatus = 'processing',
    String? muxUploadId,
  }) {
    // Map legacy 'privacy' values to spec 'visibility' enum values.
    final String visibility = switch (privacy) {
      'Followers' || 'followers_only' => 'followers_only',
      'Private' || 'private' => 'private',
      _ => 'public',
    };
    final categoryFields = buildCanonicalCategoryFields(category);
    final canonicalCategory = categoryFields['category'] as String;

    final data = <String, dynamic>{
      'caption': caption,
      'hashtags': hashtags,
      'privacy': privacy, // legacy field — keep for backward compat
      'visibility': visibility, // spec §2 canonical field
      'allowComments': allowComments,
      ...categoryFields,
      'updatedAt': FieldValue.serverTimestamp(),
      'thumbnailUrl': thumbnailUrl,
      'thumbnails': thumbnails,
      'videoUrl': videoUrl,
      'status': status,
      'visible': false,
      'isReadyForFeed': false,
      'sourcePlatform': 'app', // spec §2 — internal tracking
      'isMux': isMux,
      'muxStatus': muxStatus,
      if (muxUploadId != null && muxUploadId.isNotEmpty)
        'muxUploadId': muxUploadId,
      'views': 0,
      'likes': 0,
      'comments': 0,
      'shares': 0,
      'moderation': {
        'approved': true,
        'checkedAt': FieldValue.serverTimestamp(),
        'confidence': moderationConfidence,
        'violations': [],
      },
      'metadata': {
        'fileSize': fileSize,
        'duration': durationSeconds,
        'resolution': '1080x1920',
        'format': 'mp4',
        'uploadedAt': FieldValue.serverTimestamp(),
        'categoryOriginal': category,
        'categoryCanonical': canonicalCategory,
      },
    };
    final allowedExtras = [
      'cross_platform_sharing',
      'watermark_applied',
      'moderation_confidence',
      'moderation_checked_at',
      'duration',
      'fileSize',
    ];
    if (additionalMetadata != null) {
      for (final k in additionalMetadata.keys) {
        if (allowedExtras.contains(k)) {
          data[k] = additionalMetadata[k];
        }
      }
    }
    return data;
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

  /// Detect category from caption and hashtags (website parity).
  String _detectCategoryFromContent(
    String caption,
    List<String> hashtags,
  ) {
    final content = '$caption ${hashtags.join(' ')}'.toLowerCase();
    const keywords = {
      'Gaming': [
        'game',
        'gaming',
        'gamer',
        'play',
        'stream',
        'twitch',
        'esports',
        'fortnite',
        'minecraft',
        'valorant',
        'apex',
        'cod',
        'fifa',
        'nba2k',
      ],
      'Art': [
        'art',
        'drawing',
        'paint',
        'sketch',
        'artist',
        'artwork',
        'digital art',
        'illustration',
        'design',
      ],
      'Music': [
        'music',
        'song',
        'sing',
        'rap',
        'beat',
        'producer',
        'dj',
        'audio',
      ],
      'Tech': [
        'tech',
        'coding',
        'programming',
        'software',
        'app',
        'computer',
        'review',
        'unboxing',
      ],
      'Sports': [
        'sport',
        'football',
        'basketball',
        'soccer',
        'workout',
        'athlete',
      ],
      'Food': [
        'food',
        'cooking',
        'recipe',
        'eat',
        'restaurant',
        'chef',
        'meal',
      ],
      'Travel': [
        'travel',
        'trip',
        'vacation',
        'journey',
        'adventure',
        'explore',
      ],
      'Fashion': [
        'fashion',
        'style',
        'outfit',
        'clothing',
        'wear',
        'dress',
      ],
      'Comedy': [
        'funny',
        'comedy',
        'joke',
        'laugh',
        'humor',
        'meme',
        'prank',
      ],
      'Education': [
        'learn',
        'education',
        'tutorial',
        'teach',
        'study',
        'how to',
      ],
      'Fitness': [
        'fitness',
        'gym',
        'workout',
        'exercise',
        'health',
        'yoga',
      ],
      'Lifestyle': [
        'lifestyle',
        'daily',
        'vlog',
        'routine',
        'morning',
        'life',
      ],
    };
    for (final entry in keywords.entries) {
      if (entry.value.any((k) => content.contains(k))) return entry.key;
    }
    return 'Other';
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
      scheduleGamificationEvent(
        GamificationEventTypes.contentPublished,
        entityType: 'video',
        entityId: videoId,
      );
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
