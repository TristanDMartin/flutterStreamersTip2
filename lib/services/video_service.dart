import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/home_video.dart';
import '../models/video_thumbnails.dart';
import '../models/user.dart' as app_user;
import '../utils/public_video_count_rules.dart';
import '../utils/video_url_resolver.dart';
import '../utils/video_health_gate.dart';
import 'real_user_data_service.dart';
import 'user_blocking_service.dart';

class VideoService extends StateNotifier<List<HomeVideo>> {
  VideoService() : super([]);

  static const int _feedDiversityWindow = 3;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RealUserDataService _userDataService = RealUserDataService();
  final Map<String, String?> _legacyOwnerCache = {};

  bool _looksLikeFirebaseUid(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 20 || trimmed.length > 40) return false;
    final uidPattern = RegExp(r'^[A-Za-z0-9]+$');
    return uidPattern.hasMatch(trimmed);
  }

  void _recordSkip(
    List<String> skippedVideoDetails,
    Map<String, int> skipReasons,
    String videoId,
    String reason,
  ) {
    skipReasons[reason] = (skipReasons[reason] ?? 0) + 1;
    skippedVideoDetails.add('$videoId -> $reason');
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadFeedCandidateDocs({
    required int preferredLimit,
    int unorderedLimit = 100,
  }) async {
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> docMap =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    Future<void> mergeQuery(
      Future<QuerySnapshot<Map<String, dynamic>>> Function() run,
      String label,
    ) async {
      try {
        final QuerySnapshot<Map<String, dynamic>> result = await run();
        debugPrint('🎬 VideoService: ${result.docs.length} videos ($label)');
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in result.docs) {
          docMap.putIfAbsent(doc.id, () => doc);
        }
      } catch (e) {
        debugPrint('⚠️ VideoService: Feed query failed ($label): $e');
      }
    }

    await mergeQuery(
      () => _firestore
          .collection('videos')
          .where('isReadyForFeed', isEqualTo: true)
          .where('status', isEqualTo: 'active')
          .where('visibility', isEqualTo: 'public')
          .orderBy('engagementScore', descending: true)
          .orderBy('publishedAt', descending: true)
          .limit(preferredLimit)
          .get(),
      'canonical isReadyForFeed query',
    );

    // If the strict query only returns a partial slice, supplement it with
    // legacy-compatible candidates instead of stopping at the first non-empty
    // result set. This keeps mobile aligned with the website's broader
    // published-video feed while still preferring canonical docs first.
    if (docMap.length < preferredLimit) {
      await mergeQuery(
        () => _firestore
            .collection('videos')
            .where('isReadyForFeed', isEqualTo: true)
            .orderBy('publishedAt', descending: true)
            .limit(preferredLimit)
            .get(),
        'isReadyForFeed, publishedAt fallback',
      );
    }

    if (docMap.length < preferredLimit) {
      await mergeQuery(
        () => _firestore
            .collection('videos')
            .where('status', whereIn: ['published', 'ready', 'active'])
            .orderBy('createdAt', descending: true)
            .limit(preferredLimit)
            .get(),
        'status whereIn fallback',
      );
    }

    if (docMap.length < preferredLimit) {
      await mergeQuery(
        () => _firestore
            .collection('videos')
            .where('status', whereIn: ['published', 'ready', 'active'])
            .limit(unorderedLimit)
            .get(),
        'status whereIn unordered fallback',
      );
    }

    if (docMap.isEmpty) {
      await mergeQuery(
        () => _firestore.collection('videos').limit(unorderedLimit).get(),
        'unordered collection fallback',
      );
    }

    return docMap.values.toList();
  }

  List<HomeVideo> _applyLightweightFeedDiversity(List<HomeVideo> videos) {
    if (videos.length <= 2) return videos;

    final remaining = List<HomeVideo>.from(videos);
    final diversified = <HomeVideo>[];

    while (remaining.isNotEmpty) {
      HomeVideo? selected;
      int selectedIndex = 0;

      for (int i = 0; i < remaining.length; i++) {
        final candidate = remaining[i];
        final recent = diversified.length <= _feedDiversityWindow
            ? diversified
            : diversified.sublist(diversified.length - _feedDiversityWindow);

        final creatorCollision =
            recent.any((video) => video.creator.id == candidate.creator.id);
        final categoryCollision = candidate.categoryId.isNotEmpty &&
            recent.any((video) => video.categoryId == candidate.categoryId);

        if (!creatorCollision && !categoryCollision) {
          selected = candidate;
          selectedIndex = i;
          break;
        }

        if (!creatorCollision && selected == null) {
          selected = candidate;
          selectedIndex = i;
        }
      }

      selected ??= remaining.first;
      diversified.add(selected);
      remaining.removeAt(selectedIndex);
    }

    return diversified;
  }

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

  Future<String?> _resolveLegacyOwnerId(Map<String, dynamic> data) async {
    final videoId = (data['id'] as String?)?.trim() ??
        (data['videoId'] as String?)?.trim() ??
        '';
    if (videoId.isNotEmpty) {
      final underscoreIndex = videoId.indexOf('_');
      if (underscoreIndex > 0) {
        final candidateOwnerId = videoId.substring(0, underscoreIndex).trim();
        if (_looksLikeFirebaseUid(candidateOwnerId)) {
          final cacheKey = 'inferred:$candidateOwnerId';
          if (_legacyOwnerCache.containsKey(cacheKey)) {
            final cached = _legacyOwnerCache[cacheKey];
            if (cached != null && cached.isNotEmpty) return cached;
          } else {
            try {
              final userDoc = await _firestore
                  .collection('users')
                  .doc(candidateOwnerId)
                  .get();
              final normalizedOwnerId =
                  userDoc.exists ? candidateOwnerId : null;
              _legacyOwnerCache[cacheKey] = normalizedOwnerId;
              if (normalizedOwnerId != null && normalizedOwnerId.isNotEmpty) {
                return normalizedOwnerId;
              }
            } catch (_) {
              _legacyOwnerCache[cacheKey] = null;
            }
          }
        }
      }

      // Avoid a collectionGroup + FieldPath.documentId fallback here. On iOS
      // Firestore can emit a native ObjC exception for legacy collection-group
      // document-id comparisons even when Dart catches the failure, which makes
      // startup/profile browsing look unstable in device logs.
    }

    final usernameCandidates = <String>{
      (data['creatorUsername'] as String?)?.trim() ?? '',
      (data['username'] as String?)?.trim() ?? '',
      (data['creator'] as String?)?.trim() ?? '',
      (data['handle'] as String?)?.trim() ?? '',
    }..removeWhere((value) => value.isEmpty);

    for (final username in usernameCandidates) {
      final cacheKey = 'username:$username';
      if (_legacyOwnerCache.containsKey(cacheKey)) {
        final cached = _legacyOwnerCache[cacheKey];
        if (cached != null && cached.isNotEmpty) return cached;
        continue;
      }

      try {
        final usernameDoc =
            await _firestore.collection('usernames').doc(username).get();
        final uid = usernameDoc.data()?['uid'] as String?;
        final normalizedUid = uid?.trim();
        _legacyOwnerCache[cacheKey] =
            normalizedUid != null && normalizedUid.isNotEmpty
                ? normalizedUid
                : null;
        if (normalizedUid != null && normalizedUid.isNotEmpty) {
          return normalizedUid;
        }
      } catch (_) {
        _legacyOwnerCache[cacheKey] = null;
      }
    }

    final displayNameCandidates = <String>{
      (data['creatorName'] as String?)?.trim() ?? '',
      (data['displayName'] as String?)?.trim() ?? '',
      (data['creatorDisplayName'] as String?)?.trim() ?? '',
    }..removeWhere((value) => value.isEmpty);

    for (final displayName in displayNameCandidates) {
      final cacheKey = 'display:$displayName';
      if (_legacyOwnerCache.containsKey(cacheKey)) {
        final cached = _legacyOwnerCache[cacheKey];
        if (cached != null && cached.isNotEmpty) return cached;
        continue;
      }

      try {
        final snapshot = await _firestore
            .collection('users')
            .where('displayName', isEqualTo: displayName)
            .limit(1)
            .get();
        final uid = snapshot.docs.isNotEmpty ? snapshot.docs.first.id : null;
        _legacyOwnerCache[cacheKey] =
            uid != null && uid.isNotEmpty ? uid : null;
        if (uid != null && uid.isNotEmpty) {
          return uid;
        }
      } catch (_) {
        _legacyOwnerCache[cacheKey] = null;
      }
    }

    return null;
  }

  /// Load all videos from Firestore and store them in memory
  Future<void> loadAllVideos() async {
    try {
      debugPrint('🎬 VideoService: ========== LOADING ALL VIDEOS ==========');

      // 🔥 CRITICAL FIX: Check if Firebase is initialized before proceeding
      if (Firebase.apps.isEmpty) {
        debugPrint(
            '⚠️ VideoService: Firebase not initialized yet, skipping video load');
        state = [];
        return;
      }

      // Check authentication first
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint(
            '❌ VideoService: User not authenticated, cannot load videos');
        debugPrint('   💡 User must be logged in to load videos');
        return;
      }
      debugPrint('✅ VideoService: User authenticated: ${user.uid}');

      final blockedUserIds = await UserBlockingService().getBlockedUsers();
      if (blockedUserIds.isNotEmpty) {
        debugPrint(
            '🚫 VideoService: Filtering ${blockedUserIds.length} blocked creators from feed');
      }

      const limitCount = 20;
      const unorderedLimitCount = 100;
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> candidateDocs =
          await _loadFeedCandidateDocs(
        preferredLimit: limitCount,
        unorderedLimit: unorderedLimitCount,
      );
      if (candidateDocs.isNotEmpty) {
        debugPrint(
            '🎬 VideoService: ${candidateDocs.length} videos (merged candidate snapshot)');
      } else {
        debugPrint('🎬 VideoService: 0 videos (unordered collection fallback)');
      }

      // In-memory sort: engagementScore DESC → publishedAt DESC → createdAt DESC.
      // Applies when the fallback query ran without the canonical ordering.
      final docsList =
          List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(candidateDocs);
      docsList.sort((a, b) {
        final aData = a.data();
        final bData = b.data();
        final aScore = (aData['engagementScore'] as num?)?.toDouble() ?? 0.0;
        final bScore = (bData['engagementScore'] as num?)?.toDouble() ?? 0.0;
        if (bScore != aScore) return bScore.compareTo(aScore);
        final aTs = aData['publishedAt'] ?? aData['createdAt'];
        final bTs = bData['publishedAt'] ?? bData['createdAt'];
        final aMs = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
        final bMs = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
        return bMs.compareTo(aMs);
      });
      debugPrint(
          '🎬 VideoService: Processing ${docsList.length} videos from Firestore (newest first)');
      for (int i = 0; i < docsList.length && i < 5; i++) {
        final doc = docsList[i];
        final data = doc.data();
        data['id'] = doc.id;
        debugPrint(
            '🎬 Video ${i + 1}: ID=${doc.id}, status=${data['status']}, updatedAt=${data['updatedAt'] != null ? 'YES' : 'NO'}, videoUrl=${(data['videoUrl'] ?? data['videoURL'] ?? data['video_url']) != null ? 'YES' : 'NO'}');
      }
      final videos = <HomeVideo>[];
      int processedCount = 0;
      int skippedCount = 0;
      final skipReasons = <String, int>{};
      final skippedVideoDetails = <String>[];

      for (final doc in docsList) {
        final data = doc.data();
        data['id'] = doc.id;

        debugPrint(
            '🎬 VideoService: Processing video ${doc.id}: status=${data['status']}, privacy=${data['privacy']}, ownerId: ${getOwnerId(data)}');

        if (!videoIsPublicFeedVisible(data)) {
          final reason = 'not public-visible';
          _recordSkip(skippedVideoDetails, skipReasons, doc.id, reason);
          skippedCount++;
          continue;
        }

        // Status gate — accept spec enum ('active') and legacy values for
        // backward compat with videos written before schema migration.
        final status = data['status'] as String?;
        final isActiveStatus =
            status == 'active' || status == 'published' || status == 'ready';
        if (!isActiveStatus) {
          final reason = 'status: $status';
          _recordSkip(skippedVideoDetails, skipReasons, doc.id, reason);
          skippedCount++;
          continue;
        }

        // isReadyForFeed gate — hard-skip if explicitly false.
        // null → legacy video; let it through for backward compat.
        if (data['isReadyForFeed'] == false) {
          _recordSkip(
            skippedVideoDetails,
            skipReasons,
            doc.id,
            'isReadyForFeed',
          );
          skippedCount++;
          continue;
        }

        // Visibility/privacy gate — spec §3: only public videos in global feed.
        // Handle both new 'visibility' field and legacy 'privacy' field.
        final visibility = data['visibility'] as String?;
        final privacy = data['privacy'] as String?;
        final isPublic = visibility == 'public' ||
            privacy == 'Everyone' ||
            privacy == 'Public' ||
            (visibility == null && privacy == null); // legacy: null = public
        if (!isPublic) {
          _recordSkip(skippedVideoDetails, skipReasons, doc.id, 'visibility');
          skippedCount++;
          continue;
        }

        // Canonical owner: single source of truth for filtering
        final userId = getOwnerId(data) ?? await _resolveLegacyOwnerId(data);
        if (userId == null) {
          _recordSkip(skippedVideoDetails, skipReasons, doc.id, 'no userId');
          skippedCount++;
          debugPrint(
              '🎬 VideoService: Skipping video ${doc.id} - no owner field');
          continue;
        }
        if (blockedUserIds.contains(userId)) {
          _recordSkip(
            skippedVideoDetails,
            skipReasons,
            doc.id,
            'blocked creator',
          );
          skippedCount++;
          continue;
        }

        // Create thumbnails object from legacy thumbnailUrl (support both field variants)
        VideoThumbnails? thumbnails;
        final thumbnailUrl =
            (data['thumbnailUrl'] ?? data['thumbnailURL']) as String?;

        final videoUrl = resolveVideoUrl(data);
        final playableResult =
            await VideoHealthGate.instance.resolvePlayableSource(
          doc.id,
          cachedData: data,
          fallbackUrl: videoUrl.isEmpty ? null : videoUrl,
        );
        if (playableResult is! Playable) {
          final unplayable = playableResult as Unplayable;
          final reason = unplayable.reason;
          final info = unplayable.debugInfo;
          _recordSkip(skippedVideoDetails, skipReasons, doc.id, reason);
          skippedCount++;
          if (kDebugMode) {
            final raw =
                data['videoUrl'] ?? data['videoURL'] ?? data['video_url'];
            final urlStr = raw is String ? raw : '';
            final host =
                urlStr.isNotEmpty ? Uri.tryParse(urlStr)?.host ?? '?' : 'none';
            debugPrint(
                '🎬 VideoService: SKIP ${doc.id} (unplayable): reason=$reason, '
                'status=$status, hasMux=${data['muxPlaybackId'] != null}, '
                'videoUrlHost=$host, raw=${raw != null ? "YES" : "NO"}');
            VideoHealthGate.instance.logUnplayableVideo(
              doc.id,
              reason,
              {...info, 'videoUrlHost': host},
            );
          }
          continue;
        }
        final playableUrl = playableResult.url;

        debugPrint('🎬 VideoService: ✅ Playable ${doc.id} - gate-approved URL');

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
            videoURL: playableUrl,
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
            '🎬 VideoService: Video ${doc.id} - thumbnailUrl: "$thumbnailUrl", playableUrl: "$playableUrl"');
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
          videoURL: playableUrl,
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

      // Log summary after processing all videos (diagnostic for "new uploads not showing")
      final totalFetched = docsList.length;
      debugPrint('🎬 VideoService: ========== FEED DIAGNOSTIC ==========');
      debugPrint(
          '   totalFetched: $totalFetched, playableCount: $processedCount, '
          'skippedCount: $skippedCount');
      if (skipReasons.isNotEmpty) {
        debugPrint('   skipReasons: $skipReasons');
        if (skippedVideoDetails.isNotEmpty) {
          final capped = skippedVideoDetails.take(25).toList();
          final suffix = skippedVideoDetails.length > capped.length
              ? '/${skippedVideoDetails.length}'
              : '';
          debugPrint('   skippedVideoDetails (${capped.length}$suffix):');
          for (final detail in capped) {
            debugPrint('     - $detail');
          }
        }
        if (skippedCount > 0 && processedCount == 0) {
          final top =
              skipReasons.entries.reduce((a, b) => a.value > b.value ? a : b);
          final hint = switch (top.key) {
            'processing' => 'webhook not updating status→ready',
            'raw_or_original_forbidden' => 'raw/isOriginal flags',
            'firebase_storage_deprecated' => 'legacy Firebase, migrate to Mux',
            'image_url_not_video' => 'placehold.co/placeholder URL',
            _ => 'check gate rules',
          };
          debugPrint(
              '   ⚠️ All skipped. Top: "${top.key}" (${top.value}x) → $hint');
        }
      }

      // Remove duplicates based on video ID
      final uniqueVideos = <String, HomeVideo>{};
      for (final video in videos) {
        if (video.id.isNotEmpty) {
          uniqueVideos[video.id] = video;
        }
      }

      // Keep order from docsList (newest updated/created first); dedupe preserves first occurrence
      final deduplicatedVideos = uniqueVideos.values.toList();
      final diversifiedVideos =
          _applyLightweightFeedDiversity(deduplicatedVideos);

      state = diversifiedVideos;
      debugPrint(
          '✅ VideoService: Loaded ${diversifiedVideos.length} unique videos (removed ${videos.length - deduplicatedVideos.length} duplicates)');

      // 🔍 DIAGNOSTIC: Log summary of loaded videos and statistics
      if (diversifiedVideos.isEmpty) {
        debugPrint('⚠️ VideoService: ⚠️⚠️⚠️ NO VIDEOS LOADED! ⚠️⚠️⚠️');
        debugPrint(
            '   Check the logs above to see why videos were filtered out.');
        debugPrint('   Common issues:');
        debugPrint('   1. Webhook not firing → status stuck at processing');
        debugPrint('   2. muxPlaybackId null → gate rejects');
        debugPrint('   3. visibility/privacy not public');
        debugPrint('   4. raw/isOriginal flags set');
        debugPrint('   5. placehold.co as videoUrl');

        // Additional diagnostic: Count total videos in Firestore
        try {
          final totalSnapshot = await _firestore
              .collection('videos')
              .limit(100)
              .get(); // Reduced to prevent memory issues
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
            if (getOwnerId(data) == null) {
              missingFields['ownerId'] = (missingFields['ownerId'] ?? 0) + 1;
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
            '🎬 VideoService: Successfully loaded ${diversifiedVideos.length} videos');
        debugPrint('📊 Video summary:');
        for (int i = 0; i < diversifiedVideos.length && i < 10; i++) {
          final video = diversifiedVideos[i];
          debugPrint(
              '   ${i + 1}. ${video.id} by ${video.creator.displayName} - ${video.videoURL.isNotEmpty ? "✅ HAS URL" : "❌ NO URL"}');
        }
        if (diversifiedVideos.length > 10) {
          debugPrint('   ... and ${diversifiedVideos.length - 10} more');
        }

        // Log count of videos filtered out
        final totalBeforeFilter = candidateDocs.length;
        final totalAfterFilter = diversifiedVideos.length;
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

  /// Fetches all of [profileUserId]'s public feed-eligible videos and merges them
  /// into [state]. The home feed only loads a small global slice; without this,
  /// [userVideosProvider] under-counts profile grids vs [reconcilePostCount].
  Future<void> mergeProfileVideosForUser(String profileUserId) async {
    try {
      if (Firebase.apps.isEmpty) {
        return;
      }
      final user = _auth.currentUser;
      if (user == null) {
        return;
      }
      final List<String> blockedUserIds =
          await UserBlockingService().getBlockedUsers();
      if (blockedUserIds.contains(profileUserId)) {
        return;
      }
      final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> docMap =
          <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final String field in <String>['userId', 'user_id', 'creatorId']) {
        final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
            .collection('videos')
            .where(field, isEqualTo: profileUserId)
            .get();
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs) {
          docMap[doc.id] = doc;
        }
      }
      final List<HomeVideo> built = <HomeVideo>[];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in docMap.values) {
        final Map<String, dynamic> data = doc.data();
        if (!videoOwnerIsUser(data, profileUserId)) {
          continue;
        }
        if (!videoCountsAsPublicPostForStats(data)) {
          continue;
        }
        try {
          if (!await videoIsPlayableForProfileCount(doc.id, data)) {
            continue;
          }
        } catch (_) {
          continue;
        }
        final HomeVideo? video = await _homeVideoFromDocAfterPlayableGate(
          doc,
          blockedUserIds,
        );
        if (video != null) {
          built.add(video);
        }
      }
      _mergeProfileVideosIntoState(built);
      if (kDebugMode) {
        debugPrint(
          '🎬 VideoService: mergeProfileVideosForUser($profileUserId) → '
          '${built.length} videos merged into state (total ${state.length})',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ VideoService: mergeProfileVideosForUser failed: $e');
      debugPrint('$stackTrace');
    }
  }

  void _mergeProfileVideosIntoState(List<HomeVideo> profileVideos) {
    if (profileVideos.isEmpty) {
      return;
    }
    final Map<String, HomeVideo> profileById = <String, HomeVideo>{
      for (final HomeVideo v in profileVideos) v.id: v,
    };
    final List<HomeVideo> next = <HomeVideo>[];
    final Set<String> seen = <String>{};
    for (final HomeVideo v in state) {
      final HomeVideo u = profileById[v.id] ?? v;
      next.add(u);
      seen.add(u.id);
    }
    for (final HomeVideo v in profileVideos) {
      if (!seen.contains(v.id)) {
        next.add(v);
      }
    }
    state = next;
  }

  Future<HomeVideo?> _homeVideoFromDocAfterPlayableGate(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    List<String> blockedUserIds,
  ) async {
    final Map<String, dynamic> data = doc.data();
    final String? ownerId = getOwnerId(data);
    if (ownerId == null || blockedUserIds.contains(ownerId)) {
      return null;
    }
    VideoThumbnails? thumbnails;
    final String? thumbnailUrl =
        (data['thumbnailUrl'] ?? data['thumbnailURL']) as String?;
    final String videoUrl = resolveVideoUrl(data);
    final dynamic playableResult =
        await VideoHealthGate.instance.resolvePlayableSource(
      doc.id,
      cachedData: data,
      fallbackUrl: videoUrl.isEmpty ? null : videoUrl,
    );
    if (playableResult is! Playable) {
      return null;
    }
    final String playableUrl = playableResult.url;
    final app_user.User? creator = await _userDataService.getUserById(ownerId);
    if (creator == null) {
      final app_user.User placeholderCreator = app_user.User(
        id: ownerId,
        username:
            'user_${ownerId.length > 10 ? ownerId.substring(0, 10) : ownerId}',
        displayName: 'User',
        avatarURL: null,
        bio: null,
        hashtags: const <String>[],
      );
      VideoThumbnails? placeholderThumbnails;
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        placeholderThumbnails = VideoThumbnails(
          urls: <int, String>{
            360: thumbnailUrl,
            540: thumbnailUrl,
            720: thumbnailUrl,
          },
          generatedAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
        );
      }
      return HomeVideo(
        id: doc.id,
        creator: placeholderCreator,
        videoURL: playableUrl,
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
          data['metadata']?['duration'] ?? data['duration'],
        ),
        isDraft: false,
        createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      );
    }
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      thumbnails = VideoThumbnails(
        urls: <int, String>{
          360: thumbnailUrl,
          540: thumbnailUrl,
          720: thumbnailUrl,
        },
        generatedAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      );
    }
    if (thumbnails == null) {
      final Map<String, dynamic>? thumbnailsData =
          data['thumbnails'] as Map<String, dynamic>?;
      if (thumbnailsData != null && thumbnailsData['urls'] != null) {
        final Map<String, dynamic> urlsData =
            thumbnailsData['urls'] as Map<String, dynamic>;
        final Map<int, String> urls = <int, String>{};
        urlsData.forEach((String key, dynamic value) {
          final int? intKey = int.tryParse(key);
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
        }
      }
    }
    return HomeVideo(
      id: doc.id,
      creator: creator,
      videoURL: playableUrl,
      thumbnailURL: thumbnailUrl,
      thumbnails: thumbnails,
      caption:
          data['caption'] ?? data['title'] ?? data['description'] ?? 'Untitled',
      categoryId: data['category'] ?? data['categoryId'] ?? 'general',
      views: data['views']?.toInt() ?? 0,
      likes: data['likes']?.toInt() ?? 0,
      comments: data['comments']?.toInt() ?? 0,
      duration:
          _parseDuration(data['metadata']?['duration'] ?? data['duration']),
      isDraft: false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
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
          '✅ VideoService: Removed video $videoId from state ($removedCount -> $newCount)');
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
      final snapshot = await _firestore
          .collection('videos')
          .limit(100)
          .get(); // Reduced to prevent memory issues

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

            if (getOwnerId(data) != null) {
              diagnostics['publishedPublicWithCreator'] =
                  (diagnostics['publishedPublicWithCreator'] as int) + 1;
            }
          }
        }

        final videoUrl = data['videoUrl'] ?? data['videoURL'];
        if (videoUrl == null || (videoUrl as String).isEmpty) {
          (diagnostics['missingFields'] as Map<String, int>)['videoUrl'] =
              ((diagnostics['missingFields'] as Map<String, int>)['videoUrl'] ??
                      0) +
                  1;
        }
        if (getOwnerId(data) == null) {
          (diagnostics['missingFields'] as Map<String, int>)['ownerId'] =
              ((diagnostics['missingFields'] as Map<String, int>)['ownerId'] ??
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
  /// Spec: 20 initial, 10 load more, cursor-based
  Future<Map<String, dynamic>> fetchForYouVideos({
    int? pageSize,
    dynamic lastDocument,
  }) async {
    try {
      debugPrint('🎬 VideoService: Fetching For You videos...');

      final isLoadMore = lastDocument != null;
      final limit = isLoadMore ? (pageSize ?? 10) : (pageSize ?? 20);

      if (isLoadMore) {
        DocumentSnapshot<Map<String, dynamic>>? startAfterDoc;
        if (lastDocument is DocumentSnapshot<Map<String, dynamic>>) {
          startAfterDoc = lastDocument;
        } else if (lastDocument is Map && lastDocument['lastDoc'] != null) {
          startAfterDoc =
              lastDocument['lastDoc'] as DocumentSnapshot<Map<String, dynamic>>;
        }
        return await _fetchForYouPaginated(
          limit: limit,
          startAfter: startAfterDoc,
        );
      }

      return await _fetchForYouPaginated(limit: limit, startAfter: null);
    } catch (e) {
      debugPrint('❌ VideoService: Error fetching For You videos: $e');
      return {
        'videos': <HomeVideo>[],
        'lastDocument': null,
      };
    }
  }

  Future<Map<String, dynamic>> _fetchForYouPaginated({
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'videos': <HomeVideo>[], 'lastDocument': null};
      }

      final blockedUserIds = await UserBlockingService().getBlockedUsers();

      // Canonical paginated query — spec §4.
      Query<Map<String, dynamic>> baseQuery;
      try {
        baseQuery = _firestore
            .collection('videos')
            .where('isReadyForFeed', isEqualTo: true)
            .where('status', isEqualTo: 'active')
            .where('visibility', isEqualTo: 'public')
            .orderBy('engagementScore', descending: true)
            .orderBy('publishedAt', descending: true)
            .limit(limit);
      } catch (_) {
        baseQuery = _firestore
            .collection('videos')
            .where('isReadyForFeed', isEqualTo: true)
            .orderBy('publishedAt', descending: true)
            .limit(limit);
      }

      Query<Map<String, dynamic>> query = startAfter != null
          ? baseQuery.startAfterDocument(startAfter)
          : baseQuery;

      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await query.get();
      } catch (_) {
        // Fallback: legacy status filter, no isReadyForFeed index.
        Query<Map<String, dynamic>> fallback = _firestore
            .collection('videos')
            .where('status', whereIn: ['published', 'ready', 'active'])
            .orderBy('createdAt', descending: true)
            .limit(limit);
        if (startAfter != null) {
          fallback = fallback.startAfterDocument(startAfter);
        }
        snapshot = await fallback.get();
      }

      final docsList = snapshot.docs;
      final videos = <HomeVideo>[];

      for (final doc in docsList) {
        final data = doc.data();
        final userId = getOwnerId(data);
        if (userId == null || blockedUserIds.contains(userId)) continue;

        final status = data['status'] as String?;
        final isActiveStatus =
            status == 'active' || status == 'published' || status == 'ready';
        if (!isActiveStatus) continue;

        if (data['isReadyForFeed'] == false) continue;

        // Visibility gate — handle both field names.
        final visibility = data['visibility'] as String?;
        final privacyField = data['privacy'] as String?;
        final isPublic = visibility == 'public' ||
            privacyField == 'Everyone' ||
            privacyField == 'Public' ||
            (visibility == null && privacyField == null);
        if (!isPublic) continue;

        final videoUrl = resolveVideoUrl(data);
        final playableResult =
            await VideoHealthGate.instance.resolvePlayableSource(
          doc.id,
          cachedData: data,
          fallbackUrl: videoUrl.isEmpty ? null : videoUrl,
        );
        if (playableResult is! Playable) continue;

        final creator = await _userDataService.getUserById(userId);
        if (creator == null) continue;

        final thumbnailUrl =
            (data['thumbnailUrl'] ?? data['thumbnailURL']) as String?;
        final video = HomeVideo(
          id: doc.id,
          creator: creator,
          videoURL: playableResult.url,
          thumbnailURL: thumbnailUrl,
          thumbnails: null,
          caption: data['caption'] ?? data['title'] ?? 'Untitled',
          categoryId: data['category'] ?? data['categoryId'] ?? 'general',
          views: data['views']?.toInt() ?? 0,
          likes: data['likes']?.toInt() ?? 0,
          comments: data['comments']?.toInt() ?? 0,
          duration:
              _parseDuration(data['metadata']?['duration'] ?? data['duration']),
          isDraft: false,
          createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
        );
        videos.add(video);
      }

      final lastDoc = docsList.isNotEmpty ? docsList.last : null;

      return {
        'videos': videos,
        'lastDocument': lastDoc,
      };
    } catch (e) {
      debugPrint('❌ VideoService: _fetchForYouPaginated error: $e');
      return {'videos': <HomeVideo>[], 'lastDocument': null};
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
final videoServiceStateProvider =
    StateNotifierProvider<VideoService, List<HomeVideo>>((ref) {
  return VideoService();
});

// Helper providers for filtered videos
final userVideosProvider =
    Provider.family<List<HomeVideo>, String>((ref, userId) {
  final allVideos = ref.watch(videoServiceStateProvider);
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
  final allVideos = ref.watch(videoServiceStateProvider);
  return allVideos.where((video) => video.categoryId == categoryId).toList();
});
