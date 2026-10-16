import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'video_upload_service.dart';
import 'video_compression_service.dart';

enum UploadStatus {
  queued,
  compressing,
  uploading,
  completed,
  failed,
  cancelled,
}

class UploadTask {
  UploadTask({
    required this.id,
    required this.videoFile,
    required this.caption,
    required this.hashtags,
    this.thumbnailFile,
    this.status = UploadStatus.queued,
    this.progress = 0.0,
    this.error,
    this.retryCount = 0,
    this.videoUrl,
  });

  final String id;
  final File videoFile;
  final String caption;
  final List<String> hashtags;
  File? thumbnailFile;
  UploadStatus status;
  double progress;
  String? error;
  int retryCount;
  String? videoUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'videoPath': videoFile.path,
        'caption': caption,
        'hashtags': hashtags,
        'thumbnailPath': thumbnailFile?.path,
        'status': status.name,
        'progress': progress,
        'error': error,
        'retryCount': retryCount,
        'videoUrl': videoUrl,
      };
}

class UploadQueueManager {
  static final UploadQueueManager _instance = UploadQueueManager._internal();
  factory UploadQueueManager() => _instance;
  UploadQueueManager._internal();

  final Queue<UploadTask> _queue = Queue<UploadTask>();
  final List<UploadTask> _history = [];
  UploadTask? _currentTask;
  bool _isProcessing = false;

  final VideoUploadService _uploadService = VideoUploadService();
  final _statusController = StreamController<List<UploadTask>>.broadcast();
  Stream<List<UploadTask>> get statusStream => _statusController.stream;

  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 5);

  /// Add upload task to queue
  String enqueueUpload({
    required File videoFile,
    required String caption,
    required List<String> hashtags,
    File? thumbnailFile,
  }) {
    final id = 'upload_${DateTime.now().millisecondsSinceEpoch}';
    final task = UploadTask(
      id: id,
      videoFile: videoFile,
      caption: caption,
      hashtags: hashtags,
      thumbnailFile: thumbnailFile,
    );

    _queue.add(task);
    _history.add(task);
    _notifyListeners();

    debugPrint('📤 Upload task queued: $id');

    if (!_isProcessing) {
      _processQueue();
    }

    return id;
  }

  /// Process upload queue
  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;

    while (_queue.isNotEmpty) {
      _currentTask = _queue.removeFirst();
      _notifyListeners();

      debugPrint('🚀 Processing upload: ${_currentTask!.id}');

      try {
        await _processUploadTask(_currentTask!);
      } catch (e) {
        debugPrint('❌ Upload task failed: $e');
        _currentTask!.status = UploadStatus.failed;
        _currentTask!.error = e.toString();

        // Retry logic
        if (_currentTask!.retryCount < maxRetries) {
          _currentTask!.retryCount++;
          debugPrint('🔄 Retrying (${_currentTask!.retryCount}/$maxRetries)...');
          await Future.delayed(retryDelay);
          _queue.addFirst(_currentTask!);
        }
      }

      _notifyListeners();
    }

    _currentTask = null;
    _isProcessing = false;
    _notifyListeners();
  }

  /// Process individual upload task with real Mux upload
  Future<void> _processUploadTask(UploadTask task) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('User not authenticated');
    }

    try {
      // Step 1: Update status to uploading
      task.status = UploadStatus.uploading;
      task.progress = 0.1;
      _notifyListeners();

      // Step 2: Call real video upload service
      debugPrint('📤 Starting real Mux upload for task: ${task.id}');
      
      final result = await _uploadService.uploadVideo(
        videoFile: task.videoFile,
        caption: task.caption,
        hashtags: task.hashtags,
        privacy: 'public',
        allowComments: true,
        isDraft: false,
      );

      // Step 3: Handle result
      if (result.success) {
        task.status = UploadStatus.completed;
        task.progress = 1.0;
        task.videoUrl = result.videoUrl;
        debugPrint('✅ Upload completed successfully: ${task.id}');
        debugPrint('   Video URL: ${result.videoUrl}');
      } else {
        throw StateError(result.error ?? 'Upload failed without error message');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Upload task failed: ${task.id}');
      debugPrint('   Error: $e');
      debugPrint('   Stack: $stackTrace');
      
      task.status = UploadStatus.failed;
      task.error = e.toString();
      task.progress = 0.0;
      
      rethrow;
    }
  }

  /// Cancel specific upload
  void cancelUpload(String id) {
    final task = _history.firstWhere(
      (t) => t.id == id,
      orElse: () => throw Exception('Task not found'),
    );

    if (task.status == UploadStatus.queued) {
      _queue.remove(task);
    }

    task.status = UploadStatus.cancelled;
    _notifyListeners();

    debugPrint('🚫 Upload cancelled: $id');
  }

  /// Retry failed upload
  void retryUpload(String id) {
    final task = _history.firstWhere(
      (t) => t.id == id,
      orElse: () => throw Exception('Task not found'),
    );

    if (task.status == UploadStatus.failed) {
      task.status = UploadStatus.queued;
      task.progress = 0.0;
      task.error = null;
      task.retryCount = 0;
      _queue.add(task);
      _notifyListeners();

      if (!_isProcessing) {
        _processQueue();
      }

      debugPrint('🔄 Retrying upload: $id');
    }
  }

  /// Get all tasks
  List<UploadTask> getAllTasks() => List.unmodifiable(_history);

  /// Get active tasks
  List<UploadTask> getActiveTasks() {
    return _history.where((task) {
      return task.status == UploadStatus.queued ||
          task.status == UploadStatus.compressing ||
          task.status == UploadStatus.uploading;
    }).toList();
  }

  /// Get completed tasks
  List<UploadTask> getCompletedTasks() {
    return _history.where((task) {
      return task.status == UploadStatus.completed;
    }).toList();
  }

  /// Get failed tasks
  List<UploadTask> getFailedTasks() {
    return _history.where((task) {
      return task.status == UploadStatus.failed;
    }).toList();
  }

  /// Clear completed tasks
  void clearCompleted() {
    _history.removeWhere((task) => task.status == UploadStatus.completed);
    _notifyListeners();
  }

  /// Clear all tasks
  void clearAll() {
    _queue.clear();
    _history.clear();
    _currentTask = null;
    _notifyListeners();
  }

  void _notifyListeners() {
    _statusController.add(_history);
  }

  void dispose() {
    _statusController.close();
  }
}
