import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'engagement_analytics_service.dart';

class LikeService {
  static final LikeService _instance = LikeService._internal();
  factory LikeService() => _instance;
  LikeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Local persistence for likes
  static const String _likedVideosKey = 'liked_videos';
  static const String _likeCountsKey = 'like_counts';

  /// Toggle like status for a video
  Future<bool> toggleLike(String videoId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Check current like status
      final isLiked = await _isVideoLiked(videoId);
      
      if (isLiked) {
        final success = await _unlikeVideo(videoId);
        if (success) {
          // Update local storage
          final likedVideos = await getLikedVideos();
          likedVideos.remove(videoId);
          await saveLikedVideos(likedVideos);
          
          // Update like count in local storage
          final likeCounts = await getLikeCounts();
          final currentCount = likeCounts[videoId] ?? 0;
          likeCounts[videoId] = (currentCount - 1).clamp(0, double.infinity).toInt();
          await saveLikeCounts(likeCounts);
        }
        return success;
      } else {
        final success = await _likeVideo(videoId);
        if (success) {
          // Update local storage
          final likedVideos = await getLikedVideos();
          likedVideos.add(videoId);
          await saveLikedVideos(likedVideos);
          
          // Update like count in local storage
          final likeCounts = await getLikeCounts();
          final currentCount = likeCounts[videoId] ?? 0;
          likeCounts[videoId] = currentCount + 1;
          await saveLikeCounts(likeCounts);
        }
        return success;
      }
    } catch (e) {
      // Error toggling like: $e
      return false;
    }
  }

  /// Like a video
  Future<bool> _likeVideo(String videoId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final batch = _firestore.batch();
      
      // Add to user's liked videos
      final userLikeRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('likedVideos')
          .doc(videoId);
      batch.set(userLikeRef, {
        'videoId': videoId,
        'likedAt': FieldValue.serverTimestamp(),
      });

      // Increment video like count
      final videoRef = _firestore.collection('videos').doc(videoId);
      batch.update(videoRef, {
        'likes': FieldValue.increment(1),
        'isLiked': true,
      });

      await batch.commit();
      return true;
    } catch (e) {
      // Error liking video: $e
      return false;
    }
  }

  /// Unlike a video
  Future<bool> _unlikeVideo(String videoId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final batch = _firestore.batch();
      
      // Remove from user's liked videos
      final userLikeRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('likedVideos')
          .doc(videoId);
      batch.delete(userLikeRef);

      // Decrement video like count
      final videoRef = _firestore.collection('videos').doc(videoId);
      batch.update(videoRef, {
        'likes': FieldValue.increment(-1),
        'isLiked': false,
      });

      await batch.commit();
      return true;
    } catch (e) {
      // Error unliking video: $e
      return false;
    }
  }

  /// Check if video is liked by current user
  Future<bool> _isVideoLiked(String videoId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final doc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('likedVideos')
          .doc(videoId)
          .get();

      return doc.exists;
    } catch (e) {
      // Error checking like status: $e
      return false;
    }
  }


  /// Track like engagement
  void trackLikeEngagement(String videoId, bool isLiked) {
    EngagementAnalyticsService().trackEngagement(
      videoId: videoId,
      event: isLiked ? EngagementEvent.like : EngagementEvent.unlike,
      metadata: {
        'timestamp': DateTime.now().toIso8601String(),
        'isReplay': false,
      },
    );
  }

  /// Get liked videos from local storage
  Future<Set<String>> getLikedVideos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final likedVideosJson = prefs.getString(_likedVideosKey);
      if (likedVideosJson != null) {
        final List<dynamic> likedVideosList = json.decode(likedVideosJson);
        return likedVideosList.cast<String>().toSet();
      }
      return <String>{};
    } catch (e) {
      // Error getting liked videos from local storage: $e
      return <String>{};
    }
  }

  /// Save liked videos to local storage
  Future<void> saveLikedVideos(Set<String> likedVideos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final likedVideosJson = json.encode(likedVideos.toList());
      await prefs.setString(_likedVideosKey, likedVideosJson);
    } catch (e) {
      // Error saving liked videos to local storage: $e
    }
  }

  /// Get like counts from local storage
  Future<Map<String, int>> getLikeCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final likeCountsJson = prefs.getString(_likeCountsKey);
      if (likeCountsJson != null) {
        final Map<String, dynamic> likeCountsMap = json.decode(likeCountsJson);
        return likeCountsMap.map((key, value) => MapEntry(key, value as int));
      }
      return <String, int>{};
    } catch (e) {
      // Error getting like counts from local storage: $e
      return <String, int>{};
    }
  }

  /// Save like counts to local storage
  Future<void> saveLikeCounts(Map<String, int> likeCounts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final likeCountsJson = json.encode(likeCounts);
      await prefs.setString(_likeCountsKey, likeCountsJson);
    } catch (e) {
      // Error saving like counts to local storage: $e
    }
  }

  /// Check if video is liked (with local persistence)
  Future<bool> isVideoLiked(String videoId) async {
    try {
      // First check local storage for immediate response
      final likedVideos = await getLikedVideos();
      if (likedVideos.contains(videoId)) {
        return true;
      }

      // Then check Firebase for accuracy
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final doc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('likedVideos')
          .doc(videoId)
          .get();

      final isLiked = doc.exists;
      
      // Update local storage with Firebase result
      if (isLiked) {
        likedVideos.add(videoId);
        await saveLikedVideos(likedVideos);
      }

      return isLiked;
    } catch (e) {
      // Error checking if video is liked: $e
      // Fallback to local storage
      final likedVideos = await getLikedVideos();
      return likedVideos.contains(videoId);
    }
  }

  /// Get like count (with local persistence)
  Future<int> getLikeCount(String videoId) async {
    try {
      // First check local storage for immediate response
      final likeCounts = await getLikeCounts();
      if (likeCounts.containsKey(videoId)) {
        return likeCounts[videoId]!;
      }

      // Then check Firebase for accuracy
      final doc = await _firestore
          .collection('videos')
          .doc(videoId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final likeCount = data?['likes'] as int? ?? 0;
        
        // Update local storage with Firebase result
        likeCounts[videoId] = likeCount;
        await saveLikeCounts(likeCounts);
        
        return likeCount;
      }

      return 0;
    } catch (e) {
      // Error getting like count: $e
      // Fallback to local storage
      final likeCounts = await getLikeCounts();
      return likeCounts[videoId] ?? 0;
    }
  }
}

/// Optimized floating hearts animation
class FloatingHeartsAnimation {
  static void createFloatingHearts(
    BuildContext context,
    Offset origin,
    VoidCallback onComplete,
  ) {
    // Simple, lightweight animation without complex state management
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => _FloatingHeartsWidget(
        origin: origin,
        onComplete: onComplete,
      ),
    );
    
    overlay.insert(overlayEntry);
    
    // Auto-remove after animation
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }
}

class _FloatingHeartsWidget extends StatefulWidget {
  final Offset origin;
  final VoidCallback onComplete;

  const _FloatingHeartsWidget({
    required this.origin,
    required this.onComplete,
  });

  @override
  State<_FloatingHeartsWidget> createState() => _FloatingHeartsWidgetState();
}

class _FloatingHeartsWidgetState extends State<_FloatingHeartsWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _positionAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.elasticOut),
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    ));

    _positionAnimation = Tween<Offset>(
      begin: widget.origin,
      end: Offset(widget.origin.dx, widget.origin.dy - 100),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _positionAnimation.value.dx - 15,
          top: _positionAnimation.value.dy - 15,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: const Icon(
                Icons.favorite,
                color: Color(0xFF9248D2),
                size: 30,
              ),
            ),
          ),
        );
      },
    );
  }
}
