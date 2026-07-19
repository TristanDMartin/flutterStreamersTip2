import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/home_video.dart';
import '../models/video_thumbnails.dart';
import '../models/user.dart' as app_user;
import '../utils/profile_grid_video_order.dart';
import '../utils/category_schema.dart';
import '../utils/video_document_rules.dart';
import '../utils/video_url_resolver.dart';
import '../utils/video_caption_resolver.dart';
import '../utils/video_health_gate.dart';
import '../features/home/domain/feed_stats.dart';
import '../features/home/domain/home_feed_mutator.dart';
import '../utils/home_video_from_firestore.dart';
import '../utils/firestore_map_readers.dart';
import '../utils/like_interaction_boundary.dart';
import '../utils/video_feed_diagnostics.dart';
import '../utils/video_metadata_backfill.dart';
import 'real_user_data_service.dart';
import 'user_blocking_service.dart';

class VideoService extends StateNotifier<List<HomeVideo>> {
  VideoService() : super([]);

  static const int _feedDiversityWindow = 3;

  bool isHydratingFeed = false;
  bool isMergingProfileVideos = false;
  Future<void>? _loadAllVideosInFlight;
  final Map<String, Future<bool>> _mergeProfileVideosInFlight =
      <String, Future<bool>>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _ownerVideosSubscription;
  String? _ownerVideosListenerUserId;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RealUserDataService _userDataService = RealUserDataService();
  final Map<String, String?> _legacyOwnerCache = {};

  app_user.User _withCanonicalUserId(app_user.User user, String ownerId) {
    if (user.id == ownerId) {
      return user;
    }
    return app_user.User(
      id: ownerId,
      username: user.username,
      displayName: user.displayName,
      bio: user.bio,
      avatarURL: user.avatarURL,
      onlineStatus: user.onlineStatus,
      hashtags: user.hashtags,
      aiSelf: user.aiSelf,
      postCount: user.postCount,
      followerCount: user.followerCount,
      followingCount: user.followingCount,
      calendarEvents: user.calendarEvents,
      privacy: user.privacy,
      pinnedVideoIds: user.pinnedVideoIds,
      role: user.role,
    );
  }

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
          final Map<String, dynamic> data =
              Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          final String? rejectReason = rejectFeedCandidateBeforeHydration(
            data,
            readOwnerId: getOwnerId,
          );
          if (rejectReason != null) {
            logFeedVideoCandidate(
              context: 'home_feed_query:$label',
              videoId: doc.id,
              data: data,
              rejectReason: rejectReason,
            );
            continue;
          }
          logFeedVideoCandidate(
            context: 'home_feed_query:$label',
            videoId: doc.id,
            data: data,
          );
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
          .where('status', whereIn: ['ready', 'active', 'published'])
          .where('visibility', isEqualTo: 'public')
          .orderBy('publishedAt', descending: true)
          .limit(preferredLimit)
          .get(),
      'canonical newest isReadyForFeed query',
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

    final List<HomeVideo> freshUploads =
        videos.where((HomeVideo v) => isFreshUpload(v)).toList();
    final List<HomeVideo> remainder =
        videos.where((HomeVideo v) => !isFreshUpload(v)).toList();
    if (remainder.length <= 2) {
      return videos;
    }

    final remaining = List<HomeVideo>.from(remainder);
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

    return [...freshUploads, ...diversified];
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

  Future<String?> _resolveOwnerFromFeedIndex(String videoId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> forYouSnap = await _firestore
          .collection('feeds')
          .doc('for_you')
          .collection('videos')
          .doc(videoId)
          .get();
      final String? uid = forYouSnap.data()?['userId'] as String?;
      if (uid != null && uid.trim().isNotEmpty) {
        return uid.trim();
      }
    } catch (_) {}
    return null;
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

  Future<HomeVideo?> homeVideoFromRealtimeFeedDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required List<String> blockedUserIds,
  }) async {
    final Map<String, dynamic> data = Map<String, dynamic>.from(doc.data());
    data['id'] = doc.id;
    data['videoId'] = doc.id;

    if (isVideoDeletedFromFirestore(data)) {
      return null;
    }
    final visibility = data['visibility'] as String?;
    final privacy = data['privacy'] as String?;
    final bool isPublic = visibility == 'public' ||
        privacy == 'Everyone' ||
        privacy == 'Public' ||
        (visibility == null && privacy == null);
    if (!isPublic) return null;

    final String? resolvedUserId = getOwnerId(data) ??
        await _resolveLegacyOwnerId(data) ??
        await _resolveOwnerFromFeedIndex(doc.id);
    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      return null;
    }
    if (blockedUserIds.contains(resolvedUserId)) {
      return null;
    }
    final String userId = resolvedUserId;

    final String status =
        ((data['status'] as String?) ?? 'processing').toLowerCase();
    if (status == 'failed' || status == 'upload_failed') {
      return null;
    }
    if (status == 'uploading' || status == 'processing') {
      return _processingHomeVideoFromDoc(data, doc.id, userId);
    }

    if (!isVideoVisibleInFeed(data) || !isVideoEligibleForPublicFeed(data)) {
      return null;
    }

    final String? playbackUrl = resolveReadyPlaybackUrl(data);
    if (playbackUrl == null) {
      return null;
    }

    final playableResult = await VideoHealthGate.instance.resolvePlayableSource(
      doc.id,
      cachedData: data,
      fallbackUrl: playbackUrl,
    );
    if (playableResult is! Playable) {
      return null;
    }

    scheduleVideoMetadataBackfill(
      firestore: _firestore,
      videoId: doc.id,
      cachedData: data,
    );

    return _homeVideoFromRealtimeData(
      data,
      doc.id,
      userId,
      playableUrl: playableResult.url,
    );
  }

  Future<List<HomeVideo>> buildRealtimePublicFeedVideos(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final blockedUserIds = await UserBlockingService().getBlockedUsers();
    final Map<String, HomeVideo> unique = <String, HomeVideo>{};

    for (final doc in docs) {
      final HomeVideo? video = await homeVideoFromRealtimeFeedDoc(
        doc,
        blockedUserIds: blockedUserIds,
      );
      if (video != null && video.id.isNotEmpty) {
        unique.putIfAbsent(video.id, () => video);
      }
    }

    final List<HomeVideo> built = unique.values.toList(growable: false);
    state = mergeHomeFeedPreserveOrder(
      existing: state,
      incoming: built,
    );
    return built;
  }

  Future<HomeVideo> _processingHomeVideoFromDoc(
    Map<String, dynamic> data,
    String videoId,
    String userId,
  ) async {
    final app_user.User loadedCreator =
        await _userDataService.getUserById(userId) ??
            app_user.User(
              id: userId,
              username: 'creator',
              displayName: 'Creator',
              avatarURL: null,
              bio: null,
              hashtags: const <String>[],
            );
    final app_user.User creator = _withCanonicalUserId(loadedCreator, userId);
    return HomeVideo(
      id: videoId,
      creator: creator,
      videoURL: '',
      thumbnailURL: (data['thumbnailUrl'] ?? data['thumbnailURL']) as String?,
      caption: resolveVideoCaptionFromFirestoreData(data),
      overlayCaption: resolveVideoOverlayCaptionFromFirestoreData(data),
      categoryId: categoryIdFromVideoDocument(data),
      views: readVideoViewCountFromFirestore(data),
      likes: readVideoLikeCountFromFirestore(data),
      comments: readVideoCommentCountFromFirestore(data),
      duration:
          _parseDuration(data['metadata']?['duration'] ?? data['duration']),
      isDraft: false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      status: (data['status'] as String?) ?? 'processing',
      visibility: (data['visibility'] as String?) ?? 'public',
      isDeleted: data['isDeleted'] == true || data['deleted'] == true,
      deletedAt: data['deletedAt'] as Timestamp?,
    );
  }

  Future<HomeVideo?> _homeVideoFromDocForProfileList(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    List<String> blockedUserIds,
  ) async {
    final Map<String, dynamic> data = Map<String, dynamic>.from(doc.data());
    final String? ownerId = getOwnerId(data);
    if (ownerId == null || blockedUserIds.contains(ownerId)) {
      return null;
    }
    final String status =
        ((data['status'] as String?) ?? 'processing').toLowerCase();
    if (status == 'failed' || status == 'upload_failed') {
      return null;
    }
    if (status == 'uploading' || status == 'processing') {
      return _processingHomeVideoFromDoc(data, doc.id, ownerId);
    }
    final HomeVideo? playable = await _homeVideoFromDocAfterPlayableGate(
      doc,
      blockedUserIds,
    );
    if (playable != null) {
      return playable;
    }
    if (isVideoProfileListStatus(status)) {
      return _processingHomeVideoFromDoc(data, doc.id, ownerId);
    }
    return null;
  }

  Query<Map<String, dynamic>> _ownerProfileVideosQuery(String userId) {
    return _firestore
        .collection('videos')
        .where('ownerId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);
  }

  Future<void> startOwnerVideosListener(String userId) async {
    if (userId.isEmpty) {
      return;
    }
    if (_ownerVideosListenerUserId == userId &&
        _ownerVideosSubscription != null) {
      return;
    }
    await stopOwnerVideosListener();
    _ownerVideosListenerUserId = userId;
    try {
      _ownerVideosSubscription =
          _ownerProfileVideosQuery(userId).snapshots().listen(
        (QuerySnapshot<Map<String, dynamic>> snapshot) {
          unawaited(_applyOwnerVideosSnapshot(userId, snapshot));
        },
        onError: (Object error) {
          if (kDebugMode) {
            debugPrint(
              '❌ VideoService: owner videos listener error for $userId: $error',
            );
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ VideoService: owner videos listener setup failed: $e',
        );
      }
    }
  }

  Future<void> stopOwnerVideosListener() async {
    await _ownerVideosSubscription?.cancel();
    _ownerVideosSubscription = null;
    _ownerVideosListenerUserId = null;
  }

  Future<void> _applyOwnerVideosSnapshot(
    String profileUserId,
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    if (LikeInteractionBoundary.isActive) {
      return;
    }
    final User? authUser = _auth.currentUser;
    if (authUser == null) {
      return;
    }
    final List<String> blockedUserIds =
        await UserBlockingService().getBlockedUsers();
    if (blockedUserIds.contains(profileUserId)) {
      return;
    }
    final List<HomeVideo> built = <HomeVideo>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final Map<String, dynamic> data = <String, dynamic>{
        ...doc.data(),
        'id': doc.id,
      };
      final String? reject = rejectProfileListCandidate(
        data,
        profileUserId,
        viewerUserId: authUser.uid,
        viewName: 'ProfileViewRealtime',
      );
      if (reject != null) {
        logVideoEligibility(
          videoId: doc.id,
          data: data,
          excludedReason: reject,
          context: 'owner_listener:$profileUserId',
        );
        continue;
      }
      final HomeVideo? video = await _homeVideoFromDocForProfileList(
        doc,
        blockedUserIds,
      );
      if (video != null) {
        built.add(video);
      }
    }
    if (built.isNotEmpty) {
      _mergeProfileVideosIntoState(built);
    }
  }

  Future<HomeVideo?> _homeVideoFromRealtimeData(
    Map<String, dynamic> data,
    String videoId,
    String userId, {
    required String playableUrl,
  }) async {
    final app_user.User? loadedCreator =
        await _userDataService.getUserById(userId);
    final app_user.User creator = _withCanonicalUserId(
      loadedCreator ?? _appUserFromVideoDocCreator(data, userId),
      userId,
    );
    final String? thumbnailUrl =
        (data['thumbnailUrl'] ?? data['thumbnailURL']) as String?;
    VideoThumbnails? thumbnails;
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      thumbnails = VideoThumbnails(
        urls: <int, String>{
          360: thumbnailUrl,
          540: thumbnailUrl,
          720: thumbnailUrl
        },
        generatedAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      );
    }
    return HomeVideo(
      id: videoId,
      creator: creator,
      videoURL: playableUrl,
      thumbnailURL: thumbnailUrl,
      thumbnails: thumbnails,
      caption: resolveVideoCaptionFromFirestoreData(data),
      overlayCaption: resolveVideoOverlayCaptionFromFirestoreData(data),
      categoryId: categoryIdFromVideoDocument(data),
      views: readVideoViewCountFromFirestore(data),
      likes: readVideoLikeCountFromFirestore(data),
      comments: readVideoCommentCountFromFirestore(data),
      duration:
          _parseDuration(data['metadata']?['duration'] ?? data['duration']),
      isDraft: false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      status: (data['status'] as String?) ?? 'ready',
      visibility: (data['visibility'] as String?) ?? 'public',
      isDeleted: data['isDeleted'] == true || data['deleted'] == true,
      deletedAt: data['deletedAt'] as Timestamp?,
    );
  }

  app_user.User _appUserFromVideoDocCreator(
    Map<String, dynamic> data,
    String userId,
  ) {
    final embedded = creatorFromVideoDoc(data, userId);
    return app_user.User(
      id: embedded.id,
      username: embedded.username,
      displayName: embedded.displayName,
      avatarURL: embedded.avatarURL,
      bio: embedded.bio,
      hashtags: embedded.hashtags,
      followerCount: embedded.followerCount,
      followingCount: embedded.followingCount,
      postCount: embedded.postCount,
      onlineStatus: embedded.onlineStatus,
    );
  }

  /// Load all videos from Firestore and store them in memory
  Future<void> loadAllVideos({String source = 'unknown'}) async {
    if (LikeInteractionBoundary.isActive) {
      LikeInteractionBoundary.reportVideoServiceReload(source: 'loadAllVideos');
      return;
    }
    if (_loadAllVideosInFlight != null) {
      VideoFeedDiagnostics.logVideoLoadSkipped(
        reason: 'in_flight_duplicate source=$source',
      );
      return _loadAllVideosInFlight!;
    }
    VideoFeedDiagnostics.logVideoLoadStart(source: source);
    _loadAllVideosInFlight = _runLoadAllVideos();
    try {
      await _loadAllVideosInFlight;
    } finally {
      _loadAllVideosInFlight = null;
    }
  }

  Future<void> _runLoadAllVideos() async {
    isHydratingFeed = true;
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

      const limitCount = 30;
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

      // In-memory sort: publishedAt DESC -> createdAt DESC.
      // Startup feed should always open on the newest ready video.
      final docsList =
          List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(candidateDocs);
      docsList.sort((a, b) {
        final aData = a.data();
        final bData = b.data();
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
      int rejectedPreHydration = 0;
      final skipReasons = <String, int>{};
      final skippedVideoDetails = <String>[];

      for (final doc in docsList) {
        final data = doc.data();
        data['id'] = doc.id;

        final String? preHydrationReject = rejectFeedCandidateBeforeHydration(
          data,
          readOwnerId: getOwnerId,
        );
        if (preHydrationReject != null) {
          _recordSkip(
            skippedVideoDetails,
            skipReasons,
            doc.id,
            preHydrationReject,
          );
          skippedCount++;
          rejectedPreHydration++;
          continue;
        }

        debugPrint(
            '🎬 VideoService: Processing video ${doc.id}: status=${data['status']}, privacy=${data['privacy']}, ownerId: ${getOwnerId(data)}');

        final status = data['status'] as String?;

        // Canonical owner: single source of truth for filtering
        final resolvedUserId = getOwnerId(data) ??
            await _resolveLegacyOwnerId(data) ??
            await _resolveOwnerFromFeedIndex(doc.id);
        if (resolvedUserId == null || resolvedUserId.isEmpty) {
          _recordSkip(
              skippedVideoDetails, skipReasons, doc.id, 'missing_owner');
          skippedCount++;
          continue;
        }
        if (blockedUserIds.contains(resolvedUserId)) {
          _recordSkip(
            skippedVideoDetails,
            skipReasons,
            doc.id,
            'blocked creator',
          );
          skippedCount++;
          continue;
        }
        final userId = resolvedUserId;

        // Create thumbnails object from legacy thumbnailUrl (support both field variants)
        VideoThumbnails? thumbnails;
        final thumbnailUrl =
            (data['thumbnailUrl'] ?? data['thumbnailURL']) as String?;

        final videoUrl = resolveReadyPlaybackUrl(data);
        if (videoUrl == null) {
          _recordSkip(
            skippedVideoDetails,
            skipReasons,
            doc.id,
            'not_ready_for_playback',
          );
          skippedCount++;
          continue;
        }
        final playableResult =
            await VideoHealthGate.instance.resolvePlayableSource(
          doc.id,
          cachedData: data,
          fallbackUrl: videoUrl,
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

        final app_user.User? loadedCreator =
            await _userDataService.getUserById(userId);
        final app_user.User creator = _withCanonicalUserId(
          loadedCreator ?? _appUserFromVideoDocCreator(data, userId),
          userId,
        );
        if (loadedCreator != null) {
          debugPrint(
              '🎬 VideoService: ✅ Creator found for ${doc.id} - ${creator.displayName} (@${creator.username})');
        }

        debugPrint(
            '🎬 VideoService: Video ${doc.id} - thumbnailUrl: "$thumbnailUrl", playableUrl: "$playableUrl"');
        debugPrint(
            '🎬 VideoService: Full video data for ${doc.id}: ${data.keys.toList()}');
        final String resolvedCaption =
            resolveVideoCaptionFromFirestoreData(data);
        if (resolvedCaption.isEmpty) {
          debugPrint(
            '📝 VideoService: videos/${doc.id} has no caption '
            '(raw="${data['caption']}", '
            'preview="${(data['metadata'] as Map?)?['preview_manual_caption']}")',
          );
        }

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

        scheduleVideoMetadataBackfill(
          firestore: _firestore,
          videoId: doc.id,
          cachedData: data,
        );

        final video = HomeVideo(
          id: doc.id,
          creator: creator,
          videoURL: playableUrl,
          thumbnailURL:
              thumbnailUrl, // Keep legacy field for backward compatibility
          thumbnails: thumbnails, // Add new thumbnails object
          caption: resolveVideoCaptionFromFirestoreData(data),
          overlayCaption: resolveVideoOverlayCaptionFromFirestoreData(data),
          categoryId: categoryIdFromVideoDocument(data),
          views: readVideoViewCountFromFirestore(data),
          likes: readVideoLikeCountFromFirestore(data),
          comments: readVideoCommentCountFromFirestore(data),
          duration:
              _parseDuration(data['metadata']?['duration'] ?? data['duration']),
          isDraft: false,
          // Store creation date for proper sorting
          createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
          status: (data['status'] as String?) ?? 'ready',
          visibility:
              (data['visibility'] as String?) ?? kDefaultVideoVisibility,
          isDeleted: data['isDeleted'] == true || data['deleted'] == true,
          deletedAt: data['deletedAt'] as Timestamp?,
        );

        debugPrint(
            '🎬 VideoService: ✅ Created video ${video.id} by ${video.creator.displayName} - URL: ${video.videoURL.isNotEmpty ? "YES" : "NO"}, Thumbnails: ${thumbnails != null ? 'YES' : 'NO'}');

        videos.add(video);
        processedCount++;
      }

      // Log summary after processing all videos (diagnostic for "new uploads not showing")
      final totalFetched = candidateDocs.length;
      final int skippedDuringHydration = skippedCount - rejectedPreHydration;
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

      FeedStats(
        fetched: totalFetched,
        rejectedPreHydration: rejectedPreHydration,
        hydrated: processedCount,
        skippedDuringHydration: skippedDuringHydration,
        skipReasons: skipReasons,
        ranked: diversifiedVideos.length,
      ).logTo(debugPrint);

      final List<HomeVideo> mergedState =
          _mergeFeedRefreshPreservingProfileVisibleVideos(diversifiedVideos);
      state = mergedState;
      VideoFeedDiagnostics.logVideoLoadDone(
        videoCount: mergedState.length,
      );
      debugPrint(
          '✅ VideoService: Loaded ${diversifiedVideos.length} unique feed videos '
          '(state ${mergedState.length}, removed ${videos.length - deduplicatedVideos.length} duplicates)');

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
            await loadAllVideos(source: 'load_all_videos_retry');
            return;
          }
        } catch (retryError) {
          debugPrint('❌ VideoService: Retry failed: $retryError');
        }
      }

      state = [];
    } finally {
      isHydratingFeed = false;
    }
  }

  List<HomeVideo> _mergeFeedRefreshPreservingProfileVisibleVideos(
    List<HomeVideo> incomingFeedVideos,
  ) {
    final String viewerId = _auth.currentUser?.uid ?? '';
    final List<HomeVideo> next = List<HomeVideo>.of(incomingFeedVideos);
    final Set<String> incomingIds =
        next.map((HomeVideo video) => video.id).toSet();
    int preservedCount = 0;

    for (final HomeVideo existing in state) {
      if (incomingIds.contains(existing.id)) {
        continue;
      }
      final String ownerId = existing.creator.id;
      if (ownerId.isEmpty) {
        continue;
      }
      if (!canShowHomeVideo(
        video: existing,
        viewerId: viewerId,
        ownerId: ownerId,
      )) {
        continue;
      }
      next.add(existing);
      incomingIds.add(existing.id);
      preservedCount++;
    }

    if (kDebugMode && preservedCount > 0) {
      debugPrint(
        '🎬 VideoService: preserved $preservedCount profile-visible videos '
        'outside refreshed home feed slice',
      );
    }

    return next;
  }

  /// Fetches all of [profileUserId]'s public feed-eligible videos and merges them
  /// into [state]. The home feed only loads a small global slice; without this,
  /// [userVideosProvider] under-counts profile grids vs [reconcilePostCount].
  /// Returns whether [state] changed after merging profile-eligible videos.
  Future<bool> mergeProfileVideosForUser(
    String profileUserId, {
    bool forceServer = true,
    String viewName = 'ProfileView',
  }) async {
    if (LikeInteractionBoundary.isActive) {
      LikeInteractionBoundary.reportVideoServiceReload(
        source: 'mergeProfileVideosForUser',
      );
      return false;
    }
    final Future<bool>? inFlight = _mergeProfileVideosInFlight[profileUserId];
    if (inFlight != null) {
      if (kDebugMode) {
        debugPrint(
          '🎬 VideoService: mergeProfileVideosForUser($profileUserId) '
          'skipped (in flight)',
        );
      }
      return inFlight;
    }
    final Future<bool> run = _runMergeProfileVideosForUser(
      profileUserId,
      forceServer: forceServer,
      viewName: viewName,
    );
    _mergeProfileVideosInFlight[profileUserId] = run;
    try {
      return await run;
    } finally {
      _mergeProfileVideosInFlight.remove(profileUserId);
    }
  }

  Future<bool> _runMergeProfileVideosForUser(
    String profileUserId, {
    bool forceServer = true,
    String viewName = 'ProfileView',
  }) async {
    isMergingProfileVideos = true;
    try {
      if (Firebase.apps.isEmpty) {
        return false;
      }
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }
      final List<String> blockedUserIds =
          await UserBlockingService().getBlockedUsers();
      if (blockedUserIds.contains(profileUserId)) {
        return false;
      }
      final GetOptions fetchOptions = GetOptions(
        source: forceServer ? Source.server : Source.serverAndCache,
      );
      final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> docMap =
          <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      Future<void> mergeProfileOwnerFieldQuery(String fieldName) async {
        try {
          final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
              .collection('videos')
              .where(fieldName, isEqualTo: profileUserId)
              .get(fetchOptions);
          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
              in snapshot.docs) {
            docMap[doc.id] = doc;
          }
          if (kDebugMode) {
            debugPrint(
              '🎬 VideoService: profile owner legacy query '
              '$fieldName=$profileUserId -> ${snapshot.docs.length} docs '
              '(merged ${docMap.length})',
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              '🎬 VideoService: profile owner legacy query failed '
              '$fieldName=$profileUserId: $e',
            );
          }
        }
      }

      try {
        final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
            .collection('videos')
            .where('ownerId', isEqualTo: profileUserId)
            .orderBy('createdAt', descending: true)
            .get(fetchOptions);
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs) {
          docMap[doc.id] = doc;
        }
        if (kDebugMode) {
          debugPrint(
            '🎬 VideoService: profile owner ordered query '
            '$profileUserId -> ${snapshot.docs.length} docs',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '🎬 VideoService: profile owner ordered query failed '
            'for $profileUserId: $e',
          );
        }
      }
      try {
        final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
            .collection('videos')
            .where('ownerId', isEqualTo: profileUserId)
            .get(fetchOptions);
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs) {
          docMap[doc.id] = doc;
        }
        if (kDebugMode) {
          debugPrint(
            '🎬 VideoService: profile owner unordered fallback '
            '$profileUserId -> ${snapshot.docs.length} docs '
            '(merged ${docMap.length})',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '🎬 VideoService: profile owner unordered fallback failed '
            'for $profileUserId: $e',
          );
        }
      }
      for (final String ownerField in const <String>[
        'userId',
        'user_id',
        'authorId',
        'uid',
        'creatorId',
        'creator_id',
        'videoOwnerId',
      ]) {
        await mergeProfileOwnerFieldQuery(ownerField);
      }
      if (kDebugMode) {
        try {
          final DocumentSnapshot<Map<String, dynamic>> traceDoc =
              await _firestore
                  .collection('videos')
                  .doc(kVideoTraceTargetId)
                  .get(
                    GetOptions(
                      source:
                          forceServer ? Source.server : Source.serverAndCache,
                    ),
                  );
          logTargetVideoTrace(
            videoId: kVideoTraceTargetId,
            found: traceDoc.exists,
            viewName: '${viewName}DirectDoc',
            data: traceDoc.data(),
          );
        } catch (e) {
          debugPrint(
            'VIDEO_TRACE target=$kVideoTraceTargetId '
            'view=${viewName}DirectDoc found=false error=$e',
          );
        }
      }
      if (!docMap.containsKey(kVideoTraceTargetId)) {
        logTargetVideoTrace(
          videoId: kVideoTraceTargetId,
          found: false,
          viewName: viewName,
          rejectReason: 'not_in_profile_owner_query',
        );
      }
      final String viewerUserId = user.uid;
      final List<HomeVideo> built = <HomeVideo>[];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in docMap.values) {
        final Map<String, dynamic> data = <String, dynamic>{
          ...doc.data(),
          'id': doc.id,
        };
        logVideoEligibility(
          videoId: doc.id,
          data: data,
          context: 'profile_merge:$profileUserId',
        );
        final String? syncReject = rejectProfileListCandidate(
          data,
          profileUserId,
          viewerUserId: viewerUserId,
          viewName: viewName,
        );
        if (syncReject != null) {
          logVideoEligibility(
            videoId: doc.id,
            data: data,
            excludedReason: syncReject,
            context: 'profile_merge:$profileUserId',
          );
          continue;
        }
        final HomeVideo? video = await _homeVideoFromDocForProfileList(
          doc,
          blockedUserIds,
        );
        if (video == null) {
          logVideoEligibility(
            videoId: doc.id,
            data: data,
            excludedReason: 'hydration_failed',
            context: 'profile_merge:$profileUserId',
          );
          continue;
        }
        built.add(video);
      }
      built.sort((HomeVideo a, HomeVideo b) {
        final int aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final int bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
      final bool changed = _mergeProfileVideosIntoState(built);
      if (kDebugMode) {
        debugPrint(
          '🎬 VideoService: mergeProfileVideosForUser($profileUserId) → '
          '${built.length}/${docMap.length} videos merged into state '
          '(total ${state.length}, changed=$changed)',
        );
      }
      return changed;
    } catch (e, stackTrace) {
      debugPrint('❌ VideoService: mergeProfileVideosForUser failed: $e');
      debugPrint('$stackTrace');
      return false;
    } finally {
      isMergingProfileVideos = false;
    }
  }

  bool _mergeProfileVideosIntoState(List<HomeVideo> profileVideos) {
    if (profileVideos.isEmpty) {
      return false;
    }
    final Map<String, HomeVideo> profileById = <String, HomeVideo>{
      for (final HomeVideo v in profileVideos) v.id: v,
    };
    final List<HomeVideo> next = <HomeVideo>[];
    final Set<String> seen = <String>{};
    bool hasProfileGridChange = false;
    for (final HomeVideo v in state) {
      final HomeVideo u = profileById[v.id] ?? v;
      final bool shouldReplace =
          !identical(u, v) && !_sameProfileGridVideo(v, u);
      if (shouldReplace) {
        hasProfileGridChange = true;
      }
      next.add(shouldReplace ? u : v);
      seen.add(u.id);
    }
    for (final HomeVideo v in profileVideos) {
      if (!seen.contains(v.id)) {
        hasProfileGridChange = true;
        next.add(v);
      }
    }
    if (!hasProfileGridChange) {
      if (kDebugMode) {
        debugPrint(
          '🎬 VideoService: mergeProfileVideosForUser skipped state update; '
          'profile grid unchanged',
        );
      }
      return false;
    }
    state = next;
    return true;
  }

  bool _sameProfileGridVideo(HomeVideo a, HomeVideo b) {
    return a.id == b.id &&
        a.creator.id == b.creator.id &&
        a.videoURL == b.videoURL &&
        a.thumbnailURL == b.thumbnailURL &&
        a.thumbnails == b.thumbnails &&
        a.caption == b.caption &&
        a.isDraft == b.isDraft &&
        a.categoryId == b.categoryId &&
        a.duration == b.duration &&
        a.createdAt == b.createdAt &&
        a.visibility == b.visibility &&
        a.status == b.status &&
        a.isDeleted == b.isDeleted &&
        a.deletedAt == b.deletedAt &&
        a.isPinned == b.isPinned &&
        listEquals(a.tags, b.tags) &&
        listEquals(a.playlistIds, b.playlistIds);
  }

  Future<HomeVideo?> _homeVideoFromPromoFixtureDoc({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required Map<String, dynamic> data,
    required String ownerId,
    required String thumbnailUrl,
  }) async {
    VideoThumbnails? thumbnails;
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
          aspectRatio:
              (thumbnailsData['aspectRatio'] as num?)?.toDouble() ?? 0.5625,
        );
      }
    }
    thumbnails ??= VideoThumbnails(
      urls: <int, String>{
        360: thumbnailUrl,
        540: thumbnailUrl,
        720: thumbnailUrl,
      },
      generatedAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      aspectRatio: 0.5625,
    );
    final app_user.User? loadedCreator =
        await _userDataService.getUserById(ownerId);
    final app_user.User resolvedCreator = _withCanonicalUserId(
      loadedCreator ??
          app_user.User(
            id: ownerId,
            username: (data['creatorUsername'] ?? data['username'] ?? 'creator')
                .toString(),
            displayName:
                (data['displayName'] ?? data['creatorName'] ?? 'Creator')
                    .toString(),
            avatarURL: null,
            bio: null,
            hashtags: const <String>[],
          ),
      ownerId,
    );
    return HomeVideo(
      id: doc.id,
      creator: resolvedCreator,
      videoURL: '',
      thumbnailURL: thumbnailUrl,
      thumbnails: thumbnails,
      caption: resolveVideoCaptionFromFirestoreData(data),
      overlayCaption: resolveVideoOverlayCaptionFromFirestoreData(data),
      categoryId: categoryIdFromVideoDocument(data),
      views: readVideoViewCountFromFirestore(data),
      likes: readVideoLikeCountFromFirestore(data),
      comments: readVideoCommentCountFromFirestore(data),
      duration: _parseDuration(
        data['metadata']?['duration'] ?? data['duration'],
      ),
      isDraft: false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      status: (data['status'] as String?) ?? 'ready',
      visibility: (data['visibility'] as String?) ?? 'public',
      isDeleted: data['isDeleted'] == true || data['deleted'] == true,
      deletedAt: data['deletedAt'] as Timestamp?,
      tags: const <String>['promo_fixture'],
    );
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
    if (isPromoFixtureVideo(data) && promoFixtureHasThumbnail(data)) {
      return _homeVideoFromPromoFixtureDoc(
        doc: doc,
        data: data,
        ownerId: ownerId,
        thumbnailUrl: thumbnailUrl!,
      );
    }
    final String? videoUrl = resolveReadyPlaybackUrl(data);
    if (videoUrl == null) {
      return null;
    }
    final dynamic playableResult =
        await VideoHealthGate.instance.resolvePlayableSource(
      doc.id,
      cachedData: data,
      fallbackUrl: videoUrl,
    );
    if (playableResult is! Playable) {
      return null;
    }
    final String playableUrl = playableResult.url;
    final app_user.User? loadedCreator =
        await _userDataService.getUserById(ownerId);
    if (loadedCreator == null) {
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
        caption: resolveVideoCaptionFromFirestoreData(data),
        overlayCaption: resolveVideoOverlayCaptionFromFirestoreData(data),
        categoryId: categoryIdFromVideoDocument(data),
        views: readVideoViewCountFromFirestore(data),
        likes: readVideoLikeCountFromFirestore(data),
        comments: readVideoCommentCountFromFirestore(data),
        duration: _parseDuration(
          data['metadata']?['duration'] ?? data['duration'],
        ),
        isDraft: false,
        createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
        status: (data['status'] as String?) ?? 'ready',
        visibility: (data['visibility'] as String?) ?? 'public',
        isDeleted: data['isDeleted'] == true || data['deleted'] == true,
        deletedAt: data['deletedAt'] as Timestamp?,
      );
    }
    final app_user.User creator = _withCanonicalUserId(loadedCreator, ownerId);
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
      caption: resolveVideoCaptionFromFirestoreData(data),
      overlayCaption: resolveVideoOverlayCaptionFromFirestoreData(data),
      categoryId: categoryIdFromVideoDocument(data),
      views: readVideoViewCountFromFirestore(data),
      likes: readVideoLikeCountFromFirestore(data),
      comments: readVideoCommentCountFromFirestore(data),
      duration:
          _parseDuration(data['metadata']?['duration'] ?? data['duration']),
      isDraft: false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      status: (data['status'] as String?) ?? 'ready',
      visibility: (data['visibility'] as String?) ?? 'public',
      isDeleted: data['isDeleted'] == true || data['deleted'] == true,
      deletedAt: data['deletedAt'] as Timestamp?,
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
    final userVideos = state
        .where((video) => _homeVideoBelongsToProfile(video, userId))
        .toList();
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
    await loadAllVideos(source: 'video_service_refresh');
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

      final int scanLimit = (limit * 3).clamp(limit, 100);

      Query<Map<String, dynamic>> baseQuery = _firestore
          .collection('videos')
          .where('visibility', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .limit(scanLimit);

      Query<Map<String, dynamic>> query = startAfter != null
          ? baseQuery.startAfterDocument(startAfter)
          : baseQuery;

      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await query.get();
      } catch (_) {
        snapshot = await _fetchForYouLegacyPage(
          limit: scanLimit,
          startAfter: startAfter,
        );
      }

      if (snapshot.docs.isEmpty && startAfter == null) {
        snapshot = await _fetchForYouLegacyPage(
          limit: scanLimit,
          startAfter: null,
        );
      }

      final List<QueryDocumentSnapshot<Map<String, dynamic>>> docsList =
          List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.docs);
      if (startAfter == null && docsList.length < scanLimit) {
        await _appendSupplementalForYouDocs(
          docsList,
          limit: scanLimit,
        );
      }
      final videos = <HomeVideo>[];
      for (final doc in docsList) {
        final HomeVideo? video = await homeVideoFromRealtimeFeedDoc(
          doc,
          blockedUserIds: blockedUserIds,
        );
        if (video != null) {
          videos.add(video);
          if (videos.length >= limit) {
            break;
          }
        }
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

  Future<void> _appendSupplementalForYouDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required int limit,
  }) async {
    final Set<String> seenIds = docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id)
        .toSet();

    Future<void> merge(Query<Map<String, dynamic>> query) async {
      if (docs.length >= limit) {
        return;
      }
      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        if (seenIds.add(doc.id)) {
          docs.add(doc);
          if (docs.length >= limit) {
            return;
          }
        }
      }
    }

    try {
      await merge(
        _firestore
            .collection('videos')
            .where('visibility', isEqualTo: 'public')
            .where('isReadyForFeed', isEqualTo: true)
            .orderBy('updatedAt', descending: true)
            .limit(limit),
      );
    } catch (_) {
      // Some older projects may not have this composite index yet.
    }

    try {
      await merge(
        _firestore
            .collection('videos')
            .where('visibility', isEqualTo: 'public')
            .where('isReadyForFeed', isEqualTo: true)
            .orderBy('publishedAt', descending: true)
            .limit(limit),
      );
    } catch (_) {
      // Keep the createdAt query as the source of truth if fallback indexes miss.
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _fetchForYouLegacyPage({
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    Query<Map<String, dynamic>> fallback = _firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      fallback = fallback.startAfterDocument(startAfter);
    }
    return fallback.get();
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
  ref.watch(_userVideosGridSignatureProvider(userId));
  final allVideos = ref.read(videoServiceStateProvider);
  final String viewerId = FirebaseAuth.instance.currentUser?.uid ?? '';

  final userVideos = allVideos.where((video) {
    return _homeVideoBelongsToProfile(video, userId) &&
        canShowHomeVideo(
          video: video,
          viewerId: viewerId,
          ownerId: userId,
        );
  }).toList();

  return orderProfileGridVideos(userVideos);
});

bool _homeVideoBelongsToProfile(HomeVideo video, String userId) {
  return userId.isNotEmpty && video.creator.id == userId;
}

final _userVideosGridSignatureProvider =
    Provider.family<String, String>((ref, userId) {
  final String viewerId = FirebaseAuth.instance.currentUser?.uid ?? '';
  return ref.watch(videoServiceStateProvider.select((videos) {
    final StringBuffer buffer = StringBuffer();
    for (final HomeVideo video in videos) {
      if (!_homeVideoBelongsToProfile(video, userId) ||
          !canShowHomeVideo(
            video: video,
            viewerId: viewerId,
            ownerId: userId,
          )) {
        continue;
      }
      buffer
        ..write(video.id)
        ..write('|')
        ..write(video.videoURL)
        ..write('|')
        ..write(video.thumbnailURL ?? '')
        ..write('|')
        ..write(video.thumbnails?.generatedAt?.millisecondsSinceEpoch ?? 0)
        ..write('|')
        ..write(video.thumbnails?.aspectRatio ?? 0)
        ..write('|')
        ..write(video.caption)
        ..write('|')
        ..write(video.duration ?? 0)
        ..write('|')
        ..write(video.createdAt?.millisecondsSinceEpoch ?? 0)
        ..write('|')
        ..write(video.visibility)
        ..write('|')
        ..write(video.status)
        ..write('|')
        ..write(video.isDeleted)
        ..write('|')
        ..write(video.deletedAt?.millisecondsSinceEpoch ?? 0)
        ..write('|')
        ..write(video.isPinned)
        ..write('|')
        ..write(video.tags.join(','))
        ..write('|')
        ..write(video.playlistIds.join(','))
        ..write('\n');
    }
    return buffer.toString();
  }));
});

final categoryVideosProvider =
    Provider.family<List<HomeVideo>, String>((ref, categoryId) {
  final allVideos = ref.watch(videoServiceStateProvider);
  return allVideos
      .where(
        (video) =>
            video.categoryId == categoryId && isHomeVideoVisibleInFeed(video),
      )
      .toList();
});
