import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import '../features/gamification/emit_gamification_event.dart';
import '../features/gamification/gamification_event_types.dart';
import '../models/scheduled_post.dart';
import '../utils/category_schema.dart';
import 'cross_post_service.dart';
import 'post_counter_service.dart';

/// Firestore-based service for managing scheduled posts
class FirestoreScheduledPostService {
  static final FirestoreScheduledPostService _instance =
      FirestoreScheduledPostService._internal();
  factory FirestoreScheduledPostService() => _instance;
  FirestoreScheduledPostService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Save a scheduled post to Firestore
  Future<String> saveScheduledPost({
    required String videoId,
    required String videoUrl,
    required String thumbnailUrl,
    required String caption,
    required List<String> hashtags,
    required String category,
    required String privacy,
    required bool allowComments,
    required PostSchedule schedule,
    required Map<String, dynamic> metadata,
    List<PlatformConfig> platforms = const [],
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      final canonicalCategory = normalizeCategoryId(category);

      final scheduledPostId =
          'scheduled_${DateTime.now().millisecondsSinceEpoch}';

      // Convert PostSchedule to Map for Firestore
      final scheduleData = {
        'scheduledAtUtc': Timestamp.fromDate(schedule.scheduledAtUtc),
        'timezone': schedule.timezone,
        'perPlatform': schedule.perPlatform.map(
          (key, value) => MapEntry(
            key, // Key is already a String in PostSchedule.perPlatform
            {
              'scheduledAtUtc': Timestamp.fromDate(value.scheduledAtUtc),
              'timezone': value.timezone,
            },
          ),
        ),
        'createdAtUtc': Timestamp.fromDate(schedule.createdAtUtc),
        'updatedAtUtc': Timestamp.fromDate(schedule.updatedAtUtc),
      };

      // Save scheduled post
      final scheduledPostData = {
        'id': scheduledPostId,
        'authorId': currentUser.uid,
        'status': PostStatus.scheduled.name,
        'caption': caption,
        'tags': hashtags,
        'visibility':
            _privacyToPostVisibility(privacy).name, // Convert enum to string
        'videoId': videoId,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'category': canonicalCategory,
        'privacy': privacy,
        'userId': currentUser.uid,
        'scheduledAt': Timestamp.fromDate(schedule.scheduledAtUtc),
        'scheduledAtUtc': Timestamp.fromDate(schedule.scheduledAtUtc),
        'visible': false,
        'allowComments': allowComments,
        'schedule': scheduleData,
        'platforms': platforms
            .map(
              (platform) => {
                'key': platform.key,
                'enabled': platform.enabled,
                'payload': platform.payload,
                'status': platform.status?.name,
                'error': platform.error,
                'scheduledAtUtc': platform.scheduledAtUtc == null
                    ? null
                    : Timestamp.fromDate(platform.scheduledAtUtc!),
              },
            )
            .toList(),
        'history': [
          _historyEntry(
            status: PostStatus.scheduled.name,
            message: 'Post scheduled for publishing.',
          ),
        ],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'metadata': {
          ...metadata,
          'categoryOriginal': category,
          'categoryCanonical': canonicalCategory,
        },
      };

      await _firestore
          .collection('scheduled_posts')
          .doc(scheduledPostId)
          .set(scheduledPostData);

      developer.log('✅ Scheduled post saved: $scheduledPostId',
          name: 'FirestoreScheduledPostService');

      return scheduledPostId;
    } catch (e) {
      developer.log('❌ Error saving scheduled post: $e',
          name: 'FirestoreScheduledPostService');
      rethrow;
    }
  }

  Future<String?> saveImmediatePublishFollowUp({
    required String videoId,
    String? videoUrl,
    String? thumbnailUrl,
    required String caption,
    required List<String> hashtags,
    required String category,
    required String privacy,
    required bool allowComments,
    required Map<String, dynamic> metadata,
    required List<CrossPostRequest> crossPostRequests,
    required List<CrossPostResult> crossPostResults,
  }) async {
    try {
      if (crossPostRequests.isEmpty) {
        return null;
      }

      final resultByPlatform = <String, CrossPostResult>{
        for (final result in crossPostResults)
          result.platformName.toLowerCase(): result,
      };
      final hasRecoverableIssue = crossPostRequests.any((request) {
        final result = resultByPlatform[request.platformName.toLowerCase()];
        return result == null || !result.isSuccess;
      });
      if (!hasRecoverableIssue) {
        return null;
      }

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final postId =
          'publish_followup_${DateTime.now().millisecondsSinceEpoch}';
      final postData = {
        'id': postId,
        'authorId': currentUser.uid,
        'status': PostStatus.published.name,
        'caption': caption,
        'tags': hashtags,
        'visibility': _privacyToPostVisibility(privacy).name,
        'videoId': videoId,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'category': category,
        'privacy': privacy,
        'allowComments': allowComments,
        'platforms': crossPostRequests.map((request) {
          final normalizedPlatform = request.platformName.toLowerCase();
          final result = resultByPlatform[normalizedPlatform];
          final status = _platformStatusFromResult(result);
          return {
            'key': normalizedPlatform,
            'enabled': true,
            'payload': {
              'caption': request.caption,
              'requiresWatermark': request.requiresWatermark,
              'watermarkConfig': request.watermarkConfig,
              'watermarkAsset': request.watermarkAsset,
              'subscriptionTier': request.subscriptionTier,
            },
            'status': status.name,
            'error': result?.errorMessage,
            'scheduledAtUtc': request.scheduleAt == null
                ? null
                : Timestamp.fromDate(request.scheduleAt!),
          };
        }).toList(),
        'history': [
          _historyEntry(
            status: PostStatus.published.name,
            message:
                'StreamersTip publish succeeded. Follow-up record saved for external recovery.',
          ),
          ...crossPostRequests.map((request) {
            final normalizedPlatform = request.platformName.toLowerCase();
            final result = resultByPlatform[normalizedPlatform];
            final status = _platformStatusFromResult(result);
            return _historyEntry(
              status: status.name,
              platform: normalizedPlatform,
              message: result?.isSuccess == true
                  ? 'Cross-post completed successfully.'
                  : result?.errorMessage ??
                      'Cross-post needs follow-up before it can complete.',
            );
          }),
        ],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'metadata': {
          ...metadata,
          'publishOrigin': 'immediate_follow_up',
          'requiresCreatorAttention': true,
          'streamerstipVideoId': videoId,
        },
      };

      await _firestore.collection('scheduled_posts').doc(postId).set(postData);
      developer.log('✅ Immediate publish follow-up saved: $postId',
          name: 'FirestoreScheduledPostService');
      return postId;
    } catch (e) {
      developer.log('❌ Error saving immediate publish follow-up: $e',
          name: 'FirestoreScheduledPostService');
      rethrow;
    }
  }

  /// Get scheduled posts for current user
  Future<List<ScheduledPost>> getScheduledPosts({
    PostStatus? status,
    PlatformKey? platform,
    String? searchQuery,
    int? limit,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        developer.log('⚠️ No authenticated user',
            name: 'FirestoreScheduledPostService');
        return [];
      }

      // Load all posts for the user first (without orderBy to avoid index issues)
      // Then sort and filter client-side
      const int defaultLimit = 100;
      final int effectiveLimit = (limit ?? defaultLimit) * 2;

      Query query = _firestore
          .collection('scheduled_posts')
          .where('authorId', isEqualTo: currentUser.uid)
          .limit(effectiveLimit);

      QuerySnapshot snapshot;
      try {
        if (status == null) {
          query = query.orderBy('createdAt', descending: true);
        }
        snapshot = await query.get();
      } catch (e) {
        if (e.toString().contains('permission-denied') ||
            e.toString().contains('PERMISSION_DENIED')) {
          return [];
        }
        developer.log('⚠️ Could not order by createdAt, loading all: $e',
            name: 'FirestoreScheduledPostService');
        Query fallbackQuery = _firestore
            .collection('scheduled_posts')
            .where('authorId', isEqualTo: currentUser.uid)
            .limit(effectiveLimit);
        snapshot = await fallbackQuery.get();
      }
      developer.log(
          '📋 Loaded ${snapshot.docs.length} scheduled posts from Firestore',
          name: 'FirestoreScheduledPostService');

      var posts = <ScheduledPost>[];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final post = _mapToScheduledPost(doc.id, data);
          posts.add(post);
        } catch (e) {
          developer.log('❌ Error mapping post ${doc.id}: $e',
              name: 'FirestoreScheduledPostService');
        }
      }

      // Client-side filtering by status (if not already filtered in query)
      if (status != null) {
        posts = posts.where((post) => post.status == status).toList();
      }

      // Client-side sorting by scheduled time if orderBy failed
      posts.sort((a, b) {
        final aTime = a.schedule?.scheduledAtUtc ?? a.createdAt;
        final bTime = b.schedule?.scheduledAtUtc ?? b.createdAt;
        return bTime.compareTo(aTime); // Newest first
      });

      // Client-side filtering for platform and searchQuery
      if (platform != null) {
        posts = posts
            .where((post) => post.platforms.any((p) => p.key == platform.name))
            .toList();
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        posts = posts.where((post) {
          final captionMatch = post.caption.toLowerCase().contains(lowerQuery);
          final tagsMatch =
              post.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
          return captionMatch || tagsMatch;
        }).toList();
      }

      developer.log('✅ Returning ${posts.length} scheduled posts',
          name: 'FirestoreScheduledPostService');
      return posts;
    } catch (e, stackTrace) {
      if (e.toString().contains('permission-denied') ||
          e.toString().contains('PERMISSION_DENIED')) {
        return [];
      }
      developer.log('❌ Error loading scheduled posts: $e\n$stackTrace',
          name: 'FirestoreScheduledPostService');
      return [];
    }
  }

  /// Update scheduled post status
  Future<void> updateScheduledPostStatus(
    String scheduledPostId,
    PostStatus status, {
    String? historyMessage,
  }) async {
    try {
      await _firestore
          .collection('scheduled_posts')
          .doc(scheduledPostId)
          .update({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      developer.log(
          '✅ Updated scheduled post status: $scheduledPostId -> $status',
          name: 'FirestoreScheduledPostService');
      await _appendHistoryEntries(scheduledPostId, [
        _historyEntry(
          status: status.name,
          message: historyMessage ?? _defaultPostHistoryMessage(status),
        ),
      ]);
    } catch (e) {
      developer.log('❌ Error updating scheduled post status: $e',
          name: 'FirestoreScheduledPostService');
      rethrow;
    }
  }

  /// Delete a scheduled post
  Future<void> deleteScheduledPost(String scheduledPostId) async {
    try {
      await _firestore
          .collection('scheduled_posts')
          .doc(scheduledPostId)
          .delete();
      developer.log('✅ Deleted scheduled post: $scheduledPostId',
          name: 'FirestoreScheduledPostService');
    } catch (e) {
      developer.log('❌ Error deleting scheduled post: $e',
          name: 'FirestoreScheduledPostService');
      rethrow;
    }
  }

  /// Delete a scheduled post (alias for deleteScheduledPost for compatibility)
  Future<void> deletePost(String scheduledPostId) async {
    return deleteScheduledPost(scheduledPostId);
  }

  /// Publish a scheduled post immediately
  Future<ScheduledPost> publishNow(String scheduledPostId) async {
    try {
      // Get the scheduled post
      final doc = await _firestore
          .collection('scheduled_posts')
          .doc(scheduledPostId)
          .get();
      if (!doc.exists) {
        throw Exception('Scheduled post not found');
      }

      final data = doc.data() as Map<String, dynamic>;
      final videoId = data['videoId'] as String?;
      if (videoId == null) {
        throw Exception('Scheduled post has no videoId');
      }
      final platforms = _mapPlatforms(data);
      final enabledPlatformKeys = platforms
          .where((platform) => platform.enabled)
          .map((platform) => platform.key)
          .toList();

      // Update status to publishing
      await updateScheduledPostStatus(
        scheduledPostId,
        PostStatus.publishing,
        historyMessage: 'Publishing started.',
      );
      if (enabledPlatformKeys.isNotEmpty) {
        await updatePlatformStatuses(
          scheduledPostId,
          platformKeys: enabledPlatformKeys,
          status: PlatformStatus.publishing,
          clearErrors: true,
        );
      }

      // Get the video document
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();
      if (!videoDoc.exists) {
        throw Exception('Video not found: $videoId');
      }

      final videoData = videoDoc.data()!;
      final privacy = videoData['privacy'] as String? ?? 'Everyone';
      final category = videoData['metadata']?['category'] as String?;
      final userId =
          videoData['userId'] as String? ?? (videoData['creatorId'] as String?);

      if (userId == null || userId.isEmpty) {
        throw Exception('Video has no userId or creatorId');
      }

      // Ensure video has creatorId for profile queries
      final hasCreatorId = videoData['creatorId'] != null;
      if (!hasCreatorId) {
        await _firestore.collection('videos').doc(videoId).update({
          'creatorId': userId,
          'creator_id': userId,
        });
      }

      final updateData = <String, dynamic>{
        'status': 'published',
        'creatorId': userId,
        'creator_id': userId,
        'updatedAt': FieldValue.serverTimestamp(),
        'scheduledAtUtc': FieldValue.delete(),
      };

      // Keep category fields aligned with the canonical upload schema.
      if (category != null && category.isNotEmpty) {
        updateData.addAll(buildCanonicalCategoryFields(category));
      }

      await _firestore.collection('videos').doc(videoId).update(updateData);

      developer.log(
          '✅ Updated video document: $videoId with status=published, creatorId=$userId, category=$category',
          name: 'FirestoreScheduledPostService');

      // Add to user's profile videos collection (same as VideoUploadService)
      await _addToUserProfile(userId, videoId);

      // Add to feeds using the same logic as VideoUploadService
      await _addToFeeds(videoId, privacy, userId, category: category);

      if (enabledPlatformKeys.isNotEmpty) {
        final crossPostResults = await CrossPostService.instance.publishToAll(
          requests: platforms
              .where((platform) => platform.enabled)
              .map(
                (platform) => CrossPostRequest(
                  platformName: platform.key,
                  caption: (platform.payload?['caption'] as String?) ??
                      (data['caption'] as String? ?? ''),
                  videoId: videoId,
                  requiresWatermark:
                      platform.payload?['requiresWatermark'] == true,
                  watermarkConfig:
                      (platform.payload?['watermarkConfig'] as Map?)?.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                  watermarkAsset:
                      platform.payload?['watermarkAsset'] as String?,
                  subscriptionTier:
                      platform.payload?['subscriptionTier'] as String?,
                ),
              )
              .toList(),
        );
        await applyCrossPostResults(
          scheduledPostId,
          crossPostResults,
        );
      }

      // Update PostCounterService
      try {
        final postCounterService = PostCounterService();
        await postCounterService.incrementPostCount(userId, postId: videoId);
      } catch (e) {
        developer.log('⚠️ Failed to update PostCounterService: $e',
            name: 'FirestoreScheduledPostService');
      }
      scheduleGamificationEvent(
        GamificationEventTypes.contentPublished,
        entityType: 'video',
        entityId: videoId,
      );
      // Update scheduled post status to published
      await updateScheduledPostStatus(
        scheduledPostId,
        PostStatus.published,
        historyMessage: 'Publishing completed.',
      );

      // Get the updated post
      final updatedDoc = await _firestore
          .collection('scheduled_posts')
          .doc(scheduledPostId)
          .get();
      final updatedData = updatedDoc.data() as Map<String, dynamic>;
      final post = _mapToScheduledPost(scheduledPostId, updatedData);

      developer.log('✅ Published scheduled post: $scheduledPostId',
          name: 'FirestoreScheduledPostService');

      return post;
    } catch (e) {
      developer.log('❌ Error publishing scheduled post: $e',
          name: 'FirestoreScheduledPostService');
      // Mark as failed
      try {
        await updateScheduledPostStatus(
          scheduledPostId,
          PostStatus.failed,
          historyMessage:
              'Publishing failed before all destinations completed.',
        );
        await updatePlatformStatuses(
          scheduledPostId,
          status: PlatformStatus.failed,
          clearErrors: false,
          platformKeys: null,
          errorMessage:
              'StreamersTip publish failed; external publish was not attempted.',
          onlyEnabledPlatforms: true,
        );
      } catch (_) {
        // Ignore error updating status
      }
      rethrow;
    }
  }

  Future<void> updatePlatformStatuses(
    String scheduledPostId, {
    required PlatformStatus status,
    List<String>? platformKeys,
    bool clearErrors = false,
    String? errorMessage,
    bool onlyEnabledPlatforms = false,
  }) async {
    final doc = await _firestore
        .collection('scheduled_posts')
        .doc(scheduledPostId)
        .get();
    if (!doc.exists) {
      throw Exception('Scheduled post not found');
    }

    final data = doc.data() as Map<String, dynamic>;
    final rawPlatforms = (data['platforms'] as List<dynamic>? ?? const []);
    final historyEntries = <Map<String, dynamic>>[];
    final updatedPlatforms = rawPlatforms.map((rawPlatform) {
      final platform = Map<String, dynamic>.from(
        rawPlatform as Map<String, dynamic>,
      );
      final key = platform['key'] as String?;
      final enabled = platform['enabled'] as bool? ?? true;
      final matchesKey =
          platformKeys == null || (key != null && platformKeys.contains(key));
      if ((!onlyEnabledPlatforms || enabled) && matchesKey) {
        platform['status'] = status.name;
        if (clearErrors) {
          platform['error'] = null;
        } else if (errorMessage != null) {
          platform['error'] = errorMessage;
        }
        if (key != null && key.isNotEmpty) {
          historyEntries.add(
            _historyEntry(
              status: status.name,
              platform: key,
              message: errorMessage ?? _defaultPlatformHistoryMessage(status),
            ),
          );
        }
      }
      return platform;
    }).toList();

    await _firestore.collection('scheduled_posts').doc(scheduledPostId).update({
      'platforms': updatedPlatforms,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _appendHistoryEntries(scheduledPostId, historyEntries);
  }

  Future<void> applyCrossPostResults(
    String scheduledPostId,
    List<CrossPostResult> results,
  ) async {
    if (results.isEmpty) return;

    final doc = await _firestore
        .collection('scheduled_posts')
        .doc(scheduledPostId)
        .get();
    if (!doc.exists) {
      throw Exception('Scheduled post not found');
    }

    final data = doc.data() as Map<String, dynamic>;
    final rawPlatforms = (data['platforms'] as List<dynamic>? ?? const []);
    final resultByPlatform = {
      for (final result in results) result.platformName.toLowerCase(): result,
    };
    final historyEntries = <Map<String, dynamic>>[];

    final updatedPlatforms = rawPlatforms.map((rawPlatform) {
      final platform = Map<String, dynamic>.from(
        rawPlatform as Map<String, dynamic>,
      );
      final key = (platform['key'] as String? ?? '').toLowerCase();
      final result = resultByPlatform[key];
      if (result != null) {
        if (result.isSuccess) {
          platform['status'] = PlatformStatus.published.name;
          platform['error'] = null;
        } else {
          platform['status'] = _isReauthError(result.errorMessage)
              ? PlatformStatus.needsReauth.name
              : PlatformStatus.failed.name;
          platform['error'] = result.errorMessage ?? 'Cross-post failed';
        }
        historyEntries.add(
          _historyEntry(
            status: platform['status'] as String? ?? PlatformStatus.failed.name,
            platform: key,
            message: result.isSuccess
                ? 'Cross-post completed successfully.'
                : result.errorMessage ?? 'Cross-post failed.',
          ),
        );
      }
      return platform;
    }).toList();

    await _firestore.collection('scheduled_posts').doc(scheduledPostId).update({
      'platforms': updatedPlatforms,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _appendHistoryEntries(scheduledPostId, historyEntries);
  }

  /// Cancel a scheduled post
  Future<ScheduledPost> cancelPost(String scheduledPostId) async {
    try {
      await updateScheduledPostStatus(
        scheduledPostId,
        PostStatus.canceled,
        historyMessage: 'Scheduled post was canceled.',
      );

      // Get the updated post
      final doc = await _firestore
          .collection('scheduled_posts')
          .doc(scheduledPostId)
          .get();
      if (!doc.exists) {
        throw Exception('Scheduled post not found');
      }

      final data = doc.data() as Map<String, dynamic>;
      final post = _mapToScheduledPost(doc.id, data);

      developer.log('✅ Canceled scheduled post: $scheduledPostId',
          name: 'FirestoreScheduledPostService');

      return post;
    } catch (e) {
      developer.log('❌ Error canceling scheduled post: $e',
          name: 'FirestoreScheduledPostService');
      rethrow;
    }
  }

  /// Retry a failed scheduled post
  Future<ScheduledPost> retryPost(
    String scheduledPostId, {
    List<String>? platformKeys,
  }) async {
    try {
      final doc = await _firestore
          .collection('scheduled_posts')
          .doc(scheduledPostId)
          .get();
      if (!doc.exists) {
        throw Exception('Scheduled post not found');
      }

      final data = doc.data() as Map<String, dynamic>;
      final rawPlatforms = (data['platforms'] as List<dynamic>? ?? const []);
      final updatedPlatforms = rawPlatforms.map((rawPlatform) {
        final platform = Map<String, dynamic>.from(
          rawPlatform as Map<String, dynamic>,
        );
        final key = platform['key'] as String?;
        final status = platform['status'] as String?;
        final matchesRequestedPlatform =
            platformKeys == null || (key != null && platformKeys.contains(key));
        if (matchesRequestedPlatform &&
            (status == PlatformStatus.failed.name ||
                status == PlatformStatus.needsReauth.name)) {
          platform['status'] = PlatformStatus.pending.name;
          platform['error'] = null;
        }
        return platform;
      }).toList();

      await _firestore
          .collection('scheduled_posts')
          .doc(scheduledPostId)
          .update({
        'status': PostStatus.scheduled.name,
        'platforms': updatedPlatforms,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _appendHistoryEntries(scheduledPostId, [
        _historyEntry(
          status: PostStatus.scheduled.name,
          message: platformKeys == null || platformKeys.isEmpty
              ? 'Post retry queued.'
              : 'Retry queued for ${platformKeys.join(', ')}.',
        ),
      ]);

      // Get the updated post
      final refreshedDoc = await _firestore
          .collection('scheduled_posts')
          .doc(scheduledPostId)
          .get();
      if (!refreshedDoc.exists) {
        throw Exception('Scheduled post not found');
      }

      final refreshedData = refreshedDoc.data() as Map<String, dynamic>;
      final post = _mapToScheduledPost(refreshedDoc.id, refreshedData);

      developer.log('✅ Retried scheduled post: $scheduledPostId',
          name: 'FirestoreScheduledPostService');

      return post;
    } catch (e) {
      developer.log('❌ Error retrying scheduled post: $e',
          name: 'FirestoreScheduledPostService');
      rethrow;
    }
  }

  Future<ScheduledPost> retryExternalPlatforms(
    String scheduledPostId, {
    List<String>? platformKeys,
  }) async {
    try {
      final doc = await _firestore
          .collection('scheduled_posts')
          .doc(scheduledPostId)
          .get();
      if (!doc.exists) {
        throw Exception('Scheduled post not found');
      }

      final data = doc.data() as Map<String, dynamic>;
      final videoId = data['videoId'] as String?;
      if (videoId == null || videoId.isEmpty) {
        throw Exception('Missing video ID for retry');
      }

      final caption = data['caption'] as String? ?? '';
      final platforms = _mapPlatforms(data);
      final targets = platforms.where((platform) {
        final matchesRequestedPlatform =
            platformKeys == null || platformKeys.contains(platform.key);
        final status = platform.status;
        return platform.enabled &&
            matchesRequestedPlatform &&
            (status == PlatformStatus.failed ||
                status == PlatformStatus.needsReauth);
      }).toList();

      if (targets.isEmpty) {
        return _mapToScheduledPost(doc.id, data);
      }

      final targetKeys = targets.map((platform) => platform.key).toList();
      await updatePlatformStatuses(
        scheduledPostId,
        status: PlatformStatus.publishing,
        platformKeys: targetKeys,
        clearErrors: true,
      );

      final results = await CrossPostService.instance.publishToAll(
        requests: targets
            .map(
              (platform) => CrossPostRequest(
                platformName: platform.key,
                caption: platform.payload?['caption'] as String? ?? caption,
                videoId: videoId,
                scheduleAt: platform.scheduledAtUtc,
                requiresWatermark:
                    platform.payload?['requiresWatermark'] == true,
                watermarkConfig:
                    (platform.payload?['watermarkConfig'] as Map?)?.map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
                watermarkAsset: platform.payload?['watermarkAsset'] as String?,
                subscriptionTier:
                    platform.payload?['subscriptionTier'] as String?,
              ),
            )
            .toList(),
      );

      await applyCrossPostResults(scheduledPostId, results);
      await _firestore
          .collection('scheduled_posts')
          .doc(scheduledPostId)
          .update({
        'status': PostStatus.published.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _appendHistoryEntries(scheduledPostId, [
        _historyEntry(
          status: PostStatus.published.name,
          message: 'External publish retry completed.',
        ),
      ]);

      final refreshedDoc = await _firestore
          .collection('scheduled_posts')
          .doc(scheduledPostId)
          .get();
      if (!refreshedDoc.exists) {
        throw Exception('Scheduled post not found');
      }

      return _mapToScheduledPost(
        refreshedDoc.id,
        refreshedDoc.data() as Map<String, dynamic>,
      );
    } catch (e) {
      developer.log('❌ Error retrying external platforms: $e',
          name: 'FirestoreScheduledPostService');
      rethrow;
    }
  }

  /// Get posts ready to publish (scheduled time has passed)
  Future<List<Map<String, dynamic>>> getPostsReadyToPublish() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        developer.log('⚠️ No authenticated user - cannot check scheduled posts',
            name: 'FirestoreScheduledPostService');
        return [];
      }

      final now = Timestamp.now();
      developer.log(
          '🔍 Checking for posts ready to publish for user ${currentUser.uid} (now: ${now.toDate()})',
          name: 'FirestoreScheduledPostService');

      // 🔥 CRITICAL FIX: Filter by authorId to comply with Firestore security rules
      // Try query with nested field first
      Query query = _firestore
          .collection('scheduled_posts')
          .where('authorId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: PostStatus.scheduled.name)
          .where('schedule.scheduledAtUtc', isLessThanOrEqualTo: now);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get();
        developer.log(
            '✅ Found ${snapshot.docs.length} posts ready to publish (using nested query)',
            name: 'FirestoreScheduledPostService');
      } catch (e) {
        // If nested field query fails (missing index), fall back to client-side filtering
        developer.log(
            '⚠️ Nested field query failed (may need composite index), using fallback: $e',
            name: 'FirestoreScheduledPostService');

        // 🔥 CRITICAL FIX: Filter by authorId to comply with Firestore security rules
        // Get scheduled posts for current user only and filter client-side
        final allScheduled = await _firestore
            .collection('scheduled_posts')
            .where('authorId', isEqualTo: currentUser.uid)
            .where('status', isEqualTo: PostStatus.scheduled.name)
            .get();

        final readyPosts = <Map<String, dynamic>>[];
        for (final doc in allScheduled.docs) {
          final data = doc.data();
          final scheduleData = data['schedule'] as Map<String, dynamic>?;
          if (scheduleData != null) {
            final scheduledAtUtc = scheduleData['scheduledAtUtc'] as Timestamp?;
            if (scheduledAtUtc != null && scheduledAtUtc.compareTo(now) <= 0) {
              readyPosts.add({
                'id': doc.id,
                ...data,
              });
            }
          }
        }

        developer.log(
            '✅ Found ${readyPosts.length} posts ready to publish (using client-side filtering)',
            name: 'FirestoreScheduledPostService');

        return readyPosts;
      }

      final result = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        result.add({
          'id': doc.id,
          ...data,
        });
      }
      return result;
    } catch (e) {
      developer.log('❌ Error getting posts ready to publish: $e',
          name: 'FirestoreScheduledPostService');
      return [];
    }
  }

  /// Helper: Convert privacy string to PostVisibility enum
  PostVisibility _privacyToPostVisibility(String privacy) {
    switch (privacy) {
      case 'Everyone':
        return PostVisibility.public;
      case 'Connections':
        return PostVisibility.public; // Treat as public for now
      case 'Private':
        return PostVisibility.private;
      default:
        return PostVisibility.public;
    }
  }

  /// Add video to user's profile videos collection
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
      developer.log('✅ Added video to user profile: $videoId',
          name: 'FirestoreScheduledPostService');
    } catch (e) {
      developer.log('⚠️ Error adding video to user profile: $e',
          name: 'FirestoreScheduledPostService');
      // Don't throw - this is not critical
    }
  }

  /// Add video to appropriate feeds based on privacy setting
  /// (Matches VideoUploadService._addToFeeds logic)
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
          // Private videos don't go to feeds
          developer.log('⏭️ Skipping feed addition for private video: $videoId',
              name: 'FirestoreScheduledPostService');
          break;
      }

      developer.log('✅ Added video to feeds: $videoId (privacy: $privacy)',
          name: 'FirestoreScheduledPostService');
    } catch (e) {
      developer.log('⚠️ Error adding video to feeds: $e',
          name: 'FirestoreScheduledPostService');
      // Don't throw - this is not critical
    }
  }

  /// Helper: Map Firestore document to ScheduledPost model
  ScheduledPost _mapToScheduledPost(String id, Map<String, dynamic> data) {
    // Convert schedule data back to PostSchedule
    PostSchedule? schedule;
    if (data['schedule'] != null) {
      final scheduleData = data['schedule'] as Map<String, dynamic>;
      schedule = PostSchedule(
        scheduledAtUtc: (scheduleData['scheduledAtUtc'] as Timestamp).toDate(),
        timezone: scheduleData['timezone'] as String,
        perPlatform:
            (scheduleData['perPlatform'] as Map<String, dynamic>?)?.map(
                  (key, value) {
                    final valueMap = value as Map<String, dynamic>;
                    final platformSchedule = PlatformSchedule(
                      scheduledAtUtc: valueMap['scheduledAtUtc'] is Timestamp
                          ? (valueMap['scheduledAtUtc'] as Timestamp).toDate()
                          : DateTime.now(),
                      timezone: valueMap['timezone'] as String?,
                    );
                    // Keep key as String since PostSchedule.perPlatform is Map<String, PlatformSchedule>
                    return MapEntry(key, platformSchedule);
                  },
                ) ??
                <String, PlatformSchedule>{},
        createdAtUtc: (scheduleData['createdAtUtc'] as Timestamp).toDate(),
        updatedAtUtc: (scheduleData['updatedAtUtc'] as Timestamp).toDate(),
      );
    }

    // Convert media data
    final media = <PostMedia>[];
    if (data['videoUrl'] != null) {
      // Use thumbnail URL for preview, fallback to video URL
      final thumbnailUrl = data['thumbnailUrl'] as String?;
      media.add(PostMedia(
        id: '${id}_media',
        type: MediaType.video,
        src: thumbnailUrl ?? data['videoUrl'] as String,
        aspectRatio: 9.0 / 16.0, // Default for vertical videos
        durationMs: (data['metadata']?['duration'] as num?)?.toInt() ?? 30000,
      ));
    }

    final platforms = _mapPlatforms(data);

    return ScheduledPost(
      id: id,
      authorId: data['authorId'] as String,
      status: PostStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => PostStatus.scheduled,
      ),
      caption: data['caption'] as String? ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      visibility: PostVisibility.values.firstWhere(
        (v) => v.name == (data['visibility'] ?? 'public'),
        orElse: () => PostVisibility.public,
      ),
      media: media,
      platforms: platforms,
      schedule: schedule,
      analyticsHints: {
        ...Map<String, dynamic>.from(data['metadata'] ?? {}),
        if (data['videoId'] != null) 'videoId': data['videoId'],
        if (data['status'] != null) 'postStatus': data['status'],
        'publishingHistory': (data['history'] as List<dynamic>? ?? const [])
            .map((entry) => Map<String, dynamic>.from(entry as Map))
            .toList(),
      },
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  List<PlatformConfig> _mapPlatforms(Map<String, dynamic> data) {
    final platforms = <PlatformConfig>[];
    final rawPlatforms = data['platforms'] as List<dynamic>? ?? const [];
    for (final rawPlatform in rawPlatforms) {
      final platformData = Map<String, dynamic>.from(
        rawPlatform as Map<String, dynamic>,
      );
      platforms.add(
        PlatformConfig(
          key: platformData['key'] as String? ?? '',
          enabled: platformData['enabled'] as bool? ?? true,
          payload: platformData['payload'] as Map<String, dynamic>?,
          status: PlatformStatus.values.firstWhere(
            (status) => status.name == platformData['status'],
            orElse: () => PlatformStatus.pending,
          ),
          error: platformData['error'] as String?,
          scheduledAtUtc: platformData['scheduledAtUtc'] is Timestamp
              ? (platformData['scheduledAtUtc'] as Timestamp).toDate()
              : null,
        ),
      );
    }
    return platforms;
  }

  bool _isReauthError(String? message) {
    if (message == null) return false;
    final normalized = message.toLowerCase();
    return normalized.contains('401') ||
        normalized.contains('403') ||
        normalized.contains('auth') ||
        normalized.contains('token') ||
        normalized.contains('reauth');
  }

  PlatformStatus _platformStatusFromResult(CrossPostResult? result) {
    if (result == null) {
      return PlatformStatus.failed;
    }
    if (result.isSuccess) {
      return PlatformStatus.published;
    }
    return _isReauthError(result.errorMessage)
        ? PlatformStatus.needsReauth
        : PlatformStatus.failed;
  }

  Future<void> _appendHistoryEntries(
    String scheduledPostId,
    List<Map<String, dynamic>> entries,
  ) async {
    if (entries.isEmpty) return;
    await _firestore.collection('scheduled_posts').doc(scheduledPostId).update({
      'history': FieldValue.arrayUnion(entries),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Map<String, dynamic> _historyEntry({
    required String status,
    required String message,
    String? platform,
  }) {
    return {
      'status': status,
      if (platform != null) 'platform': platform,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  String _defaultPostHistoryMessage(PostStatus status) {
    switch (status) {
      case PostStatus.scheduled:
        return 'Post is scheduled.';
      case PostStatus.publishing:
        return 'Publishing started.';
      case PostStatus.published:
        return 'Publishing completed.';
      case PostStatus.failed:
        return 'Publishing failed.';
      case PostStatus.canceled:
        return 'Post canceled.';
      case PostStatus.draft:
        return 'Post saved as draft.';
    }
  }

  String _defaultPlatformHistoryMessage(PlatformStatus status) {
    switch (status) {
      case PlatformStatus.pending:
        return 'Destination queued.';
      case PlatformStatus.publishing:
        return 'Destination publish started.';
      case PlatformStatus.published:
        return 'Destination publish succeeded.';
      case PlatformStatus.failed:
        return 'Destination publish failed.';
      case PlatformStatus.needsReauth:
        return 'Destination requires reconnect.';
      case PlatformStatus.canceled:
        return 'Destination publish canceled.';
    }
  }
}
