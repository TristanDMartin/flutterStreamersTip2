import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/firebase_app_check_startup.dart';
import '../models/optimistic_video.dart';
import '../utils/category_schema.dart';
import '../utils/firestore_strip_nulls.dart';
import '../utils/upload_error_classifier.dart';
import '../utils/video_caption_firestore.dart';
import '../utils/video_caption_resolver.dart';

class OptimisticVideoService extends ChangeNotifier {
  static final OptimisticVideoService _instance =
      OptimisticVideoService._internal();
  factory OptimisticVideoService() => _instance;
  OptimisticVideoService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Map<String, OptimisticVideo> _optimisticVideos = {};
  final Map<String, StreamSubscription> _videoListeners = {};
  final Map<String, String> _publishedCaptionByVideoId = <String, String>{};

  final StreamController<String> _feedRefreshController =
      StreamController<String>.broadcast();
  final StreamController<List<String>> _categoryRefreshController =
      StreamController<List<String>>.broadcast();

  String? _pendingHomeScrollVideoId;

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

    final AppCheckReadiness appCheck = await ensureAppCheckReadyForFirestore();
    if (!appCheck.isReady) {
      final UploadFailureClassification failure = UploadFailureClassification(
        kind: UploadFailureKind.appCheck,
        logLabel: 'App Check',
        userMessage: appCheck.detail.contains('attestation')
            ? UploadFailureClassification.classify(appCheck.detail).userMessage
            : 'App Check token unavailable. ${appCheck.detail}',
      );
      _logUploadFailure('optimistic_placeholder', failure);
      throw Exception(failure.userMessage);
    }

    if (persistToFirestore) {
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
    _setupVideoListener(videoId);
    notifyListeners();
    return verified;
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
    _videoListeners[videoId] = _firestore
        .collection('videos')
        .doc(videoId)
        .snapshots()
        .listen((DocumentSnapshot<Map<String, dynamic>> snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        _handleVideoUpdate(videoId, snapshot.data()!);
      }
    });
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
        updatedVideo = OptimisticVideoFactory.markAsReady(
          optimisticVideo: optimisticVideo,
          videoUrl: data['videoUrl'] as String? ?? '',
          thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
          hlsUrl: data['hlsUrl'] as String?,
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
          _optimisticVideos.remove(videoId);
          _videoListeners[videoId]?.cancel();
          _videoListeners.remove(videoId);
        });
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
