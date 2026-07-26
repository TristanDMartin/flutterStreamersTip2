import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/upload_job.dart';
import 'upload_job_storage_service.dart';
import 'background_upload_service.dart';
import 'video_publish_finalize_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UploadStatusManager extends ChangeNotifier {
  static final UploadStatusManager _instance = UploadStatusManager._internal();
  factory UploadStatusManager() => _instance;
  UploadStatusManager._internal();

  final UploadJobStorageService _jobStorage = UploadJobStorageService();
  final BackgroundUploadService _uploadService = BackgroundUploadService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, UploadJob> _activeUploads = {};
  final Map<String, StreamSubscription<double>> _progressSubscriptions = {};
  final Map<String, StreamSubscription<UploadResult>> _resultSubscriptions = {};

  // Current active job state
  bool _showStatusBar = false;
  UploadJobState _currentState = UploadJobState.idle;
  double _currentProgress = 0.0;
  String? _currentJobId;
  String? _currentVideoId;
  String? _errorMessage;
  String? _thumbnailUrl;
  Timer? _pollingTimer;
  DateTime? _uploadStartTime;

  // Getters
  bool get showStatusBar => _showStatusBar;
  UploadJobState get currentState => _currentState;
  double get currentProgress => _currentProgress;
  String? get currentJobId => _currentJobId;
  String? get currentVideoId => _currentVideoId;
  String? get errorMessage => _errorMessage;
  String? get thumbnailUrl => _thumbnailUrl;
  List<UploadJob> get activeUploads => _activeUploads.values.toList();
  bool get hasActiveUploads => _activeUploads.isNotEmpty;

  String get currentStatusMessage {
    switch (_currentState) {
      case UploadJobState.validating:
        return 'Checking your video...';
      case UploadJobState.uploading:
      case UploadJobState.queued:
        final pct = (_currentProgress * 100).toStringAsFixed(0);
        final eta = _estimatedTimeRemaining();
        return eta != null
            ? 'Uploading $pct% • $eta left'
            : 'Uploading $pct%...';
      case UploadJobState.processing:
        return 'Processing your video...';
      case UploadJobState.ready:
      case UploadJobState.done:
        return 'Your video is live 🎉';
      case UploadJobState.failed:
        return _errorMessage ?? 'Upload failed';
      case UploadJobState.idle:
        return '';
    }
  }

  String? _estimatedTimeRemaining() {
    if (_uploadStartTime == null || _currentProgress <= 0.01) return null;
    final elapsed = DateTime.now().difference(_uploadStartTime!).inSeconds;
    if (elapsed < 3) return null;
    final totalEstimated = elapsed / _currentProgress;
    final remaining = (totalEstimated - elapsed).round();
    if (remaining <= 0) return null;
    if (remaining < 60) return '${remaining}s';
    return '${(remaining / 60).ceil()}m';
  }

  Future<void> initialize() async {
    await _jobStorage.initialize();
    await _resumeActiveUploads();
  }

  /// Called by the publishing screen right after file validation starts.
  void enterValidating() {
    _currentState = UploadJobState.validating;
    _showStatusBar = false; // Validating is in-screen — bar not needed
    notifyListeners();
  }

  /// Background-managed upload (status bar owns progress via BackgroundUploadService).
  Future<String> startUpload({
    required String fileUri,
    String? thumbUri,
    required String title,
    required List<String> categories,
    required String videoId,
    Map<String, dynamic>? metadata,
  }) async {
    final localId = _generateLocalId();
    _uploadStartTime = DateTime.now();
    final Map<String, dynamic> jobMetadata = <String, dynamic>{
      ...?metadata,
      'source': 'background',
    };
    final job = UploadJob(
      localId: localId,
      fileUri: fileUri,
      thumbUri: thumbUri,
      title: title,
      categories: categories,
      createdAt: DateTime.now(),
      state: UploadJobState.queued,
      videoId: videoId,
      metadata: jobMetadata,
    );
    await _jobStorage.saveJob(job);
    _activeUploads[localId] = job;
    _currentJobId = localId;
    _currentVideoId = videoId;
    _currentState = UploadJobState.uploading;
    _currentProgress = 0.0;
    _errorMessage = null;
    _showStatusBar = true;
    notifyListeners();
    await _uploadService.startUpload(localId);
    _setupProgressTracking(localId);
    return localId;
  }

  /// Publish-screen owned upload: persist checkpoint + show bar, no duplicate upload.
  Future<String> beginInScreenUpload({
    required String fileUri,
    String? thumbUri,
    required String title,
    required List<String> categories,
    required String videoId,
    Map<String, dynamic>? metadata,
  }) async {
    final String localId = _currentJobId ?? _generateLocalId();
    _uploadStartTime = DateTime.now();
    final Map<String, dynamic> jobMetadata = <String, dynamic>{
      ...?metadata,
      'source': 'publish_screen',
      'privacy': metadata?['privacy'] ?? 'Everyone',
      'allowComments': metadata?['allowComments'] ?? true,
    };
    final UploadJob job = UploadJob(
      localId: localId,
      fileUri: fileUri,
      thumbUri: thumbUri,
      title: title,
      categories: categories,
      createdAt: DateTime.now(),
      state: UploadJobState.uploading,
      videoId: videoId,
      progress: 0.0,
      metadata: jobMetadata,
    );
    await _jobStorage.saveJob(job);
    _activeUploads[localId] = job;
    _currentJobId = localId;
    _currentVideoId = videoId;
    _currentState = UploadJobState.uploading;
    _currentProgress = 0.0;
    _errorMessage = null;
    _showStatusBar = true;
    notifyListeners();
    return localId;
  }

  Future<void> reportUploadProgress(double progress) async {
    final double clamped = progress.clamp(0.0, 1.0);
    _currentProgress = clamped;
    _currentState = UploadJobState.uploading;
    _showStatusBar = true;
    final String? localId = _currentJobId;
    if (localId != null) {
      final UploadJob? existing = _activeUploads[localId];
      if (existing != null) {
        _activeUploads[localId] = existing.copyWith(
          progress: clamped,
          state: UploadJobState.uploading,
        );
      }
      await _jobStorage.updateJobState(
        localId,
        UploadJobState.uploading,
        progress: clamped,
      );
    }
    notifyListeners();
  }

  Future<void> markFailed(String message) async {
    await _enterFailed(_currentJobId, message);
  }

  /// Called after bytes are fully uploaded — waits for Mux webhook via Firestore.
  void enterProcessing(String videoId) {
    _currentVideoId = videoId;
    _currentState = UploadJobState.processing;
    _currentProgress = 0.0;
    _showStatusBar = true;
    _pollingTimer?.cancel();
    final String? localId = _currentJobId;
    if (localId != null) {
      final UploadJob? existing = _activeUploads[localId];
      if (existing != null) {
        _activeUploads[localId] = existing.copyWith(
          state: UploadJobState.processing,
          videoId: videoId,
        );
      }
      unawaited(
        _jobStorage.updateJobState(localId, UploadJobState.processing),
      );
    }
    notifyListeners();
    _pollForReady(videoId);
  }

  void _setupProgressTracking(String localId) {
    final progressStream = _uploadService.getUploadProgress(localId);
    if (progressStream != null) {
      _progressSubscriptions[localId] = progressStream.listen((progress) {
        _currentProgress = progress;
        notifyListeners();
      });
    }

    final resultStream = _uploadService.getUploadResult(localId);
    if (resultStream != null) {
      _resultSubscriptions[localId] = resultStream.listen((result) {
        _handleUploadResult(localId, result);
      });
    }
  }

  void _handleUploadResult(String localId, UploadResult result) {
    final videoId = _activeUploads[localId]?.videoId ?? _currentVideoId;
    if (result.success && videoId != null) {
      _cleanupJob(localId);
      enterProcessing(videoId);
    } else {
      unawaited(
        _enterFailed(
          localId,
          result.errorMessage ?? 'Upload failed. Please try again.',
        ),
      );
    }
  }

  void _pollForReady(String videoId) {
    // Poll Firestore every 3 seconds until the video is feed-ready or timeout (5min).
    const pollInterval = Duration(seconds: 3);
    const timeout = Duration(minutes: 5);
    final deadline = DateTime.now().add(timeout);

    _pollingTimer = Timer.periodic(pollInterval, (timer) async {
      if (DateTime.now().isAfter(deadline)) {
        timer.cancel();
        unawaited(
          _enterFailed(
            null,
            'Processing timed out. Your video may still appear soon.',
          ),
        );
        return;
      }
      try {
        final doc = await _firestore.collection('videos').doc(videoId).get();
        if (!doc.exists) return;
        final data = doc.data()!;
        final isReady = data['isReadyForFeed'] as bool? ?? false;
        final playbackReady = data['playbackReady'] as bool?;
        final status = data['status'] as String? ?? '';
        final hasPlayableSource =
            (data['muxPlaybackId'] as String?)?.isNotEmpty == true ||
                (data['canonicalPlaybackUrl'] as String?)?.isNotEmpty == true ||
                (data['hlsUrl'] as String?)?.isNotEmpty == true ||
                (data['hls_url'] as String?)?.isNotEmpty == true;
        final thumbUrl =
            data['thumbnailUrl'] as String? ?? data['thumbnail_url'] as String?;
        final isCanonicalReady = isReady &&
            (playbackReady != false) &&
            (status == 'active' || status == 'ready');
        final isLegacyReady = hasPlayableSource &&
            (playbackReady != false) &&
            (status == 'active' || status == 'ready');
        if (isCanonicalReady || isLegacyReady) {
          timer.cancel();
          _enterReady(thumbUrl);
        }
      } catch (_) {
        // Network error — keep polling
      }
    });
  }

  void _enterReady(String? thumbUrl) {
    _currentState = UploadJobState.ready;
    _currentProgress = 1.0;
    _thumbnailUrl = thumbUrl;
    _showStatusBar = true;
    notifyListeners();
    final String? localId = _currentJobId;
    if (localId != null) {
      unawaited(_jobStorage.updateJobState(localId, UploadJobState.ready));
      unawaited(_jobStorage.deleteJob(localId));
      _cleanupJob(localId);
    }
    final String? videoId = _currentVideoId;
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (videoId != null && videoId.isNotEmpty && uid != null) {
      unawaited(
        VideoPublishFinalizeService.instance.finalizeDiscoverability(
          videoId: videoId,
          userId: uid,
          waitForMux: false,
        ),
      );
    }
  }

  Future<void> _enterFailed(String? localId, String message) async {
    _pollingTimer?.cancel();
    _currentState = UploadJobState.failed;
    _errorMessage = message;
    _showStatusBar = true;
    if (localId != null) {
      final UploadJob? existing = _activeUploads[localId];
      if (existing != null) {
        _activeUploads[localId] = existing.copyWith(
          state: UploadJobState.failed,
          errorMessage: message,
        );
      }
      await _jobStorage.updateJobState(
        localId,
        UploadJobState.failed,
        errorMessage: message,
      );
    }
    notifyListeners();
  }

  /// Retry after failure — re-upload the current job via BackgroundUploadService.
  Future<void> retryUpload() async {
    final String? localId = _currentJobId;
    if (localId == null) return;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _currentState = UploadJobState.uploading;
    _currentProgress = 0.0;
    _errorMessage = null;
    _uploadStartTime = DateTime.now();
    notifyListeners();
    await _jobStorage.updateJobState(localId, UploadJobState.queued);
    await _uploadService.retryUpload(localId);
    _setupProgressTracking(localId);
  }

  Future<void> cancelUpload(String localId) async {
    _pollingTimer?.cancel();
    await _uploadService.cancelUpload(localId);
    _cleanupJob(localId);
    _reset();
  }

  void dismissStatusBar() {
    if (_currentState == UploadJobState.ready ||
        _currentState == UploadJobState.failed) {
      final String? localId = _currentJobId;
      if (localId != null && _currentState == UploadJobState.failed) {
        unawaited(_jobStorage.deleteJob(localId));
        _cleanupJob(localId);
      }
      _reset();
    }
  }

  void _reset() {
    _showStatusBar = false;
    _currentState = UploadJobState.idle;
    _currentJobId = null;
    _currentVideoId = null;
    _currentProgress = 0.0;
    _errorMessage = null;
    _thumbnailUrl = null;
    _uploadStartTime = null;
    notifyListeners();
  }

  void _cleanupJob(String localId) {
    _activeUploads.remove(localId);
    _progressSubscriptions[localId]?.cancel();
    _resultSubscriptions[localId]?.cancel();
    _progressSubscriptions.remove(localId);
    _resultSubscriptions.remove(localId);
  }

  Future<void> _resumeActiveUploads() async {
    final List<UploadJob> resumableJobs =
        await _jobStorage.loadResumableJobs();
    for (final UploadJob job in resumableJobs) {
      _activeUploads[job.localId] = job;
      final String? source = job.metadata?['source'] as String?;
      final bool isInScreen = source == 'publish_screen';
      if (job.state == UploadJobState.failed) {
        _currentJobId = job.localId;
        _currentVideoId = job.videoId;
        _currentState = UploadJobState.failed;
        _errorMessage = job.errorMessage ?? 'Upload failed';
        _showStatusBar = true;
        continue;
      }
      if (job.state == UploadJobState.processing && job.videoId != null) {
        _currentJobId = job.localId;
        _currentVideoId = job.videoId;
        _currentState = UploadJobState.processing;
        _showStatusBar = true;
        _pollForReady(job.videoId!);
        continue;
      }
      if (job.state == UploadJobState.uploading ||
          job.state == UploadJobState.queued) {
        _currentJobId = job.localId;
        _currentVideoId = job.videoId;
        _currentState = UploadJobState.uploading;
        _currentProgress = job.progress ?? 0.0;
        _showStatusBar = true;
        // In-screen jobs need the publish UI; surface as failed so Retry works.
        if (isInScreen) {
          await _enterFailed(
            job.localId,
            'Upload interrupted. Tap Retry to finish publishing.',
          );
          continue;
        }
        await _uploadService.startUpload(job.localId);
        _setupProgressTracking(job.localId);
      }
    }
    if (_activeUploads.isNotEmpty && _currentState == UploadJobState.idle) {
      final UploadJob first = _activeUploads.values.first;
      _currentJobId = first.localId;
      _currentVideoId = first.videoId;
      _currentState = first.state;
      _errorMessage = first.errorMessage;
      _showStatusBar = true;
    }
    notifyListeners();
  }

  UploadJob? getUploadStatus(String localId) => _activeUploads[localId];

  double get totalProgress {
    if (_activeUploads.isEmpty) return 0.0;
    final sum = _activeUploads.values
        .map((j) => j.progress ?? 0.0)
        .reduce((a, b) => a + b);
    return sum / _activeUploads.length;
  }

  String _generateLocalId() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random();
    final suffix = String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
    );
    return 'upload_${DateTime.now().millisecondsSinceEpoch}_$suffix';
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    for (final s in _progressSubscriptions.values) {
      s.cancel();
    }
    for (final s in _resultSubscriptions.values) {
      s.cancel();
    }
    super.dispose();
  }
}
