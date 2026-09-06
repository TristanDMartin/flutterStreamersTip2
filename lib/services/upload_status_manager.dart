import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/upload_job.dart';
import '../utils/video_ready_contract.dart';
import 'upload_job_storage_service.dart';
import 'background_upload_service.dart';
import 'video_publish_finalize_service.dart';
import 'publish_transaction_trace.dart';
import 'optimistic_video_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/optimistic_video.dart';
import 'dart:io';

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
        return 'Preparing…';
      case UploadJobState.uploading:
      case UploadJobState.queued:
        if (_currentProgress <= 0.005) {
          return 'Preparing…';
        }
        final pct = (_currentProgress * 100).toStringAsFixed(0);
        final eta = _estimatedTimeRemaining();
        return eta != null
            ? 'Uploading $pct% • $eta left'
            : 'Uploading $pct%...';
      case UploadJobState.processing:
        return 'Processing…';
      case UploadJobState.ready:
      case UploadJobState.done:
        return 'Ready';
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
      state: UploadJobState.validating,
      videoId: videoId,
      progress: 0.0,
      metadata: jobMetadata,
    );
    await _jobStorage.saveJob(job);
    _activeUploads[localId] = job;
    _currentJobId = localId;
    _currentVideoId = videoId;
    _currentState = UploadJobState.validating;
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

  Future<void> markFailed(String message, {String stage = 'UPLOAD_JOB'}) async {
    // Never demote a job whose canonical video is already processing/ready.
    final String? videoId = _currentVideoId;
    if (videoId != null && videoId.isNotEmpty) {
      final _CanonicalUploadPhase? phase =
          await _readCanonicalUploadPhase(videoId);
      if (phase == _CanonicalUploadPhase.ready) {
        debugPrint(
          'JOB_STATE IGNORE_FAIL stage=$stage reason=canonical_ready '
          'videoId=$videoId',
        );
        await _completeFromCanonical(videoId);
        return;
      }
      if (phase == _CanonicalUploadPhase.processing) {
        debugPrint(
          'JOB_STATE IGNORE_FAIL stage=$stage reason=canonical_processing '
          'videoId=$videoId',
        );
        enterProcessing(videoId);
        return;
      }
    }
    debugPrint('JOB_STATE FAILED stage=$stage reason=$message');
    await _enterFailed(_currentJobId, message, stage: stage);
  }

  /// Called after bytes are fully uploaded — waits for Mux webhook via Firestore.
  void enterProcessing(String videoId) {
    _currentVideoId = videoId;
    _currentState = UploadJobState.processing;
    _currentProgress = 0.0;
    _showStatusBar = true;
    debugPrint('PROCESSING videoId=$videoId');
    PublishTransactionTrace.active?.event(
      'MUX_PROCESSING',
      detail: 'videoId=$videoId',
    );
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
    // Poll Firestore until Worker/webhook marks playback ready (or timeout).
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
            stage: 'MUX_READY',
          ),
        );
        return;
      }
      try {
        final doc = await _firestore.collection('videos').doc(videoId).get();
        if (!doc.exists) return;
        final data = doc.data()!;
        if (videoStatusIsFailed(data)) {
          timer.cancel();
          debugPrint('JOB_STATE FAILED reason=mux_processing_failed');
          unawaited(
            _enterFailed(
              null,
              (data['transcodingError'] as String?) ??
                  (data['uploadError'] as String?) ??
                  'Video processing failed. Please try again.',
            ),
          );
          return;
        }
        // Single contract: playable Mux URL + ready status.
        // isReadyForFeed is required for global feeds; private videos still
        // exit Processing when playbackReady + muxPlaybackId land.
        final bool playbackReady = isCanonicalPlaybackReady(data);
        final bool feedReady = isCanonicalFeedReady(data);
        if (!playbackReady) {
          return;
        }
        final thumbUrl =
            data['thumbnailUrl'] as String? ?? data['thumbnail_url'] as String?;
        timer.cancel();
        final PublishTransactionTrace? trace = PublishTransactionTrace.active;
        trace?.ok('mux-ready', detail: 'videoId=$videoId');
        trace?.event('MUX_READY', detail: 'videoId=$videoId');
        trace?.event(
          'FEED_READY',
          detail: 'isReadyForFeed=$feedReady',
        );
        trace?.ok(
          'feed-ready',
          detail: 'isReadyForFeed=$feedReady',
        );
        trace?.end(success: true);
        debugPrint(
          'MUX_WEBHOOK_READY videoId=$videoId '
          'PLAYBACK_READY=true IS_READY_FOR_FEED=$feedReady',
        );
        _enterReady(thumbUrl);
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
    debugPrint('LIVE_TOAST_SHOWN');
    notifyListeners();
    final String? localId = _currentJobId;
    if (localId != null) {
      unawaited(_jobStorage.updateJobState(localId, UploadJobState.ready));
      unawaited(_jobStorage.deleteJob(localId));
      _cleanupJob(localId);
    }
    final String? videoId = _currentVideoId;
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    // Keep optimistic local playback until the Home/Profile surfaces pick up
    // the canonical remote-ready row. Removing here caused Instant Play to
    // collapse into the "Posting…" processing cell.
    if (videoId != null && videoId.isNotEmpty) {
      OptimisticVideoService().requestFeedRefresh();
    }
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

  Future<void> _enterFailed(
    String? localId,
    String message, {
    String stage = 'UPLOAD_JOB',
  }) async {
    _pollingTimer?.cancel();
    _currentState = UploadJobState.failed;
    _errorMessage = message;
    _showStatusBar = true;
    final PublishTransactionTrace? trace = PublishTransactionTrace.active;
    if (trace != null) {
      trace.publishFailed(
        stageName: stage,
        videoId: _currentVideoId,
        detail: message,
      );
      trace.fail(stage.toLowerCase(), detail: message);
      trace.end(success: false);
    }
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

  /// Retry after failure — reconcile canonical state before any re-upload.
  Future<void> retryUpload() async {
    final String? localId = _currentJobId;
    if (localId == null) {
      return;
    }
    final String? videoId =
        _currentVideoId ?? _activeUploads[localId]?.videoId;
    if (videoId != null && videoId.isNotEmpty) {
      final _CanonicalUploadPhase? phase =
          await _readCanonicalUploadPhase(videoId);
      if (phase == _CanonicalUploadPhase.ready) {
        debugPrint(
          'UPLOAD_RETRY_SKIPPED videoId=$videoId reason=canonical_ready',
        );
        await _completeFromCanonical(videoId, localId: localId);
        return;
      }
      if (phase == _CanonicalUploadPhase.processing) {
        debugPrint(
          'UPLOAD_RETRY_SKIPPED videoId=$videoId reason=canonical_processing',
        );
        _errorMessage = null;
        enterProcessing(videoId);
        return;
      }
      if (phase == _CanonicalUploadPhase.serverFailed) {
        debugPrint(
          'UPLOAD_RETRY_BLOCKED videoId=$videoId reason=server_failed',
        );
        await _enterFailed(
          localId,
          'Video processing failed on the server. Start a new post.',
          stage: 'CANONICAL_FAILED',
        );
        return;
      }
      // notFound / needsPut / null → fall through to resume PUT / restart.
      debugPrint(
        'UPLOAD_RETRY_CONTINUE videoId=$videoId phase=${phase?.name ?? "unknown"}',
      );
    }
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

  /// Drop every local upload job / status bar (stuck Instant Publish cleanup).
  Future<void> discardAllUploads() async {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    final List<String> localIds = _activeUploads.keys.toList();
    for (final String localId in localIds) {
      try {
        await _uploadService.cancelUpload(localId);
      } catch (_) {
        // Best-effort cancel.
      }
      _cleanupJob(localId);
    }
    await _jobStorage.clearAllJobs();
    _reset();
    notifyListeners();
    debugPrint('UPLOAD_STATUS discardAllUploads count=${localIds.length}');
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
    final OptimisticVideoService optimistic = OptimisticVideoService();
    // Only resume jobs that still exist on disk — do not rehydrate every
    // Instant Publish JSON (that revived ghost "still posting" cards).
    for (final UploadJob job in resumableJobs) {
      _activeUploads[job.localId] = job;
      await _restoreOptimisticFromJob(job);
      final String? source = job.metadata?['source'] as String?;
      final bool isInScreen = source == 'publish_screen';
      final String? videoId = job.videoId?.trim();
      if (videoId != null && videoId.isNotEmpty) {
        final _CanonicalUploadPhase? phase =
            await _readCanonicalUploadPhase(videoId);
        if (phase == _CanonicalUploadPhase.ready) {
          debugPrint(
            'UPLOAD_RESUME_RECONCILE videoId=$videoId phase=ready '
            'localState=${job.state.name}',
          );
          await _completeFromCanonical(videoId, localId: job.localId);
          continue;
        }
        if (phase == _CanonicalUploadPhase.processing) {
          debugPrint(
            'UPLOAD_RESUME_RECONCILE videoId=$videoId phase=processing '
            'localState=${job.state.name}',
          );
          _currentJobId = job.localId;
          _currentVideoId = videoId;
          _errorMessage = null;
          enterProcessing(videoId);
          continue;
        }
        if (phase == _CanonicalUploadPhase.serverFailed) {
          _currentJobId = job.localId;
          _currentVideoId = videoId;
          await _enterFailed(
            job.localId,
            job.errorMessage ??
                'Video processing failed. Please try again.',
            stage: 'CANONICAL_FAILED',
          );
          continue;
        }
      }
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
          job.state == UploadJobState.queued ||
          job.state == UploadJobState.validating) {
        _currentJobId = job.localId;
        _currentVideoId = job.videoId;
        _currentState = UploadJobState.uploading;
        _currentProgress = job.progress ?? 0.0;
        _showStatusBar = true;
        // In-screen publish owns the PUT. Canonical ready/processing was
        // already handled above — remaining means bytes may still be needed.
        if (isInScreen) {
          await _enterFailed(
            job.localId,
            'Upload interrupted. Tap Retry to finish publishing.',
            stage: 'UPLOAD_PUT',
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
    if (resumableJobs.isNotEmpty) {
      optimistic.requestFeedRefresh();
    }
    debugPrint('UPLOAD_RESUME resumable=${resumableJobs.length}');
  }

  Future<_CanonicalUploadPhase?> _readCanonicalUploadPhase(
    String videoId,
  ) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _firestore.collection('videos').doc(videoId).get(
                const GetOptions(source: Source.server),
              );
      if (!doc.exists || doc.data() == null) {
        return _CanonicalUploadPhase.notFound;
      }
      final Map<String, dynamic> data = doc.data()!;
      if (videoStatusIsFailed(data)) {
        return _CanonicalUploadPhase.serverFailed;
      }
      final bool feedReady = isCanonicalFeedReady(data);
      final bool playbackReady = isCanonicalPlaybackReady(data);
      final String? muxPlaybackId =
          (data['muxPlaybackId'] as String?)?.trim() ??
              (data['mux_playback_id'] as String?)?.trim();
      if (feedReady ||
          (playbackReady &&
              muxPlaybackId != null &&
              muxPlaybackId.isNotEmpty)) {
        debugPrint(
          'CANONICAL_READY videoId=$videoId feedReady=$feedReady '
          'muxPlaybackId=${muxPlaybackId ?? "-"}',
        );
        return _CanonicalUploadPhase.ready;
      }
      final String status =
          (data['status'] as String? ?? '').trim().toLowerCase();
      if (status == 'processing' ||
          status == 'uploading' ||
          status == 'pending' ||
          (data['muxStatus'] as String?)?.toLowerCase() == 'processing' ||
          (data['muxStatus'] as String?)?.toLowerCase() == 'waiting') {
        return _CanonicalUploadPhase.processing;
      }
      final String? muxUploadId =
          (data['muxUploadId'] as String?)?.trim() ??
              (data['uploadId'] as String?)?.trim();
      if (muxUploadId != null && muxUploadId.isNotEmpty) {
        // Doc exists with Mux upload id but not processing/ready yet —
        // PUT may still be needed.
        return _CanonicalUploadPhase.needsPut;
      }
      return _CanonicalUploadPhase.needsPut;
    } catch (e) {
      debugPrint('UPLOAD_CANONICAL_LOOKUP_FAILED videoId=$videoId error=$e');
      return null;
    }
  }

  Future<void> _completeFromCanonical(
    String videoId, {
    String? localId,
  }) async {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    String? thumbUrl;
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _firestore.collection('videos').doc(videoId).get();
      final Map<String, dynamic>? data = doc.data();
      thumbUrl = data?['thumbnailUrl'] as String? ??
          data?['thumbnail_url'] as String?;
    } catch (_) {
      // Best-effort thumbnail.
    }
    final String? jobId = localId ?? _currentJobId;
    _currentJobId = jobId;
    _currentVideoId = videoId;
    _errorMessage = null;
    // Drop durable Instant Publish pending once canonical is READY.
    OptimisticVideoService().removeOptimisticVideo(videoId);
    OptimisticVideoService().requestFeedRefresh();
    _enterReady(thumbUrl);
    debugPrint(
      'UPLOAD_JOB_COMPLETED_FROM_CANONICAL videoId=$videoId localId=${jobId ?? "-"}',
    );
  }

  Future<void> _restoreOptimisticFromJob(UploadJob job) async {
    final String? videoId = job.videoId;
    if (videoId == null || videoId.isEmpty) {
      return;
    }
    final OptimisticVideoService optimistic = OptimisticVideoService();
    if (optimistic.isOptimisticVideo(videoId)) {
      optimistic.attachServerListener(videoId);
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final String fileUri = job.fileUri.trim();
    final String? thumbUri = job.thumbUri?.trim();
    String? localVideoPath;
    if (fileUri.isNotEmpty) {
      final String path = fileUri.startsWith('file://')
          ? Uri.parse(fileUri).toFilePath()
          : fileUri;
      if (File(path).existsSync()) {
        localVideoPath = path;
      }
    }
    String? localThumbPath;
    if (thumbUri != null && thumbUri.isNotEmpty) {
      final String path = thumbUri.startsWith('file://')
          ? Uri.parse(thumbUri).toFilePath()
          : thumbUri;
      if (File(path).existsSync()) {
        localThumbPath = path;
      }
    }
    final OptimisticVideo restored = OptimisticVideoFactory.createPlaceholder(
      videoId: videoId,
      ownerId: user.uid,
      caption: job.title,
      categories: job.categories,
      localThumbnailPath: localThumbPath,
      localVideoPath: localVideoPath,
      metadata: job.metadata,
    ).copyWith(
      status: job.state == UploadJobState.failed
          ? VideoStatus.uploadFailed
          : VideoStatus.processing,
      errorMessage: job.errorMessage,
      uploadProgress: job.progress,
      createdAt: job.createdAt,
    );
    await optimistic.restoreOptimisticVideo(restored);
    debugPrint('OPTIMISTIC_RESUME_FROM_JOB videoId=$videoId');
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

/// Server-authoritative phase for a local upload job.
enum _CanonicalUploadPhase {
  ready,
  processing,
  needsPut,
  notFound,
  serverFailed,
}
