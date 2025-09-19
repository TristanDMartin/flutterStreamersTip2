import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/upload_job.dart';
import 'upload_job_storage_service.dart';

class BackgroundUploadService {
  static final BackgroundUploadService _instance = BackgroundUploadService._internal();
  factory BackgroundUploadService() => _instance;
  BackgroundUploadService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UploadJobStorageService _jobStorage = UploadJobStorageService();

  // Upload progress streams
  final Map<String, StreamController<double>> _progressControllers = {};
  final Map<String, StreamController<UploadResult>> _resultControllers = {};

  // Active upload tasks
  final Map<String, UploadTask> _activeUploads = {};

  /// Start background upload for a job
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
      // Update job state to uploading
      await _jobStorage.updateJobState(localId, UploadJobState.uploading);

      // Create progress controller
      _progressControllers[localId] = StreamController<double>.broadcast();
      _resultControllers[localId] = StreamController<UploadResult>.broadcast();

      // Start upload process
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

  /// Perform the actual upload with chunked upload and resume support
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
      // 1. Upload video file with chunked upload
      log('📤 Starting chunked upload for job $localId');
      final videoUrl = await _uploadVideoFile(file, job.videoId ?? localId, user.uid, localId);
      
      // 2. Generate and upload thumbnail
      log('🖼️ Generating thumbnail for job $localId');
      final thumbnailUrl = await _generateAndUploadThumbnail(file, job.videoId ?? localId, user.uid);
      
      // 3. Update Firestore with final video data
      log('💾 Updating Firestore for job $localId');
      await _updateVideoDocument(
        job.videoId ?? localId,
        user.uid,
        videoUrl,
        thumbnailUrl,
        job,
      );

      // 4. Mark job as completed
      await _jobStorage.updateJobState(localId, UploadJobState.done);
      _resultControllers[localId]?.add(UploadResult.success(videoUrl, thumbnailUrl));

      log('✅ Upload completed successfully for job $localId');

    } catch (e) {
      log('❌ Upload failed for job $localId: $e');
      await _jobStorage.updateJobState(
        localId, 
        UploadJobState.failed, 
        errorMessage: e.toString(),
      );
      _resultControllers[localId]?.add(UploadResult.failure(e.toString()));
    } finally {
      _activeUploads.remove(localId);
    }
  }

  /// Upload video file with chunked upload and resume support
  Future<String> _uploadVideoFile(File file, String videoId, String userId, String localId) async {
    final ref = _storage
        .ref()
        .child('videos')
        .child(userId)
        .child('$videoId.mp4');

    // Create upload task with metadata
    final metadata = SettableMetadata(
      contentType: 'video/mp4',
      customMetadata: {
        'uploadedAt': DateTime.now().toIso8601String(),
        'originalName': file.path.split('/').last,
        'localId': localId,
      },
    );

    final uploadTask = ref.putFile(file, metadata);
    _activeUploads[localId] = uploadTask;

    // Listen to upload progress
    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      final progress = snapshot.bytesTransferred / snapshot.totalBytes;
      _progressControllers[localId]?.add(progress);
      log('📊 Upload progress for $localId: ${(progress * 100).toStringAsFixed(1)}%');
    });

    // Wait for upload to complete
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Generate and upload thumbnail
  Future<String> _generateAndUploadThumbnail(File videoFile, String videoId, String userId) async {
    // For now, we'll use a placeholder thumbnail
    // In a real implementation, you would use FFmpeg or similar to extract a frame
    final ref = _storage
        .ref()
        .child('thumbnails')
        .child(userId)
        .child('$videoId.jpg');

    // Create a simple placeholder thumbnail
    // Note: In production, this would use FFmpeg or video_thumbnail package to extract a frame
    final placeholderData = await _createPlaceholderThumbnail();
    
    final uploadTask = ref.putData(Uint8List.fromList(placeholderData));
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Create placeholder thumbnail (temporary implementation)
  Future<List<int>> _createPlaceholderThumbnail() async {
    // This is a placeholder - in real implementation, extract frame from video
    // For now, return a simple 1x1 pixel image
    return [
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x01, 0x00, 0x48,
      0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43, 0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08,
      0x07, 0x07, 0x07, 0x09, 0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
      0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20, 0x24, 0x2E, 0x27, 0x20,
      0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29, 0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27,
      0x39, 0x3D, 0x38, 0x32, 0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x11, 0x08, 0x00, 0x01,
      0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01, 0xFF, 0xC4, 0x00, 0x14,
      0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x08, 0xFF, 0xC4, 0x00, 0x14, 0x10, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xDA, 0x00, 0x0C, 0x03, 0x01, 0x00, 0x02,
      0x11, 0x03, 0x11, 0x00, 0x3F, 0x00, 0x00, 0xFF, 0xD9
    ];
  }

  /// Update Firestore document with final video data
  Future<void> _updateVideoDocument(
    String videoId,
    String userId,
    String videoUrl,
    String thumbnailUrl,
    UploadJob job,
  ) async {
    await _firestore.collection('videos').doc(videoId).update({
      'status': 'ready',
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'updatedAt': FieldValue.serverTimestamp(),
      'duration': job.metadata?['duration'] ?? 0,
      'fileSize': job.metadata?['fileSize'] ?? 0,
    });

    // Update user's video list
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('videos')
        .doc(videoId)
        .update({
      'status': 'ready',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get upload progress stream
  Stream<double>? getUploadProgress(String localId) {
    return _progressControllers[localId]?.stream;
  }

  /// Get upload result stream
  Stream<UploadResult>? getUploadResult(String localId) {
    return _resultControllers[localId]?.stream;
  }

  /// Cancel upload
  Future<void> cancelUpload(String localId) async {
    final uploadTask = _activeUploads[localId];
    if (uploadTask != null) {
      await uploadTask.cancel();
      _activeUploads.remove(localId);
    }
    
    await _jobStorage.updateJobState(localId, UploadJobState.failed, errorMessage: 'Cancelled by user');
    _progressControllers[localId]?.close();
    _resultControllers[localId]?.close();
  }

  /// Retry failed upload
  Future<void> retryUpload(String localId) async {
    await _jobStorage.updateJobState(localId, UploadJobState.queued);
    await startUpload(localId);
  }

  /// Resume all active uploads (called on app start)
  Future<void> resumeActiveUploads() async {
    final activeJobs = await _jobStorage.loadActiveJobs();
    for (final job in activeJobs) {
      if (job.state == UploadJobState.queued) {
        await startUpload(job.localId);
      }
    }
  }

  /// Clean up resources
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
