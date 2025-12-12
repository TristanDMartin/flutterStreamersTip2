import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/home_video.dart';
import '../models/video_thumbnails.dart';
import '../models/user.dart' as app_user;
import 'real_user_data_service.dart';

class VideoService extends StateNotifier<List<HomeVideo>> {
  VideoService() : super([]);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RealUserDataService _userDataService = RealUserDataService();

  /// Parse duration from various formats (string "M:SS", double, int) to seconds (double)
  double _parseDuration(dynamic duration) {
    try {
      if (duration == null) return 0.0;

      if (duration is double) return duration;
      if (duration is int) return duration.toDouble();

      if (duration is String) {
        // Handle duration stored as string (e.g., "120" or "2:00" or "0:02")
        if (duration.contains(':')) {
          // Parse format like "2:00" or "1:30" or "0:02"
          final parts = duration.split(':');
          if (parts.length == 2) {
            final minutes = int.tryParse(parts[0]) ?? 0;
            final secs = int.tryParse(parts[1]) ?? 0;
            return (minutes * 60 + secs).toDouble();
          }
        } else {
          // Parse as seconds string
          return double.tryParse(duration) ?? 0.0;
        }
      }

      return 0.0;
    } catch (e) {
      debugPrint('⚠️ VideoService: Error parsing duration "$duration": $e');
      return 0.0;
    }
  }

  /// Load all videos from Firestore and store them in memory
  Future<void> loadAllVideos() async {
    try {
      debugPrint('🎬 VideoService: ========== LOADING ALL VIDEOS ==========');

      // Check authentication first
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint(
            '❌ VideoService: User not authenticated, cannot load videos');
        debugPrint('   💡 User must be logged in to load videos');
        return;
      }
      debugPrint('✅ VideoService: User authenticated: ${user.uid}');

      // 🔍 FIX: Query videos - try multiple approaches for maximum compatibility
      QuerySnapshot<Map<String, dynamic>> snapshot;

      // First, try query with status filter (requires composite index)
      try {
        final query = _firestore
            .collection('videos')
            .where('status', isEqualTo: 'published')
            .orderBy('createdAt', descending: true)
            .limit(500);
        snapshot = await query.get();
        debugPrint(
            '🎬 VideoService: Found ${snapshot.docs.length} published videos in Firestore (with status filter)');
      } catch (e) {
        debugPrint(
            '⚠️ VideoService: Composite index missing, trying fallback query: $e');

        // Fallback 1: Try query without status filter, just order by createdAt
        try {
          final fallbackQuery = _firestore
              .collection('videos')
              .orderBy('createdAt', descending: true)
              .limit(1000); // Get more to account for filtering
          snapshot = await fallbackQuery.get();
          debugPrint(
              '🎬 VideoService: Found ${snapshot.docs.length} total videos (will filter in memory)');
        } catch (e2) {
          debugPrint(
              '⚠️ VideoService: OrderBy also failed, trying simple query: $e2');

          // Fallback 2: Just get all videos without ordering
          snapshot = await _firestore.collection('videos').limit(1000).get();
          debugPrint(
              '🎬 VideoService: Found ${snapshot.docs.length} total videos (no ordering)');
        }
      }

      // Debug: Show details of each video found
      debugPrint(
          '🎬 VideoService: Processing ${snapshot.docs.length} videos from Firestore');
      for (int i = 0; i < snapshot.docs.length && i < 5; i++) {
        final doc = snapshot.docs[i];
        final data = doc.data();
        debugPrint(
            '🎬 Video ${i + 1}: ID=${doc.id}, userId=${data['userId'] ?? data['creatorId'] ?? 'NONE'}, status=${data['status']}, privacy=${data['privacy']}, videoUrl=${(data['videoUrl'] ?? data['videoURL']) != null ? 'YES' : 'NO'}, thumbnailUrl=${(data['thumbnailUrl'] ?? data['thumbnailURL']) != null ? 'YES' : 'NO'}');
      }
      final videos = <HomeVideo>[];
      int processedCount = 0;
      int skippedCount = 0;
      final skipReasons = <String, int>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        debugPrint(
            '🎬 VideoService: Processing video ${doc.id}: status=${data['status']}, privacy=${data['privacy']}, userId: ${data['userId']}');

        // 🔍 FIX: Filter for published videos only (if not already filtered by query)
        if (data['status'] != 'published') {
          final reason = 'status: ${data['status']}';
          skipReasons[reason] = (skipReasons[reason] ?? 0) + 1;
          skippedCount++;
          debugPrint(
              '🎬 VideoService: Skipping video ${doc.id} - status: ${data['status']} (not published)');
          continue;
        }

        // 🔍 FIX: Filter for public videos only (privacy == 'Everyone' or null)
        // Note: null privacy is treated as public for backward compatibility
        // TEMPORARILY RELAXED: Show all published videos regardless of privacy for debugging
        final privacy = data['privacy'] as String?;
        if (privacy != null && privacy != 'Everyone' && privacy != 'Public') {
          debugPrint(
              '🎬 VideoService: ⚠️ Video ${doc.id} has privacy: "$privacy" (will still show for now)');
          // Don't skip - show all published videos regardless of privacy
          // TODO: Re-enable privacy filtering once videos are confirmed working
        } else {
          debugPrint(
              '🎬 VideoService: ✅ Privacy check passed for ${doc.id} - privacy: ${privacy ?? "null (treated as public)"}');
        }

        // Support all field name variants for cross-platform compatibility
        final userId = (data['userId'] ??
            data['creatorId'] ??
            data['creator_id']) as String?;
        if (userId == null) {
          skipReasons['no userId'] = (skipReasons['no userId'] ?? 0) + 1;
          skippedCount++;
          debugPrint(
              '🎬 VideoService: Skipping video ${doc.id} - no userId/creatorId/creator_id field');
          continue;
        }

        // Create thumbnails object from legacy thumbnailUrl (support both field variants)
        VideoThumbnails? thumbnails;
        final thumbnailUrl =
            (data['thumbnailUrl'] ?? data['thumbnailURL']) as String?;

        // 🔍 FIX: Validate video URL before processing (support both field variants)
        final videoUrl =
            (data['videoUrl'] ?? data['videoURL']) as String? ?? '';
        if (videoUrl.isEmpty) {
          skipReasons['no videoUrl'] = (skipReasons['no videoUrl'] ?? 0) + 1;
          skippedCount++;
          debugPrint(
              '🎬 VideoService: ⚠️ SKIPPING video ${doc.id} - no videoUrl/videoURL field');
          debugPrint(
              '   💡 To fix: Ensure videoUrl or videoURL is set in Firestore for this video');
          continue;
        }

        // 🔍 FIX: Validate URL format (must be HTTP/HTTPS, not localhost)
        if (!videoUrl.startsWith('http://') &&
            !videoUrl.startsWith('https://')) {
          skipReasons['invalid URL format'] =
              (skipReasons['invalid URL format'] ?? 0) + 1;
          skippedCount++;
          debugPrint(
              '🎬 VideoService: ⚠️ SKIPPING video ${doc.id} - invalid URL format: "$videoUrl"');
          debugPrint(
              '   💡 To fix: Video URL must start with http:// or https://');
          continue;
        }

        // 🔍 FIX: Skip localhost URLs (these won't work in production)
        // BUT: Allow localhost in debug mode for development
        if (!kDebugMode &&
            (videoUrl.contains('localhost') ||
                videoUrl.contains('127.0.0.1'))) {
          skipReasons['localhost URL'] =
              (skipReasons['localhost URL'] ?? 0) + 1;
          skippedCount++;
          debugPrint(
              '🎬 VideoService: ⚠️ SKIPPING video ${doc.id} - localhost URL: "$videoUrl"');
          debugPrint(
              '   💡 To fix: Video URL must point to Firebase Storage or CDN, not localhost');
          continue;
        }

        debugPrint(
            '🎬 VideoService: ✅ Video URL check passed for ${doc.id} - URL length: ${videoUrl.length}, valid format: ✅');

        // Get creator data
        final creator = await _userDataService.getUserById(userId);
        if (creator == null) {
          debugPrint(
              '🎬 VideoService: ⚠️ Creator not found for userId: $userId, creating placeholder');
          debugPrint(
              '   💡 To fix: Ensure user document exists in Firestore users collection');
          // Create placeholder creator instead of skipping video
          final placeholderCreator = app_user.User(
            id: userId,
            username:
                'user_${userId.length > 10 ? userId.substring(0, 10) : userId}',
            displayName: 'User',
            avatarURL: null,
            bio: null,
            hashtags: const [],
          );
          debugPrint(
              '🎬 VideoService: ✅ Using placeholder creator for ${doc.id}');

          // Create thumbnails for placeholder
          VideoThumbnails? placeholderThumbnails;
          if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
            placeholderThumbnails = VideoThumbnails(
              urls: {
                360: thumbnailUrl,
                540: thumbnailUrl,
                720: thumbnailUrl,
              },
              generatedAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
            );
          }

          // Continue with placeholder creator
          final placeholderVideo = HomeVideo(
            id: doc.id,
            creator: placeholderCreator,
            videoURL: videoUrl,
            thumbnailURL: thumbnailUrl,
            thumbnails: placeholderThumbnails,
            caption: data['caption'] ??
                data['title'] ??
                data['description'] ??
                'Untitled',
            categoryId: data['category'] ?? data['categoryId'] ?? 'general',
            views: data['views']?.toInt() ?? 0,
            likes: data['likes']?.toInt() ?? 0,
            comments: data['comments']?.toInt() ?? 0,
            duration: _parseDuration(
                data['metadata']?['duration'] ?? data['duration']),
            isDraft: false,
            createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
          );
          videos.add(placeholderVideo);
          processedCount++;
          continue; // Skip to next video since we already added this one
        } else {
          debugPrint(
              '🎬 VideoService: ✅ Creator found for ${doc.id} - ${creator.displayName} (@${creator.username})');
        }

        debugPrint(
            '🎬 VideoService: Video ${doc.id} - thumbnailUrl: "$thumbnailUrl", videoUrl: "$videoUrl"');
        debugPrint(
            '🎬 VideoService: Full video data for ${doc.id}: ${data.keys.toList()}');

        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
          // Create a VideoThumbnails object with the legacy URL as w360 (most common size)
          thumbnails = VideoThumbnails(
            urls: {
              360: thumbnailUrl,
              540: thumbnailUrl, // Use same URL for now
              720: thumbnailUrl, // Use same URL for now
            },
            generatedAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
          );
          debugPrint(
              '🖼️ VideoService: Created thumbnails for ${doc.id}: $thumbnailUrl');
        } else {
          debugPrint(
              '🖼️ VideoService: No thumbnail URL for video ${doc.id}, videoUrl: $videoUrl');
        }

        // Check for new format thumbnails if legacy format not available
        if (thumbnails == null) {
          final thumbnailsData = data['thumbnails'] as Map<String, dynamic>?;
          if (thumbnailsData != null && thumbnailsData['urls'] != null) {
            final urlsData = thumbnailsData['urls'] as Map<String, dynamic>;
            final urls = <int, String>{};

            // Convert string keys to int keys
            urlsData.forEach((key, value) {
              final intKey = int.tryParse(key);
              if (intKey != null && value is String) {
                urls[intKey] = value;
              }
            });

            if (urls.isNotEmpty) {
              thumbnails = VideoThumbnails(
                urls: urls,
                generatedAt: thumbnailsData['generatedAt'] as Timestamp? ??
                    data['createdAt'] as Timestamp? ??
                    Timestamp.now(),
              );
              debugPrint(
                  '🖼️ VideoService: Using new format thumbnails for ${doc.id}: ${urls.length} sizes');
            }
          }
        }

        final video = HomeVideo(
          id: doc.id,
          creator: creator,
          videoURL: videoUrl,
          thumbnailURL:
              thumbnailUrl, // Keep legacy field for backward compatibility
          thumbnails: thumbnails, // Add new thumbnails object
          caption: data['caption'] ??
              data['title'] ??
              data['description'] ??
              'Untitled',
          categoryId: data['category'] ?? data['categoryId'] ?? 'general',
          views: data['views']?.toInt() ?? 0,
          likes: data['likes']?.toInt() ?? 0,
          comments: data['comments']?.toInt() ?? 0,
          duration:
              _parseDuration(data['metadata']?['duration'] ?? data['duration']),
          isDraft: false,
          // Store creation date for proper sorting
          createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
        );

        debugPrint(
            '🎬 VideoService: ✅ Created video ${video.id} by ${video.creator.displayName} - URL: ${video.videoURL.isNotEmpty ? "YES" : "NO"}, Thumbnails: ${thumbnails != null ? 'YES' : 'NO'}');

        videos.add(video);
        processedCount++;
      }

      // Log summary after processing all videos
      debugPrint('🎬 VideoService: ========== PROCESSING SUMMARY ==========');
      debugPrint('   Total videos from Firestore: ${snapshot.docs.length}');
      debugPrint('   Successfully processed: $processedCount');
      debugPrint('   Skipped: $skippedCount');
      if (skipReasons.isNotEmpty) {
        debugPrint('   Skip reasons: $skipReasons');
      }

      // Remove duplicates based on video ID
      final uniqueVideos = <String, HomeVideo>{};
      for (final video in videos) {
        if (video.id.isNotEmpty) {
          uniqueVideos[video.id] = video;
        }
      }

      // Convert back to list and sort by creation date (newest first)
      final deduplicatedVideos = uniqueVideos.values.toList();

      // Sort by creation date - newest first (most recent uploads at top)
      deduplicatedVideos.sort((a, b) {
        // Sort by creation timestamp - newest first
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime); // Reverse order for newest first
      });

      state = deduplicatedVideos;
      debugPrint(
          '✅ VideoService: Loaded ${deduplicatedVideos.length} unique videos (removed ${videos.length - deduplicatedVideos.length} duplicates)');

      // 🔍 DIAGNOSTIC: Log summary of loaded videos and statistics
      if (deduplicatedVideos.isEmpty) {
        debugPrint('⚠️ VideoService: ⚠️⚠️⚠️ NO VIDEOS LOADED! ⚠️⚠️⚠️');
        debugPrint(
            '   Check the logs above to see why videos were filtered out.');
        debugPrint('   Common issues:');
        debugPrint('   1. Videos have status != "published"');
        debugPrint('   2. Videos have privacy != "Everyone" (or null)');
        debugPrint('   3. Videos are missing videoUrl field');
        debugPrint('   4. Videos are missing userId/creatorId field');
        debugPrint('   5. Creator user documents don\'t exist');

        // Additional diagnostic: Count total videos in Firestore
        try {
          final totalSnapshot =
              await _firestore.collection('videos').limit(1000).get();
          debugPrint(
              '📊 Diagnostic: Found ${totalSnapshot.docs.length} total videos in Firestore');

          // Count by status
          final statusCounts = <String, int>{};
          final privacyCounts = <String, int>{};
          final missingFields = <String, int>{};

          for (final doc in totalSnapshot.docs) {
            final data = doc.data();
            final status = data['status'] as String? ?? 'unknown';
            final privacy = data['privacy'] as String? ?? 'null';

            statusCounts[status] = (statusCounts[status] ?? 0) + 1;
            privacyCounts[privacy] = (privacyCounts[privacy] ?? 0) + 1;

            if (data['videoUrl'] == null ||
                (data['videoUrl'] as String).isEmpty) {
              missingFields['videoUrl'] = (missingFields['videoUrl'] ?? 0) + 1;
            }
            if (data['userId'] == null && data['creatorId'] == null) {
              missingFields['userId/creatorId'] =
                  (missingFields['userId/creatorId'] ?? 0) + 1;
            }
          }

          debugPrint('📊 Videos by status: $statusCounts');
          debugPrint('📊 Videos by privacy: $privacyCounts');
          if (missingFields.isNotEmpty) {
            debugPrint('📊 Videos missing fields: $missingFields');
          }
        } catch (e) {
          debugPrint('⚠️ Could not run diagnostics: $e');
        }
      } else {
        debugPrint(
            '🎬 VideoService: Successfully loaded ${deduplicatedVideos.length} videos');
        debugPrint('📊 Video summary:');
        for (int i = 0; i < deduplicatedVideos.length && i < 10; i++) {
          final video = deduplicatedVideos[i];
          debugPrint(
              '   ${i + 1}. ${video.id} by ${video.creator.displayName} - ${video.videoURL.isNotEmpty ? "✅ HAS URL" : "❌ NO URL"}');
        }
        if (deduplicatedVideos.length > 10) {
          debugPrint('   ... and ${deduplicatedVideos.length - 10} more');
        }

        // Log count of videos filtered out
        final totalBeforeFilter = snapshot.docs.length;
        final totalAfterFilter = deduplicatedVideos.length;
        final filteredOut = totalBeforeFilter - totalAfterFilter;
        if (filteredOut > 0) {
          debugPrint(
              '⚠️ Filtered out $filteredOut videos (${((filteredOut / totalBeforeFilter) * 100).toStringAsFixed(1)}%)');
          debugPrint(
              '   Reasons: privacy != "Everyone", missing creator, missing videoUrl, etc.');
        }
      }
    } catch (e) {
      debugPrint('❌ VideoService: Error loading videos: $e');

      // If it's a permission error, wait a bit and retry (auth might be initializing)
      if (e.toString().contains('permission-denied')) {
        debugPrint(
            '🔄 VideoService: Permission denied, waiting for auth and retrying...');
        await Future.delayed(const Duration(seconds: 2));

        // Retry once
        try {
          final user = _auth.currentUser;
          if (user != null) {
            debugPrint(
                '🔄 VideoService: Retrying with authenticated user: ${user.uid}');
            await loadAllVideos();
            return;
          }
        } catch (retryError) {
          debugPrint('❌ VideoService: Retry failed: $retryError');
        }
      }

      state = [];
    }
  }

  /// Add a new video to the service (called after upload)
  void addVideo(HomeVideo video) {
    final currentVideos = List<HomeVideo>.from(state);

    // Check if video already exists to prevent duplicates
    final existingIndex = currentVideos.indexWhere((v) => v.id == video.id);
    if (existingIndex != -1) {
      // Replace existing video instead of adding duplicate
      currentVideos[existingIndex] = video;
      debugPrint('🔄 VideoService: Updated existing video: ${video.caption}');
    } else {
      // Add new video to beginning (newest first)
      currentVideos.insert(0, video);
      debugPrint('✅ VideoService: Added new video: ${video.caption}');
    }

    // Re-sort to maintain newest-first order
    currentVideos.sort((a, b) {
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime); // Reverse order for newest first
    });

    state = currentVideos;
  }

  /// Remove a video from the service (called after deletion)
  void removeVideo(String videoId) {
    final currentVideos = List<HomeVideo>.from(state);
    final removedCount = currentVideos.length;

    // Remove video from state
    currentVideos.removeWhere((v) => v.id == videoId);

    final newCount = currentVideos.length;
    state = currentVideos;

    if (removedCount != newCount) {
      debugPrint(
          '✅ VideoService: Removed video $videoId from state (${removedCount} -> ${newCount})');
    } else {
      debugPrint('⚠️ VideoService: Video $videoId not found in state');
    }
  }

  /// Get videos for a specific user
  /// 🚀 NEWEST FIRST: Returns videos sorted by creation date (newest first)
  List<HomeVideo> getUserVideos(String userId) {
    final userVideos =
        state.where((video) => video.creator.id == userId).toList();
    // 🚀 NEWEST FIRST: Sort by creation date (newest first)
    userVideos.sort((a, b) {
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime); // Reverse order for newest first
    });
    return userVideos;
  }

  /// Get videos for a specific category
  List<HomeVideo> getCategoryVideos(String categoryId) {
    return state.where((video) => video.categoryId == categoryId).toList();
  }

  /// Get all videos (for HomeView)
  List<HomeVideo> getAllVideos() {
    return state;
  }

  /// Update video stats (likes, views, etc.)
  void updateVideoStats(
    String videoId, {
    int? views,
    int? likes,
    int? comments,
  }) {
    final currentVideos = List<HomeVideo>.from(state);
    final index = currentVideos.indexWhere((video) => video.id == videoId);

    if (index != -1) {
      final video = currentVideos[index];
      currentVideos[index] = video.copyWith(
        views: views ?? video.views,
        likes: likes ?? video.likes,
        comments: comments ?? video.comments,
      );
      state = currentVideos;
    }
  }

  /// Update video metadata (caption, tags, etc.)
  void updateVideoMetadata(
    String videoId, {
    String? caption,
    List<String>? tags,
  }) {
    final currentVideos = List<HomeVideo>.from(state);
    final index = currentVideos.indexWhere((video) => video.id == videoId);

    if (index != -1) {
      final video = currentVideos[index];
      currentVideos[index] = video.copyWith(
        caption: caption ?? video.caption,
        tags: tags ?? video.tags,
      );
      state = currentVideos;
      debugPrint(
          '✅ VideoService: Updated video metadata for $videoId - caption: "${caption ?? video.caption}", tags: ${tags ?? video.tags}');
    } else {
      debugPrint(
          '❌ VideoService: Video not found for metadata update: $videoId');
    }
  }

  /// Refresh videos from Firestore (useful after uploads or scheduled posts)
  Future<void> refresh() async {
    debugPrint('🔄 VideoService: Refreshing videos...');
    await loadAllVideos();
    debugPrint(
        '✅ VideoService: Refresh complete - ${state.length} videos loaded');
  }

  /// Get diagnostic information about videos in Firestore
  Future<Map<String, dynamic>> getVideoDiagnostics() async {
    try {
      final snapshot = await _firestore.collection('videos').limit(1000).get();

      final diagnostics = <String, dynamic>{
        'totalVideos': snapshot.docs.length,
        'byStatus': <String, int>{},
        'byPrivacy': <String, int>{},
        'missingFields': <String, int>{},
        'publishedPublicVideos': 0,
        'publishedPublicWithUrl': 0,
        'publishedPublicWithCreator': 0,
      };

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'unknown';
        final privacy = data['privacy'] as String? ?? 'null';

        (diagnostics['byStatus'] as Map<String, int>)[status] =
            ((diagnostics['byStatus'] as Map<String, int>)[status] ?? 0) + 1;
        (diagnostics['byPrivacy'] as Map<String, int>)[privacy] =
            ((diagnostics['byPrivacy'] as Map<String, int>)[privacy] ?? 0) + 1;

        // Check if video would appear in HomeView
        if (status == 'published' &&
            (privacy == 'Everyone' || privacy == 'null')) {
          diagnostics['publishedPublicVideos'] =
              (diagnostics['publishedPublicVideos'] as int) + 1;

          // Check both videoUrl and videoURL field variants
          final videoUrl = data['videoUrl'] ?? data['videoURL'];
          if (videoUrl != null && (videoUrl as String).isNotEmpty) {
            diagnostics['publishedPublicWithUrl'] =
                (diagnostics['publishedPublicWithUrl'] as int) + 1;

            final userId =
                data['userId'] ?? data['creatorId'] ?? data['creator_id'];
            if (userId != null) {
              diagnostics['publishedPublicWithCreator'] =
                  (diagnostics['publishedPublicWithCreator'] as int) + 1;
            }
          }
        }

        // Check both field variants for missing fields
        final videoUrl = data['videoUrl'] ?? data['videoURL'];
        if (videoUrl == null || (videoUrl as String).isEmpty) {
          (diagnostics['missingFields'] as Map<String, int>)['videoUrl'] =
              ((diagnostics['missingFields'] as Map<String, int>)['videoUrl'] ??
                      0) +
                  1;
        }
        final userId =
            data['userId'] ?? data['creatorId'] ?? data['creator_id'];
        if (userId == null) {
          (diagnostics['missingFields']
                  as Map<String, int>)['userId/creatorId'] =
              ((diagnostics['missingFields']
                          as Map<String, int>)['userId/creatorId'] ??
                      0) +
                  1;
        }
      }

      return diagnostics;
    } catch (e) {
      debugPrint('❌ Error getting video diagnostics: $e');
      return {'error': e.toString()};
    }
  }

  /// Preload video for performance optimization
  Future<void> preloadVideo(String videoId) async {
    try {
      debugPrint('🎬 VideoService: Preloading video: $videoId');
      // This could be extended to actually preload video data
      // For now, just log the preload request
      debugPrint('✅ VideoService: Video preload requested: $videoId');
    } catch (e) {
      debugPrint('❌ VideoService: Error preloading video: $e');
    }
  }

  /// Fetch "For You" videos (public videos) - returns a result object with videos and pagination info
  Future<Map<String, dynamic>> fetchForYouVideos({
    int? pageSize,
    dynamic lastDocument,
  }) async {
    try {
      debugPrint('🎬 VideoService: Fetching For You videos...');

      // 🔍 FIX: Ensure videos are loaded first
      if (state.isEmpty) {
        debugPrint(
            '⚠️ VideoService: No videos in state, loading videos first...');
        await loadAllVideos();
      }

      // Get all videos from current state
      final allVideos = state;
      debugPrint('🎬 VideoService: Total videos in state: ${allVideos.length}');

      // Filter for public, published videos only
      final forYouVideos = allVideos
          .where((video) =>
                  !video.isDraft && // Only published videos
                  video.videoURL.isNotEmpty && // Must have video URL
                  video.creator.id.isNotEmpty // Must have creator
              )
          .toList();

      debugPrint(
          '✅ VideoService: Found ${forYouVideos.length} For You videos (filtered from ${allVideos.length} total)');

      // Log first few videos for debugging
      if (forYouVideos.isNotEmpty) {
        for (int i = 0; i < forYouVideos.length && i < 3; i++) {
          final video = forYouVideos[i];
          debugPrint(
              '🎬 For You Video ${i + 1}: ${video.id} by ${video.creator.displayName} - ${video.videoURL.isNotEmpty ? "HAS URL" : "NO URL"}');
        }
      } else {
        debugPrint('⚠️ VideoService: No For You videos found! Check:');
        debugPrint('   1. Are videos published (status == "published")?');
        debugPrint('   2. Are videos public (privacy == "Everyone")?');
        debugPrint('   3. Do videos have videoUrl field?');
        debugPrint('   4. Do videos have userId/creatorId field?');
      }

      return {
        'videos': forYouVideos,
        'lastDocument': null, // No pagination for now
      };
    } catch (e) {
      debugPrint('❌ VideoService: Error fetching For You videos: $e');
      return {
        'videos': <HomeVideo>[],
        'lastDocument': null,
      };
    }
  }

  /// Fetch following videos (from users the current user follows) - returns a result object
  Future<Map<String, dynamic>> fetchFollowingVideos({
    List<String>? followingIds,
    int? pageSize,
    dynamic lastDocument,
  }) async {
    try {
      debugPrint('🎬 VideoService: Fetching Following videos...');

      // For now, return all videos (this could be enhanced to filter by following relationships)
      final allVideos = state;
      final followingVideos = allVideos
          .where((video) => !video.isDraft // Only published videos
              )
          .toList();

      debugPrint(
          '✅ VideoService: Found ${followingVideos.length} Following videos');
      return {
        'videos': followingVideos,
        'lastDocument': null, // No pagination for now
      };
    } catch (e) {
      debugPrint('❌ VideoService: Error fetching Following videos: $e');
      return {
        'videos': <HomeVideo>[],
        'lastDocument': null,
      };
    }
  }

  /// Toggle like status for a video
  Future<bool> toggleLike(String videoId) async {
    try {
      debugPrint('🎬 VideoService: Toggling like for video: $videoId');

      final currentVideos = List<HomeVideo>.from(state);
      final index = currentVideos.indexWhere((video) => video.id == videoId);

      if (index != -1) {
        final video = currentVideos[index];
        final newIsLiked = !video.isLiked;
        final newLikeCount = newIsLiked ? video.likes + 1 : video.likes - 1;

        currentVideos[index] = video.copyWith(
          isLiked: newIsLiked,
          likes: newLikeCount,
        );

        state = currentVideos;
        debugPrint('✅ VideoService: Like toggled for video: $videoId');
        return newIsLiked;
      }
      return false;
    } catch (e) {
      debugPrint('❌ VideoService: Error toggling like: $e');
      return false;
    }
  }

  /// Get videos by their IDs
  Future<List<HomeVideo>> getVideosByIds(List<String> videoIds) async {
    try {
      debugPrint('🎬 VideoService: Getting videos by IDs: $videoIds');

      final allVideos = state;
      final requestedVideos =
          allVideos.where((video) => videoIds.contains(video.id)).toList();

      debugPrint(
          '✅ VideoService: Found ${requestedVideos.length} videos by IDs');
      return requestedVideos;
    } catch (e) {
      debugPrint('❌ VideoService: Error getting videos by IDs: $e');
      return [];
    }
  }
}

// Provider for VideoService
final videoServiceProvider =
    StateNotifierProvider<VideoService, List<HomeVideo>>((ref) {
  return VideoService();
});

// Helper providers for filtered videos
final userVideosProvider =
    Provider.family<List<HomeVideo>, String>((ref, userId) {
  final allVideos = ref.watch(videoServiceProvider);
  debugPrint('🎬 userVideosProvider: Looking for userId: $userId');
  debugPrint('🎬 userVideosProvider: Total videos: ${allVideos.length}');

  final userVideos = allVideos.where((video) {
    // Filter by user ID
    final matchesUser = video.creator.id == userId;

    // Safety check: Exclude drafts (should already be filtered by VideoService, but double-check)
    final isDraft = video.isDraft == true;

    if (matchesUser && !isDraft) {
      debugPrint(
          '🎬 userVideosProvider: Found matching video: ${video.id} by ${video.creator.displayName}');
    }

    return matchesUser && !isDraft;
  }).toList();

  debugPrint(
      '🎬 userVideosProvider: Found ${userVideos.length} published videos for user $userId');
  return userVideos;
});

final categoryVideosProvider =
    Provider.family<List<HomeVideo>, String>((ref, categoryId) {
  final allVideos = ref.watch(videoServiceProvider);
  return allVideos.where((video) => video.categoryId == categoryId).toList();
});
