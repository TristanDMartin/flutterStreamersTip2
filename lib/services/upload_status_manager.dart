import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/upload_job.dart';
import 'upload_job_storage_service.dart';
import 'background_upload_service.dart';

class UploadStatusManager extends ChangeNotifier {
  static final UploadStatusManager _instance = UploadStatusManager._internal();
  factory UploadStatusManager() => _instance;
  UploadStatusManager._internal();

  final UploadJobStorageService _jobStorage = UploadJobStorageService();
  final BackgroundUploadService _uploadService = BackgroundUploadService();

  // Active uploads tracking
  final Map<String, UploadJob> _activeUploads = {};
  final Map<String, StreamSubscription<double>> _progressSubscriptions = {};
  final Map<String, StreamSubscription<UploadResult>> _resultSubscriptions = {};

  // Status UI state
  bool _showStatusBar = false;
  String _currentStatusMessage = '';
  double _currentProgress = 0.0;
  String? _currentJobId;

  // Getters
  bool get showStatusBar => _showStatusBar;
  String get currentStatusMessage => _currentStatusMessage;
  double get currentProgress => _currentProgress;
  String? get currentJobId => _currentJobId;
  List<UploadJob> get activeUploads => _activeUploads.values.toList();

  /// Initialize the upload status manager
  Future<void> initialize() async {
    await _jobStorage.initialize();
    await _resumeActiveUploads();
  }

  /// Start upload with optimistic UI updates
  Future<String> startUpload({
    required String fileUri,
    String? thumbUri,
    required String title,
    required List<String> categories,
    required String videoId,
    Map<String, dynamic>? metadata,
  }) async {
    final localId = _generateLocalId();
    
    // Create upload job
    final job = UploadJob(
      localId: localId,
      fileUri: fileUri,
      thumbUri: thumbUri,
      title: title,
      categories: categories,
      createdAt: DateTime.now(),
      state: UploadJobState.queued,
      videoId: videoId,
      metadata: metadata,
    );

    // Save job to local storage
    await _jobStorage.saveJob(job);
    _activeUploads[localId] = job;

    // Start background upload
    await _uploadService.startUpload(localId);

    // Set up progress tracking
    _setupProgressTracking(localId);

    // Show status UI
    _showUploadStatus(localId, 'Uploading...', 0.0);

    return localId;
  }

  /// Set up progress tracking for a job
  void _setupProgressTracking(String localId) {
    // Progress tracking
    final progressStream = _uploadService.getUploadProgress(localId);
    if (progressStream != null) {
      _progressSubscriptions[localId] = progressStream.listen((progress) {
        _updateUploadProgress(localId, progress);
      });
    }

    // Result tracking
    final resultStream = _uploadService.getUploadResult(localId);
    if (resultStream != null) {
      _resultSubscriptions[localId] = resultStream.listen((result) {
        _handleUploadResult(localId, result);
      });
    }
  }

  /// Update upload progress
  void _updateUploadProgress(String localId, double progress) {
    _currentProgress = progress;
    _currentStatusMessage = 'Uploading ${(progress * 100).toStringAsFixed(0)}%...';
    notifyListeners();
  }

  /// Handle upload result
  void _handleUploadResult(String localId, UploadResult result) {
    if (result.success) {
      _showSuccessMessage('Published 🎉');
      _hideStatusBar();
      _cleanupJob(localId);
    } else {
      _showErrorMessage('Upload failed — retry');
      _hideStatusBar();
    }
  }

  /// Show upload status
  void _showUploadStatus(String jobId, String message, double progress) {
    _showStatusBar = true;
    _currentJobId = jobId;
    _currentStatusMessage = message;
    _currentProgress = progress;
    notifyListeners();
  }

  /// Show success message
  void _showSuccessMessage(String message) {
    _currentStatusMessage = message;
    _currentProgress = 1.0;
    notifyListeners();

    // Hide after 3 seconds
    Timer(const Duration(seconds: 3), () {
      _hideStatusBar();
    });
  }

  /// Show error message
  void _showErrorMessage(String message) {
    _currentStatusMessage = message;
    _currentProgress = 0.0;
    notifyListeners();

    // Hide after 5 seconds
    Timer(const Duration(seconds: 5), () {
      _hideStatusBar();
    });
  }

  /// Hide status bar
  void _hideStatusBar() {
    _showStatusBar = false;
    _currentJobId = null;
    _currentStatusMessage = '';
    _currentProgress = 0.0;
    notifyListeners();
  }

  /// Clean up completed job
  void _cleanupJob(String localId) {
    _activeUploads.remove(localId);
    _progressSubscriptions[localId]?.cancel();
    _resultSubscriptions[localId]?.cancel();
    _progressSubscriptions.remove(localId);
    _resultSubscriptions.remove(localId);
  }

  /// Retry failed upload
  Future<void> retryUpload(String localId) async {
    await _uploadService.retryUpload(localId);
    _setupProgressTracking(localId);
    _showUploadStatus(localId, 'Retrying upload...', 0.0);
  }

  /// Cancel upload
  Future<void> cancelUpload(String localId) async {
    await _uploadService.cancelUpload(localId);
    _cleanupJob(localId);
    _hideStatusBar();
  }

  /// Resume active uploads on app start
  Future<void> _resumeActiveUploads() async {
    final activeJobs = await _jobStorage.loadActiveJobs();
    for (final job in activeJobs) {
      _activeUploads[job.localId] = job;
      if (job.state == UploadJobState.queued) {
        await _uploadService.startUpload(job.localId);
        _setupProgressTracking(job.localId);
      }
    }

    if (_activeUploads.isNotEmpty) {
      final firstJob = _activeUploads.values.first;
      _showUploadStatus(
        firstJob.localId,
        'Resuming upload...',
        firstJob.progress ?? 0.0,
      );
    }
  }

  /// Get upload status for a specific job
  UploadJob? getUploadStatus(String localId) {
    return _activeUploads[localId];
  }

  /// Check if there are any active uploads
  bool get hasActiveUploads => _activeUploads.isNotEmpty;

  /// Get total upload progress (average of all active uploads)
  double get totalProgress {
    if (_activeUploads.isEmpty) return 0.0;
    
    final totalProgress = _activeUploads.values
        .map((job) => job.progress ?? 0.0)
        .reduce((a, b) => a + b);
    
    return totalProgress / _activeUploads.length;
  }

  /// Generate unique local ID
  String _generateLocalId() {
    return 'upload_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(6)}';
  }

  /// Generate random string
  String _generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  @override
  void dispose() {
    for (final subscription in _progressSubscriptions.values) {
      subscription.cancel();
    }
    for (final subscription in _resultSubscriptions.values) {
      subscription.cancel();
    }
    _progressSubscriptions.clear();
    _resultSubscriptions.clear();
    _activeUploads.clear();
    super.dispose();
  }
}
