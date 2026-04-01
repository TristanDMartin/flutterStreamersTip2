import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/upload_job.dart';
import 'upload_job_storage_service.dart';
import 'video_upload_service.dart';

class BackgroundUploadService {
  static final BackgroundUploadService _instance =
      BackgroundUploadService._internal();
  factory BackgroundUploadService() => _instance;
  BackgroundUploadService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UploadJobStorageService _jobStorage = UploadJobStorageService();
  final VideoUploadService _uploadService = VideoUploadService();

  final Map<String, StreamController<double>> _progressControllers = {};
  final Map<String, StreamController<UploadResult>> _resultControllers = {};

  Future<void> startUpload(String localId) async {
    final job = await _jobStorage.loadJob(localId);
    if (job == null) {
      log('❌ Upload job not found: $localId');
      return;
    }
    if (job.state != UploadJobState.queued) {
      log('❌ Job is not in queued state: ${job.state}');
      return;
    }
    try {
      await _jobStorage.updateJobState(localId, UploadJobState.uploading);
      _progressControllers[localId] = StreamController<double>.broadcast();
      _resultControllers[localId] = StreamController<UploadResult>.broadcast();
      await _performUpload(job);
    } catch (e) {
      log('❌ Error starting upload for job $localId: $e');
      await _jobStorage.updateJobState(
        localId,
        UploadJobState.failed,
        errorMessage: e.toString(),
      );
      _resultControllers[localId]?.add(UploadResult.failure(e.toString()));
    }
  }

  Future<void> _performUpload(UploadJob job) async {
    final localId = job.localId;
    final file = File(job.fileUri);
    if (!await file.exists()) {
      throw Exception('Video file not found: ${job.fileUri}');
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    try {
      log('📤 Starting Mux upload for job $localId');
      void onProgress(double p) {
        _progressControllers[localId]?.add(p);
        log('📊 Upload progress for $localId: ${(p * 100).toStringAsFixed(1)}%');
      }
      final result = await _uploadService.uploadVideo(
        videoFile: file,
        caption: job.title,
        hashtags: job.categories,
        privacy: 'public',
        allowComments: true,
        additionalMetadata: job.metadata,
        onProgress: onProgress,
      );
      if (!result.success) {
        throw Exception(result.error ?? 'Upload failed');
      }
      final placeholderUrl = result.videoUrl ?? result.thumbnailUrl ?? '';
      await _jobStorage.updateJobState(localId, UploadJobState.done);
      _resultControllers[localId]?.add(
        UploadResult.success(placeholderUrl, placeholderUrl),
      );
      log('✅ Upload completed successfully for job $localId');
    } catch (e) {
      log('❌ Upload failed for job $localId: $e');
      await _jobStorage.updateJobState(
        localId,
        UploadJobState.failed,
        errorMessage: e.toString(),
      );
      _resultControllers[localId]?.add(UploadResult.failure(e.toString()));
    }
  }

  Stream<double>? getUploadProgress(String localId) {
    return _progressControllers[localId]?.stream;
  }

  Stream<UploadResult>? getUploadResult(String localId) {
    return _resultControllers[localId]?.stream;
  }

  Future<void> cancelUpload(String localId) async {
    await _jobStorage.updateJobState(
      localId,
      UploadJobState.failed,
      errorMessage: 'Cancelled by user',
    );
    _progressControllers[localId]?.close();
    _resultControllers[localId]?.close();
  }

  Future<void> retryUpload(String localId) async {
    await _jobStorage.updateJobState(localId, UploadJobState.queued);
    await startUpload(localId);
  }

  Future<void> resumeActiveUploads() async {
    final activeJobs = await _jobStorage.loadActiveJobs();
    for (final job in activeJobs) {
      if (job.state == UploadJobState.queued) {
        await startUpload(job.localId);
      }
    }
  }

  void dispose() {
    for (final controller in _progressControllers.values) {
      controller.close();
    }
    for (final controller in _resultControllers.values) {
      controller.close();
    }
    _progressControllers.clear();
    _resultControllers.clear();
  }
}

class UploadResult {
  final bool success;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? errorMessage;

  UploadResult._({
    required this.success,
    this.videoUrl,
    this.thumbnailUrl,
    this.errorMessage,
  });

  factory UploadResult.success(String videoUrl, String thumbnailUrl) {
    return UploadResult._(
      success: true,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
    );
  }

  factory UploadResult.failure(String errorMessage) {
    return UploadResult._(
      success: false,
      errorMessage: errorMessage,
    );
  }
}
