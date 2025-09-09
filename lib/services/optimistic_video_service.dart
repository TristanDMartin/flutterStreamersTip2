import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/optimistic_video.dart';

class OptimisticVideoService extends ChangeNotifier {
  static final OptimisticVideoService _instance = OptimisticVideoService._internal();
  factory OptimisticVideoService() => _instance;
  OptimisticVideoService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Optimistic videos cache
  final Map<String, OptimisticVideo> _optimisticVideos = {};
  final Map<String, StreamSubscription> _videoListeners = {};

  // Feed refresh triggers
  final StreamController<String> _feedRefreshController = StreamController<String>.broadcast();
  final StreamController<List<String>> _categoryRefreshController = StreamController<List<String>>.broadcast();

  // Getters
  List<OptimisticVideo> get optimisticVideos => _optimisticVideos.values.toList();
  Stream<String> get feedRefreshStream => _feedRefreshController.stream;
  Stream<List<String>> get categoryRefreshStream => _categoryRefreshController.stream;

  /// Create optimistic video placeholder
  Future<OptimisticVideo> createOptimisticVideo({
    required String videoId,
    required String caption,
    required List<String> categories,
    String? localThumbnailPath,
    String? localVideoPath,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Create optimistic video
    final optimisticVideo = OptimisticVideoFactory.createPlaceholder(
      videoId: videoId,
      ownerId: user.uid,
      caption: caption,
      categories: categories,
      localThumbnailPath: localThumbnailPath,
      localVideoPath: localVideoPath,
      metadata: metadata,
    );

    // Add to cache
    _optimisticVideos[videoId] = optimisticVideo;

    // Create placeholder documents in Firestore
    await _createPlaceholderDocuments(optimisticVideo);

    // Set up listener for this video
    _setupVideoListener(videoId);

    // Trigger feed refresh
    _feedRefreshController.add('home');
    _categoryRefreshController.add(categories);

    notifyListeners();
    return optimisticVideo;
  }

  /// Create placeholder documents in Firestore
  Future<void> _createPlaceholderDocuments(OptimisticVideo video) async {
    // Create main video document
    await _firestore.collection('videos').doc(video.videoId).set({
      'ownerId': video.ownerId,
      'caption': video.caption,
      'categories': video.categories,
      'createdAt': video.createdAt,
      'status': 'processing',
      'thumbnailUrl': video.localThumbnailPath, // Use local thumbnail initially
      'videoUrl': null,
      'hlsUrl': null,
      'duration': video.duration ?? 0,
      'fileSize': video.fileSize ?? 0,
      'metadata': video.metadata ?? {},
    });

    // Add to user's video list
    await _firestore
        .collection('users')
        .doc(video.ownerId)
        .collection('videos')
        .doc(video.videoId)
        .set({
      'createdAt': video.createdAt,
      'status': 'processing',
    });

    // Add to category feeds for each category
    for (final category in video.categories) {
      await _firestore
          .collection('feeds')
          .doc('categories')
          .collection(category)
          .doc(video.videoId)
          .set({
        'videoId': video.videoId,
        'userId': video.ownerId,
        'category': category,
        'status': 'processing',
        'addedAt': video.createdAt,
      });
    }

    // Add to public feeds (for_you)
    await _firestore
        .collection('feeds')
        .doc('for_you')
        .collection('videos')
        .doc(video.videoId)
        .set({
      'videoId': video.videoId,
      'userId': video.ownerId,
      'status': 'processing',
      'addedAt': video.createdAt,
    });

    // Add to following feed
    await _firestore
        .collection('feeds')
        .doc('following')
        .collection('videos')
        .doc(video.videoId)
        .set({
      'videoId': video.videoId,
      'userId': video.ownerId,
      'status': 'processing',
      'addedAt': video.createdAt,
    });
  }

  /// Set up listener for video status changes
  void _setupVideoListener(String videoId) {
    _videoListeners[videoId] = _firestore
        .collection('videos')
        .doc(videoId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        _handleVideoUpdate(videoId, data);
      }
    });
  }

  /// Handle video status update
  void _handleVideoUpdate(String videoId, Map<String, dynamic> data) {
    final status = data['status'] as String?;
    final optimisticVideo = _optimisticVideos[videoId];

    if (optimisticVideo == null) return;

    OptimisticVideo updatedVideo;

    switch (status) {
      case 'ready':
        updatedVideo = OptimisticVideoFactory.markAsReady(
          optimisticVideo: optimisticVideo,
          videoUrl: data['videoUrl'] as String? ?? '',
          thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
          hlsUrl: data['hlsUrl'] as String?,
          duration: data['duration'] as int?,
          fileSize: data['fileSize'] as int?,
        );
        
        // Remove from optimistic cache after a delay
        Timer(const Duration(seconds: 5), () {
          _optimisticVideos.remove(videoId);
          _videoListeners[videoId]?.cancel();
          _videoListeners.remove(videoId);
        });
        break;

      case 'failed':
        updatedVideo = OptimisticVideoFactory.markAsFailed(
          optimisticVideo: optimisticVideo,
          errorMessage: data['errorMessage'] as String? ?? 'Upload failed',
        );
        break;

      default:
        return; // No update needed
    }

    _optimisticVideos[videoId] = updatedVideo;
    notifyListeners();

    // Trigger feed refresh
    _feedRefreshController.add('home');
    _categoryRefreshController.add(updatedVideo.categories);
  }

  /// Update upload progress
  void updateUploadProgress(String videoId, double progress) {
    final optimisticVideo = _optimisticVideos[videoId];
    if (optimisticVideo != null) {
      _optimisticVideos[videoId] = OptimisticVideoFactory.updateProgress(
        optimisticVideo: optimisticVideo,
        progress: progress,
      );
      notifyListeners();
    }
  }

  /// Get optimistic video by ID
  OptimisticVideo? getOptimisticVideo(String videoId) {
    return _optimisticVideos[videoId];
  }

  /// Check if video is optimistic
  bool isOptimisticVideo(String videoId) {
    return _optimisticVideos.containsKey(videoId);
  }

  /// Get optimistic videos for a specific user
  List<OptimisticVideo> getOptimisticVideosForUser(String userId) {
    return _optimisticVideos.values
        .where((video) => video.ownerId == userId)
        .toList();
  }

  /// Get optimistic videos for specific categories
  List<OptimisticVideo> getOptimisticVideosForCategories(List<String> categories) {
    return _optimisticVideos.values
        .where((video) => video.categories.any((cat) => categories.contains(cat)))
        .toList();
  }

  /// Remove optimistic video (when upload fails permanently)
  void removeOptimisticVideo(String videoId) {
    _optimisticVideos.remove(videoId);
    _videoListeners[videoId]?.cancel();
    _videoListeners.remove(videoId);
    notifyListeners();
  }

  /// Clean up all optimistic videos
  void clearAllOptimisticVideos() {
    for (final listener in _videoListeners.values) {
      listener.cancel();
    }
    _videoListeners.clear();
    _optimisticVideos.clear();
    notifyListeners();
  }

  /// Get combined video list (optimistic + regular videos)
  List<OptimisticVideo> getCombinedVideos(List<Map<String, dynamic>> regularVideos) {
    final combinedVideos = <OptimisticVideo>[];

    // Add regular videos
    for (final videoData in regularVideos) {
      final videoId = videoData['id'] as String? ?? videoData['videoId'] as String?;
      if (videoId != null && !_optimisticVideos.containsKey(videoId)) {
        combinedVideos.add(OptimisticVideo.fromJson(videoData));
      }
    }

    // Add optimistic videos
    combinedVideos.addAll(_optimisticVideos.values);

    // Sort by creation date (newest first)
    combinedVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return combinedVideos;
  }

  @override
  void dispose() {
    for (final listener in _videoListeners.values) {
      listener.cancel();
    }
    _videoListeners.clear();
    _optimisticVideos.clear();
    _feedRefreshController.close();
    _categoryRefreshController.close();
    super.dispose();
  }
}
