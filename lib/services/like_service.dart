import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'engagement_analytics_service.dart';

class LikeService {
  static final LikeService _instance = LikeService._internal();
  factory LikeService() => _instance;
  LikeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Toggle like status for a video
  Future<bool> toggleLike(String videoId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Check current like status
      final isLiked = await _isVideoLiked(videoId);
      
      if (isLiked) {
        return await _unlikeVideo(videoId);
      } else {
        return await _likeVideo(videoId);
      }
    } catch (e) {
      print('Error toggling like: $e');
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
      print('Error liking video: $e');
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
      print('Error unliking video: $e');
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
      print('Error checking like status: $e');
      return false;
    }
  }

  /// Get like count for a video
  Future<int> getLikeCount(String videoId) async {
    try {
      final doc = await _firestore.collection('videos').doc(videoId).get();
      return doc.data()?['likes'] ?? 0;
    } catch (e) {
      print('Error getting like count: $e');
      return 0;
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
