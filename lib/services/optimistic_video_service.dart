import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../core/firebase_app_check_startup.dart';
import '../debug/agent_debug_log.dart';
import '../models/optimistic_video.dart';
import '../utils/category_schema.dart';
import '../utils/firestore_strip_nulls.dart';
import '../utils/home_video_playback.dart';
import '../utils/upload_error_classifier.dart';
import '../utils/video_caption_firestore.dart';
import '../utils/video_caption_resolver.dart';
import '../utils/video_url_resolver.dart';
import 'optimistic_video_persistence.dart';

class OptimisticVideoService extends ChangeNotifier {
  static final OptimisticVideoService _instance =
      OptimisticVideoService._internal();
  factory OptimisticVideoService() => _instance;
  OptimisticVideoService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OptimisticVideoPersistence _persistence =
      OptimisticVideoPersistence.instance;

  final Map<String, OptimisticVideo> _optimisticVideos = {};
  final Map<String, StreamSubscription> _videoListeners = {};
  final Map<String, String> _publishedCaptionByVideoId = <String, String>{};

  final StreamController<String> _feedRefreshController =
      StreamController<String>.broadcast();
  final StreamController<List<String>> _categoryRefreshController =
      StreamController<List<String>>.broadcast();

  String? _pendingHomeScrollVideoId;
  bool _didRestoreFromDisk = false;

  List<OptimisticVideo> get optimisticVideos =>
      _optimisticVideos.values.toList();
  Stream<String> get feedRefreshStream => _feedRefreshController.stream;
  Stream<List<String>> get categoryRefreshStream =>
      _categoryRefreshController.stream;

  void requestFeedRefresh({List<String>? categories}) {
    _feedRefreshController.add('home');
    if (categories != null && categories.isNotEmpty) {
      _categoryRefreshController.add(categories);
    }
  }

  void requestHomeScrollToVideo(String videoId) {
    if (videoId.isEmpty) {
      return;
    }
    _pendingHomeScrollVideoId = videoId;
  }

  String? consumePendingHomeScrollVideoId() {
    final String? videoId = _pendingHomeScrollVideoId;
    _pendingHomeScrollVideoId = null;
    return videoId;
  }

  String? peekPendingHomeScrollVideoId() => _pendingHomeScrollVideoId;

  void rememberPublishedCaption({
    required String videoId,
    required String caption,
  }) {
    final String trimmed = caption.trim();
    if (videoId.isEmpty || trimmed.isEmpty) {
      return;
    }
    _publishedCaptionByVideoId[videoId] = trimmed;
  }

  String? peekPublishedCaption(String videoId) {
    final String? cached = _publishedCaptionByVideoId[videoId];
    if (cached != null && cached.trim().isNotEmpty) {
      return cached.trim();
    }
    return null;
  }

  void clearPublishedCaption(String videoId) {
    _publishedCaptionByVideoId.remove(videoId);
  }

  /// Cold start: reload Instant Publish rows so Home/Profile keep the same
  /// videoId after kill (local MP4/cover when still on disk).
  Future<int> restorePersistedOptimisticVideos() async {
    if (_didRestoreFromDisk) {
      return _optimisticVideos.length;
    }
    _didRestoreFromDisk = true;
    final List<OptimisticVideo> stored = await _persistence.loadAll();
    if (stored.isEmpty) {
      debugPrint('OPTIMISTIC_RESTORE count=0');
      return 0;
    }
    final String? uid = _auth.currentUser?.uid;
    int restored = 0;
    for (final OptimisticVideo video in stored) {
      if (uid != null &&
          uid.isNotEmpty &&
          video.ownerId.isNotEmpty &&
          video.ownerId != uid) {
        unawaited(_persistence.remove(video.videoId));
        continue;
      }
      if (_optimisticVideos.containsKey(video.videoId)) {
        continue;
      }
      _optimisticVideos[video.videoId] = video;
      rememberPublishedCaption(
        videoId: video.videoId,
        caption: video.caption,
      );
      attachServerListener(video.videoId);
      restored += 1;
    }
    if (restored > 0) {
      notifyListeners();
      requestFeedRefresh();
    }
    debugPrint('OPTIMISTIC_RESTORE count=$restored');
    return restored;
  }

  /// Rehydrate a single Instant Publish row (upload-job resume / cold start).
  Future<OptimisticVideo> restoreOptimisticVideo(OptimisticVideo video) async {
    _optimisticVideos[video.videoId] = video;
    rememberPublishedCaption(
      videoId: video.videoId,
      caption: video.caption,
    );
    attachServerListener(video.videoId);
    await _persistVideo(video);
    notifyListeners();
    requestFeedRefresh();
    return video;
  }

  Future<void> _persistVideo(OptimisticVideo video) async {
    await _persistence.save(video);
  }

  /// In-memory optimistic row. Set [persistToFirestore] false during publish so
  /// the Worker owns the canonical `videos/{id}` create (avoids 409 collisions).
  Future<OptimisticVideo> createOptimisticVideo({
    required String videoId,
    required String caption,
    required List<String> categories,
    String? localThumbnailPath,
    String? localVideoPath,
    Map<String, dynamic>? metadata,
    bool persistToFirestore = true,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final OptimisticVideo pending = OptimisticVideoFactory.createPlaceholder(
      videoId: videoId,
      ownerId: user.uid,
      caption: caption,
      categories: categories,
      localThumbnailPath: localThumbnailPath,
      localVideoPath: localVideoPath,
      metadata: metadata,
    );

    // #region agent log
    agentDebugLog(
      hypothesisId: 'C',
      location: 'optimistic_video_service.dart:createOptimisticVideo',
      message: 'optimistic_create_enter',
      data: <String, Object?>{
        'persistToFirestore': persistToFirestore,
        'videoId': videoId,
      },
    );
    // #endregion

    // App Check is only required when writing Firestore placeholders.
    // Publish uses persistToFirestore=false; hanging on getToken blocked Share.
    if (persistToFirestore) {
      // #region agent log
      agentDebugLog(
        hypothesisId: 'C',
        location: 'optimistic_video_service.dart:createOptimisticVideo',
        message: 'optimistic_app_check_begin',
        data: <String, Object?>{'videoId': videoId},
      );
      // #endregion
      final AppCheckReadiness appCheck =
          await ensureAppCheckReadyForFirestore().timeout(
        const Duration(seconds: 8),
        onTimeout: () => const AppCheckReadiness(
          isReady: false,
          detail: 'App Check readiness timed out',
        ),
      );
      // #region agent log
      agentDebugLog(
        hypothesisId: 'C',
        location: 'optimistic_video_service.dart:createOptimisticVideo',
        message: 'optimistic_app_check_done',
        data: <String, Object?>{
          'ready': appCheck.isReady,
          'detail': appCheck.detail,
        },
      );
      // #endregion
      if (!appCheck.isReady) {
        final UploadFailureClassification failure = UploadFailureClassification(
          kind: UploadFailureKind.appCheck,
          logLabel: 'App Check',
          userMessage: appCheck.detail.contains('attestation')
              ? UploadFailureClassification.classify(appCheck.detail)
                  .userMessage
              : 'App Check token unavailable. ${appCheck.detail}',
        );
        _logUploadFailure('optimistic_placeholder', failure);
        throw Exception(failure.userMessage);
      }

      try {
        await _createPlaceholderDocuments(pending);
      } catch (e) {
        final UploadFailureClassification failure =
            UploadFailureClassification.classify(e);
        _logUploadFailure('optimistic_placeholder', failure);
        final OptimisticVideo rejected = pending.copyWith(
          status: VideoStatus.placeholderRejected,
          errorMessage: failure.userMessage,
          isOptimistic: false,
        );
        _optimisticVideos[videoId] = rejected;
        notifyListeners();
        rethrow;
      }
    }

    final OptimisticVideo verified = pending.copyWith(
      status: VideoStatus.processing,
    );
    _optimisticVideos[videoId] = verified;
    rememberPublishedCaption(videoId: videoId, caption: caption);
    await _persistVideo(verified);
    // Only listen after Worker creates videos/{id}. Early snapshots on a
    // missing doc evaluate canReadVideo(resource.data) → PERMISSION_DENIED.
    if (persistToFirestore) {
      _setupVideoListener(videoId);
    }
    requestHomeScrollToVideo(videoId);
    notifyListeners();
    debugPrint('OPTIMISTIC_CREATED videoId=$videoId');
    debugPrint(
      'PENDING_OVERLAY_COUNT=${_optimisticVideos.values.where((OptimisticVideo v) => v.ownerId == user.uid && (v.status.isProcessing || v.status.isPlaceholderPending || v.status.hasFailed)).length}',
    );
    requestFeedRefresh(categories: categories);
    // #region agent log
    agentDebugLog(
      hypothesisId: 'C',
      location: 'optimistic_video_service.dart:createOptimisticVideo',
      message: 'optimistic_create_done',
      data: <String, Object?>{
        'videoId': videoId,
        'localVideoPath': localVideoPath,
      },
    );
    // #endregion
    return verified;
  }

  /// Attach Firestore listener once the Worker has created videos/{id}.
  void attachServerListener(String videoId) {
    if (videoId.isEmpty) {
      return;
    }
    if (_videoListeners.containsKey(videoId)) {
      return;
    }
    if (!_optimisticVideos.containsKey(videoId)) {
      return;
    }
    try {
      if (Firebase.apps.isEmpty) {
        return;
      }
    } catch (_) {
      return;
    }
    _setupVideoListener(videoId);
  }

  /// Re-key optimistic UI after Worker allocates the canonical videoId.
  void bindServerVideoId({
    required String clientVideoId,
    required String serverVideoId,
  }) {
    if (clientVideoId == serverVideoId) {
      return;
    }
    final OptimisticVideo? existing = _optimisticVideos.remove(clientVideoId);
    _videoListeners[clientVideoId]?.cancel();
    _videoListeners.remove(clientVideoId);
    if (existing == null) {
      return;
    }
    final OptimisticVideo rebound = existing.copyWith(videoId: serverVideoId);
    _optimisticVideos[serverVideoId] = rebound;
    rememberPublishedCaption(
      videoId: serverVideoId,
      caption: existing.caption,
    );
    unawaited(_persistence.remove(clientVideoId));
    unawaited(_persistVideo(rebound));
    _setupVideoListener(serverVideoId);
    notifyListeners();
  }

  void _logUploadFailure(String stage, UploadFailureClassification failure) {
    debugPrint(
      '❌ OptimisticVideoService [$stage] ${failure.logLabel}: '
      '${failure.userMessage}',
    );
  }

  Future<void> _createPlaceholderDocuments(OptimisticVideo video) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    debugPrint(
      '🔥 OptimisticVideoService: placeholder write videos/${video.videoId}',
    );

    final String rawCategory =
        video.categories.isNotEmpty ? video.categories.first : 'gaming';
    final Map<String, dynamic> categoryFields =
        buildCanonicalCategoryFields(rawCategory);
    final String canonicalCategory = categoryFields['category'] as String;

    final Map<String, dynamic> metadata = {
      ...(video.metadata ?? <String, dynamic>{}),
      'categoryOriginal': rawCategory,
      'categoryCanonical': canonicalCategory,
    };
    metadata.removeWhere((_, dynamic v) => v == null);

    final String resolvedCaption = resolveUploadCaption(
      caption: video.caption,
      additionalMetadata: metadata,
    );
    final Map<String, dynamic> videoData = <String, dynamic>{
      'userId': video.ownerId,
      'ownerId': video.ownerId,
      'creatorId': video.ownerId,
      'creator_id': video.ownerId,
      'caption': resolvedCaption,
      if (resolvedCaption.isNotEmpty) 'description': resolvedCaption,
      ...categoryFields,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'processing',
      'visibility': 'public',
      'isDeleted': false,
      'isReadyForFeed': false,
      'duration': video.duration ?? 0,
      'fileSize': video.fileSize ?? 0,
      'metadata': metadata,
    };
    if (video.localThumbnailPath != null &&
        video.localThumbnailPath!.isNotEmpty) {
      videoData['thumbnailUrl'] = video.localThumbnailPath;
    }

    final DocumentReference<Map<String, dynamic>> videoRef =
        _firestore.collection('videos').doc(video.videoId);

    await videoRef.set(stripNullFieldsDeep(videoData));
    await _verifyVideoDocumentExists(videoRef, video.ownerId);

    debugPrint(
      '✅ OptimisticVideoService: verified videos/${video.videoId} in Firestore',
    );

    try {
      await _firestore
          .collection('users')
          .doc(video.ownerId)
          .collection('videos')
          .doc(video.videoId)
          .set(<String, dynamic>{
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'processing',
      });
    } catch (e) {
      final UploadFailureClassification failure =
          UploadFailureClassification.classify(e);
      debugPrint(
        '⚠️ OptimisticVideoService: users/…/videos mirror failed '
        '(${failure.logLabel}): ${failure.userMessage}',
      );
    }
  }

  Future<void> _verifyVideoDocumentExists(
    DocumentReference<Map<String, dynamic>> videoRef,
    String ownerId,
  ) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await videoRef.get(const GetOptions(source: Source.server));
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception(
        'Firestore placeholder missing after write (${videoRef.path})',
      );
    }
    final Map<String, dynamic> data = snapshot.data()!;
    final String? storedUserId = data['userId'] as String?;
    if (storedUserId == null || storedUserId != ownerId) {
      throw Exception(
        'Firestore placeholder owner mismatch (expected $ownerId, '
        'got $storedUserId)',
      );
    }
  }

  void _setupVideoListener(String videoId) {
    _videoListeners[videoId]?.cancel();
    _videoListeners[videoId] = _firestore
        .collection('videos')
        .doc(videoId)
        .snapshots()
        .listen(
      (DocumentSnapshot<Map<String, dynamic>> snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          _handleVideoUpdate(videoId, snapshot.data()!);
        }
      },
      onError: (Object error) {
        debugPrint(
          '⚠️ OptimisticVideoService: videos/$videoId listen error: $error',
        );
      },
    );
  }

  void _handleVideoUpdate(String videoId, Map<String, dynamic> data) {
    final OptimisticVideo? optimisticVideo = _optimisticVideos[videoId];
    if (optimisticVideo == null) {
      return;
    }

    final VideoStatus status =
        VideoStatusExtension.fromFirestoreStatus(data['status'] as String?);
    OptimisticVideo updatedVideo;

    switch (status) {
      case VideoStatus.uploadSucceeded:
        final String? resolvedRemote = resolveReadyPlaybackUrl(data);
        final String hlsUrl = (data['hlsUrl'] as String?)?.trim().isNotEmpty ==
                true
            ? (data['hlsUrl'] as String).trim()
            : (resolvedRemote ?? '');
        final String videoUrl =
            (data['videoUrl'] as String?)?.trim().isNotEmpty == true
                ? (data['videoUrl'] as String).trim()
                : (data['videoURL'] as String?)?.trim().isNotEmpty == true
                    ? (data['videoURL'] as String).trim()
                    : (resolvedRemote ?? '');
        final String thumbnailUrl =
            (data['thumbnailUrl'] as String?)?.trim().isNotEmpty == true
                ? (data['thumbnailUrl'] as String).trim()
                : (data['thumbnailURL'] as String?)?.trim() ?? '';
        updatedVideo = OptimisticVideoFactory.markAsReady(
          optimisticVideo: optimisticVideo,
          videoUrl: videoUrl,
          thumbnailUrl: thumbnailUrl,
          hlsUrl: hlsUrl.isNotEmpty ? hlsUrl : resolvedRemote,
          duration: data['duration'] as int?,
          fileSize: data['fileSize'] as int?,
        );
        rememberPublishedCaption(
          videoId: videoId,
          caption: optimisticVideo.caption,
        );
        final String? uid = _auth.currentUser?.uid;
        if (uid != null) {
          unawaited(
            persistVideoCaptionIfMissing(
              firestore: _firestore,
              videoId: videoId,
              userId: uid,
              caption: optimisticVideo.caption,
            ),
          );
          scheduleVideoCaptionBackfill(
            firestore: _firestore,
            videoId: videoId,
            userId: uid,
            caption: optimisticVideo.caption,
          );
        }
        Timer(const Duration(seconds: 5), () {
          final OptimisticVideo? still = _optimisticVideos[videoId];
          if (still == null) {
            return;
          }
          final String remote =
              (still.hlsUrl ?? still.videoUrl ?? '').trim();
          // Keep the Instant Publish row until a remote URL exists so Profile
          // / Streamer cannot lose the card when Mux ready races local overlay.
          if (remote.isEmpty || isHomeVideoLocalFileUrl(remote)) {
            debugPrint(
              'PENDING_KEEP_UNTIL_REMOTE videoId=$videoId',
            );
            return;
          }
          _optimisticVideos.remove(videoId);
          unawaited(_persistence.remove(videoId));
          _videoListeners[videoId]?.cancel();
          _videoListeners.remove(videoId);
          notifyListeners();
          _feedRefreshController.add('home');
        });
        debugPrint('PENDING_CANONICAL_RECONCILED videoId=$videoId');
        break;
      case VideoStatus.uploadFailed:
        updatedVideo = OptimisticVideoFactory.markAsFailed(
          optimisticVideo: optimisticVideo,
          errorMessage: data['errorMessage'] as String? ??
              data['uploadError'] as String? ??
              'Upload failed',
        );
        break;
      default:
        return;
    }

    _optimisticVideos[videoId] = updatedVideo;
    unawaited(_persistVideo(updatedVideo));
    notifyListeners();
    if (status == VideoStatus.uploadSucceeded) {
      requestHomeScrollToVideo(videoId);
    }
    _feedRefreshController.add('home');
    _categoryRefreshController.add(updatedVideo.categories);
  }

  void updateUploadProgress(String videoId, double progress) {
    final OptimisticVideo? optimisticVideo = _optimisticVideos[videoId];
    if (optimisticVideo != null) {
      _optimisticVideos[videoId] = OptimisticVideoFactory.updateProgress(
        optimisticVideo: optimisticVideo,
        progress: progress,
      );
      notifyListeners();
    }
  }

  OptimisticVideo? getOptimisticVideo(String videoId) {
    return _optimisticVideos[videoId];
  }

  bool isOptimisticVideo(String videoId) {
    return _optimisticVideos.containsKey(videoId);
  }

  List<OptimisticVideo> getOptimisticVideosForUser(String userId) {
    return _optimisticVideos.values
        .where((OptimisticVideo video) => video.ownerId == userId)
        .toList();
  }

  List<OptimisticVideo> getOptimisticVideosForCategories(
    List<String> categories,
  ) {
    return _optimisticVideos.values
        .where(
          (OptimisticVideo video) =>
              video.categories.any((String cat) => categories.contains(cat)),
        )
        .toList();
  }

  void removeOptimisticVideo(String videoId) {
    _optimisticVideos.remove(videoId);
    unawaited(_persistence.remove(videoId));
    _videoListeners[videoId]?.cancel();
    _videoListeners.remove(videoId);
    notifyListeners();
  }

  void clearAllOptimisticVideos() {
    for (final StreamSubscription<dynamic> listener in _videoListeners.values) {
      listener.cancel();
    }
    _videoListeners.clear();
    _optimisticVideos.clear();
    unawaited(_persistence.clear());
    notifyListeners();
  }

  List<OptimisticVideo> getCombinedVideos(
    List<Map<String, dynamic>> regularVideos,
  ) {
    final List<OptimisticVideo> combinedVideos = <OptimisticVideo>[];

    for (final Map<String, dynamic> videoData in regularVideos) {
      final String? videoId =
          videoData['id'] as String? ?? videoData['videoId'] as String?;
      if (videoId != null && !_optimisticVideos.containsKey(videoId)) {
        combinedVideos.add(OptimisticVideo.fromJson(videoData));
      }
    }

    combinedVideos.addAll(_optimisticVideos.values);
    combinedVideos.sort(
      (OptimisticVideo a, OptimisticVideo b) =>
          b.createdAt.compareTo(a.createdAt),
    );
    return combinedVideos;
  }

  @override
  void dispose() {
    for (final StreamSubscription<dynamic> listener in _videoListeners.values) {
      listener.cancel();
    }
    _videoListeners.clear();
    _optimisticVideos.clear();
    _feedRefreshController.close();
    _categoryRefreshController.close();
    super.dispose();
  }
}
