import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import '../models/scheduled_post.dart';
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
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

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
        'category': category,
        'privacy': privacy,
        'allowComments': allowComments,
        'schedule': scheduleData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'metadata': metadata,
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
      Query query = _firestore
          .collection('scheduled_posts')
          .where('authorId', isEqualTo: currentUser.uid);

      QuerySnapshot snapshot;
      try {
        // Try to order by createdAt (has index) if no status filter
        if (status == null) {
          query = query.orderBy('createdAt', descending: true);
        }
        if (limit != null) {
          query = query.limit(
              limit * 2); // Get more to account for client-side filtering
        }
        snapshot = await query.get();
      } catch (e) {
        // If orderBy fails, just get all documents
        developer.log('⚠️ Could not order by createdAt, loading all: $e',
            name: 'FirestoreScheduledPostService');
        Query fallbackQuery = _firestore
            .collection('scheduled_posts')
            .where('authorId', isEqualTo: currentUser.uid);
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
        // Note: Since we're not storing platforms in Firestore yet,
        // this filter won't do anything for now
        // posts = posts.where((post) =>
        //   post.platforms.any((p) => p.key == platform.name)).toList();
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
      developer.log('❌ Error loading scheduled posts: $e\n$stackTrace',
          name: 'FirestoreScheduledPostService');
      return [];
    }
  }

  /// Update scheduled post status
  Future<void> updateScheduledPostStatus(
    String scheduledPostId,
    PostStatus status,
  ) async {
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

      // Update status to publishing
      await updateScheduledPostStatus(scheduledPostId, PostStatus.publishing);

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
        });
      }

      // Update video status to published and ensure all required fields are set
      final updateData = <String, dynamic>{
        'status': 'published',
        'creatorId': userId, // Ensure creatorId is set (for profile queries)
        'updatedAt': FieldValue.serverTimestamp(),
        'scheduledAtUtc': FieldValue.delete(),
      };

      // Ensure category/categoryId is set for VideoService (it looks for both)
      if (category != null && category.isNotEmpty) {
        updateData['category'] = category;
        updateData['categoryId'] =
            category; // VideoService might look for this too
      }

      await _firestore.collection('videos').doc(videoId).update(updateData);

      developer.log(
          '✅ Updated video document: $videoId with status=published, creatorId=$userId, category=$category',
          name: 'FirestoreScheduledPostService');

      // Add to user's profile videos collection (same as VideoUploadService)
      await _addToUserProfile(userId, videoId);

      // Add to feeds using the same logic as VideoUploadService
      await _addToFeeds(videoId, privacy, userId, category: category);

      // Update PostCounterService
      try {
        final postCounterService = PostCounterService();
        await postCounterService.incrementPostCount(userId, postId: videoId);
      } catch (e) {
        developer.log('⚠️ Failed to update PostCounterService: $e',
            name: 'FirestoreScheduledPostService');
      }

      // Update scheduled post status to published
      await updateScheduledPostStatus(scheduledPostId, PostStatus.published);

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
        await updateScheduledPostStatus(scheduledPostId, PostStatus.failed);
      } catch (_) {
        // Ignore error updating status
      }
      rethrow;
    }
  }

  /// Cancel a scheduled post
  Future<ScheduledPost> cancelPost(String scheduledPostId) async {
    try {
      await updateScheduledPostStatus(scheduledPostId, PostStatus.canceled);

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
  Future<ScheduledPost> retryPost(String scheduledPostId) async {
    try {
      await updateScheduledPostStatus(scheduledPostId, PostStatus.scheduled);

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

      developer.log('✅ Retried scheduled post: $scheduledPostId',
          name: 'FirestoreScheduledPostService');

      return post;
    } catch (e) {
      developer.log('❌ Error retrying scheduled post: $e',
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

    // Convert platform configs
    final platforms = <PlatformConfig>[];

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
      analyticsHints: Map<String, dynamic>.from(data['metadata'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
