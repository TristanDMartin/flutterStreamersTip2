import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/optimistic_video.dart';

class OptimisticVideoService extends ChangeNotifier {
  static final OptimisticVideoService _instance =
      OptimisticVideoService._internal();
  factory OptimisticVideoService() => _instance;
  OptimisticVideoService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Optimistic videos cache
  final Map<String, OptimisticVideo> _optimisticVideos = {};
  final Map<String, StreamSubscription> _videoListeners = {};

  // Feed refresh triggers
  final StreamController<String> _feedRefreshController =
      StreamController<String>.broadcast();
  final StreamController<List<String>> _categoryRefreshController =
      StreamController<List<String>>.broadcast();

  // Getters
  List<OptimisticVideo> get optimisticVideos =>
      _optimisticVideos.values.toList();
  Stream<String> get feedRefreshStream => _feedRefreshController.stream;
  Stream<List<String>> get categoryRefreshStream =>
      _categoryRefreshController.stream;

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
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    debugPrint(
        '🔥 OptimisticVideoService: Creating placeholder document for video: ${video.videoId}');
    debugPrint(
        '🔥 OptimisticVideoService: Authenticated user UID: ${user.uid}');
    debugPrint('🔥 OptimisticVideoService: Video owner ID: ${video.ownerId}');
    debugPrint(
        '🔥 OptimisticVideoService: UIDs match: ${user.uid == video.ownerId}');

    final videoData = {
      'userId': video.ownerId,
      'creatorId': video.ownerId, // Add for web/cross-platform compatibility
      'creator_id':
          video.ownerId, // Snake case variant for website compatibility
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
    };

    debugPrint(
        '🔥 OptimisticVideoService: Video data keys: ${videoData.keys.toList()}');
    debugPrint(
        '🔥 OptimisticVideoService: Video data values: ${videoData.values.map((v) => v.toString()).toList()}');

    // Check Firestore auth context
    debugPrint('🔥 OptimisticVideoService: Checking Firestore auth context...');
    try {
      final firestoreUser = _auth.currentUser;
      debugPrint(
          '🔥 OptimisticVideoService: Firestore auth user: ${firestoreUser?.uid}');
      debugPrint(
          '🔥 OptimisticVideoService: Firestore auth user email: ${firestoreUser?.email}');
      debugPrint(
          '🔥 OptimisticVideoService: Firestore auth user displayName: ${firestoreUser?.displayName}');

      if (firestoreUser != null) {
        final firestoreToken = await firestoreUser.getIdToken(true);
        debugPrint(
            '🔥 OptimisticVideoService: Firestore auth token length: ${firestoreToken?.length ?? 0}');
        debugPrint(
            '🔥 OptimisticVideoService: Firestore auth token preview: ${firestoreToken?.substring(0, 20) ?? 'null'}...');

        // Force refresh the Firestore client authentication
        debugPrint(
            '🔥 OptimisticVideoService: Forcing Firestore client auth refresh...');
        try {
          // Wait a moment for auth to propagate
          await Future.delayed(const Duration(milliseconds: 500));

          // Force refresh the auth token
          final refreshedToken = await firestoreUser.getIdToken(true);
          debugPrint(
              '🔥 OptimisticVideoService: Refreshed auth token length: ${refreshedToken?.length ?? 0}');

          // Wait for auth to propagate to Firestore
          await Future.delayed(const Duration(milliseconds: 1000));
          debugPrint(
              '🔥 OptimisticVideoService: Firestore client should be authenticated');
        } catch (e) {
          debugPrint(
              '🔥 OptimisticVideoService: Error refreshing Firestore auth: $e');
        }
      }
    } catch (e) {
      debugPrint(
          '🔥 OptimisticVideoService: Error checking Firestore auth: $e');
    }

    // Create main video document
    debugPrint(
        '🔥 OptimisticVideoService: Attempting to write to Firestore...');
    try {
      await _firestore.collection('videos').doc(video.videoId).set(videoData);
      debugPrint('🔥 OptimisticVideoService: Successfully wrote to Firestore!');
    } catch (e) {
      debugPrint('❌ OptimisticVideoService: Failed to write to Firestore: $e');
      debugPrint('❌ OptimisticVideoService: Error type: ${e.runtimeType}');
      debugPrint('❌ OptimisticVideoService: Error details: ${e.toString()}');

      // Check if user is still authenticated
      final currentUser = _auth.currentUser;
      debugPrint(
          '❌ OptimisticVideoService: Current user after error: ${currentUser?.uid}');
      debugPrint(
          '❌ OptimisticVideoService: User email after error: ${currentUser?.email}');

      rethrow;
    }

    // Add to user's video list
    debugPrint(
        '🔥 OptimisticVideoService: Adding to user video list: ${video.ownerId}/videos/${video.videoId}');
    try {
      await _firestore
          .collection('users')
          .doc(video.ownerId)
          .collection('videos')
          .doc(video.videoId)
          .set({
        'createdAt': video.createdAt,
        'status': 'processing',
      });
      debugPrint(
          '🔥 OptimisticVideoService: Successfully added to user video list!');
    } catch (e) {
      debugPrint(
          '🔥 OptimisticVideoService: Error adding to user video list: $e');
      rethrow;
    }

    // Get privacy setting from metadata
    final privacy = video.metadata?['privacy'] as String? ?? 'Everyone';
    debugPrint('🔥 OptimisticVideoService: Privacy setting: $privacy');

    // Add to appropriate feeds based on privacy setting
    switch (privacy) {
      case 'Everyone':
        // Add to public feeds (For You feed)
        debugPrint('🔥 OptimisticVideoService: Adding to For You feed');
        try {
          await _firestore
              .collection('feeds')
              .doc('for_you')
              .collection('videos')
              .doc(video.videoId)
              .set({
            'videoId': video.videoId,
            'userId': video.ownerId,
            'privacy': privacy,
            'status': 'processing',
            'addedAt': video.createdAt,
          });
          debugPrint(
              '🔥 OptimisticVideoService: Successfully added to For You feed!');
        } catch (e) {
          debugPrint(
              '🔥 OptimisticVideoService: Error adding to For You feed: $e');
          rethrow;
        }

        // Add to following feed
        debugPrint('🔥 OptimisticVideoService: Adding to Following feed');
        try {
          await _firestore
              .collection('feeds')
              .doc('following')
              .collection('videos')
              .doc(video.videoId)
              .set({
            'videoId': video.videoId,
            'userId': video.ownerId,
            'privacy': privacy,
            'status': 'processing',
            'addedAt': video.createdAt,
          });
          debugPrint(
              '🔥 OptimisticVideoService: Successfully added to Following feed!');
        } catch (e) {
          debugPrint(
              '🔥 OptimisticVideoService: Error adding to Following feed: $e');
          rethrow;
        }

        // Add to category feeds for each category
        debugPrint(
            '🔥 OptimisticVideoService: Adding to category feeds: ${video.categories}');
        for (final category in video.categories) {
          debugPrint(
              '🔥 OptimisticVideoService: Adding to category: $category');
          try {
            await _firestore
                .collection('feeds')
                .doc('categories')
                .collection(category)
                .doc(video.videoId)
                .set({
              'videoId': video.videoId,
              'userId': video.ownerId,
              'category': category,
              'privacy': privacy,
              'status': 'processing',
              'addedAt': video.createdAt,
            });
            debugPrint(
                '🔥 OptimisticVideoService: Successfully added to category $category!');
          } catch (e) {
            debugPrint(
                '🔥 OptimisticVideoService: Error adding to category $category: $e');
            rethrow;
          }
        }
        break;

      case 'Connections':
        // Add only to following feed
        await _firestore
            .collection('feeds')
            .doc('following')
            .collection('videos')
            .doc(video.videoId)
            .set({
          'videoId': video.videoId,
          'userId': video.ownerId,
          'privacy': privacy,
          'status': 'processing',
          'addedAt': video.createdAt,
        });

        // Add to connections-only category feeds
        for (final category in video.categories) {
          await _firestore
              .collection('feeds')
              .doc('connections_categories')
              .collection(category)
              .doc(video.videoId)
              .set({
            'videoId': video.videoId,
            'userId': video.ownerId,
            'category': category,
            'privacy': privacy,
            'status': 'processing',
            'addedAt': video.createdAt,
          });
        }
        break;

      case 'Private':
        // Add only to user's private collection
        await _firestore
            .collection('users')
            .doc(video.ownerId)
            .collection('private_videos')
            .doc(video.videoId)
            .set({
          'videoId': video.videoId,
          'userId': video.ownerId,
          'privacy': privacy,
          'status': 'processing',
          'addedAt': video.createdAt,
        });
        break;

      default:
        // Default to private
        await _firestore
            .collection('users')
            .doc(video.ownerId)
            .collection('private_videos')
            .doc(video.videoId)
            .set({
          'videoId': video.videoId,
          'userId': video.ownerId,
          'privacy': privacy,
          'status': 'processing',
          'addedAt': video.createdAt,
        });
        break;
    }
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
  List<OptimisticVideo> getOptimisticVideosForCategories(
      List<String> categories) {
    return _optimisticVideos.values
        .where(
            (video) => video.categories.any((cat) => categories.contains(cat)))
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
  List<OptimisticVideo> getCombinedVideos(
      List<Map<String, dynamic>> regularVideos) {
    final combinedVideos = <OptimisticVideo>[];

    // Add regular videos
    for (final videoData in regularVideos) {
      final videoId =
          videoData['id'] as String? ?? videoData['videoId'] as String?;
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
