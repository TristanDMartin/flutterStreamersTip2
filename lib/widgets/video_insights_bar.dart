import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/video.dart';
import '../models/home_video.dart';
import '../models/user.dart';

class VideoInsightsBar extends StatefulWidget {
  final Video video;
  final String? currentUserId;
  final VoidCallback? onInsightsTap;

  const VideoInsightsBar({
    super.key,
    required this.video,
    this.currentUserId,
    this.onInsightsTap,
  });

  @override
  State<VideoInsightsBar> createState() => _VideoInsightsBarState();
}

class _VideoInsightsBarState extends State<VideoInsightsBar> {
  VideoAnalytics? analytics;
  StreamSubscription? _analyticsSubscription;
  final VideoAnalyticsService _analyticsService = VideoAnalyticsService();

  bool get isVideoOwner => widget.currentUserId == widget.video.creator.id;

  int get displayViews => analytics?.views ?? widget.video.views;

  @override
  void initState() {
    super.initState();
    if (isVideoOwner) {
      _startListeningToAnalytics();
    }
  }

  @override
  void dispose() {
    _stopListeningToAnalytics();
    super.dispose();
  }

  void _startListeningToAnalytics() {
    _analyticsSubscription = _analyticsService.startListeningToAnalytics(
      widget.video.id,
      onAnalyticsUpdate: (updatedAnalytics) {
        if (mounted) {
          setState(() {
            analytics = updatedAnalytics;
          });
        }
      },
    );
  }

  void _stopListeningToAnalytics() {
    _analyticsSubscription?.cancel();
    _analyticsSubscription = null;
    _analyticsService.stopListeningToAnalytics(widget.video.id);
  }

  @override
  Widget build(BuildContext context) {
    if (!isVideoOwner) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Left side - View count
          Row(
            children: [
              const Icon(
                Icons.play_circle,
                size: 14,
                color: Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                "${_formattedViews(displayViews)} views",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          
          const Spacer(),
          
          // Right side - More insights button
          GestureDetector(
            onTap: widget.onInsightsTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha:0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.trending_up,
                    size: 14,
                    color: Colors.white,
                  ),
                  SizedBox(width: 6),
                  Text(
                    "More insights",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formattedViews(int views) {
    if (views < 1000) return views.toString();
    final kValue = views / 1000.0;
    return "${kValue.toStringAsFixed(1)}K";
  }
}

// Video analytics service
class VideoAnalyticsService {
  final Map<String, VideoAnalytics> _videoAnalytics = {};
  final Map<String, StreamSubscription> _listeners = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  VideoAnalytics? getVideoAnalytics(String videoId) {
    return _videoAnalytics[videoId];
  }

  StreamSubscription startListeningToAnalytics(
    String videoId, {
    required Function(VideoAnalytics) onAnalyticsUpdate,
  }) {
    debugPrint("Started listening to analytics for video: $videoId");
    
    return _firestore
        .collection('video_analytics')
        .doc(videoId)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          final analytics = VideoAnalytics.fromMap(snapshot.data()!);
          _videoAnalytics[videoId] = analytics;
          onAnalyticsUpdate(analytics);
        }
      },
      onError: (error) {
        debugPrint("Error listening to analytics for video $videoId: $error");
      },
    );
  }

  void stopListeningToAnalytics(String videoId) {
    final listener = _listeners[videoId];
    listener?.cancel();
    _listeners.remove(videoId);
    debugPrint("Stopped listening to analytics for video: $videoId");
  }

  Future<void> trackVideoView({required String videoId, String? userId}) async {
    try {
      debugPrint("Tracked video view: $videoId by user: $userId");
      
      final analyticsRef = _firestore.collection('video_analytics').doc(videoId);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(analyticsRef);
        
        if (snapshot.exists) {
          final currentViews = snapshot.data()?['views'] ?? 0;
          transaction.update(analyticsRef, {
            'views': currentViews + 1,
            'lastViewedAt': FieldValue.serverTimestamp(),
            if (userId != null) 'viewedBy': FieldValue.arrayUnion([userId]),
          });
        } else {
          transaction.set(analyticsRef, {
            'views': 1,
            'likes': 0,
            'shares': 0,
            'comments': 0,
            'watchTime': 0.0,
            'engagementRate': 0.0,
            'lastViewedAt': FieldValue.serverTimestamp(),
            if (userId != null) 'viewedBy': [userId],
          });
        }
      });
    } catch (error) {
      debugPrint("Error tracking video view: $error");
    }
  }
}

// Video analytics data model
class VideoAnalytics {
  final int views;
  final int likes;
  final int shares;
  final int comments;
  final double watchTime;
  final double engagementRate;

  const VideoAnalytics({
    required this.views,
    required this.likes,
    required this.shares,
    required this.comments,
    required this.watchTime,
    required this.engagementRate,
  });

  factory VideoAnalytics.fromMap(Map<String, dynamic> map) {
    return VideoAnalytics(
      views: map['views'] ?? 0,
      likes: map['likes'] ?? 0,
      shares: map['shares'] ?? 0,
      comments: map['comments'] ?? 0,
      watchTime: (map['watchTime'] ?? 0.0).toDouble(),
      engagementRate: (map['engagementRate'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'views': views,
      'likes': likes,
      'shares': shares,
      'comments': comments,
      'watchTime': watchTime,
      'engagementRate': engagementRate,
    };
  }
}

// Preview widget for testing
class VideoInsightsBarPreview extends StatelessWidget {
  const VideoInsightsBarPreview({super.key});

  @override
  Widget build(BuildContext context) {
    // Create a sample video for preview
    const sampleVideo = HomeVideo(
      id: "sample-video-id",
      creator: User(id: 'current-user-id', username: 'sampleuser', displayName: 'Sample User'),
      videoURL: "https://example.com/video.mp4",
      thumbnailURL: "https://example.com/thumbnail.jpg",
      likes: 42,
      comments: 12,
      views: 1234,
      caption: 'Preview caption',
    );

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Preview for video owner
          VideoInsightsBar(
            video: sampleVideo,
            currentUserId: "current-user-id", // Same as video.userId
            onInsightsTap: () => debugPrint("Insights tapped"),
          ),
          
          const SizedBox(height: 20),
          
          // Preview for non-owner (should be hidden)
          VideoInsightsBar(
            video: sampleVideo,
            currentUserId: "different-user-id", // Different from video.userId
            onInsightsTap: () => debugPrint("Insights tapped"),
          ),
        ],
      ),
    );
  }
}
